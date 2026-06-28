class_name BattleSidebar
extends Panel

signal pause_requested

const MAX_HEALTH := 6
const BUTTON_HOVER_SCALE := Vector2(1.04, 1.04)
const BUTTON_PRESS_SCALE := Vector2(0.96, 0.96)

@onready var enemy_hearts: HBoxContainer = %EnemyHearts
@onready var player_hearts: HBoxContainer = %PlayerHearts
@onready var enemy_name: Label = %EnemyName
@onready var enemy_icon: TextureRect = %EnemyIcon
@onready var behavior: Label = %Behavior
@onready var reward: Label = %Reward
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

func _ready() -> void:
	_build_heart_row(enemy_hearts)
	_build_heart_row(player_hearts)
	set_health(MAX_HEALTH, MAX_HEALTH)
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

func set_health(player_health: int, enemy_health: int) -> void:
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
	trial_value.text = "%d / %d" % [trial_current, trial_total]
	clash_value.text = str(clash)

func set_money(amount: int) -> void:
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
	enemy_name.text = str(enemy_data.get("name", "Unknown Rival"))
	behavior.text = str(enemy_data.get("description", "No known pattern."))
	var default_reward := "$$$" if bool(enemy_data.get("is_boss", false)) else "$"
	reward.text = "REWARD  -  %s" % str(enemy_data.get("reward", default_reward))
	var icon_path := str(enemy_data.get("icon", ""))
	enemy_icon.visible = not icon_path.is_empty() and ResourceLoader.exists(icon_path)
	if enemy_icon.visible:
		enemy_icon.texture = load(icon_path)

func clear_history() -> void:
	_enemy_history_cards.clear()
	_player_history_cards.clear()
	_history_turns.clear()
	_history_turn = 0
	_render_history_row(enemy_history, _enemy_history_cards, false)
	_render_history_row(player_history, _player_history_cards, false)
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
