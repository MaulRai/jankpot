class_name PackOpening
extends Control

signal card_awarded(card: CardDef)

const WeaponCatalogData  = preload("res://scripts/data/WeaponCatalog.gd")
const CardRevealFxScript := preload("res://scripts/main/CardRevealFx.gd")

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
	var reward  := _roll_pack_card(pack_id)

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

	await _reveal_card(reward)
	card_awarded.emit(reward)

	_pack_prompt.text = "TAP ANYWHERE TO CONTINUE"
	var prompt_tween := _pack_stage.create_tween()
	prompt_tween.tween_property(_pack_prompt, "modulate:a", 1.0, 0.18)
	_pack_state = PACK_STATE_REVEALED
	_pack_busy  = false


# ---------------------------------------------------------------------------
# Card reveal
# ---------------------------------------------------------------------------

func _reveal_card(card_data: CardDef) -> void:
	_clear_revealed_card()

	var viewport_size   := _pack_layer.get_viewport().get_visible_rect().size
	var card_center     := viewport_size * 0.5
	var reveal_position := card_center - CARD_SIZE * 0.5

	# Build FX node. Node2D has no pivot_offset, so its origin is anchored at
	# the fixed visual centre (not the top-left) — this keeps the glow and
	# sparkles centred on the card as it scales, instead of drifting toward
	# the bottom-right as REVEAL_SCALE grows. display_size is the card's
	# final on-screen footprint (post-scale), used to place the stage sparkles.
	_reveal_fx = CardRevealFxScript.new()
	_pack_stage.add_child(_reveal_fx)
	_reveal_fx.global_position = card_center
	_reveal_fx.setup(card_data, _pack_stage, CARD_SIZE * REVEAL_SCALE)

	# Build the card visual (instantiated CardView)
	_revealed_card          = _build_reveal_card(card_data)
	_revealed_card.z_index  = 10
	_pack_stage.add_child(_revealed_card)
	_revealed_card.global_position = reveal_position

	# Set pivot and initial state for scale animations
	var pivot := CARD_SIZE * 0.5
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
	tween.tween_property(node, "scale", Vector2(REVEAL_SCALE, REVEAL_SCALE), 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation_degrees", 0.0, 0.36) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_reveal_card(card_data: CardDef) -> Control:
	var card_view := CARD_VIEW_SCENE.instantiate() as Control
	card_view.set("card_data", card_data)
	card_view.set("interaction_enabled", false)
	card_view.custom_minimum_size = CARD_SIZE

	var name_lbl = card_view.get_node_or_null("%NameLabel")
	if name_lbl:
		name_lbl.add_theme_font_override("font", STAR_CRUSH_FONT)
		name_lbl.add_theme_font_size_override("font_size", 16)
	var desc_lbl = card_view.get_node_or_null("%DescriptionLabel")
	if desc_lbl:
		desc_lbl.add_theme_font_override("normal_font", STAR_CRUSH_FONT)
		desc_lbl.add_theme_font_size_override("normal_font_size", 12)

	return card_view


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
		WeaponCatalogData.RARITY_COMMON:   return ["quartz", "bronze_razor", "sculptural_sheet"]
		WeaponCatalogData.RARITY_UNCOMMON: return ["spiked_boulder", "rusty_shears", "mist_veil"]
		WeaponCatalogData.RARITY_RARE:     return ["ruby", "guillotine_blades", "hatter_slip"]
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