class_name BattleState
extends Resource

@export var player_hp := 6
@export var enemy_hp := 6
@export var turn_count := 0
@export var stage_number := 1
@export var round_status := "ongoing"

var player_bleed_pending := false
var enemy_bleed_pending := false
var player_shield := 0
var enemy_shield := 0
var player_cup_a_joe_pending := false
var disabled_player_type: CardDef.CardType = CardDef.CardType.ROCK
var has_disabled_player_type := false


func reset_for_battle() -> void:
	player_hp = 6
	enemy_hp = 6
	turn_count = 0
	round_status = "ongoing"
	player_bleed_pending = false
	enemy_bleed_pending = false
	player_shield = 0
	enemy_shield = 0
	player_cup_a_joe_pending = false
	has_disabled_player_type = false
