class_name HandView
extends Control

signal card_play_requested(card_data: CardDef, card_view: CardView)

@export var card_scene: PackedScene
@export var hand_size: int = 3

var card_views: Array[CardView] = []

func _ready() -> void:
	pass

func set_cards(cards: Array[CardDef]) -> void:
	_clear_hand()
	for card_data in cards:
		_add_card(card_data)
	_layout_cards()

func _add_card(card_data: CardDef) -> void:
	if not card_scene:
		return
	var card_view: CardView = card_scene.instantiate()
	card_view.set_card_data(card_data)
	card_view.card_play_requested.connect(_on_card_play_requested)
	card_view.card_hovered.connect(_on_card_hovered)
	card_view.card_unhovered.connect(_on_card_unhovered)
	add_child(card_view)
	card_views.append(card_view)

func _clear_hand() -> void:
	for card in card_views:
		card.queue_free()
	card_views.clear()

func _layout_cards() -> void:
	var card_width: float = 160.0
	var overlap: float = 50.0
	var spacing: float = card_width - overlap
	var total_width: float = card_views.size() * card_width + (card_views.size() - 1) * (spacing - card_width)
	if card_views.size() > 1:
		total_width = card_views.size() * card_width - (card_views.size() - 1) * overlap
	else:
		total_width = card_width
	var start_x: float = (size.x - total_width) / 2.0
	var center_index: float = (card_views.size() - 1) / 2.0
	for i in range(card_views.size()):
		var card := card_views[i]
		var offset := i - center_index
		card.base_position = Vector2(start_x + i * spacing, 0)
		card.position = card.base_position
		card.rotation_degrees = offset * 3.0
		card.pivot_offset = Vector2(card_width / 2.0, card.size.y / 2.0)
		# Center card highest z-index for natural overlap
		card.base_z_index = card_views.size() - int(abs(offset))
		card.z_index = card.base_z_index

func remove_card_view(card_view: CardView) -> void:
	card_views.erase(card_view)
	if card_view.get_parent() == self:
		remove_child(card_view)

func _on_card_play_requested(card: CardView) -> void:
	if card.card_data:
		emit_signal("card_play_requested", card.card_data, card)

func _on_card_hovered(card: CardView) -> void:
	card.z_index = 100

func _on_card_unhovered(card: CardView) -> void:
	card.z_index = card.base_z_index
