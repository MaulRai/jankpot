class_name GameController
extends Node

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")
const BattleStateData = preload("res://scripts/game/battle/BattleState.gd")
const BattleEffectResolverData = preload("res://scripts/game/battle/BattleEffectResolver.gd")
const BattleEffectExecutorData = preload("res://scripts/game/battle/BattleEffectExecutor.gd")
const BattleAnimatorData = preload("res://scripts/animation/BattleAnimator.gd")
const RunConfigData = preload("res://scripts/data/RunConfig.gd")
const PlayerStorageData = preload("res://scripts/data/PlayerStorage.gd")
const EffectKeywordData = preload("res://scripts/data/EffectKeyword.gd")
const PIXEL_FRAME_SCRIPT := preload("res://scripts/ui/PixelFramePanel.gd")
const STAR_CRUSH_FONT := preload("res://fonts/Star Crush.otf")
const SELECTED_CARD_BASE_TEXTURE := preload("res://assets/ui/card-base.png")
const CARD_SCENE := preload("res://scenes/ui/CardView.tscn")

const ItemHandlerData = preload("res://scripts/game/ItemHandler.gd")
const MorphResolverData = preload("res://scripts/game/MorphResolver.gd")
const RunSerializerData = preload("res://scripts/game/RunSerializer.gd")

signal turn_resolved
signal battle_ended(winner: String)
signal boss_victory(money_earned: int)

@onready var deck_manager: DeckManager = $DeckManager
@onready var battle_resolver: BattleResolver = $BattleResolver
@onready var enemy_controller: EnemyController = $EnemyController
@onready var hand_view: HandView = get_node("../BottomHand")
@onready var battle_board: Control = get_node("../CenterBoard")
@onready var player_slot: CardSlot = get_node("../CenterBoard/PlayerSlot")
@onready var enemy_slot: CardSlot = get_node("../CenterBoard/EnemySlot")
@onready var battle_sidebar: BattleSidebar = get_node("../LeftPanel")
@onready var tooltip_manager: TooltipManager = get_node("../TooltipManager")
@onready var draw_pile_visual: Control = get_node("../DrawPileVisual")
@onready var pile_card_bottom: TextureRect = get_node("../DrawPileVisual/PileCardBottom")
@onready var pile_card_middle: TextureRect = get_node("../DrawPileVisual/PileCardMiddle")
@onready var pile_card_top: TextureRect = get_node("../DrawPileVisual/PileCardTop")
@onready var pile_count_label: Label = get_node("../DrawPileVisual/CountLabel")
@onready var reward_overlay: Control = get_node("../RewardOverlay")
@onready var discard_viewer: Control = get_node("../DiscardViewer")
@onready var consumable_shelf: ConsumableShelf = get_node("../ConsumableShelf")
@onready var magic_ball_modal: Control = get_node("../MagicBallModal")
@onready var sfx_manager: Node = get_node("../SFXManager")

var _state: Resource = BattleStateData.new()
var _effects: RefCounted = BattleEffectResolverData.new()
var _animator: Node
var _effect_executor: Node
var _is_animating := false
var _pending_enemy_card: CardDef
var _enemy_preview_view: CardView
var _pick_mode: PickMode
var _run_money_earned := 0

var item_handler: RefCounted
var morph_resolver: RefCounted
var run_serializer: RefCounted

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
	item_handler = ItemHandlerData.new()
	item_handler.configure(self)
	morph_resolver = MorphResolverData.new()
	morph_resolver.configure(self)
	run_serializer = RunSerializerData.new()
	run_serializer.configure(self)

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

	consumable_shelf.magic_ball_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_MAGIC_BALL))
	consumable_shelf.shield_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_SHIELD))
	consumable_shelf.remedy_kit_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_REMEDY_KIT))
	consumable_shelf.cup_a_joe_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_CUP_A_JOE))
	consumable_shelf.moonlight_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_MOONLIGHT))
	consumable_shelf.snake_oil_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_SNAKE_OIL))
	consumable_shelf.pocketwatch_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_POCKETWATCH))
	consumable_shelf.velvet_gloves_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_VELVET_GLOVES))
	consumable_shelf.l_ivoire_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_L_IVOIRE))
	consumable_shelf.sealed_missive_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_SEALED_MISSIVE))
	consumable_shelf.curio_requested.connect(item_handler.use_item.bind(PlayerStorageData.CONSUMABLE_CURIO))

	_stock_consumables_from_storage()
	
	await _initialize_first_battle()


func _initialize_first_battle() -> void:
	_is_animating = true
	hand_view.set_dragging_enabled(false)
	var saved_state: Dictionary = {}
	if PlayerStorageData.has_saved_run():
		saved_state = PlayerStorageData.load_saved_run()
		restore_run_state(saved_state)
		PlayerStorageData.clear_saved_run()
	else:
		# No saved run — clean up any run-only weapons that were never removed
		# (e.g. if the player force-quit before the run-end cleanup could run)
		PlayerStorageData.remove_run_weapons()
	_update_labels()
	var upgrade_count := clampi(stage_number - 1, 0, 9)
	var selected_enemy := _select_stage_enemy(upgrade_count)
	deck_manager.assigned_deck = PlayerStorageData.selected_weapon_cards()
	deck_manager.deck_blueprint.clear()
	deck_manager.setup_starting_deck()
	# Restore exact pile distribution if we have a saved run
	if not saved_state.is_empty():
		run_serializer._restore_deck_pile_state(saved_state)
		# _is_animating is true so _on_hand_changed won't auto-refresh the view
		hand_view.set_cards(deck_manager.hand)
	_animator.update_pile_visuals()
	await get_tree().process_frame
	battle_sidebar.set_money(_run_money_earned)
	battle_sidebar.set_enemy_info(selected_enemy)
	if saved_state.is_empty():
		await _refill_hand_or_give_skip()
	_animator.update_pile_visuals()
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


func _play_card(card_data: CardDef, card_view: CardView) -> void:
	_is_animating = true
	hand_view.set_dragging_enabled(false, card_view)
	card_view.set_interaction_enabled(false)
	await _animator.move_player_card_to_slot(card_view)
	if card_data.id.begins_with("origami"):
		await morph_resolver._show_origami_choice_ui(card_data)
	
	
	# Smoothly slide and re-balance remaining cards in hand
	var rem_count := hand_view.card_views.size()
	if rem_count > 0:
		hand_view.prepare_layout(rem_count)
		var slide_tween := create_tween().set_parallel(true)
		for i in range(rem_count):
			var cv := hand_view.card_views[i]
			slide_tween.tween_property(cv, "position", cv.get_rest_position(), 0.3) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			slide_tween.tween_property(cv, "rotation_degrees", cv.base_rotation_degrees, 0.3) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_state.has_disabled_player_type = false
	hand_view.set_disabled_type(false, _state.disabled_player_type)
	if not _pending_enemy_card or not is_instance_valid(_enemy_preview_view):
		await _prepare_enemy_card()
	var enemy_card := _pending_enemy_card
	var enemy_view := _enemy_preview_view
	enemy_card = _apply_luck(card_data, enemy_card, _luck_chance(deck_manager.hand, card_data), false)
	enemy_card = _apply_luck(card_data, enemy_card, _luck_chance(enemy_controller.enemy_hand, null), true)
	_pending_enemy_card = enemy_card
	await _animator.flip_card(enemy_view, enemy_card)
	await morph_resolver.resolve_origami_morphs(card_data, enemy_card, card_view, enemy_view)

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
	morph_resolver.revert_combat_cards(card_data)
	morph_resolver.revert_combat_cards(enemy_card)
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
	battle_board.set_cup_a_joe_status(_state.player_cup_a_joe_pending)
	battle_board.set_poison_status(_state.player_poison_turns, _state.enemy_poison_turns)
	battle_board.set_aegis_status(_state.player_has_aegis, _state.enemy_has_aegis)
	battle_board.set_pocketwatch_status(_state.player_pocketwatch_active)
	var total_trials := RunConfigData.encounter_ids.size()
	if total_trials == 0:
		total_trials = 3
	battle_sidebar.set_progress(stage_number, total_trials, turn_count + 1)


func _end_battle() -> void:
	round_status = "ended"
	hand_view.set_dragging_enabled(false)
	var winner := "Draw"
	if player_hp <= 0 and enemy_hp > 0:
		winner = "Enemy"
	elif enemy_hp <= 0 and player_hp > 0:
		winner = "Player"

	var bonus_text := ""
	if winner == "Player":
		if turn_count <= 10:
			bonus_text = "Instant Kill!"
		elif turn_count <= 15:
			bonus_text = "Speedrun!"
		_award_battle_money()

	battle_ended.emit(winner)
	if winner == "Player":
		if RunConfigData.is_final_stage(stage_number):
			boss_victory.emit(_run_money_earned)
			_is_animating = false
			return
		consumable_shelf.show_level_complete(bonus_text)
		stage_number += 1
		await start_battle()
	else:
		_is_animating = false


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
	battle_sidebar.set_enemy_info(_select_stage_enemy(upgrade_count))
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
	if _state.velvet_gloves_skip_draw:
		_state.velvet_gloves_skip_draw = false
		hand_view.prepare_layout(deck_manager.hand.size())
		hand_view.set_cards(deck_manager.hand)
		_animator.update_pile_visuals()
		return

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


func _select_stage_enemy(upgrade_count: int) -> Dictionary:
	# DEBUG: force every stage to spawn the Hatter Mimic. Remove when done.
	return enemy_controller.select_enemy("cowardly_knight", upgrade_count)
	var enemy_id := RunConfigData.enemy_id_for_stage(stage_number)
	if enemy_id.is_empty():
		return enemy_controller.select_random_non_boss(upgrade_count)
	return enemy_controller.select_enemy(enemy_id, upgrade_count)


func _stock_consumables_from_storage() -> void:
	var selected := PlayerStorageData.selected_consumables()
	var counts := PlayerStorageData.consumable_counts()
	for id in selected:
		if int(counts.get(id, 0)) > 0:
			match id:
				PlayerStorageData.CONSUMABLE_MAGIC_BALL:
					consumable_shelf.add_magic_ball()
				PlayerStorageData.CONSUMABLE_SHIELD:
					consumable_shelf.add_shield()
				PlayerStorageData.CONSUMABLE_REMEDY_KIT:
					consumable_shelf.add_remedy_kit()
				PlayerStorageData.CONSUMABLE_CUP_A_JOE:
					consumable_shelf.add_cup_a_joe()
				PlayerStorageData.CONSUMABLE_MOONLIGHT:
					consumable_shelf.add_moonlight()
				PlayerStorageData.CONSUMABLE_SNAKE_OIL:
					consumable_shelf.add_snake_oil()
				PlayerStorageData.CONSUMABLE_POCKETWATCH:
					consumable_shelf.add_pocketwatch()
				PlayerStorageData.CONSUMABLE_VELVET_GLOVES:
					consumable_shelf.add_velvet_gloves()
				PlayerStorageData.CONSUMABLE_L_IVOIRE:
					consumable_shelf.add_l_ivoire()
				PlayerStorageData.CONSUMABLE_SEALED_MISSIVE:
					consumable_shelf.add_sealed_missive()
				PlayerStorageData.CONSUMABLE_CURIO:
					consumable_shelf.add_curio()

	if OS.is_debug_build():
		pass


func _on_storage_consumable_used(consumable_id: String) -> void:
	PlayerStorageData.consume_consumable(consumable_id)


func _award_battle_money() -> void:
	var is_boss := bool(enemy_controller.current_enemy.get("is_boss", false))
	var amount := 3 if is_boss else 1

	var bonus := 0
	if turn_count <= 10:
		bonus = 2
	elif turn_count <= 15:
		bonus = 1

	var total := amount + bonus
	_run_money_earned += total
	battle_sidebar.set_money(_run_money_earned)
	battle_sidebar.animate_money_gain(total)
	if sfx_manager:
		sfx_manager.play_sfx("coins_falling")
		if bonus > 0:
			sfx_manager.play_sfx("chaching")


func cash_out_run_money() -> int:
	var amount := _run_money_earned
	if amount > 0:
		PlayerStorageData.add_money(amount)
	_run_money_earned = 0
	return amount


func run_money_earned() -> int:
	return _run_money_earned


func get_run_state() -> Dictionary:
	return run_serializer.get_run_state()


func restore_run_state(state: Dictionary) -> void:
	run_serializer.restore_run_state(state)
