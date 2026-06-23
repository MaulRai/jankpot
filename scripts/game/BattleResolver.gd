class_name BattleResolver
extends Node

enum Result { WIN, LOSE, DRAW }

static func resolve(player_type: CardDef.CardType, enemy_type: CardDef.CardType) -> Result:
	if player_type == enemy_type:
		return Result.DRAW
	match player_type:
		CardDef.CardType.ROCK:
			return Result.WIN if enemy_type == CardDef.CardType.SCISSORS else Result.LOSE
		CardDef.CardType.PAPER:
			return Result.WIN if enemy_type == CardDef.CardType.ROCK else Result.LOSE
		CardDef.CardType.SCISSORS:
			return Result.WIN if enemy_type == CardDef.CardType.PAPER else Result.LOSE
	return Result.DRAW
