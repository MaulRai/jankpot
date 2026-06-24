class_name GameController
extends Node

signal turn_resolved
signal battle_ended(winner: String)
signal wind_exit_batch_finished

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
var _pending_wind_exits: int = 0

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

	# 6. Resolve battle
	var result: BattleResolver.Result = battle_resolver.resolve(card_data.card_type, enemy_card.card_type)
	await _apply_result(result)

	# 7. Brief pause, then blow both cards off the board.
	await get_tree().create_timer(0.35).timeout
	await _discard_animations(card_view, enemy_view)

	# 8. Update discard data only after the cards have visually left the board.
	deck_manager.play_card(card_data.id)
	deck_manager.discard_played_card(enemy_card)

	# 9. Check battle end after the final cards have left the board.
	if player_hp <= 0 or enemy_hp <= 0:
		_end_battle()
		return

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
	_pending_wind_exits = 0

	if is_instance_valid(player_card):
		_pending_wind_exits += 1
		animate_card_wind_exit(player_card, Vector2(-1.0, 0.22)).connect(
			_on_card_wind_exit_finished,
			CONNECT_ONE_SHOT
		)
	if is_instance_valid(enemy_card):
		_pending_wind_exits += 1
		animate_card_wind_exit(enemy_card, Vector2(1.0, -0.22)).connect(
			_on_card_wind_exit_finished,
			CONNECT_ONE_SHOT
		)

	if _pending_wind_exits > 0:
		await wind_exit_batch_finished

	player_slot.clear_slot()
	enemy_slot.clear_slot()

func _on_card_wind_exit_finished() -> void:
	_pending_wind_exits -= 1
	if _pending_wind_exits <= 0:
		wind_exit_batch_finished.emit()

func animate_card_wind_exit(card_view: Control, direction: Vector2) -> Signal:
	var duration := randf_range(0.7, 0.85)
	var viewport_size := get_viewport().get_visible_rect().size
	var travel_distance := viewport_size.x + card_view.size.x * 1.5
	var natural_direction := direction.normalized()
	natural_direction.y += randf_range(-0.08, 0.08)
	var target_position := card_view.global_position + natural_direction * travel_distance
	target_position.y += randf_range(-35.0, 35.0)

	card_view.pivot_offset = card_view.size * 0.5
	card_view.z_index = 1500
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rotation_amount := deg_to_rad(randf_range(18.0, 32.0))
	if direction.x < 0.0:
		rotation_amount *= -1.0

	var movement_tween := create_tween()
	movement_tween.set_parallel(true)
	movement_tween.tween_property(card_view, "global_position", target_position, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	movement_tween.tween_property(
		card_view,
		"rotation",
		card_view.rotation + rotation_amount,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var flip_tween := create_tween()
	flip_tween.tween_property(card_view, "scale:x", 0.78, duration * 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flip_tween.tween_property(card_view, "scale:x", 1.0, duration * 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flip_tween.tween_property(card_view, "scale", Vector2(0.93, 0.93), duration * 0.48) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return movement_tween.finished

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
