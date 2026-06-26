class_name EnemyStrategyContext
extends RefCounted

var enemy_hp := 6
var enemy_last_type: CardDef.CardType = CardDef.CardType.ROCK
var player_last_type: CardDef.CardType = CardDef.CardType.ROCK
var has_enemy_last_type := false
var has_player_last_type := false
var last_result: BattleResolver.Result = BattleResolver.Result.DRAW
var has_last_result := false
var clash_count := 0
var hand: Array[CardDef] = []
