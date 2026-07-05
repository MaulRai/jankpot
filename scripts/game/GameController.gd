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
	consumable_shelf.magic_ball_requested.connect(_on_magic_ball_requested)
	consumable_shelf.shield_requested.connect(_on_shield_requested)
	consumable_shelf.remedy_kit_requested.connect(_on_remedy_kit_requested)
	consumable_shelf.cup_a_joe_requested.connect(_on_cup_a_joe_requested)
	consumable_shelf.moonlight_requested.connect(_on_moonlight_requested)
	consumable_shelf.snake_oil_requested.connect(_on_snake_oil_requested)
	consumable_shelf.pocketwatch_requested.connect(_on_pocketwatch_requested)
	consumable_shelf.velvet_gloves_requested.connect(_on_velvet_gloves_requested)
	consumable_shelf.l_ivoire_requested.connect(_on_l_ivoire_requested)
	consumable_shelf.sealed_missive_requested.connect(_on_sealed_missive_requested)
	consumable_shelf.curio_requested.connect(_on_curio_requested)
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
		_restore_deck_pile_state(saved_state)
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
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_MAGIC_BALL)
	magic_ball_modal.show_prediction(prediction)


func _on_shield_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	_state.player_shield += 1
	consumable_shelf.consume_shield()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_SHIELD)
	_update_labels()


func _on_remedy_kit_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	if not _state.player_bleed_pending and _state.player_poison_turns <= 0:
		return
	_state.player_bleed_pending = false
	_state.player_poison_turns = 0
	consumable_shelf.consume_remedy_kit()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_REMEDY_KIT)
	_update_labels()


func _on_cup_a_joe_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	_state.player_cup_a_joe_pending = true
	sfx_manager.play_sfx("power_up")
	consumable_shelf.consume_cup_a_joe()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_CUP_A_JOE)
	_update_labels()


func _on_moonlight_requested() -> void:
	if _is_animating:
		return
	# Moonlight costs $2 from the run wallet
	if _run_money_earned < 2:
		sfx_manager.play_sfx("buzzer")
		return
	_is_animating = true

	_run_money_earned -= 2
	battle_sidebar.set_money(_run_money_earned)
	consumable_shelf.consume_moonlight()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_MOONLIGHT)

	# Create PickMode on the scene root so it spans the full viewport
	if not _pick_mode:
		_pick_mode = PickMode.new()
		get_parent().add_child(_pick_mode)

	hand_view.set_dragging_enabled(false)
	_pick_mode.start(hand_view, 2, _on_moonlight_discard_chosen)
	sfx_manager.play_sfx("card_pickup")


func _on_moonlight_discard_chosen(selected_views: Array[CardView]) -> void:
	# Animate selected cards flying off screen, then draw replacements.
	var discard_count := selected_views.size()

	for card_view in selected_views:
		if not is_instance_valid(card_view) or not card_view.card_data:
			discard_count -= 1
			continue
		var card_data: CardDef = card_view.card_data
		# Kill any active selection/hover tweens before changing parent coordinate space
		card_view.cancel_transform_tween()
		# Re-parent to scene root so exit animation renders above everything
		card_view.reparent(get_parent(), true)
		card_view.z_index = 1200
		hand_view.remove_card_view(card_view)
		# Move card data to discard pile
		deck_manager.play_card(card_data.id)
		# Clean upward move and fade out
		var exit_tween := card_view.create_tween().set_parallel(true)
		exit_tween.tween_property(card_view, "global_position",
			card_view.global_position + Vector2(0.0, -100.0), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		exit_tween.tween_property(card_view, "modulate:a", 0.0, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		exit_tween.chain().tween_callback(card_view.queue_free)

	_animator.play_sfx("card_leave", -2.0, randf_range(0.97, 1.03))
	# Brief pause to let the exit animations start before sliding
	await get_tree().create_timer(0.15).timeout

	# Slide remaining cards to their final slot positions (leftmost) of the target hand layout
	var current_count := hand_view.card_views.size()
	var target_count := current_count + discard_count
	if current_count > 0:
		var slide_tween := get_tree().create_tween().set_parallel(true)
		for index in range(current_count):
			var cv := hand_view.card_views[index]
			# Position remaining cards starting at index 0 in the final layout
			cv.base_position = hand_view._get_card_base_position(index, target_count)
			var center_index: float = (target_count - 1) / 2.0
			var offset := index - center_index
			cv.base_rotation_degrees = offset * 3.0
			cv.base_z_index = index
			
			slide_tween.tween_property(cv, "position", cv.base_position, 0.22) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			slide_tween.tween_property(cv, "rotation_degrees", cv.base_rotation_degrees, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await slide_tween.finished

	# Draw the same number of replacement cards with animated refill
	deck_manager.draw_until_full(target_count)
	hand_view.prepare_layout(deck_manager.hand.size())
	for index in range(current_count, deck_manager.hand.size()):
		var sig: Signal = _animator._animate_card_draw(
			deck_manager.hand[index], index, deck_manager.hand.size(), 0.0
		)
		await sig

	for cv: CardView in hand_view.card_views:
		cv.set_interaction_enabled(true)
	hand_view.normalize_card_layers()
	_animator.update_pile_visuals()
	hand_view.set_dragging_enabled(true)
	_update_labels()
	_is_animating = false


func _on_snake_oil_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	_is_animating = true

	var poison_amount := 1
	if _check_double_loss_history():
		poison_amount = 2

	consumable_shelf.consume_snake_oil()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_SNAKE_OIL)

	sfx_manager.play_sfx("poison")

	var enemy_card_view := enemy_slot.get_child(0) as CardView
	if is_instance_valid(enemy_card_view):
		_animator.show_exclamation(
			enemy_card_view,
			"Poisoned!",
			Color(EffectKeywordData.get_color("Poison"))
		)

	_state.enemy_poison_turns += poison_amount
	_update_labels()

	var shake_target: Control = enemy_card_view if is_instance_valid(enemy_card_view) else enemy_slot
	await _animator.shake(shake_target)
	_is_animating = false


func _on_pocketwatch_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	if _state.player_pocketwatch_active:
		return
	_is_animating = true
	_state.player_pocketwatch_active = true
	consumable_shelf.consume_pocketwatch()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_POCKETWATCH)
	
	sfx_manager.play_sfx("pocketwatch")
	
	var player_card_view := player_slot.get_child(0) as CardView if player_slot.get_child_count() > 0 else null
	if is_instance_valid(player_card_view):
		_animator.show_exclamation(
			player_card_view,
			"Pocketwatch!",
			Color(EffectKeywordData.get_color("Pocketwatch"))
		)
	_update_labels()
	var shake_target: Control = player_card_view if is_instance_valid(player_card_view) else player_slot
	await _animator.shake(shake_target)
	_is_animating = false


func _on_velvet_gloves_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return

	if deck_manager.draw_pile.is_empty():
		sfx_manager.play_sfx("buzzer")
		var player_card_view := player_slot.get_child(0) as CardView if player_slot.get_child_count() > 0 else null
		var warn_target: Control = player_card_view if is_instance_valid(player_card_view) else player_slot
		_animator.show_exclamation(warn_target, "Empty Draw Pile!", Color("#FF5555"))
		return

	_is_animating = true
	hand_view.set_dragging_enabled(false)
	sfx_manager.play_sfx("click")

	var main_root = get_parent()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# 1. Dim Backdrop Rect
	var dim := ColorRect.new()
	dim.name = "VelvetGlovesDim"
	dim.color = Color(0.004, 0.007, 0.008, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 1100
	dim.z_as_relative = false
	main_root.add_child(dim)

	# 2. Window Panel (panel-window-alt)
	var window := TextureRect.new()
	window.name = "VelvetGlovesWindow"
	window.texture = load("res://assets/ui/panel-window-alt.png")
	window.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window.stretch_mode = TextureRect.STRETCH_SCALE
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.custom_minimum_size = Vector2(800, 540)
	window.size = Vector2(800, 540)
	window.pivot_offset = window.size * 0.5
	window.position = Vector2(
		(viewport_size.x - 800) * 0.5,
		viewport_size.y + 40
	)
	window.z_index = 1101
	window.z_as_relative = false
	main_root.add_child(window)

	# 3. Content Layout
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 40
	content.offset_top = 64
	content.offset_right = -40
	content.offset_bottom = -40
	window.add_child(content)

	# Heading Label
	var heading := Label.new()
	heading.text = "CHERRY PICK A CARD"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", STAR_CRUSH_FONT)
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1.0))
	heading.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	heading.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(heading)

	# Scroll Container
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 240)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 14)
	card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_row)

	# Create the SELECT and CANCEL buttons first so they are immediately accessible in the closures
	var select_btn_frame = _make_gloves_button("SELECT")
	var select_btn := select_btn_frame.get_child(0) as Button
	select_btn.disabled = true
	select_btn_frame.set("base_tint", Color(0.16, 0.14, 0.12, 1.0))
	select_btn_frame.set("frame_outline_tint", Color(0.3, 0.28, 0.24, 1.0))
	select_btn_frame.set("base_outline_tint", Color(0.18, 0.16, 0.14, 1.0))
	select_btn_frame.set("base_fill_tint", Color(0.08, 0.07, 0.06, 1.0))
	if select_btn_frame.has_method("_rebuild_palette_textures"):
		select_btn_frame.call("_rebuild_palette_textures")
	if select_btn_frame.has_method("queue_redraw"):
		select_btn_frame.queue_redraw()

	var cancel_btn_frame = _make_gloves_button("CANCEL")
	var cancel_btn := cancel_btn_frame.get_child(0) as Button

	# Shared state dictionary for mutually exclusive card selection
	var state_data := {
		"selected_card": null,
		"selected_highlight": null
	}

	for card_data in deck_manager.draw_pile:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(160, 230)
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		card_row.add_child(wrapper)

		var highlight := TextureRect.new()
		highlight.texture = SELECTED_CARD_BASE_TEXTURE
		highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		highlight.stretch_mode = TextureRect.STRETCH_SCALE
		highlight.size = Vector2(160, 230)
		highlight.position = Vector2.ZERO
		highlight.pivot_offset = highlight.size * 0.5
		highlight.modulate = Color(0.35, 0.72, 1.0, 0.56)
		highlight.visible = false
		wrapper.add_child(highlight)

		var card_view := CARD_SCENE.instantiate() as Control
		card_view.set("card_data", card_data)
		card_view.set("interaction_enabled", false)
		card_view.scale = Vector2(0.9, 0.9)
		card_view.position = wrapper.custom_minimum_size * 0.5 - card_view.pivot_offset
		wrapper.add_child(card_view)

		var name_lbl = card_view.get_node_or_null("%NameLabel")
		if name_lbl:
			name_lbl.add_theme_font_override("font", STAR_CRUSH_FONT)
			name_lbl.add_theme_font_size_override("font_size", 16)
		var desc_lbl = card_view.get_node_or_null("%DescriptionLabel")
		if desc_lbl:
			desc_lbl.add_theme_font_override("normal_font", STAR_CRUSH_FONT)
			desc_lbl.add_theme_font_size_override("normal_font_size", 12)

		var overlay_btn := Button.new()
		overlay_btn.flat = true
		overlay_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrapper.add_child(overlay_btn)

		overlay_btn.pressed.connect(func() -> void:
			sfx_manager.play_sfx("click")
			if state_data.selected_highlight:
				state_data.selected_highlight.visible = false
			state_data.selected_card = card_data
			state_data.selected_highlight = highlight
			highlight.visible = true
			
			select_btn.disabled = false
			select_btn_frame.set("base_tint", Color(0.26, 0.12, 0.2, 1.0))
			select_btn_frame.set("frame_outline_tint", Color(1.0, 0.86, 0.42, 1.0))
			select_btn_frame.set("base_outline_tint", Color(0.26, 0.12, 0.2, 1.0))
			select_btn_frame.set("base_fill_tint", Color(0.12, 0.07, 0.12, 1.0))
			if select_btn_frame.has_method("_rebuild_palette_textures"):
				select_btn_frame.call("_rebuild_palette_textures")
			if select_btn_frame.has_method("queue_redraw"):
				select_btn_frame.queue_redraw()
		)

	# Button row at bottom
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	content.add_child(btn_row)
	btn_row.add_child(select_btn_frame)
	btn_row.add_child(cancel_btn_frame)

	var target_y := (viewport_size.y - 540) * 0.5
	var slide_in := create_tween().set_parallel(true)
	slide_in.tween_property(window, "position:y", target_y, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_in.tween_property(dim, "modulate:a", 1.0, 0.25)

	select_btn.pressed.connect(func() -> void:
		var target_card_data = state_data.selected_card
		if not target_card_data:
			return
		sfx_manager.play_sfx("card_pickup")
		var slide_out := create_tween().set_parallel(true)
		slide_out.tween_property(window, "position:y", viewport_size.y + 40, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		slide_out.tween_property(dim, "modulate:a", 0.0, 0.25)
		await slide_out.finished
		dim.queue_free()
		window.queue_free()

		consumable_shelf.consume_velvet_gloves()
		_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_VELVET_GLOVES)
		_state.velvet_gloves_skip_draw = true

		deck_manager.draw_pile.erase(target_card_data)
		deck_manager.hand.append(target_card_data)
		deck_manager.draw_pile_changed.emit()

		hand_view.prepare_layout(deck_manager.hand.size())

		var rearrange_tween := create_tween().set_parallel(true)
		for cv in hand_view.card_views:
			cv.set_interaction_enabled(false)
			rearrange_tween.tween_property(cv, "position", cv.get_rest_position(), 0.38) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			rearrange_tween.tween_property(cv, "rotation_degrees", cv.base_rotation_degrees, 0.38) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		var sig = _animator._animate_card_draw(target_card_data, deck_manager.hand.size() - 1, deck_manager.hand.size(), 0.0)
		await rearrange_tween.finished
		await sig

		for cv in hand_view.card_views:
			cv.set_interaction_enabled(true)
		hand_view.set_dragging_enabled(true)
		_is_animating = false
		_update_labels()
	)

	cancel_btn.pressed.connect(func() -> void:
		sfx_manager.play_sfx("click")
		var slide_out := create_tween().set_parallel(true)
		slide_out.tween_property(window, "position:y", viewport_size.y + 40, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		slide_out.tween_property(dim, "modulate:a", 0.0, 0.25)
		await slide_out.finished
		dim.queue_free()
		window.queue_free()
		hand_view.set_dragging_enabled(true)
		_is_animating = false
	)


func _on_l_ivoire_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	var rare_card := _get_random_rare_card_for_type(CardDef.CardType.SCISSORS)
	consumable_shelf.consume_l_ivoire()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_L_IVOIRE)
	await _animate_add_rare_card(rare_card, "arcane_general_1")


func _on_sealed_missive_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	var rare_card := _get_random_rare_card_for_type(CardDef.CardType.PAPER)
	consumable_shelf.consume_sealed_missive()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_SEALED_MISSIVE)
	await _animate_add_rare_card(rare_card, "paper_general")


func _on_curio_requested() -> void:
	if round_status != "ongoing" or _is_animating:
		return
	var rare_card := _get_random_rare_card_for_type(CardDef.CardType.ROCK)
	consumable_shelf.consume_curio()
	_on_storage_consumable_used(PlayerStorageData.CONSUMABLE_CURIO)
	await _animate_add_rare_card(rare_card, "arcane_general_2")


func _get_random_rare_card_for_type(type: CardDef.CardType) -> CardDef:
	var rares: Array[String] = []
	for weapon_id in WeaponCatalogData._all_upgrade_ids():
		var card := WeaponCatalogData.create_weapon(weapon_id)
		if card.card_type == type and card.rarity == WeaponCatalogData.RARITY_RARE:
			rares.append(weapon_id)
	if rares.is_empty():
		match type:
			CardDef.CardType.ROCK: rares.append("ruby")
			CardDef.CardType.PAPER: rares.append("hatter_slip")
			CardDef.CardType.SCISSORS: rares.append("guillotine_blades")
	var chosen_id: String = rares.pick_random()
	# Keep the clean catalog ID — the runtime _assigned_ suffix added by
	# _initialize_blueprint is enough for uniqueness in the draw pile.
	return WeaponCatalogData.create_weapon(chosen_id)


func _animate_add_rare_card(rare_card: CardDef, initial_sfx: String) -> void:
	_is_animating = true
	hand_view.set_dragging_enabled(false)
	sfx_manager.play_sfx(initial_sfx)

	var main_root := get_parent()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	var dim := ColorRect.new()
	dim.color = Color(0.004, 0.007, 0.008, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 1200
	dim.z_as_relative = false
	dim.modulate.a = 0.0
	main_root.add_child(dim)

	var card_view := CARD_SCENE.instantiate() as Control
	card_view.set("card_data", rare_card)
	card_view.set("interaction_enabled", false)
	card_view.scale = Vector2.ZERO
	card_view.modulate.a = 0.0
	card_view.z_index = 1201
	card_view.z_as_relative = false
	main_root.add_child(card_view)

	var card_width: float = 160.0
	var card_height: float = 240.0
	card_view.position = (viewport_size - Vector2(card_width, card_height)) * 0.5

	var name_lbl = card_view.get_node_or_null("%NameLabel")
	if name_lbl:
		name_lbl.add_theme_font_override("font", STAR_CRUSH_FONT)
		name_lbl.add_theme_font_size_override("font_size", 16)
	var desc_lbl = card_view.get_node_or_null("%DescriptionLabel")
	if desc_lbl:
		desc_lbl.add_theme_font_override("normal_font", STAR_CRUSH_FONT)
		desc_lbl.add_theme_font_size_override("normal_font_size", 12)

	var tween_in := create_tween().set_parallel(true)
	tween_in.tween_property(dim, "modulate:a", 1.0, 0.3)
	tween_in.tween_property(card_view, "scale", Vector2.ONE, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(card_view, "modulate:a", 1.0, 0.3)
	await tween_in.finished

	await get_tree().create_timer(1.4).timeout

	var flip_half := create_tween()
	flip_half.tween_property(card_view, "scale:x", 0.06, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await flip_half.finished
	
	if card_view.has_method("set_face_down"):
		card_view.call("set_face_down", true)
	
	var flip_done := create_tween()
	flip_done.tween_property(card_view, "scale:x", 1.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await flip_done.finished

	var dest_pos: Vector2 = _animator.pile_card_top.global_position - Vector2(card_width * 0.25, card_height * 0.25)

	# Drop below the DrawPileVisual (z_index=20) so the card slides *behind* the pile
	card_view.z_index = 19
	card_view.z_as_relative = false

	var fly_tween := create_tween().set_parallel(true)
	fly_tween.tween_property(card_view, "global_position", dest_pos, 0.55)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly_tween.tween_property(card_view, "scale", Vector2(0.5, 0.5), 0.55)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly_tween.tween_property(card_view, "rotation_degrees", randf_range(-12.0, 12.0), 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly_tween.tween_property(dim, "modulate:a", 0.0, 0.55)
	# Fade card out over the last 0.2s of the flight (starts at t=0.35s)
	var fade_tween := create_tween()
	fade_tween.tween_interval(0.35)
	fade_tween.tween_property(card_view, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fly_tween.finished

	sfx_manager.play_sfx("card_placed")
	
	var rand_idx := randi_range(0, deck_manager.draw_pile.size())
	deck_manager.draw_pile.insert(rand_idx, rare_card)
	deck_manager.draw_pile_changed.emit()
	_animator.update_pile_visuals()

	PlayerStorageData.add_weapon_and_select(rare_card)

	dim.queue_free()
	card_view.queue_free()
	
	hand_view.set_dragging_enabled(true)
	_is_animating = false
	_update_labels()


func _make_gloves_button(label: String) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(160, 52)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var empty_style := StyleBoxEmpty.new()
	frame.add_theme_stylebox_override("panel", empty_style)
	frame.set_script(PIXEL_FRAME_SCRIPT)
	frame.set("base_tint", Color(0.12, 0.07, 0.12, 1))
	frame.set("frame_outline_tint", Color(1, 0.86, 0.42, 1))
	frame.set("base_outline_tint", Color(0.26, 0.12, 0.2, 1))
	frame.set("base_fill_tint", Color(0.12, 0.07, 0.12, 1))
	frame.set("component_scale", 1.0)
	frame.set("top_right_corner_variant", 1)
	frame.pivot_offset = frame.custom_minimum_size * 0.5

	var button := Button.new()
	button.text = label
	button.flat = true
	button.add_theme_font_override("font", STAR_CRUSH_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.82, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 0.68, 0.3, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.38, 0.35, 1.0))
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	frame.add_child(button)

	button.mouse_entered.connect(func() -> void:
		var tween := create_tween()
		tween.tween_property(frame, "scale", Vector2(1.06, 1.06), 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	button.mouse_exited.connect(func() -> void:
		var tween := create_tween()
		tween.tween_property(frame, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	return frame


func _check_double_loss_history() -> bool:
	var player_history := battle_sidebar._player_history_cards
	var enemy_history := battle_sidebar._enemy_history_cards
	var size := player_history.size()
	if size < 2:
		return false

	var last_result := BattleResolver.resolve_cards(player_history[size - 1], enemy_history[size - 1])
	var prev_result := BattleResolver.resolve_cards(player_history[size - 2], enemy_history[size - 2])
	return last_result == BattleResolver.Result.LOSE and prev_result == BattleResolver.Result.LOSE


func _play_card(card_data: CardDef, card_view: CardView) -> void:
	_is_animating = true
	hand_view.set_dragging_enabled(false, card_view)
	card_view.set_interaction_enabled(false)
	await _animator.move_player_card_to_slot(card_view)
	if card_data.id.begins_with("origami"):
		await _show_origami_choice_ui(card_data)
	
	
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
	await _resolve_origami_morphs(card_data, enemy_card, card_view, enemy_view)

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
	_revert_origami(card_data)
	_revert_origami(enemy_card)
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
	return {
		"stage_number": stage_number,
		"player_hp": player_hp,
		"enemy_hp": enemy_hp,
		"run_money_earned": _run_money_earned,
		"selected_stage_id": RunConfigData.selected_stage_id,
		"selected_boss_id": RunConfigData.selected_boss_id,
		"encounter_ids": RunConfigData.encounter_ids,
		"player_history": _serialize_card_history(battle_sidebar._player_history_cards),
		"enemy_history": _serialize_card_history(battle_sidebar._enemy_history_cards),
		"history_turns": battle_sidebar._history_turns,
		"history_turn": battle_sidebar._history_turn,
		"active_consumables": consumable_shelf.get_active_items(),
		"draw_pile": _serialize_card_history(deck_manager.draw_pile),
		"discard_pile": _serialize_card_history(deck_manager.discard_pile),
		"hand_pile": _serialize_card_history(deck_manager.hand),
	}


func restore_run_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	stage_number = maxi(1, int(state.get("stage_number", 1)))
	_run_money_earned = maxi(0, int(state.get("run_money_earned", 0)))
	var restored_hp := int(state.get("player_hp", _state.player_hp))
	if restored_hp > 0:
		player_hp = restored_hp
	var restored_enemy_hp := int(state.get("enemy_hp", _state.enemy_hp))
	if restored_enemy_hp > 0:
		enemy_hp = restored_enemy_hp

	if state.has("selected_stage_id"):
		RunConfigData.selected_stage_id = str(state.get("selected_stage_id"))
	if state.has("selected_boss_id"):
		RunConfigData.selected_boss_id = str(state.get("selected_boss_id"))
	if state.has("encounter_ids"):
		var raw_ids = state.get("encounter_ids", [])
		if typeof(raw_ids) == TYPE_ARRAY:
			RunConfigData.encounter_ids.clear()
			for id in raw_ids:
				RunConfigData.encounter_ids.append(str(id))

	if state.has("player_history") and state.has("enemy_history") and state.has("history_turns") and state.has("history_turn"):
		var p_history = _deserialize_card_history(state.get("player_history", []))
		var e_history = _deserialize_card_history(state.get("enemy_history", []))
		var turns: Array[int] = []
		for t in state.get("history_turns", []):
			turns.append(int(t))
		var turn_num = int(state.get("history_turn", 0))
		battle_sidebar.restore_history(p_history, e_history, turns, turn_num)

	if state.has("active_consumables"):
		var items = state.get("active_consumables", [])
		if typeof(items) == TYPE_ARRAY:
			consumable_shelf.restore_shelf(items)


# Returns the clean catalog ID for a card, stripping all runtime suffixes.
# This MUST match the logic in _serialize_card_history for pile keys to align.
func _get_card_base_id(card: CardDef) -> String:
	if not card:
		return ""
	if card.is_skip:
		return "skip"
	if card.is_basic:
		match card.card_type:
			CardDef.CardType.ROCK: return "basic_rock"
			CardDef.CardType.PAPER: return "basic_paper"
			CardDef.CardType.SCISSORS: return "basic_scissors"
		return ""
	var clean := card.id
	for suffix in ["_storage_", "_selected_", "_assigned_", "_player_"]:
		var parts := clean.split(suffix)
		if parts.size() > 1:
			clean = parts[0]
			break
	return clean


func _restore_deck_pile_state(state: Dictionary) -> void:
	if not (state.has("draw_pile") or state.has("discard_pile") or state.has("hand_pile")):
		return
	var raw_draw = state.get("draw_pile", [])
	var raw_discard = state.get("discard_pile", [])
	var raw_hand = state.get("hand_pile", [])
	if typeof(raw_draw) != TYPE_ARRAY and typeof(raw_discard) != TYPE_ARRAY and typeof(raw_hand) != TYPE_ARRAY:
		return
	# Build a pool keyed by clean catalog ID from the cards setup_starting_deck created.
	# Using _get_card_base_id() guarantees the key matches what _serialize_card_history wrote.
	var all_cards := deck_manager.get_all_battle_cards()
	var card_pool: Dictionary = {}
	for card in all_cards:
		var key := _get_card_base_id(card)
		if key.is_empty():
			continue
		if key not in card_pool:
			card_pool[key] = []
		card_pool[key].append(card)

	var new_draw: Array[CardDef] = []
	var new_discard: Array[CardDef] = []
	var new_hand: Array[CardDef] = []

	for raw_id in raw_draw:
		var card := _pop_from_pool(card_pool, str(raw_id))
		if card:
			new_draw.append(card)
	for raw_id in raw_discard:
		var card := _pop_from_pool(card_pool, str(raw_id))
		if card:
			new_discard.append(card)
	for raw_id in raw_hand:
		var card := _pop_from_pool(card_pool, str(raw_id))
		if card:
			new_hand.append(card)

	# Leftover cards (shouldn't happen on a clean save) go into draw pile
	for pool_list in card_pool.values():
		for leftover in pool_list:
			new_draw.append(leftover)

	deck_manager.draw_pile.clear()
	deck_manager.hand.clear()
	deck_manager.discard_pile.clear()
	deck_manager.draw_pile.assign(new_draw)
	deck_manager.hand.assign(new_hand)
	deck_manager.discard_pile.assign(new_discard)
	deck_manager.draw_pile_changed.emit()
	deck_manager.hand_changed.emit()
	deck_manager.discard_pile_changed.emit()


func _pop_from_pool(pool: Dictionary, base_id: String) -> CardDef:
	if base_id in pool and not pool[base_id].is_empty():
		return pool[base_id].pop_back()
	return null


func _serialize_card_history(cards: Array[CardDef]) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		result.append(_get_card_base_id(card))
	return result


func _deserialize_card_history(ids: Array) -> Array[CardDef]:
	var result: Array[CardDef] = []
	for raw_id in ids:
		var id := str(raw_id)
		if id.is_empty():
			result.append(null)
		elif id == "skip":
			result.append(WeaponCatalogData.create_skip())
		elif id == "basic_rock":
			result.append(WeaponCatalogData.create_basic(CardDef.CardType.ROCK))
		elif id == "basic_paper":
			result.append(WeaponCatalogData.create_basic(CardDef.CardType.PAPER))
		elif id == "basic_scissors":
			result.append(WeaponCatalogData.create_basic(CardDef.CardType.SCISSORS))
		else:
			result.append(WeaponCatalogData.create_weapon(id))
	return result


func _show_origami_choice_ui(card_data: CardDef) -> void:
	var main_root = get_parent()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# 1. Dim Backdrop
	var dim := ColorRect.new()
	dim.name = "OrigamiDim"
	dim.color = Color(0.004, 0.007, 0.008, 0.0) # Start fully transparent
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 1100
	dim.z_as_relative = false
	main_root.add_child(dim)

	# 2. Window Panel (panel-window-alt)
	var window := TextureRect.new()
	window.name = "OrigamiWindow"
	window.texture = load("res://assets/ui/panel-window-alt.png")
	window.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window.stretch_mode = TextureRect.STRETCH_SCALE
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.custom_minimum_size = Vector2(500, 360)
	window.size = Vector2(500, 360)
	window.pivot_offset = window.size * 0.5
	window.position = Vector2(
		(viewport_size.x - 500) * 0.5,
		viewport_size.y + 40
	)
	window.z_index = 1101
	window.z_as_relative = false
	main_root.add_child(window)

	# 3. Content VBox
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 30
	content.offset_top = 40
	content.offset_right = -30
	content.offset_bottom = -30
	window.add_child(content)

	# Title
	var title := Label.new()
	title.text = "CHOOSE MORPH TARGET"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", STAR_CRUSH_FONT)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.64, 1.0))
	content.add_child(title)

	# HBox for options
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	content.add_child(hbox)

	var choices := [
		WeaponCatalogData.create_basic(CardDef.CardType.ROCK),
		WeaponCatalogData.create_basic(CardDef.CardType.SCISSORS)
	]

	var choice_container := []

	for option_data in choices:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(160, 230)
		hbox.add_child(wrapper)

		var card_view := CARD_SCENE.instantiate() as Control
		card_view.set("card_data", option_data)
		card_view.set("interaction_enabled", false)
		card_view.scale = Vector2(0.9, 0.9)
		card_view.position = wrapper.custom_minimum_size * 0.5 - card_view.pivot_offset
		wrapper.add_child(card_view)

		var name_lbl = card_view.get_node_or_null("%NameLabel")
		if name_lbl:
			name_lbl.add_theme_font_override("font", STAR_CRUSH_FONT)
			name_lbl.add_theme_font_size_override("font_size", 16)
		var desc_lbl = card_view.get_node_or_null("%DescriptionLabel")
		if desc_lbl:
			desc_lbl.add_theme_font_override("normal_font", STAR_CRUSH_FONT)
			desc_lbl.add_theme_font_size_override("normal_font_size", 12)

		var overlay_btn := Button.new()
		overlay_btn.flat = true
		overlay_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrapper.add_child(overlay_btn)

		var current_dim = dim
		var current_window = window
		overlay_btn.pressed.connect(func() -> void:
			sfx_manager.play_sfx("click")
			choice_container.append(option_data.card_type)
			
			var slide_out := create_tween().set_parallel(true)
			slide_out.tween_property(current_window, "position:y", viewport_size.y + 40, 0.25) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			slide_out.tween_property(current_dim, "modulate:a", 0.0, 0.2)
			await slide_out.finished
			current_window.queue_free()
			current_dim.queue_free()
		)

	# Slide in
	var target_y := (viewport_size.y - 360) * 0.5
	var slide_in := create_tween().set_parallel(true)
	slide_in.tween_property(window, "position:y", target_y, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_in.tween_property(dim, "modulate:a", 1.0, 0.2)

	# Wait until choice is selected and added to choice_container
	while choice_container.is_empty():
		await get_tree().process_frame

	card_data.set_meta("origami_choice", choice_container[0])


func _get_clash_value(my_type: CardDef.CardType, opp_type: CardDef.CardType) -> int:
	if my_type == opp_type:
		return 0
	match my_type:
		CardDef.CardType.ROCK:
			return 1 if opp_type == CardDef.CardType.SCISSORS else -1
		CardDef.CardType.PAPER:
			return 1 if opp_type == CardDef.CardType.ROCK else -1
		CardDef.CardType.SCISSORS:
			return 1 if opp_type == CardDef.CardType.PAPER else -1
	return -1


func _morph_card_to_basic(card: CardDef, type: CardDef.CardType) -> void:
	var basic := WeaponCatalogData.create_basic(type, card.id)
	card.card_type = basic.card_type
	card.card_name = basic.card_name
	card.brief_description = basic.brief_description
	card.art_path = basic.art_path
	card.background_color = basic.background_color
	card.keywords = basic.keywords
	card.effects = basic.effects
	card.is_basic = basic.is_basic


func _resolve_origami_morphs(player_card: CardDef, enemy_card: CardDef, player_view: CardView, enemy_view: CardView) -> void:
	var p_morphed := false
	var e_morphed := false

	# 1. Player check against enemy base
	if player_card.id.begins_with("origami") and player_card.has_meta("origami_choice"):
		var p_choice: CardDef.CardType = player_card.get_meta("origami_choice")
		if _get_clash_value(p_choice, enemy_card.card_type) > _get_clash_value(player_card.card_type, enemy_card.card_type):
			_morph_card_to_basic(player_card, p_choice)
			p_morphed = true

	# 2. Enemy check against player base (either original paper or already morphed player card)
	if enemy_card.id.begins_with("origami") and enemy_card.has_meta("origami_choice"):
		var e_choice: CardDef.CardType = enemy_card.get_meta("origami_choice")
		if _get_clash_value(e_choice, player_card.card_type) > _get_clash_value(enemy_card.card_type, player_card.card_type):
			_morph_card_to_basic(enemy_card, e_choice)
			e_morphed = true

	# 3. Double-check player in case enemy morphed changed the outcome
	if e_morphed and player_card.id.begins_with("origami") and player_card.has_meta("origami_choice") and not p_morphed:
		var p_choice: CardDef.CardType = player_card.get_meta("origami_choice")
		if _get_clash_value(p_choice, enemy_card.card_type) > _get_clash_value(player_card.card_type, enemy_card.card_type):
			_morph_card_to_basic(player_card, p_choice)
			p_morphed = true

	# 4. Double-check enemy in case player morphed changed the outcome
	if p_morphed and enemy_card.id.begins_with("origami") and enemy_card.has_meta("origami_choice") and not e_morphed:
		var e_choice: CardDef.CardType = enemy_card.get_meta("origami_choice")
		if _get_clash_value(e_choice, player_card.card_type) > _get_clash_value(enemy_card.card_type, player_card.card_type):
			_morph_card_to_basic(enemy_card, e_choice)
			e_morphed = true

	if p_morphed or e_morphed:
		sfx_manager.play_sfx("morph")
		if p_morphed and is_instance_valid(player_view):
			player_view.set_card_data(player_card)
			_animator.show_exclamation(player_view, "Morphed!", Color("#FFD166"))
		if e_morphed and is_instance_valid(enemy_view):
			enemy_view.set_card_data(enemy_card)
			_animator.show_exclamation(enemy_view, "Morphed!", Color("#FFD166"))
		await get_tree().create_timer(0.4).timeout


func _revert_origami(card: CardDef) -> void:
	if card and card.id.begins_with("origami"):
		var origami := WeaponCatalogData.create_weapon("origami")
		card.card_type = origami.card_type
		card.card_name = origami.card_name
		card.brief_description = origami.brief_description
		card.art_path = origami.art_path
		card.background_color = origami.background_color
		card.keywords = origami.keywords.duplicate()
		card.effects = origami.effects.duplicate()
		card.is_basic = origami.is_basic
		if card.has_meta("origami_choice"):
			card.remove_meta("origami_choice")
