class_name BattleBoard
extends Control

const MAX_HEALTH := 6
const BLEED_KEYWORD := "Bleed"
const SHIELD_KEYWORD := "Shield"
const CUP_A_JOE_KEYWORD := "Cup-a-Joe"
const EffectKeywordData = preload("res://scripts/data/EffectKeyword.gd")

@onready var player_hearts: HBoxContainer = %PlayerHearts
@onready var enemy_hearts: HBoxContainer = %EnemyHearts
@onready var player_bleed_pulse: TextureRect = %PlayerBleedPulse
@onready var enemy_bleed_pulse: TextureRect = %EnemyBleedPulse
@onready var player_bleed_status: TextureRect = %PlayerBleedStatus
@onready var enemy_bleed_status: TextureRect = %EnemyBleedStatus
@onready var player_shield_pulse: TextureRect = %PlayerShieldPulse
@onready var enemy_shield_pulse: TextureRect = %EnemyShieldPulse
@onready var player_shield_status: TextureRect = %PlayerShieldStatus
@onready var enemy_shield_status: TextureRect = %EnemyShieldStatus
@onready var player_cup_pulse: TextureRect = %PlayerCupPulse
@onready var player_cup_status: TextureRect = %PlayerCupStatus

const POISON_KEYWORD := "Poison"
const AEGIS_KEYWORD := "Aegis"
const POCKETWATCH_KEYWORD := "Pocketwatch"

var player_poison_status: TextureRect
var enemy_poison_status: TextureRect
var player_poison_pulse: TextureRect
var enemy_poison_pulse: TextureRect

var player_aegis_status: TextureRect
var enemy_aegis_status: TextureRect
var player_aegis_pulse: TextureRect
var enemy_aegis_pulse: TextureRect

var player_pocketwatch_status: TextureRect
var player_pocketwatch_pulse: TextureRect

var tooltip_manager: TooltipManager
var _heart_texture: Texture2D = preload("res://assets/ui/heart.png")
var _bleed_texture: Texture2D = preload("res://assets/icon/effect/bleed.png")
var _shield_texture: Texture2D = preload("res://assets/item/shield.png")
var _poison_texture: Texture2D = preload("res://assets/icon/effect/poison.png")
var _pocketwatch_texture: Texture2D = preload("res://assets/item/pocketwatch.png")
var _aegis_texture: Texture2D = preload("res://assets/icon/effect/aegis.png")
var _player_health_displayed := 0
var _enemy_health_displayed := 0
var _heart_fill_tweens: Dictionary = {}


func _ready() -> void:
	_build_heart_row(player_hearts)
	_build_heart_row(enemy_hearts)
	_initialize_poison_nodes()
	_initialize_aegis_nodes()
	_initialize_pocketwatch_nodes()
	set_health(0, 0)
	set_bleed_status(false, false)
	set_shield_status(0, 0)
	set_cup_a_joe_status(false)
	set_poison_status(0, 0)
	set_aegis_status(false, false)
	set_pocketwatch_status(false)
	_connect_status_hover(player_bleed_status, BLEED_KEYWORD)
	_connect_status_hover(enemy_bleed_status, BLEED_KEYWORD)
	_connect_status_hover(player_shield_status, SHIELD_KEYWORD)
	_connect_status_hover(enemy_shield_status, SHIELD_KEYWORD)
	_connect_status_hover(player_cup_status, CUP_A_JOE_KEYWORD)
	_connect_status_hover(player_poison_status, POISON_KEYWORD)
	_connect_status_hover(enemy_poison_status, POISON_KEYWORD)
	_connect_status_hover(player_aegis_status, AEGIS_KEYWORD)
	_connect_status_hover(enemy_aegis_status, AEGIS_KEYWORD)
	_connect_status_hover(player_pocketwatch_status, POCKETWATCH_KEYWORD)


func set_tooltip_manager(manager: TooltipManager) -> void:
	tooltip_manager = manager


func set_health(player_health: int, enemy_health: int) -> void:
	if not player_hearts: player_hearts = %PlayerHearts
	if not enemy_hearts: enemy_hearts = %EnemyHearts
	_update_heart_row(player_hearts, player_health, _player_health_displayed)
	_update_heart_row(enemy_hearts, enemy_health, _enemy_health_displayed)
	_player_health_displayed = clampi(player_health, 0, MAX_HEALTH)
	_enemy_health_displayed = clampi(enemy_health, 0, MAX_HEALTH)


func set_bleed_status(player_bleeding: bool, enemy_bleeding: bool) -> void:
	if not player_bleed_status: player_bleed_status = %PlayerBleedStatus
	if not enemy_bleed_status: enemy_bleed_status = %EnemyBleedStatus
	if not player_bleed_pulse: player_bleed_pulse = %PlayerBleedPulse
	if not enemy_bleed_pulse: enemy_bleed_pulse = %EnemyBleedPulse
	var player_was_visible := player_bleed_status.visible
	var enemy_was_visible := enemy_bleed_status.visible
	player_bleed_status.visible = player_bleeding
	enemy_bleed_status.visible = enemy_bleeding
	if player_bleeding and not player_was_visible:
		_play_bleed_pulse_once(player_bleed_pulse)
	if enemy_bleeding and not enemy_was_visible:
		_play_bleed_pulse_once(enemy_bleed_pulse)


func set_shield_status(player_shields: int, enemy_shields: int) -> void:
	if not player_shield_status: player_shield_status = %PlayerShieldStatus
	if not enemy_shield_status: enemy_shield_status = %EnemyShieldStatus
	if not player_shield_pulse: player_shield_pulse = %PlayerShieldPulse
	if not enemy_shield_pulse: enemy_shield_pulse = %EnemyShieldPulse
	var player_was_visible := player_shield_status.visible
	var enemy_was_visible := enemy_shield_status.visible
	player_shield_status.visible = player_shields > 0
	enemy_shield_status.visible = enemy_shields > 0
	if player_shields > 0 and not player_was_visible:
		_play_status_pulse_once(player_shield_pulse, Color(0.56, 0.85, 1.0, 0.52))
	if enemy_shields > 0 and not enemy_was_visible:
		_play_status_pulse_once(enemy_shield_pulse, Color(0.56, 0.85, 1.0, 0.52))


func set_cup_a_joe_status(is_active: bool) -> void:
	if not player_cup_status: player_cup_status = %PlayerCupStatus
	if not player_cup_pulse: player_cup_pulse = %PlayerCupPulse
	var was_visible := player_cup_status.visible
	if is_active:
		player_cup_status.visible = true
	if is_active and not was_visible:
		_play_status_pulse_once(player_cup_pulse, Color(1.0, 0.77, 0.44, 0.52))
	elif not is_active and was_visible:
		_play_cup_status_expire(player_cup_status)


func play_bleed_damage_feedback(is_player: bool, target_card: Control) -> void:
	_play_bleed_status_expire(player_bleed_status if is_player else enemy_bleed_status)
	_play_card_bleed_overlay(target_card)


func play_shield_block_feedback(is_player: bool, target_card: Control) -> void:
	var status_icon := player_shield_status if is_player else enemy_shield_status
	_play_card_shield_overlay(target_card)
	await _play_shield_status_absorb(status_icon)


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


func animate_heart_loss_burst(is_player: bool, health_before_damage: int, health_after_damage: int) -> void:
	var container := player_hearts if is_player else enemy_hearts
	var start_index := clampi(health_after_damage, 0, MAX_HEALTH)
	var end_index := clampi(health_before_damage - 1, 0, MAX_HEALTH - 1)
	if start_index > end_index:
		return

	var falling_hearts: Array[TextureRect] = []
	for heart_index in range(start_index, end_index + 1):
		if heart_index >= container.get_child_count():
			continue
		var source_heart := container.get_child(heart_index) as TextureRect
		if not source_heart:
			continue

		var falling_heart := TextureRect.new()
		falling_heart.texture = source_heart.texture
		falling_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		falling_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		falling_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		falling_heart.size = source_heart.size
		falling_heart.pivot_offset = falling_heart.size * 0.5
		get_tree().current_scene.add_child(falling_heart)
		falling_heart.global_position = source_heart.global_position
		falling_heart.z_index = 2500 + heart_index
		falling_hearts.append(falling_heart)
		source_heart.modulate = Color(0.16, 0.17, 0.2, 0.5)

	var direction := -1.0 if is_player else 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	for i in range(falling_hearts.size()):
		var heart := falling_hearts[i]
		var spread := float(i) - float(falling_hearts.size() - 1) * 0.5
		var jump_position := heart.global_position + Vector2(direction * (9.0 + spread * 5.0), -24.0 - absf(spread) * 4.0)
		var fall_position := Vector2(
			heart.global_position.x + direction * randf_range(38.0, 68.0) + spread * 10.0,
			get_viewport_rect().size.y + heart.size.y + 30.0
		)
		tween.tween_property(heart, "global_position", jump_position, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(heart, "global_position", fall_position, 0.5) \
			.set_delay(0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(heart, "rotation_degrees", direction * randf_range(32.0, 52.0), 0.66)
		tween.tween_property(heart, "modulate:a", 0.12, 0.5) \
			.set_delay(0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	for heart in falling_hearts:
		heart.queue_free()
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


func _connect_status_hover(status_label: TextureRect, keyword: String) -> void:
	status_label.mouse_filter = Control.MOUSE_FILTER_STOP
	status_label.mouse_entered.connect(_show_status_tooltip.bind(status_label, keyword))
	status_label.mouse_exited.connect(_hide_status_tooltip)


func _show_status_tooltip(status_label: TextureRect, keyword: String) -> void:
	if tooltip_manager:
		tooltip_manager.show_tooltip(
			[keyword],
			status_label.global_position + Vector2(status_label.size.x + 10.0, -6.0)
		)


func _hide_status_tooltip() -> void:
	if tooltip_manager:
		tooltip_manager.hide_tooltip()


func _play_bleed_pulse_once(pulse_icon: TextureRect) -> void:
	_play_status_pulse_once(pulse_icon, Color(1.0, 0.36, 0.36, 0.48))


func _play_status_pulse_once(pulse_icon: TextureRect, tint: Color) -> void:
	pulse_icon.visible = true
	pulse_icon.pivot_offset = pulse_icon.size * 0.5
	pulse_icon.scale = Vector2.ONE
	pulse_icon.modulate = tint

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse_icon, "scale", Vector2(2.35, 2.35), 0.72) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse_icon, "modulate:a", 0.0, 0.72) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	pulse_icon.visible = false
	pulse_icon.scale = Vector2.ONE
	pulse_icon.modulate.a = 0.0


func _play_shield_status_absorb(status_icon: TextureRect) -> void:
	if not status_icon.visible:
		return
	status_icon.pivot_offset = status_icon.size * 0.5
	status_icon.modulate = Color.WHITE

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(status_icon, "scale", Vector2(1.35, 1.35), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(status_icon, "modulate", Color(0.65, 0.9, 1.0, 1.0), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(status_icon, "scale", Vector2(0.72, 0.72), 0.2) \
		.set_delay(0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(status_icon, "modulate:a", 0.0, 0.2) \
		.set_delay(0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	status_icon.visible = false
	status_icon.scale = Vector2.ONE
	status_icon.modulate = Color.WHITE


func _play_bleed_status_expire(status_icon: TextureRect) -> void:
	_play_status_expire_downward(status_icon)


func _play_cup_status_expire(status_icon: TextureRect) -> void:
	_play_status_expire_downward(status_icon)


func _play_card_shield_overlay(target_card: Control) -> void:
	if not target_card or not is_instance_valid(target_card):
		return
	_play_card_status_overlay(
		target_card,
		_shield_texture,
		Color(0.55, 0.88, 1.0, 0.78),
		Vector2(1.55, 1.55)
	)


func _play_card_bleed_overlay(target_card: Control) -> void:
	if not target_card or not is_instance_valid(target_card):
		return
	_play_card_status_overlay(
		target_card,
		_bleed_texture,
		Color(1.0, 0.26, 0.26, 0.78),
		Vector2(1.95, 1.95)
	)


func _play_card_status_overlay(
	target_card: Control,
	texture: Texture2D,
	tint: Color,
	target_scale: Vector2
) -> void:
	if not target_card or not is_instance_valid(target_card):
		return

	var target_size := target_card.size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = target_card.custom_minimum_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = Vector2(160.0, 240.0)

	var overlay := TextureRect.new()
	overlay.texture = texture
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 2000
	overlay.size = Vector2.ONE * minf(target_size.y * 0.72, target_size.x * 1.35)
	overlay.position = (target_size - overlay.size) * 0.5
	overlay.pivot_offset = overlay.size * 0.5
	overlay.scale = Vector2(0.72, 0.72)
	overlay.modulate = tint
	target_card.add_child(overlay)

	var tween := target_card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "scale", target_scale, 0.48) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.48) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "rotation_degrees", randf_range(-8.0, 8.0), 0.48) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	overlay.queue_free()


func _initialize_poison_nodes() -> void:
	# Player Poison Status
	player_poison_status = TextureRect.new()
	player_poison_status.name = "PlayerPoisonStatus"
	player_poison_status.texture = _poison_texture
	player_poison_status.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_poison_status.stretch_mode = TextureRect.STRETCH_SCALE
	player_poison_status.mouse_filter = Control.MOUSE_FILTER_PASS
	player_poison_status.size = Vector2(40, 40)
	player_poison_status.layout_mode = 1
	player_poison_status.anchor_left = 0.0
	player_poison_status.anchor_right = 0.0
	player_poison_status.anchor_top = 0.5
	player_poison_status.anchor_bottom = 0.5
	player_poison_status.offset_left = -164.0
	player_poison_status.offset_top = 122.0
	player_poison_status.offset_right = -124.0
	player_poison_status.offset_bottom = 162.0
	player_poison_status.visible = false
	add_child(player_poison_status)

	var p_badge := Label.new()
	p_badge.name = "Badge"
	p_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_badge.add_theme_font_size_override("font_size", 12)
	p_badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55, 1.0))
	p_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	p_badge.add_theme_constant_override("shadow_offset_y", 2)
	p_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p_badge.offset_left = -20
	p_badge.offset_top = -20
	p_badge.offset_right = 0
	p_badge.offset_bottom = 0
	p_badge.size = Vector2(20, 20)
	player_poison_status.add_child(p_badge)

	# Player Poison Pulse
	player_poison_pulse = TextureRect.new()
	player_poison_pulse.name = "PlayerPoisonPulse"
	player_poison_pulse.texture = _poison_texture
	player_poison_pulse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_poison_pulse.stretch_mode = TextureRect.STRETCH_SCALE
	player_poison_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_poison_pulse.size = Vector2(40, 40)
	player_poison_pulse.layout_mode = 1
	player_poison_pulse.anchor_left = 0.0
	player_poison_pulse.anchor_right = 0.0
	player_poison_pulse.anchor_top = 0.5
	player_poison_pulse.anchor_bottom = 0.5
	player_poison_pulse.offset_left = -164.0
	player_poison_pulse.offset_top = 122.0
	player_poison_pulse.offset_right = -124.0
	player_poison_pulse.offset_bottom = 162.0
	player_poison_pulse.modulate = Color(EffectKeywordData.get_color("Poison"))
	player_poison_pulse.modulate.a = 0.0
	player_poison_pulse.visible = false
	add_child(player_poison_pulse)

	# Enemy Poison Status
	enemy_poison_status = TextureRect.new()
	enemy_poison_status.name = "EnemyPoisonStatus"
	enemy_poison_status.texture = _poison_texture
	enemy_poison_status.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_poison_status.stretch_mode = TextureRect.STRETCH_SCALE
	enemy_poison_status.mouse_filter = Control.MOUSE_FILTER_PASS
	enemy_poison_status.size = Vector2(40, 40)
	enemy_poison_status.layout_mode = 1
	enemy_poison_status.anchor_left = 1.0
	enemy_poison_status.anchor_right = 1.0
	enemy_poison_status.anchor_top = 0.5
	enemy_poison_status.anchor_bottom = 0.5
	enemy_poison_status.offset_left = 124.0
	enemy_poison_status.offset_top = 122.0
	enemy_poison_status.offset_right = 164.0
	enemy_poison_status.offset_bottom = 162.0
	enemy_poison_status.visible = false
	add_child(enemy_poison_status)

	var e_badge := Label.new()
	e_badge.name = "Badge"
	e_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	e_badge.add_theme_font_size_override("font_size", 12)
	e_badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55, 1.0))
	e_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	e_badge.add_theme_constant_override("shadow_offset_y", 2)
	e_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	e_badge.offset_left = -20
	e_badge.offset_top = -20
	e_badge.offset_right = 0
	e_badge.offset_bottom = 0
	e_badge.size = Vector2(20, 20)
	enemy_poison_status.add_child(e_badge)

	# Enemy Poison Pulse
	enemy_poison_pulse = TextureRect.new()
	enemy_poison_pulse.name = "EnemyPoisonPulse"
	enemy_poison_pulse.texture = _poison_texture
	enemy_poison_pulse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_poison_pulse.stretch_mode = TextureRect.STRETCH_SCALE
	enemy_poison_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_poison_pulse.size = Vector2(40, 40)
	enemy_poison_pulse.layout_mode = 1
	enemy_poison_pulse.anchor_left = 1.0
	enemy_poison_pulse.anchor_right = 1.0
	enemy_poison_pulse.anchor_top = 0.5
	enemy_poison_pulse.anchor_bottom = 0.5
	enemy_poison_pulse.offset_left = 124.0
	enemy_poison_pulse.offset_top = 122.0
	enemy_poison_pulse.offset_right = 164.0
	enemy_poison_pulse.offset_bottom = 162.0
	enemy_poison_pulse.modulate = Color(EffectKeywordData.get_color("Poison"))
	enemy_poison_pulse.modulate.a = 0.0
	enemy_poison_pulse.visible = false
	add_child(enemy_poison_pulse)


func set_poison_status(player_poison_turns: int, enemy_poison_turns: int) -> void:
	if not player_poison_status: player_poison_status = get_node_or_null("PlayerPoisonStatus")
	if not enemy_poison_status: enemy_poison_status = get_node_or_null("EnemyPoisonStatus")
	if not player_poison_pulse: player_poison_pulse = get_node_or_null("PlayerPoisonPulse")
	if not enemy_poison_pulse: enemy_poison_pulse = get_node_or_null("EnemyPoisonPulse")
	
	if not player_poison_status:
		return

	var player_was_visible := player_poison_status.visible
	var enemy_was_visible := enemy_poison_status.visible

	player_poison_status.visible = player_poison_turns > 0
	if player_poison_turns > 0:
		var badge := player_poison_status.get_node_or_null("Badge") as Label
		if badge:
			badge.text = str(player_poison_turns)

	enemy_poison_status.visible = enemy_poison_turns > 0
	if enemy_poison_turns > 0:
		var badge := enemy_poison_status.get_node_or_null("Badge") as Label
		if badge:
			badge.text = str(enemy_poison_turns)

	if player_poison_turns > 0 and not player_was_visible:
		_play_poison_pulse_once(player_poison_pulse)
	if enemy_poison_turns > 0 and not enemy_was_visible:
		_play_poison_pulse_once(enemy_poison_pulse)


func play_poison_damage_feedback(is_player: bool, target_card: Control, is_expiring: bool) -> void:
	if is_expiring:
		_play_status_expire_downward(player_poison_status if is_player else enemy_poison_status)
	_play_card_poison_overlay(target_card)


func play_aegis_block_feedback(is_player: bool, target_card: Control) -> void:
	_play_card_aegis_overlay(target_card)
	await _play_status_expire_downward(player_aegis_status if is_player else enemy_aegis_status)


func _play_card_aegis_overlay(target_card: Control) -> void:
	if not target_card or not is_instance_valid(target_card):
		return
	_play_card_status_overlay(
		target_card,
		_aegis_texture,
		Color(1.0, 0.88, 0.42, 0.78),
		Vector2(1.55, 1.55)
	)


func _play_poison_pulse_once(pulse_icon: TextureRect) -> void:
	_play_status_pulse_once(pulse_icon, Color(EffectKeywordData.get_color("Poison")))


func _play_status_expire_downward(status_icon: TextureRect) -> void:
	if not status_icon or not status_icon.visible:
		return
	status_icon.pivot_offset = status_icon.size * 0.5
	var original_pos := status_icon.position
	
	var tween := create_tween().set_parallel(true)
	# Slide downward by 30 pixels
	tween.tween_property(status_icon, "position:y", original_pos.y + 30.0, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(status_icon, "modulate:a", 0.0, 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	status_icon.visible = false
	status_icon.modulate.a = 1.0
	status_icon.position = original_pos


func _play_card_poison_overlay(target_card: Control) -> void:
	if not target_card or not is_instance_valid(target_card):
		return
	var poison_tint := Color(EffectKeywordData.get_color("Poison"))
	poison_tint.a = 0.78
	_play_card_status_overlay(
		target_card,
		_poison_texture,
		poison_tint,
		Vector2(1.95, 1.95)
	)


func _initialize_aegis_nodes() -> void:
	# Player Aegis Status
	player_aegis_status = TextureRect.new()
	player_aegis_status.name = "PlayerAegisStatus"
	player_aegis_status.texture = _aegis_texture
	player_aegis_status.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_aegis_status.stretch_mode = TextureRect.STRETCH_SCALE
	player_aegis_status.mouse_filter = Control.MOUSE_FILTER_PASS
	player_aegis_status.size = Vector2(40, 40)
	player_aegis_status.layout_mode = 1
	player_aegis_status.anchor_left = 0.0
	player_aegis_status.anchor_right = 0.0
	player_aegis_status.anchor_top = 0.5
	player_aegis_status.anchor_bottom = 0.5
	player_aegis_status.offset_left = -214.0
	player_aegis_status.offset_top = 122.0
	player_aegis_status.offset_right = -174.0
	player_aegis_status.offset_bottom = 162.0
	player_aegis_status.visible = false
	add_child(player_aegis_status)

	# Player Aegis Pulse
	player_aegis_pulse = TextureRect.new()
	player_aegis_pulse.name = "PlayerAegisPulse"
	player_aegis_pulse.texture = _aegis_texture
	player_aegis_pulse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_aegis_pulse.stretch_mode = TextureRect.STRETCH_SCALE
	player_aegis_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_aegis_pulse.size = Vector2(40, 40)
	player_aegis_pulse.layout_mode = 1
	player_aegis_pulse.anchor_left = 0.0
	player_aegis_pulse.anchor_right = 0.0
	player_aegis_pulse.anchor_top = 0.5
	player_aegis_pulse.anchor_bottom = 0.5
	player_aegis_pulse.offset_left = -214.0
	player_aegis_pulse.offset_top = 122.0
	player_aegis_pulse.offset_right = -174.0
	player_aegis_pulse.offset_bottom = 162.0
	player_aegis_pulse.modulate = Color(EffectKeywordData.get_color("Aegis"))
	player_aegis_pulse.modulate.a = 0.0
	player_aegis_pulse.visible = false
	add_child(player_aegis_pulse)

	# Enemy Aegis Status
	enemy_aegis_status = TextureRect.new()
	enemy_aegis_status.name = "EnemyAegisStatus"
	enemy_aegis_status.texture = _aegis_texture
	enemy_aegis_status.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_aegis_status.stretch_mode = TextureRect.STRETCH_SCALE
	enemy_aegis_status.mouse_filter = Control.MOUSE_FILTER_PASS
	enemy_aegis_status.size = Vector2(40, 40)
	enemy_aegis_status.layout_mode = 1
	enemy_aegis_status.anchor_left = 1.0
	enemy_aegis_status.anchor_right = 1.0
	enemy_aegis_status.anchor_top = 0.5
	enemy_aegis_status.anchor_bottom = 0.5
	enemy_aegis_status.offset_left = 174.0
	enemy_aegis_status.offset_top = 122.0
	enemy_aegis_status.offset_right = 214.0
	enemy_aegis_status.offset_bottom = 162.0
	enemy_aegis_status.visible = false
	add_child(enemy_aegis_status)

	# Enemy Aegis Pulse
	enemy_aegis_pulse = TextureRect.new()
	enemy_aegis_pulse.name = "EnemyAegisPulse"
	enemy_aegis_pulse.texture = _aegis_texture
	enemy_aegis_pulse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_aegis_pulse.stretch_mode = TextureRect.STRETCH_SCALE
	enemy_aegis_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_aegis_pulse.size = Vector2(40, 40)
	enemy_aegis_pulse.layout_mode = 1
	enemy_aegis_pulse.anchor_left = 1.0
	enemy_aegis_pulse.anchor_right = 1.0
	enemy_aegis_pulse.anchor_top = 0.5
	enemy_aegis_pulse.anchor_bottom = 0.5
	enemy_aegis_pulse.offset_left = 174.0
	enemy_aegis_pulse.offset_top = 122.0
	enemy_aegis_pulse.offset_right = 214.0
	enemy_aegis_pulse.offset_bottom = 162.0
	enemy_aegis_pulse.modulate = Color(EffectKeywordData.get_color("Aegis"))
	enemy_aegis_pulse.modulate.a = 0.0
	enemy_aegis_pulse.visible = false
	add_child(enemy_aegis_pulse)


func _initialize_pocketwatch_nodes() -> void:
	# Player Pocketwatch Status
	player_pocketwatch_status = TextureRect.new()
	player_pocketwatch_status.name = "PlayerPocketwatchStatus"
	player_pocketwatch_status.texture = _pocketwatch_texture
	player_pocketwatch_status.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_pocketwatch_status.stretch_mode = TextureRect.STRETCH_SCALE
	player_pocketwatch_status.mouse_filter = Control.MOUSE_FILTER_PASS
	player_pocketwatch_status.size = Vector2(40, 40)
	player_pocketwatch_status.layout_mode = 1
	player_pocketwatch_status.anchor_left = 0.0
	player_pocketwatch_status.anchor_right = 0.0
	player_pocketwatch_status.anchor_top = 0.5
	player_pocketwatch_status.anchor_bottom = 0.5
	player_pocketwatch_status.offset_left = -264.0
	player_pocketwatch_status.offset_top = 122.0
	player_pocketwatch_status.offset_right = -224.0
	player_pocketwatch_status.offset_bottom = 162.0
	player_pocketwatch_status.visible = false
	add_child(player_pocketwatch_status)

	# Player Pocketwatch Pulse
	player_pocketwatch_pulse = TextureRect.new()
	player_pocketwatch_pulse.name = "PlayerPocketwatchPulse"
	player_pocketwatch_pulse.texture = _pocketwatch_texture
	player_pocketwatch_pulse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_pocketwatch_pulse.stretch_mode = TextureRect.STRETCH_SCALE
	player_pocketwatch_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_pocketwatch_pulse.size = Vector2(40, 40)
	player_pocketwatch_pulse.layout_mode = 1
	player_pocketwatch_pulse.anchor_left = 0.0
	player_pocketwatch_pulse.anchor_right = 0.0
	player_pocketwatch_pulse.anchor_top = 0.5
	player_pocketwatch_pulse.anchor_bottom = 0.5
	player_pocketwatch_pulse.offset_left = -264.0
	player_pocketwatch_pulse.offset_top = 122.0
	player_pocketwatch_pulse.offset_right = -224.0
	player_pocketwatch_pulse.offset_bottom = 162.0
	player_pocketwatch_pulse.modulate = Color(EffectKeywordData.get_color("Pocketwatch"))
	player_pocketwatch_pulse.modulate.a = 0.0
	player_pocketwatch_pulse.visible = false
	add_child(player_pocketwatch_pulse)


func set_aegis_status(p_aegis: bool, e_aegis: bool) -> void:
	if not player_aegis_status: player_aegis_status = get_node_or_null("PlayerAegisStatus")
	if not enemy_aegis_status: enemy_aegis_status = get_node_or_null("EnemyAegisStatus")
	if not player_aegis_pulse: player_aegis_pulse = get_node_or_null("PlayerAegisPulse")
	if not enemy_aegis_pulse: enemy_aegis_pulse = get_node_or_null("EnemyAegisPulse")

	if not player_aegis_status:
		return

	var player_was_visible := player_aegis_status.visible
	var enemy_was_visible := enemy_aegis_status.visible

	player_aegis_status.visible = p_aegis
	enemy_aegis_status.visible = e_aegis

	if p_aegis and not player_was_visible:
		_play_status_pulse_once(player_aegis_pulse, Color(EffectKeywordData.get_color("Aegis")))
	if e_aegis and not enemy_was_visible:
		_play_status_pulse_once(enemy_aegis_pulse, Color(EffectKeywordData.get_color("Aegis")))


func set_pocketwatch_status(active: bool) -> void:
	if not player_pocketwatch_status: player_pocketwatch_status = get_node_or_null("PlayerPocketwatchStatus")
	if not player_pocketwatch_pulse: player_pocketwatch_pulse = get_node_or_null("PlayerPocketwatchPulse")

	if not player_pocketwatch_status:
		return

	var was_visible := player_pocketwatch_status.visible
	player_pocketwatch_status.visible = active

	if active and not was_visible:
		_play_status_pulse_once(player_pocketwatch_pulse, Color(EffectKeywordData.get_color("Pocketwatch")))
