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
@onready var player_slot: CardSlot = get_node("../CenterBoard/PlayerSlot")
@onready var enemy_slot: CardSlot = get_node("../CenterBoard/EnemySlot")
@onready var battle_sidebar: Control = get_node("../LeftPanel")
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
		"battle_sidebar": battle_sidebar,
		"player_slot": player_slot,
		"enemy_slot": enemy_slot,
		"update_labels": _update_labels,
	})
	deck_manager.hand_changed.connect(_on_hand_changed)
	deck_manager.draw_pile_changed.connect(_animator.update_pile_visuals)
	deck_manager.discard_pile_changed.connect(_animator.update_pile_visuals)
	hand_view.card_play_requested.connect(_on_card_play_requested)
	hand_view.card_drag_started.connect(_on_hand_card_drag_started)
	hand_view.card_drag_ended.connect(_on_hand_card_drag_ended)
	reward_overlay.reward_selected.connect(_on_reward_selected)
	consumable_shelf.magic_ball_requested.connect(_on_magic_ball_requested)
	await _initialize_first_battle()


func _initialize_first_battle() -> void:
	_is_animating = true
	var selected_enemy := enemy_controller.select_random_non_boss(0)
	deck_manager.setup_starting_deck()
	_animator.update_pile_visuals()
	await get_tree().process_frame
	battle_sidebar.set_enemy_info(selected_enemy)
	await _animator.refill_hand()
	await _prepare_enemy_card()
	_is_animating = false
	_update_labels()


func _on_hand_changed() -> void:
	if not _is_animating:
		hand_view.set_cards(deck_manager.hand)


func _on_card_play_requested(card_data: CardDef, card_view: CardView) -> void:
	if round_status != "ongoing" or _is_animating \
			or (_state.has_disabled_player_type \
			and card_data.card_type == _state.disabled_player_type):
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


func _play_card(card_data: CardDef, card_view: CardView) -> void:
	_is_animating = true
	_state.has_disabled_player_type = false
	card_view.set_interaction_enabled(false)
	await _animator.move_player_card_to_slot(card_view)
	if not _pending_enemy_card or not is_instance_valid(_enemy_preview_view):
		await _prepare_enemy_card()
	var enemy_card := _pending_enemy_card
	var enemy_view := _enemy_preview_view
	await get_tree().create_timer(0.2).timeout
	await _animator.flip_card(enemy_view, enemy_card)

	var player_history := card_data.copy()
	var enemy_history := enemy_card.copy()
	var result: BattleResolver.Result = battle_resolver.resolve(
		card_data.card_type, enemy_card.card_type
	)
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
	_pending_enemy_card = null
	_enemy_preview_view = null
	deck_manager.play_card(card_data.id)
	enemy_controller.play_card(enemy_card)
	if player_hp <= 0 or enemy_hp <= 0:
		_end_battle()
		return
	await _animator.refill_hand()
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
	_enemy_preview_view = hand_view.card_scene.instantiate()
	_enemy_preview_view.custom_minimum_size = Vector2(160, 240)
	enemy_slot.place_card(_enemy_preview_view)
	_enemy_preview_view.set_interaction_enabled(false)
	_enemy_preview_view.set_face_down(true)
	_enemy_preview_view.z_index = 0
	await _animator.animate_enemy_card_entry(_enemy_preview_view)


func _update_labels() -> void:
	battle_sidebar.set_health(player_hp, enemy_hp)
	battle_sidebar.set_progress(2, 8, turn_count + 1)


func _end_battle() -> void:
	round_status = "ended"
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
	_update_labels()
