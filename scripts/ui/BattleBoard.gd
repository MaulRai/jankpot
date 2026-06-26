class_name BattleBoard
extends Control

const MAX_HEALTH := 6
const BLEED_KEYWORD := "Bleed"

@onready var player_hearts: HBoxContainer = %PlayerHearts
@onready var enemy_hearts: HBoxContainer = %EnemyHearts
@onready var player_bleed_status: Label = %PlayerBleedStatus
@onready var enemy_bleed_status: Label = %EnemyBleedStatus

var tooltip_manager: TooltipManager
var _heart_texture: Texture2D = preload("res://assets/ui/heart.png")


func _ready() -> void:
	_build_heart_row(player_hearts)
	_build_heart_row(enemy_hearts)
	set_health(MAX_HEALTH, MAX_HEALTH)
	set_bleed_status(false, false)
	_connect_status_hover(player_bleed_status)
	_connect_status_hover(enemy_bleed_status)


func set_tooltip_manager(manager: TooltipManager) -> void:
	tooltip_manager = manager


func set_health(player_health: int, enemy_health: int) -> void:
	_update_heart_row(player_hearts, player_health)
	_update_heart_row(enemy_hearts, enemy_health)


func set_bleed_status(player_bleeding: bool, enemy_bleeding: bool) -> void:
	player_bleed_status.visible = player_bleeding
	enemy_bleed_status.visible = enemy_bleeding


func animate_heart_loss(is_player: bool, health_after_damage: int) -> void:
	var container := player_hearts if is_player else enemy_hearts
	var heart_index := clampi(health_after_damage, 0, MAX_HEALTH - 1)
	if heart_index >= container.get_child_count():
		return

	var source_heart := container.get_child(heart_index) as TextureRect
	if not source_heart:
		return

	var falling_heart := TextureRect.new()
	falling_heart.texture = source_heart.texture
	falling_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	falling_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	falling_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	falling_heart.size = source_heart.size
	falling_heart.pivot_offset = falling_heart.size * 0.5
	get_tree().current_scene.add_child(falling_heart)
	falling_heart.global_position = source_heart.global_position
	falling_heart.z_index = 2500

	source_heart.modulate = Color(0.16, 0.17, 0.2, 0.5)

	var direction := -1.0 if is_player else 1.0
	var jump_position := falling_heart.global_position + Vector2(direction * 7.0, -22.0)
	var fall_position := Vector2(
		falling_heart.global_position.x + direction * randf_range(28.0, 55.0),
		get_viewport_rect().size.y + falling_heart.size.y + 30.0
	)

	var tween := create_tween()
	tween.tween_property(falling_heart, "global_position", jump_position, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		falling_heart,
		"rotation_degrees",
		direction * randf_range(8.0, 15.0),
		0.16
	)
	tween.tween_property(falling_heart, "global_position", fall_position, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		falling_heart,
		"rotation_degrees",
		direction * randf_range(28.0, 42.0),
		0.5
	)
	tween.parallel().tween_property(falling_heart, "modulate:a", 0.15, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	falling_heart.queue_free()
	_update_heart_row(container, health_after_damage)


func _build_heart_row(container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	for i in range(MAX_HEALTH):
		var heart := TextureRect.new()
		heart.custom_minimum_size = Vector2(24.0, 20.0)
		heart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heart.texture = _heart_texture
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(heart)


func _update_heart_row(container: HBoxContainer, health: int) -> void:
	var clamped_health := clampi(health, 0, MAX_HEALTH)
	for i in range(container.get_child_count()):
		var heart := container.get_child(i) as TextureRect
		if heart:
			heart.visible = true
			heart.modulate = Color.WHITE if i < clamped_health else Color(0.16, 0.17, 0.2, 0.5)


func _connect_status_hover(status_label: Label) -> void:
	status_label.mouse_filter = Control.MOUSE_FILTER_STOP
	status_label.mouse_entered.connect(_show_bleed_tooltip.bind(status_label))
	status_label.mouse_exited.connect(_hide_bleed_tooltip)


func _show_bleed_tooltip(status_label: Label) -> void:
	if tooltip_manager:
		tooltip_manager.show_tooltip(
			[BLEED_KEYWORD],
			status_label.global_position + Vector2(status_label.size.x + 10.0, -6.0)
		)


func _hide_bleed_tooltip() -> void:
	if tooltip_manager:
		tooltip_manager.hide_tooltip()
