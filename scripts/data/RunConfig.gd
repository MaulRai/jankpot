class_name RunConfig
extends RefCounted

const EnemyCatalogData = preload("res://scripts/data/EnemyCatalog.gd")

static var selected_stage_id := "wounderland"
static var selected_boss_id := "mad_hatter"
static var encounter_ids: Array[String] = []


static func configure_stage(stage_id: String, boss_id: String) -> void:
	selected_stage_id = stage_id
	selected_boss_id = boss_id

	var non_boss_ids := EnemyCatalogData.non_boss_ids()
	non_boss_ids.shuffle()
	encounter_ids.clear()
	for enemy_id in non_boss_ids:
		if encounter_ids.size() >= 2:
			break
		encounter_ids.append(enemy_id)
	encounter_ids.append(selected_boss_id)


static func ensure_configured() -> void:
	if encounter_ids.is_empty():
		configure_stage(selected_stage_id, selected_boss_id)


static func enemy_id_for_stage(stage_number: int) -> String:
	ensure_configured()
	var index := stage_number - 1
	if index < 0 or index >= encounter_ids.size():
		return ""
	return encounter_ids[index]


static func is_final_stage(stage_number: int) -> bool:
	ensure_configured()
	return stage_number >= encounter_ids.size()
