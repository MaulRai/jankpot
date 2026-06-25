class_name CardExitAnimator
extends Node

func animate(
	card_view: CardView,
	direction: Vector2,
	exit_type: String = "auto"
) -> Signal:
	if exit_type == "downgrade":
		return animate_downgrade(card_view, direction)
	if card_view.card_data and "Fragile" in card_view.card_data.keywords:
		return animate_fragile(card_view)
	return animate_wind(card_view, direction)

func show_exclamation(card_view: Control, text: String, color: Color) -> void:
	if not is_instance_valid(card_view):
		return
	var label := _create_keyword_label(card_view, text)
	label.add_theme_color_override("font_color", color)
	_animate_exclamation(label)

func _animate_exclamation(label: Label) -> void:
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", -44.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_property(label, "position:y", -68.0, 0.32) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.32) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

func animate_downgrade(card_view: CardView, direction: Vector2) -> Signal:
	_prepare_card(card_view)
	var original_modulate := card_view.modulate
	var original_scale := card_view.scale
	var downgrade_label := _create_keyword_label(card_view, "Downgrade!")

	var duration := randf_range(0.7, 0.85)
	var viewport_size := get_viewport().get_visible_rect().size
	var travel_distance := viewport_size.x + card_view.size.x * 1.5
	var natural_direction := direction.normalized()
	natural_direction.y += randf_range(-0.08, 0.08)
	var target_position := card_view.global_position + natural_direction * travel_distance
	target_position.y += randf_range(-35.0, 35.0)

	var rotation_amount := deg_to_rad(randf_range(18.0, 32.0))
	if direction.x < 0.0:
		rotation_amount *= -1.0

	var tween := create_tween()
	# A short uneven fade creates a dissolve-like breakup without an overlay.
	tween.tween_property(card_view, "modulate:a", 0.62, 0.055)
	tween.parallel().tween_property(downgrade_label, "modulate:a", 1.0, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(downgrade_label, "position:y", -34.0, 0.11) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_view, "modulate:a", 0.28, 0.055)
	tween.parallel().tween_property(card_view, "scale", Vector2(1.035, 0.965), 0.055)
	tween.tween_property(card_view, "modulate:a", 0.0, 0.085) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		card_view.render()
		card_view.modulate = Color(original_modulate.r, original_modulate.g, original_modulate.b, 0.0)
		card_view.scale = Vector2(0.96, 1.04)
	)
	tween.tween_property(card_view, "modulate:a", original_modulate.a, 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "scale", original_scale, 0.13) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(downgrade_label, "position:y", -62.0, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(downgrade_label, "modulate:a", 0.0, 0.4) \
		.set_delay(0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(card_view, "global_position", target_position, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		card_view,
		"rotation",
		card_view.rotation + rotation_amount,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(card_view, "scale", Vector2(0.93, 0.93), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween.finished

func animate_fragile(card_view: Control) -> Signal:
	_prepare_card(card_view)

	var fragile_label := _create_keyword_label(card_view, "Fragile!")

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
	tween.tween_property(card_view, "scale", Vector2(1.22, 1.22), 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "modulate:a", 0.0, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(fragile_label, "position:y", -58.0, 0.56) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fragile_label, "modulate:a", 0.0, 0.5) \
		.set_delay(0.12) \
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

func _create_keyword_label(card_view: Control, text: String) -> Label:
	var keyword := text.trim_suffix("!")
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override(
		"font_color",
		Color(EffectKeyword.get_color(keyword))
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(card_view.size.x, 32.0)
	label.position = Vector2(0.0, -12.0)
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_view.add_child(label)
	return label
