class_name EnemyDef
extends Resource

@export var id: String
@export var display_name: String
@export_multiline var description: String
@export var rule: String
@export_file("*.png") var icon_path: String
@export var is_boss := false
@export var strategy_id: String


func to_dictionary() -> Dictionary:
	var data := {
		"id": id,
		"name": display_name,
		"description": description,
		"rule": rule,
		"icon": icon_path,
		"reward": "$$$" if is_boss else "$",
	}
	if is_boss:
		data["is_boss"] = true
	return data
