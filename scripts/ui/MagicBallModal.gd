class_name MagicBallModal
extends Control

@onready var prediction_label: Label = %PredictionLabel
@onready var prediction_icon: TextureRect = %PredictionIcon
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(hide_modal)

func show_prediction(type: CardDef.CardType) -> void:
	prediction_label.text = "Enemy may play %s" % _type_name(type)
	prediction_icon.texture = load(_type_art(type))
	visible = true

func hide_modal() -> void:
	visible = false

func _type_name(type: CardDef.CardType) -> String:
	match type:
		CardDef.CardType.ROCK:
			return "Rock"
		CardDef.CardType.PAPER:
			return "Paper"
		_:
			return "Scissors"

func _type_art(type: CardDef.CardType) -> String:
	match type:
		CardDef.CardType.ROCK:
			return "res://assets/weapon/rock-1.png"
		CardDef.CardType.PAPER:
			return "res://assets/weapon/paper-1.png"
		_:
			return "res://assets/weapon/scissors-1.png"
