class_name EnemyCatalog
extends RefCounted

const DEFINITIONS: Array = [
	preload("res://resources/enemies/pebble_grunt.tres"),
	preload("res://resources/enemies/paper_moth.tres"),
	preload("res://resources/enemies/tin_cutter.tres"),
	preload("res://resources/enemies/dice_imp.tres"),
	preload("res://resources/enemies/echo_goblin.tres"),
	preload("res://resources/enemies/vengeful_crow.tres"),
	preload("res://resources/enemies/mirror_jester.tres"),
	preload("res://resources/enemies/cowardly_knight.tres"),
	preload("res://resources/enemies/duelist_finch.tres"),
	preload("res://resources/enemies/bruise_toad.tres"),
	preload("res://resources/enemies/gambler_hare.tres"),
	preload("res://resources/enemies/fog_witch.tres"),
	preload("res://resources/enemies/ledger_golem.tres"),
	preload("res://resources/enemies/hatter_mimic.tres"),
	preload("res://resources/enemies/blood_magpie.tres"),
	preload("res://resources/enemies/mad_hatter.tres"),
	preload("res://resources/enemies/iron_tortoise.tres"),
	preload("res://resources/enemies/guillotine_duke.tres"),
]

static var _by_id: Dictionary = {}


static func get_enemy(enemy_id: String) -> Resource:
	_ensure_index()
	return _by_id.get(enemy_id, _by_id["pebble_grunt"]) as Resource


static func random_non_boss() -> Resource:
	var candidates: Array = []
	for definition in DEFINITIONS:
		if not definition.is_boss:
			candidates.append(definition)
	return candidates.pick_random()


static func non_boss_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in DEFINITIONS:
		if not definition.is_boss:
			ids.append(definition.id)
	return ids


static func boss_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in DEFINITIONS:
		if definition.is_boss:
			ids.append(definition.id)
	return ids


static func _ensure_index() -> void:
	if not _by_id.is_empty():
		return
	for definition in DEFINITIONS:
		_by_id[definition.id] = definition
