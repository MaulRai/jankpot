class_name HandView
extends Control

signal card_play_requested(card_data: CardDef, card_view: CardView)
signal card_drag_started(card_view: CardView)
signal card_drag_ended(card_view: CardView)

@export var card_scene: PackedScene
@export var hand_size: int = 3

@onready var tooltip_manager: TooltipManager = get_node_or_null("../TooltipManager")

var card_views: Array[CardView] = []
var _disabled_type: CardDef.CardType = CardDef.CardType.ROCK
var _has_disabled_type := false
var _dragging_enabled := true

func _ready() -> void:
	resized.connect(_on_resized)

func _on_resized() -> void:
	if card_views.size() > 0:
		_layout_cards()

func set_cards(cards: Array[CardDef]) -> void:
	_clear_hand()
	for card_data in cards:
		_add_card(card_data)
	_layout_cards()
	_apply_disabled_visuals(false)

func _add_card(card_data: CardDef) -> CardView:
	if not card_scene:
		return null
	var card_view: CardView = card_scene.instantiate()
	card_view.set_card_data(card_data)
	card_view.set_drag_enabled(_dragging_enabled)
	card_view.card_drag_started.connect(_on_card_drag_started)
	card_view.card_drag_ended.connect(_on_card_drag_ended)
	card_view.card_hovered.connect(_on_card_hovered)
	card_view.card_unhovered.connect(_on_card_unhovered)
	add_child(card_view)
	card_views.append(card_view)
	return card_view

func _clear_hand() -> void:
	_hide_tooltip()
	for card in card_views:
		card.queue_free()
	card_views.clear()

func _layout_cards() -> void:
	for i in range(card_views.size()):
		_apply_card_layout(card_views[i], i, card_views.size())
	_apply_disabled_visuals(false)

func prepare_layout(card_count: int) -> void:
	for i in range(card_views.size()):
		_set_card_base_layout(card_views[i], i, card_count)
		card_views[i].z_index = card_views[i].base_z_index

func add_card_for_draw(card_data: CardDef, index: int, card_count: int) -> CardView:
	var card := _add_card(card_data)
	if card:
		_set_card_base_layout(card, index, card_count)
		_apply_card_disabled_visual(card, false)
	return card

func get_card_target_global_position(index: int, card_count: int) -> Vector2:
	return get_global_transform() * _get_card_base_position(index, card_count)

func _get_card_base_position(index: int, card_count: int) -> Vector2:
	var card_width: float = 160.0
	var preferred_spacing: float = 110.0
	var available_width: float = maxf(size.x - 80.0, card_width)
	var spacing: float = preferred_spacing
	if card_count > 1:
		spacing = minf(preferred_spacing, (available_width - card_width) / (card_count - 1))
		spacing = maxf(spacing, 42.0)
	var total_width: float
	if card_count > 1:
		total_width = card_width + (card_count - 1) * spacing
	else:
		total_width = card_width
	var start_x: float = (size.x - total_width) / 2.0
	var bottom_y: float = size.y - 240.0
	if bottom_y < 0:
		bottom_y = 30.0
	return Vector2(start_x + index * spacing, bottom_y)

func _apply_card_layout(card: CardView, index: int, card_count: int) -> void:
	_set_card_base_layout(card, index, card_count)
	card.position = card.get_rest_position()
	card.rotation_degrees = card.base_rotation_degrees
	card.z_index = card.base_z_index

func _set_card_base_layout(card: CardView, index: int, card_count: int) -> void:
	var center_index: float = (card_count - 1) / 2.0
	var offset := index - center_index
	card.base_position = _get_card_base_position(index, card_count)
	card.base_rotation_degrees = offset * 3.0
	# Cards further to the right are drawn above cards to their left.
	card.base_z_index = index
	card.pivot_offset = Vector2(80.0, card.size.y / 2.0)

func normalize_card_layers() -> void:
	for i in range(card_views.size()):
		var card := card_views[i]
		card.base_z_index = i
		card.z_index = i
		move_child(card, i)
	_apply_disabled_visuals(false)

func set_disabled_type(has_disabled_type: bool, disabled_type: CardDef.CardType) -> void:
	_has_disabled_type = has_disabled_type
	_disabled_type = disabled_type
	_apply_disabled_visuals(true)

func set_dragging_enabled(enabled: bool, excluded_card: CardView = null) -> void:
	_dragging_enabled = enabled
	for card in card_views:
		if card == excluded_card:
			continue
		_apply_card_disabled_visual(card, false)

func remove_card_view(card_view: CardView) -> void:
	_hide_tooltip()
	card_views.erase(card_view)
	if card_view.get_parent() == self:
		remove_child(card_view)

func _on_card_drag_started(card: CardView) -> void:
	_hide_tooltip()
	card.z_index = 1000
	card_drag_started.emit(card)

func _on_card_drag_ended(card: CardView) -> void:
	card_drag_ended.emit(card)
	if card.card_data:
		emit_signal("card_play_requested", card.card_data, card)

func _on_card_hovered(card: CardView) -> void:
	if not tooltip_manager or not card.card_data or card.card_data.keywords.is_empty():
		return
	var tooltip_global_position := card.global_position + Vector2(card.size.x + 12.0, 8.0)
	tooltip_manager.show_tooltip(card.card_data.keywords, tooltip_global_position)

func _on_card_unhovered(_card: CardView) -> void:
	_hide_tooltip()

func _hide_tooltip() -> void:
	if tooltip_manager:
		tooltip_manager.hide_tooltip()

func _apply_disabled_visuals(animate: bool) -> void:
	for card in card_views:
		_apply_card_disabled_visual(card, animate)

func _apply_card_disabled_visual(card: CardView, animate: bool) -> void:
	if not card.card_data:
		return
	var is_disabled := _has_disabled_type \
		and not card.card_data.is_skip \
		and card.card_data.card_type == _disabled_type
	card.set_disabled_visual(is_disabled, animate)
	card.set_drag_enabled(_dragging_enabled and not is_disabled)
