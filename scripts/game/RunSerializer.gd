class_name RunSerializer
extends RefCounted

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")
const RunConfigData = preload("res://scripts/data/RunConfig.gd")

var controller: Node

func configure(p_controller: Node) -> void:
	controller = p_controller


func get_run_state() -> Dictionary:
	return {
		"stage_number": controller.stage_number,
		"player_hp": controller.player_hp,
		"enemy_hp": controller.enemy_hp,
		"run_money_earned": controller._run_money_earned,
		"selected_stage_id": RunConfigData.selected_stage_id,
		"selected_boss_id": RunConfigData.selected_boss_id,
		"encounter_ids": RunConfigData.encounter_ids,
		"player_history": _serialize_card_history(controller.battle_sidebar._player_history_cards),
		"enemy_history": _serialize_card_history(controller.battle_sidebar._enemy_history_cards),
		"history_turns": controller.battle_sidebar._history_turns,
		"history_turn": controller.battle_sidebar._history_turn,
		"active_consumables": controller.consumable_shelf.get_active_items(),
		"draw_pile": _serialize_card_history(controller.deck_manager.draw_pile),
		"discard_pile": _serialize_card_history(controller.deck_manager.discard_pile),
		"hand_pile": _serialize_card_history(controller.deck_manager.hand),
	}


func restore_run_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	controller.stage_number = maxi(1, int(state.get("stage_number", 1)))
	controller._run_money_earned = maxi(0, int(state.get("run_money_earned", 0)))
	var restored_hp = int(state.get("player_hp", controller.player_hp))
	if restored_hp > 0:
		controller.player_hp = restored_hp
	var restored_enemy_hp = int(state.get("enemy_hp", controller.enemy_hp))
	if restored_enemy_hp > 0:
		controller.enemy_hp = restored_enemy_hp

	if state.has("selected_stage_id"):
		RunConfigData.selected_stage_id = str(state.get("selected_stage_id"))
	if state.has("selected_boss_id"):
		RunConfigData.selected_boss_id = str(state.get("selected_boss_id"))
	if state.has("encounter_ids"):
		var raw_ids = state.get("encounter_ids", [])
		if typeof(raw_ids) == TYPE_ARRAY:
			RunConfigData.encounter_ids.clear()
			for id in raw_ids:
				RunConfigData.encounter_ids.append(str(id))

	if state.has("player_history") and state.has("enemy_history") and state.has("history_turns") and state.has("history_turn"):
		var p_history = _deserialize_card_history(state.get("player_history", []))
		var e_history = _deserialize_card_history(state.get("enemy_history", []))
		var turns: Array[int] = []
		for t in state.get("history_turns", []):
			turns.append(int(t))
		var turn_num = int(state.get("history_turn", 0))
		controller.battle_sidebar.restore_history(p_history, e_history, turns, turn_num)

	if state.has("active_consumables"):
		var items = state.get("active_consumables", [])
		if typeof(items) == TYPE_ARRAY:
			controller.consumable_shelf.restore_shelf(items)

	# Restore decks
	_restore_deck_pile_state(state)


func _get_card_base_id(card: CardDef) -> String:
	if not card:
		return ""
	if card.is_skip:
		return "skip"
	if card.is_basic:
		match card.card_type:
			CardDef.CardType.ROCK: return "basic_rock"
			CardDef.CardType.PAPER: return "basic_paper"
			CardDef.CardType.SCISSORS: return "basic_scissors"
		return ""
	var clean = card.id
	for suffix in ["_storage_", "_selected_", "_assigned_", "_player_"]:
		var parts = clean.split(suffix)
		if parts.size() > 1:
			clean = parts[0]
			break
	return clean


func _restore_deck_pile_state(state: Dictionary) -> void:
	if not (state.has("draw_pile") or state.has("discard_pile") or state.has("hand_pile")):
		return
	var raw_draw = state.get("draw_pile", [])
	var raw_discard = state.get("discard_pile", [])
	var raw_hand = state.get("hand_pile", [])
	if typeof(raw_draw) != TYPE_ARRAY and typeof(raw_discard) != TYPE_ARRAY and typeof(raw_hand) != TYPE_ARRAY:
		return

	var all_cards = controller.deck_manager.get_all_battle_cards()
	var card_pool: Dictionary = {}
	for card in all_cards:
		var key = _get_card_base_id(card)
		if key.is_empty():
			continue
		if key not in card_pool:
			card_pool[key] = []
		card_pool[key].append(card)

	var new_draw: Array[CardDef] = []
	var new_discard: Array[CardDef] = []
	var new_hand: Array[CardDef] = []

	for raw_id in raw_draw:
		var card = _pop_from_pool(card_pool, str(raw_id))
		if card:
			new_draw.append(card)
	for raw_id in raw_discard:
		var card = _pop_from_pool(card_pool, str(raw_id))
		if card:
			new_discard.append(card)
	for raw_id in raw_hand:
		var card = _pop_from_pool(card_pool, str(raw_id))
		if card:
			new_hand.append(card)

	# Leftover cards go into draw pile
	for pool_list in card_pool.values():
		for leftover in pool_list:
			new_draw.append(leftover)

	controller.deck_manager.draw_pile.clear()
	controller.deck_manager.hand.clear()
	controller.deck_manager.discard_pile.clear()
	controller.deck_manager.draw_pile.assign(new_draw)
	controller.deck_manager.hand.assign(new_hand)
	controller.deck_manager.discard_pile.assign(new_discard)
	controller.deck_manager.draw_pile_changed.emit()
	controller.deck_manager.hand_changed.emit()
	controller.deck_manager.discard_pile_changed.emit()


func _pop_from_pool(pool: Dictionary, base_id: String) -> CardDef:
	if base_id in pool and not pool[base_id].is_empty():
		return pool[base_id].pop_back()
	return null


func _serialize_card_history(cards: Array[CardDef]) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		result.append(_get_card_base_id(card))
	return result


func _deserialize_card_history(ids: Array) -> Array[CardDef]:
	var result: Array[CardDef] = []
	for raw_id in ids:
		var id = str(raw_id)
		if id.is_empty():
			result.append(null)
		elif id == "skip":
			result.append(WeaponCatalogData.create_skip())
		elif id == "basic_rock":
			result.append(WeaponCatalogData.create_basic(CardDef.CardType.ROCK))
		elif id == "basic_paper":
			result.append(WeaponCatalogData.create_basic(CardDef.CardType.PAPER))
		elif id == "basic_scissors":
			result.append(WeaponCatalogData.create_basic(CardDef.CardType.SCISSORS))
		else:
			result.append(WeaponCatalogData.create_weapon(id))
	return result
