class_name CardRevealFx
extends Control

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

# Tweens owned by this node so they die when the node is freed.
var _tweens: Array[Tween] = []


func setup(card_data: CardDef, card_size: Vector2) -> void:
	size = card_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0

	match card_data.rarity:
		WeaponCatalogData.RARITY_UNCOMMON:
			_add_radial_glow(_uncommon_glow_color(), card_size)
		WeaponCatalogData.RARITY_RARE:
			_add_radial_glow(_rare_glow_color(), card_size)
			_add_sparkle_field(card_size)


# Radial glow
func _uncommon_glow_color() -> Color:
	return Color(0.42, 0.72, 1.0, 0.48)


func _rare_glow_color() -> Color:
	return Color(1.0, 0.54, 0.96, 0.86)


## Draws a large soft radial gradient centred behind the card.
## We use a MeshInstance2D with an ImmediateMesh so we can emit vertex colours
## that blend to transparent at the edges — giving a true radial look without
## needing a shader or a pre-baked texture.
func _add_radial_glow(color: Color, card_size: Vector2) -> void:
	# How far the glow extends beyond the card on each axis.
	var pad_x := card_size.x * 0.72
	var pad_y := card_size.y * 0.58
	var glow_w := card_size.x + pad_x * 2.0
	var glow_h := card_size.y + pad_y * 2.0

	var mesh_inst := MeshInstance2D.new()
	# Centre the glow over the card (which starts at local (0,0)).
	mesh_inst.position = card_size * 0.5

	var im := ImmediateMesh.new()
	_fill_radial_mesh(im, glow_w * 0.5, glow_h * 0.5, color, 48)
	mesh_inst.mesh = im

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mesh_inst.material = mat

	add_child(mesh_inst)

	# Gentle breathe animation.
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(mesh_inst, "scale", Vector2(1.06, 1.04), 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_property(mesh_inst, "scale", Vector2(0.96, 0.98), 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(tween)


## Fills `mesh` with a fan of triangles: centre vertex = opaque `color`,
## outer ring = fully transparent, producing a radial gradient in vertex colour.
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
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		# Ellipse points on the outer ring.
		var p0 := Vector2(cos(a0) * half_w, sin(a0) * half_h)
		var p1 := Vector2(cos(a1) * half_w, sin(a1) * half_h)
		# Centre
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(0.0, 0.0, 0.0))
		# Outer ring
		mesh.surface_set_color(transparent)
		mesh.surface_add_vertex(Vector3(p0.x, p0.y, 0.0))
		mesh.surface_set_color(transparent)
		mesh.surface_add_vertex(Vector3(p1.x, p1.y, 0.0))
	mesh.surface_end()


# Plus-sign sparkles (Rare only)
func _add_sparkle_field(card_size: Vector2) -> void:
	var anchors := [
		Vector2(-28.0, 36.0),
		Vector2(card_size.x + 30.0, 54.0),
		Vector2(-34.0, card_size.y * 0.56),
		Vector2(card_size.x + 36.0, card_size.y * 0.46),
		Vector2(18.0, -28.0),
		Vector2(card_size.x - 18.0, -30.0),
		Vector2(34.0, card_size.y + 30.0),
		Vector2(card_size.x - 42.0, card_size.y + 34.0),
	]
	for index in range(anchors.size()):
		var length := randf_range(28.0, 48.0)
		var color := Color(1.0, randf_range(0.82, 1.0), randf_range(0.92, 1.0), 1.0)
		var sparkle := _create_plus_sparkle(length, color)
		sparkle.position = anchors[index]
		add_child(sparkle)
		_animate_plus_sparkle(sparkle, randf_range(0.0, 0.32))

	for _i in range(28):
		var length := randf_range(22.0, 42.0)
		var color := Color(1.0, randf_range(0.78, 1.0), randf_range(0.9, 1.0), 1.0)
		var sparkle := _create_plus_sparkle(length, color)
		sparkle.position = Vector2(
			randf_range(-58.0, card_size.x + 58.0),
			randf_range(-54.0, card_size.y + 54.0)
		)
		add_child(sparkle)
		_animate_plus_sparkle(sparkle, randf_range(0.0, 1.0))


## Creates a Control holding two Line2D arms (horizontal + vertical).
## Each arm contracts independently so the plus "twinkles" asymmetrically.
func _create_plus_sparkle(length: float, color: Color) -> Control:
	var sparkle := Control.new()
	sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkle.size = Vector2.ZERO
	sparkle.modulate.a = 1.0

	var h := _make_arm(length, 0.0, color)
	h.name = "H"
	var v := _make_arm(length * randf_range(0.88, 1.12), PI * 0.5, color)
	v.name = "V"
	sparkle.add_child(h)
	sparkle.add_child(v)
	return sparkle


func _make_arm(length: float, rotation_rad: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.points = PackedVector2Array([
		Vector2(-length * 0.5, 0.0),
		Vector2( length * 0.5, 0.0),
	])
	line.rotation = rotation_rad
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	line.material = mat
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0),
		color,
		Color(color.r, color.g, color.b, 0.0),
	])
	line.gradient = grad
	return line


## Animates a plus sparkle so each arm contracts along its own axis independently.
## `scale:x` on a rotated Line2D contracts along that line's local X = the arm length.
func _animate_plus_sparkle(sparkle: Control, initial_delay: float) -> void:
	var h := sparkle.get_node("H") as Line2D
	var v := sparkle.get_node("V") as Line2D
	if not h or not v:
		return

	# Each arm gets its own looping tween so phase drift is permanent.
	var h_dur_in  := randf_range(0.22, 0.44)
	var h_dur_out := randf_range(0.32, 0.58)
	var v_dur_in  := randf_range(0.26, 0.48)   # deliberately different
	var v_dur_out := randf_range(0.34, 0.62)

	# Horizontal arm tween.
	var th := create_tween()
	th.set_loops()
	th.tween_interval(initial_delay)
	h.scale.x = randf_range(1.05, 1.35)
	th.tween_property(h, "scale:x", randf_range(1.2, 1.6), h_dur_in) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	th.chain().tween_property(h, "scale:x", randf_range(0.12, 0.28), h_dur_out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tweens.append(th)

	# Vertical arm tween — independent loop, slightly offset phase.
	var tv := create_tween()
	tv.set_loops()
	tv.tween_interval(initial_delay + randf_range(0.05, 0.22))
	v.scale.x = randf_range(1.0, 1.28)
	tv.tween_property(v, "scale:x", randf_range(1.15, 1.55), v_dur_in) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tv.chain().tween_property(v, "scale:x", randf_range(0.14, 0.30), v_dur_out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tweens.append(tv)

	# Overall alpha blink driven by a third independent tween.
	var ta := create_tween()
	ta.set_loops()
	ta.tween_interval(initial_delay * 0.5)
	sparkle.modulate.a = randf_range(0.72, 1.0)
	ta.tween_property(sparkle, "modulate:a", 1.0, randf_range(0.18, 0.36)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ta.chain().tween_property(sparkle, "modulate:a", randf_range(0.06, 0.22), randf_range(0.28, 0.54)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tweens.append(ta)

func stop_all() -> void:
	for t in _tweens:
		if t and t.is_valid():
			t.kill()
	_tweens.clear()
