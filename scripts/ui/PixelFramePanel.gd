class_name PixelFramePanel
extends PanelContainer

const BASE_TEXTURE: Texture2D = preload("res://assets/ui/component/base.png")
const SIDE_TEXTURE: Texture2D = preload("res://assets/ui/component/side.png")
const CORNER_TEXTURE: Texture2D = preload("res://assets/ui/component/corner.png")
const CORNER_SHINING_TEXTURE: Texture2D = preload("res://assets/ui/component/corner-shining.png")

enum TopRightCornerVariant {
	NORMAL,
	SHINING,
}

@export var frame_tint := Color(0.78, 0.84, 0.94, 1.0)
@export var base_tint := Color(0.12, 0.14, 0.18, 1.0)
@export var frame_outline_tint := Color(1.0, 1.0, 1.0, 1.0)
@export var base_outline_tint := Color(0.18, 0.21, 0.28, 1.0)
@export var base_fill_tint := Color(0.12, 0.14, 0.18, 1.0)
@export var frame_alpha := 1.0
@export_range(0.5, 4.0, 0.5) var component_scale := 1.0
@export var top_right_corner_variant: TopRightCornerVariant = TopRightCornerVariant.NORMAL

var _base_texture: Texture2D
var _side_texture: Texture2D
var _corner_texture: Texture2D
var _corner_shining_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rebuild_palette_textures()
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	if not _base_texture or not _side_texture or not _corner_texture or not _corner_shining_texture:
		_rebuild_palette_textures()

	var corner_size := _corner_texture.get_size() * component_scale
	var side_size := _side_texture.get_size() * component_scale

	_draw_base(side_size)
	_draw_sides(corner_size, side_size)
	_draw_corners(corner_size)

func _rebuild_palette_textures() -> void:
	# The component sprites are intentionally two-tone: white for the crisp outline,
	# #cecece for the filler. In side/corner pieces, the filler must match the base
	# color so the frame reads as a shaped panel, not as a separate double-colored rim.
	var frame_outline := _with_alpha(frame_outline_tint, frame_alpha)
	var frame_fill := _with_alpha(base_fill_tint, frame_alpha)
	_base_texture = _make_palette_texture(BASE_TEXTURE, base_outline_tint, base_fill_tint)
	_side_texture = _make_palette_texture(SIDE_TEXTURE, frame_outline, frame_fill)
	_corner_texture = _make_palette_texture(CORNER_TEXTURE, frame_outline, frame_fill)
	_corner_shining_texture = _make_palette_texture(CORNER_SHINING_TEXTURE, frame_outline, frame_fill)

func _make_palette_texture(source_texture: Texture2D, outline_color: Color, fill_color: Color) -> Texture2D:
	var image := source_texture.get_image()
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			var source := image.get_pixel(x, y)
			if source.a <= 0.0:
				continue
			var color := outline_color if _is_source_outline(source) else fill_color
			color.a *= source.a
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _is_source_outline(color: Color) -> bool:
	return color.r >= 0.93 and color.g >= 0.93 and color.b >= 0.93

func _with_alpha(color: Color, alpha_multiplier: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha_multiplier)

func _draw_base(side_size: Vector2) -> void:
	var inset := maxf(1.0, side_size.x)
	var rect := Rect2(Vector2(inset, inset), Vector2(
		maxf(0.0, size.x - inset * 2.0),
		maxf(0.0, size.y - inset * 2.0)
	))
	draw_texture_rect(_base_texture, rect, true, Color.WHITE)

func _draw_sides(corner_size: Vector2, side_size: Vector2) -> void:
	var horizontal_length := maxf(0.0, size.x - corner_size.x * 2.0)
	var vertical_length := maxf(0.0, size.y - corner_size.y * 2.0)

	# The source side is the left edge. Other sides are true rotations of that asset,
	# so the white/gray bevel direction stays consistent around the whole frame.
	_draw_rotated_texture_rect(
		_side_texture,
		Rect2(Vector2(corner_size.x, 0.0), Vector2(side_size.x, horizontal_length)),
		PI * 0.5,
		true,
		Color.WHITE
	)
	_draw_rotated_texture_rect(
		_side_texture,
		Rect2(Vector2(corner_size.x, size.y - side_size.x), Vector2(side_size.x, horizontal_length)),
		-PI * 0.5,
		true,
		Color.WHITE
	)

	_draw_rotated_texture_rect(
		_side_texture,
		Rect2(Vector2(0.0, corner_size.y), Vector2(side_size.x, vertical_length)),
		0.0,
		true,
		Color.WHITE
	)
	_draw_rotated_texture_rect(
		_side_texture,
		Rect2(Vector2(size.x - side_size.x, corner_size.y), Vector2(side_size.x, vertical_length)),
		PI,
		true,
		Color.WHITE
	)

func _draw_corners(corner_size: Vector2) -> void:
	_draw_rotated_texture_rect(
		_corner_texture,
		Rect2(Vector2.ZERO, corner_size),
		0.0,
		false,
		Color.WHITE
	)

	var top_right_corner_texture := _corner_texture
	if top_right_corner_variant == TopRightCornerVariant.SHINING:
		top_right_corner_texture = _corner_shining_texture

	_draw_rotated_texture_rect(
		top_right_corner_texture,
		Rect2(Vector2(size.x - corner_size.x, 0.0), corner_size),
		PI * 0.5,
		false,
		Color.WHITE
	)
	_draw_rotated_texture_rect(
		_corner_texture,
		Rect2(size - corner_size, corner_size),
		PI,
		false,
		Color.WHITE
	)
	_draw_rotated_texture_rect(
		_corner_texture,
		Rect2(Vector2(0.0, size.y - corner_size.y), corner_size),
		-PI * 0.5,
		false,
		Color.WHITE
	)

func _draw_rotated_texture_rect(
	texture: Texture2D,
	rect: Rect2,
	angle: float,
	tile: bool,
	modulate: Color,
	transpose: bool = false
) -> void:
	var origin := _rotated_origin_for_bounds(rect, angle)
	draw_set_transform(origin, angle, Vector2.ONE * component_scale)
	draw_texture_rect(
		texture,
		Rect2(Vector2.ZERO, rect.size / component_scale),
		tile,
		modulate,
		transpose
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _rotated_origin_for_bounds(rect: Rect2, angle: float) -> Vector2:
	if is_equal_approx(angle, PI * 0.5):
		return Vector2(rect.position.x + rect.size.y, rect.position.y)
	if is_equal_approx(angle, -PI * 0.5):
		return Vector2(rect.position.x, rect.position.y + rect.size.x)
	if is_equal_approx(absf(angle), PI):
		return rect.position + rect.size
	return rect.position