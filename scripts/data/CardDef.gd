class_name CardDef
extends Resource

enum CardType { ROCK, PAPER, SCISSORS }

@export var id: String
@export var card_type: CardType
@export var card_name: String
@export var brief_description: String
@export var art_path: String
@export var background_color: Color
@export var keywords: Array[String]
@export var effects: Array[String]
@export var rarity: String = "Basic"
@export var price: int = 0
@export var is_basic: bool = true
@export var is_skip: bool = false
@export var temporarily_disabled: bool = false

func copy() -> CardDef:
	return duplicate(true) as CardDef
