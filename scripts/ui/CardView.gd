class_name CardView
extends Control

signal card_hovered(card: CardView)
signal card_unhovered(card: CardView)
signal card_drag_started(card: CardView)
signal card_drag_ended(card: CardView)
signal card_clicked(card: CardView)

@export var card_data: CardDef

@onready var art_texture: TextureRect = %ArtTexture
@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var type_background: ColorRect = %TypeBackground
@onready var art_separator: ColorRect = %ArtSeparator
@onready var card_back: TextureRect = %CardBack
@onready var outline: Panel = %Outline

const BACKGROUND_SHADER := preload("res://shaders/card_type_background.gdshader")

var base_position: Vector2
var base_z_index: int = 0
var base_rotation_degrees: float = 0.0

var is_dragging: bool = false
var interaction_enabled: bool = true
var drag_enabled: bool = true
var disabled_visual := false
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
		var rarity_val := 0
		match card_data.rarity:
			"Common":
				rarity_val = 1
			"Uncommon":
				rarity_val = 2
			"Rare":
				rarity_val = 3
			_:
				rarity_val = 0
		
		if not type_background.material or not type_background.material is ShaderMaterial:
			var mat := ShaderMaterial.new()
			mat.shader = BACKGROUND_SHADER
			type_background.material = mat
		
		var shader_mat := type_background.material as ShaderMaterial
		shader_mat.set_shader_parameter("base_color", card_data.background_color)
		shader_mat.set_shader_parameter("rarity_mode", rarity_val)
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
	if is_dragging or not interaction_enabled or disabled_visual:
		return
	emit_signal("card_hovered", self)
	if not drag_enabled:
		return
	z_index = 100
	cancel_transform_tween()
	transform_tween = create_tween()
	transform_tween.tween_property(self, "position:y", base_position.y - 30, 0.15).set_ease(Tween.EASE_OUT)
	transform_tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	if is_dragging or not interaction_enabled or disabled_visual:
		return
	emit_signal("card_unhovered", self)
	if not drag_enabled:
		return
	z_index = base_z_index
	cancel_transform_tween()
	transform_tween = create_tween()
	transform_tween.tween_property(self, "position:y", base_position.y, 0.15).set_ease(Tween.EASE_OUT)
	transform_tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)

func _on_gui_input(event: InputEvent) -> void:
	if not interaction_enabled or disabled_visual:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not drag_enabled:
				card_clicked.emit(self)
				accept_event()
				return
			is_dragging = true
			_play_sfx("card_pickup", -2.0, randf_range(0.97, 1.03))
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
	position = get_rest_position()
	rotation_degrees = base_rotation_degrees
	scale = Vector2(1.0, 1.0)

func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		is_dragging = false
		cancel_transform_tween()
		z_index = base_z_index
		scale = Vector2.ONE
		if outline:
			outline.visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP

func set_drag_enabled(enabled: bool) -> void:
	drag_enabled = enabled

func set_disabled_visual(is_disabled: bool, animate := true) -> void:
	var changed := disabled_visual != is_disabled
	disabled_visual = is_disabled
	drag_enabled = not disabled_visual
	cancel_transform_tween()
	var target_position := get_rest_position()
	var target_modulate := Color(0.48, 0.48, 0.52, 1.0) if disabled_visual else Color.WHITE
	if animate and (changed or not position.is_equal_approx(target_position)):
		transform_tween = create_tween()
		transform_tween.set_parallel(true)
		transform_tween.tween_property(self, "position", target_position, 0.24) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		transform_tween.tween_property(self, "modulate", target_modulate, 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		position = target_position
		modulate = target_modulate

func get_rest_position() -> Vector2:
	return base_position + Vector2(0.0, 34.0) if disabled_visual else base_position

func cancel_transform_tween() -> void:
	if transform_tween and transform_tween.is_valid():
		transform_tween.kill()
	transform_tween = null

func _play_sfx(sfx_name: String, volume_offset_db: float = 0.0, pitch: float = 1.0) -> void:
	var manager: Node = get_tree().get_first_node_in_group("sfx_manager")
	if manager:
		manager.play_sfx(sfx_name, volume_offset_db, pitch)
