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
# Running tally of every weapon type the player has thrown this battle,
# indexed by CardDef.CardType (0 = Rock, 1 = Paper, 2 = Scissors).
var player_type_history: Array[int] = [0, 0, 0]
# Type counts of the cards the player still holds (hand + draw pile), same
# indexing. Lets analytical rivals reason about what the player *can* throw.
var player_remaining_counts: Array[int] = [0, 0, 0]
