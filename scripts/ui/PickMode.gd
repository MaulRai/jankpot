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
const OVERLAY_ALPHA      := 0.60
const LIFT_OFFSET_Y      := -36.0   # selected cards lift this many px
const SELECTED_SCALE     := Vector2(1.08, 1.08)
const UNSEL_MODULATE     := Color(0.52, 0.52, 0.58, 1.0)
const TWEEN_DURATION     := 0.14

# ── internal state ────────────────────────────────────────────────────────────
var _hand_view:        HandView
var _chosen_callback:  Callable
var _max_pick:         int = 2
var _selected_views:   Array[CardView] = []

# ── ui nodes ─────────────────────────────────────────────────────────────────
var _overlay:      ColorRect
var _hint_label:   Label
var _choose_btn:   Button


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
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_top   = 28.0
	_hint_label.offset_bottom = 56.0
	_hint_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)

	# ── Choose button (right side) ────────────────────────────────────────────
	_choose_btn = Button.new()
	_choose_btn.name   = "ChooseButton"
	_choose_btn.text   = "Choose"
	_choose_btn.visible = false
	# anchor to right-centre of screen
	_choose_btn.anchor_left   = 1.0
	_choose_btn.anchor_right  = 1.0
	_choose_btn.anchor_top    = 0.5
	_choose_btn.anchor_bottom = 0.5
	_choose_btn.offset_left   = -160.0
	_choose_btn.offset_right  = -24.0
	_choose_btn.offset_top    = -28.0
	_choose_btn.offset_bottom = 28.0
	_choose_btn.pressed.connect(_on_choose_pressed)
	# style
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color             = Color(0.18, 0.55, 0.90, 0.95)
	normal_style.corner_radius_top_left    = 10
	normal_style.corner_radius_top_right   = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.content_margin_left  = 18.0
	normal_style.content_margin_right = 18.0
	normal_style.content_margin_top   = 10.0
	normal_style.content_margin_bottom = 10.0
	_choose_btn.add_theme_stylebox_override("normal", normal_style)
	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.24, 0.68, 1.0, 0.98)
	_choose_btn.add_theme_stylebox_override("hover", hover_style)
	_choose_btn.add_theme_font_size_override("font_size", 20)
	_choose_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(_choose_btn)

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

	# Reset visuals so all cards start un-dimmed
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


func _refresh_card_visuals() -> void:
	for cv: CardView in _hand_view.card_views:
		cv.cancel_transform_tween()
		var picked := _selected_views.has(cv)
		var target_pos := cv.base_position + (Vector2(0, LIFT_OFFSET_Y) if picked else Vector2.ZERO)
		var target_scale := SELECTED_SCALE if picked else Vector2.ONE
		var target_mod   := Color.WHITE if picked else UNSEL_MODULATE

		cv.transform_tween = cv.create_tween().set_parallel(true)
		cv.transform_tween.tween_property(cv, "position", target_pos, TWEEN_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cv.transform_tween.tween_property(cv, "scale", target_scale, TWEEN_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cv.transform_tween.tween_property(cv, "modulate", target_mod, TWEEN_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		cv.z_index = 60 if picked else cv.base_z_index


func _update_choose_button() -> void:
	_choose_btn.visible = true   # always show the button during pick mode
	_choose_btn.text = "Choose (%d)" % _selected_views.size() if _selected_views.size() > 0 \
		else "Skip"


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