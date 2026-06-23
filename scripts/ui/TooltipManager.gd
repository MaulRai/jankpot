class_name TooltipManager
extends Control

@export var tooltip_scene: PackedScene

var active_tooltip: Control = null

func show_tooltip(keywords: Array[String], position: Vector2) -> void:
	hide_tooltip()
	if not tooltip_scene:
		return
	active_tooltip = tooltip_scene.instantiate()
	var text := ""
	for kw in keywords:
		var desc := EffectKeyword.get_description(kw)
		if desc:
			text += "[color=%s]%s[/color]: %s\n" % [EffectKeyword.get_color(kw), kw, desc]
	var rich_label := active_tooltip.get_node_or_null("RichTextLabel") as RichTextLabel
	if rich_label:
		rich_label.text = text.strip_edges()
	add_child(active_tooltip)
	active_tooltip.position = position
	active_tooltip.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(active_tooltip, "modulate:a", 1.0, 0.1)

func hide_tooltip() -> void:
	if active_tooltip:
		active_tooltip.queue_free()
		active_tooltip = null
