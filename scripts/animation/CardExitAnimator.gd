class_name CardExitAnimator
extends Node

func animate(card_view: CardView, direction: Vector2) -> Signal:
	if card_view.card_data and "Fragile" in card_view.card_data.keywords:
		return animate_fragile(card_view)
	return animate_wind(card_view, direction)

func animate_fragile(card_view: Control) -> Signal:
	_prepare_card(card_view)

	var fragile_label := Label.new()
	fragile_label.text = "Fragile"
	fragile_label.add_theme_font_size_override("font_size", 22)
	fragile_label.add_theme_color_override(
		"font_color",
		Color(EffectKeyword.get_color("Fragile"))
	)
	fragile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fragile_label.custom_minimum_size = Vector2(card_view.size.x, 32.0)
	fragile_label.position = Vector2(0.0, -12.0)
	fragile_label.modulate.a = 0.0
	fragile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_view.add_child(fragile_label)

	var original_position := card_view.position
	var tween := create_tween()
	for i in range(7):
		var strength := 3.0 + float(i) * 0.8
		tween.tween_property(
			card_view,
			"position",
			original_position + Vector2(
				randf_range(-strength, strength),
				randf_range(-2.5, 2.5)
			),
			0.025
		)
	tween.tween_property(card_view, "position", original_position, 0.035)
	tween.tween_property(card_view, "modulate", Color(2.4, 2.4, 2.4, 1.0), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fragile_label, "modulate:a", 1.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_view, "scale", Vector2(1.22, 1.22), 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "modulate:a", 0.0, 0.38) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(fragile_label, "position:y", -58.0, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fragile_label, "modulate:a", 0.0, 0.38) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tween.finished

func animate_wind(card_view: Control, direction: Vector2) -> Signal:
	var duration := randf_range(0.7, 0.85)
	var viewport_size := get_viewport().get_visible_rect().size
	var travel_distance := viewport_size.x + card_view.size.x * 1.5
	var natural_direction := direction.normalized()
	natural_direction.y += randf_range(-0.08, 0.08)
	var target_position := card_view.global_position + natural_direction * travel_distance
	target_position.y += randf_range(-35.0, 35.0)

	_prepare_card(card_view)

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

func _prepare_card(card_view: Control) -> void:
	card_view.pivot_offset = card_view.size * 0.5
	card_view.z_index = 1500
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
