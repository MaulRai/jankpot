class_name PickMode
extends CanvasLayer
## Full-screen overlay for selecting cards from the player's hand.
## The board is darkened; cards remain at normal colour, with selected cards
## lifted. A "Choose" button appears on the right once at least one card is
## selected. Calls the supplied callback with the chosen Array[CardView].
##
## Usage (GameController):
##   _pick_mode.start(hand_view, 2, _on_moonlight_discard_chosen)
##
## Callback signature:  func(selected_views: Array[CardView]) -> void

signal chosen(selected_views: Array[CardView])

# ── tunables ──────────────────────────────────────────────────────────────────
const OVERLAY_ALPHA      := 0.40
const LIFT_OFFSET_Y      := -36.0   # selected cards lift this many px
const SELECTED_SCALE     := Vector2(1.08, 1.08)
const UNSEL_MODULATE     := Color(0.52, 0.52, 0.58, 1.0)  # un-picked cards dim to show pick contrast
const HOVER_MODULATE     := Color.WHITE  # hovered/selected cards return to full colour
const TWEEN_DURATION     := 0.14

const STAR_CRUSH_FONT    := preload("res://fonts/Star Crush.otf")

# ── internal state ────────────────────────────────────────────────────────────
var _hand_view:        HandView
var _chosen_callback:  Callable
var _max_pick:         int = 2
var _selected_views:   Array[CardView] = []
var _hovered_view:    CardView  # currently hovered card (for undarken preview)

# ── ui nodes ─────────────────────────────────────────────────────────────────
var _overlay:      ColorRect
var _hint_label:   Label
var _choose_btn:   Button
var _choose_frame: PixelFramePanel


func _ready() -> void:
	layer = 80                     # above cards (z_index ~50) but below modals

	# ── dark overlay ──────────────────────────────────────────────────────────
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, OVERLAY_ALPHA)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# ── hint label (top-centre) ───────────────────────────────────────────────
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "Pick up to %d card(s) to discard, then press Choose." % _max_pick
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_font_override("font", STAR_CRUSH_FONT)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_top   = 28.0
	_hint_label.offset_bottom = 56.0
	_hint_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)

	# ── Choose button (right side, framed in PixelFramePanel) ────────────────
	_choose_frame = PixelFramePanel.new()
	_choose_frame.name = "ChooseFrame"
	_choose_frame.custom_minimum_size = Vector2(110, 44)
	# Use same frame colours as main menu buttons
	_choose_frame.base_tint = Color(0.12, 0.07, 0.12, 1.0)
	_choose_frame.frame_outline_tint = Color(1.0, 0.86, 0.42, 1.0)
	_choose_frame.base_outline_tint = Color(0.26, 0.12, 0.2, 1.0)
	_choose_frame.base_fill_tint = Color(0.12, 0.07, 0.12, 1.0)
	_choose_frame.component_scale = 1.0
	_choose_frame.top_right_corner_variant = PixelFramePanel.TopRightCornerVariant.SHINING
	# anchor to right-centre of screen
	_choose_frame.anchor_left   = 1.0
	_choose_frame.anchor_right  = 1.0
	_choose_frame.anchor_top    = 0.5
	_choose_frame.anchor_bottom = 0.5
	_choose_frame.offset_left   = -110.0
	_choose_frame.offset_right  = -24.0
	_choose_frame.offset_top    = -22.0
	_choose_frame.offset_bottom = 22.0
	_choose_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_choose_frame)

	# Inner button (flat, transparent, sits inside the frame)
	_choose_btn = Button.new()
	_choose_btn.name   = "ChooseButton"
	_choose_btn.text   = "Choose"
	_choose_btn.flat     = true
	_choose_frame.visible = false  # frame starts hidden
	_choose_btn.anchor_left   = 0.0
	_choose_btn.anchor_right  = 1.0
	_choose_btn.anchor_top    = 0.0
	_choose_btn.anchor_bottom = 1.0
	_choose_btn.offset_left   = 0.0
	_choose_btn.offset_right  = 0.0
	_choose_btn.offset_top    = 0.0
	_choose_btn.offset_bottom = 0.0
	_choose_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_choose_btn.pressed.connect(_on_choose_pressed)
	# Transparent theme overrides so the frame's pixel art shows through
	var empty_style := StyleBoxEmpty.new()
	_choose_btn.add_theme_stylebox_override("normal", empty_style)
	_choose_btn.add_theme_stylebox_override("hover", empty_style)
	_choose_btn.add_theme_stylebox_override("pressed", empty_style)
	_choose_btn.add_theme_stylebox_override("focus", empty_style)
	_choose_btn.add_theme_stylebox_override("disabled", empty_style)
	_choose_btn.add_theme_font_override("font", STAR_CRUSH_FONT)
	_choose_btn.add_theme_font_size_override("font_size", 20)
	_choose_btn.add_theme_color_override("font_color", Color(1, 0.93, 0.62, 1))
	_choose_btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.82, 1))
	_choose_btn.add_theme_color_override("font_pressed_color", Color(0.86, 0.68, 0.3, 1))
	_choose_frame.add_child(_choose_btn)

	hide()


# ── public API ────────────────────────────────────────────────────────────────

func start(hand_view: HandView, max_pick: int, on_chosen: Callable) -> void:
	_hand_view       = hand_view
	_max_pick        = max_pick
	_chosen_callback = on_chosen
	_selected_views.clear()

	_hint_label.text = "Pick up to %d card(s) to discard, then press Choose." % _max_pick
	_update_choose_button()

	# Disable drag on every card; clicks will emit card_clicked instead
	for cv: CardView in _hand_view.card_views:
		cv.set_drag_enabled(false)
		cv.set_interaction_enabled(true)
		if not cv.card_clicked.is_connected(_on_card_clicked):
			cv.card_clicked.connect(_on_card_clicked)
		if not cv.card_hovered.is_connected(_on_card_hovered):
			cv.card_hovered.connect(_on_card_hovered)
		if not cv.card_unhovered.is_connected(_on_card_unhovered):
			cv.card_unhovered.connect(_on_card_unhovered)

	_refresh_card_visuals()

	show()


func cleanup() -> void:
	_disconnect_all()
	_restore_card_visuals()
	hide()


# ── card interaction ──────────────────────────────────────────────────────────

func _on_card_clicked(card_view: CardView) -> void:
	if _selected_views.has(card_view):
		# Deselect
		_selected_views.erase(card_view)
	else:
		if _selected_views.size() >= _max_pick:
			return   # already at limit
		_selected_views.append(card_view)

	_refresh_card_visuals()
	_update_choose_button()



func _on_card_hovered(card_view: CardView) -> void:
	_hovered_view = card_view
	_refresh_card_visuals()


func _on_card_unhovered(card_view: CardView) -> void:
	_hovered_view = null
	_refresh_card_visuals()


func _refresh_card_visuals() -> void:
	for cv: CardView in _hand_view.card_views:
		cv.cancel_transform_tween()
		var picked := _selected_views.has(cv)
		var is_hovered := cv == _hovered_view and _hovered_view != null
		var target_pos := cv.base_position + (Vector2(0, LIFT_OFFSET_Y) if picked else Vector2.ZERO)
		var target_scale := SELECTED_SCALE if picked else Vector2.ONE
		var target_mod   := Color.WHITE if picked or is_hovered else UNSEL_MODULATE

		cv.transform_tween = cv.create_tween().set_parallel(true)
		cv.transform_tween.tween_property(cv, "position", target_pos, TWEEN_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cv.transform_tween.tween_property(cv, "scale", target_scale, TWEEN_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cv.transform_tween.tween_property(cv, "modulate", target_mod, TWEEN_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		cv.z_index = 60 if picked else cv.base_z_index


func _update_choose_button() -> void:
	_choose_frame.visible = true   # always show the frame during pick mode
	var count := _selected_views.size()
	_choose_btn.text = "Choose (%d)" % count if count > 0 else "Skip"


# ── confirm ───────────────────────────────────────────────────────────────────

func _on_choose_pressed() -> void:
	var result: Array[CardView] = _selected_views.duplicate()

	_disconnect_all()
	_restore_card_visuals()
	hide()

	if _chosen_callback:
		_chosen_callback.call(result)
	chosen.emit(result)


# ── helpers ───────────────────────────────────────────────────────────────────

func _disconnect_all() -> void:
	if not _hand_view:
		return
	for cv: CardView in _hand_view.card_views:
		if cv.card_clicked.is_connected(_on_card_clicked):
			cv.card_clicked.disconnect(_on_card_clicked)
		if cv.card_hovered.is_connected(_on_card_hovered):
			cv.card_hovered.disconnect(_on_card_hovered)
		if cv.card_unhovered.is_connected(_on_card_unhovered):
			cv.card_unhovered.disconnect(_on_card_unhovered)


func _restore_card_visuals() -> void:
	if not _hand_view:
		return
	for i in range(_hand_view.card_views.size()):
		var cv: CardView = _hand_view.card_views[i]
		cv.cancel_transform_tween()
		cv.position   = cv.base_position
		cv.scale      = Vector2.ONE
		cv.modulate   = Color.WHITE
		cv.z_index    = i
		cv.set_drag_enabled(true)