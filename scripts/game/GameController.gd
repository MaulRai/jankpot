class_name GameController
extends Node

signal turn_resolved
signal battle_ended(winner: String)

@onready var deck_manager: DeckManager = $DeckManager
@onready var battle_resolver: BattleResolver = $BattleResolver
@onready var enemy_controller: EnemyController = $EnemyController
@onready var hand_view: HandView = get_node("../BottomHand")
@onready var player_slot: CardSlot = get_node("../CenterBoard/PlayerSlot")

var player_hp: int = 10
var enemy_hp: int = 10
var turn_count: int = 0
var round_status: String = "ongoing"
var _is_animating: bool = false

func _ready() -> void:
	if deck_manager:
		deck_manager.hand_changed.connect(_on_hand_changed)
	if hand_view:
		hand_view.card_play_requested.connect(_on_card_play_requested)
	if deck_manager:
		deck_manager.setup_starting_deck()
		deck_manager.draw_until_full(3)

func _on_hand_changed() -> void:
	if _is_animating:
		return
	if hand_view:
		hand_view.set_cards(deck_manager.hand)

func _on_card_play_requested(card_data: CardDef, card_view: CardView) -> void:
	if round_status != "ongoing" or _is_animating:
		_snap_card_back(card_view)
		return
	
	var drop_pos: Vector2 = card_view.global_position + card_view.size / 2
	if not player_slot.get_global_rect().has_point(drop_pos):
		_snap_card_back(card_view)
		return
	
	_play_card(card_data, card_view)

func _snap_card_back(card_view: CardView) -> void:
	_is_animating = true
	var target_global: Vector2 = hand_view.to_global(card_view.base_position)
	var tween := create_tween()
	tween.tween_property(card_view, "global_position", target_global, 0.2).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "rotation_degrees", card_view.base_rotation_degrees, 0.2)
	
	await tween.finished
	
	card_view.top_level = false
	card_view.position = card_view.base_position
	card_view.rotation_degrees = card_view.base_rotation_degrees
	card_view.scale = Vector2(1.0, 1.0)
	card_view.z_index = card_view.base_z_index
	_is_animating = false

func _play_card(card_data: CardDef, card_view: CardView) -> void:
	_is_animating = true

	# Capture start global position BEFORE removing from hand
	var start_global: Vector2 = card_view.global_position

	# Remove card from hand UI without freeing it
	hand_view.remove_card_view(card_view)

	# Reparent to Main for free animation across the UI
	var main_node: Node = get_parent()
	main_node.add_child(card_view)
	card_view.global_position = start_global
	card_view.z_index = 1000

	# Animate to player slot
	var target_pos: Vector2 = player_slot.global_position
	var tween := create_tween()
	tween.tween_property(card_view, "global_position", target_pos, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "rotation_degrees", 0.0, 0.45)
	tween.parallel().tween_property(card_view, "scale", Vector2(1.0, 1.0), 0.45)

	await tween.finished

	# Place in slot (clear previous first)
	player_slot.clear_slot()
	player_slot.place_card(card_view)
	card_view.z_index = 0
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Update deck: play card + draw refill
	deck_manager.play_card(card_data.id)
	deck_manager.draw_until_full(3)

	_is_animating = false
	if hand_view:
		hand_view.set_cards(deck_manager.hand)

	turn_count += 1
	emit_signal("turn_resolved")

func start_battle() -> void:
	player_hp = 10
	enemy_hp = 10
	turn_count = 0
	round_status = "ongoing"
	player_slot.clear_slot()
	if deck_manager:
		deck_manager.setup_starting_deck()
		deck_manager.draw_until_full(3)
