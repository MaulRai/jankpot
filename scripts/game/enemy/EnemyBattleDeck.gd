class_name EnemyBattleDeck
extends RefCounted

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

var deck: Array[CardDef] = []
var draw_pile: Array[CardDef] = []
var hand: Array[CardDef] = []
var discard_pile: Array[CardDef] = []
var hand_size := 3


func setup(
	upgrade_count: int,
	assigned_deck: Array[CardDef],
	starting_hand_indices: Array[int],
	type_counts: Array[int] = []
) -> void:
	deck.clear()
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	if assigned_deck.is_empty():
		_generate(upgrade_count, type_counts)
	else:
		for index in range(assigned_deck.size()):
			var source := assigned_deck[index]
			if source:
				var card := source.copy()
				card.id = "%s_assigned_%d" % [source.id, index]
				deck.append(card)

	var battle_cards: Array[CardDef] = []
	for card in deck:
		var battle_card := card.copy()
		battle_card.temporarily_disabled = false
		battle_cards.append(battle_card)
	_assign_starting_hand(battle_cards, starting_hand_indices)
	draw_pile.append_array(battle_cards)
	draw_pile.shuffle()
	refill_hand()


func refill_hand() -> void:
	while hand.size() < hand_size:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			draw_pile.shuffle()
		var card: CardDef = draw_pile.pop_back()
		if not card.temporarily_disabled:
			hand.append(card)


func play_card(card: CardDef) -> void:
	if not card:
		return
	if card.is_skip:
		return
	hand.erase(card)
	if not card.temporarily_disabled:
		discard_pile.append(card)
	refill_hand()


func has_active_effect(effect_id: String) -> bool:
	for card in hand:
		if not card.temporarily_disabled and effect_id in card.effects:
			return true
	return false


func temporarily_downgrade(card: CardDef) -> void:
	var basic := WeaponCatalogData.create_basic(card.card_type, card.id)
	_apply_card_data(card, basic)


func temporarily_remove(card: CardDef) -> void:
	card.temporarily_disabled = true
	deck.erase(card)
	draw_pile.erase(card)
	hand.erase(card)
	discard_pile.erase(card)


func remove_unavailable_type_weights(weights: Array[float]) -> void:
	for type in [CardDef.CardType.ROCK, CardDef.CardType.PAPER, CardDef.CardType.SCISSORS]:
		var available := false
		for card in hand:
			if card.card_type == type and not card.temporarily_disabled:
				available = true
				break
		if not available:
			weights[type] = 0.0


func _generate(upgrade_count: int, type_counts: Array[int]) -> void:
	for type in [CardDef.CardType.ROCK, CardDef.CardType.PAPER, CardDef.CardType.SCISSORS]:
		var count := _count_for_type(type_counts, type)
		for index in range(count):
			deck.append(WeaponCatalogData.create_basic(
				type,
				"enemy_basic_%d_%d" % [type, index]
			))

	var upgrade_slots: Array[int] = []
	for index in range(deck.size()):
		upgrade_slots.append(index)
	upgrade_slots.shuffle()
	for index in range(clampi(upgrade_count, 0, deck.size())):
		var slot := upgrade_slots[index]
		var upgrade := WeaponCatalogData.random_upgrade_for_type(deck[slot].card_type)
		upgrade.id = "enemy_%s_%d" % [upgrade.id, slot]
		deck[slot] = upgrade


func _count_for_type(type_counts: Array[int], type: CardDef.CardType) -> int:
	if type_counts.size() <= type:
		return 3
	return maxi(0, type_counts[type])


func _assign_starting_hand(
	battle_cards: Array[CardDef],
	starting_hand_indices: Array[int]
) -> void:
	var selected: Array[int] = []
	for index in starting_hand_indices:
		if hand.size() >= hand_size:
			break
		if index < 0 or index >= battle_cards.size() or index in selected:
			continue
		selected.append(index)
		hand.append(battle_cards[index])
	selected.sort()
	selected.reverse()
	for index in selected:
		battle_cards.remove_at(index)


func _apply_card_data(target: CardDef, source: CardDef) -> void:
	target.card_type = source.card_type
	target.card_name = source.card_name
	target.brief_description = source.brief_description
	target.art_path = source.art_path
	target.background_color = source.background_color
	target.keywords = source.keywords.duplicate()
	target.effects = source.effects.duplicate()
	target.rarity = source.rarity
	target.price = source.price
	target.is_basic = source.is_basic
