class_name DeckManager
extends Node

signal hand_changed
signal draw_pile_changed
signal discard_pile_changed

var draw_pile: Array[CardDef] = []
var hand: Array[CardDef] = []
var discard_pile: Array[CardDef] = []

func setup_starting_deck() -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	# 3 Rock
	for i in range(3):
		var rock := CardDef.new()
		rock.id = "rock_%d" % i
		rock.card_type = CardDef.CardType.ROCK
		rock.card_name = "Rock"
		rock.brief_description = "Solid and steady."
		rock.art_path = "res://assets/weapon/rock-1.png"
		rock.background_color = Color("#7E91A3")
		draw_pile.append(rock)
	# 3 Paper
	for i in range(3):
		var paper := CardDef.new()
		paper.id = "paper_%d" % i
		paper.card_type = CardDef.CardType.PAPER
		paper.card_name = "Paper"
		paper.brief_description = "Covers all bases."
		paper.art_path = "res://assets/weapon/paper-1.png"
		paper.background_color = Color("#E7DFA4")
		draw_pile.append(paper)
	# 3 Scissors
	for i in range(3):
		var scissors := CardDef.new()
		scissors.id = "scissors_%d" % i
		scissors.card_type = CardDef.CardType.SCISSORS
		scissors.card_name = "Scissors"
		scissors.brief_description = "Cuts through defenses."
		scissors.art_path = "res://assets/weapon/scissors-1.png"
		scissors.background_color = Color("#9A4A4A")
		draw_pile.append(scissors)
	shuffle_draw_pile()
	emit_signal("draw_pile_changed")

func shuffle_draw_pile() -> void:
	draw_pile.shuffle()

func draw_until_full(hand_size: int) -> void:
	while hand.size() < hand_size:
		if draw_pile.is_empty():
			reshuffle_discard_if_needed()
			if draw_pile.is_empty():
				break
		hand.append(draw_pile.pop_back())
	emit_signal("hand_changed")
	emit_signal("draw_pile_changed")

func play_card(card_id: String) -> CardDef:
	for i in range(hand.size()):
		if hand[i].id == card_id:
			var card: CardDef = hand.pop_at(i)
			discard_pile.append(card)
			emit_signal("hand_changed")
			emit_signal("discard_pile_changed")
			return card
	return null

func discard_played_card(card: CardDef) -> void:
	discard_pile.append(card)
	emit_signal("discard_pile_changed")

func reshuffle_discard_if_needed() -> void:
	if draw_pile.is_empty() and not discard_pile.is_empty():
		draw_pile.append_array(discard_pile)
		discard_pile.clear()
		shuffle_draw_pile()
		emit_signal("draw_pile_changed")
		emit_signal("discard_pile_changed")
