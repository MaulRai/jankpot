extends Control

const MAIN_MENU_SCENE_PATH := "res://scenes/main/MainMenu.tscn"
const INTRO_DURATION := 0.62
const BOARD_FADE_DURATION := 0.44
const COVER_FADE_DURATION := 0.24
const FLOOR_OFFSET := 260.0
const SIDE_OFFSET := 320.0
const TOP_OFFSET := 230.0

@onready var _transition_cover: ColorRect = $TransitionCover
@onready var _game_controller: GameController = $GameController
@onready var _sidebar: Control = $LeftPanel
@onready var _pause_overlay: PauseOverlay = $PauseOverlay
@onready var _discard_viewer: Control = $DiscardViewer
@onready var _draw_pile: Control = $DrawPileVisual
@onready var _hand: Control = $BottomHand
@onready var _rack: Control = $ConsumableShelf
@onready var _player_slot: Control = $CenterBoard/PlayerSlot
@onready var _enemy_slot: Control = $CenterBoard/EnemySlot
@onready var _vs_label: Control = $CenterBoard/VSLabel

var _defeat_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_controller.battle_ended.connect(_on_battle_ended)
	_sidebar.pause_requested.connect(_pause_game)
	_pause_overlay.resume_requested.connect(_resume_game)
	_pause_overlay.main_menu_requested.connect(_go_to_main_menu)
	_pause_overlay.try_again_requested.connect(_try_again)
	_transition_cover.visible = true
	_transition_cover.modulate.a = 1.0
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _pause_overlay.can_resume():
			_resume_game()
		elif not _pause_overlay.is_open() and not _defeat_active:
			_pause_game()


func _pause_game() -> void:
	if _defeat_active or get_tree().paused or _pause_overlay.is_open():
		return
	get_tree().paused = true
	await _pause_overlay.open_pause()


func _resume_game() -> void:
	if not _pause_overlay.is_open():
		return
	await _pause_overlay.close_pause()
	get_tree().paused = false


func _go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _try_again() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_battle_ended(winner: String) -> void:
	if winner != "Enemy":
		return
	_defeat_active = true
	get_tree().paused = true
	await _pause_overlay.open_defeat()


func _play_intro() -> void:
	var sidebar_final := _sidebar.position
	var discard_final := _discard_viewer.position
	var draw_final := _draw_pile.position
	var hand_final := _hand.position
	var rack_final := _rack.position

	_sidebar.position = sidebar_final + Vector2(-SIDE_OFFSET, 0.0)
	_discard_viewer.position = discard_final + Vector2(0.0, FLOOR_OFFSET)
	_draw_pile.position = draw_final + Vector2(0.0, FLOOR_OFFSET)
	_hand.position = hand_final + Vector2(0.0, FLOOR_OFFSET)
	_rack.position = rack_final + Vector2(0.0, -TOP_OFFSET)

	for control in [_player_slot, _enemy_slot, _vs_label]:
		control.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_transition_cover, "modulate:a", 0.0, COVER_FADE_DURATION) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	_slide_to(tween, _sidebar, sidebar_final, INTRO_DURATION, 0.0)
	_slide_to(tween, _discard_viewer, discard_final, INTRO_DURATION, 0.06)
	_slide_to(tween, _draw_pile, draw_final, INTRO_DURATION, 0.06)
	_slide_to(tween, _hand, hand_final, INTRO_DURATION, 0.06)
	_slide_to(tween, _rack, rack_final, INTRO_DURATION, 0.04)
	for control in [_player_slot, _enemy_slot, _vs_label]:
		tween.tween_property(control, "modulate:a", 1.0, BOARD_FADE_DURATION) \
			.set_delay(0.12) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	tween.finished.connect(_transition_cover.hide)


func _slide_to(
	tween: Tween,
	control: Control,
	target_position: Vector2,
	duration: float,
	delay: float
) -> void:
	tween.tween_property(control, "position", target_position, duration) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
