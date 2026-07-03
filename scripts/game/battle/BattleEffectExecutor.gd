class_name BattleEffectExecutor
extends Node

const EffectKeywordData = preload("res://scripts/data/EffectKeyword.gd")

var state: Resource
var animator: Node
var deck_manager: Node
var enemy_controller: Node
var health_display: Control
var player_slot: Control
var enemy_slot: Control
var update_labels: Callable


func configure(dependencies: Dictionary) -> void:
	state = dependencies.state
	animator = dependencies.animator
	deck_manager = dependencies.deck_manager
	enemy_controller = dependencies.enemy_controller
	health_display = dependencies.health_display
	player_slot = dependencies.player_slot
	enemy_slot = dependencies.enemy_slot
	update_labels = dependencies.update_labels


func execute(
	plan: RefCounted,
	result: BattleResolver.Result,
	player_card: CardDef,
	enemy_card: CardDef,
	player_view: CardView,
	enemy_view: CardView
) -> void:
	animator.play_sfx(plan.result_sfx)
	for sfx in plan.immediate_sfx:
		animator.play_sfx(sfx)
		if sfx == "bleed":
			_sync_bleed_status(plan)
		elif sfx == "poison":
			_sync_poison_status(plan)
	if plan.disable_enemy_type >= 0:
		enemy_controller.disable_type_once(plan.disable_enemy_type as CardDef.CardType)
		animator.show_exclamation(player_view, "Concealed!", Color("#AAAAFF"))
	if plan.disable_player_type >= 0:
		state.disabled_player_type = plan.disable_player_type as CardDef.CardType
		state.has_disabled_player_type = true
		animator.show_exclamation(enemy_view, "Concealed!", Color("#AAAAFF"))
	if plan.player_execute:
		animator.show_exclamation(player_view, "Execute!", Color("#FFD166"))
		animator.play_sfx("fatal_hit", -1.0, randf_range(0.96, 1.04))
	if plan.enemy_execute:
		animator.show_exclamation(enemy_view, "Execute!", Color("#FFD166"))
		animator.play_sfx("fatal_hit", -1.0, randf_range(0.96, 1.04))

	if result == BattleResolver.Result.LOSE:
		await _deal_planned_damage(true, plan.damage_to_player, plan.enemy_execute)
		await _deal_planned_damage(false, plan.damage_to_enemy, plan.player_execute)
	else:
		await _deal_planned_damage(false, plan.damage_to_enemy, plan.player_execute)
		if plan.player_double_execute and plan.player_double_execute_damage > 0:
			animator.show_exclamation(player_view, "Again!", Color("#D7A56A"))
			animator.play_sfx("result_win")
			await get_tree().create_timer(0.12).timeout
			await _deal_planned_damage(
				false,
				plan.player_double_execute_damage,
				plan.player_execute
			)
		await _deal_planned_damage(true, plan.damage_to_player, plan.enemy_execute)
	if plan.player_blood_price:
		await _apply_blood_price(player_view, true)
	if plan.enemy_blood_price:
		await _apply_blood_price(enemy_view, false)
	for reaction in plan.ordered_reactions(result):
		var view: CardView = player_view if reaction.side == "player" else enemy_view
		await _reaction(
			view, reaction.text, reaction.color, reaction.sfx, reaction.damage_player
		)
	if plan.old_enemy_bleed:
		animator.play_sfx("bleed")
		health_display.play_bleed_damage_feedback(false, enemy_view)
		await _deal_damage(false, 1)
	if plan.old_player_bleed:
		animator.play_sfx("bleed")
		health_display.play_bleed_damage_feedback(true, player_view)
		await _deal_damage(true, 1)
	if plan.old_enemy_poison > 0 or plan.old_player_poison > 0:
		_sync_poison_status(plan)
	if plan.old_enemy_poison > 0:
		animator.play_sfx("poison")
		animator.show_exclamation(
			enemy_view,
			"Poisoned!",
			Color(EffectKeywordData.get_color("Poison"))
		)
		health_display.play_poison_damage_feedback(false, enemy_view)
		await _deal_damage(false, 1)
	if plan.old_player_poison > 0:
		animator.play_sfx("poison")
		animator.show_exclamation(
			player_view,
			"Poisoned!",
			Color(EffectKeywordData.get_color("Poison"))
		)
		health_display.play_poison_damage_feedback(true, player_view)
		await _deal_damage(true, 1)
	_apply_recovery(plan)
	_apply_card_mutations(plan, player_card, enemy_card)
	update_labels.call()
	if result == BattleResolver.Result.DRAW \
			and plan.damage_to_enemy == 0 and plan.damage_to_player == 0:
		await get_tree().create_timer(0.3).timeout


func _apply_recovery(plan: RefCounted) -> void:
	if plan.player_regen and state.player_hp > 0 and state.player_hp < 6:
		animator.show_exclamation(player_slot.get_card(), "Regen!", Color("#66D98C"))
		state.player_hp += 1
		animator.play_sfx("regen")
	if plan.enemy_regen and state.enemy_hp > 0 and state.enemy_hp < 6:
		animator.show_exclamation(enemy_slot.get_card(), "Regen!", Color("#66D98C"))
		state.enemy_hp += 1
		animator.play_sfx("regen")
	if state.player_hp <= 0 and plan.player_revive:
		animator.show_exclamation(player_slot.get_card(), "Revive!", Color("#FF9DB5"))
		state.player_hp = 1
		animator.play_sfx("revive")
	if state.enemy_hp <= 0 and plan.enemy_revive:
		animator.show_exclamation(enemy_slot.get_card(), "Revive!", Color("#FF9DB5"))
		state.enemy_hp = 1
		animator.play_sfx("revive")


func _sync_bleed_status(plan: RefCounted) -> void:
	if not plan.new_player_bleed and not plan.new_enemy_bleed:
		return
	health_display.set_bleed_status(
		state.player_bleed_pending or plan.old_player_bleed,
		state.enemy_bleed_pending or plan.old_enemy_bleed
	)


func _sync_poison_status(plan: RefCounted) -> void:
	health_display.set_poison_status(
		state.player_poison_turns + plan.old_player_poison,
		state.enemy_poison_turns + plan.old_enemy_poison
	)


func _apply_card_mutations(
	plan: RefCounted,
	player_card: CardDef,
	enemy_card: CardDef
) -> void:
	if plan.player_fragile:
		deck_manager.temporarily_remove(player_card)
	if plan.enemy_fragile:
		enemy_controller.temporarily_remove(enemy_card)
	if plan.player_downgrade:
		deck_manager.temporarily_downgrade(player_card)
	if plan.enemy_downgrade:
		enemy_controller.temporarily_downgrade(enemy_card)


func _reaction(
	card_view: CardView,
	text: String,
	color: Color,
	sfx: String,
	damage_player: bool
) -> void:
	animator.show_exclamation(card_view, text, color)
	animator.play_sfx(sfx)
	await get_tree().create_timer(0.12).timeout
	await _deal_damage(damage_player, 1)


func _deal_planned_damage(to_player: bool, amount: int, burst: bool) -> void:
	if burst:
		await _deal_damage_burst(to_player, amount)
	else:
		await _deal_damage(to_player, amount)


func _apply_blood_price(card_view: CardView, damage_player: bool) -> void:
	animator.show_exclamation(card_view, "Blood Price!", Color("#FF7657"))
	animator.play_sfx("bleed")
	await get_tree().create_timer(0.12).timeout
	await _deal_damage(damage_player, 1)


func _deal_damage(to_player: bool, amount: int) -> void:
	for index in range(amount):
		var blocked := await _block_damage_if_shielded(to_player)
		if blocked:
			continue
		if to_player:
			if state.player_hp <= 0:
				break
			state.player_hp = maxi(0, state.player_hp - 1)
			await health_display.animate_heart_loss(true, state.player_hp)
			await animator.shake(player_slot)
		else:
			if state.enemy_hp <= 0:
				break
			state.enemy_hp = maxi(0, state.enemy_hp - 1)
			await health_display.animate_heart_loss(false, state.enemy_hp)
			await animator.shake(enemy_slot)


func _deal_damage_burst(to_player: bool, amount: int) -> void:
	if amount <= 0:
		return
	var blocked := await _block_damage_if_shielded(to_player)
	if blocked:
		amount -= 1
	if amount <= 0:
		return
	if to_player:
		if state.player_hp <= 0:
			return
		var health_before: int = state.player_hp
		state.player_hp = maxi(0, state.player_hp - amount)
		await health_display.animate_heart_loss_burst(true, health_before, state.player_hp)
		await animator.shake(player_slot)
	else:
		if state.enemy_hp <= 0:
			return
		var health_before: int = state.enemy_hp
		state.enemy_hp = maxi(0, state.enemy_hp - amount)
		await health_display.animate_heart_loss_burst(false, health_before, state.enemy_hp)
		await animator.shake(enemy_slot)


func _block_damage_if_shielded(to_player: bool) -> bool:
	if to_player:
		if state.player_shield <= 0:
			return false
		animator.play_sfx("shield")
		await health_display.play_shield_block_feedback(true, player_slot)
		state.player_shield = maxi(0, state.player_shield - 1)
		update_labels.call()
		await animator.shake(player_slot)
		return true
	if state.enemy_shield <= 0:
		return false
	animator.play_sfx("shield")
	await health_display.play_shield_block_feedback(false, enemy_slot)
	state.enemy_shield = maxi(0, state.enemy_shield - 1)
	update_labels.call()
	await animator.shake(enemy_slot)
	return true
