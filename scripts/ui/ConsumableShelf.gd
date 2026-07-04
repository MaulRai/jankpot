class_name ConsumableShelf
extends Control

const MAGIC_BALL_TEXTURE := preload("res://assets/item/magic-ball.png")
const SHIELD_TEXTURE := preload("res://assets/item/shield.png")
const REMEDY_KIT_TEXTURE := preload("res://assets/item/remedy-kit.png")
const CUP_A_JOE_TEXTURE := preload("res://assets/item/cup-a-joe.png")
const MOONLIGHT_TEXTURE := preload("res://assets/item/moonlight.png")
const SNAKE_OIL_TEXTURE := preload("res://assets/item/snake-oil.png")
const POCKETWATCH_TEXTURE := preload("res://assets/item/pocketwatch.png")
const VELVET_GLOVES_TEXTURE := preload("res://assets/item/velvet-gloves.png")

signal moonlight_requested
signal magic_ball_requested
signal shield_requested
signal remedy_kit_requested
signal cup_a_joe_requested
signal snake_oil_requested
signal pocketwatch_requested
signal velvet_gloves_requested

const MAX_ITEMS := 5
const CHAIN_SWAY_DEGREES := 2.2
const SHELF_SWAY_PIXELS := 3.0
const CHAIN_SWAY_DURATION := 1.8
const ITEM_HOVER_SCALE := Vector2(1.08, 1.08)
const ITEM_PRESS_SCALE := Vector2(0.92, 0.92)
const COMPLETE_POPUP_TEXT := "Complete"

@onready var slots: HBoxContainer = %Slots
@onready var shelf_body: Control = %ShelfBody
@onready var left_chain: TextureRect = %LeftChain
@onready var right_chain: TextureRect = %RightChain

var _buttons: Dictionary = {}
var _button_tweens: Dictionary = {}
var _complete_tween: Tween
var _complete_popup: Label

func _ready() -> void:
	_ensure_nodes_bound()
	_animate_chains()


func _ensure_nodes_bound() -> void:
	if not slots:
		slots = get_node_or_null("%Slots") as HBoxContainer
	if not shelf_body:
		shelf_body = get_node_or_null("%ShelfBody") as Control
	if not left_chain:
		left_chain = get_node_or_null("%LeftChain") as TextureRect
	if not right_chain:
		right_chain = get_node_or_null("%RightChain") as TextureRect

func add_magic_ball() -> bool:
	return _add_unique_consumable(
		&"magic_ball",
		MAGIC_BALL_TEXTURE,
		"Magic Ball\nOne use. Predicts the enemy's next weapon with 80% accuracy.",
		func() -> void: magic_ball_requested.emit()
	)

func add_shield() -> bool:
	return _add_unique_consumable(
		&"shield",
		SHIELD_TEXTURE,
		"Shield\nOne use. Blocks 1 DMG.",
		func() -> void: shield_requested.emit()
	)

func add_remedy_kit() -> bool:
	return _add_unique_consumable(
		&"remedy_kit",
		REMEDY_KIT_TEXTURE,
		"Remedy Kit\nOne use. Removes Ailments such as Bleed and Poison.",
		func() -> void: remedy_kit_requested.emit()
	)

func add_cup_a_joe() -> bool:
	return _add_unique_consumable(
		&"cup_a_joe",
		CUP_A_JOE_TEXTURE,
		"Cup-a-Joe\nThis turn, if your card wins, it executes twice.",
		func() -> void: cup_a_joe_requested.emit()
	)

func add_moonlight() -> bool:
	return _add_unique_consumable(
		&"moonlight",
		MOONLIGHT_TEXTURE,
		"Moonlight\n$2. Discard up to 2 cards, then draw that many.",
		func() -> void: moonlight_requested.emit()
	)

func add_snake_oil() -> bool:
	return _add_unique_consumable(
		&"snake_oil",
		SNAKE_OIL_TEXTURE,
		"Snake Oil\nInflict 1 poison. If lose twice in a row, inflict 2 instead.",
		func() -> void: snake_oil_requested.emit()
	)

func add_pocketwatch() -> bool:
	return _add_unique_consumable(
		&"pocketwatch",
		POCKETWATCH_TEXTURE,
		"Pocketwatch\nRaise Aegis for next turn every time you lose a clash. Lasts one trial.",
		func() -> void: pocketwatch_requested.emit()
	)

func add_velvet_gloves() -> bool:
	return _add_unique_consumable(
		&"velvet_gloves",
		VELVET_GLOVES_TEXTURE,
		"Velvet Gloves\nCherry pick a card from draw pile.",
		func() -> void: velvet_gloves_requested.emit()
	)

func consume_magic_ball() -> void:
	_consume(&"magic_ball")

func consume_shield() -> void:
	_consume(&"shield")

func consume_remedy_kit() -> void:
	_consume(&"remedy_kit")

func consume_cup_a_joe() -> void:
	_consume(&"cup_a_joe")

func consume_moonlight() -> void:
	_consume(&"moonlight")

func consume_snake_oil() -> void:
	_consume(&"snake_oil")

func consume_pocketwatch() -> void:
	_consume(&"pocketwatch")

func consume_velvet_gloves() -> void:
	_consume(&"velvet_gloves")

func show_level_complete(bonus_text := "") -> void:
	if _complete_tween and _complete_tween.is_valid():
		_complete_tween.kill()
	if _complete_popup and is_instance_valid(_complete_popup):
		_complete_popup.queue_free()
	var popup := Label.new()
	_complete_popup = popup
	popup.text = COMPLETE_POPUP_TEXT
	popup.z_index = 30
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_color_override("font_color", Color(1.0, 0.9, 0.48, 1.0))
	popup.add_theme_color_override("font_shadow_color", Color(0.0, 0.05, 0.04, 0.85))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 3)
	add_child(popup)
	popup.set_anchors_preset(Control.PRESET_TOP_WIDE)
	popup.offset_left = 0.0
	popup.offset_right = 0.0
	popup.offset_top = 192.0
	popup.offset_bottom = 230.0
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.88, 0.88)
	popup.pivot_offset = Vector2(size.x * 0.5, 18.0)

	_complete_tween = create_tween()
	_complete_tween.set_parallel(true)
	_complete_tween.tween_property(popup, "modulate:a", 1.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_complete_tween.tween_property(popup, "scale", Vector2(1.08, 1.08), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_complete_tween.tween_property(popup, "position:y", popup.position.y + 14.0, 1.32) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_complete_tween.tween_property(popup, "modulate:a", 0.0, 0.4) \
		.set_delay(1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var bonus_label: Label = null
	if not bonus_text.is_empty():
		bonus_label = Label.new()
		bonus_label.text = bonus_text
		bonus_label.z_index = 30
		bonus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_label.add_theme_font_size_override("font_size", 22)
		var text_color := Color(0.35, 0.88, 1.0, 1.0) if bonus_text == "Speedrun!" else Color(1.0, 0.42, 0.42, 1.0)
		bonus_label.add_theme_color_override("font_color", text_color)
		bonus_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.05, 0.04, 0.85))
		bonus_label.add_theme_constant_override("shadow_offset_x", 2)
		bonus_label.add_theme_constant_override("shadow_offset_y", 3)
		var star_crush_path := "res://fonts/Star Crush.otf"
		if ResourceLoader.exists(star_crush_path):
			bonus_label.add_theme_font_override("font", load(star_crush_path))
		add_child(bonus_label)
		bonus_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		bonus_label.offset_left = 0.0
		bonus_label.offset_right = 0.0
		bonus_label.offset_top = 236.0
		bonus_label.offset_bottom = 270.0
		bonus_label.modulate.a = 0.0
		bonus_label.scale = Vector2(0.8, 0.8)
		bonus_label.pivot_offset = Vector2(size.x * 0.5, 17.0)

		_complete_tween.tween_property(bonus_label, "modulate:a", 1.0, 0.16).set_delay(0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_complete_tween.tween_property(bonus_label, "scale", Vector2.ONE, 0.2).set_delay(0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_complete_tween.tween_property(bonus_label, "position:y", bonus_label.position.y + 14.0, 1.32).set_delay(0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_complete_tween.tween_property(bonus_label, "modulate:a", 0.0, 0.4) \
			.set_delay(1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_complete_tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
		if is_instance_valid(bonus_label):
			bonus_label.queue_free()
		if _complete_popup == popup:
			_complete_popup = null
	)

func _add_unique_consumable(
	item_id: StringName,
	texture: Texture2D,
	tooltip: String,
	pressed_callback: Callable
) -> bool:
	_ensure_nodes_bound()
	if slots.get_child_count() >= MAX_ITEMS or _has_item(item_id):
		return false
	var button := _create_item_button(texture, tooltip)
	button.pressed.connect(pressed_callback)
	slots.add_child(button)
	_buttons[item_id] = button
	return true

func _create_item_button(texture: Texture2D, tooltip: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(93.0, 93.0)
	button.flat = true
	button.tooltip_text = tooltip
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.mouse_entered.connect(_animate_item_button.bind(button, ITEM_HOVER_SCALE, Color(1.08, 1.08, 1.0, 1.0), 0.12))
	button.mouse_exited.connect(_animate_item_button.bind(button, Vector2.ONE, Color.WHITE, 0.14))
	button.button_down.connect(_animate_item_button.bind(button, ITEM_PRESS_SCALE, Color(0.86, 0.86, 0.78, 1.0), 0.06))
	button.button_up.connect(_on_item_button_up.bind(button))

	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button

func _consume(item_id: StringName) -> void:
	if not _has_item(item_id):
		return
	var button := _buttons[item_id] as Button
	_buttons.erase(item_id)
	button.queue_free()

func _has_item(item_id: StringName) -> bool:
	return _buttons.has(item_id) and is_instance_valid(_buttons[item_id])

func _on_item_button_up(button: Button) -> void:
	var target_scale := ITEM_HOVER_SCALE if button.is_hovered() else Vector2.ONE
	var target_modulate := Color(1.08, 1.08, 1.0, 1.0) if button.is_hovered() else Color.WHITE
	_animate_item_button(button, target_scale, target_modulate, 0.1)

func _animate_item_button(
	button: Button,
	target_scale: Vector2,
	target_modulate: Color,
	duration: float
) -> void:
	if not is_instance_valid(button):
		return
	if _button_tweens.has(button):
		var old_tween := _button_tweens[button] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(button, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_modulate, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_button_tweens[button] = tween

func _animate_chains() -> void:
	_start_chain_sway(left_chain, 1.0)
	_start_chain_sway(right_chain, 1.0)
	_start_shelf_sway()

func _start_chain_sway(chain: TextureRect, direction: float) -> void:
	if not chain:
		return
	chain.pivot_offset = Vector2(chain.size.x * 0.5, 0.0)
	chain.rotation_degrees = -CHAIN_SWAY_DEGREES * direction
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(chain, "rotation_degrees", CHAIN_SWAY_DEGREES * direction, CHAIN_SWAY_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(chain, "rotation_degrees", -CHAIN_SWAY_DEGREES * direction, CHAIN_SWAY_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_shelf_sway() -> void:
	if not shelf_body:
		return
	var base_position := shelf_body.position
	shelf_body.position.x = base_position.x + SHELF_SWAY_PIXELS
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(shelf_body, "position:x", base_position.x - SHELF_SWAY_PIXELS, CHAIN_SWAY_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shelf_body, "position:x", base_position.x + SHELF_SWAY_PIXELS, CHAIN_SWAY_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func get_active_items() -> Array[String]:
	var items: Array[String] = []
	for key in _buttons.keys():
		if is_instance_valid(_buttons[key]):
			items.append(str(key))
	return items


func clear_shelf() -> void:
	_ensure_nodes_bound()
	for key in _buttons.keys():
		var button = _buttons[key]
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()


func restore_shelf(items: Array) -> void:
	_ensure_nodes_bound()
	clear_shelf()
	for item in items:
		var name_str := str(item)
		match name_str:
			"magic_ball":
				add_magic_ball()
			"shield":
				add_shield()
			"remedy_kit":
				add_remedy_kit()
			"cup_a_joe":
				add_cup_a_joe()
			"moonlight":
				add_moonlight()
			"snake_oil":
				add_snake_oil()
			"pocketwatch":
				add_pocketwatch()
			"velvet_gloves":
				add_velvet_gloves()
