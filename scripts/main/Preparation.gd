extends Control

const RunConfigData = preload("res://scripts/data/RunConfig.gd")
const PlayerStorageData = preload("res://scripts/data/PlayerStorage.gd")

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CARD_SCENE := preload("res://scenes/ui/CardView.tscn")
const BACKGROUND_SHADER := preload("res://shaders/main_menu_background.gdshader")
const SELECTED_CARD_BASE_TEXTURE := preload("res://assets/ui/card-base.png")
const MAGIC_BALL_TEXTURE := preload("res://assets/item/magic-ball.png")
const SHIELD_TEXTURE := preload("res://assets/item/shield.png")
const REMEDY_KIT_TEXTURE := preload("res://assets/item/remedy-kit.png")
const CUP_A_JOE_TEXTURE := preload("res://assets/item/cup-a-joe.png")
const SNAKE_OIL_TEXTURE := preload("res://assets/item/snake-oil.png")
const POCKETWATCH_TEXTURE := preload("res://assets/item/pocketwatch.png")
const VELVET_GLOVES_TEXTURE := preload("res://assets/item/velvet-gloves.png")
const TOOLTIP_BOX_SCENE := preload("res://scenes/ui/TooltipBox.tscn")
var STAR_CRUSH_FONT := preload("res://fonts/Star Crush.otf")


const STAGES := [
	{
		"id": "wounderland",
		"name": "The Wounderland",
		"boss": "Mad Hatter",
		"boss_id": "mad_hatter",
		"icon": "res://assets/icon/enemy/mad-hatter.png",
		"color": Color("#B83ACB"),
	},
	{
		"id": "bulwark",
		"name": "The Bulwark",
		"boss": "Iron Tortoise",
		"boss_id": "iron_tortoise",
		"icon": "res://assets/icon/enemy/iron-tortoise.png",
		"color": Color("#2F6B3E"),
	},
	{
		"id": "verdict",
		"name": "The Verdict",
		"boss": "Guillotine Duke",
		"boss_id": "guillotine_duke",
		"icon": "res://assets/icon/enemy/guillotine-duke.png",
		"color": Color("#9F7B24"),
	},
]

const HOVER_SCALE := Vector2(1.08, 1.08)
const PRESSED_SCALE := Vector2(0.94, 0.94)
const NORMAL_SCALE := Vector2.ONE

var _selected_stage_index := 0
var _stage_panel: PixelFramePanel
var _stage_prefix_label: Label
var _stage_title_label: Label
var _stage_icon: TextureRect
var _stage_prev_button: Button
var _stage_next_button: Button
var _collection_sections: VBoxContainer
var _selected_count_label: Label
var _selected_count_feedback_tween: Tween
var _consumable_grid: GridContainer
var _active_tooltip: Control = null


func _ready() -> void:
	STAR_CRUSH_FONT.multichannel_signed_distance_field = true
	_build_ui()


func _build_ui() -> void:
	_build_background()

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 34)
	root_margin.add_theme_constant_override("margin_top", 20)
	root_margin.add_theme_constant_override("margin_right", 34)
	root_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(root_margin)

	var main_layout := VBoxContainer.new()
	main_layout.add_theme_constant_override("separation", 14)
	root_margin.add_child(main_layout)

	var back_btn_bundle := _make_back_button()
	var back_frame := back_btn_bundle["frame"] as PixelFramePanel
	var back_button := back_btn_bundle["button"] as Button
	back_button.pressed.connect(func() -> void:
		_play_sfx("click")
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
	)
	main_layout.add_child(back_frame)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout.add_child(columns)

	var collection_panel := _make_panel()
	collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_panel.size_flags_stretch_ratio = 4.0
	columns.add_child(collection_panel)
	_build_collection(collection_panel)

	var side_panel := _make_panel()
	side_panel.custom_minimum_size = Vector2(230, 0)
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_stretch_ratio = 1.0
	columns.add_child(side_panel)
	_build_side_panel(side_panel)


func _build_collection(parent: Control) -> void:
	var margin := _make_margin(24, 20, 24, 20)
	parent.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(header)

	var title := _make_label("CARD COLLECTION", 34, Color(1.0, 0.88, 0.48, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_selected_count_label = _make_label("", 18, Color(0.66, 0.94, 0.92, 1.0))
	_selected_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_selected_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_collection_sections = VBoxContainer.new()
	_collection_sections.add_theme_constant_override("separation", 42)
	_collection_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_collection_sections)

	_rebuild_card_collection()


func _build_side_panel(parent: Control) -> void:
	var margin := _make_margin(16, 18, 16, 18)
	parent.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	content.add_child(_make_label("CONSUMABLES", 22, Color(1.0, 0.88, 0.48, 1.0)))

	var consumable_scroll := ScrollContainer.new()
	consumable_scroll.custom_minimum_size = Vector2(0, 260)
	consumable_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	consumable_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(consumable_scroll)

	var consumable_grid := GridContainer.new()
	_consumable_grid = consumable_grid
	consumable_grid.columns = 2
	consumable_grid.add_theme_constant_override("h_separation", 10)
	consumable_grid.add_theme_constant_override("v_separation", 10)
	consumable_scroll.add_child(consumable_grid)
	_add_owned_consumables(consumable_grid)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	content.add_child(_make_label("STAGE", 22, Color(1.0, 0.88, 0.48, 1.0)))
	_build_stage_selector(content)
	_update_stage_selector()

	var play_bundle := _make_framed_button("PLAY", Vector2(0, 58), 24)
	var play_frame := play_bundle["frame"] as PixelFramePanel
	var play_button := play_bundle["button"] as Button
	play_button.pressed.connect(_on_play_pressed)
	content.add_child(play_frame)


func _add_card_section(parent: VBoxContainer, title_text: String, type: CardDef.CardType, color: Color) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)

	var title := _make_label(title_text, 22, color.lightened(0.25))
	section.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	section.add_child(grid)

	for card in PlayerStorageData.weapon_cards():
		if card.card_type == type:
			grid.add_child(_make_card_preview(card, _is_card_selected(card)))


func _make_card_preview(card: CardDef, selected: bool) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(208, 308)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.gui_input.connect(_on_card_preview_gui_input.bind(int(card.get_meta("storage_index", -1))))
	wrapper.mouse_entered.connect(_on_card_mouse_entered.bind(wrapper, card))
	wrapper.mouse_exited.connect(_on_card_mouse_exited)

	if selected:
		var selected_back := TextureRect.new()
		selected_back.texture = SELECTED_CARD_BASE_TEXTURE
		selected_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		selected_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		selected_back.stretch_mode = TextureRect.STRETCH_SCALE
		selected_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected_back.size = Vector2(208, 308)
		selected_back.position = Vector2.ZERO
		selected_back.pivot_offset = selected_back.size * 0.5
		selected_back.modulate = Color(0.35, 0.72, 1.0, 0.42)
		wrapper.add_child(selected_back)
		_start_selected_card_pulse(selected_back)

	var card_view: CardView = CARD_SCENE.instantiate()
	card_view.set_card_data(card)
	card_view.set_interaction_enabled(false)
	card_view.scale = Vector2(1.2, 1.2)
	card_view.position = wrapper.custom_minimum_size * 0.5 - card_view.pivot_offset

	var name_lbl = card_view.get_node_or_null("%NameLabel")
	if name_lbl:
		name_lbl.add_theme_font_override("font", STAR_CRUSH_FONT)
	var desc_lbl = card_view.get_node_or_null("%DescriptionLabel")
	if desc_lbl:
		desc_lbl.add_theme_font_override("normal_font", STAR_CRUSH_FONT)

	wrapper.add_child(card_view)

	return wrapper


func _is_card_selected(card: CardDef) -> bool:
	if not card.has_meta("storage_index"):
		return false
	return PlayerStorageData.is_weapon_selected(int(card.get_meta("storage_index")))


func _rebuild_card_collection() -> void:
	for child in _collection_sections.get_children():
		child.queue_free()
	_add_card_section(_collection_sections, "ROCK", CardDef.CardType.ROCK, Color("#8791A0"))
	_add_card_section(_collection_sections, "PAPER", CardDef.CardType.PAPER, Color("#E0D58A"))
	_add_card_section(_collection_sections, "SCISSORS", CardDef.CardType.SCISSORS, Color("#A74D55"))
	_update_selected_count_label()


func _update_selected_count_label() -> void:
	if _selected_count_feedback_tween == null or not _selected_count_feedback_tween.is_valid():
		_reset_selected_count_visual()
	_selected_count_label.text = "Selected %d/9" % PlayerStorageData.selected_weapon_count()


func _on_card_preview_gui_input(event: InputEvent, storage_index: int) -> void:
	var clicked: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed
	if not clicked:
		return
	if PlayerStorageData.toggle_weapon_selected(storage_index):
		_play_sfx("click")
		_rebuild_card_collection()
	accept_event()


func _start_selected_card_pulse(node: CanvasItem) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 0.7, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2(1.018, 1.018), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain()
	tween.tween_property(node, "modulate:a", 0.42, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_owned_consumables(parent: GridContainer) -> void:
	var counts := PlayerStorageData.consumable_counts()
	var definitions := [
		{ "id": PlayerStorageData.CONSUMABLE_MAGIC_BALL, "name": "Magic Ball", "texture": MAGIC_BALL_TEXTURE },
		{ "id": PlayerStorageData.CONSUMABLE_SHIELD, "name": "Shield", "texture": SHIELD_TEXTURE },
		{ "id": PlayerStorageData.CONSUMABLE_REMEDY_KIT, "name": "Remedy Kit", "texture": REMEDY_KIT_TEXTURE },
		{ "id": PlayerStorageData.CONSUMABLE_CUP_A_JOE, "name": "Cup-a-Joe", "texture": CUP_A_JOE_TEXTURE },
		{ "id": PlayerStorageData.CONSUMABLE_SNAKE_OIL, "name": "Snake Oil", "texture": SNAKE_OIL_TEXTURE },
		{ "id": PlayerStorageData.CONSUMABLE_POCKETWATCH, "name": "Pocketwatch", "texture": POCKETWATCH_TEXTURE },
		{ "id": PlayerStorageData.CONSUMABLE_VELVET_GLOVES, "name": "Velvet Gloves", "texture": VELVET_GLOVES_TEXTURE },
	]
	var has_any := false
	for definition in definitions:
		var count := int(counts.get(definition["id"], 0))
		if count <= 0:
			continue
		has_any = true
		_add_consumable(parent, str(definition["id"]), str(definition["name"]), definition["texture"] as Texture2D, count)
	if has_any:
		return

	var empty := _make_label("No consumables owned.", 13, Color(0.68, 0.76, 0.72, 1.0))
	empty.custom_minimum_size = Vector2(180, 44)
	parent.add_child(empty)


func _add_consumable(parent: GridContainer, consumable_id: String, name: String, texture: Texture2D, count: int) -> void:
	var item := Control.new()
	item.custom_minimum_size = Vector2(92, 112)
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.gui_input.connect(_on_consumable_gui_input.bind(consumable_id))
	parent.add_child(item)

	var selected := PlayerStorageData.is_consumable_selected(consumable_id)
	if selected:
		var selected_back := TextureRect.new()
		selected_back.texture = SELECTED_CARD_BASE_TEXTURE
		selected_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		selected_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		selected_back.stretch_mode = TextureRect.STRETCH_SCALE
		selected_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected_back.size = Vector2(92, 112)
		selected_back.position = Vector2.ZERO
		selected_back.pivot_offset = selected_back.size * 0.5
		selected_back.modulate = Color(0.35, 0.72, 1.0, 0.42)
		item.add_child(selected_back)
		_start_selected_card_pulse(selected_back)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(74, 74)
	icon.size = Vector2(74, 74)
	icon.position = Vector2(9, 2)
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(icon)

	var label := _make_label(name, 12, Color(0.84, 0.9, 0.84, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 80)
	label.size = Vector2(92, 30)
	item.add_child(label)

	var badge := Label.new()
	badge.text = "x%d" % count
	badge.size = Vector2(38, 22)
	badge.position = Vector2(52, 56)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62, 1.0))
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	badge.add_theme_constant_override("shadow_offset_y", 2)
	item.add_child(badge)


func _on_consumable_gui_input(event: InputEvent, consumable_id: String) -> void:
	var clicked: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed
	if not clicked:
		return
	if PlayerStorageData.toggle_consumable_selected(consumable_id):
		_play_sfx("click")
		_rebuild_consumable_grid()
	else:
		_play_sfx("buzzer")
	accept_event()


func _rebuild_consumable_grid() -> void:
	if not is_instance_valid(_consumable_grid):
		return
	for child in _consumable_grid.get_children():
		child.queue_free()
	_add_owned_consumables(_consumable_grid)


func _build_stage_selector(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 86)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_stage_prev_button = _make_chevron_flat_button(true, Vector2(36, 78))
	_stage_prev_button.pressed.connect(func() -> void:
		_selected_stage_index = maxi(0, _selected_stage_index - 1)
		_play_sfx("click")
		_update_stage_selector()
	)
	row.add_child(_stage_prev_button)

	_stage_panel = PixelFramePanel.new()
	_stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_panel.custom_minimum_size = Vector2(0, 76)
	_configure_pixel_frame(
		_stage_panel,
		Color(0.08, 0.06, 0.09, 0.98),
		Color(0.9, 0.72, 0.36, 0.95),
		Color(0.16, 0.1, 0.16, 1.0),
		1.0,
		false
	)
	row.add_child(_stage_panel)

	var stage_margin := MarginContainer.new()
	stage_margin.add_theme_constant_override("margin_left", 24)
	stage_margin.add_theme_constant_override("margin_top", 8)
	stage_margin.add_theme_constant_override("margin_right", 10)
	stage_margin.add_theme_constant_override("margin_bottom", 8)
	_stage_panel.add_child(stage_margin)

	var stage_content := HBoxContainer.new()
	stage_content.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_content.add_theme_constant_override("separation", 2)
	stage_margin.add_child(stage_content)

	_stage_icon = TextureRect.new()
	_stage_icon.custom_minimum_size = Vector2(42, 42)
	_stage_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage_content.add_child(_stage_icon)

	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 0)
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.custom_minimum_size = Vector2(98, 60)
	stage_content.add_child(text_stack)

	_stage_prefix_label = _make_label("THE", 11, Color(1.0, 0.88, 0.58, 0.9))
	_stage_prefix_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_stack.add_child(_stage_prefix_label)

	_stage_title_label = _make_label("", 24, Color(1.0, 0.95, 0.72, 1.0))
	_stage_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_title_label.clip_text = true
	_stage_title_label.custom_minimum_size = Vector2(0, 30)
	_stage_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_child(_stage_title_label)

	_stage_next_button = _make_chevron_flat_button(false, Vector2(36, 78))
	_stage_next_button.pressed.connect(func() -> void:
		_selected_stage_index = mini(STAGES.size() - 1, _selected_stage_index + 1)
		_play_sfx("click")
		_update_stage_selector()
	)
	row.add_child(_stage_next_button)


func _update_stage_selector() -> void:
	var stage: Dictionary = STAGES[_selected_stage_index]
	var color: Color = stage["color"]
	var stage_fill := Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 0.96)
	_stage_panel.base_tint = stage_fill
	_stage_panel.base_fill_tint = stage_fill
	_stage_panel.base_outline_tint = color.darkened(0.35)
	_stage_panel.frame_outline_tint = color.lightened(0.3)
	_stage_panel.queue_redraw()
	_stage_title_label.text = _stage_display_name(str(stage["name"]))
	_stage_title_label.add_theme_font_size_override("font_size", _stage_title_font_size(str(stage["name"])))
	_stage_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72, 1.0))
	_stage_icon.texture = load(str(stage["icon"])) if ResourceLoader.exists(str(stage["icon"])) else null
	_set_chevron_disabled(_stage_prev_button, _selected_stage_index <= 0)
	_set_chevron_disabled(_stage_next_button, _selected_stage_index >= STAGES.size() - 1)


func _on_play_pressed() -> void:
	if PlayerStorageData.selected_weapon_count() < 9:
		_play_sfx("buzzer")
		_play_selected_count_error_feedback()
		return
	_play_sfx("click")
	var stage: Dictionary = STAGES[_selected_stage_index]
	RunConfigData.configure_stage(str(stage["id"]), str(stage["boss_id"]))
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _make_panel() -> PixelFramePanel:
	var panel := PixelFramePanel.new()
	_configure_pixel_frame(
		panel,
		Color(0.025, 0.04, 0.038, 0.86),
		Color(0.78, 0.63, 0.32, 0.94),
		Color(0.08, 0.11, 0.1, 1.0),
		2.0,
		false
	)
	return panel


func _make_framed_button(
	text: String,
	minimum_size: Vector2,
	font_size: int,
	frame_scale := 1.5
) -> Dictionary:
	var frame := PixelFramePanel.new()
	frame.custom_minimum_size = minimum_size
	_configure_pixel_frame(
		frame,
		Color(0.12, 0.07, 0.12, 1.0),
		Color(1.0, 0.86, 0.42, 1.0),
		Color(0.26, 0.12, 0.2, 1.0),
		frame_scale
	)

	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.82, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 0.68, 0.3, 1.0))
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	frame.add_child(button)
	return { "frame": frame, "button": button }


func _configure_pixel_frame(
	frame: PixelFramePanel,
	fill: Color,
	outline: Color,
	base_outline: Color,
	scale: float,
	shining := true
) -> void:
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.base_tint = fill
	frame.base_fill_tint = fill
	frame.frame_outline_tint = outline
	frame.base_outline_tint = base_outline
	frame.component_scale = scale
	frame.top_right_corner_variant = PixelFramePanel.TopRightCornerVariant.SHINING \
		if shining else PixelFramePanel.TopRightCornerVariant.NORMAL


func _stage_display_name(stage_name: String) -> String:
	return stage_name.trim_prefix("The ")


func _stage_title_font_size(stage_name: String) -> int:
	var display := _stage_display_name(stage_name)
	if display.length() >= 12:
		return 16
	if display.length() >= 10:
		return 18
	return 22


func _build_background() -> void:
	var fallback := ColorRect.new()
	fallback.color = Color(0.01, 0.045, 0.04, 1.0)
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fallback)

	var viewport_container := SubViewportContainer.new()
	viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport_container.stretch = true
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var shader_canvas := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	shader_canvas.material = material
	shader_canvas.color = Color.WHITE
	shader_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_canvas.offset_right = 320
	shader_canvas.offset_bottom = 180
	viewport.add_child(shader_canvas)


func _make_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label


func _play_sfx(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	var manager: Node = get_tree().get_first_node_in_group("sfx_manager")
	if manager:
		manager.play_sfx(sfx_name, volume_offset_db)


func _play_selected_count_error_feedback() -> void:
	if _selected_count_feedback_tween and _selected_count_feedback_tween.is_valid():
		_selected_count_feedback_tween.kill()
	_reset_selected_count_visual()
	_selected_count_label.pivot_offset = _selected_count_label.size * 0.5
	_selected_count_label.add_theme_color_override("font_color", Color(1.0, 0.34, 0.28, 1.0))
	_selected_count_label.add_theme_color_override("font_shadow_color", Color(0.6, 0.0, 0.0, 1.0))
	_selected_count_label.add_theme_constant_override("shadow_offset_x", 0)
	_selected_count_label.add_theme_constant_override("shadow_offset_y", 4)

	_selected_count_feedback_tween = create_tween()
	_selected_count_feedback_tween.set_parallel(true)
	_selected_count_feedback_tween.tween_property(
		_selected_count_label,
		"scale",
		Vector2(1.08, 1.08),
		0.07
	)
	_selected_count_feedback_tween.tween_property(
		_selected_count_label,
		"rotation_degrees",
		-3.0,
		0.045
	)
	_selected_count_feedback_tween.chain()
	_selected_count_feedback_tween.tween_property(_selected_count_label, "rotation_degrees", 3.0, 0.055)
	_selected_count_feedback_tween.tween_property(_selected_count_label, "rotation_degrees", -2.0, 0.05)
	_selected_count_feedback_tween.tween_property(_selected_count_label, "rotation_degrees", 1.5, 0.045)
	_selected_count_feedback_tween.tween_property(_selected_count_label, "rotation_degrees", 0.0, 0.04)
	_selected_count_feedback_tween.parallel().tween_property(_selected_count_label, "scale", Vector2.ONE, 0.22)
	_selected_count_feedback_tween.tween_interval(0.22)
	_selected_count_feedback_tween.tween_callback(func() -> void:
		_reset_selected_count_visual()
		_selected_count_label.set_deferred("rotation_degrees", 0.0)
		_selected_count_label.set_deferred("scale", Vector2.ONE)
		_selected_count_label.add_theme_color_override("font_color", Color(0.66, 0.94, 0.92, 1.0))
		_selected_count_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
		_selected_count_label.add_theme_constant_override("shadow_offset_y", 3)
	)


func _reset_selected_count_visual() -> void:
	if not is_instance_valid(_selected_count_label):
		return
	_selected_count_label.rotation_degrees = 0.0
	_selected_count_label.scale = Vector2.ONE


func _make_back_button() -> Dictionary:
	var frame := PixelFramePanel.new()
	frame.custom_minimum_size = Vector2(210, 48)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_configure_pixel_frame(
		frame,
		Color(0.12, 0.07, 0.12, 1.0),
		Color(1.0, 0.86, 0.42, 1.0),
		Color(0.26, 0.12, 0.2, 1.0),
		1.2
	)

	var button := Button.new()
	button.flat = true
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	frame.add_child(button)
	_setup_menu_button_preparations(button, frame)

	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)

	var icon := TextureRect.new()
	icon.texture = preload("res://assets/ui/chevron-left.png")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(16, 16)
	content.add_child(icon)

	var label := Label.new()
	label.text = "Back to Main Menu"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_y", 2)
	content.add_child(label)

	return { "frame": frame, "button": button }


func _make_chevron_flat_button(is_left: bool, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = minimum_size
	button.flat = true
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())

	var icon := TextureRect.new()
	icon.texture = preload("res://assets/ui/chevron-left.png")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.flip_h = not is_left
	icon.size = Vector2(24, 24)
	
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -12
	icon.offset_top = -12
	icon.offset_right = 12
	icon.offset_bottom = 12
	button.add_child(icon)

	button.pivot_offset = minimum_size * 0.5
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.mouse_entered.connect(func() -> void: _tween_node_scale(button, HOVER_SCALE, 0.12))
	button.mouse_exited.connect(func() -> void: _tween_node_scale(button, NORMAL_SCALE, 0.12))
	button.button_down.connect(func() -> void: _tween_node_scale(button, PRESSED_SCALE, 0.06))
	button.button_up.connect(func() -> void:
		var target_scale := HOVER_SCALE if button.is_hovered() else NORMAL_SCALE
		_tween_node_scale(button, target_scale, 0.1)
	)

	return button


func _setup_menu_button_preparations(button: Button, frame: PixelFramePanel) -> void:
	frame.pivot_offset = frame.size * 0.5
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	button.mouse_entered.connect(func() -> void: _tween_button_frame(frame, HOVER_SCALE, 0.12))
	button.mouse_exited.connect(func() -> void:
		if not button.button_pressed:
			_tween_button_frame(frame, NORMAL_SCALE, 0.12)
	)
	button.button_down.connect(func() -> void: _tween_button_frame(frame, PRESSED_SCALE, 0.06))
	button.button_up.connect(func() -> void:
		var target_scale := HOVER_SCALE if button.is_hovered() else NORMAL_SCALE
		_tween_button_frame(frame, target_scale, 0.1)
	)


func _tween_button_frame(frame: PixelFramePanel, target_scale: Vector2, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(frame, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _tween_node_scale(node: Control, target_scale: Vector2, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _set_chevron_disabled(button: Button, disabled: bool) -> void:
	button.disabled = disabled
	if button.get_child_count() > 0:
		var icon := button.get_child(0) as TextureRect
		if icon:
			icon.modulate = Color(0.24, 0.24, 0.24, 0.5) if disabled else Color.WHITE


func _on_card_mouse_entered(wrapper: Control, card: CardDef) -> void:
	if not card or not card.keywords or card.keywords.is_empty():
		return
	var tooltip_pos := wrapper.global_position + Vector2(wrapper.size.x + 12.0, 8.0)
	_show_tooltip(card.keywords, tooltip_pos)


func _on_card_mouse_exited() -> void:
	_hide_tooltip()


func _show_tooltip(keywords: Array[String], global_pos: Vector2) -> void:
	_hide_tooltip()
	if keywords.is_empty():
		return
	var tooltip := TOOLTIP_BOX_SCENE.instantiate() as Control
	var text := ""
	for kw in keywords:
		var desc := EffectKeyword.get_description(kw)
		if desc:
			text += "[color=%s]%s[/color]: %s\n" % [EffectKeyword.get_color(kw), kw, desc]
	var rich_label := tooltip.get_node_or_null("Panel/RichTextLabel") as RichTextLabel
	if rich_label:
		rich_label.text = text.strip_edges()
	if text.is_empty():
		tooltip.queue_free()
		return
	add_child(tooltip)
	_active_tooltip = tooltip

	var local_position := get_global_transform().affine_inverse() * global_pos
	var tooltip_size := tooltip.size
	var viewport_size := get_viewport_rect().size
	local_position.x = clampf(local_position.x, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0))
	local_position.y = clampf(local_position.y, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0))
	tooltip.position = local_position
	tooltip.z_index = 2600
	tooltip.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(tooltip, "modulate:a", 1.0, 0.1)


func _hide_tooltip() -> void:
	if _active_tooltip:
		if _active_tooltip.get_parent() == self:
			remove_child(_active_tooltip)
		_active_tooltip.queue_free()
		_active_tooltip = null
