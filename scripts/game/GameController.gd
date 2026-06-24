class_name GameController
extends Node

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

signal turn_resolved
signal battle_ended(winner: String)
signal wind_exit_batch_finished

@onready var deck_manager: DeckManager = $DeckManager
@onready var battle_resolver: BattleResolver = $BattleResolver
@onready var enemy_controller: EnemyController = $EnemyController
@onready var hand_view: HandView = get_node("../BottomHand")
@onready var player_slot: CardSlot = get_node("../CenterBoard/PlayerSlot")
@onready var enemy_slot: CardSlot = get_node("../CenterBoard/EnemySlot")
@onready var battle_sidebar: Control = get_node("../LeftPanel")
@onready var battle_board: Control = get_node("../CenterBoard")
@onready var draw_pile_visual: Control = get_node("../DrawPileVisual")
@onready var pile_card_bottom: TextureRect = get_node("../DrawPileVisual/PileCardBottom")
@onready var pile_card_middle: TextureRect = get_node("../DrawPileVisual/PileCardMiddle")
@onready var pile_card_top: TextureRect = get_node("../DrawPileVisual/PileCardTop")
@onready var pile_count_label: Label = get_node("../DrawPileVisual/CountLabel")
@onready var reward_overlay: Control = get_node("../RewardOverlay")

var player_hp: int = 6
var enemy_hp: int = 6
var turn_count: int = 0
var stage_number: int = 1
var round_status: String = "ongoing"
var _is_animating: bool = false
var _pending_wind_exits: int = 0
var _pending_enemy_card: CardDef
var _enemy_preview_view: CardView
var _player_bleed_pending := false
var _enemy_bleed_pending := false
var _disabled_player_type: CardDef.CardType = CardDef.CardType.ROCK
var _has_disabled_player_type := false

func _ready() -> void:
	if deck_manager:
		deck_manager.hand_changed.connect(_on_hand_changed)
		deck_manager.draw_pile_changed.connect(_update_pile_visuals)
		deck_manager.discard_pile_changed.connect(_update_pile_visuals)
	if hand_view:
		hand_view.card_play_requested.connect(_on_card_play_requested)
		hand_view.card_drag_started.connect(_on_hand_card_drag_started)
		hand_view.card_drag_ended.connect(_on_hand_card_drag_ended)
	reward_overlay.reward_selected.connect(_on_reward_selected)
	if deck_manager:
		_is_animating = true
		var selected_enemy := enemy_controller.select_random_non_boss(0)
		deck_manager.setup_starting_deck()
		_update_pile_visuals()
		await get_tree().process_frame
		battle_sidebar.set_enemy_info(selected_enemy)
		await _refill_hand_animated()
		await _prepare_enemy_card()
		_is_animating = false
	_update_labels()

func _on_hand_changed() -> void:
	if _is_animating:
		return
	if hand_view:
		hand_view.set_cards(deck_manager.hand)

func _update_labels() -> void:
	if battle_sidebar:
		battle_sidebar.set_health(player_hp, enemy_hp)
		battle_sidebar.set_progress(2, 8, turn_count + 1)

func _on_card_play_requested(card_data: CardDef, card_view: CardView) -> void:
	if round_status != "ongoing" or _is_animating:
		_snap_card_back(card_view)
		return
	if _has_disabled_player_type and card_data.card_type == _disabled_player_type:
		_snap_card_back(card_view)
		return
	
	var drop_pos: Vector2 = card_view.global_position + card_view.size / 2
	if not player_slot.get_global_rect().has_point(drop_pos):
		_snap_card_back(card_view)
		return
	
	_play_card(card_data, card_view)

func _on_hand_card_drag_started(_card_view: CardView) -> void:
	if round_status == "ongoing" and not _is_animating:
		player_slot.set_drop_target_active(true)

func _on_hand_card_drag_ended(_card_view: CardView) -> void:
	player_slot.set_drop_target_active(false)

func _snap_card_back(card_view: CardView) -> void:
	_is_animating = true
	card_view.cancel_transform_tween()
	var tween := create_tween()
	tween.tween_property(card_view, "position", card_view.base_position, 0.2).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "rotation_degrees", card_view.base_rotation_degrees, 0.2)
	
	await tween.finished
	
	card_view.reset_transform()
	card_view.z_index = card_view.base_z_index
	_is_animating = false

func _play_card(card_data: CardDef, card_view: CardView) -> void:
	_is_animating = true
	_has_disabled_player_type = false
	card_view.set_interaction_enabled(false)

	# 1. Animate player card from hand to player slot
	var start_global: Vector2 = card_view.global_position
	hand_view.remove_card_view(card_view)
	var main_node: Node = get_parent()
	main_node.add_child(card_view)
	card_view.global_position = start_global
	card_view.z_index = 1000

	var tween := create_tween()
	tween.tween_property(
		card_view,
		"global_position",
		player_slot.get_card_target_global_position(),
		0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "rotation_degrees", 0.0, 0.35)
	tween.parallel().tween_property(card_view, "scale", Vector2(1.0, 1.0), 0.35)

	await tween.finished

	player_slot.clear_slot()
	player_slot.place_card(card_view)
	card_view.z_index = 0

	# 2. Use the enemy card that was already waiting face-down.
	var enemy_card: CardDef = _pending_enemy_card
	var enemy_view: CardView = _enemy_preview_view
	if not enemy_card or not is_instance_valid(enemy_view):
		await _prepare_enemy_card()
		enemy_card = _pending_enemy_card
		enemy_view = _enemy_preview_view

	# 4. Brief pause before reveal
	await get_tree().create_timer(0.2).timeout

	# 5. Flip reveal enemy card
	if enemy_view and enemy_card:
		await _flip_card(enemy_view, enemy_card)

	# 6. Resolve battle
	var result: BattleResolver.Result = battle_resolver.resolve(card_data.card_type, enemy_card.card_type)
	await _apply_result(result, card_data, enemy_card)
	battle_sidebar.add_history(card_data, enemy_card)
	enemy_controller.record_clash(card_data.card_type, enemy_card.card_type, result)

	# 7. Brief pause, then blow both cards off the board.
	await get_tree().create_timer(0.35).timeout
	await _discard_animations(card_view, enemy_view)
	_pending_enemy_card = null
	_enemy_preview_view = null

	# 8. Update discard data only after the cards have visually left the board.
	deck_manager.play_card(card_data.id)

	# 9. Check battle end after the final cards have left the board.
	if player_hp <= 0 or enemy_hp <= 0:
		_end_battle()
		return

	# 10. Draw refill and rebuild hand
	await _refill_hand_animated()
	await _prepare_enemy_card()

	_is_animating = false
	turn_count += 1
	_update_labels()
	emit_signal("turn_resolved")

func _prepare_enemy_card() -> void:
	if round_status != "ongoing" or not hand_view.card_scene:
		return
	if is_instance_valid(_enemy_preview_view):
		return

	_pending_enemy_card = enemy_controller.choose_card(enemy_hp, player_hp)
	_enemy_preview_view = hand_view.card_scene.instantiate()
	_enemy_preview_view.custom_minimum_size = Vector2(160, 240)
	enemy_slot.place_card(_enemy_preview_view)
	_enemy_preview_view.set_interaction_enabled(false)
	_enemy_preview_view.set_face_down(true)
	_enemy_preview_view.z_index = 0
	await _animate_enemy_card_entry(_enemy_preview_view)

func _refill_hand_animated() -> void:
	if deck_manager.draw_pile.is_empty() and not deck_manager.discard_pile.is_empty():
		deck_manager.reshuffle_discard_if_needed()
		await _animate_pile_rebuild()

	var previous_hand_size := deck_manager.hand.size()
	deck_manager.draw_until_full(hand_view.hand_size)
	var final_hand_size := deck_manager.hand.size()
	hand_view.prepare_layout(final_hand_size)

	var last_finished: Signal

	# Existing cards smoothly make room for the incoming cards.
	for card in hand_view.card_views:
		card.set_interaction_enabled(false)
		var rearrange := create_tween()
		rearrange.set_parallel(true)
		rearrange.tween_property(card, "position", card.base_position, 0.38) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		rearrange.tween_property(card, "rotation_degrees", card.base_rotation_degrees, 0.38) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		last_finished = rearrange.finished

	for index in range(previous_hand_size, final_hand_size):
		var stagger := float(index - previous_hand_size) * 0.12
		last_finished = _animate_card_draw_to_hand(
			deck_manager.hand[index],
			index,
			final_hand_size,
			stagger
		)

	if last_finished:
		await last_finished

	for card in hand_view.card_views:
		card.set_interaction_enabled(true)
	hand_view.normalize_card_layers()
	_update_pile_visuals()

func _animate_card_draw_to_hand(
	card_data: CardDef,
	hand_index: int,
	hand_count: int,
	delay: float = 0.0
) -> Signal:
	if not hand_view.card_scene:
		return get_tree().process_frame

	var drawn_card := hand_view.add_card_for_draw(card_data, hand_index, hand_count)
	if not drawn_card:
		return get_tree().process_frame
	drawn_card.set_interaction_enabled(false)
	drawn_card.set_face_down(true)
	var pile_position_in_hand := hand_view.get_global_transform().affine_inverse() \
		* pile_card_top.global_position
	drawn_card.position = pile_position_in_hand
	drawn_card.scale = Vector2(0.5, 0.5)
	drawn_card.rotation_degrees = randf_range(-8.0, 8.0)
	drawn_card.z_index = drawn_card.base_z_index

	var movement := create_tween()
	if delay > 0.0:
		movement.tween_interval(delay)
	movement.tween_property(drawn_card, "position", drawn_card.base_position, 0.58) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	movement.parallel().tween_property(drawn_card, "scale:y", 1.0, 0.58) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	movement.parallel().tween_property(
		drawn_card,
		"rotation_degrees",
		drawn_card.base_rotation_degrees,
		0.58
	) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var flip := create_tween()
	if delay + 0.08 > 0.0:
		flip.tween_interval(delay + 0.08)
	flip.tween_property(drawn_card, "scale:x", 0.06, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip.tween_callback(func() -> void:
		drawn_card.set_face_down(false)
	)
	flip.tween_property(drawn_card, "scale:x", 1.0, 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	return movement.finished

func _animate_pile_rebuild() -> void:
	_set_pile_cards_visible(false)
	var last_tween: Tween
	var spawned_cards: Array[TextureRect] = []
	var target_position := pile_card_top.global_position
	var viewport_width := get_viewport().get_visible_rect().size.x

	for i in range(6):
		var card_back := TextureRect.new()
		card_back.texture = load("res://assets/ui/card-back.png")
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.size = Vector2(160.0, 240.0)
		card_back.scale = Vector2(0.5, 0.5)
		card_back.pivot_offset = card_back.size * 0.5
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_parent().add_child(card_back)
		card_back.global_position = Vector2(
			viewport_width + randf_range(40.0, 180.0),
			target_position.y + randf_range(-90.0, 90.0)
		)
		card_back.rotation_degrees = randf_range(-20.0, 20.0)
		card_back.z_index = 1700 + i
		spawned_cards.append(card_back)

		last_tween = create_tween()
		last_tween.set_parallel(true)
		last_tween.tween_property(
			card_back,
			"global_position",
			target_position + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)),
			0.38
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		last_tween.tween_property(card_back, "rotation_degrees", randf_range(-2.0, 2.0), 0.38) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.055).timeout

	if last_tween:
		await last_tween.finished
	for card_back in spawned_cards:
		card_back.queue_free()
	_set_pile_cards_visible(true)
	_update_pile_visuals()

func _update_pile_visuals() -> void:
	var draw_count := deck_manager.draw_pile.size() if deck_manager else 0
	pile_count_label.text = str(draw_count)
	_set_pile_cards_visible(draw_count > 0)

func _set_pile_cards_visible(is_visible: bool) -> void:
	pile_card_bottom.visible = is_visible
	pile_card_middle.visible = is_visible
	pile_card_top.visible = is_visible

func _animate_enemy_card_entry(card_view: CardView) -> void:
	card_view.position = Vector2(0.0, -70.0)
	card_view.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(card_view, "position", Vector2.ZERO, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func _flip_card(card_view: CardView, revealed_data: CardDef) -> void:
	# Scale X to 0 to hide
	var tween := create_tween()
	tween.tween_property(card_view, "scale:x", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished

	# Reveal content
	card_view.set_face_down(false)
	card_view.set_card_data(revealed_data)

	# Scale X back to 1
	var tween2 := create_tween()
	tween2.tween_property(card_view, "scale:x", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	await tween2.finished

func _apply_result(
	result: BattleResolver.Result,
	player_card: CardDef,
	enemy_card: CardDef
) -> void:
	var damage_to_enemy := 1 if result == BattleResolver.Result.WIN else 0
	var damage_to_player := 1 if result == BattleResolver.Result.LOSE else 0
	var old_player_bleed := _player_bleed_pending
	var old_enemy_bleed := _enemy_bleed_pending
	_player_bleed_pending = false
	_enemy_bleed_pending = false

	var player_luck := _luck_bonus(deck_manager.hand, player_card)
	var enemy_luck := _luck_bonus(enemy_controller.enemy_deck, enemy_card)

	# Player weapon effects.
	if WeaponCatalogData.EFFECT_QUARTZ in player_card.effects and result == BattleResolver.Result.LOSE:
		damage_to_player = maxi(0, damage_to_player - 1)
		deck_manager.temporarily_downgrade(player_card)
	if WeaponCatalogData.EFFECT_BRONZE_RAZOR in player_card.effects \
			and result == BattleResolver.Result.WIN and _chance(0.5, player_luck):
		damage_to_enemy += 1
	if WeaponCatalogData.EFFECT_SCULPTURAL_SHEET in player_card.effects \
			and result == BattleResolver.Result.DRAW:
		damage_to_enemy += 1
	if WeaponCatalogData.EFFECT_SPIKE_BOULDER in player_card.effects \
			and damage_to_player > 0 and _chance(0.5, player_luck):
		damage_to_enemy += 1
	if WeaponCatalogData.EFFECT_RUSTY_SHEARS in player_card.effects \
			and result == BattleResolver.Result.WIN:
		_enemy_bleed_pending = true
	if WeaponCatalogData.EFFECT_MIST_VEIL in player_card.effects \
			and result == BattleResolver.Result.WIN:
		enemy_controller.disable_type_once(enemy_card.card_type)
	if WeaponCatalogData.EFFECT_GUILLOTINE in player_card.effects:
		if result == BattleResolver.Result.WIN:
			damage_to_enemy = 3
		else:
			damage_to_player += 1

	# Enemy weapon effects use the mirrored result.
	if WeaponCatalogData.EFFECT_QUARTZ in enemy_card.effects and result == BattleResolver.Result.WIN:
		damage_to_enemy = maxi(0, damage_to_enemy - 1)
		enemy_controller.temporarily_downgrade(enemy_card)
	if WeaponCatalogData.EFFECT_BRONZE_RAZOR in enemy_card.effects \
			and result == BattleResolver.Result.LOSE and _chance(0.5, enemy_luck):
		damage_to_player += 1
	if WeaponCatalogData.EFFECT_SCULPTURAL_SHEET in enemy_card.effects \
			and result == BattleResolver.Result.DRAW:
		damage_to_player += 1
	if WeaponCatalogData.EFFECT_SPIKE_BOULDER in enemy_card.effects \
			and damage_to_enemy > 0 and _chance(0.5, enemy_luck):
		damage_to_player += 1
	if WeaponCatalogData.EFFECT_RUSTY_SHEARS in enemy_card.effects \
			and result == BattleResolver.Result.LOSE:
		_player_bleed_pending = true
	if WeaponCatalogData.EFFECT_MIST_VEIL in enemy_card.effects \
			and result == BattleResolver.Result.LOSE:
		_disabled_player_type = player_card.card_type
		_has_disabled_player_type = true
	if WeaponCatalogData.EFFECT_GUILLOTINE in enemy_card.effects:
		if result == BattleResolver.Result.LOSE:
			damage_to_player = 3
		else:
			damage_to_enemy += 1

	await _deal_damage(false, damage_to_enemy)
	await _deal_damage(true, damage_to_player)

	# Bleed created on the previous clash resolves at the end of this clash.
	if old_enemy_bleed:
		await _deal_damage(false, 1)
	if old_player_bleed:
		await _deal_damage(true, 1)

	if WeaponCatalogData.EFFECT_RUBY_REGEN in player_card.effects \
			and result == BattleResolver.Result.WIN and player_hp > 0:
		player_hp = mini(6, player_hp + 1)
	if WeaponCatalogData.EFFECT_RUBY_REGEN in enemy_card.effects \
			and result == BattleResolver.Result.LOSE and enemy_hp > 0:
		enemy_hp = mini(6, enemy_hp + 1)

	if player_hp <= 0 and WeaponCatalogData.EFFECT_RUBY_REVIVE in player_card.effects:
		player_hp = 1
		deck_manager.temporarily_remove(player_card)
	if enemy_hp <= 0 and WeaponCatalogData.EFFECT_RUBY_REVIVE in enemy_card.effects:
		enemy_hp = 1
		enemy_controller.temporarily_remove(enemy_card)

	_update_labels()
	if result == BattleResolver.Result.DRAW and damage_to_enemy == 0 and damage_to_player == 0:
		await get_tree().create_timer(0.3).timeout

func _deal_damage(to_player: bool, amount: int) -> void:
	for i in range(amount):
		if to_player:
			if player_hp <= 0:
				break
			player_hp = maxi(0, player_hp - 1)
			await battle_sidebar.animate_heart_loss(true, player_hp)
			await _shake_node(player_slot)
		else:
			if enemy_hp <= 0:
				break
			enemy_hp = maxi(0, enemy_hp - 1)
			await battle_sidebar.animate_heart_loss(false, enemy_hp)
			await _shake_node(enemy_slot)

func _luck_bonus(cards: Array[CardDef], excluded_card: CardDef) -> float:
	for card in cards:
		if card != excluded_card and not card.temporarily_disabled \
				and WeaponCatalogData.EFFECT_HATTER_SLIP in card.effects:
			return 0.15
	return 0.0

func _chance(base_chance: float, luck_bonus: float) -> bool:
	return randf() < clampf(base_chance + luck_bonus, 0.0, 1.0)

func _shake_node(node: Control) -> void:
	var original_pos := Vector2(node.position)
	var tween := create_tween()
	for i in range(6):
		var offset := Vector2(randf_range(-6, 6), randf_range(-4, 4))
		tween.tween_property(node, "position", original_pos + offset, 0.04)
	tween.tween_property(node, "position", original_pos, 0.04)
	await tween.finished

func _discard_animations(player_card: CardView, enemy_card: CardView) -> void:
	_pending_wind_exits = 0

	if is_instance_valid(player_card):
		_pending_wind_exits += 1
		animate_card_wind_exit(player_card, Vector2(-1.0, 0.22)).connect(
			_on_card_wind_exit_finished,
			CONNECT_ONE_SHOT
		)
	if is_instance_valid(enemy_card):
		_pending_wind_exits += 1
		animate_card_wind_exit(enemy_card, Vector2(1.0, -0.22)).connect(
			_on_card_wind_exit_finished,
			CONNECT_ONE_SHOT
		)

	if _pending_wind_exits > 0:
		await wind_exit_batch_finished

	player_slot.clear_slot()
	enemy_slot.clear_slot()

func _on_card_wind_exit_finished() -> void:
	_pending_wind_exits -= 1
	if _pending_wind_exits <= 0:
		wind_exit_batch_finished.emit()

func animate_card_wind_exit(card_view: Control, direction: Vector2) -> Signal:
	var duration := randf_range(0.7, 0.85)
	var viewport_size := get_viewport().get_visible_rect().size
	var travel_distance := viewport_size.x + card_view.size.x * 1.5
	var natural_direction := direction.normalized()
	natural_direction.y += randf_range(-0.08, 0.08)
	var target_position := card_view.global_position + natural_direction * travel_distance
	target_position.y += randf_range(-35.0, 35.0)

	card_view.pivot_offset = card_view.size * 0.5
	card_view.z_index = 1500
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rotation_amount := deg_to_rad(randf_range(18.0, 32.0))
	if direction.x < 0.0:
		rotation_amount *= -1.0

	var movement_tween := create_tween()
	movement_tween.set_parallel(true)
	movement_tween.tween_property(card_view, "global_position", target_position, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	movement_tween.tween_property(
		card_view,
		"rotation",
		card_view.rotation + rotation_amount,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var flip_tween := create_tween()
	flip_tween.tween_property(card_view, "scale:x", 0.78, duration * 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flip_tween.tween_property(card_view, "scale:x", 1.0, duration * 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flip_tween.tween_property(card_view, "scale", Vector2(0.93, 0.93), duration * 0.48) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return movement_tween.finished

func _end_battle() -> void:
	round_status = "ended"
	var winner := "Draw"
	if player_hp <= 0 and enemy_hp <= 0:
		winner = "Draw"
	elif player_hp <= 0:
		winner = "Enemy"
	elif enemy_hp <= 0:
		winner = "Player"
	emit_signal("battle_ended", winner)
	if winner == "Player":
		var available_types := deck_manager.get_types_with_basic_weapon()
		reward_overlay.show_choices(WeaponCatalogData.generate_reward_choices(3, available_types))
	else:
		_is_animating = false

func _on_reward_selected(card: CardDef) -> void:
	deck_manager.replace_basic_with_upgrade(card)
	stage_number += 1
	await start_battle()

func start_battle() -> void:
	player_hp = 6
	enemy_hp = 6
	turn_count = 0
	round_status = "ongoing"
	_is_animating = true
	_pending_enemy_card = null
	_enemy_preview_view = null
	_player_bleed_pending = false
	_enemy_bleed_pending = false
	_has_disabled_player_type = false
	player_slot.set_drop_target_active(false)
	player_slot.clear_slot()
	enemy_slot.clear_slot()
	battle_sidebar.clear_history()
	# hand_changed is ignored while animating, so remove the previous battle's
	# surviving card views explicitly before drawing the new opening hand.
	hand_view.set_cards([])
	if deck_manager:
		var enemy_upgrade_count := clampi(stage_number - 1, 0, 9)
		battle_sidebar.set_enemy_info(
			enemy_controller.select_random_non_boss(enemy_upgrade_count)
		)
		deck_manager.setup_starting_deck()
		await _refill_hand_animated()
		await _prepare_enemy_card()
	_is_animating = false
	_update_labels()
