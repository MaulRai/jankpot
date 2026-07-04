class_name CardRevealFx
## Visual effects node placed BEHIND the revealed card.
## - Uncommon: large radial glow
## - Rare:     large radial glow + floating plus-sign sparkles
##
## IMPORTANT: This is a Node2D (not Control) so it has no size/clipping concept.
## All children use local positions relative to this node's origin, which
## PackOpening places at the card's global_position.
## Sparkles are spawned directly onto _pack_stage at global coordinates so they
## are never clipped by any Control boundary.
extends Node2D

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

## Must match _build_reveal_card() in PackOpening.
const CARD_SIZE := Vector2(200.0, 300.0)

var _tweens: Array[Tween] = []

## `stage` is the Control that owns the full overlay (PRESET_FULL_RECT).
## Sparkles are added there so they float freely above everything.
func setup(card_data: CardDef, stage: Control) -> void:
	z_index = 5
	match card_data.rarity:
		WeaponCatalogData.RARITY_UNCOMMON:
			_add_radial_glow(_uncommon_glow_color())
		WeaponCatalogData.RARITY_RARE:
			_add_radial_glow(_rare_glow_color())
			_add_sparkle_field(stage)


# ---------------------------------------------------------------------------
# Radial glow  (child of this Node2D, centred on CARD_SIZE * 0.5)
# ---------------------------------------------------------------------------

func _uncommon_glow_color() -> Color:
	return Color(0.42, 0.72, 1.0, 0.55)

func _rare_glow_color() -> Color:
	return Color(1.0, 0.54, 0.96, 0.90)

func _add_radial_glow(color: Color) -> void:
	var pad_x  := CARD_SIZE.x * 0.82
	var pad_y  := CARD_SIZE.y * 0.68
	var glow_w := CARD_SIZE.x + pad_x * 2.0
	var glow_h := CARD_SIZE.y + pad_y * 2.0

	var mesh_inst := MeshInstance2D.new()
	# Centre glow on the card rectangle (origin of this node = card top-left).
	mesh_inst.position = CARD_SIZE * 0.5

	var im := ImmediateMesh.new()
	_fill_radial_mesh(im, glow_w * 0.5, glow_h * 0.5, color, 64)
	mesh_inst.mesh = im

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mesh_inst.material = mat

	add_child(mesh_inst)

	# Gentle breathe.
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(mesh_inst, "scale", Vector2(1.07, 1.05), 1.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_property(mesh_inst, "scale", Vector2(0.95, 0.97), 1.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(tween)

func _fill_radial_mesh(
	mesh: ImmediateMesh,
	half_w: float,
	half_h: float,
	color: Color,
	segments: int
) -> void:
	var transparent := Color(color.r, color.g, color.b, 0.0)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 := TAU * float(i)       / float(segments)
		var a1 := TAU * float(i + 1)   / float(segments)
		var p0 := Vector2(cos(a0) * half_w, sin(a0) * half_h)
		var p1 := Vector2(cos(a1) * half_w, sin(a1) * half_h)
		mesh.surface_set_color(color);       mesh.surface_add_vertex(Vector3(0,  0,  0))
		mesh.surface_set_color(transparent); mesh.surface_add_vertex(Vector3(p0.x, p0.y, 0))
		mesh.surface_set_color(transparent); mesh.surface_add_vertex(Vector3(p1.x, p1.y, 0))
	mesh.surface_end()


# ---------------------------------------------------------------------------
# Plus-sign sparkles  (added to `stage`, positioned via global_position)
# Spawning on the stage (full-rect Control) means no Control clips them.
# ---------------------------------------------------------------------------

func _add_sparkle_field(stage: Control) -> void:
	# Fixed anchor positions just outside the card boundary — always visible.
	var card_origin: Vector2 = global_position  # set by PackOpening before setup()
	var cx := card_origin.x
	var cy := card_origin.y
	var cw := CARD_SIZE.x
	var ch := CARD_SIZE.y

	var fixed_positions: Array[Vector2] = [
		Vector2(cx - 26.0,       cy + ch * 0.16),
		Vector2(cx + cw + 26.0,  cy + ch * 0.20),
		Vector2(cx - 24.0,       cy + ch * 0.58),
		Vector2(cx + cw + 24.0,  cy + ch * 0.62),
		Vector2(cx + cw * 0.22,  cy - 28.0),
		Vector2(cx + cw * 0.78,  cy - 26.0),
		Vector2(cx + cw * 0.25,  cy + ch + 28.0),
		Vector2(cx + cw * 0.74,  cy + ch + 26.0),
	]

	for pos in fixed_positions:
		var length  := randf_range(24.0, 38.0)
		var color   := _sparkle_color()
		var sparkle := _create_plus_sparkle(length, color, stage)
		sparkle.global_position = pos - sparkle.size * 0.5
		_animate_plus_sparkle(sparkle, randf_range(0.0, 0.4))

	# Additional scattered sparkles around the card perimeter.
	for _i in range(18):
		var side   := randi() % 4
		var length := randf_range(15.0, 30.0)
		var color  := _sparkle_color()
		var pos    := _random_perimeter_pos(cx, cy, cw, ch, side)
		var sparkle := _create_plus_sparkle(length, color, stage)
		sparkle.global_position = pos - sparkle.size * 0.5
		_animate_plus_sparkle(sparkle, randf_range(0.0, 1.2))

func _sparkle_color() -> Color:
	return Color(1.0, randf_range(0.84, 0.96), randf_range(0.95, 1.0), randf_range(0.78, 0.94))

func _random_perimeter_pos(cx: float, cy: float, cw: float, ch: float, side: int) -> Vector2:
	match side:
		0: return Vector2(cx + randf_range(-36.0, cw + 36.0), cy + randf_range(-46.0, -20.0))  # top
		1: return Vector2(cx + randf_range(-36.0, cw + 36.0), cy + ch + randf_range(20.0, 46.0)) # bottom
		2: return Vector2(cx + randf_range(-48.0, -22.0), cy + randf_range(-20.0, ch + 20.0)) # left
		_: return Vector2(cx + cw + randf_range(22.0, 48.0), cy + randf_range(-20.0, ch + 20.0)) # right

## Creates the plus-sign Control and adds it to `stage` (not to self).
## Using stage as parent ensures sparkles render above everything in the overlay
## and are never subject to any size-based clipping.
func _create_plus_sparkle(length: float, color: Color, stage: Control) -> Control:
	var sparkle := Control.new()
	sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkle.size = Vector2(length, length)
	sparkle.pivot_offset = sparkle.size * 0.5
	sparkle.z_index = 50
	sparkle.modulate.a = 1.0

	var thickness := clampf(length * 0.12, 2.0, 4.0)
	var h := _make_arm(Vector2(length, thickness), color)
	var v := _make_arm(Vector2(thickness, length * randf_range(0.9, 1.08)), color)
	h.name = "H"
	v.name = "V"
	h.position = Vector2(0.0, length * 0.5 - h.size.y * 0.5)
	v.position = Vector2(length * 0.5 - v.size.x * 0.5, (length - v.size.y) * 0.5)
	sparkle.add_child(h)
	sparkle.add_child(v)

	var core := _make_arm(Vector2(thickness * 1.55, thickness * 1.55), Color(1.0, 1.0, 1.0, color.a))
	core.name = "Core"
	core.position = sparkle.size * 0.5 - core.size * 0.5
	sparkle.add_child(core)

	stage.add_child(sparkle)
	_stage_sparkles.append(sparkle)
	return sparkle

func _make_arm(size: Vector2, color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = size
	line.pivot_offset = size * 0.5
	line.color = color
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	line.material  = mat
	return line

## Three independent tweens per sparkle so H arm, V arm and alpha drift apart.
func _animate_plus_sparkle(sparkle: Control, initial_delay: float) -> void:
	var h := sparkle.get_node("H") as ColorRect
	var v := sparkle.get_node("V") as ColorRect
	var core := sparkle.get_node("Core") as ColorRect
	if not h or not v:
		return
	var tween := create_tween()
	tween.set_loops()
	_tweens.append(tween)

	tween.tween_interval(initial_delay)
	tween.tween_callback(_reset_sparkle.bind(sparkle, h, v, core))
	tween.tween_property(sparkle, "modulate:a", randf_range(0.9, 1.0), randf_range(0.18, 0.34)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(h, "scale:x", randf_range(1.12, 1.42), randf_range(0.3, 0.52)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(v, "scale:y", randf_range(1.08, 1.36), randf_range(0.34, 0.58)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if core:
		tween.parallel().tween_property(core, "scale", Vector2(randf_range(1.1, 1.28), randf_range(1.1, 1.28)), randf_range(0.24, 0.42)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(randf_range(0.14, 0.46))
	tween.tween_property(sparkle, "modulate:a", 0.0, randf_range(0.44, 0.82)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(h, "scale:x", randf_range(0.22, 0.46), randf_range(0.42, 0.76)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(v, "scale:y", randf_range(0.26, 0.5), randf_range(0.44, 0.78)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if core:
		tween.parallel().tween_property(core, "scale", Vector2(randf_range(0.66, 0.84), randf_range(0.66, 0.84)), randf_range(0.38, 0.68)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_interval(randf_range(0.26, 1.2))


func _reset_sparkle(
	sparkle: Control,
	h: ColorRect,
	v: ColorRect,
	core: ColorRect
) -> void:
	if not is_instance_valid(sparkle):
		return
	sparkle.modulate.a = 0.0
	sparkle.global_position = _random_stage_sparkle_position() - sparkle.size * 0.5
	sparkle.rotation_degrees = randf_range(-8.0, 8.0)
	h.scale.x = randf_range(0.28, 0.52)
	v.scale.y = randf_range(0.3, 0.54)
	if core and is_instance_valid(core):
		core.scale = Vector2(randf_range(0.72, 0.9), randf_range(0.72, 0.9))


func _random_stage_sparkle_position() -> Vector2:
	var card_origin: Vector2 = global_position
	return _random_perimeter_pos(
		card_origin.x,
		card_origin.y,
		CARD_SIZE.x,
		CARD_SIZE.y,
		randi() % 4
	)


# ---------------------------------------------------------------------------
# Cleanup — kills tweens AND frees all sparkles added to the stage.
# ---------------------------------------------------------------------------

## `stage_sparkles` is the list of sparkle Controls that were parented to stage.
## PackOpening collects them and passes the list here on close.
var _stage_sparkles: Array[Control] = []

func register_stage_sparkle(s: Control) -> void:
	_stage_sparkles.append(s)

func stop_all() -> void:
	for t in _tweens:
		if t and t.is_valid():
			t.kill()
	_tweens.clear()
	for s in _stage_sparkles:
		if s and is_instance_valid(s):
			s.queue_free()
	_stage_sparkles.clear()
