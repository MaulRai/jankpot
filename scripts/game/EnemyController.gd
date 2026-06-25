class_name EnemyController
extends Node

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

signal enemy_card_chosen(card: CardDef)
signal enemy_selected(enemy_data: Dictionary)

const NON_BOSS_IDS: Array[String] = [
	"pebble_grunt",
	"paper_moth",
	"tin_cutter",
	"dice_imp",
	"echo_goblin",
	"vengeful_crow",
	"mirror_jester",
	"cowardly_knight",
	"duelist_finch",
	"bruise_toad",
	"gambler_hare",
	"fog_witch",
	"ledger_golem",
	"hatter_mimic",
	"blood_magpie",
]

const BOSS_IDS: Array[String] = [
	"mad_hatter",
	"iron_tortoise",
	"guillotine_duke",
]

const ENEMIES := {
	"pebble_grunt": {
		"name": "Pebble Grunt",
		"description": "Often plays Rock.",
		"rule": "Rock-biased fighter",
		"icon": "res://assets/icon/enemy/pebble-grunt.png",
	},
	"paper_moth": {
		"name": "Paper Moth",
		"description": "Often plays Paper.",
		"rule": "Paper-biased fighter",
		"icon": "res://assets/icon/enemy/paper-moth.png",
	},
	"tin_cutter": {
		"name": "Tin Cutter",
		"description": "Often plays Scissors.",
		"rule": "Scissors-biased fighter",
		"icon": "res://assets/icon/enemy/tin-cutter.png",
	},
	"dice_imp": {
		"name": "Dice Imp",
		"description": "Completely unpredictable.",
		"rule": "No stable pattern",
		"icon": "res://assets/icon/enemy/dice-imp.png",
	},
	"echo_goblin": {
		"name": "Echo Goblin",
		"description": "Repeats winning moves.",
		"rule": "Echoes its successful choices",
		"icon": "res://assets/icon/enemy/echo-goblin.png",
	},
	"vengeful_crow": {
		"name": "Vengeful Crow",
		"description": "Counters your last card.",
		"rule": "Watches your previous move",
		"icon": "res://assets/icon/enemy/vengeful-crow.png",
	},
	"mirror_jester": {
		"name": "Mirror Jester",
		"description": "Copies your last card.",
		"rule": "Mirrors your previous move",
		"icon": "res://assets/icon/enemy/mirror-jester.png",
	},
	"cowardly_knight": {
		"name": "Cowardly Knight",
		"description": "Plays safer when low HP.",
		"rule": "Favors Rock at 3 HP or less",
		"icon": "res://assets/icon/enemy/cowardly-knight.png",
	},
	"duelist_finch": {
		"name": "Duelist Finch",
		"description": "Avoids repeating itself.",
		"rule": "Rarely repeats its last move",
		"icon": "res://assets/icon/enemy/duelist-finch.png",
	},
	"bruise_toad": {
		"name": "Bruise Toad",
		"description": "Gets aggressive after losing.",
		"rule": "Retaliates after a lost clash",
		"icon": "res://assets/icon/enemy/bruise-toad.png",
	},
	"gambler_hare": {
		"name": "Gambler Hare",
		"description": "Takes risky swings.",
		"rule": "Gambles on a type every 3 clashes",
		"icon": "res://assets/icon/enemy/gambler-hare.png",
	},
	"fog_witch": {
		"name": "Fog Witch",
		"description": "Hides its pattern.",
		"rule": "Changes pattern every 3 clashes",
		"icon": "res://assets/icon/enemy/fog-witch.png",
	},
	"ledger_golem": {
		"name": "Ledger Golem",
		"description": "Follows a fixed sequence.",
		"rule": "Cycles Rock, Paper, Scissors",
		"icon": "res://assets/icon/enemy/ledger-golem.png",
	},
	"hatter_mimic": {
		"name": "Hatter Mimic",
		"description": "Often plays Paper.",
		"rule": "Its displayed pattern may be false",
		"icon": "res://assets/icon/enemy/hatter-mimic.png",
	},
	"blood_magpie": {
		"name": "Blood Magpie",
		"description": "Repeats if it damages you.",
		"rule": "Repeats successful attacks",
		"icon": "res://assets/icon/enemy/blood-magpie.png",
	},
	"mad_hatter": {
		"name": "Mad Hatter",
		"description": "Changes rules every 3 clashes.",
		"rule": "Cycles chaos, mirror, counter, and Paper modes",
		"icon": "res://assets/icon/enemy/mad-hatter.png",
		"is_boss": true,
	},
	"iron_tortoise": {
		"name": "Iron Tortoise",
		"description": "Defensive boss that favors Rock.",
		"rule": "Favors Rock more strongly at low HP",
		"icon": "res://assets/icon/enemy/iron-tortoise.png",
		"is_boss": true,
	},
	"guillotine_duke": {
		"name": "Guillotine Duke",
		"description": "Aggressive boss that hunts Paper.",
		"rule": "Scissors bias rises after you play Paper",
		"icon": "res://assets/icon/enemy/guillotine-duke.png",
		"is_boss": true,
	},
}

var enemy_deck: Array[CardDef] = []
var enemy_draw_pile: Array[CardDef] = []
var enemy_hand: Array[CardDef] = []
var enemy_discard_pile: Array[CardDef] = []
@export var assigned_deck: Array[CardDef] = []
@export var starting_hand_indices: Array[int] = []
@export var enemy_hand_size := 3
var current_enemy_id: String = "pebble_grunt"
var current_enemy: Dictionary = {}

var enemy_last_type: CardDef.CardType = CardDef.CardType.ROCK
var player_last_type: CardDef.CardType = CardDef.CardType.ROCK
var has_enemy_last_type := false
var has_player_last_type := false
var last_result: BattleResolver.Result = BattleResolver.Result.DRAW
var has_last_result := false
var clash_count := 0
var _fog_mode := -1
var _gambler_type: CardDef.CardType = CardDef.CardType.ROCK
var _disabled_type: CardDef.CardType = CardDef.CardType.ROCK
var _has_disabled_type := false

func _ready() -> void:
	setup_enemy_deck()

func setup_enemy_deck(upgrade_count: int = 0) -> void:
	enemy_deck.clear()
	enemy_draw_pile.clear()
	enemy_hand.clear()
	enemy_discard_pile.clear()
	if not assigned_deck.is_empty():
		for i in range(assigned_deck.size()):
			var assigned_card := assigned_deck[i]
			if assigned_card:
				var card := assigned_card.copy()
				card.id = "%s_assigned_%d" % [assigned_card.id, i]
				enemy_deck.append(card)
	else:
		_generate_enemy_deck(upgrade_count)

	var battle_cards: Array[CardDef] = []
	for card in enemy_deck:
		var battle_card := card.copy()
		battle_card.temporarily_disabled = false
		battle_cards.append(battle_card)
	_assign_enemy_starting_hand(battle_cards)
	enemy_draw_pile.append_array(battle_cards)
	enemy_draw_pile.shuffle()
	_refill_enemy_hand()

func select_random_non_boss(upgrade_count: int = 0) -> Dictionary:
	return select_enemy(NON_BOSS_IDS.pick_random(), upgrade_count)

func select_enemy(enemy_id: String, upgrade_count: int = 0) -> Dictionary:
	if not ENEMIES.has(enemy_id):
		enemy_id = "pebble_grunt"
	reset_battle_context()
	current_enemy_id = enemy_id
	current_enemy = ENEMIES[current_enemy_id].duplicate(true)
	current_enemy["id"] = current_enemy_id
	current_enemy["reward"] = "Choose 1 Upgrade"
	setup_enemy_deck(upgrade_count)
	enemy_selected.emit(current_enemy)
	return current_enemy

func reset_battle_context() -> void:
	has_enemy_last_type = false
	has_player_last_type = false
	has_last_result = false
	clash_count = 0
	_fog_mode = -1

func choose_card(enemy_hp: int = 6, _player_hp: int = 6) -> CardDef:
	_refill_enemy_hand()
	if enemy_hand.is_empty():
		return null
	var weights: Array[float] = _weights_for_current_enemy(enemy_hp)
	if _has_disabled_type:
		weights[_disabled_type] = 0.0
		_has_disabled_type = false
	_remove_unavailable_type_weights(weights)
	var chosen_type: CardDef.CardType = _choose_weighted_type(weights)
	var matching_cards: Array[CardDef] = []
	for card in enemy_hand:
		if card.card_type == chosen_type:
			matching_cards.append(card)
	var chosen: CardDef = matching_cards.pick_random() if not matching_cards.is_empty() else enemy_hand.pick_random()
	enemy_card_chosen.emit(chosen)
	return chosen

func play_card(card: CardDef) -> void:
	if not card:
		return
	enemy_hand.erase(card)
	if not card.temporarily_disabled:
		enemy_discard_pile.append(card)
	_refill_enemy_hand()

func disable_type_once(type: CardDef.CardType) -> void:
	_disabled_type = type
	_has_disabled_type = true

func has_active_effect(effect_id: String) -> bool:
	for card in enemy_hand:
		if not card.temporarily_disabled and effect_id in card.effects:
			return true
	return false

func temporarily_downgrade(card: CardDef) -> void:
	var replacement := WeaponCatalogData.create_basic(card.card_type, card.id)
	_replace_enemy_runtime_card(card, replacement)

func temporarily_remove(card: CardDef) -> void:
	card.temporarily_disabled = true
	enemy_deck.erase(card)
	enemy_draw_pile.erase(card)
	enemy_hand.erase(card)
	enemy_discard_pile.erase(card)

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

func _weights_for_current_enemy(enemy_hp: int) -> Array[float]:
	match current_enemy_id:
		"pebble_grunt":
			return _make_weights(55.0, 25.0, 20.0)
		"paper_moth":
			return _make_weights(20.0, 55.0, 25.0)
		"tin_cutter":
			return _make_weights(25.0, 20.0, 55.0)
		"dice_imp":
			return _dice_imp_weights()
		"echo_goblin":
			return _echo_goblin_weights()
		"vengeful_crow":
			return _relative_to_player_weights(20.0, 65.0, 15.0)
		"mirror_jester":
			return _relative_to_player_weights(60.0, 20.0, 20.0)
		"cowardly_knight":
			return _make_weights(60.0, 25.0, 15.0) if enemy_hp <= 3 else _balanced_weights()
		"duelist_finch":
			return _avoid_last_weights()
		"bruise_toad":
			return _bruise_toad_weights()
		"gambler_hare":
			return _gambler_hare_weights()
		"fog_witch":
			return _fog_witch_weights()
		"ledger_golem":
			return _ledger_golem_weights()
		"hatter_mimic":
			return _make_weights(40.0, 40.0, 20.0)
		"blood_magpie":
			return _blood_magpie_weights()
		"mad_hatter":
			return _mad_hatter_weights()
		"iron_tortoise":
			return _make_weights(70.0, 20.0, 10.0) if enemy_hp <= 3 else _make_weights(50.0, 30.0, 20.0)
		"guillotine_duke":
			if has_player_last_type and player_last_type == CardDef.CardType.PAPER:
				return _make_weights(15.0, 10.0, 75.0)
			return _make_weights(25.0, 20.0, 55.0)
	return _balanced_weights()

func _dice_imp_weights() -> Array[float]:
	if clash_count > 0 and clash_count % 3 == 0:
		var weights := _balanced_weights()
		weights[randi_range(0, 2)] += 18.0
		return weights
	return _balanced_weights()

func _echo_goblin_weights() -> Array[float]:
	if not has_last_result or not has_enemy_last_type:
		return _balanced_weights()
	if last_result == BattleResolver.Result.LOSE:
		return _weights_with_preference(enemy_last_type, 65.0, 17.5)
	if last_result == BattleResolver.Result.DRAW:
		return _weights_with_preference(enemy_last_type, 45.0, 27.5)
	return _balanced_weights()

func _relative_to_player_weights(same: float, counter: float, losing: float) -> Array[float]:
	if not has_player_last_type:
		return _balanced_weights()
	var weights: Array[float] = _make_weights(0.0, 0.0, 0.0)
	weights[player_last_type] = same
	weights[_counter_of(player_last_type)] = counter
	weights[_loses_to(player_last_type)] = losing
	return weights

func _avoid_last_weights() -> Array[float]:
	if not has_enemy_last_type:
		return _balanced_weights()
	return _weights_with_preference(enemy_last_type, 10.0, 45.0)

func _bruise_toad_weights() -> Array[float]:
	if has_last_result and last_result == BattleResolver.Result.WIN and has_player_last_type:
		return _weights_with_preference(_counter_of(player_last_type), 70.0, 15.0)
	return _make_weights(35.0, 30.0, 35.0)

func _gambler_hare_weights() -> Array[float]:
	var upgraded_types := _available_upgraded_types()

	# Every third clash is a high-risk gamble using the strongest weapon
	# rarity that is actually present in this enemy's current loadout.
	if clash_count > 0 and clash_count % 3 == 0:
		var strongest_types := _highest_rarity_types()
		if not strongest_types.is_empty():
			_gambler_type = strongest_types.pick_random() as CardDef.CardType
			return _weights_with_preference(_gambler_type, 70.0, 15.0)

	# Outside gamble turns, each type with an upgraded weapon receives +25.
	var weights := _balanced_weights()
	for type in upgraded_types:
		weights[type] += 25.0
	return weights

func _available_upgraded_types() -> Array[int]:
	var types: Array[int] = []
	for card in enemy_hand:
		if not card.is_basic and not card.temporarily_disabled and card.card_type not in types:
			types.append(card.card_type)
	return types

func _highest_rarity_types() -> Array[int]:
	var highest_rank := 0
	var types: Array[int] = []
	for card in enemy_hand:
		if card.temporarily_disabled:
			continue
		var rank := _rarity_rank(card.rarity)
		if rank > highest_rank:
			highest_rank = rank
			types.clear()
			types.append(card.card_type)
		elif rank == highest_rank and rank > 0 and card.card_type not in types:
			types.append(card.card_type)
	return types

func _refill_enemy_hand() -> void:
	while enemy_hand.size() < enemy_hand_size:
		if enemy_draw_pile.is_empty():
			if enemy_discard_pile.is_empty():
				break
			enemy_draw_pile.append_array(enemy_discard_pile)
			enemy_discard_pile.clear()
			enemy_draw_pile.shuffle()
		var card: CardDef = enemy_draw_pile.pop_back()
		if not card.temporarily_disabled:
			enemy_hand.append(card)

func _remove_unavailable_type_weights(weights: Array[float]) -> void:
	for type in [CardDef.CardType.ROCK, CardDef.CardType.PAPER, CardDef.CardType.SCISSORS]:
		var available := false
		for card in enemy_hand:
			if card.card_type == type and not card.temporarily_disabled:
				available = true
				break
		if not available:
			weights[type] = 0.0

func _replace_enemy_runtime_card(old_card: CardDef, replacement: CardDef) -> void:
	for pile in [enemy_deck, enemy_draw_pile, enemy_hand, enemy_discard_pile]:
		var index: int = pile.find(old_card)
		if index >= 0:
			pile[index] = replacement

func _generate_enemy_deck(upgrade_count: int) -> void:
	for type in [CardDef.CardType.ROCK, CardDef.CardType.PAPER, CardDef.CardType.SCISSORS]:
		for i in range(3):
			var card := WeaponCatalogData.create_basic(type, "enemy_basic_%d_%d" % [type, i])
			enemy_deck.append(card)

	var upgrade_slots: Array[int] = []
	for i in range(enemy_deck.size()):
		upgrade_slots.append(i)
	upgrade_slots.shuffle()
	for i in range(clampi(upgrade_count, 0, enemy_deck.size())):
		var slot_index := upgrade_slots[i]
		var basic_card := enemy_deck[slot_index]
		var upgrade: CardDef = WeaponCatalogData.random_upgrade_for_type(basic_card.card_type)
		upgrade.id = "enemy_%s_%d" % [upgrade.id, slot_index]
		enemy_deck[slot_index] = upgrade

func _assign_enemy_starting_hand(battle_cards: Array[CardDef]) -> void:
	if starting_hand_indices.is_empty():
		return
	var selected_indices: Array[int] = []
	for index in starting_hand_indices:
		if enemy_hand.size() >= enemy_hand_size:
			break
		if index < 0 or index >= battle_cards.size() or index in selected_indices:
			continue
		selected_indices.append(index)
		enemy_hand.append(battle_cards[index])
	selected_indices.sort()
	selected_indices.reverse()
	for index in selected_indices:
		battle_cards.remove_at(index)

func _rarity_rank(rarity: String) -> int:
	match rarity:
		WeaponCatalogData.RARITY_RARE:
			return 3
		WeaponCatalogData.RARITY_UNCOMMON:
			return 2
		WeaponCatalogData.RARITY_COMMON:
			return 1
	return 0

func _fog_witch_weights() -> Array[float]:
	var mode_block := clash_count / 3
	if mode_block != _fog_mode:
		_fog_mode = mode_block
		_gambler_type = randi_range(0, 2) as CardDef.CardType
	match _gambler_type:
		CardDef.CardType.ROCK:
			return _make_weights(55.0, 25.0, 20.0)
		CardDef.CardType.PAPER:
			return _make_weights(20.0, 55.0, 25.0)
		_:
			return _make_weights(25.0, 20.0, 55.0)

func _ledger_golem_weights() -> Array[float]:
	var expected := (clash_count % 3) as CardDef.CardType
	return _weights_with_preference(expected, 75.0, 12.5)

func _blood_magpie_weights() -> Array[float]:
	if has_last_result and last_result == BattleResolver.Result.LOSE and has_enemy_last_type:
		return _weights_with_preference(enemy_last_type, 70.0, 15.0)
	return _balanced_weights()

func _mad_hatter_weights() -> Array[float]:
	var mode := (clash_count / 3) % 4
	match mode:
		0:
			return _balanced_weights()
		1:
			if not has_player_last_type:
				return _balanced_weights()
			return _weights_with_preference(player_last_type, 60.0, 20.0)
		2:
			if not has_player_last_type:
				return _balanced_weights()
			return _weights_with_preference(_counter_of(player_last_type), 65.0, 17.5)
		_:
			return _make_weights(20.0, 60.0, 20.0)

func _choose_weighted_type(weights: Array[float]) -> CardDef.CardType:
	var total := 0.0
	for weight in weights:
		total += maxf(weight, 0.0)
	var roll := randf() * total
	for i in range(weights.size()):
		roll -= maxf(weights[i], 0.0)
		if roll <= 0.0:
			return i as CardDef.CardType
	return CardDef.CardType.SCISSORS

func _weights_with_preference(
	preferred: CardDef.CardType,
	preferred_weight: float,
	other_weight: float
) -> Array[float]:
	var weights: Array[float] = _make_weights(other_weight, other_weight, other_weight)
	weights[preferred] = preferred_weight
	return weights

func _balanced_weights() -> Array[float]:
	return _make_weights(33.0, 33.0, 33.0)

func _make_weights(rock: float, paper: float, scissors: float) -> Array[float]:
	var weights: Array[float] = [rock, paper, scissors]
	return weights

func _create_enemy_card(type: CardDef.CardType, index: int) -> CardDef:
	var card := CardDef.new()
	card.card_type = type
	match type:
		CardDef.CardType.ROCK:
			card.id = "enemy_rock_%d" % index
			card.card_name = "Rock"
			card.brief_description = "Solid and steady."
			card.art_path = "res://assets/weapon/rock-1.png"
			card.background_color = Color("#7E91A3")
		CardDef.CardType.PAPER:
			card.id = "enemy_paper_%d" % index
			card.card_name = "Paper"
			card.brief_description = "Covers all bases."
			card.art_path = "res://assets/weapon/paper-1.png"
			card.background_color = Color("#E7DFA4")
		CardDef.CardType.SCISSORS:
			card.id = "enemy_scissors_%d" % index
			card.card_name = "Scissors"
			card.brief_description = "Cuts through defenses."
			card.art_path = "res://assets/weapon/scissors-1.png"
			card.background_color = Color("#9A4A4A")
	return card

static func _counter_of(type: CardDef.CardType) -> CardDef.CardType:
	match type:
		CardDef.CardType.ROCK:
			return CardDef.CardType.PAPER
		CardDef.CardType.PAPER:
			return CardDef.CardType.SCISSORS
		_:
			return CardDef.CardType.ROCK

static func _loses_to(type: CardDef.CardType) -> CardDef.CardType:
	match type:
		CardDef.CardType.ROCK:
			return CardDef.CardType.SCISSORS
		CardDef.CardType.PAPER:
			return CardDef.CardType.ROCK
		_:
			return CardDef.CardType.PAPER
