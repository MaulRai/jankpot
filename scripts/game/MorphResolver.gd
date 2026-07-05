class_name MorphResolver
extends RefCounted

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")
const STAR_CRUSH_FONT := preload("res://fonts/Star Crush.otf")
const CARD_SCENE := preload("res://scenes/ui/CardView.tscn")

var controller: Node

func configure(p_controller: Node) -> void:
	controller = p_controller


func _show_origami_choice_ui(card_data: CardDef) -> void:
	var main_root = controller.get_parent()
	var viewport_size: Vector2 = controller.get_viewport().get_visible_rect().size

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
			controller.sfx_manager.play_sfx("click")
			choice_container.append(option_data.card_type)
			
			var slide_out := controller.create_tween().set_parallel(true)
			slide_out.tween_property(current_window, "position:y", viewport_size.y + 40, 0.25) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			slide_out.tween_property(current_dim, "modulate:a", 0.0, 0.2)
			await slide_out.finished
			current_window.queue_free()
			current_dim.queue_free()
		)

	# Slide in
	var target_y := (viewport_size.y - 360) * 0.5
	var slide_in := controller.create_tween().set_parallel(true)
	slide_in.tween_property(window, "position:y", target_y, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_in.tween_property(dim, "modulate:a", 1.0, 0.2)

	# Wait until choice is selected and added to choice_container
	while choice_container.is_empty():
		await controller.get_tree().process_frame

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


func resolve_origami_morphs(player_card: CardDef, enemy_card: CardDef, player_view: CardView, enemy_view: CardView) -> void:
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
		controller.sfx_manager.play_sfx("morph")
		if p_morphed and is_instance_valid(player_view):
			player_view.set_card_data(player_card)
			controller._animator.show_exclamation(player_view, "Morphed!", Color("#FFD166"))
		if e_morphed and is_instance_valid(enemy_view):
			enemy_view.set_card_data(enemy_card)
			controller._animator.show_exclamation(enemy_view, "Morphed!", Color("#FFD166"))
		await controller.get_tree().create_timer(0.4).timeout


func revert_combat_cards(card: CardDef) -> void:
	if not card:
		return
	if card.id.begins_with("origami"):
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
	elif card.has_meta("plague"):
		card.remove_meta("plague")
