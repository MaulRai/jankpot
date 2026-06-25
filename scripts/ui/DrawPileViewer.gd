class_name DrawPileViewer
extends Control

@onready var count_label: Label = %CountLabel
@onready var popup: PanelContainer = %Popup
@onready var cards_container: GridContainer = %Cards
@onready var empty_label: Label = %EmptyLabel
@onready var pile_button: Button = %PileButton

var _cards: Array[CardDef] = []

func _ready() -> void:
	pile_button.pressed.connect(_toggle_popup)
	popup.visible = false
	set_process_input(true)
	_refresh_view()

func _input(event: InputEvent) -> void:
	if not popup.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		var mouse_position := get_global_mouse_position()
		if not popup.get_global_rect().has_point(mouse_position) \
				and not pile_button.get_global_rect().has_point(mouse_position):
			popup.visible = false

func set_cards(cards: Array[CardDef]) -> void:
	_cards.clear()
	for card in cards:
		_cards.append(card.copy())
	# Display order must not reveal the actual draw order.
	_cards.sort_custom(func(a: CardDef, b: CardDef) -> bool:
		var name_comparison := a.card_name.naturalnocasecmp_to(b.card_name)
		if name_comparison == 0:
			return a.rarity.naturalnocasecmp_to(b.rarity) < 0
		return name_comparison < 0
	)
	if not is_node_ready():
		return
	_refresh_view()

func _refresh_view() -> void:
	count_label.text = str(_cards.size())
	_render_cards()

func _toggle_popup() -> void:
	popup.visible = not popup.visible

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
		art.tooltip_text = "%s - %s" % [card.card_name, card.rarity]
		entry.add_child(art)

		var name_label := Label.new()
		name_label.text = card.card_name
		name_label.custom_minimum_size = Vector2(68.0, 24.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size", 10)
		entry.add_child(name_label)
