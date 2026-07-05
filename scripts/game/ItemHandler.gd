class_name ItemHandler
extends RefCounted

const PlayerStorageData = preload("res://scripts/data/PlayerStorage.gd")
const EffectKeywordData = preload("res://scripts/data/EffectKeyword.gd")
const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")
const PIXEL_FRAME_SCRIPT := preload("res://scripts/ui/PixelFramePanel.gd")
const STAR_CRUSH_FONT := preload("res://fonts/Star Crush.otf")
const SELECTED_CARD_BASE_TEXTURE := preload("res://assets/ui/card-base.png")
const CARD_SCENE := preload("res://scenes/ui/CardView.tscn")

var controller: Node

func configure(p_controller: Node) -> void:
	controller = p_controller


func use_item(item_id: String) -> void:
	match item_id:
		PlayerStorageData.CONSUMABLE_MAGIC_BALL:
			_on_magic_ball_requested()
		PlayerStorageData.CONSUMABLE_SHIELD:
			_on_shield_requested()
		PlayerStorageData.CONSUMABLE_REMEDY_KIT:
			_on_remedy_kit_requested()
		PlayerStorageData.CONSUMABLE_CUP_A_JOE:
			_on_cup_a_joe_requested()
		PlayerStorageData.CONSUMABLE_MOONLIGHT:
			_on_moonlight_requested()
		PlayerStorageData.CONSUMABLE_SNAKE_OIL:
			_on_snake_oil_requested()
		PlayerStorageData.CONSUMABLE_POCKETWATCH:
			_on_pocketwatch_requested()
		PlayerStorageData.CONSUMABLE_VELVET_GLOVES:
			_on_velvet_gloves_requested()
		PlayerStorageData.CONSUMABLE_L_IVOIRE:
			_on_l_ivoire_requested()
		PlayerStorageData.CONSUMABLE_SEALED_MISSIVE:
			_on_sealed_missive_requested()
		PlayerStorageData.CONSUMABLE_CURIO:
			_on_curio_requested()


func _on_magic_ball_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating or not controller._pending_enemy_card:
		return
	var prediction = controller._pending_enemy_card.card_type
	if randf() >= 0.8:
		var wrong_types: Array[int] = [
			CardDef.CardType.ROCK, CardDef.CardType.PAPER, CardDef.CardType.SCISSORS,
		]
		wrong_types.erase(prediction)
		prediction = wrong_types.pick_random() as CardDef.CardType
	controller.consumable_shelf.consume_magic_ball()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_MAGIC_BALL)
	controller.magic_ball_modal.show_prediction(prediction)


func _on_shield_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return
	controller._state.player_shield += 1
	controller.consumable_shelf.consume_shield()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_SHIELD)
	controller._update_labels()


func _on_remedy_kit_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return
	if not controller._state.player_bleed_pending and controller._state.player_poison_turns <= 0:
		return
	controller._state.player_bleed_pending = false
	controller._state.player_poison_turns = 0
	controller.consumable_shelf.consume_remedy_kit()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_REMEDY_KIT)
	controller._update_labels()


func _on_cup_a_joe_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return
	controller._state.player_cup_a_joe_pending = true
	controller.sfx_manager.play_sfx("power_up")
	controller.consumable_shelf.consume_cup_a_joe()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_CUP_A_JOE)
	controller._update_labels()


func _on_moonlight_requested() -> void:
	if controller._is_animating:
		return
	if controller._run_money_earned < 2:
		controller.sfx_manager.play_sfx("buzzer")
		return
	controller._is_animating = true

	controller._run_money_earned -= 2
	controller.battle_sidebar.set_money(controller._run_money_earned)
	controller.consumable_shelf.consume_moonlight()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_MOONLIGHT)

	if not controller._pick_mode:
		controller._pick_mode = PickMode.new()
		controller.get_parent().add_child(controller._pick_mode)

	controller.hand_view.set_dragging_enabled(false)
	controller._pick_mode.start(controller.hand_view, 2, _on_moonlight_discard_chosen)
	controller.sfx_manager.play_sfx("card_pickup")


func _on_moonlight_discard_chosen(selected_views: Array[CardView]) -> void:
	var discard_count := selected_views.size()

	for card_view in selected_views:
		if not is_instance_valid(card_view) or not card_view.card_data:
			discard_count -= 1
			continue
		var card_data: CardDef = card_view.card_data
		card_view.cancel_transform_tween()
		card_view.reparent(controller.get_parent(), true)
		card_view.z_index = 1200
		controller.hand_view.remove_card_view(card_view)
		controller.deck_manager.play_card(card_data.id)
		
		var exit_tween := card_view.create_tween().set_parallel(true)
		exit_tween.tween_property(card_view, "global_position",
			card_view.global_position + Vector2(0.0, -100.0), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		exit_tween.tween_property(card_view, "modulate:a", 0.0, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		exit_tween.chain().tween_callback(card_view.queue_free)

	controller._animator.play_sfx("card_leave", -2.0, randf_range(0.97, 1.03))
	await controller.get_tree().create_timer(0.15).timeout

	var current_count = controller.hand_view.card_views.size()
	var target_count = current_count + discard_count
	if current_count > 0:
		var slide_tween = controller.get_tree().create_tween().set_parallel(true)
		for index in range(current_count):
			var cv = controller.hand_view.card_views[index]
			cv.base_position = controller.hand_view._get_card_base_position(index, target_count)
			var center_index: float = (target_count - 1) / 2.0
			var offset := index - center_index
			cv.base_rotation_degrees = offset * 3.0
			cv.base_z_index = index
			
			slide_tween.tween_property(cv, "position", cv.base_position, 0.22) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			slide_tween.tween_property(cv, "rotation_degrees", cv.base_rotation_degrees, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await slide_tween.finished

	controller.deck_manager.draw_until_full(target_count)
	controller.hand_view.prepare_layout(controller.deck_manager.hand.size())
	for index in range(current_count, controller.deck_manager.hand.size()):
		var sig: Signal = controller._animator._animate_card_draw(
			controller.deck_manager.hand[index], index, controller.deck_manager.hand.size(), 0.0
		)
		await sig

	for cv: CardView in controller.hand_view.card_views:
		cv.set_interaction_enabled(true)
	controller.hand_view.normalize_card_layers()
	controller._animator.update_pile_visuals()
	controller.hand_view.set_dragging_enabled(true)
	controller._update_labels()
	controller._is_animating = false


func _on_snake_oil_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return
	controller._is_animating = true

	var poison_amount := 1
	if _check_double_loss_history():
		poison_amount = 2

	controller.consumable_shelf.consume_snake_oil()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_SNAKE_OIL)

	controller.sfx_manager.play_sfx("poison")

	var enemy_card_view = controller.enemy_slot.get_child(0) as CardView if controller.enemy_slot.get_child_count() > 0 else null
	if is_instance_valid(enemy_card_view):
		controller._animator.show_exclamation(
			enemy_card_view,
			"Poisoned!",
			Color(EffectKeywordData.get_color("Poison"))
		)

	controller._state.enemy_poison_turns += poison_amount
	controller._update_labels()

	var shake_target: Control = enemy_card_view if is_instance_valid(enemy_card_view) else controller.enemy_slot
	await controller._animator.shake(shake_target)
	controller._is_animating = false


func _on_pocketwatch_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return
	if controller._state.player_pocketwatch_active:
		return
	controller._is_animating = true
	controller._state.player_pocketwatch_active = true
	controller.consumable_shelf.consume_pocketwatch()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_POCKETWATCH)
	
	controller.sfx_manager.play_sfx("pocketwatch")
	
	var player_card_view = controller.player_slot.get_child(0) as CardView if controller.player_slot.get_child_count() > 0 else null
	if is_instance_valid(player_card_view):
		controller._animator.show_exclamation(
			player_card_view,
			"Pocketwatch!",
			Color(EffectKeywordData.get_color("Pocketwatch"))
		)
	controller._update_labels()
	var shake_target: Control = player_card_view if is_instance_valid(player_card_view) else controller.player_slot
	await controller._animator.shake(shake_target)
	controller._is_animating = false


func _on_velvet_gloves_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return

	if controller.deck_manager.draw_pile.is_empty():
		controller.sfx_manager.play_sfx("buzzer")
		var player_card_view = controller.player_slot.get_child(0) as CardView if controller.player_slot.get_child_count() > 0 else null
		var warn_target: Control = player_card_view if is_instance_valid(player_card_view) else controller.player_slot
		controller._animator.show_exclamation(warn_target, "Empty Draw Pile!", Color("#FF5555"))
		return

	controller._is_animating = true
	controller.hand_view.set_dragging_enabled(false)
	controller.sfx_manager.play_sfx("click")

	var main_root = controller.get_parent()
	var viewport_size: Vector2 = controller.get_viewport().get_visible_rect().size

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

	var state_data := {
		"selected_card": null,
		"selected_highlight": null
	}

	for card_data in controller.deck_manager.draw_pile:
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
			controller.sfx_manager.play_sfx("click")
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

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	content.add_child(btn_row)
	btn_row.add_child(select_btn_frame)
	btn_row.add_child(cancel_btn_frame)

	var target_y := (viewport_size.y - 540) * 0.5
	var slide_in = controller.create_tween().set_parallel(true)
	slide_in.tween_property(window, "position:y", target_y, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_in.tween_property(dim, "modulate:a", 1.0, 0.25)

	select_btn.pressed.connect(func() -> void:
		var target_card_data = state_data.selected_card
		if not target_card_data:
			return
		controller.sfx_manager.play_sfx("card_pickup")
		var slide_out = controller.create_tween().set_parallel(true)
		slide_out.tween_property(window, "position:y", viewport_size.y + 40, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		slide_out.tween_property(dim, "modulate:a", 0.0, 0.25)
		await slide_out.finished
		dim.queue_free()
		window.queue_free()

		controller.consumable_shelf.consume_velvet_gloves()
		PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_VELVET_GLOVES)
		controller._state.velvet_gloves_skip_draw = true

		controller.deck_manager.draw_pile.erase(target_card_data)
		controller.deck_manager.hand.append(target_card_data)
		controller.deck_manager.draw_pile_changed.emit()

		controller.hand_view.prepare_layout(controller.deck_manager.hand.size())

		var rearrange_tween = controller.create_tween().set_parallel(true)
		for cv in controller.hand_view.card_views:
			cv.set_interaction_enabled(false)
			rearrange_tween.tween_property(cv, "position", cv.get_rest_position(), 0.38) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			rearrange_tween.tween_property(cv, "rotation_degrees", cv.base_rotation_degrees, 0.38) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		var sig = controller._animator._animate_card_draw(target_card_data, controller.deck_manager.hand.size() - 1, controller.deck_manager.hand.size(), 0.0)
		await rearrange_tween.finished
		await sig

		for cv in controller.hand_view.card_views:
			cv.set_interaction_enabled(true)
		controller.hand_view.set_dragging_enabled(true)
		controller._is_animating = false
		controller._update_labels()
	)

	cancel_btn.pressed.connect(func() -> void:
		controller.sfx_manager.play_sfx("click")
		var slide_out = controller.create_tween().set_parallel(true)
		slide_out.tween_property(window, "position:y", viewport_size.y + 40, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		slide_out.tween_property(dim, "modulate:a", 0.0, 0.25)
		await slide_out.finished
		dim.queue_free()
		window.queue_free()
		controller.hand_view.set_dragging_enabled(true)
		controller._is_animating = false
	)


func _on_l_ivoire_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return
	var rare_card = _get_random_rare_card_for_type(CardDef.CardType.SCISSORS)
	controller.consumable_shelf.consume_l_ivoire()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_L_IVOIRE)
	await _animate_add_rare_card(rare_card, "arcane_general_1")


func _on_sealed_missive_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return
	var rare_card = _get_random_rare_card_for_type(CardDef.CardType.PAPER)
	controller.consumable_shelf.consume_sealed_missive()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_SEALED_MISSIVE)
	await _animate_add_rare_card(rare_card, "paper_general")


func _on_curio_requested() -> void:
	if controller.round_status != "ongoing" or controller._is_animating:
		return
	var rare_card = _get_random_rare_card_for_type(CardDef.CardType.ROCK)
	controller.consumable_shelf.consume_curio()
	PlayerStorageData.consume_consumable(PlayerStorageData.CONSUMABLE_CURIO)
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
	return WeaponCatalogData.create_weapon(chosen_id)


func _animate_add_rare_card(rare_card: CardDef, initial_sfx: String) -> void:
	controller._is_animating = true
	controller.hand_view.set_dragging_enabled(false)
	controller.sfx_manager.play_sfx(initial_sfx)

	var main_root = controller.get_parent()
	var viewport_size: Vector2 = controller.get_viewport().get_visible_rect().size

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

	var tween_in = controller.create_tween().set_parallel(true)
	tween_in.tween_property(dim, "modulate:a", 1.0, 0.3)
	tween_in.tween_property(card_view, "scale", Vector2.ONE, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(card_view, "modulate:a", 1.0, 0.3)
	await tween_in.finished

	await controller.get_tree().create_timer(1.4).timeout

	var flip_half = controller.create_tween()
	flip_half.tween_property(card_view, "scale:x", 0.06, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await flip_half.finished
	
	if card_view.has_method("set_face_down"):
		card_view.call("set_face_down", true)
	
	var flip_done = controller.create_tween()
	flip_done.tween_property(card_view, "scale:x", 1.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await flip_done.finished

	var dest_pos: Vector2 = controller._animator.pile_card_top.global_position - Vector2(card_width * 0.25, card_height * 0.25)

	card_view.z_index = 19
	card_view.z_as_relative = false

	var fly_tween = controller.create_tween().set_parallel(true)
	fly_tween.tween_property(card_view, "global_position", dest_pos, 0.55)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly_tween.tween_property(card_view, "scale", Vector2(0.5, 0.5), 0.55)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly_tween.tween_property(card_view, "rotation_degrees", randf_range(-12.0, 12.0), 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly_tween.tween_property(dim, "modulate:a", 0.0, 0.55)
	
	var fade_tween := controller.create_tween()
	fade_tween.tween_interval(0.35)
	fade_tween.tween_property(card_view, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fly_tween.finished

	controller.sfx_manager.play_sfx("card_placed")
	
	var rand_idx := randi_range(0, controller.deck_manager.draw_pile.size())
	controller.deck_manager.draw_pile.insert(rand_idx, rare_card)
	controller.deck_manager.draw_pile_changed.emit()
	controller._animator.update_pile_visuals()

	PlayerStorageData.add_weapon_and_select(rare_card)

	dim.queue_free()
	card_view.queue_free()
	
	controller.hand_view.set_dragging_enabled(true)
	controller._is_animating = false
	controller._update_labels()


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
		var tween = controller.create_tween()
		tween.tween_property(frame, "scale", Vector2(1.06, 1.06), 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	button.mouse_exited.connect(func() -> void:
		var tween = controller.create_tween()
		tween.tween_property(frame, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	return frame


func _check_double_loss_history() -> bool:
	var player_history = controller.battle_sidebar._player_history_cards
	var enemy_history = controller.battle_sidebar._enemy_history_cards
	var size = player_history.size()
	if size < 2:
		return false
	var last_result = BattleResolver.resolve_cards(player_history[size - 1], enemy_history[size - 1])
	var prev_result = BattleResolver.resolve_cards(player_history[size - 2], enemy_history[size - 2])
	return last_result == BattleResolver.Result.LOSE and prev_result == BattleResolver.Result.LOSE
