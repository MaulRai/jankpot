class_name TooltipManager
extends Control

@export var tooltip_scene: PackedScene

var active_tooltip: Control = null

func show_tooltip(keywords: Array[String], position: Vector2) -> void:
	hide_tooltip()
	if not tooltip_scene or keywords.is_empty():
		return
	active_tooltip = tooltip_scene.instantiate()
	var text := ""
	for kw in keywords:
		var desc := EffectKeyword.get_description(kw)
		if desc:
			text += "[color=%s]%s[/color]: %s\n" % [EffectKeyword.get_color(kw), kw, desc]
	var rich_label := active_tooltip.get_node_or_null("Panel/RichTextLabel") as RichTextLabel
	if rich_label:
		rich_label.text = text.strip_edges()
	if text.is_empty():
		active_tooltip.queue_free()
		active_tooltip = null
		return
	add_child(active_tooltip)
	var local_position := get_global_transform().affine_inverse() * position
	var tooltip_size := active_tooltip.size
	var viewport_size := get_viewport_rect().size
	local_position.x = clampf(local_position.x, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0))
	local_position.y = clampf(local_position.y, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0))
	active_tooltip.position = local_position
	active_tooltip.z_index = 2600
	active_tooltip.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(active_tooltip, "modulate:a", 1.0, 0.1)

func hide_tooltip() -> void:
	if active_tooltip:
		if active_tooltip.get_parent() == self:
			remove_child(active_tooltip)
		active_tooltip.queue_free()
		active_tooltip = null
