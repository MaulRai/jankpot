extends Control

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")
const PackOpeningScript := preload("res://scripts/main/PackOpening.gd")

const MAIN_MENU_SCENE_PATH := "res://scenes/main/MainMenu.tscn"
const RESET_SECONDS        := 60 * 60 * 3
const HOVER_SCALE          := Vector2(1.06, 1.06)
const PRESS_SCALE          := Vector2(0.95, 0.95)

const STAR_CRUSH_FONT    := preload("res://fonts/Star Crush.ttf")
const BASIC_PACK_TEXTURE := preload("res://assets/item/pack/basic-weapon-card-pack.png")
const PREMIUM_PACK_TEXTURE := preload("res://assets/item/pack/premium-weapon-card-pack.png")
const SHOP_DISPLAY_TEXTURE := preload("res://assets/ui/shop-display.png")
const MAGIC_BALL_TEXTURE := preload("res://assets/item/magic-ball.png")
const SHIELD_TEXTURE     := preload("res://assets/item/shield.png")
const REMEDY_KIT_TEXTURE := preload("res://assets/item/remedy-kit.png")
const CUP_A_JOE_TEXTURE  := preload("res://assets/item/cup-a-joe.png")

@onready var _offers_grid:  GridContainer  = %OffersGrid
@onready var _reset_label:  Label          = %ResetLabel
@onready var _back_button:  Button         = %BackButton
@onready var _back_frame:   PixelFramePanel = %BackFrame
@onready var _timer:        Timer          = %CountdownTimer

var _frame_tweens: Dictionary = {}
var _pack_opening: Control


func _ready() -> void:
	_pack_opening = PackOpeningScript.new()
	_pack_opening.initialise(self)

	_setup_frame_button(_back_button, _back_frame)
	_back_button.pressed.connect(
		func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	)
	_timer.timeout.connect(_update_reset_label)
	_populate_shop()
	_update_reset_label()


func _unhandled_input(event: InputEvent) -> void:
	_pack_opening.handle_unhandled_input(event)

func _populate_shop() -> void:
	for child in _offers_grid.get_children():
		child.queue_free()

	_offers_grid.add_child(_create_offer({
		"name":        "Basic Weapon Pack",
		"price":       8,
		"description": "A humble pack with a steady chance for stronger weapons.",
		"texture":     BASIC_PACK_TEXTURE,
		"kind":        "pack",
		"pack_id":     "basic",
	}))
	_offers_grid.add_child(_create_offer({
		"name":        "Premium Pack",
		"price":       15,
		"description": "A finer pack with better odds for unusual weapons.",
		"texture":     PREMIUM_PACK_TEXTURE,
		"kind":        "pack",
		"pack_id":     "premium",
	}))
	for item in _rotating_consumables():
		_offers_grid.add_child(_create_offer(item))


func _rotating_consumables() -> Array:
	var pool   := _all_consumables()
	var chosen : Array = []
	var rng    := RandomNumberGenerator.new()
	rng.seed = _current_reset_block() * 7919 + 31
	while chosen.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		chosen.append(pool[index])
		pool.remove_at(index)
	return chosen


func _all_consumables() -> Array:
	return [
		{ "name": "Magic Ball",  "price": 4, "description": "Predicts the enemy's next weapon.",  "texture": MAGIC_BALL_TEXTURE, "kind": "consumable" },
		{ "name": "Shield",      "price": 2, "description": "Blocks 1 DMG.",                      "texture": SHIELD_TEXTURE,     "kind": "consumable" },
		{ "name": "Remedy Kit",  "price": 2, "description": "Removes Bleed.",                     "texture": REMEDY_KIT_TEXTURE, "kind": "consumable" },
		{ "name": "Cup-a-Joe",   "price": 2, "description": "Win attacks twice this turn.",       "texture": CUP_A_JOE_TEXTURE,  "kind": "consumable" },
	]


func _create_offer(data: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(190.0, 300.0)
	card.add_theme_constant_override("separation", 8)

	# --- Display area (shop frame + item icon) ---
	var display_area := Control.new()
	display_area.custom_minimum_size = Vector2(190.0, 144.0)
	display_area.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	card.add_child(display_area)

	var display := TextureRect.new()
	display.texture        = SHOP_DISPLAY_TEXTURE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	display.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	display.offset_left  = -78.0
	display.offset_top   = -58.0
	display.offset_right =  78.0
	display.offset_bottom =  0.0
	display_area.add_child(display)

	var icon_size := Vector2(72.0, 72.0) if data.get("kind", "") == "consumable" else Vector2(86.0, 112.0)
	var icon := TextureRect.new()
	icon.texture        = data["texture"] as Texture2D
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left   = -icon_size.x * 0.5
	icon.offset_top    = -icon_size.y * 0.5 - 14.0
	icon.offset_right  =  icon_size.x * 0.5
	icon.offset_bottom =  icon_size.y * 0.5 - 14.0
	display_area.add_child(icon)

	var name_label := Label.new()
	name_label.text                = str(data["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.64, 1.0))
	card.add_child(name_label)

	# --- Description ---
	var description := Label.new()
	description.text                = str(data["description"])
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0.0, 42.0)
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.78, 0.86, 0.82, 1.0))
	card.add_child(description)

	# --- Buy button ---
	var buy_frame  := _create_button_frame()
	card.add_child(buy_frame)

	var buy_button := Button.new()
	buy_button.text = "$%d" % int(data["price"])
	buy_button.flat = true
	buy_button.add_theme_font_size_override("font_size", 21)
	buy_button.add_theme_color_override("font_color",         Color(1.0,  0.93, 0.62, 1.0))
	buy_button.add_theme_color_override("font_hover_color",   Color(1.0,  1.0,  0.82, 1.0))
	buy_button.add_theme_color_override("font_pressed_color", Color(0.86, 0.68, 0.3,  1.0))
	for style in ["normal", "hover", "pressed", "focus"]:
		buy_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	buy_frame.add_child(buy_button)
	_setup_frame_button(buy_button, buy_frame)
	buy_button.pressed.connect(_on_buy_pressed.bind(buy_button, buy_frame, data))

	return card


func _create_button_frame() -> PixelFramePanel:
	var frame := PixelFramePanel.new()
	frame.custom_minimum_size     = Vector2(132.0, 50.0)
	frame.size_flags_horizontal   = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.base_tint               = Color(0.12, 0.07, 0.12, 1.0)
	frame.frame_outline_tint      = Color(1.0,  0.86, 0.42, 1.0)
	frame.base_outline_tint       = Color(0.26, 0.12, 0.2,  1.0)
	frame.base_fill_tint          = Color(0.12, 0.07, 0.12, 1.0)
	frame.component_scale         = 1.5
	frame.top_right_corner_variant = PixelFramePanel.TopRightCornerVariant.SHINING
	return frame


func _setup_frame_button(button: Button, frame: PixelFramePanel) -> void:
	frame.pivot_offset = frame.size * 0.5
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	button.mouse_entered.connect(_tween_frame.bind(frame, HOVER_SCALE, 0.12))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button, frame))
	button.button_down.connect(_tween_frame.bind(frame, PRESS_SCALE, 0.06))
	button.button_up.connect(_on_button_up.bind(button, frame))


func _on_button_mouse_exited(button: Button, frame: PixelFramePanel) -> void:
	if not button.button_pressed:
		_tween_frame(frame, Vector2.ONE, 0.12)


func _on_button_up(button: Button, frame: PixelFramePanel) -> void:
	_tween_frame(frame, HOVER_SCALE if button.is_hovered() else Vector2.ONE, 0.1)


func _on_buy_pressed(button: Button, frame: PixelFramePanel, data: Dictionary) -> void:
	var price := int(data["price"])
	button.text = "BUY $%d" % price
	_tween_frame(frame, Vector2(1.12, 1.12), 0.08)
	await get_tree().create_timer(0.22).timeout
	if is_instance_valid(button):
		button.text = "$%d" % price
	if is_instance_valid(frame):
		_tween_frame(frame, HOVER_SCALE if button.is_hovered() else Vector2.ONE, 0.12)
	if data.get("kind", "") == "pack":
		await _pack_opening.start(str(data.get("pack_id", "basic")), data["texture"] as Texture2D)


func _tween_frame(frame: PixelFramePanel, target_scale: Vector2, duration: float) -> void:
	if _frame_tweens.has(frame):
		var old_tween := _frame_tweens[frame] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	tween.tween_property(frame, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_frame_tweens[frame] = tween

func _update_reset_label() -> void:
	var seconds_left := maxi(0,
		(_current_reset_block() + 1) * RESET_SECONDS - Time.get_unix_time_from_system()
	)
	_reset_label.text = "CONSUMABLES RESET IN %02d:%02d:%02d" % [
		seconds_left / 3600,
		(seconds_left % 3600) / 60,
		seconds_left % 60,
	]


func _current_reset_block() -> int:
	return int(Time.get_unix_time_from_system() / RESET_SECONDS)
