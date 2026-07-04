class_name PlayerStorage
extends RefCounted

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

const SAVE_PATH := "user://player_storage.json"

const CONSUMABLE_MAGIC_BALL := "magic_ball"
const CONSUMABLE_SHIELD := "shield"
const CONSUMABLE_REMEDY_KIT := "remedy_kit"
const CONSUMABLE_CUP_A_JOE := "cup_a_joe"
const CONSUMABLE_SNAKE_OIL := "snake_oil"
const CONSUMABLE_MOONLIGHT := "moonlight"
const CONSUMABLE_POCKETWATCH := "pocketwatch"

static var _loaded := false

static var _money := 0
static var _weapon_ids: Array[String] = []
static var _selected_weapon_indices: Array[int] = []
static var _consumable_counts: Dictionary = {}
static var _selected_consumable_ids: Array[String] = []
static var _saved_run: Dictionary = {}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		_set_default_inventory()
		save()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_set_default_inventory()
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		_set_default_inventory()
		return

	_money = maxi(0, int(data.get("money", 0)))

	_weapon_ids.clear()
	var raw_weapons: Array = data.get("weapons", [])
	for raw_id in raw_weapons:
		_weapon_ids.append(str(raw_id))

	_selected_weapon_indices.clear()
	var raw_selected: Array = data.get("selected_weapon_indices", [])
	for raw_index in raw_selected:
		_selected_weapon_indices.append(int(raw_index))

	_consumable_counts.clear()
	var raw_consumables: Dictionary = data.get("consumables", {})
	for key in raw_consumables.keys():
		_consumable_counts[str(key)] = maxi(0, int(raw_consumables[key]))

	_selected_consumable_ids.clear()
	var raw_selected_consumables: Array = data.get("selected_consumables", [])
	for raw_id in raw_selected_consumables:
		_selected_consumable_ids.append(str(raw_id))

	_saved_run.clear()
	var raw_saved_run = data.get("saved_run", null)
	if typeof(raw_saved_run) == TYPE_DICTIONARY:
		_saved_run = (raw_saved_run as Dictionary).duplicate(true)

	if _weapon_ids.is_empty():
		_set_default_inventory()
	
	# DEBUG: Load each upgrade card to the player's collection
	if OS.is_debug_build():
		for id in WeaponCatalogData._all_upgrade_ids():
			if id not in _weapon_ids:
				_weapon_ids.append(id)
				
	_normalize_selected_weapon_indices()


static func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify({
		"money": _money,
		"weapons": _weapon_ids,
		"selected_weapon_indices": _selected_weapon_indices,
		"consumables": _consumable_counts,
		"selected_consumables": _selected_consumable_ids,
		"saved_run": _saved_run,
	}))


static func weapon_cards() -> Array[CardDef]:
	ensure_loaded()
	var cards: Array[CardDef] = []
	for index in _weapon_ids.size():
		var card := _create_card_from_storage_id(_weapon_ids[index])
		card.id = "%s_storage_%d" % [card.id, index]
		card.set_meta("storage_index", index)
		cards.append(card)
	return cards


static func money() -> int:
	ensure_loaded()
	return _money


static func add_money(amount: int) -> void:
	ensure_loaded()
	_money = maxi(0, _money + amount)
	save()


static func spend_money(amount: int) -> bool:
	ensure_loaded()
	if amount <= 0:
		return true
	if _money < amount:
		return false
	_money -= amount
	save()
	return true


static func selected_weapon_indices() -> Array[int]:
	ensure_loaded()
	return _selected_weapon_indices.duplicate()


static func selected_weapon_count() -> int:
	ensure_loaded()
	return _selected_weapon_indices.size()


static func is_weapon_selected(storage_index: int) -> bool:
	ensure_loaded()
	return storage_index in _selected_weapon_indices


static func toggle_weapon_selected(storage_index: int) -> bool:
	ensure_loaded()
	if storage_index < 0 or storage_index >= _weapon_ids.size():
		return false
	if storage_index in _selected_weapon_indices:
		_selected_weapon_indices.erase(storage_index)
		save()
		return true
	if _selected_weapon_indices.size() >= 9:
		return false
	_selected_weapon_indices.append(storage_index)
	save()
	return true


static func selected_weapon_cards() -> Array[CardDef]:
	ensure_loaded()
	var cards: Array[CardDef] = []
	for index in _selected_weapon_indices:
		if index < 0 or index >= _weapon_ids.size():
			continue
		var card := _create_card_from_storage_id(_weapon_ids[index])
		card.id = "%s_selected_%d" % [card.id, index]
		cards.append(card)
	return cards


static func consumable_counts() -> Dictionary:
	ensure_loaded()
	return _consumable_counts.duplicate()


static func add_weapon(card: CardDef) -> void:
	if not card:
		return
	ensure_loaded()
	_weapon_ids.append(_storage_id_for_card(card))
	save()


static func add_consumable(consumable_id: String, amount := 1) -> void:
	ensure_loaded()
	_consumable_counts[consumable_id] = maxi(0, int(_consumable_counts.get(consumable_id, 0)) + amount)
	if consumable_id not in _selected_consumable_ids and _selected_consumable_ids.size() < 5:
		_selected_consumable_ids.append(consumable_id)
	save()


static func consume_consumable(consumable_id: String, amount := 1) -> int:
	ensure_loaded()
	# A selected consumable can only be used once across the whole run.
	# Remove the entire stack and deselect it so it cannot be restocked.
	_consumable_counts.erase(consumable_id)
	_selected_consumable_ids.erase(consumable_id)
	save()
	return 0


static func selected_consumables() -> Array[String]:
	ensure_loaded()
	var valid: Array[String] = []
	for id in _selected_consumable_ids:
		if int(_consumable_counts.get(id, 0)) > 0:
			valid.append(id)
	return valid


static func is_consumable_selected(consumable_id: String) -> bool:
	ensure_loaded()
	return consumable_id in _selected_consumable_ids


static func toggle_consumable_selected(consumable_id: String) -> bool:
	ensure_loaded()
	if consumable_id in _selected_consumable_ids:
		_selected_consumable_ids.erase(consumable_id)
		save()
		return true
	if _selected_consumable_ids.size() >= 5:
		return false
	_selected_consumable_ids.append(consumable_id)
	save()
	return true


static func has_saved_run() -> bool:
	ensure_loaded()
	return not _saved_run.is_empty()


static func load_saved_run() -> Dictionary:
	ensure_loaded()
	return _saved_run.duplicate(true)


static func save_run(state: Dictionary) -> void:
	ensure_loaded()
	_saved_run = state.duplicate(true)
	save()


static func clear_saved_run() -> void:
	ensure_loaded()
	if _saved_run.is_empty():
		return
	_saved_run.clear()
	save()


static func _set_default_inventory() -> void:
	_money = 0
	_weapon_ids.clear()
	for id in ["basic_rock", "basic_paper", "basic_scissors"]:
		for _i in range(3):
			_weapon_ids.append(id)
	_selected_weapon_indices = _default_selected_weapon_indices()
	_consumable_counts.clear()


static func _normalize_selected_weapon_indices() -> void:
	var normalized: Array[int] = []
	for index in _selected_weapon_indices:
		if index < 0 or index >= _weapon_ids.size() or index in normalized:
			continue
		normalized.append(index)
	_selected_weapon_indices = normalized
	if _selected_weapon_indices.is_empty():
		_selected_weapon_indices = _default_selected_weapon_indices()


static func _default_selected_weapon_indices() -> Array[int]:
	var selected: Array[int] = []
	for index in _weapon_ids.size():
		if selected.size() >= 9:
			break
		if _weapon_ids[index].begins_with("basic_"):
			selected.append(index)
	if selected.size() >= 9:
		return selected
	for index in _weapon_ids.size():
		if selected.size() >= 9:
			break
		if index not in selected:
			selected.append(index)
	return selected


static func _create_card_from_storage_id(storage_id: String) -> CardDef:
	match storage_id:
		"basic_rock":
			return WeaponCatalogData.create_basic(CardDef.CardType.ROCK)
		"basic_paper":
			return WeaponCatalogData.create_basic(CardDef.CardType.PAPER)
		"basic_scissors":
			return WeaponCatalogData.create_basic(CardDef.CardType.SCISSORS)
	return WeaponCatalogData.create_weapon(storage_id)


static func _storage_id_for_card(card: CardDef) -> String:
	if card.is_basic:
		match card.card_type:
			CardDef.CardType.ROCK:
				return "basic_rock"
			CardDef.CardType.PAPER:
				return "basic_paper"
			CardDef.CardType.SCISSORS:
				return "basic_scissors"
	return card.id.split("_storage_")[0]
