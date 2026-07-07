class_name BattleSidebar
extends Panel

signal pause_requested

const MAX_HEALTH := 6
const BUTTON_HOVER_SCALE := Vector2(1.04, 1.04)
const BUTTON_PRESS_SCALE := Vector2(0.96, 0.96)

const PANEL_TEXTURE := preload("res://assets/ui/panel-window.png")
const STAR_CRUSH_FONT := preload("res://fonts/Star Crush.otf")
const PIXEL_FRAME_SCRIPT := preload("res://scripts/ui/PixelFramePanel.gd")
const STRATEGY_EVALUATOR := preload("res://scripts/game/enemy/EnemyStrategyEvaluator.gd")

# Detailed, human-readable explanation of each enemy strategy. Keyed by strategy_id.
const STRATEGY_DETAILS := {
	"rock_bias": "Leans hard on Rock, throwing it roughly half the time. Paper and Scissors show up only now and then.",
	"paper_bias": "Favours Paper above all, playing it about half the time. Rock and Scissors are rare filler.",
	"scissors_bias": "A Scissors specialist that reaches for the blades about half of every clash.",
	"dice_imp": "Can't stand throwing the same weapon twice, almost always switches, splitting evenly between the two weapons it didn't just play.",
	"echo": "Echoes its last weapon after a loss or draw, doubling down on whatever it just threw.",
	"counter_player": "Studies your previous throw and heavily favours the weapon that beats it.",
	"mirror_player": "Tends to mirror you, repeating the weapon you played last clash.",
	"cowardly": "Fights evenly while healthy, but at 3 hearts or fewer it panics and clings to Rock.",
	"avoid_last": "Rarely repeats itself, steering away from the weapon it threw last.",
	"bruise_toad": "After beating you it presses the wound, countering the throw you just lost with.",
	"gambler": "Mostly random, but every third clash it commits fully to its strongest card in hand.",
	"fog_witch": "Rotates its favoured weapon every 3 clashes, keeping its true pattern hidden in the fog.",
	"ledger": "Counts methodically, cycling its preference Rock, then Paper, then Scissors each clash.",
	"blood_magpie": "After a loss it fixates, throwing the same weapon it just lost with over and over.",
	"mad_hatter": "Cycles four moods every 3 clashes: random, then mirror you, then counter you, then Paper-heavy.",
	"iron_tortoise": "A stubborn wall of Rock that only hardens further as its health drops.",
	"guillotine_duke": "A Scissors duelist that punishes Paper especially — expect blades when you show paper.",
	"hatter_mimic": "Wears a false face. It advertises {face}, yet truly splits its throws between {face} and the {counter} that beats it. The pattern it shows you is only half the story.",
}

const TYPE_LABELS := ["ROCK", "PAPER", "SCISSORS"]
const TYPE_NAMES := ["Rock", "Paper", "Scissors"]
# Weapon that beats each type, by CardType index: Rock->Paper, Paper->Scissors, Scissors->Rock.
const TYPE_COUNTERED_BY := [1, 2, 0]
const TYPE_COLORS := [
	Color(0.60, 0.80, 0.96, 1.0),
	Color(0.78, 0.62, 0.46, 1.0),
	Color(0.92, 0.48, 0.44, 1.0),
]

@onready var enemy_hearts: HBoxContainer = %EnemyHearts
@onready var player_hearts: HBoxContainer = %PlayerHearts
@onready var enemy_name_line1: Label = %EnemyNameLine1
@onready var enemy_name_line2: Label = %EnemyNameLine2
@onready var enemy_icon: TextureRect = %EnemyIcon
@onready var behavior: Label = %Behavior
@onready var reward: Label = %Reward
@onready var info_button: Button = %InfoButton
@onready var enemy_history: HBoxContainer = %EnemyHistory
@onready var player_history: HBoxContainer = %PlayerHistory
@onready var turn_history: HBoxContainer = %TurnHistory
@onready var trial_value: Label = %TrialValue
@onready var clash_value: Label = %ClashValue
@onready var pause_button: Button = %PauseButton
@onready var money_display: Control = %MoneyDisplay
@onready var money_label: Label = %MoneyLabel

var _heart_texture: Texture2D = preload("res://assets/ui/heart.png")
var _enemy_history_cards: Array[CardDef] = []
var _player_history_cards: Array[CardDef] = []
var _history_turns: Array[int] = []
var _history_turn := 0
var _pause_button_tween: Tween
var _money_tween: Tween
var _money_gain_label: Label
var _player_health_displayed := 0
var _enemy_health_displayed := 0
var _heart_fill_tweens: Dictionary = {}

var _enemy_data: Dictionary = {}
var _info_layer: CanvasLayer
var _info_root: Control
var _info_window: Control
var _info_content: VBoxContainer
var _info_window_base_position := Vector2.ZERO
var _info_tween: Tween
var _info_open := false
var _info_close_frame: PixelFramePanel

func _ready() -> void:
	_build_heart_row(enemy_hearts)
	_build_heart_row(player_hearts)
	set_health(0, 0)
	pause_button.pivot_offset = pause_button.size * 0.5
	pause_button.resized.connect(func() -> void: pause_button.pivot_offset = pause_button.size * 0.5)
	pause_button.mouse_entered.connect(_tween_pause_button.bind(BUTTON_HOVER_SCALE, 0.12))
	pause_button.mouse_exited.connect(_on_pause_button_mouse_exited)
	pause_button.button_down.connect(_tween_pause_button.bind(BUTTON_PRESS_SCALE, 0.06))
	pause_button.button_up.connect(_on_pause_button_up)
	pause_button.pressed.connect(func() -> void:
		_play_sfx("click")
		pause_requested.emit()
	)
	_build_info_overlay()
	info_button.pressed.connect(_on_info_pressed)
	info_button.mouse_entered.connect(func() -> void:
		reward.add_theme_color_override("font_color", Color(1.0, 0.95, 0.66, 1.0))
	)
	info_button.mouse_exited.connect(func() -> void:
		reward.add_theme_color_override("font_color", Color(0.98, 0.8, 0.32, 1.0))
	)

func set_health(player_health: int, enemy_health: int) -> void:
	if not player_hearts:
		player_hearts = %PlayerHearts
	if not enemy_hearts:
		enemy_hearts = %EnemyHearts
	_update_heart_row(player_hearts, player_health, _player_health_displayed)
	_update_heart_row(enemy_hearts, enemy_health, _enemy_health_displayed)
	_player_health_displayed = clampi(player_health, 0, MAX_HEALTH)
	_enemy_health_displayed = clampi(enemy_health, 0, MAX_HEALTH)

func _on_pause_button_mouse_exited() -> void:
	if pause_button.button_pressed:
		return
	_tween_pause_button(Vector2.ONE, 0.12)

func _on_pause_button_up() -> void:
	var target_scale := BUTTON_HOVER_SCALE if pause_button.is_hovered() else Vector2.ONE
	_tween_pause_button(target_scale, 0.1)

func _tween_pause_button(target_scale: Vector2, duration: float) -> void:
	if _pause_button_tween and _pause_button_tween.is_valid():
		_pause_button_tween.kill()
	_pause_button_tween = create_tween()
	_pause_button_tween.tween_property(pause_button, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_progress(trial_current: int, trial_total: int, clash: int) -> void:
	if not trial_value: trial_value = %TrialValue
	if not clash_value: clash_value = %ClashValue
	trial_value.text = "%d / %d" % [trial_current, trial_total]
	clash_value.text = str(clash)

func set_money(amount: int) -> void:
	if not money_label: money_label = %MoneyLabel
	money_label.text = str(maxi(0, amount))

func animate_money_gain(amount: int) -> void:
	if amount <= 0:
		return
	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()
	if _money_gain_label and is_instance_valid(_money_gain_label):
		_money_gain_label.queue_free()
	money_display.scale = Vector2.ONE
	var gain_label := Label.new()
	_money_gain_label = gain_label
	gain_label.text = "+$%d" % amount
	gain_label.z_index = 20
	gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gain_label.add_theme_font_size_override("font_size", 22)
	gain_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.74, 1.0))
	gain_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.04, 0.85))
	gain_label.add_theme_constant_override("shadow_offset_x", 1)
	gain_label.add_theme_constant_override("shadow_offset_y", 2)
	money_display.add_child(gain_label)
	gain_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gain_label.position = Vector2(-4.0, -8.0)

	_money_tween = create_tween()
	_money_tween.set_parallel(true)
	_money_tween.tween_property(money_display, "scale", Vector2(1.08, 1.08), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_money_tween.tween_property(gain_label, "position:y", -34.0, 0.62) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_money_tween.tween_property(gain_label, "modulate:a", 0.0, 0.42) \
		.set_delay(0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_money_tween.chain().tween_property(money_display, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_money_tween.finished.connect(func() -> void:
		if is_instance_valid(gain_label):
			gain_label.queue_free()
		if _money_gain_label == gain_label:
			_money_gain_label = null
	)

func set_enemy_info(enemy_data: Dictionary) -> void:
	if not enemy_name_line1: enemy_name_line1 = %EnemyNameLine1
	if not enemy_name_line2: enemy_name_line2 = %EnemyNameLine2
	if not behavior: behavior = %Behavior
	if not reward: reward = %Reward
	if not enemy_icon: enemy_icon = %EnemyIcon

	_enemy_data = enemy_data.duplicate(true)

	var name_str := str(enemy_data.get("name", "Unknown Rival"))
	var parts := name_str.split(" ", true, 1)
	if parts.size() > 1:
		enemy_name_line1.text = parts[0]
		enemy_name_line2.text = parts[1]
		enemy_name_line2.visible = true
	else:
		enemy_name_line1.text = name_str
		enemy_name_line2.text = ""
		enemy_name_line2.visible = false

	behavior.text = _apply_face_placeholders(str(enemy_data.get("description", "No known pattern.")))
	reward.text = "TAP FOR MORE INFO"
	var icon_path := str(enemy_data.get("icon", ""))
	enemy_icon.visible = not icon_path.is_empty() and ResourceLoader.exists(icon_path)
	if enemy_icon.visible:
		enemy_icon.texture = load(icon_path)

func clear_history() -> void:
	_enemy_history_cards.clear()
	_player_history_cards.clear()
	_history_turns.clear()
	_history_turn = 0
	if not enemy_history:
		enemy_history = %EnemyHistory
	if not player_history:
		player_history = %PlayerHistory
	if not turn_history:
		turn_history = %TurnHistory
	_render_history_row(enemy_history, _enemy_history_cards, false)
	_render_history_row(player_history, _player_history_cards, false)
	_render_turn_row(false)


func restore_history(
	p_cards: Array[CardDef],
	e_cards: Array[CardDef],
	turns: Array[int],
	turn_num: int
) -> void:
	_player_history_cards = p_cards.duplicate()
	_enemy_history_cards = e_cards.duplicate()
	_history_turns = turns.duplicate()
	_history_turn = turn_num
	if not enemy_history:
		enemy_history = %EnemyHistory
	if not player_history:
		player_history = %PlayerHistory
	if not turn_history:
		turn_history = %TurnHistory
	_render_history_row(player_history, _player_history_cards, false)
	_render_history_row(enemy_history, _enemy_history_cards, false)
	_render_turn_row(false)

func add_history(player_card: CardDef, enemy_card: CardDef) -> void:
	_history_turn += 1
	_player_history_cards.append(player_card.copy())
	_enemy_history_cards.append(enemy_card.copy())
	_history_turns.append(_history_turn)
	if _player_history_cards.size() > 5:
		_player_history_cards.pop_front()
	if _enemy_history_cards.size() > 5:
		_enemy_history_cards.pop_front()
	if _history_turns.size() > 5:
		_history_turns.pop_front()
	_render_history_row(player_history, _player_history_cards, true)
	_render_history_row(enemy_history, _enemy_history_cards, true)
	_render_turn_row(true)

func _render_history_row(
	container: HBoxContainer,
	cards: Array[CardDef],
	animate_latest: bool
) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for i in range(cards.size()):
		var card := cards[i]
		var entry := Control.new()
		entry.custom_minimum_size = Vector2(30.0, 36.0)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(entry)

		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.texture = load(card.art_path) if ResourceLoader.exists(card.art_path) else null
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.tooltip_text = card.card_name
		entry.add_child(icon)

		if animate_latest and i == cards.size() - 1:
			entry.modulate.a = 0.0
			entry.position.y = -5.0
			entry.scale = Vector2(0.9, 0.9)
			entry.pivot_offset = entry.size * 0.5
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(entry, "modulate:a", 1.0, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(entry, "position:y", 0.0, 0.26) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(entry, "scale", Vector2.ONE, 0.26) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _render_turn_row(animate_latest: bool) -> void:
	for child in turn_history.get_children():
		turn_history.remove_child(child)
		child.queue_free()
	for i in range(_history_turns.size()):
		var turn_label := Label.new()
		turn_label.custom_minimum_size = Vector2(30.0, 14.0)
		turn_label.text = str(_history_turns[i])
		turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turn_label.add_theme_font_size_override("font_size", 10)
		turn_label.modulate = Color(0.58, 0.66, 0.74, 1.0)
		turn_history.add_child(turn_label)
		if animate_latest and i == _history_turns.size() - 1:
			turn_label.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_property(turn_label, "modulate:a", 1.0, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func animate_heart_loss(is_player: bool, health_after_damage: int) -> void:
	var container := player_hearts if is_player else enemy_hearts
	var heart_index := clampi(health_after_damage, 0, MAX_HEALTH - 1)
	if heart_index >= container.get_child_count():
		return

	var source_heart := container.get_child(heart_index) as TextureRect
	if not source_heart:
		return

	var falling_heart := TextureRect.new()
	falling_heart.texture = source_heart.texture
	falling_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	falling_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	falling_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	falling_heart.size = source_heart.size
	falling_heart.pivot_offset = falling_heart.size * 0.5
	get_tree().current_scene.add_child(falling_heart)
	falling_heart.global_position = source_heart.global_position
	falling_heart.z_index = 2500

	# Keep an empty dark heart in the bar while its colored copy falls away.
	source_heart.modulate = Color(0.16, 0.17, 0.2, 0.5)

	var direction := -1.0 if is_player else 1.0
	var jump_position := falling_heart.global_position + Vector2(direction * 7.0, -22.0)
	var fall_position := Vector2(
		falling_heart.global_position.x + direction * randf_range(28.0, 55.0),
		get_viewport_rect().size.y + falling_heart.size.y + 30.0
	)

	var tween := create_tween()
	tween.tween_property(falling_heart, "global_position", jump_position, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		falling_heart,
		"rotation_degrees",
		direction * randf_range(8.0, 15.0),
		0.16
	)
	tween.tween_property(falling_heart, "global_position", fall_position, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		falling_heart,
		"rotation_degrees",
		direction * randf_range(28.0, 42.0),
		0.5
	)
	tween.parallel().tween_property(falling_heart, "modulate:a", 0.15, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	falling_heart.queue_free()
	_update_heart_row(container, health_after_damage)

func _build_heart_row(container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	for i in range(MAX_HEALTH):
		var heart := TextureRect.new()
		heart.custom_minimum_size = Vector2(24.0, 20.0)
		heart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heart.texture = _heart_texture
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(heart)

func _update_heart_row(container: HBoxContainer, health: int, previous_health := -1) -> void:
	var clamped_health := clampi(health, 0, MAX_HEALTH)
	var previous := clampi(previous_health, 0, MAX_HEALTH)
	var should_animate_fill := previous_health >= 0 and clamped_health > previous
	_kill_heart_fill_tween(container)
	for i in range(container.get_child_count()):
		var heart := container.get_child(i) as TextureRect
		if heart:
			heart.visible = true
			heart.modulate = Color.WHITE if i < clamped_health else Color(0.16, 0.17, 0.2, 0.5)
			heart.scale = Vector2.ONE
			if should_animate_fill and i >= previous and i < clamped_health:
				heart.modulate.a = 0.0
				heart.scale = Vector2(0.68, 0.68)
				heart.pivot_offset = heart.size * 0.5
	if should_animate_fill:
		_play_heart_fill_sequence(container, previous, clamped_health)


func _play_heart_fill_sequence(container: HBoxContainer, start_index: int, end_health: int) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	_heart_fill_tweens[container] = tween
	for i in range(start_index, end_health):
		var heart := container.get_child(i) as TextureRect
		if not heart:
			continue
		var delay := float(i - start_index) * 0.07
		tween.tween_property(heart, "modulate:a", 1.0, 0.16) \
			.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(heart, "scale", Vector2(1.18, 1.18), 0.12) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(heart, "scale", Vector2.ONE, 0.12) \
			.set_delay(delay + 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if _heart_fill_tweens.get(container) == tween:
			_heart_fill_tweens.erase(container)
	)


func _kill_heart_fill_tween(container: HBoxContainer) -> void:
	if not _heart_fill_tweens.has(container):
		return
	var tween := _heart_fill_tweens[container] as Tween
	if tween and tween.is_valid():
		tween.kill()
	_heart_fill_tweens.erase(container)


func _play_sfx(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	var manager: Node = get_tree().get_first_node_in_group("sfx_manager")
	if manager:
		manager.play_sfx(sfx_name, volume_offset_db)


func _unhandled_input(event: InputEvent) -> void:
	if _info_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_info()


# --- Enemy info overlay ------------------------------------------------------

func _build_info_overlay() -> void:
	_info_layer = CanvasLayer.new()
	_info_layer.name = "EnemyInfoLayer"
	_info_layer.layer = 960
	add_child(_info_layer)

	var root := Control.new()
	root.name = "EnemyInfoRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	_info_layer.add_child(root)
	_info_root = root

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.005, 0.009, 0.011, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(dim_event: InputEvent) -> void:
		if dim_event is InputEventMouseButton and dim_event.pressed:
			_close_info()
	)
	root.add_child(dim)

	var window := Control.new()
	window.name = "Window"
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.offset_left = -310.0
	window.offset_top = -246.0
	window.offset_right = 310.0
	window.offset_bottom = 246.0
	root.add_child(window)
	_info_window = window

	var panel_image := TextureRect.new()
	panel_image.texture = PANEL_TEXTURE
	panel_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_image.stretch_mode = TextureRect.STRETCH_SCALE
	window.add_child(panel_image)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 52.0
	content.offset_top = 40.0
	content.offset_right = -52.0
	content.offset_bottom = -88.0
	content.add_theme_constant_override("separation", 10)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	window.add_child(content)
	_info_content = content

	_info_close_frame = _make_info_close_button()
	window.add_child(_info_close_frame)


func _make_info_close_button() -> PixelFramePanel:
	var frame := PixelFramePanel.new()
	frame.custom_minimum_size = Vector2(150.0, 52.0)
	frame.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	frame.offset_left = -75.0
	frame.offset_top = -70.0
	frame.offset_right = 75.0
	frame.offset_bottom = -18.0
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.base_tint = Color(0.12, 0.07, 0.12, 1.0)
	frame.frame_outline_tint = Color(1.0, 0.86, 0.42, 1.0)
	frame.base_outline_tint = Color(0.26, 0.12, 0.2, 1.0)
	frame.base_fill_tint = Color(0.12, 0.07, 0.12, 1.0)
	frame.component_scale = 1.6
	frame.top_right_corner_variant = PixelFramePanel.TopRightCornerVariant.SHINING

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.text = "CLOSE"
	button.flat = true
	button.add_theme_font_override("font", STAR_CRUSH_FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.82, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 0.68, 0.3, 1.0))
	for style in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	frame.add_child(button)

	frame.pivot_offset = frame.custom_minimum_size * 0.5
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	button.mouse_entered.connect(_tween_info_close.bind(BUTTON_HOVER_SCALE, 0.12))
	button.mouse_exited.connect(func() -> void:
		if not button.button_pressed:
			_tween_info_close(Vector2.ONE, 0.12)
	)
	button.button_down.connect(_tween_info_close.bind(BUTTON_PRESS_SCALE, 0.06))
	button.button_up.connect(func() -> void:
		_tween_info_close(BUTTON_HOVER_SCALE if button.is_hovered() else Vector2.ONE, 0.1)
	)
	button.pressed.connect(_close_info)
	return frame


func _tween_info_close(target_scale: Vector2, duration: float) -> void:
	if not is_instance_valid(_info_close_frame):
		return
	var tween := create_tween()
	tween.tween_property(_info_close_frame, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_info_pressed() -> void:
	_play_sfx("click")
	_open_info()


func _open_info() -> void:
	if _info_open:
		return
	_info_open = true
	_populate_info_content()
	_info_root.visible = true
	if _info_window_base_position == Vector2.ZERO:
		_info_window_base_position = _info_window.position

	var dim := _info_root.get_node("Dim") as ColorRect
	dim.modulate.a = 0.0
	_info_window.position = _info_window_base_position + Vector2(0.0, get_viewport_rect().size.y)
	_info_window.scale = Vector2(0.96, 0.96)

	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()
	_info_tween = create_tween()
	_info_tween.set_parallel(true)
	_info_tween.tween_property(dim, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_info_tween.tween_property(_info_window, "position", _info_window_base_position, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_info_tween.tween_property(_info_window, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_info() -> void:
	if not _info_open:
		return
	_info_open = false
	_play_sfx("click")
	var dim := _info_root.get_node("Dim") as ColorRect
	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()
	_info_tween = create_tween()
	_info_tween.set_parallel(true)
	_info_tween.tween_property(dim, "modulate:a", 0.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_info_tween.tween_property(
		_info_window,
		"position",
		_info_window_base_position + Vector2(0.0, get_viewport_rect().size.y),
		0.24
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_info_tween.tween_property(_info_window, "scale", Vector2(0.96, 0.96), 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _info_tween.finished
	if not _info_open:
		_info_root.visible = false
		_info_window.position = _info_window_base_position
		_info_window.scale = Vector2.ONE


func _populate_info_content() -> void:
	for child in _info_content.get_children():
		child.queue_free()

	var name_str := str(_enemy_data.get("name", "Unknown Rival"))
	var is_boss := bool(_enemy_data.get("is_boss", false))

	var title := Label.new()
	title.text = name_str
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", STAR_CRUSH_FONT)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 3)
	_info_content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = ("BOSS RIVAL" if is_boss else "RIVAL DOSSIER")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", STAR_CRUSH_FONT)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.96, 0.66, 0.55, 1.0))
	_info_content.add_child(subtitle)

	_info_content.add_child(_make_info_heading("MECHANIC"))

	var strategy_id := str(_enemy_data.get("strategy_id", ""))
	var detail_text := str(STRATEGY_DETAILS.get(
		strategy_id, _enemy_data.get("description", "This rival keeps its methods a secret.")
	))
	detail_text = _apply_face_placeholders(detail_text)
	var rule := str(_enemy_data.get("rule", ""))
	if not rule.is_empty():
		detail_text += "\n(%s)" % rule

	var detail := Label.new()
	detail.text = detail_text
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_override("font", STAR_CRUSH_FONT)
	detail.add_theme_font_size_override("font_size", 19)
	detail.add_theme_color_override("font_color", Color(0.9, 0.86, 0.72, 0.92))
	detail.add_theme_constant_override("line_spacing", 3)
	_info_content.add_child(detail)

	_info_content.add_child(_make_info_heading("DECK COMPOSITION"))

	var hint := Label.new()
	hint.text = "roughly, before it starts scheming"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", STAR_CRUSH_FONT)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.68, 0.7))
	_info_content.add_child(hint)

	var percents := _composition_percents(strategy_id)
	_info_content.add_child(_make_composition_bar(percents))
	_info_content.add_child(_make_composition_legend())


# Substitutes {face}/{counter} in mimic text with the weapon advertised this
# battle and the weapon that counters it. No-op when text has no placeholders.
func _apply_face_placeholders(text: String) -> String:
	if not text.contains("{face}") and not text.contains("{counter}"):
		return text
	var face := int(_enemy_data.get("advertised_face", -1))
	if face < 0 or face >= TYPE_NAMES.size():
		return text.replace("{face}", "one weapon").replace("{counter}", "counter")
	return text.replace("{face}", TYPE_NAMES[face]) \
		.replace("{counter}", TYPE_NAMES[TYPE_COUNTERED_BY[face]])


func _make_info_heading(text: String) -> Label:
	var heading := Label.new()
	heading.text = text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", STAR_CRUSH_FONT)
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.62, 0.72, 0.9, 1.0))
	return heading


func _make_composition_bar(percents: Array) -> Control:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0.0, 30.0)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.06, 0.07, 0.09, 0.85)
	track_style.set_corner_radius_all(6)
	track.add_theme_stylebox_override("panel", track_style)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 3.0
	row.offset_top = 3.0
	row.offset_right = -3.0
	row.offset_bottom = -3.0
	row.add_theme_constant_override("separation", 2)
	track.add_child(row)

	for type in range(3):
		var segment := Panel.new()
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Proportion is carried by the stretch ratio, so no numbers are shown.
		segment.size_flags_stretch_ratio = maxf(float(percents[type]), 0.001)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var segment_style := StyleBoxFlat.new()
		segment_style.bg_color = TYPE_COLORS[type]
		if type == 0:
			segment_style.corner_radius_top_left = 4
			segment_style.corner_radius_bottom_left = 4
		if type == 2:
			segment_style.corner_radius_top_right = 4
			segment_style.corner_radius_bottom_right = 4
		segment.add_theme_stylebox_override("panel", segment_style)
		row.add_child(segment)

	return track


func _make_composition_legend() -> Control:
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 20)

	for type in range(3):
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 7)

		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(16.0, 16.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var swatch_style := StyleBoxFlat.new()
		swatch_style.bg_color = TYPE_COLORS[type]
		swatch_style.set_corner_radius_all(3)
		swatch.add_theme_stylebox_override("panel", swatch_style)
		item.add_child(swatch)

		var label := Label.new()
		label.text = TYPE_LABELS[type]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", STAR_CRUSH_FONT)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.95))
		item.add_child(label)

		legend.add_child(item)

	return legend


func _composition_percents(strategy_id: String) -> Array:
	var evaluator := STRATEGY_EVALUATOR.new()
	var counts: Array = evaluator.deck_type_counts(strategy_id)
	var total := 0
	for count in counts:
		total += int(count)
	if total <= 0:
		return [33, 33, 34]
	# Round to the nearest 5% so the numbers read as an estimate, not a spec sheet.
	var percents: Array = []
	for count in counts:
		var raw := float(int(count)) / float(total) * 100.0
		percents.append(int(round(raw / 5.0)) * 5)
	return percents
