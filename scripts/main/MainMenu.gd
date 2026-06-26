extends Control

const GAME_SCENE_PATH := "res://scenes/main/Main.tscn"

@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	_play_button.grab_focus()
	_play_button.pressed.connect(_on_play_button_pressed)


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
