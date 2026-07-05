class_name PackOpening
extends Control

signal card_awarded(card: CardDef)
signal item_awarded(item_id: String)

const WeaponCatalogData  = preload("res://scripts/data/WeaponCatalog.gd")
const CardRevealFxScript := preload("res://scripts/main/CardRevealFx.gd")
const PixelFramePanel    := preload("res://scripts/ui/PixelFramePanel.gd")

const STAR_CRUSH_FONT := preload("res://fonts/Star Crush.otf")
const ITEM_REVEALING_SFX := preload("res://audio/sfx/item-revealing.mp3")
const ITEM_REVEALED_SFX := preload("res://audio/sfx/item-revealed.mp3")
const HIT_SFX := preload("res://audio/sfx/hit.mp3")

const PACK_STATE_CLOSED   := "closed"
const PACK_STATE_REVEALED := "revealed"

const CARD_SIZE := Vector2(160.0, 240.0)   # must match CardView.tscn's native size (root Control offset_right/offset_bottom)
const REVEAL_SCALE := 1.6   # visual enlargement of the revealed card (scale-based — CardView's children use fixed pixel offsets, not anchors, so resizing the root does nothing; scale is the only way to enlarge it)
const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")


var _pack_layer:   CanvasLayer
var _pack_overlay: ColorRect
var _pack_stage:   Control     # full-rect, parent of card + fx + sparkles
var _pack_texture: TextureRect
var _pack_prompt:  Label
var _spark_layer:  Control     # burst sparks only

var _revealed_card: Control
var _reveal_fx:     CardRevealFx

var _pack_state := ""
var _pack_busy  := false
var _floating_tween: Tween


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func initialise(parent: Node) -> void:
	_build_overlay_tree(parent)

func handle_unhandled_input(event: InputEvent) -> void:
	if not _pack_layer or not _pack_layer.visible or _pack_busy:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_advance_pack_flow()

func start(pack_id: String, texture: Texture2D) -> void:
	if _pack_busy:
		return
	await _start_pack_flow(pack_id, texture)

func is_visible_and_busy() -> bool:
	return _pack_layer != null and _pack_layer.visible and _pack_busy


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_overlay_gui_input(event: InputEvent) -> void:
	if not _pack_layer or not _pack_layer.visible or _pack_busy:
		return
	var clicked: bool = (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if clicked:
		_pack_overlay.accept_event()
		_advance_pack_flow()

func _advance_pack_flow() -> void:
	match _pack_state:
		PACK_STATE_CLOSED:   _open_floating_pack()
		PACK_STATE_REVEALED: _close_pack_overlay()


# ---------------------------------------------------------------------------
# Overlay tree construction
# ---------------------------------------------------------------------------

func _build_overlay_tree(parent: Node) -> void:
	_pack_layer         = CanvasLayer.new()
	_pack_layer.name    = "PackOpeningLayer"
	_pack_layer.layer   = 96
	_pack_layer.visible = false
	parent.add_child(_pack_layer)

	_pack_overlay              = ColorRect.new()
	_pack_overlay.name         = "PackOverlay"
	_pack_overlay.color        = Color(0.004, 0.007, 0.008, 0.86)
	_pack_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pack_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pack_overlay.gui_input.connect(_on_overlay_gui_input)
	_pack_layer.add_child(_pack_overlay)

	_spark_layer              = Control.new()
	_spark_layer.name         = "SparkLayer"
	_spark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pack_overlay.add_child(_spark_layer)

	_pack_stage              = Control.new()
	_pack_stage.name         = "PackStage"
	_pack_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pack_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pack_overlay.add_child(_pack_stage)

	_pack_texture                     = TextureRect.new()
	_pack_texture.name                = "FloatingPack"
	_pack_texture.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	_pack_texture.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	_pack_texture.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pack_texture.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_pack_texture.custom_minimum_size = Vector2(190.0, 190.0)
	_pack_texture.size                = Vector2(190.0, 190.0)
	_pack_texture.pivot_offset        = _pack_texture.size * 0.5
	_pack_stage.add_child(_pack_texture)

	_pack_prompt                     = Label.new()
	_pack_prompt.name                = "PackPrompt"
	_pack_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pack_prompt.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	_pack_prompt.add_theme_font_size_override("font_size", 24)
	_pack_prompt.add_theme_font_override("font", STAR_CRUSH_FONT)
	_pack_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1.0))
	_pack_prompt.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_pack_prompt.add_theme_constant_override("shadow_offset_y", 4)
	_pack_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pack_prompt.position.y = 286.0
	_pack_stage.add_child(_pack_prompt)


# ---------------------------------------------------------------------------
# Pack flow
# ---------------------------------------------------------------------------

func _start_pack_flow(pack_id: String, texture: Texture2D) -> void:
	_pack_busy                  = true
	_pack_state                 = ""
	_pack_layer.visible         = true
	_pack_overlay.modulate.a    = 0.0
	_pack_texture.texture       = texture
	_pack_texture.visible       = true
	_pack_texture.modulate      = Color.WHITE
	_pack_texture.scale         = Vector2(0.9, 0.9)
	_pack_texture.rotation_degrees = -4.0
	_pack_prompt.text           = "TAP THE PACK"
	_pack_prompt.modulate.a     = 0.0
	_clear_revealed_card()
	_clear_sparks()

	var viewport_size := _pack_layer.get_viewport().get_visible_rect().size
	var center        := viewport_size * 0.5
	_pack_texture.global_position = Vector2(
		center.x - _pack_texture.size.x * 0.5,
		viewport_size.y + _pack_texture.size.y
	)
	var target_position := center - _pack_texture.size * 0.5 + Vector2(0.0, -18.0)

	var tween := _pack_stage.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_pack_overlay, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_pack_texture, "global_position", target_position, 0.58) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_pack_texture, "scale", Vector2.ONE, 0.58) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

	_start_pack_float(target_position)
	var prompt_tween := _pack_stage.create_tween()
	prompt_tween.tween_property(_pack_prompt, "modulate:a", 1.0, 0.18)
	_pack_texture.set_meta("pack_id", pack_id)
	_pack_state = PACK_STATE_CLOSED
	_pack_busy  = false


func _start_pack_float(base_position: Vector2) -> void:
	if _floating_tween and _floating_tween.is_valid():
		_floating_tween.kill()
	_floating_tween = _pack_stage.create_tween()
	_floating_tween.set_loops()
	_floating_tween.set_parallel(true)
	_floating_tween.tween_property(_pack_texture, "global_position:y", base_position.y - 10.0, 1.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_floating_tween.tween_property(_pack_texture, "rotation_degrees", 4.0, 1.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_floating_tween.chain().tween_property(_pack_texture, "global_position:y", base_position.y + 4.0, 1.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_floating_tween.parallel().tween_property(_pack_texture, "rotation_degrees", -4.0, 1.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _open_floating_pack() -> void:
	_pack_busy  = true
	_pack_state = ""

	if _floating_tween and _floating_tween.is_valid():
		_floating_tween.kill()
	_floating_tween = null
	_pack_prompt.modulate.a = 0.0

	var pack_id := str(_pack_texture.get_meta("pack_id", "basic"))

	_play_sfx(HIT_SFX, -4.0)
	_play_sfx(ITEM_REVEALING_SFX)
	var shake := _pack_stage.create_tween()
	shake.tween_property(_pack_texture, "rotation_degrees", -12.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees",  13.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees", -11.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees",  12.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees",  -9.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees",  10.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees",  -7.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees",   8.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees",  -4.0, 0.09)
	shake.tween_property(_pack_texture, "rotation_degrees",   0.0, 0.10)
	await shake.finished
	_play_sfx(ITEM_REVEALED_SFX)

	_emit_pack_sparks(_pack_texture.global_position + _pack_texture.size * 0.5)

	var burst := _pack_stage.create_tween()
	burst.set_parallel(true)
	burst.tween_property(_pack_texture, "scale",      Vector2(1.42, 1.42), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst.tween_property(_pack_texture, "modulate:a", 0.0,                 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await burst.finished
	_pack_texture.visible = false

	if pack_id == "item":
		var reward_item := _roll_pack_item()
		await _reveal_item(reward_item)
		item_awarded.emit(reward_item)
	else:
		var reward  := _roll_pack_card(pack_id)
		await _reveal_card(reward)
		card_awarded.emit(reward)

	_pack_prompt.text = "TAP ANYWHERE TO CONTINUE"
	var prompt_tween := _pack_stage.create_tween()
	prompt_tween.tween_property(_pack_prompt, "modulate:a", 1.0, 0.18)
	_pack_state = PACK_STATE_REVEALED
	_pack_busy  = false


func _reveal_item(item_id: String) -> void:
	_clear_revealed_card()

	var native_size := Vector2(280.0, 420.0)
	var viewport_size := _pack_layer.get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var reveal_position := center - native_size * 0.5

	# Build a container for the item
	var container := Control.new()
	container.custom_minimum_size = native_size
	container.size = native_size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_revealed_card = container
	_revealed_card.z_index = 10
	_pack_stage.add_child(_revealed_card)
	_revealed_card.global_position = reveal_position

	# Item Icon (Enlarged and centered in upper 260px area)
	var icon := TextureRect.new()
	icon.texture = load(_get_item_texture_path(item_id))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(110.0, 110.0)
	icon.position = Vector2((native_size.x - icon.size.x) / 2.0, (260.0 - icon.size.y) / 2.0)
	container.add_child(icon)

	# PixelFramePanel for item details below (anchored to bottom edge, no gaps!)
	var info_frame := PixelFramePanel.new()
	info_frame.layout_mode = 1
	container.add_child(info_frame)
	info_frame.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info_frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info_frame.offset_left = 0.0
	info_frame.offset_right = 0.0
	info_frame.offset_top = -160.0
	info_frame.offset_bottom = 0.0
	info_frame.custom_minimum_size = Vector2(280.0, 160.0)
	info_frame.base_tint = Color(0.08, 0.09, 0.12, 0.95)
	info_frame.frame_outline_tint = Color(0.52, 0.6, 0.74, 1.0)
	info_frame.base_outline_tint = Color(0.12, 0.15, 0.205, 1.0)
	info_frame.base_fill_tint = Color(0.055, 0.068, 0.1, 0.95)
	info_frame.component_scale = 1.0

	# Margin inside the panel
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	info_frame.add_child(margin)

	# VBox inside margin
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var info := _get_item_info(item_id)

	# Item Name Label
	var name_lbl := Label.new()
	name_lbl.text = info["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", STAR_CRUSH_FONT)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.64, 1.0))
	vbox.add_child(name_lbl)

	# Item Description Label (overridden with Star Crush font)
	var desc_lbl := Label.new()
	desc_lbl.text = info["description"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", STAR_CRUSH_FONT)
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.82, 1.0))
	vbox.add_child(desc_lbl)

	# Set pivot and initial state for scale animations (matching card reveal)
	var pivot := native_size * 0.5
	var initial_rotation := randf_range(-7.0, 7.0)
	_revealed_card.pivot_offset = pivot
	_revealed_card.scale = Vector2(0.25, 0.25)
	_revealed_card.rotation_degrees = initial_rotation
	_revealed_card.modulate.a = 0.0

	var tween := _pack_stage.create_tween()
	tween.set_parallel(true)
	_tween_reveal_node(tween, _revealed_card)
	await tween.finished


func _roll_pack_item() -> String:
	var items = [
		"magic_ball",
		"shield",
		"remedy_kit",
		"cup_a_joe",
		"snake_oil",
		"pocketwatch",
		"velvet_gloves",
		"l_ivoire",
		"sealed_missive",
		"curio"
	]
	return items.pick_random()


func _get_item_texture_path(item_id: String) -> String:
	var file_name = item_id.replace("_", "-")
	return "res://assets/item/%s.png" % file_name


func _get_item_info(item_id: String) -> Dictionary:
	match item_id:
		"magic_ball":
			return { "name": "Magic Ball", "description": "Predicts the enemy's next weapon." }
		"shield":
			return { "name": "Shield", "description": "Blocks 1 DMG." }
		"remedy_kit":
			return { "name": "Remedy Kit", "description": "Removes all ailments (Bleed, Poison)." }
		"cup_a_joe":
			return { "name": "Cup-a-Joe", "description": "Win attacks twice this turn." }
		"snake_oil":
			return { "name": "Snake Oil", "description": "Inflict 1 poison. If lose twice in a row, inflict 2 instead." }
		"pocketwatch":
			return { "name": "Pocketwatch", "description": "Raise Aegis for next turn when you lose clash." }
		"velvet_gloves":
			return { "name": "Velvet Gloves", "description": "Cherry pick a card from draw pile." }
		"l_ivoire":
			return { "name": "L'Ivoire", "description": "Add random Rare Scissors to deck that lasts entire run." }
		"sealed_missive":
			return { "name": "Sealed Missive", "description": "Add random Rare Paper to deck that lasts entire run." }
		"curio":
			return { "name": "Curio", "description": "Add random Rare Rock to deck that lasts entire run." }
	return { "name": "Unknown", "description": "" }


# ---------------------------------------------------------------------------
# Card reveal
# ---------------------------------------------------------------------------

func _reveal_card(card_data: CardDef) -> void:
	_clear_revealed_card()

	var native_card_size := Vector2(230.0, 345.0)
	var viewport_size   := _pack_layer.get_viewport().get_visible_rect().size
	var card_center     := viewport_size * 0.5
	var reveal_position := card_center - native_card_size * 0.5

	# Build FX node.
	_reveal_fx = CardRevealFxScript.new()
	_pack_stage.add_child(_reveal_fx)
	_reveal_fx.global_position = card_center
	_reveal_fx.setup(card_data, _pack_stage, native_card_size)

	# Build the card visual (natively sized to prevent scaling blur)
	_revealed_card          = _build_reveal_card(card_data)
	_revealed_card.z_index  = 10
	_pack_stage.add_child(_revealed_card)
	_revealed_card.global_position = reveal_position

	# Set pivot and initial state for scale animations
	var pivot := native_card_size * 0.5
	var initial_rotation := randf_range(-7.0, 7.0)
	_revealed_card.pivot_offset = pivot
	_revealed_card.scale = Vector2(0.25, 0.25)
	_revealed_card.rotation_degrees = initial_rotation
	_revealed_card.modulate.a = 0.0
	_reveal_fx.scale = Vector2(0.25, 0.25)
	_reveal_fx.rotation_degrees = initial_rotation
	_reveal_fx.modulate.a = 0.0

	var tween := _pack_stage.create_tween()
	tween.set_parallel(true)
	_tween_reveal_node(tween, _reveal_fx)
	_tween_reveal_node(tween, _revealed_card)
	await tween.finished


func _tween_reveal_node(tween: Tween, node: CanvasItem) -> void:
	tween.tween_property(node, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation_degrees", 0.0, 0.36) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_reveal_card(card_data: CardDef) -> Control:
	var native_card_size := Vector2(230.0, 345.0)
	var card := Control.new()
	card.custom_minimum_size = native_card_size
	card.size = native_card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# StyleBox shadow panel
	var shadow := Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.015)
	shadow_style.corner_radius_top_left = 14
	shadow_style.corner_radius_top_right = 14
	shadow_style.corner_radius_bottom_right = 14
	shadow_style.corner_radius_bottom_left = 14
	shadow_style.shadow_color = Color(0, 0, 0, 0.28)
	shadow_style.shadow_size = 10
	shadow_style.shadow_offset = Vector2(0, 6)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	card.add_child(shadow)

	# Card Base Background Texture (no colors or tints applied, kept original!)
	var base_bg := TextureRect.new()
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_bg.texture = load("res://assets/ui/card-base.png")
	base_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_bg.stretch_mode = TextureRect.STRETCH_SCALE
	card.add_child(base_bg)
	base_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Type Background ColorRect with Rarity Shader (precise 1.4375 scaling ratio)
	var type_bg := ColorRect.new()
	type_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_bg.position = Vector2(14.375, 14.375)
	type_bg.size = Vector2(201.25, 201.25)
	
	var BACKGROUND_SHADER = load("res://shaders/card_type_background.gdshader")
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = BACKGROUND_SHADER
	
	var rarity_val := 0
	match card_data.rarity:
		"Common": rarity_val = 1
		"Uncommon": rarity_val = 2
		"Rare": rarity_val = 3
		_: rarity_val = 0
		
	shader_mat.set_shader_parameter("base_color", card_data.background_color)
	shader_mat.set_shader_parameter("rarity_mode", rarity_val)
	type_bg.material = shader_mat
	card.add_child(type_bg)

	# Art Texture Rect
	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(card_data.art_path):
		art.texture = load(card_data.art_path)
	art.position = Vector2(23.0, 23.0)
	art.size = Vector2(184.0, 184.0)
	card.add_child(art)

	# Art Separator
	var sep := ColorRect.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.position = Vector2(14.375, 215.625)
	sep.size = Vector2(201.25, 2.875)
	sep.color = card_data.background_color.darkened(0.3)
	card.add_child(sep)

	# Name Label
	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.position = Vector2(14.375, 224.25)
	name_lbl.size = Vector2(201.25, 31.625)
	name_lbl.text = card_data.card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", STAR_CRUSH_FONT)
	name_lbl.add_theme_font_size_override("font_size", 23)
	name_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
	card.add_child(name_lbl)

	# Description Label
	var desc_lbl := RichTextLabel.new()
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.position = Vector2(17.25, 261.625)
	desc_lbl.size = Vector2(195.5, 71.875)
	desc_lbl.bbcode_enabled = true
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	
	var formatted_desc := card_data.brief_description
	for kw in card_data.keywords:
		var color = EffectKeyword.get_color(kw)
		formatted_desc = formatted_desc.replace(kw, "[color=%s]%s[/color]" % [color, kw])
	
	desc_lbl.text = "[center]" + formatted_desc + "[/center]"
	desc_lbl.add_theme_font_override("normal_font", STAR_CRUSH_FONT)
	desc_lbl.add_theme_font_size_override("normal_font_size", 16)
	desc_lbl.add_theme_color_override("default_color", Color(0.15, 0.15, 0.15, 1.0))
	card.add_child(desc_lbl)

	return card


# ---------------------------------------------------------------------------
# Close
# ---------------------------------------------------------------------------

func _close_pack_overlay() -> void:
	_pack_busy  = true
	_pack_state = ""

	if _reveal_fx and is_instance_valid(_reveal_fx):
		_reveal_fx.stop_all()   # kills tweens + frees stage sparkles

	var tween := _pack_stage.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_pack_overlay, "modulate:a", 0.0, 0.2)
	_tween_close_node(tween, _revealed_card)
	_tween_close_node(tween, _reveal_fx)
	await tween.finished

	_pack_layer.visible = false
	_clear_revealed_card()
	_clear_sparks()
	_pack_busy = false


func _tween_close_node(tween: Tween, node: CanvasItem) -> void:
	if not node or not is_instance_valid(node):
		return
	tween.tween_property(node, "scale", Vector2(0.82, 0.82), 0.18)
	tween.tween_property(node, "modulate:a", 0.0, 0.18)


# ---------------------------------------------------------------------------
# Burst sparks (pack open effect)
# ---------------------------------------------------------------------------

func _emit_pack_sparks(origin: Vector2) -> void:
	_clear_sparks()
	for index in range(28):
		var spark := ColorRect.new()
		spark.mouse_filter    = Control.MOUSE_FILTER_IGNORE
		spark.color           = Color(1.0, randf_range(0.78, 0.95), randf_range(0.36, 0.68), 1.0)
		spark.size            = Vector2(randf_range(4.0, 8.0), randf_range(4.0, 8.0))
		spark.pivot_offset    = spark.size * 0.5
		spark.global_position = origin - spark.size * 0.5
		_spark_layer.add_child(spark)

		var angle    := TAU * float(index) / 28.0 + randf_range(-0.18, 0.18)
		var distance := randf_range(90.0, 230.0)
		var target   := origin + Vector2(cos(angle), sin(angle)) * distance

		var tween := _spark_layer.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", target,
			randf_range(0.35, 0.62)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0,
			randf_range(0.34, 0.56)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(spark, "scale",
			Vector2(randf_range(1.8, 3.0), randf_range(1.8, 3.0)), 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.finished.connect(spark.queue_free)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _clear_revealed_card() -> void:
	if _revealed_card and is_instance_valid(_revealed_card):
		_revealed_card.queue_free()
	_revealed_card = null
	if _reveal_fx and is_instance_valid(_reveal_fx):
		_reveal_fx.stop_all()
		_reveal_fx.queue_free()
	_reveal_fx = null

func _clear_sparks() -> void:
	if not _spark_layer:
		return
	for child in _spark_layer.get_children():
		child.queue_free()

func _roll_pack_card(pack_id: String) -> CardDef:
	var rarity     := _roll_pack_rarity(pack_id)
	var candidates := _weapon_ids_for_rarity(rarity)
	if candidates.is_empty():
		return WeaponCatalogData.create_basic(randi_range(0, 2) as CardDef.CardType)
	return WeaponCatalogData.create_weapon(candidates.pick_random())

func _roll_pack_rarity(pack_id: String) -> String:
	if pack_id == "premium":
		var premium_roll := randi_range(1, 5)
		return WeaponCatalogData.RARITY_UNCOMMON \
			if premium_roll <= 1 else WeaponCatalogData.RARITY_RARE

	var ratios := [8, 3, 1]
	var roll   := randi_range(1, ratios[0] + ratios[1] + ratios[2])
	if roll <= ratios[0]:
		return WeaponCatalogData.RARITY_COMMON
	if roll <= ratios[0] + ratios[1]:
		return WeaponCatalogData.RARITY_UNCOMMON
	return WeaponCatalogData.RARITY_RARE

func _weapon_ids_for_rarity(rarity: String) -> Array[String]:
	match rarity:
		WeaponCatalogData.RARITY_COMMON:   return ["quartz", "bronze_razor", "sculptural_sheet", "garnet"]
		WeaponCatalogData.RARITY_UNCOMMON: return ["spiked_boulder", "rusty_shears", "mist_veil"]
		WeaponCatalogData.RARITY_RARE:     return ["ruby", "guillotine_blades", "hatter_slip", "origami", "davys"]
	return []

func _type_outline_color(type: CardDef.CardType) -> Color:
	match type:
		CardDef.CardType.ROCK:     return Color(0.78, 0.88, 1.0,  1.0)
		CardDef.CardType.PAPER:    return Color(1.0,  0.93, 0.58, 1.0)
		CardDef.CardType.SCISSORS: return Color(1.0,  0.48, 0.46, 1.0)
	return Color(1.0, 0.9, 0.55, 1.0)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		WeaponCatalogData.RARITY_COMMON:   return Color(0.68, 0.93, 0.78, 1.0)
		WeaponCatalogData.RARITY_UNCOMMON: return Color(0.62, 0.82, 1.0,  1.0)
		WeaponCatalogData.RARITY_RARE:     return Color(1.0,  0.72, 0.96, 1.0)
	return Color(1.0, 0.9, 0.55, 1.0)


func _play_sfx(stream: AudioStream, volume_db: float = -2.0) -> void:
	if not stream or not _pack_layer:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	_pack_layer.add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
