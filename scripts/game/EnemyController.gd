class_name EnemyController
extends Node

const EnemyCatalogData = preload("res://scripts/data/EnemyCatalog.gd")
const EnemyBattleDeckData = preload("res://scripts/game/enemy/EnemyBattleDeck.gd")
const EnemyStrategyContextData = preload("res://scripts/game/enemy/EnemyStrategyContext.gd")
const EnemyStrategyEvaluatorData = preload("res://scripts/game/enemy/EnemyStrategyEvaluator.gd")
const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

signal enemy_card_chosen(card: CardDef)
signal enemy_selected(enemy_data: Dictionary)

@export var assigned_deck: Array[CardDef] = []
@export var starting_hand_indices: Array[int] = []
@export var enemy_hand_size := 3

var current_enemy_id := "pebble_grunt"
var current_enemy: Dictionary = {}
var enemy_last_type: CardDef.CardType = CardDef.CardType.ROCK
var player_last_type: CardDef.CardType = CardDef.CardType.ROCK
var has_enemy_last_type := false
var has_player_last_type := false
var last_result: BattleResolver.Result = BattleResolver.Result.DRAW
var has_last_result := false
var clash_count := 0
# Cumulative tally of the player's throws this battle, indexed by CardType.
var player_type_history: Array[int] = [0, 0, 0]
# Snapshot of the type counts still in the player's hand + draw pile, set by
# GameController just before each enemy card selection.
var player_remaining_counts: Array[int] = [0, 0, 0]

var _disabled_type: CardDef.CardType = CardDef.CardType.ROCK
var _has_disabled_type := false
var _deck := EnemyBattleDeckData.new()
var _strategy := EnemyStrategyEvaluatorData.new()

var enemy_deck: Array[CardDef]:
	get:
		return _deck.deck
var enemy_draw_pile: Array[CardDef]:
	get:
		return _deck.draw_pile
var enemy_hand: Array[CardDef]:
	get:
		return _deck.hand
var enemy_discard_pile: Array[CardDef]:
	get:
		return _deck.discard_pile


func _ready() -> void:
	setup_enemy_deck()


func setup_enemy_deck(upgrade_count: int = 0) -> void:
	_deck.hand_size = enemy_hand_size
	var strategy_id := ""
	if current_enemy.has("strategy_id"):
		strategy_id = str(current_enemy["strategy_id"])
	if strategy_id.is_empty():
		var definition: Resource = EnemyCatalogData.get_enemy(current_enemy_id)
		strategy_id = definition.strategy_id
	_deck.setup(
		upgrade_count,
		assigned_deck,
		starting_hand_indices,
		_strategy.deck_type_counts(strategy_id)
	)


func select_random_non_boss(upgrade_count: int = 0) -> Dictionary:
	return select_enemy(EnemyCatalogData.random_non_boss().id, upgrade_count)


func select_enemy(enemy_id: String, upgrade_count: int = 0) -> Dictionary:
	var definition: Resource = EnemyCatalogData.get_enemy(enemy_id)
	reset_battle_context()
	current_enemy_id = definition.id
	current_enemy = definition.to_dictionary()
	current_enemy["strategy_id"] = definition.strategy_id
	setup_enemy_deck(upgrade_count)
	current_enemy["advertised_face"] = _strategy.advertised_face(definition.strategy_id)
	enemy_selected.emit(current_enemy)
	return current_enemy


func reset_battle_context() -> void:
	has_enemy_last_type = false
	has_player_last_type = false
	has_last_result = false
	clash_count = 0
	player_type_history = [0, 0, 0]
	player_remaining_counts = [0, 0, 0]
	_has_disabled_type = false
	_strategy.reset()


func set_player_remaining_counts(counts: Array[int]) -> void:
	player_remaining_counts = counts


func choose_card(enemy_hp: int = 6, _player_hp: int = 6) -> CardDef:
	_deck.refill_hand()
	if enemy_hand.is_empty():
		return null
	var context: RefCounted = _make_strategy_context(enemy_hp)
	var definition: Resource = EnemyCatalogData.get_enemy(current_enemy_id)
	var weights: Array[float] = _strategy.weights(definition.strategy_id, context)
	if _has_disabled_type:
		weights[_disabled_type] = 0.0
		_has_disabled_type = false
	_deck.remove_unavailable_type_weights(weights)
	if _total_weight(weights) <= 0.0:
		var skip := WeaponCatalogData.create_skip("enemy_skip_%d" % Time.get_ticks_usec())
		enemy_card_chosen.emit(skip)
		return skip
	var chosen: CardDef
	var preference := _strategy.card_preference(definition.strategy_id, context)
	if preference != 0:
		# Rarity-driven rivals pick across every usable card, not by weapon type.
		var available: Array[CardDef] = []
		for card in enemy_hand:
			if weights[card.card_type] > 0.0:
				available.append(card)
		chosen = _pick_card_by_rarity_preference(available, preference)
	else:
		var chosen_type: CardDef.CardType = _strategy.choose_type(weights)
		var matching: Array[CardDef] = []
		for card in enemy_hand:
			if card.card_type == chosen_type:
				matching.append(card)
		chosen = matching.pick_random() \
			if not matching.is_empty() else enemy_hand.pick_random()
	if chosen and chosen.id.begins_with("origami"):
		var enemy_choice: CardDef.CardType = CardDef.CardType.ROCK if randf() < 0.5 else CardDef.CardType.SCISSORS
		chosen.set_meta("origami_choice", enemy_choice)
	enemy_card_chosen.emit(chosen)
	return chosen


func play_card(card: CardDef) -> void:
	_deck.play_card(card)


func disable_type_once(type: CardDef.CardType) -> void:
	_disabled_type = type
	_has_disabled_type = true


func has_active_effect(effect_id: String) -> bool:
	return _deck.has_active_effect(effect_id)


func temporarily_downgrade(card: CardDef) -> void:
	_deck.temporarily_downgrade(card)


func temporarily_remove(card: CardDef) -> void:
	_deck.temporarily_remove(card)


func record_clash(
	player_type: CardDef.CardType,
	enemy_type: CardDef.CardType,
	result: BattleResolver.Result
) -> void:
	player_last_type = player_type
	enemy_last_type = enemy_type
	has_player_last_type = true
	has_enemy_last_type = true
	last_result = result
	has_last_result = true
	clash_count += 1
	player_type_history[player_type] += 1


func _make_strategy_context(enemy_hp: int) -> RefCounted:
	var context: RefCounted = EnemyStrategyContextData.new()
	context.enemy_hp = enemy_hp
	context.enemy_last_type = enemy_last_type
	context.player_last_type = player_last_type
	context.has_enemy_last_type = has_enemy_last_type
	context.has_player_last_type = has_player_last_type
	context.last_result = last_result
	context.has_last_result = has_last_result
	context.clash_count = clash_count
	context.hand = enemy_hand
	context.player_type_history = player_type_history
	context.player_remaining_counts = player_remaining_counts
	return context


# Picks a card with a strong-but-not-absolute lean toward (preference > 0) or
# away from (preference < 0) non-basic cards. Falls back to any card when the
# preferred rarity isn't in hand.
func _pick_card_by_rarity_preference(cards: Array[CardDef], preference: int) -> CardDef:
	if cards.is_empty():
		return enemy_hand.pick_random()
	var want_nonbasic := preference > 0
	var preferred: Array[CardDef] = []
	for card in cards:
		if (not card.is_basic) == want_nonbasic:
			preferred.append(card)
	if not preferred.is_empty() and randf() < 0.8:
		return preferred.pick_random()
	return cards.pick_random()


func _total_weight(weights: Array[float]) -> float:
	var total := 0.0
	for weight in weights:
		total += maxf(weight, 0.0)
	return total
