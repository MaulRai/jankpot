class_name CardView
extends Control

signal card_hovered(card: CardView)
signal card_unhovered(card: CardView)
signal card_drag_started(card: CardView)
signal card_drag_ended(card: CardView)

@export var card_data: CardDef

@onready var art_texture: TextureRect = %ArtTexture
@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var type_background: ColorRect = %TypeBackground
@onready var art_separator: ColorRect = %ArtSeparator
@onready var card_back: TextureRect = %CardBack
@onready var outline: Panel = %Outline

var base_position: Vector2
var base_z_index: int = 0
var base_rotation_degrees: float = 0.0

var is_dragging: bool = false
var interaction_enabled: bool = true
var drag_offset: Vector2 = Vector2.ZERO
var transform_tween: Tween

func _ready() -> void:
	if card_data:
		render()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func set_card_data(data: CardDef) -> void:
	card_data = data
	render()

func render() -> void:
	if not card_data:
		return
	if art_texture and ResourceLoader.exists(card_data.art_path):
		art_texture.texture = load(card_data.art_path)
	if name_label:
		name_label.text = card_data.card_name
	if description_label:
		description_label.text = _format_description(card_data.brief_description, card_data.keywords)
	if type_background:
		type_background.color = card_data.background_color
	if art_separator:
		art_separator.color = card_data.background_color.darkened(0.3)

func set_face_down(face_down: bool) -> void:
	card_back.visible = face_down
	$Background.visible = not face_down
	art_texture.visible = not face_down
	name_label.visible = not face_down
	description_label.visible = not face_down
	type_background.visible = not face_down
	art_separator.visible = not face_down
	if not face_down:
		if card_data:
			render()

func _format_description(text: String, keywords: Array[String]) -> String:
	var formatted := text
	for kw in keywords:
		var color := EffectKeyword.get_color(kw)
		formatted = formatted.replace(kw, "[color=%s]%s[/color]" % [color, kw])
	return formatted

func _on_mouse_entered() -> void:
	if is_dragging or not interaction_enabled:
		return
	emit_signal("card_hovered", self)
	z_index = 100
	cancel_transform_tween()
	transform_tween = create_tween()
	transform_tween.tween_property(self, "position:y", base_position.y - 30, 0.15).set_ease(Tween.EASE_OUT)
	transform_tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	if is_dragging or not interaction_enabled:
		return
	emit_signal("card_unhovered", self)
	z_index = base_z_index
	cancel_transform_tween()
	transform_tween = create_tween()
	transform_tween.tween_property(self, "position:y", base_position.y, 0.15).set_ease(Tween.EASE_OUT)
	transform_tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)

func _on_gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			cancel_transform_tween()
			drag_offset = get_global_mouse_position() - global_position
			z_index = 1000
			# Reset hover transform for clean drag start
			scale = Vector2(1.0, 1.0)
			if outline:
				outline.visible = true
			emit_signal("card_drag_started", self)
			accept_event()
		elif is_dragging:
			is_dragging = false
			if outline:
				outline.visible = false
			emit_signal("card_drag_ended", self)
			accept_event()

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func reset_transform() -> void:
	cancel_transform_tween()
	position = base_position
	rotation_degrees = base_rotation_degrees
	scale = Vector2(1.0, 1.0)

func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		is_dragging = false
		cancel_transform_tween()
		if outline:
			outline.visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP

func cancel_transform_tween() -> void:
	if transform_tween and transform_tween.is_valid():
		transform_tween.kill()
	transform_tween = null
