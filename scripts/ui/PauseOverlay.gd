class_name PauseOverlay
extends Control

signal resume_requested
signal main_menu_requested
signal try_again_requested

const HOVER_SCALE := Vector2(1.08, 1.08)
const PRESSED_SCALE := Vector2(0.94, 0.94)
const NORMAL_SCALE := Vector2.ONE
const MODE_PAUSE := "pause"
const MODE_DEFEAT := "defeat"
const MODE_VICTORY := "victory"

@onready var dim: ColorRect = %Dim
@onready var pause_window: Control = %PauseWindow
@onready var title: Label = %Title
@onready var reward_info: Label = %RewardInfo
@onready var resume_frame: PixelFramePanel = %ResumeFrame
@onready var main_menu_frame: PixelFramePanel = %MainMenuFrame
@onready var resume_button: Button = %ResumeButton
@onready var main_menu_button: Button = %MainMenuButton

var _window_base_position := Vector2.ZERO
var _button_tweens: Dictionary = {}
var _overlay_tween: Tween
var _is_open := false
var _mode := MODE_PAUSE
var _victory_money := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window_base_position = pause_window.position
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_button(resume_button, resume_frame)
	_setup_button(main_menu_button, main_menu_frame)
	resume_button.pressed.connect(_on_primary_pressed)
	main_menu_button.pressed.connect(func() -> void:
		_play_sfx("click")
		main_menu_requested.emit()
	)


func is_open() -> bool:
	return _is_open


func can_resume() -> bool:
	return _is_open and _mode == MODE_PAUSE


func open_pause() -> void:
	_apply_mode(MODE_PAUSE)
	await _open()


func open_defeat() -> void:
	_apply_mode(MODE_DEFEAT)
	await _open()


func open_victory(money_earned: int) -> void:
	_victory_money = maxi(0, money_earned)
	_apply_mode(MODE_VICTORY)
	await _open()


func _open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	dim.modulate.a = 0.0
	pause_window.position = _window_base_position + Vector2(0.0, get_viewport_rect().size.y)
	pause_window.scale = Vector2(0.96, 0.96)

	_kill_overlay_tween()
	_overlay_tween = create_tween()
	_overlay_tween.set_parallel(true)
	_overlay_tween.tween_property(dim, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_overlay_tween.tween_property(pause_window, "position", _window_base_position, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_overlay_tween.tween_property(pause_window, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _overlay_tween.finished


func close_pause() -> void:
	if not _is_open:
		return
	_is_open = false
	_kill_overlay_tween()
	_overlay_tween = create_tween()
	_overlay_tween.set_parallel(true)
	_overlay_tween.tween_property(dim, "modulate:a", 0.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_overlay_tween.tween_property(
		pause_window,
		"position",
		_window_base_position + Vector2(0.0, get_viewport_rect().size.y),
		0.24
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_overlay_tween.tween_property(pause_window, "scale", Vector2(0.96, 0.96), 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _overlay_tween.finished
	visible = false
	pause_window.position = _window_base_position
	pause_window.scale = Vector2.ONE


func _apply_mode(mode: String) -> void:
	_mode = mode
	reward_info.visible = false
	resume_frame.visible = true
	if mode == MODE_DEFEAT:
		title.text = "DEFEAT"
		resume_button.text = "TRY AGAIN"
		main_menu_button.text = "MAIN MENU"
		return
	if mode == MODE_VICTORY:
		title.text = "VICTORY"
		reward_info.text = "Earned $%d" % _victory_money
		reward_info.visible = true
		resume_frame.visible = false
		main_menu_button.text = "MAIN MENU"
		return
	title.text = "PAUSED"
	resume_button.text = "RESUME"
	main_menu_button.text = "MAIN MENU"


func _on_primary_pressed() -> void:
	_play_sfx("click")
	if _mode == MODE_DEFEAT:
		try_again_requested.emit()
	else:
		resume_requested.emit()


func _setup_button(button: Button, frame: PixelFramePanel) -> void:
	frame.pivot_offset = frame.size * 0.5
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	button.mouse_entered.connect(_tween_button_frame.bind(frame, HOVER_SCALE, 0.12))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button, frame))
	button.button_down.connect(_tween_button_frame.bind(frame, PRESSED_SCALE, 0.06))
	button.button_up.connect(_on_button_up.bind(button, frame))


func _on_button_mouse_exited(button: Button, frame: PixelFramePanel) -> void:
	if button.button_pressed:
		return
	_tween_button_frame(frame, NORMAL_SCALE, 0.12)


func _on_button_up(button: Button, frame: PixelFramePanel) -> void:
	var target_scale := HOVER_SCALE if button.is_hovered() else NORMAL_SCALE
	_tween_button_frame(frame, target_scale, 0.1)


func _tween_button_frame(frame: PixelFramePanel, target_scale: Vector2, duration: float) -> void:
	if _button_tweens.has(frame):
		var old_tween := _button_tweens[frame] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	tween.tween_property(frame, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tweens[frame] = tween


func _kill_overlay_tween() -> void:
	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_overlay_tween = null


func _play_sfx(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	var manager: Node = get_tree().get_first_node_in_group("sfx_manager")
	if manager:
		manager.play_sfx(sfx_name, volume_offset_db)
