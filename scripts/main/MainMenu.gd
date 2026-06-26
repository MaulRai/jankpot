extends Control

const GAME_SCENE_PATH := "res://scenes/main/Main.tscn"
const HOVER_SCALE := Vector2(1.08, 1.08)
const PRESSED_SCALE := Vector2(0.94, 0.94)
const NORMAL_SCALE := Vector2.ONE

@onready var _play_button: Button = %PlayButton
@onready var _play_frame: PixelFramePanel = %PlayFrame

var _button_tween: Tween


func _ready() -> void:
	_play_button.grab_focus()
	_play_frame.pivot_offset = _play_frame.size * 0.5
	_play_frame.resized.connect(_center_play_frame_pivot)
	_play_button.mouse_entered.connect(_on_play_button_mouse_entered)
	_play_button.mouse_exited.connect(_on_play_button_mouse_exited)
	_play_button.button_down.connect(_on_play_button_down)
	_play_button.button_up.connect(_on_play_button_up)
	_play_button.pressed.connect(_on_play_button_pressed)


func _center_play_frame_pivot() -> void:
	_play_frame.pivot_offset = _play_frame.size * 0.5


func _on_play_button_mouse_entered() -> void:
	_tween_play_frame(HOVER_SCALE, 0.12)


func _on_play_button_mouse_exited() -> void:
	if _play_button.button_pressed:
		return
	_tween_play_frame(NORMAL_SCALE, 0.12)


func _on_play_button_down() -> void:
	_tween_play_frame(PRESSED_SCALE, 0.06)


func _on_play_button_up() -> void:
	var target_scale := HOVER_SCALE if _play_button.is_hovered() else NORMAL_SCALE
	_tween_play_frame(target_scale, 0.1)


func _on_play_button_pressed() -> void:
	_play_button.disabled = true
	_tween_play_frame(Vector2(1.12, 1.12), 0.09)
	await get_tree().create_timer(0.12).timeout
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _tween_play_frame(target_scale: Vector2, duration: float) -> void:
	if _button_tween:
		_button_tween.kill()
	_button_tween = create_tween()
	_button_tween.tween_property(_play_frame, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
