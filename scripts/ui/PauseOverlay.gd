class_name PauseOverlay
extends Control

signal resume_requested
signal main_menu_requested
signal try_again_requested
signal save_requested
signal abandon_requested

const HOVER_SCALE := Vector2(1.08, 1.08)
const PRESSED_SCALE := Vector2(0.94, 0.94)
const NORMAL_SCALE := Vector2.ONE
const MODE_PAUSE := "pause"
const MODE_DEFEAT := "defeat"
const MODE_VICTORY := "victory"
const PANEL_TEXTURE := preload("res://assets/ui/panel-window.png")
const PIXEL_FRAME_SCRIPT := preload("res://scripts/ui/PixelFramePanel.gd")
const STAR_CRUSH_FONT := preload("res://fonts/Star Crush.otf")

@onready var dim: ColorRect = %Dim
@onready var pause_window: Control = %PauseWindow
@onready var title: Label = %Title
@onready var reward_info: Label = %RewardInfo
@onready var resume_frame: PixelFramePanel = %ResumeFrame
@onready var main_menu_frame: PixelFramePanel = %MainMenuFrame
@onready var resume_button: Button = %ResumeButton
@onready var main_menu_button: Button = %MainMenuButton

var _window_base_position := Vector2.ZERO
var _confirm_window_base_position := Vector2.ZERO
var _button_tweens: Dictionary = {}
var _overlay_tween: Tween
var _is_open := false
var _mode := MODE_PAUSE
var _victory_money := 0
var _defeat_money := 0
var _confirm_layer: CanvasLayer
var _confirm_panel: Control
var _confirm_window: Control
var _confirm_tween: Tween
var _confirm_open := false
var _confirm_button_frames: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window_base_position = pause_window.position
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_button(resume_button, resume_frame)
	_setup_button(main_menu_button, main_menu_frame)
	resume_button.pressed.connect(_on_primary_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	_build_confirm_modal()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_confirm_cancel_pressed()


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


func open_defeat_with_money(money_earned: int) -> void:
	_defeat_money = maxi(0, money_earned)
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
		if _defeat_money > 0:
			reward_info.text = "Cashed out $%d" % _defeat_money
			reward_info.visible = true
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


func _on_main_menu_pressed() -> void:
	_play_sfx("click")
	if _mode == MODE_PAUSE:
		_open_confirm()
	else:
		main_menu_requested.emit()


func _build_confirm_modal() -> void:
	_confirm_layer = CanvasLayer.new()
	_confirm_layer.name = "ConfirmLayer"
	_confirm_layer.layer = 970
	_confirm_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_confirm_layer)

	var root := Control.new()
	root.name = "ConfirmRoot"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	_confirm_layer.add_child(root)
	_confirm_panel = root

	var dim := ColorRect.new()
	dim.name = "ConfirmDim"
	dim.color = Color(0.005, 0.009, 0.011, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var window := Control.new()
	window.name = "ConfirmWindow"
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.offset_left = -320.0
	window.offset_top = -240.0
	window.offset_right = 320.0
	window.offset_bottom = 240.0
	root.add_child(window)
	_confirm_window = window

	var panel_image := TextureRect.new()
	panel_image.texture = PANEL_TEXTURE
	panel_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_image.stretch_mode = TextureRect.STRETCH_SCALE
	window.add_child(panel_image)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -250.0
	content.offset_top = -160.0
	content.offset_right = 250.0
	content.offset_bottom = 160.0
	content.add_theme_constant_override("separation", 22)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	window.add_child(content)

	var heading := Label.new()
	heading.text = "ARE YOU SURE?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", STAR_CRUSH_FONT)
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1.0))
	heading.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	heading.add_theme_constant_override("shadow_offset_y", 4)
	content.add_child(heading)

	var subtext := Label.new()
	subtext.text = "Save to resume later, or\nabandon and cash out."
	subtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtext.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtext.add_theme_font_override("font", STAR_CRUSH_FONT)
	subtext.add_theme_font_size_override("font_size", 18)
	subtext.add_theme_color_override("font_color", Color(0.9, 0.86, 0.7, 0.85))
	subtext.add_theme_constant_override("line_spacing", 2)
	content.add_child(subtext)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	content.add_child(button_row)

	var save_frame := _make_confirm_button("SAVE")
	button_row.add_child(save_frame)
	var save_button := save_frame.get_child(0) as Button
	save_button.pressed.connect(_on_confirm_save_pressed)

	var abandon_frame := _make_confirm_button("ABANDON")
	button_row.add_child(abandon_frame)
	var abandon_button := abandon_frame.get_child(0) as Button
	abandon_button.pressed.connect(_on_confirm_abandon_pressed)

	var cancel_frame := _make_confirm_button("CANCEL")
	content.add_child(cancel_frame)
	var cancel_button := cancel_frame.get_child(0) as Button
	cancel_button.pressed.connect(_on_confirm_cancel_pressed)


func _make_confirm_button(label: String) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(240, 66)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var empty_style := StyleBoxEmpty.new()
	frame.add_theme_stylebox_override("panel", empty_style)
	frame.set_script(PIXEL_FRAME_SCRIPT)
	frame.set("base_tint", Color(0.12, 0.07, 0.12, 1))
	frame.set("frame_outline_tint", Color(1, 0.86, 0.42, 1))
	frame.set("base_outline_tint", Color(0.26, 0.12, 0.2, 1))
	frame.set("base_fill_tint", Color(0.12, 0.07, 0.12, 1))
	frame.set("component_scale", 2.0)
	frame.set("top_right_corner_variant", 1)
	frame.pivot_offset = frame.custom_minimum_size * 0.5

	var button := Button.new()
	button.text = label
	button.flat = true
	button.add_theme_font_override("font", STAR_CRUSH_FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.82, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 0.68, 0.3, 1.0))
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	frame.add_child(button)

	_confirm_button_frames[button] = frame
	_setup_confirm_button(button, frame)

	return frame


func _setup_confirm_button(button: Button, frame: PanelContainer) -> void:
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	button.mouse_entered.connect(_tween_confirm_button_frame.bind(frame, HOVER_SCALE, 0.12))
	button.mouse_exited.connect(_on_confirm_button_mouse_exited.bind(button, frame))
	button.button_down.connect(_tween_confirm_button_frame.bind(frame, PRESSED_SCALE, 0.06))
	button.button_up.connect(_on_confirm_button_up.bind(button, frame))


func _on_confirm_button_mouse_exited(button: Button, frame: PanelContainer) -> void:
	if button.button_pressed:
		return
	_tween_confirm_button_frame(frame, NORMAL_SCALE, 0.12)


func _on_confirm_button_up(button: Button, frame: PanelContainer) -> void:
	var target_scale := HOVER_SCALE if button.is_hovered() else NORMAL_SCALE
	_tween_confirm_button_frame(frame, target_scale, 0.1)


func _tween_confirm_button_frame(frame: PanelContainer, target_scale: Vector2, duration: float) -> void:
	if _button_tweens.has(frame):
		var old_tween := _button_tweens[frame] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	tween.tween_property(frame, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tweens[frame] = tween


func _open_confirm() -> void:
	if _confirm_open:
		return
	_confirm_open = true
	_confirm_panel.visible = true
	_confirm_panel.modulate.a = 0.0
	if _confirm_window_base_position == Vector2.ZERO:
		_confirm_window_base_position = _confirm_window.position
	_confirm_window.position = _confirm_window_base_position + Vector2(0.0, get_viewport_rect().size.y)
	_confirm_window.scale = Vector2(0.96, 0.96)
	if _confirm_tween and _confirm_tween.is_valid():
		_confirm_tween.kill()
	_confirm_tween = create_tween()
	_confirm_tween.set_parallel(true)
	_confirm_tween.tween_property(_confirm_panel, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_confirm_tween.tween_property(_confirm_window, "position", _confirm_window_base_position, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_confirm_tween.tween_property(_confirm_window, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_confirm() -> void:
	if not _confirm_open:
		return
	_confirm_open = false
	if _confirm_tween and _confirm_tween.is_valid():
		_confirm_tween.kill()
	_confirm_tween = create_tween()
	_confirm_tween.set_parallel(true)
	_confirm_tween.tween_property(_confirm_panel, "modulate:a", 0.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_confirm_tween.tween_property(
		_confirm_window,
		"position",
		_confirm_window_base_position + Vector2(0.0, get_viewport_rect().size.y),
		0.24
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_confirm_tween.tween_property(_confirm_window, "scale", Vector2(0.96, 0.96), 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _confirm_tween.finished
	_confirm_panel.visible = false
	_confirm_window.position = _confirm_window_base_position
	_confirm_window.scale = Vector2.ONE


func _on_confirm_save_pressed() -> void:
	_play_sfx("click")
	_close_confirm()
	save_requested.emit()


func _on_confirm_abandon_pressed() -> void:
	_play_sfx("click")
	_close_confirm()
	abandon_requested.emit()


func _on_confirm_cancel_pressed() -> void:
	_play_sfx("click")
	_close_confirm()
