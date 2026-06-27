extends Control

const GAME_SCENE_PATH := "res://scenes/main/Main.tscn"
const SHOP_SCENE_PATH := "res://scenes/main/Shop.tscn"
const HOVER_SCALE := Vector2(1.08, 1.08)
const PRESSED_SCALE := Vector2(0.94, 0.94)
const NORMAL_SCALE := Vector2.ONE
const LOADING_FADE_DURATION := 0.28
const LOADING_HOLD_DURATION := 0.18
const SPINNER_SIZE := Vector2(190, 190)
const SILHOUETTE_SIZE := Vector2(56, 56)
const SILHOUETTE_TEXTURES := [
	"res://assets/ui/silhouette-rock.png",
	"res://assets/ui/silhouette-paper.png",
	"res://assets/ui/silhouette-scissor.png",
]

@onready var _play_button: Button = %PlayButton
@onready var _play_frame: PixelFramePanel = %PlayFrame
@onready var _shop_button: Button = %ShopButton
@onready var _shop_frame: PixelFramePanel = %ShopFrame

var _button_tweens: Dictionary = {}
var _spinner_tween: Tween
var _loading_layer: CanvasLayer
var _loading_overlay: ColorRect
var _loading_label: Label
var _loading_spinner: Control


func _ready() -> void:
	_create_loading_overlay()
	_play_button.grab_focus()
	_setup_menu_button(_play_button, _play_frame)
	_setup_menu_button(_shop_button, _shop_frame)
	_play_button.pressed.connect(_on_play_button_pressed)
	_shop_button.pressed.connect(_on_shop_button_pressed)


func _on_play_button_pressed() -> void:
	_play_sfx("click")
	_play_button.disabled = true
	_shop_button.disabled = true
	_tween_button_frame(_play_frame, Vector2(1.12, 1.12), 0.09)
	await _show_loading_screen()
	await _switch_to_gameplay()


func _on_shop_button_pressed() -> void:
	_play_sfx("click")
	_play_button.disabled = true
	_shop_button.disabled = true
	_tween_button_frame(_shop_frame, Vector2(1.12, 1.12), 0.09)
	get_tree().change_scene_to_file(SHOP_SCENE_PATH)


func _setup_menu_button(button: Button, frame: PixelFramePanel) -> void:
	frame.pivot_offset = frame.size * 0.5
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	button.mouse_entered.connect(_tween_button_frame.bind(frame, HOVER_SCALE, 0.12))
	button.mouse_exited.connect(_on_menu_button_mouse_exited.bind(button, frame))
	button.button_down.connect(_tween_button_frame.bind(frame, PRESSED_SCALE, 0.06))
	button.button_up.connect(_on_menu_button_up.bind(button, frame))


func _on_menu_button_mouse_exited(button: Button, frame: PixelFramePanel) -> void:
	if button.button_pressed:
		return
	_tween_button_frame(frame, NORMAL_SCALE, 0.12)


func _on_menu_button_up(button: Button, frame: PixelFramePanel) -> void:
	var target_scale := HOVER_SCALE if button.is_hovered() else NORMAL_SCALE
	_tween_button_frame(frame, target_scale, 0.1)


func _create_loading_overlay() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.name = "LoadingLayer"
	_loading_layer.layer = 128
	add_child(_loading_layer)

	_loading_overlay = ColorRect.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_overlay.color = Color(0.008, 0.015, 0.014, 1.0)
	_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.modulate.a = 0.0
	_loading_overlay.visible = false
	_loading_layer.add_child(_loading_overlay)

	_create_loading_spinner()

	_loading_label = Label.new()
	_loading_label.name = "LoadingLabel"
	_loading_label.text = "LOADING"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 34)
	_loading_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1.0))
	_loading_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	_loading_label.add_theme_constant_override("shadow_offset_x", 0)
	_loading_label.add_theme_constant_override("shadow_offset_y", 4)
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.position.y = 48.0
	_loading_overlay.add_child(_loading_label)


func _create_loading_spinner() -> void:
	_loading_spinner = Control.new()
	_loading_spinner.name = "SilhouetteSpinner"
	_loading_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_spinner.set_anchors_preset(Control.PRESET_CENTER)
	_loading_spinner.offset_left = -SPINNER_SIZE.x * 0.5
	_loading_spinner.offset_top = -SPINNER_SIZE.y * 0.5 - 82.0
	_loading_spinner.offset_right = SPINNER_SIZE.x * 0.5
	_loading_spinner.offset_bottom = SPINNER_SIZE.y * 0.5 - 82.0
	_loading_spinner.pivot_offset = SPINNER_SIZE * 0.5
	_loading_overlay.add_child(_loading_spinner)

	var center := SPINNER_SIZE * 0.5
	var radius := 58.0
	var silhouette_tint := Color(1.0, 0.9, 0.55, 0.78)
	for index in SILHOUETTE_TEXTURES.size():
		var icon := TextureRect.new()
		icon.name = "Silhouette%d" % index
		icon.texture = load(SILHOUETTE_TEXTURES[index])
		icon.custom_minimum_size = SILHOUETTE_SIZE
		icon.size = SILHOUETTE_SIZE
		icon.pivot_offset = SILHOUETTE_SIZE * 0.5
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = silhouette_tint
		var angle := -PI * 0.5 + TAU * float(index) / float(SILHOUETTE_TEXTURES.size())
		icon.position = center + Vector2(cos(angle), sin(angle)) * radius - SILHOUETTE_SIZE * 0.5
		_loading_spinner.add_child(icon)

		var icon_tween := create_tween()
		icon_tween.set_loops()
		icon_tween.tween_property(icon, "rotation", -TAU, 1.65) \
			.set_trans(Tween.TRANS_LINEAR) \
			.set_ease(Tween.EASE_IN_OUT)

	_spinner_tween = create_tween()
	_spinner_tween.set_loops()
	_spinner_tween.tween_property(_loading_spinner, "rotation", TAU, 1.9) \
		.set_trans(Tween.TRANS_LINEAR) \
		.set_ease(Tween.EASE_IN_OUT)


func _show_loading_screen() -> void:
	_loading_overlay.visible = true
	_loading_overlay.modulate.a = 0.0
	_loading_label.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_loading_overlay, "modulate:a", 1.0, LOADING_FADE_DURATION) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_loading_label, "modulate:a", 1.0, LOADING_FADE_DURATION * 0.9) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(LOADING_HOLD_DURATION).timeout


func _switch_to_gameplay() -> void:
	var packed_scene := load(GAME_SCENE_PATH) as PackedScene
	if not packed_scene:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
		return

	var gameplay_scene := packed_scene.instantiate()
	var tree := get_tree()
	tree.root.add_child(gameplay_scene)
	tree.current_scene = gameplay_scene
	await tree.process_frame
	await tree.process_frame
	_loading_layer.queue_free()
	queue_free()


func _tween_button_frame(frame: PixelFramePanel, target_scale: Vector2, duration: float) -> void:
	if _button_tweens.has(frame):
		var old_tween := _button_tweens[frame] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	tween.tween_property(frame, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_button_tweens[frame] = tween


func _play_sfx(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	var manager: Node = get_tree().get_first_node_in_group("sfx_manager")
	if manager:
		manager.play_sfx(sfx_name, volume_offset_db)
