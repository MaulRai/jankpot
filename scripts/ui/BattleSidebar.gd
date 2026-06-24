class_name BattleSidebar
extends Panel

const MAX_HEALTH := 6

@onready var enemy_hearts: HBoxContainer = %EnemyHearts
@onready var player_hearts: HBoxContainer = %PlayerHearts
@onready var trial_value: Label = %TrialValue
@onready var clash_value: Label = %ClashValue

var _heart_texture: Texture2D = preload("res://assets/ui/heart.png")

func _ready() -> void:
	_build_heart_row(enemy_hearts)
	_build_heart_row(player_hearts)
	set_health(MAX_HEALTH, MAX_HEALTH)

func set_health(player_health: int, enemy_health: int) -> void:
	_update_heart_row(player_hearts, player_health)
	_update_heart_row(enemy_hearts, enemy_health)

func set_progress(trial_current: int, trial_total: int, clash: int) -> void:
	trial_value.text = "%d / %d" % [trial_current, trial_total]
	clash_value.text = str(clash)

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

	# Keep an empty dark heart in the bar while its colored copy falls away.
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
