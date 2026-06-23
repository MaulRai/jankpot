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
