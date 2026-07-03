class_name BattleEffectResolver
extends RefCounted

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")
const BattleEffectPlanData = preload("res://scripts/game/battle/BattleEffectPlan.gd")


func build_plan(
	result: BattleResolver.Result,
	player_card: CardDef,
	enemy_card: CardDef,
	player_hand: Array[CardDef],
	enemy_hand: Array[CardDef],
	state: Resource
) -> RefCounted:
	var plan: RefCounted = BattleEffectPlanData.new()
	plan.result_sfx = _result_sfx(result)
	plan.damage_to_enemy = 1 if result == BattleResolver.Result.WIN else 0
	plan.damage_to_player = 1 if result == BattleResolver.Result.LOSE else 0
	
	plan.old_player_bleed = state.player_bleed_pending
	plan.old_enemy_bleed = state.enemy_bleed_pending
	state.player_bleed_pending = false
	state.enemy_bleed_pending = false

	plan.old_player_poison = state.player_poison_turns
	plan.old_enemy_poison = state.enemy_poison_turns
	if state.player_poison_turns > 0:
		state.player_poison_turns -= 1
		plan.new_player_poison = state.player_poison_turns
	else:
		plan.new_player_poison = 0
		
	if state.enemy_poison_turns > 0:
		state.enemy_poison_turns -= 1
		plan.new_enemy_poison = state.enemy_poison_turns
	else:
		plan.new_enemy_poison = 0

	var player_luck := _luck_bonus(player_hand, player_card)
	var enemy_luck := _luck_bonus(enemy_hand, enemy_card)
	if not player_card.is_skip:
		_apply_player_effects(plan, state, result, player_card, enemy_card, player_luck)
	if not enemy_card.is_skip:
		_apply_enemy_effects(plan, state, result, player_card, enemy_card, enemy_luck)
	if state.player_cup_a_joe_pending:
		if result == BattleResolver.Result.WIN and plan.damage_to_enemy > 0:
			plan.player_double_execute = true
			plan.player_double_execute_damage = plan.damage_to_enemy
		state.player_cup_a_joe_pending = false
	return plan


func _apply_player_effects(
	plan: RefCounted,
	state: Resource,
	result: BattleResolver.Result,
	card: CardDef,
	enemy_card: CardDef,
	luck: float
) -> void:
	plan.player_downgrade = WeaponCatalogData.EFFECT_QUARTZ in card.effects
	plan.player_fragile = WeaponCatalogData.EFFECT_RUBY_REVIVE in card.effects
	if plan.player_downgrade and result == BattleResolver.Result.LOSE:
		plan.damage_to_player = maxi(0, plan.damage_to_player - 1)
		plan.immediate_sfx.append("block")
	if WeaponCatalogData.EFFECT_BRONZE_RAZOR in card.effects \
			and result == BattleResolver.Result.WIN and _chance(0.5, luck):
		plan.player_bonus_attack = true
	if WeaponCatalogData.EFFECT_SCULPTURAL_SHEET in card.effects \
			and result == BattleResolver.Result.DRAW:
		plan.player_papercut = true
	if WeaponCatalogData.EFFECT_SPIKE_BOULDER in card.effects \
			and plan.damage_to_player > 0 and _chance(0.5, luck):
		plan.player_vengeance = true
	if WeaponCatalogData.EFFECT_RUSTY_SHEARS in card.effects \
			and result == BattleResolver.Result.WIN:
		state.enemy_bleed_pending = true
		plan.new_enemy_bleed = true
		plan.immediate_sfx.append("bleed")
	if WeaponCatalogData.EFFECT_MIST_VEIL in card.effects \
			and result == BattleResolver.Result.WIN:
		plan.disable_enemy_type = enemy_card.card_type
		plan.player_conceal = true
		plan.immediate_sfx.append("mist_veil")
	if WeaponCatalogData.EFFECT_GUILLOTINE in card.effects:
		if result == BattleResolver.Result.WIN:
			plan.damage_to_enemy = 3
			plan.player_execute = true
		else:
			plan.player_blood_price = true
	plan.player_regen = WeaponCatalogData.EFFECT_RUBY_REGEN in card.effects \
		and result == BattleResolver.Result.WIN
	plan.player_revive = WeaponCatalogData.EFFECT_RUBY_REVIVE in card.effects


func _apply_enemy_effects(
	plan: RefCounted,
	state: Resource,
	result: BattleResolver.Result,
	player_card: CardDef,
	card: CardDef,
	luck: float
) -> void:
	plan.enemy_downgrade = WeaponCatalogData.EFFECT_QUARTZ in card.effects
	plan.enemy_fragile = WeaponCatalogData.EFFECT_RUBY_REVIVE in card.effects
	if plan.enemy_downgrade and result == BattleResolver.Result.WIN:
		plan.damage_to_enemy = maxi(0, plan.damage_to_enemy - 1)
		plan.immediate_sfx.append("block")
	if WeaponCatalogData.EFFECT_BRONZE_RAZOR in card.effects \
			and result == BattleResolver.Result.LOSE and _chance(0.5, luck):
		plan.enemy_bonus_attack = true
	if WeaponCatalogData.EFFECT_SCULPTURAL_SHEET in card.effects \
			and result == BattleResolver.Result.DRAW:
		plan.enemy_papercut = true
	if WeaponCatalogData.EFFECT_SPIKE_BOULDER in card.effects \
			and plan.damage_to_enemy > 0 and _chance(0.5, luck):
		plan.enemy_vengeance = true
	if WeaponCatalogData.EFFECT_RUSTY_SHEARS in card.effects \
			and result == BattleResolver.Result.LOSE:
		state.player_bleed_pending = true
		plan.new_player_bleed = true
		plan.immediate_sfx.append("bleed")
	if WeaponCatalogData.EFFECT_MIST_VEIL in card.effects \
			and result == BattleResolver.Result.LOSE:
		plan.disable_player_type = player_card.card_type
		plan.enemy_conceal = true
		plan.immediate_sfx.append("mist_veil")
	if WeaponCatalogData.EFFECT_GUILLOTINE in card.effects:
		if result == BattleResolver.Result.LOSE:
			plan.damage_to_player = 3
			plan.enemy_execute = true
		else:
			plan.enemy_blood_price = true
	plan.enemy_regen = WeaponCatalogData.EFFECT_RUBY_REGEN in card.effects \
		and result == BattleResolver.Result.LOSE
	plan.enemy_revive = WeaponCatalogData.EFFECT_RUBY_REVIVE in card.effects


func _luck_bonus(cards: Array[CardDef], excluded_card: CardDef) -> float:
	for card in cards:
		if card != excluded_card and not card.temporarily_disabled \
				and WeaponCatalogData.EFFECT_HATTER_SLIP in card.effects:
			return 0.15
	return 0.0


func _chance(base_chance: float, luck_bonus: float) -> bool:
	return randf() < clampf(base_chance + luck_bonus, 0.0, 1.0)


func _result_sfx(result: BattleResolver.Result) -> String:
	match result:
		BattleResolver.Result.WIN:
			return "result_win"
		BattleResolver.Result.LOSE:
			return "result_lose"
	return "result_draw"
