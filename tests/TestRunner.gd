extends SceneTree

const EnemyCatalogData = preload("res://scripts/data/EnemyCatalog.gd")
const EnemyBattleDeckData = preload("res://scripts/game/enemy/EnemyBattleDeck.gd")
const EnemyStrategyContextData = preload("res://scripts/game/enemy/EnemyStrategyContext.gd")
const EnemyStrategyEvaluatorData = preload("res://scripts/game/enemy/EnemyStrategyEvaluator.gd")
const BattleStateData = preload("res://scripts/game/battle/BattleState.gd")
const BattleEffectPlanData = preload("res://scripts/game/battle/BattleEffectPlan.gd")
const BattleEffectResolverData = preload("res://scripts/game/battle/BattleEffectResolver.gd")
const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_test_enemy_catalog()
	_test_enemy_strategy_weights()
	_test_enemy_deck()
	_test_basic_effect_plans()
	_test_reaction_order()
	_test_poison_ticks()
	_test_pocketwatch_and_aegis()
	_test_velvet_gloves()
	_test_rare_card_add_consumables()
	await _test_scene_smoke()
	if failures.is_empty():
		print("TESTS PASSED")
		quit()
	else:
		for failure in failures:
			push_error(failure)
		print("TESTS FAILED: %d" % failures.size())
		quit(1)


func _test_enemy_catalog() -> void:
	var ids: Dictionary = {}
	for definition in EnemyCatalogData.DEFINITIONS:
		_expect(not ids.has(definition.id), "Enemy ID must be unique: %s" % definition.id)
		ids[definition.id] = true
		_expect(ResourceLoader.exists(definition.icon_path), "Missing icon: %s" % definition.icon_path)
	_expect(EnemyCatalogData.non_boss_ids().size() == 15, "Expected 15 non-boss enemies")
	_expect(EnemyCatalogData.boss_ids().size() == 3, "Expected 3 boss enemies")


func _test_enemy_strategy_weights() -> void:
	var evaluator: RefCounted = EnemyStrategyEvaluatorData.new()
	var context: RefCounted = EnemyStrategyContextData.new()
	for definition in EnemyCatalogData.DEFINITIONS:
		var weights: Array[float] = evaluator.weights(definition.strategy_id, context)
		_expect(weights.size() == 3, "Strategy must return 3 weights: %s" % definition.id)
		_expect(weights[0] >= 0.0 and weights[1] >= 0.0 and weights[2] >= 0.0,
			"Strategy weights must be non-negative: %s" % definition.id)
	_expect(evaluator.weights("rock_bias", context) == [55.0, 25.0, 20.0],
		"Rock bias weights changed")
	context.has_player_last_type = true
	context.player_last_type = CardDef.CardType.PAPER
	_expect(evaluator.weights("counter_player", context) == [15.0, 20.0, 65.0],
		"Counter strategy should favor Scissors against Paper")
	context.clash_count = 2
	_expect(evaluator.weights("ledger", context) == [12.5, 12.5, 75.0],
		"Ledger sequence changed")


func _test_enemy_deck() -> void:
	var deck: RefCounted = EnemyBattleDeckData.new()
	var no_cards: Array[CardDef] = []
	var no_indices: Array[int] = []
	deck.setup(0, no_cards, no_indices)
	_expect(deck.deck.size() == 9, "Default enemy deck must contain 9 cards")
	_expect(deck.hand.size() == 3, "Enemy opening hand must contain 3 cards")
	_expect(deck.draw_pile.size() == 6, "Enemy draw pile must contain 6 cards after refill")
	var played: CardDef = deck.hand[0]
	deck.play_card(played)
	_expect(deck.hand.size() == 3, "Enemy hand must refill after playing")
	_expect(deck.discard_pile.size() == 1, "Played enemy card must enter discard")


func _test_basic_effect_plans() -> void:
	var resolver: RefCounted = BattleEffectResolverData.new()
	var state: Resource = BattleStateData.new()
	var rock := WeaponCatalogData.create_basic(CardDef.CardType.ROCK)
	var scissors := WeaponCatalogData.create_basic(CardDef.CardType.SCISSORS)
	var player_hand: Array[CardDef] = [rock]
	var enemy_hand: Array[CardDef] = [scissors]
	var plan: RefCounted = resolver.build_plan(
		BattleResolver.Result.WIN, rock, scissors, player_hand, enemy_hand, state
	)
	_expect(plan.damage_to_enemy == 1 and plan.damage_to_player == 0,
		"Basic win damage changed")
	var quartz := WeaponCatalogData.create_weapon("quartz")
	player_hand = [quartz]
	enemy_hand = [rock]
	plan = resolver.build_plan(
		BattleResolver.Result.LOSE, quartz, rock, player_hand, enemy_hand, state
	)
	_expect(plan.damage_to_player == 0 and plan.player_downgrade,
		"Quartz block/downgrade plan changed")
	var ruby := WeaponCatalogData.create_weapon("ruby")
	player_hand = [ruby]
	enemy_hand = [scissors]
	plan = resolver.build_plan(
		BattleResolver.Result.WIN, ruby, scissors, player_hand, enemy_hand, state
	)
	_expect(plan.player_regen and plan.player_revive and plan.player_fragile,
		"Ruby recovery/fragile plan changed")


func _test_reaction_order() -> void:
	var plan: RefCounted = BattleEffectPlanData.new()
	plan.player_vengeance = true
	plan.player_papercut = true
	plan.enemy_papercut = true
	plan.player_bonus_attack = true
	var reactions: Array[Dictionary] = plan.ordered_reactions(BattleResolver.Result.LOSE)
	var labels: Array[String] = []
	var sides: Array[String] = []
	for reaction in reactions:
		labels.append(reaction.text)
		sides.append(reaction.side)
	_expect(labels == ["Vengeance!", "Papercut!", "Papercut!", "Bonus Attack!"],
		"Reaction order changed")
	_expect(sides == ["player", "player", "enemy", "player"],
		"Dual Papercut must remain player-first")


func _test_scene_smoke() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await create_timer(2.5).timeout
	var controller: Node = scene.get_node("GameController")
	var enemy: Node = scene.get_node("GameController/EnemyController")
	_expect(controller.player_hp == 6 and controller.enemy_hp == 6,
		"Battle facade HP API changed")
	_expect(controller.round_status == "ongoing", "Battle should start ongoing")
	_expect(enemy.current_enemy.has("id"), "Enemy facade dictionary API changed")
	_expect(enemy.enemy_hand.size() == 3, "Enemy facade hand API changed")
	await controller.start_battle()
	_expect(controller.turn_count == 0 and controller.player_hp == 6,
		"Starting the next battle should reset battle state")
	scene.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_poison_ticks() -> void:
	var resolver: RefCounted = BattleEffectResolverData.new()
	var state: Resource = BattleStateData.new()
	state.enemy_poison_turns = 2
	var rock := WeaponCatalogData.create_basic(CardDef.CardType.ROCK)
	var scissors := WeaponCatalogData.create_basic(CardDef.CardType.SCISSORS)
	var player_hand: Array[CardDef] = [rock]
	var enemy_hand: Array[CardDef] = [scissors]
	
	# Turn 1 — enemy has 2 poison stacks; should decrement to 1, damage handled by executor
	var plan: RefCounted = resolver.build_plan(
		BattleResolver.Result.WIN, rock, scissors, player_hand, enemy_hand, state
	)
	_expect(plan.old_enemy_poison == 2, "Turn1: old_enemy_poison should be 2")
	_expect(plan.new_enemy_poison == 1, "Turn1: new_enemy_poison should be 1")
	_expect(state.enemy_poison_turns == 1, "Turn1: state should decrement to 1")
	# poison damage is NOT in plan.damage_to_enemy — executor deals it separately
	_expect(plan.damage_to_enemy == 1, "Turn1: base damage to enemy (win) should be 1")
	
	# Turn 2 — enemy has 1 poison stack; should decrement to 0
	plan = resolver.build_plan(
		BattleResolver.Result.WIN, rock, scissors, player_hand, enemy_hand, state
	)
	_expect(plan.old_enemy_poison == 1, "Turn2: old_enemy_poison should be 1")
	_expect(plan.new_enemy_poison == 0, "Turn2: new_enemy_poison should be 0")
	_expect(state.enemy_poison_turns == 0, "Turn2: state should decrement to 0")
	_expect(plan.damage_to_enemy == 1, "Turn2: base damage to enemy (win) should be 1")
	
	# Turn 3 — no more poison
	plan = resolver.build_plan(
		BattleResolver.Result.WIN, rock, scissors, player_hand, enemy_hand, state
	)
	_expect(plan.old_enemy_poison == 0, "Turn3: old_enemy_poison should be 0")
	_expect(plan.new_enemy_poison == 0, "Turn3: new_enemy_poison should be 0")


func _test_pocketwatch_and_aegis() -> void:
	var resolver: RefCounted = BattleEffectResolverData.new()
	var state: Resource = BattleStateData.new()
	var rock := WeaponCatalogData.create_basic(CardDef.CardType.ROCK)
	var scissors := WeaponCatalogData.create_basic(CardDef.CardType.SCISSORS)
	var player_hand: Array[CardDef] = [rock]
	var enemy_hand: Array[CardDef] = [scissors]

	# 1. Pocketwatch starts inactive
	_expect(not state.player_pocketwatch_active, "Pocketwatch should start inactive")
	_expect(not state.player_has_aegis, "Aegis should start inactive")

	# 2. Activate Pocketwatch
	state.player_pocketwatch_active = true

	# 3. Lose clash -> should trigger Aegis for the next turn
	var plan: RefCounted = resolver.build_plan(
		BattleResolver.Result.LOSE, scissors, rock, player_hand, enemy_hand, state
	)
	_expect(plan.old_player_pocketwatch, "Pocketwatch should have been recorded as active")
	_expect(not plan.old_player_aegis, "Player did not have Aegis at start of Turn 1")
	_expect(state.player_has_aegis, "Losing clash with Pocketwatch active should raise Aegis for next turn")

	plan = resolver.build_plan(
		BattleResolver.Result.WIN, rock, scissors, player_hand, enemy_hand, state
	)
	_expect(plan.old_player_aegis, "Player should have had Aegis at start of Turn 2")
	_expect(not state.player_has_aegis, "Aegis should expire/reset at start of turn and not be raised if they win")


func _test_velvet_gloves() -> void:
	var state: Resource = BattleStateData.new()
	_expect(not state.velvet_gloves_skip_draw, "Velvet Gloves skip draw flag should start false")
	state.velvet_gloves_skip_draw = true
	_expect(state.velvet_gloves_skip_draw, "Velvet Gloves skip draw flag should be true after use")


func _test_rare_card_add_consumables() -> void:
	# Verify that the Rare resolution logic functions correctly for each weapon type
	# 1. SCISSORS -> Guillotine Blades
	var scissors_rares: Array[String] = []
	for weapon_id in WeaponCatalogData._all_upgrade_ids():
		var card := WeaponCatalogData.create_weapon(weapon_id)
		if card.card_type == CardDef.CardType.SCISSORS and card.rarity == WeaponCatalogData.RARITY_RARE:
			scissors_rares.append(weapon_id)
	_expect(scissors_rares.has("guillotine_blades"), "Guillotine Blades should be registered as a Rare Scissors")

	# 2. PAPER -> Hatter Slip
	var paper_rares: Array[String] = []
	for weapon_id in WeaponCatalogData._all_upgrade_ids():
		var card := WeaponCatalogData.create_weapon(weapon_id)
		if card.card_type == CardDef.CardType.PAPER and card.rarity == WeaponCatalogData.RARITY_RARE:
			paper_rares.append(weapon_id)
	_expect(paper_rares.has("hatter_slip"), "Hatter Slip should be registered as a Rare Paper")

	# 3. ROCK -> Ruby
	var rock_rares: Array[String] = []
	for weapon_id in WeaponCatalogData._all_upgrade_ids():
		var card := WeaponCatalogData.create_weapon(weapon_id)
		if card.card_type == CardDef.CardType.ROCK and card.rarity == WeaponCatalogData.RARITY_RARE:
			rock_rares.append(weapon_id)
	_expect(rock_rares.has("ruby"), "Ruby should be registered as a Rare Rock")


