class_name BattleResolver
extends Node

enum Result { WIN, LOSE, DRAW }

static func resolve_cards(player_card: CardDef, enemy_card: CardDef) -> Result:
	var player_skips := player_card and player_card.is_skip
	var enemy_skips := enemy_card and enemy_card.is_skip
	if player_skips and enemy_skips:
		return Result.DRAW
	if player_skips:
		return Result.LOSE
	if enemy_skips:
		return Result.WIN
	return resolve(player_card.card_type, enemy_card.card_type)

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
