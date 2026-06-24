class_name GameController
extends Node

signal turn_resolved
signal battle_ended(winner: String)

@onready var deck_manager: DeckManager = $DeckManager
@onready var battle_resolver: BattleResolver = $BattleResolver
@onready var enemy_controller: EnemyController = $EnemyController
@onready var hand_view: HandView = get_node("../BottomHand")
@onready var player_slot: CardSlot = get_node("../CenterBoard/PlayerSlot")
@onready var enemy_slot: CardSlot = get_node("../CenterBoard/EnemySlot")
@onready var hp_label: Label = get_node("../LeftPanel/VBoxContainer/HPLabel")
@onready var turn_label: Label = get_node("../LeftPanel/VBoxContainer/TurnLabel")
@onready var battle_board: Control = get_node("../CenterBoard")

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
	_update_labels()

func _on_hand_changed() -> void:
	if _is_animating:
		return
	if hand_view:
		hand_view.set_cards(deck_manager.hand)

func _update_labels() -> void:
	if hp_label:
		hp_label.text = "HP: %d / 10" % player_hp
	if turn_label:
		turn_label.text = "Turn: %d" % turn_count

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
	card_view.cancel_transform_tween()
	var tween := create_tween()
	tween.tween_property(card_view, "position", card_view.base_position, 0.2).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "rotation_degrees", card_view.base_rotation_degrees, 0.2)
	
	await tween.finished
	
	card_view.reset_transform()
	card_view.z_index = card_view.base_z_index
	_is_animating = false

func _play_card(card_data: CardDef, card_view: CardView) -> void:
	_is_animating = true
	card_view.set_interaction_enabled(false)

	# 1. Animate player card from hand to player slot
	var start_global: Vector2 = card_view.global_position
	hand_view.remove_card_view(card_view)
	var main_node: Node = get_parent()
	main_node.add_child(card_view)
	card_view.global_position = start_global
	card_view.z_index = 1000

	var tween := create_tween()
	tween.tween_property(
		card_view,
		"global_position",
		player_slot.get_card_target_global_position(),
		0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "rotation_degrees", 0.0, 0.35)
	tween.parallel().tween_property(card_view, "scale", Vector2(1.0, 1.0), 0.35)

	await tween.finished

	player_slot.clear_slot()
	player_slot.place_card(card_view)
	card_view.z_index = 0

	# 2. Enemy chooses hidden card
	var enemy_card: CardDef = enemy_controller.choose_card()

	# 3. Show enemy card face-down in enemy slot
	var enemy_view: CardView
	if hand_view.card_scene:
		enemy_view = hand_view.card_scene.instantiate()
		enemy_view.custom_minimum_size = Vector2(160, 240)
		enemy_slot.place_card(enemy_view)
		enemy_view.set_interaction_enabled(false)
		enemy_view.set_face_down(true)
		enemy_view.z_index = 0
		await _animate_enemy_card_entry(enemy_view)

	# 4. Brief pause before reveal
	await get_tree().create_timer(0.2).timeout

	# 5. Flip reveal enemy card
	if enemy_view and enemy_card:
		await _flip_card(enemy_view, enemy_card)

	# 6. Move both played cards to discard in deck manager
	deck_manager.play_card(card_data.id)
	deck_manager.discard_played_card(enemy_card)

	# 7. Resolve battle
	var result: BattleResolver.Result = battle_resolver.resolve(card_data.card_type, enemy_card.card_type)
	await _apply_result(result)

	# 8. Check battle end
	if player_hp <= 0 or enemy_hp <= 0:
		_end_battle()
		return

	# 9. Brief pause then discard cards
	await get_tree().create_timer(0.4).timeout
	await _discard_animations(card_view, enemy_view)

	# 10. Draw refill and rebuild hand
	deck_manager.draw_until_full(3)
	if hand_view:
		hand_view.set_cards(deck_manager.hand)

	_is_animating = false
	turn_count += 1
	_update_labels()
	emit_signal("turn_resolved")

func _animate_enemy_card_entry(card_view: CardView) -> void:
	card_view.position = Vector2(0.0, -70.0)
	card_view.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(card_view, "position", Vector2.ZERO, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func _flip_card(card_view: CardView, revealed_data: CardDef) -> void:
	# Scale X to 0 to hide
	var tween := create_tween()
	tween.tween_property(card_view, "scale:x", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished

	# Reveal content
	card_view.set_face_down(false)
	card_view.set_card_data(revealed_data)

	# Scale X back to 1
	var tween2 := create_tween()
	tween2.tween_property(card_view, "scale:x", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	await tween2.finished

func _apply_result(result: BattleResolver.Result) -> void:
	match result:
		BattleResolver.Result.WIN:
			enemy_hp -= 1
			_update_labels()
			_show_floating_text(enemy_slot, "1", Color("#FF5555"))
			await _shake_node(enemy_slot)
		BattleResolver.Result.LOSE:
			player_hp -= 1
			_update_labels()
			_show_floating_text(player_slot, "1", Color("#FF5555"))
			await _shake_node(player_slot)
		BattleResolver.Result.DRAW:
			_show_floating_text(player_slot, "Draw", Color.GRAY)
			await get_tree().create_timer(0.4).timeout

func _show_floating_text(target_node: Control, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position above target node
	var label_pos: Vector2 = target_node.global_position + Vector2(0, -40)
	var root: Node = get_parent()
	root.add_child(label)
	label.global_position = label_pos
	label.z_index = 2000
	
	var tween := create_tween()
	tween.tween_property(label, "global_position:y", label_pos.y - 50, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	
	await tween.finished
	label.queue_free()

func _shake_node(node: Control) -> void:
	var original_pos := Vector2(node.position)
	var tween := create_tween()
	for i in range(6):
		var offset := Vector2(randf_range(-6, 6), randf_range(-4, 4))
		tween.tween_property(node, "position", original_pos + offset, 0.04)
	tween.tween_property(node, "position", original_pos, 0.04)
	await tween.finished

func _discard_animations(player_card: CardView, enemy_card: CardView) -> void:
	var discard_target: Vector2 = player_slot.global_position + Vector2(0, 300)
	
	# Animate both cards down and fade out
	var tween := create_tween()
	if player_card:
		tween.tween_property(player_card, "global_position", discard_target, 0.35).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(player_card, "modulate:a", 0.0, 0.35)
	if enemy_card:
		tween.parallel().tween_property(enemy_card, "global_position", discard_target + Vector2(40, 0), 0.35).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(enemy_card, "modulate:a", 0.0, 0.35)
	await tween.finished
	
	player_slot.clear_slot()
	enemy_slot.clear_slot()

func _end_battle() -> void:
	round_status = "ended"
	var winner := "Draw"
	if player_hp <= 0 and enemy_hp <= 0:
		winner = "Draw"
	elif player_hp <= 0:
		winner = "Enemy"
	elif enemy_hp <= 0:
		winner = "Player"
	emit_signal("battle_ended", winner)
	_is_animating = false

func start_battle() -> void:
	player_hp = 10
	enemy_hp = 10
	turn_count = 0
	round_status = "ongoing"
	player_slot.clear_slot()
	enemy_slot.clear_slot()
	if deck_manager:
		deck_manager.setup_starting_deck()
		deck_manager.draw_until_full(3)
	_update_labels()
