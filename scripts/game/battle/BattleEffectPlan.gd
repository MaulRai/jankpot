class_name BattleEffectPlan
extends RefCounted

var damage_to_enemy := 0
var damage_to_player := 0
var result_sfx := ""
var immediate_sfx: Array[String] = []

var player_papercut := false
var enemy_papercut := false
var player_vengeance := false
var enemy_vengeance := false
var player_bonus_attack := false
var enemy_bonus_attack := false
var old_player_bleed := false
var old_enemy_bleed := false
var new_player_bleed := false
var new_enemy_bleed := false

var disable_enemy_type := -1
var disable_player_type := -1
var player_conceal := false
var enemy_conceal := false
var player_execute := false
var enemy_execute := false
var player_double_execute := false
var player_blood_price := false
var enemy_blood_price := false
var player_regen := false
var enemy_regen := false
var player_revive := false
var enemy_revive := false
var player_downgrade := false
var enemy_downgrade := false
var player_fragile := false
var enemy_fragile := false


func ordered_reactions(result: BattleResolver.Result) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []
	if result == BattleResolver.Result.LOSE and player_vengeance:
		reactions.append(_reaction("player", "Vengeance!", "#FF7657", "reflect", false))
	elif result == BattleResolver.Result.WIN and enemy_vengeance:
		reactions.append(_reaction("enemy", "Vengeance!", "#FF7657", "reflect", true))
	else:
		if player_vengeance:
			reactions.append(_reaction("player", "Vengeance!", "#FF7657", "reflect", false))
		if enemy_vengeance:
			reactions.append(_reaction("enemy", "Vengeance!", "#FF7657", "reflect", true))
	if player_papercut:
		reactions.append(_reaction("player", "Papercut!", "#F4E7A1", "reflect", false))
	if enemy_papercut:
		reactions.append(_reaction("enemy", "Papercut!", "#F4E7A1", "reflect", true))
	if player_bonus_attack:
		reactions.append(_reaction(
			"player", "Bonus Attack!", "#FFD166", "bonus_attack", false
		))
	if enemy_bonus_attack:
		reactions.append(_reaction(
			"enemy", "Bonus Attack!", "#FFD166", "bonus_attack", true
		))
	return reactions


func _reaction(
	side: String,
	text: String,
	color: String,
	sfx: String,
	damage_player: bool
) -> Dictionary:
	return {
		"side": side,
		"text": text,
		"color": Color(color),
		"sfx": sfx,
		"damage_player": damage_player,
	}
