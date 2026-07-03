class_name PickMode
extends Control
## Reusable card-picking overlay.
##
## Shows the player's hand in a separate panel, lets them select N cards,
## and calls back with the selected cards when the "Choose" button is pressed.
##
## Usage:
##   var picker := PickMode.new()
##   add_child(picker)
##   picker.start(cards, max_pick, on_chosen)

signal chosen(selected: Array[CardDef])

@export var card_scene: PackedScene
@export var pick_limit: int = 2
@export var min_pick: int = 1

@onready var cards_container: HBoxContainer = %CardsContainer
@onready var choose_button: Button = %ChooseButton
@onready var count_label: Label = %CountLabel
@onready var prompt_label: Label = %PromptLabel

var _cards: Array[CardDef] = []
var _selected_indices: PackedInt32Array = []
var _chosen_callback: Callable

func _ready() -> void:
	choose_button.pressed.connect(_on_choose)
	choose_button.visible = false
	visible = false

func start(cards: Array[CardDef], max_pick: int, on_chosen: Callable, min_pick_val: int = 1) -> void:
	_cards = cards
	pick_limit = maxi(1, max_pick)
	min_pick = maxi(0, clampi(min_pick_val, 0, max_pick))
	_chosen_callback = on_chosen
	_selected_indices.clear()
	_render_cards()
	visible = true
	choose_button.visible = false

func _render_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()

	for i in range(_cards.size()):
		var card_data := _cards[i]
		if not card_scene:
			continue
		var card_view: CardView = card_scene.instantiate()
		card_view.set_card_data(card_data)
		card_view.interaction_enabled = true
		card_view.drag_enabled = false
		card_view.card_clicked.connect(_on_card_clicked.bind(i))
		card_view.card_hovered.connect(_on_card_hovered.bind(i))
		card_view.card_unhovered.connect(_on_card_unhovered.bind(i))
		cards_container.add_child(card_view)

	_update_selection_visuals()

func _on_card_clicked(card_view: CardView, index: int) -> void:
	if index in _selected_indices:
		_selected_indices.remove_at(_selected_indices.find(index))
	else:
		if _selected_indices.size() >= pick_limit:
			return
		_selected_indices.append(index)
	_update_selection_visuals()

func _on_card_hovered(card_view: CardView, index: int) -> void:
	if index in _selected_indices:
		card_view.scale = Vector2(1.08, 1.08)
		return
	card_view.z_index = 100

func _on_card_unhovered(card_view: CardView, index: int) -> void:
	if index in _selected_indices:
		card_view.z_index = 50
		return
	card_view.z_index = 0

func _update_selection_visuals() -> void:
	for i in range(cards_container.get_child_count()):
		var card_view := cards_container.get_child(i) as CardView
		if not card_view:
			continue
		var is_selected := i in _selected_indices
		if is_selected:
			card_view.position = Vector2.ZERO
			card_view.scale = Vector2(1.06, 1.06)
			card_view.z_index = 50
			card_view.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			card_view.position = Vector2.ZERO
			card_view.scale = Vector2(1.0, 1.0)
			card_view.z_index = 0
			card_view.modulate = Color(1.0, 1.0, 1.0, 0.85)

	choose_button.visible = _selected_indices.size() >= min_pick
	if count_label:
		count_label.text = "%d / %d" % [_selected_indices.size(), pick_limit]

func _on_choose() -> void:
	var selected: Array[CardDef] = []
	for idx in _selected_indices:
		selected.append(_cards[idx])
	visible = false
	if _chosen_callback:
		_chosen_callback.call(selected)
	chosen.emit(selected)

func cleanup() -> void:
	visible = false
	for child in cards_container.get_children():
		child.queue_free()
	_cards.clear()
	_selected_indices.clear()