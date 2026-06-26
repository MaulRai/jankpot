class_name GameController
extends Node

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")
const BattleStateData = preload("res://scripts/game/battle/BattleState.gd")
const BattleEffectResolverData = preload("res://scripts/game/battle/BattleEffectResolver.gd")
const BattleEffectExecutorData = preload("res://scripts/game/battle/BattleEffectExecutor.gd")
const BattleAnimatorData = preload("res://scripts/animation/BattleAnimator.gd")

signal turn_resolved
signal battle_ended(winner: String)

@onready var deck_manager: DeckManager = $DeckManager
@onready var battle_resolver: BattleResolver = $BattleResolver
@onready var enemy_controller: EnemyController = $EnemyController
@onready var hand_view: HandView = get_node("../BottomHand")
@onready var battle_board: Control = get_node("../CenterBoard")
@onready var player_slot: CardSlot = get_node("../CenterBoard/PlayerSlot")
@onready var enemy_slot: CardSlot = get_node("../CenterBoard/EnemySlot")
@onready var battle_sidebar: Control = get_node("../LeftPanel")
@onready var tooltip_manager: TooltipManager = get_node("../TooltipManager")
@onready var draw_pile_visual: Control = get_node("../DrawPileVisual")
@onready var pile_card_bottom: TextureRect = get_node("../DrawPileVisual/PileCardBottom")
@onready var pile_card_middle: TextureRect = get_node("../DrawPileVisual/PileCardMiddle")
@onready var pile_card_top: TextureRect = get_node("../DrawPileVisual/PileCardTop")
@onready var pile_count_label: Label = get_node("../DrawPileVisual/CountLabel")
@onready var reward_overlay: Control = get_node("../RewardOverlay")
@onready var discard_viewer: Control = get_node("../DiscardViewer")
@onready var consumable_shelf: Control = get_node("../ConsumableShelf")
@onready var magic_ball_modal: Control = get_node("../MagicBallModal")
@onready var sfx_manager: Node = get_node("../SFXManager")

var _state: Resource = BattleStateData.new()
var _effects: RefCounted = BattleEffectResolverData.new()
var _animator: Node
var _effect_executor: Node
var _is_animating := false
var _pending_enemy_card: CardDef
var _enemy_preview_view: CardView

var player_hp: int:
	get: return _state.player_hp
	set(value): _state.player_hp = value
var enemy_hp: int:
	get: return _state.enemy_hp
	set(value): _state.enemy_hp = value
var turn_count: int:
	get: return _state.turn_count
	set(value): _state.turn_count = value
var stage_number: int:
	get: return _state.stage_number
	set(value): _state.stage_number = value
var round_status: String:
	get: return _state.round_status
	set(value): _state.round_status = value


func _ready() -> void:
	_animator = BattleAnimatorData.new()
	add_child(_animator)
	_animator.configure({
		"main_node": get_parent(),
		"hand_view": hand_view,
		"player_slot": player_slot,
		"enemy_slot": enemy_slot,
		"pile_card_bottom": pile_card_bottom,
		"pile_card_middle": pile_card_middle,
		"pile_card_top": pile_card_top,
		"pile_count_label": pile_count_label,
		"draw_pile_visual": draw_pile_visual,
		"discard_viewer": discard_viewer,
		"deck_manager": deck_manager,
		"sfx_manager": sfx_manager,
	})
	_effect_executor = BattleEffectExecutorData.new()
	add_child(_effect_executor)
	_effect_executor.configure({
		"state": _state,
		"animator": _animator,
		"deck_manager": deck_manager,
		"enemy_controller": enemy_controller,
		"health_display": battle_board,
		"player_slot": player_slot,
		"enemy_slot": enemy_slot,
		"update_labels": _update_labels,
	})
	battle_board.set_tooltip_manager(tooltip_manager)
	deck_manager.hand_changed.connect(_on_hand_changed)
	deck_manager.draw_pile_changed.connect(_animator.update_pile_visuals)
	deck_manager.discard_pile_changed.connect(_animator.update_pile_visuals)
	hand_view.card_play_requested.connect(_on_card_play_requested)
	hand_view.card_drag_started.connect(_on_hand_card_drag_started)
	hand_view.card_drag_ended.connect(_on_hand_card_drag_ended)
	reward_overlay.reward_selected.connect(_on_reward_selected)
	consumable_shelf.magic_ball_requested.connect(_on_magic_ball_requested)
	consumable_shelf.shield_requested.connect(_on_shield_requested)
	await _initialize_first_battle()


func _initialize_first_battle() -> void:
	_is_animating = true
	hand_view.set_dragging_enabled(false)
	var selected_enemy := enemy_controller.select_random_non_boss(0)
	deck_manager.setup_starting_deck()
	_animator.update_pile_visuals()
	await get_tree().process_frame
	battle_sidebar.set_enemy_info(selected_enemy)
	await _refill_hand_or_give_skip()
	await _prepare_enemy_card()
	_is_animating = false
	hand_view.set_dragging_enabled(true)
	_update_labels()


func _on_hand_changed() -> void:
	if not _is_animating:
		_ensure_player_skip_if_needed()
		hand_view.set_cards(deck_manager.hand)


func _on_card_play_requested(card_data: CardDef, card_view: CardView) -> void:
	if round_status != "ongoing" or _is_animating \
			or (_state.has_disabled_player_type \
			and card_data.card_type == _state.disabled_player_type \
			and not card_data.is_skip):
		await _reject_card(card_view)
		return
	var drop_pos := card_view.global_position + card_view.size / 2.0
	if not player_slot.get_global_rect().has_point(drop_pos):
		await _reject_card(card_view)
		return
	await _play_card(card_data, card_view)


func _reject_card(card_view: CardView) -> void:
	_is_animating = true
	await _animator.snap_card_back(card_view)
	_is_animating = false


func _on_hand_card_drag_started(_card_view: CardView) -> void:
	if round_status == "ongoing" and not _is_animating:
		player_slot.set_drop_target_active(true)


func _on_hand_card_drag_ended(_card_view: CardView) -> void:
	player_slot.set_drop_target_active(false)


func _on_magic_ball_requested() -> void:
	if round_status != "ongoing" or _is_animating or not _pending_enemy_card:
		return
	var prediction := _pending_enemy_card.card_type
	if randf() >= 0.8:
		var wrong_types: Array[int] = [
			CardDef.CardType.ROCK, CardDef.CardType.PAPER, CardDef.CardType.SCISSORS,
		]
		wrong_types.erase(prediction)
		prediction = wrong_types.pick_random() as CardDef.CardType
	consumable_shelf.consume_magic_ball()
	magic_ball_modal.show_prediction(prediction)


func _on_shield_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	_state.player_shield += 1
	consumable_shelf.consume_shield()
	_update_labels()


func _play_card(card_data: CardDef, card_view: CardView) -> void:
	_is_animating = true
	hand_view.set_dragging_enabled(false, card_view)
	card_view.set_interaction_enabled(false)
	await _animator.move_player_card_to_slot(card_view)
	_state.has_disabled_player_type = false
	hand_view.set_disabled_type(false, _state.disabled_player_type)
	if not _pending_enemy_card or not is_instance_valid(_enemy_preview_view):
		await _prepare_enemy_card()
	var enemy_card := _pending_enemy_card
	var enemy_view := _enemy_preview_view
	enemy_card = _apply_luck(card_data, enemy_card, _luck_chance(deck_manager.hand, card_data), false)
	enemy_card = _apply_luck(card_data, enemy_card, _luck_chance(enemy_controller.enemy_hand, null), true)
	_pending_enemy_card = enemy_card
	await get_tree().create_timer(0.2).timeout
	await _animator.flip_card(enemy_view, enemy_card)

	var player_history := card_data.copy()
	var enemy_history := enemy_card.copy()
	var result: BattleResolver.Result = battle_resolver.resolve_cards(card_data, enemy_card)
	var plan: RefCounted = _effects.build_plan(
		result, card_data, enemy_card, deck_manager.hand,
		enemy_controller.enemy_hand, _state
	)
	await _effect_executor.execute(
		plan, result, card_data, enemy_card, card_view, enemy_view
	)
	battle_sidebar.add_history(player_history, enemy_history)
	enemy_controller.record_clash(
		player_history.card_type, enemy_history.card_type, result
	)

	await get_tree().create_timer(0.35).timeout
	await _animator.discard_cards(
		card_view, enemy_view,
		"downgrade" if plan.player_downgrade else "auto",
		"downgrade" if plan.enemy_downgrade else "auto"
	)
	hand_view.set_dragging_enabled(true)
	_pending_enemy_card = null
	_enemy_preview_view = null
	deck_manager.play_card(card_data.id)
	enemy_controller.play_card(enemy_card)
	if player_hp <= 0 or enemy_hp <= 0:
		_end_battle()
		return
	await _refill_hand_or_give_skip()
	await _prepare_enemy_card()
	_is_animating = false
	turn_count += 1
	_update_labels()
	turn_resolved.emit()


func _prepare_enemy_card() -> void:
	if round_status != "ongoing" or not hand_view.card_scene \
			or is_instance_valid(_enemy_preview_view):
		return
	_pending_enemy_card = enemy_controller.choose_card(enemy_hp, player_hp)
	if not _pending_enemy_card:
		_pending_enemy_card = WeaponCatalogData.create_skip("enemy_skip_%d" % Time.get_ticks_usec())
	_enemy_preview_view = hand_view.card_scene.instantiate()
	_enemy_preview_view.custom_minimum_size = Vector2(160, 240)
	enemy_slot.place_card(_enemy_preview_view)
	_enemy_preview_view.set_interaction_enabled(false)
	_enemy_preview_view.set_face_down(true)
	_enemy_preview_view.z_index = 0
	await _animator.animate_enemy_card_entry(_enemy_preview_view)


func _update_labels() -> void:
	hand_view.set_disabled_type(_state.has_disabled_player_type, _state.disabled_player_type)
	battle_sidebar.set_health(player_hp, enemy_hp)
	battle_board.set_health(player_hp, enemy_hp)
	battle_board.set_bleed_status(
		_state.player_bleed_pending,
		_state.enemy_bleed_pending
	)
	battle_board.set_shield_status(
		_state.player_shield,
		_state.enemy_shield
	)
	battle_sidebar.set_progress(2, 8, turn_count + 1)


func _end_battle() -> void:
	round_status = "ended"
	hand_view.set_dragging_enabled(false)
	var winner := "Draw"
	if player_hp <= 0 and enemy_hp > 0:
		winner = "Enemy"
	elif enemy_hp <= 0 and player_hp > 0:
		winner = "Player"
	battle_ended.emit(winner)
	if winner == "Player":
		reward_overlay.show_choices(WeaponCatalogData.generate_reward_choices(
			3, deck_manager.get_types_with_basic_weapon()
		))
	else:
		_is_animating = false


func _on_reward_selected(card: CardDef) -> void:
	deck_manager.replace_basic_with_upgrade(card)
	stage_number += 1
	await start_battle()


func start_battle() -> void:
	_state.reset_for_battle()
	_is_animating = true
	hand_view.set_dragging_enabled(false)
	_pending_enemy_card = null
	_enemy_preview_view = null
	player_slot.set_drop_target_active(false)
	player_slot.clear_slot()
	enemy_slot.clear_slot()
	battle_sidebar.clear_history()
	hand_view.set_cards([])
	var upgrade_count := clampi(stage_number - 1, 0, 9)
	battle_sidebar.set_enemy_info(enemy_controller.select_random_non_boss(upgrade_count))
	deck_manager.setup_starting_deck()
	await _animator.refill_hand()
	await _prepare_enemy_card()
	_is_animating = false
	hand_view.set_dragging_enabled(true)
	_update_labels()


func _ensure_player_skip_if_needed() -> void:
	if round_status != "ongoing":
		return
	if _player_has_valid_move():
		return
	deck_manager.ensure_skip_card()


func _refill_hand_or_give_skip() -> void:
	if not deck_manager.has_playable_available(
		_state.has_disabled_player_type,
		_state.disabled_player_type
	):
		var had_skip := _player_has_skip_in_hand()
		var skip := deck_manager.create_skip_card_in_hand()
		if not had_skip:
			await _animator.animate_skip_card_entry(skip)
		else:
			hand_view.set_cards(deck_manager.hand)
		hand_view.set_disabled_type(_state.has_disabled_player_type, _state.disabled_player_type)
		_animator.update_pile_visuals()
		return
	await _animator.refill_hand()


func _player_has_valid_move() -> bool:
	for card in deck_manager.hand:
		if not card or card.temporarily_disabled or card.is_skip:
			continue
		if _state.has_disabled_player_type and card.card_type == _state.disabled_player_type:
			continue
		return true
	return false


func _player_has_skip_in_hand() -> bool:
	for card in deck_manager.hand:
		if card and card.is_skip:
			return true
	return false


func _apply_luck(
	player_card: CardDef,
	enemy_card: CardDef,
	luck: float,
	favors_enemy: bool
) -> CardDef:
	if not player_card or player_card.is_skip:
		return enemy_card
	if luck <= 0.0 or randf() >= luck:
		return enemy_card

	var priorities: Array[BattleResolver.Result]
	if favors_enemy:
		priorities = [
			BattleResolver.Result.LOSE,
			BattleResolver.Result.DRAW,
			BattleResolver.Result.WIN,
		]
	else:
		priorities = [
			BattleResolver.Result.WIN,
			BattleResolver.Result.DRAW,
			BattleResolver.Result.LOSE,
		]

	var replacement := _best_enemy_card_for_result(player_card, priorities)
	return replacement if replacement else enemy_card


func _luck_chance(cards: Array[CardDef], excluded_card: CardDef) -> float:
	var chance := 0.0
	if _has_hatter_slip(cards, excluded_card):
		chance += 0.15
	return clampf(chance, 0.0, 1.0)


func _best_enemy_card_for_result(
	player_card: CardDef,
	priorities: Array[BattleResolver.Result]
) -> CardDef:
	for desired_result in priorities:
		var matches: Array[CardDef] = []
		for enemy_card in enemy_controller.enemy_hand:
			if not enemy_card or enemy_card.temporarily_disabled:
				continue
			var result := battle_resolver.resolve_cards(player_card, enemy_card)
			if result == desired_result:
				matches.append(enemy_card)
		if not matches.is_empty():
			return matches.pick_random()
	return null


func _has_hatter_slip(cards: Array[CardDef], excluded_card: CardDef) -> bool:
	for card in cards:
		if card and card != excluded_card and not card.temporarily_disabled \
				and WeaponCatalogData.EFFECT_HATTER_SLIP in card.effects:
			return true
	return false
