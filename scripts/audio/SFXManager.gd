class_name SFXManager
extends Node

const STREAMS := {
	"bleed": preload("res://audio/sfx/bleed.mp3"),
	"block": preload("res://audio/sfx/block.mp3"),
	"bonus_attack": preload("res://audio/sfx/bonus-attack.mp3"),
	"buzzer": preload("res://audio/sfx/buzzer.mp3"),
	"card_leave": preload("res://audio/sfx/card-leave.mp3"),
	"card_pickup": preload("res://audio/sfx/card-pickup.mp3"),
	"card_placed": preload("res://audio/sfx/card-placed.mp3"),
	"card_shuffle": preload("res://audio/sfx/card-shuffle.mp3"),
	"chaching": preload("res://audio/sfx/chaching.mp3"),
	"click": preload("res://audio/sfx/click.mp3"),
	"coins_falling": preload("res://audio/sfx/coins-falling.mp3"),
	"downgrade": preload("res://audio/sfx/downgrade.mp3"),
	"fragile": preload("res://audio/sfx/fragile.mp3"),
	"fatal_hit": preload("res://audio/sfx/fatal-hit.mp3"),
	"hit": preload("res://audio/sfx/hit.mp3"),
	"mist_veil": preload("res://audio/sfx/mist-veil.mp3"),
	"power_up": preload("res://audio/sfx/power-up.mp3"),
	"reflect": preload("res://audio/sfx/reflect.mp3"),
	"regen": preload("res://audio/sfx/regen.mp3"),
	"result_draw": preload("res://audio/sfx/result-draw.mp3"),
	"result_lose": preload("res://audio/sfx/result-lose.mp3"),
	"result_win": preload("res://audio/sfx/result-win.mp3"),
	"revive": preload("res://audio/sfx/revive.mp3"),
	"reward_hover": preload("res://audio/sfx/reward-item-hover.mp3"),
	"reward_selected": preload("res://audio/sfx/reward-item-selected.mp3"),
	"shield": preload("res://audio/sfx/shield.mp3"),
}

@export_range(-40.0, 6.0, 0.5) var volume_db := -4.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sfx_manager")


func play_sfx(
	sfx_name: String,
	volume_offset_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	var audio_stream := STREAMS.get(sfx_name) as AudioStream
	if audio_stream == null:
		push_warning("Unknown SFX: %s" % sfx_name)
		return

	var player := AudioStreamPlayer.new()
	player.stream = audio_stream
	player.volume_db = volume_db + volume_offset_db
	player.pitch_scale = pitch_scale
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
