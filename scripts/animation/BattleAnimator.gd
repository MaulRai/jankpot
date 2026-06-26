class_name BattleAnimator
extends Node

const CardExitAnimatorData = preload("res://scripts/animation/CardExitAnimator.gd")

signal discard_batch_finished

var main_node: Node
var hand_view: Control
var player_slot: Control
var enemy_slot: Control
var pile_card_bottom: TextureRect
var pile_card_middle: TextureRect
var pile_card_top: TextureRect
var pile_count_label: Label
var draw_pile_visual: Control
var discard_viewer: Control
var deck_manager: Node
var sfx_manager: Node
var _exit_animator: Node
var _pending_exits := 0


func configure(dependencies: Dictionary) -> void:
	main_node = dependencies.main_node
	hand_view = dependencies.hand_view
	player_slot = dependencies.player_slot
	enemy_slot = dependencies.enemy_slot
	pile_card_bottom = dependencies.pile_card_bottom
	pile_card_middle = dependencies.pile_card_middle
	pile_card_top = dependencies.pile_card_top
	pile_count_label = dependencies.pile_count_label
	draw_pile_visual = dependencies.draw_pile_visual
	discard_viewer = dependencies.discard_viewer
	deck_manager = dependencies.deck_manager
	sfx_manager = dependencies.sfx_manager
	_exit_animator = CardExitAnimatorData.new()
	add_child(_exit_animator)


func snap_card_back(card_view: CardView) -> void:
	card_view.cancel_transform_tween()
	var tween := create_tween()
	tween.tween_property(card_view, "position", card_view.base_position, 0.2) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		card_view, "rotation_degrees", card_view.base_rotation_degrees, 0.2
	)
	await tween.finished
	card_view.reset_transform()
	card_view.z_index = card_view.base_z_index


func move_player_card_to_slot(card_view: CardView) -> void:
	var start_global := card_view.global_position
	hand_view.remove_card_view(card_view)
	main_node.add_child(card_view)
	card_view.global_position = start_global
	card_view.z_index = 1000
	var tween := create_tween()
	tween.tween_property(
		card_view, "global_position", player_slot.get_card_target_global_position(), 0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "rotation_degrees", 0.0, 0.35)
	tween.parallel().tween_property(card_view, "scale", Vector2.ONE, 0.35)
	await tween.finished
	play_sfx("card_placed", -1.0, randf_range(0.98, 1.02))
	player_slot.clear_slot()
	player_slot.place_card(card_view)
	card_view.z_index = 0


func animate_enemy_card_entry(card_view: CardView) -> void:
	card_view.position = Vector2(0.0, -70.0)
	card_view.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(card_view, "position", Vector2.ZERO, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func flip_card(card_view: CardView, revealed_data: CardDef) -> void:
	var close := create_tween()
	close.tween_property(card_view, "scale:x", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await close.finished
	card_view.set_face_down(false)
	card_view.set_card_data(revealed_data)
	var open := create_tween()
	open.tween_property(card_view, "scale:x", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	await open.finished


func refill_hand() -> void:
	if deck_manager.draw_pile.is_empty() and not deck_manager.discard_pile.is_empty():
		deck_manager.reshuffle_discard_if_needed()
		await animate_pile_rebuild()
	var previous_size: int = hand_view.card_views.size()
	deck_manager.draw_until_full(hand_view.hand_size)
	var final_size: int = deck_manager.hand.size()
	hand_view.prepare_layout(final_size)
	var last_finished: Signal
	for card in hand_view.card_views:
		card.set_interaction_enabled(false)
		var rearrange := create_tween().set_parallel(true)
		rearrange.tween_property(card, "position", card.get_rest_position(), 0.38) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		rearrange.tween_property(
			card, "rotation_degrees", card.base_rotation_degrees, 0.38
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		last_finished = rearrange.finished
	for index in range(previous_size, final_size):
		last_finished = _animate_card_draw(
			deck_manager.hand[index], index, final_size,
			float(index - previous_size) * 0.12
		)
	if last_finished:
		await last_finished
	for card in hand_view.card_views:
		card.set_interaction_enabled(true)
	hand_view.normalize_card_layers()
	update_pile_visuals()


func animate_skip_card_entry(skip_card: CardDef) -> void:
	var final_size: int = hand_view.card_views.size() + 1
	hand_view.prepare_layout(final_size)
	for card in hand_view.card_views:
		card.set_interaction_enabled(false)
		var rearrange := create_tween().set_parallel(true)
		rearrange.tween_property(card, "position", card.get_rest_position(), 0.28) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		rearrange.tween_property(card, "rotation_degrees", card.base_rotation_degrees, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var skip_view: CardView = hand_view.add_card_for_draw(skip_card, final_size - 1, final_size)
	if not skip_view:
		return
	skip_view.set_interaction_enabled(false)
	skip_view.set_face_down(true)
	skip_view.position = hand_view.get_global_transform().affine_inverse() \
		* (pile_card_top.global_position + Vector2(0.0, -24.0))
	skip_view.scale = Vector2(0.44, 0.44)
	skip_view.rotation_degrees = randf_range(-10.0, 10.0)
	skip_view.modulate = Color(0.7, 0.7, 0.78, 0.0)
	skip_view.z_index = 1200

	play_sfx("card_shuffle", -5.0, randf_range(0.92, 0.98))
	var movement := create_tween()
	movement.tween_property(skip_view, "modulate:a", 1.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	movement.parallel().tween_property(skip_view, "position", skip_view.base_position, 0.46) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	movement.parallel().tween_property(skip_view, "scale:y", 1.0, 0.46) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	movement.parallel().tween_property(skip_view, "rotation_degrees", skip_view.base_rotation_degrees, 0.46) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var flip := create_tween()
	flip.tween_interval(0.08)
	flip.tween_property(skip_view, "scale:x", 0.06, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip.tween_callback(func() -> void: skip_view.set_face_down(false))
	flip.tween_property(skip_view, "scale:x", 1.1, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip.tween_property(skip_view, "scale:x", 1.0, 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await movement.finished
	await flip.finished
	for card in hand_view.card_views:
		card.set_interaction_enabled(true)
	hand_view.normalize_card_layers()
	update_pile_visuals()


func animate_pile_rebuild() -> void:
	play_sfx("card_shuffle")
	_set_pile_cards_visible(false)
	var last_tween: Tween
	var spawned: Array[TextureRect] = []
	var target := pile_card_top.global_position
	var viewport_width := get_viewport().get_visible_rect().size.x
	for index in range(6):
		var card_back := TextureRect.new()
		card_back.texture = load("res://assets/ui/card-back.png")
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.size = Vector2(160.0, 240.0)
		card_back.scale = Vector2(0.5, 0.5)
		card_back.pivot_offset = card_back.size * 0.5
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main_node.add_child(card_back)
		card_back.global_position = Vector2(
			viewport_width + randf_range(40.0, 180.0),
			target.y + randf_range(-90.0, 90.0)
		)
		card_back.rotation_degrees = randf_range(-20.0, 20.0)
		card_back.z_index = 1700 + index
		spawned.append(card_back)
		last_tween = create_tween().set_parallel(true)
		last_tween.tween_property(
			card_back, "global_position",
			target + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)), 0.38
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		last_tween.tween_property(
			card_back, "rotation_degrees", randf_range(-2.0, 2.0), 0.38
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.055).timeout
	if last_tween:
		await last_tween.finished
	for card_back in spawned:
		card_back.queue_free()
	_set_pile_cards_visible(true)
	update_pile_visuals()


func update_pile_visuals() -> void:
	var count: int = deck_manager.draw_pile.size()
	pile_count_label.text = str(count)
	_set_pile_cards_visible(count > 0)
	draw_pile_visual.set_cards(deck_manager.draw_pile)
	discard_viewer.set_cards(deck_manager.discard_pile)


func shake(node: Control) -> void:
	var original := node.position
	var tween := create_tween()
	for index in range(6):
		var offset := Vector2(randf_range(-6, 6), randf_range(-4, 4))
		tween.tween_property(node, "position", original + offset, 0.04)
	tween.tween_property(node, "position", original, 0.04)
	await tween.finished


func discard_cards(
	player_card: CardView,
	enemy_card: CardView,
	player_exit_type := "auto",
	enemy_exit_type := "auto"
) -> void:
	_pending_exits = 0
	_start_exit(player_card, Vector2(-1.0, 0.22), player_exit_type)
	_start_exit(enemy_card, Vector2(1.0, -0.22), enemy_exit_type)
	if _pending_exits > 0:
		await discard_batch_finished
	player_slot.clear_slot()
	enemy_slot.clear_slot()


func show_exclamation(card_view: CardView, text: String, color: Color) -> void:
	_exit_animator.show_exclamation(card_view, text, color)


func play_sfx(
	sfx_name: String,
	volume_offset_db := 0.0,
	pitch_scale := 1.0
) -> void:
	if sfx_manager:
		sfx_manager.play_sfx(sfx_name, volume_offset_db, pitch_scale)


func _animate_card_draw(
	card_data: CardDef,
	hand_index: int,
	hand_count: int,
	delay: float
) -> Signal:
	var drawn_card: CardView = hand_view.add_card_for_draw(card_data, hand_index, hand_count)
	if not drawn_card:
		return get_tree().process_frame
	drawn_card.set_interaction_enabled(false)
	drawn_card.set_face_down(true)
	drawn_card.position = hand_view.get_global_transform().affine_inverse() \
		* pile_card_top.global_position
	drawn_card.scale = Vector2(0.5, 0.5)
	drawn_card.rotation_degrees = randf_range(-8.0, 8.0)
	drawn_card.z_index = drawn_card.base_z_index
	var movement := create_tween()
	if delay > 0.0:
		movement.tween_interval(delay)
	movement.tween_property(drawn_card, "position", drawn_card.base_position, 0.58) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	movement.parallel().tween_property(drawn_card, "scale:y", 1.0, 0.58) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	movement.parallel().tween_property(
		drawn_card, "rotation_degrees", drawn_card.base_rotation_degrees, 0.58
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var flip := create_tween()
	flip.tween_interval(delay + 0.08)
	flip.tween_property(drawn_card, "scale:x", 0.06, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip.tween_callback(func() -> void: drawn_card.set_face_down(false))
	flip.tween_property(drawn_card, "scale:x", 1.0, 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return movement.finished


func _start_exit(card: CardView, direction: Vector2, exit_type: String) -> void:
	if not is_instance_valid(card):
		return
	_pending_exits += 1
	if exit_type == "downgrade":
		play_sfx("downgrade")
	elif card.card_data and "Fragile" in card.card_data.keywords:
		play_sfx("fragile")
	else:
		play_sfx("card_leave", -2.0, randf_range(0.97, 1.03))
	_exit_animator.animate(card, direction, exit_type).connect(
		_on_exit_finished, CONNECT_ONE_SHOT
	)


func _on_exit_finished() -> void:
	_pending_exits -= 1
	if _pending_exits <= 0:
		discard_batch_finished.emit()


func _set_pile_cards_visible(is_visible: bool) -> void:
	pile_card_bottom.visible = is_visible
	pile_card_middle.visible = is_visible
	pile_card_top.visible = is_visible
