class_name BattleBoard
extends Control

const MAX_HEALTH := 6
const BLEED_KEYWORD := "Bleed"
const SHIELD_KEYWORD := "Shield"
const CUP_A_JOE_KEYWORD := "Cup-a-Joe"

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

var tooltip_manager: TooltipManager
var _heart_texture: Texture2D = preload("res://assets/ui/heart.png")
var _bleed_texture: Texture2D = preload("res://assets/icon/effect/bleed.png")
var _shield_texture: Texture2D = preload("res://assets/item/shield.png")


func _ready() -> void:
	_build_heart_row(player_hearts)
	_build_heart_row(enemy_hearts)
	set_health(MAX_HEALTH, MAX_HEALTH)
	set_bleed_status(false, false)
	set_shield_status(0, 0)
	set_cup_a_joe_status(false)
	_connect_status_hover(player_bleed_status, BLEED_KEYWORD)
	_connect_status_hover(enemy_bleed_status, BLEED_KEYWORD)
	_connect_status_hover(player_shield_status, SHIELD_KEYWORD)
	_connect_status_hover(enemy_shield_status, SHIELD_KEYWORD)
	_connect_status_hover(player_cup_status, CUP_A_JOE_KEYWORD)


func set_tooltip_manager(manager: TooltipManager) -> void:
	tooltip_manager = manager


func set_health(player_health: int, enemy_health: int) -> void:
	_update_heart_row(player_hearts, player_health)
	_update_heart_row(enemy_hearts, enemy_health)


func set_bleed_status(player_bleeding: bool, enemy_bleeding: bool) -> void:
	var player_was_visible := player_bleed_status.visible
	var enemy_was_visible := enemy_bleed_status.visible
	player_bleed_status.visible = player_bleeding
	enemy_bleed_status.visible = enemy_bleeding
	if player_bleeding and not player_was_visible:
		_play_bleed_pulse_once(player_bleed_pulse)
	if enemy_bleeding and not enemy_was_visible:
		_play_bleed_pulse_once(enemy_bleed_pulse)


func set_shield_status(player_shields: int, enemy_shields: int) -> void:
	var player_was_visible := player_shield_status.visible
	var enemy_was_visible := enemy_shield_status.visible
	player_shield_status.visible = player_shields > 0
	enemy_shield_status.visible = enemy_shields > 0
	if player_shields > 0 and not player_was_visible:
		_play_status_pulse_once(player_shield_pulse, Color(0.56, 0.85, 1.0, 0.52))
	if enemy_shields > 0 and not enemy_was_visible:
		_play_status_pulse_once(enemy_shield_pulse, Color(0.56, 0.85, 1.0, 0.52))


func set_cup_a_joe_status(is_active: bool) -> void:
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


func _update_heart_row(container: HBoxContainer, health: int) -> void:
	var clamped_health := clampi(health, 0, MAX_HEALTH)
	for i in range(container.get_child_count()):
		var heart := container.get_child(i) as TextureRect
		if heart:
			heart.visible = true
			heart.modulate = Color.WHITE if i < clamped_health else Color(0.16, 0.17, 0.2, 0.5)


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
	if not status_icon.visible:
		return
	status_icon.pivot_offset = status_icon.size * 0.5
	status_icon.modulate = Color.WHITE

	var tween := create_tween()
	tween.tween_property(status_icon, "modulate", Color(1.0, 0.62, 0.62, 1.0), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(status_icon, "modulate", Color(1.0, 1.0, 1.0, 0.72), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(status_icon, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(status_icon, "modulate", Color(1.0, 0.92, 0.86, 0.0), 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	status_icon.visible = false
	status_icon.modulate = Color.WHITE


func _play_cup_status_expire(status_icon: TextureRect) -> void:
	if not status_icon.visible:
		return
	status_icon.pivot_offset = status_icon.size * 0.5
	status_icon.modulate = Color.WHITE

	var tween := create_tween()
	tween.tween_property(status_icon, "modulate", Color(1.0, 0.82, 0.48, 1.0), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(status_icon, "modulate", Color(1.0, 1.0, 1.0, 0.72), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(status_icon, "modulate", Color(1.0, 0.7, 0.32, 1.0), 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(status_icon, "modulate", Color(1.0, 0.92, 0.72, 0.0), 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	status_icon.visible = false
	status_icon.modulate = Color.WHITE


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
