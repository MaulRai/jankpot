class_name ConsumableShelf
extends Control

const MAGIC_BALL_TEXTURE := preload("res://assets/item/magic-ball.png")
const SHIELD_TEXTURE := preload("res://assets/item/shield.png")
const REMEDY_KIT_TEXTURE := preload("res://assets/item/remedy-kit.png")
const CUP_A_JOE_TEXTURE := preload("res://assets/item/cup-a-joe.png")

signal magic_ball_requested
signal shield_requested
signal remedy_kit_requested
signal cup_a_joe_requested

const MAX_ITEMS := 5
const CHAIN_SWAY_DEGREES := 2.2
const SHELF_SWAY_PIXELS := 3.0
const CHAIN_SWAY_DURATION := 1.8
const ITEM_HOVER_SCALE := Vector2(1.08, 1.08)
const ITEM_PRESS_SCALE := Vector2(0.92, 0.92)

@onready var slots: HBoxContainer = %Slots
@onready var shelf_body: Control = %ShelfBody
@onready var left_chain: TextureRect = %LeftChain
@onready var right_chain: TextureRect = %RightChain

var _buttons: Dictionary = {}
var _button_tweens: Dictionary = {}

func _ready() -> void:
	_animate_chains()
	add_shield()
	add_remedy_kit()
	add_cup_a_joe()

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

func consume_magic_ball() -> void:
	_consume(&"magic_ball")

func consume_shield() -> void:
	_consume(&"shield")

func consume_remedy_kit() -> void:
	_consume(&"remedy_kit")

func consume_cup_a_joe() -> void:
	_consume(&"cup_a_joe")

func _add_unique_consumable(
	item_id: StringName,
	texture: Texture2D,
	tooltip: String,
	pressed_callback: Callable
) -> bool:
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
