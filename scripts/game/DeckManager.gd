class_name DeckManager
extends Node

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

signal hand_changed
signal draw_pile_changed
signal discard_pile_changed

@export var assigned_deck: Array[CardDef] = []
@export var starting_hand_indices: Array[int] = []

var draw_pile: Array[CardDef] = []
var hand: Array[CardDef] = []
var discard_pile: Array[CardDef] = []
var deck_blueprint: Array[CardDef] = []

func _ready() -> void:
	if deck_blueprint.is_empty():
		_initialize_blueprint()

func setup_starting_deck() -> void:
	if deck_blueprint.is_empty():
		_initialize_blueprint()
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	var battle_cards: Array[CardDef] = []
	for blueprint_card in deck_blueprint:
		var card := blueprint_card.copy()
		card.temporarily_disabled = false
		battle_cards.append(card)

	_assign_starting_hand(battle_cards)
	draw_pile.append_array(battle_cards)
	shuffle_draw_pile()
	emit_signal("hand_changed")
	emit_signal("draw_pile_changed")
	emit_signal("discard_pile_changed")

func replace_basic_with_upgrade(upgrade: CardDef) -> bool:
	for i in range(deck_blueprint.size()):
		var card := deck_blueprint[i]
		if card.card_type == upgrade.card_type and card.is_basic:
			var replacement := upgrade.copy()
			replacement.id = "%s_player_%d" % [upgrade.id, Time.get_ticks_usec()]
			deck_blueprint[i] = replacement
			return true
	# Once every basic of this type has been replaced, upgrade the oldest
	# matching weapon so the reward loop can continue in long runs.
	for i in range(deck_blueprint.size()):
		if deck_blueprint[i].card_type == upgrade.card_type:
			var replacement := upgrade.copy()
			replacement.id = "%s_player_%d" % [upgrade.id, Time.get_ticks_usec()]
			deck_blueprint[i] = replacement
			return true
	return false

func get_types_with_basic_weapon() -> Array[int]:
	var types: Array[int] = []
	for card in deck_blueprint:
		if card.is_basic and card.card_type not in types:
			types.append(card.card_type)
	return types

func get_all_battle_cards() -> Array[CardDef]:
	var cards: Array[CardDef] = []
	cards.append_array(draw_pile)
	cards.append_array(hand)
	cards.append_array(discard_pile)
	return cards

func has_active_effect(effect_id: String) -> bool:
	for card in hand:
		if not card.temporarily_disabled and effect_id in card.effects:
			return true
	return false

func temporarily_downgrade(card: CardDef) -> void:
	_replace_runtime_card(card, WeaponCatalogData.create_basic(card.card_type, card.id))

func temporarily_remove(card: CardDef) -> void:
	card.temporarily_disabled = true
	draw_pile.erase(card)
	hand.erase(card)
	discard_pile.erase(card)
	emit_signal("hand_changed")
	emit_signal("draw_pile_changed")
	emit_signal("discard_pile_changed")

func shuffle_draw_pile() -> void:
	draw_pile.shuffle()

func draw_until_full(hand_size: int) -> void:
	while hand.size() < hand_size:
		if draw_pile.is_empty():
			reshuffle_discard_if_needed()
			if draw_pile.is_empty():
				break
		var card: CardDef = draw_pile.pop_back()
		if card.temporarily_disabled:
			continue
		hand.append(card)
	emit_signal("hand_changed")
	emit_signal("draw_pile_changed")

func play_card(card_id: String) -> CardDef:
	for i in range(hand.size()):
		if hand[i].id == card_id:
			var card: CardDef = hand.pop_at(i)
			if not card.temporarily_disabled:
				discard_pile.append(card)
			emit_signal("hand_changed")
			emit_signal("discard_pile_changed")
			return card
	return null

func discard_played_card(card: CardDef) -> void:
	if card and not card.temporarily_disabled:
		discard_pile.append(card)
	emit_signal("discard_pile_changed")

func reshuffle_discard_if_needed() -> void:
	if draw_pile.is_empty() and not discard_pile.is_empty():
		draw_pile.append_array(discard_pile)
		discard_pile.clear()
		shuffle_draw_pile()
		emit_signal("draw_pile_changed")
		emit_signal("discard_pile_changed")

func _create_default_blueprint() -> void:
	deck_blueprint.clear()
	for type in [CardDef.CardType.ROCK, CardDef.CardType.PAPER, CardDef.CardType.SCISSORS]:
		for i in range(3):
			deck_blueprint.append(WeaponCatalogData.create_basic(type, "player_%d_%d" % [type, i]))

func _initialize_blueprint() -> void:
	deck_blueprint.clear()
	if not assigned_deck.is_empty():
		for i in range(assigned_deck.size()):
			var card := assigned_deck[i]
			if card:
				var assigned_card := card.copy()
				assigned_card.id = "%s_assigned_%d" % [card.id, i]
				deck_blueprint.append(assigned_card)
	else:
		_create_default_blueprint()

func _assign_starting_hand(battle_cards: Array[CardDef]) -> void:
	if starting_hand_indices.is_empty():
		return
	var selected_indices: Array[int] = []
	for index in starting_hand_indices:
		if hand.size() >= 3:
			break
		if index < 0 or index >= battle_cards.size() or index in selected_indices:
			continue
		selected_indices.append(index)
		hand.append(battle_cards[index])
	selected_indices.sort()
	selected_indices.reverse()
	for index in selected_indices:
		battle_cards.remove_at(index)

func _replace_runtime_card(old_card: CardDef, replacement: CardDef) -> void:
	var piles: Array[Array] = [draw_pile, hand, discard_pile]
	for pile: Array in piles:
		var index: int = pile.find(old_card)
		if index >= 0:
			pile[index] = replacement
			break
	emit_signal("hand_changed")
	emit_signal("draw_pile_changed")
	emit_signal("discard_pile_changed")
