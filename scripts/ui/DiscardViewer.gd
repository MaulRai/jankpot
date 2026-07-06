class_name DiscardViewer
extends Control

@onready var count_label: Label = %CountLabel
@onready var popup: PanelContainer = %Popup
@onready var cards_container: GridContainer = %Cards
@onready var empty_label: Label = %EmptyLabel
@onready var box_button: TextureButton = %BoxButton

var _cards: Array[CardDef] = []
var _button_tween: Tween

func _ready() -> void:
	box_button.pressed.connect(_toggle_popup)
	box_button.mouse_entered.connect(_animate_box_button.bind(true, false))
	box_button.mouse_exited.connect(_animate_box_button.bind(false, false))
	box_button.button_down.connect(_animate_box_button.bind(true, true))
	box_button.button_up.connect(_on_box_button_up)
	_prepare_button_animation()
	popup.visible = false
	set_process_input(true)
	_refresh_view()
	
	_reposition_dynamically()
	get_tree().process_frame.connect(_reposition_dynamically)
	get_viewport().size_changed.connect(_reposition_dynamically)


func _reposition_dynamically() -> void:
	var sidebar = get_node_or_null("../LeftPanel")
	var board = get_node_or_null("../CenterBoard")
	if not sidebar or not board:
		return
	
	var sidebar_right = sidebar.position.x + sidebar.size.x
	var board_left = board.position.x
	
	var gap_width = board_left - sidebar_right
	var my_width = size.x
	
	var target_x = sidebar_right + (gap_width - my_width) / 2.0
	target_x = maxf(target_x, sidebar_right + 10.0)
	
	# Match the Y position of the DrawPileVisual sibling
	var draw_pile = get_node_or_null("../DrawPileVisual")
	var target_y = 482.0 # Fallback default
	if draw_pile:
		target_y = draw_pile.position.y
	
	position = Vector2(target_x, target_y)


func _input(event: InputEvent) -> void:
	if not popup.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		var mouse_position := get_global_mouse_position()
		if not popup.get_global_rect().has_point(mouse_position) \
				and not box_button.get_global_rect().has_point(mouse_position):
			popup.visible = false

func set_cards(cards: Array[CardDef]) -> void:
	_cards.clear()
	for card in cards:
		_cards.append(card.copy())
	if not is_node_ready():
		return
	_refresh_view()

func _refresh_view() -> void:
	count_label.text = str(_cards.size())
	_render_cards()

func _toggle_popup() -> void:
	popup.visible = not popup.visible

func _prepare_button_animation() -> void:
	box_button.pivot_offset = box_button.size * 0.5
	count_label.pivot_offset = count_label.size * 0.5

func _on_box_button_up() -> void:
	_animate_box_button(box_button.is_hovered(), false)

func _animate_box_button(is_hovered: bool, is_pressed: bool) -> void:
	if _button_tween and _button_tween.is_valid():
		_button_tween.kill()
	var target_scale := Vector2.ONE
	var target_modulate := Color.WHITE
	if is_pressed:
		target_scale = Vector2(0.94, 0.94)
		target_modulate = Color(0.9, 0.76, 0.72, 1.0)
	elif is_hovered:
		target_scale = Vector2(1.06, 1.06)
		target_modulate = Color(1.15, 1.05, 1.0, 1.0)
	var badge_scale := Vector2(1.12, 1.12) if is_hovered or is_pressed else Vector2.ONE
	_button_tween = create_tween()
	_button_tween.set_parallel(true)
	_button_tween.tween_property(box_button, "scale", target_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(box_button, "modulate", target_modulate, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(count_label, "scale", badge_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _render_cards() -> void:
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()

	empty_label.visible = _cards.is_empty()
	for card in _cards:
		var entry := VBoxContainer.new()
		entry.custom_minimum_size = Vector2(70.0, 92.0)
		entry.add_theme_constant_override("separation", 2)
		cards_container.add_child(entry)

		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(64.0, 64.0)
		art.texture = load(card.art_path) if ResourceLoader.exists(card.art_path) else null
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.tooltip_text = "%s — %s" % [card.card_name, card.rarity]
		entry.add_child(art)

		var name_label := Label.new()
		name_label.text = card.card_name
		name_label.custom_minimum_size = Vector2(68.0, 24.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size", 10)
		entry.add_child(name_label)
