class_name EnemyController
extends Node

signal enemy_card_chosen(card: CardDef)

var enemy_deck: Array[CardDef] = []
var pattern: String = "random"
var last_winning_type: CardDef.CardType = CardDef.CardType.ROCK
var has_last_winning_type: bool = false
var player_last_type: CardDef.CardType = CardDef.CardType.ROCK
var has_player_last_type: bool = false

func _ready() -> void:
	setup_enemy_deck()

func setup_enemy_deck() -> void:
	enemy_deck.clear()
	for i in range(3):
		var rock := CardDef.new()
		rock.id = "enemy_rock_%d" % i
		rock.card_type = CardDef.CardType.ROCK
		rock.card_name = "Rock"
		rock.brief_description = "Solid and steady."
		rock.art_path = "res://assets/weapon/rock-1.png"
		rock.background_color = Color("#7E91A3")
		enemy_deck.append(rock)
	for i in range(3):
		var paper := CardDef.new()
		paper.id = "enemy_paper_%d" % i
		paper.card_type = CardDef.CardType.PAPER
		paper.card_name = "Paper"
		paper.brief_description = "Covers all bases."
		paper.art_path = "res://assets/weapon/paper-1.png"
		paper.background_color = Color("#E7DFA4")
		enemy_deck.append(paper)
	for i in range(3):
		var scissors := CardDef.new()
		scissors.id = "enemy_scissors_%d" % i
		scissors.card_type = CardDef.CardType.SCISSORS
		scissors.card_name = "Scissors"
		scissors.brief_description = "Cuts through defenses."
		scissors.art_path = "res://assets/weapon/scissors-1.png"
		scissors.background_color = Color("#9A4A4A")
		enemy_deck.append(scissors)

func choose_card() -> CardDef:
	var chosen: CardDef
	match pattern:
		"random":
			chosen = _choose_random()
		"repeater":
			chosen = _choose_repeater()
		"counter":
			chosen = _choose_counter()
		"biased_rock":
			chosen = _choose_biased(CardDef.CardType.ROCK)
		_:
			chosen = _choose_random()
	emit_signal("enemy_card_chosen", chosen)
	return chosen

func _choose_random() -> CardDef:
	return enemy_deck.pick_random()

func _choose_repeater() -> CardDef:
	if randf() < 0.6 and has_last_winning_type:
		for card in enemy_deck:
			if card.card_type == last_winning_type:
				return card
	return enemy_deck.pick_random()

func _choose_counter() -> CardDef:
	if randf() < 0.6 and has_player_last_type:
		var counter_type := _counter_of(player_last_type)
		for card in enemy_deck:
			if card.card_type == counter_type:
				return card
	return enemy_deck.pick_random()

func _choose_biased(favored: CardDef.CardType) -> CardDef:
	if randf() < 0.5:
		for card in enemy_deck:
			if card.card_type == favored:
				return card
	return enemy_deck.pick_random()

static func _counter_of(t: CardDef.CardType) -> CardDef.CardType:
	match t:
		CardDef.CardType.ROCK: return CardDef.CardType.PAPER
		CardDef.CardType.PAPER: return CardDef.CardType.SCISSORS
		CardDef.CardType.SCISSORS: return CardDef.CardType.ROCK
	return CardDef.CardType.ROCK
