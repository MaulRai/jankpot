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
			heart.modulate = Color.WHITE if i < clamped_health else Color(0.22, 0.24, 0.28, 0.38)
