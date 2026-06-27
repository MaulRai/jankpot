class_name EnemyStrategyEvaluator
extends RefCounted

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

var _fog_mode := -1
var _variable_type: CardDef.CardType = CardDef.CardType.ROCK


func reset() -> void:
	_fog_mode = -1


func weights(strategy_id: String, context: RefCounted) -> Array[float]:
	match strategy_id:
		"rock_bias":
			return _make_weights(55.0, 25.0, 20.0)
		"paper_bias":
			return _make_weights(20.0, 55.0, 25.0)
		"scissors_bias":
			return _make_weights(25.0, 20.0, 55.0)
		"dice_imp":
			return _dice_imp(context)
		"echo":
			return _echo(context)
		"counter_player":
			return _relative_to_player(context, 20.0, 65.0, 15.0)
		"mirror_player":
			return _relative_to_player(context, 60.0, 20.0, 20.0)
		"cowardly":
			return _make_weights(60.0, 25.0, 15.0) \
				if context.enemy_hp <= 3 else _balanced()
		"avoid_last":
			return _avoid_last(context)
		"bruise_toad":
			return _bruise_toad(context)
		"gambler":
			return _gambler(context)
		"fog_witch":
			return _fog_witch(context)
		"ledger":
			return _with_preference(
				(context.clash_count % 3) as CardDef.CardType, 75.0, 12.5
			)
		"blood_magpie":
			return _blood_magpie(context)
		"mad_hatter":
			return _mad_hatter(context)
		"iron_tortoise":
			return _make_weights(70.0, 20.0, 10.0) \
				if context.enemy_hp <= 3 else _make_weights(50.0, 30.0, 20.0)
		"guillotine_duke":
			if context.has_player_last_type \
					and context.player_last_type == CardDef.CardType.PAPER:
				return _make_weights(15.0, 10.0, 75.0)
			return _make_weights(25.0, 20.0, 55.0)
		"hatter_mimic":
			return _make_weights(40.0, 40.0, 20.0)
	return _balanced()


func deck_type_counts(strategy_id: String) -> Array[int]:
	match strategy_id:
		"rock_bias":
			return _counts_with_preference(CardDef.CardType.ROCK)
		"paper_bias":
			return _counts_with_preference(CardDef.CardType.PAPER)
		"scissors_bias":
			return _counts_with_preference(CardDef.CardType.SCISSORS)
		"iron_tortoise":
			return _counts_with_preference(CardDef.CardType.ROCK)
		"guillotine_duke":
			return _counts_with_preference(CardDef.CardType.SCISSORS)
	return _balanced_counts()


func choose_type(weights: Array[float]) -> CardDef.CardType:
	var total := 0.0
	for weight in weights:
		total += maxf(weight, 0.0)
	var roll := randf() * total
	for index in range(weights.size()):
		roll -= maxf(weights[index], 0.0)
		if roll <= 0.0:
			return index as CardDef.CardType
	return CardDef.CardType.SCISSORS


func _dice_imp(context: RefCounted) -> Array[float]:
	var result := _balanced()
	if context.clash_count > 0 and context.clash_count % 3 == 0:
		result[randi_range(0, 2)] += 18.0
	return result


func _echo(context: RefCounted) -> Array[float]:
	if not context.has_last_result or not context.has_enemy_last_type:
		return _balanced()
	if context.last_result == BattleResolver.Result.LOSE:
		return _with_preference(context.enemy_last_type, 65.0, 17.5)
	if context.last_result == BattleResolver.Result.DRAW:
		return _with_preference(context.enemy_last_type, 45.0, 27.5)
	return _balanced()


func _relative_to_player(
	context: RefCounted,
	same: float,
	counter: float,
	losing: float
) -> Array[float]:
	if not context.has_player_last_type:
		return _balanced()
	var result := _make_weights(0.0, 0.0, 0.0)
	result[context.player_last_type] = same
	result[_counter_of(context.player_last_type)] = counter
	result[_loses_to(context.player_last_type)] = losing
	return result


func _avoid_last(context: RefCounted) -> Array[float]:
	if not context.has_enemy_last_type:
		return _balanced()
	return _with_preference(context.enemy_last_type, 10.0, 45.0)


func _bruise_toad(context: RefCounted) -> Array[float]:
	if context.has_last_result and context.last_result == BattleResolver.Result.WIN \
			and context.has_player_last_type:
		return _with_preference(_counter_of(context.player_last_type), 70.0, 15.0)
	return _make_weights(35.0, 30.0, 35.0)


func _gambler(context: RefCounted) -> Array[float]:
	var upgraded := _available_upgraded_types(context.hand)
	if context.clash_count > 0 and context.clash_count % 3 == 0:
		var strongest := _highest_rarity_types(context.hand)
		if not strongest.is_empty():
			_variable_type = strongest.pick_random() as CardDef.CardType
			return _with_preference(_variable_type, 70.0, 15.0)
	var result := _balanced()
	for type in upgraded:
		result[type] += 25.0
	return result


func _fog_witch(context: RefCounted) -> Array[float]:
	var mode_block: int = context.clash_count / 3
	if mode_block != _fog_mode:
		_fog_mode = mode_block
		_variable_type = randi_range(0, 2) as CardDef.CardType
	match _variable_type:
		CardDef.CardType.ROCK:
			return _make_weights(55.0, 25.0, 20.0)
		CardDef.CardType.PAPER:
			return _make_weights(20.0, 55.0, 25.0)
	return _make_weights(25.0, 20.0, 55.0)


func _blood_magpie(context: RefCounted) -> Array[float]:
	if context.has_last_result and context.last_result == BattleResolver.Result.LOSE \
			and context.has_enemy_last_type:
		return _with_preference(context.enemy_last_type, 70.0, 15.0)
	return _balanced()


func _mad_hatter(context: RefCounted) -> Array[float]:
	match (context.clash_count / 3) % 4:
		0:
			return _balanced()
		1:
			if context.has_player_last_type:
				return _with_preference(context.player_last_type, 60.0, 20.0)
		2:
			if context.has_player_last_type:
				return _with_preference(_counter_of(context.player_last_type), 65.0, 17.5)
		_:
			return _make_weights(20.0, 60.0, 20.0)
	return _balanced()


func _available_upgraded_types(cards: Array[CardDef]) -> Array[int]:
	var types: Array[int] = []
	for card in cards:
		if not card.is_basic and not card.temporarily_disabled and card.card_type not in types:
			types.append(card.card_type)
	return types


func _highest_rarity_types(cards: Array[CardDef]) -> Array[int]:
	var highest := 0
	var types: Array[int] = []
	for card in cards:
		if card.temporarily_disabled:
			continue
		var rank := _rarity_rank(card.rarity)
		if rank > highest:
			highest = rank
			types.clear()
			types.append(card.card_type)
		elif rank == highest and rank > 0 and card.card_type not in types:
			types.append(card.card_type)
	return types


func _rarity_rank(rarity: String) -> int:
	match rarity:
		WeaponCatalogData.RARITY_RARE:
			return 3
		WeaponCatalogData.RARITY_UNCOMMON:
			return 2
		WeaponCatalogData.RARITY_COMMON:
			return 1
	return 0


func _with_preference(
	preferred: CardDef.CardType,
	preferred_weight: float,
	other_weight: float
) -> Array[float]:
	var result := _make_weights(other_weight, other_weight, other_weight)
	result[preferred] = preferred_weight
	return result


func _balanced() -> Array[float]:
	return _make_weights(33.0, 33.0, 33.0)


func _make_weights(rock: float, paper: float, scissors: float) -> Array[float]:
	return [rock, paper, scissors]


func _counts_with_preference(preferred: CardDef.CardType) -> Array[int]:
	var counts: Array[int] = [2, 2, 2]
	counts[preferred] = 5
	return counts


func _balanced_counts() -> Array[int]:
	var counts: Array[int] = [3, 3, 3]
	return counts


static func _counter_of(type: CardDef.CardType) -> CardDef.CardType:
	match type:
		CardDef.CardType.ROCK:
			return CardDef.CardType.PAPER
		CardDef.CardType.PAPER:
			return CardDef.CardType.SCISSORS
	return CardDef.CardType.ROCK


static func _loses_to(type: CardDef.CardType) -> CardDef.CardType:
	match type:
		CardDef.CardType.ROCK:
			return CardDef.CardType.SCISSORS
		CardDef.CardType.PAPER:
			return CardDef.CardType.ROCK
	return CardDef.CardType.PAPER
