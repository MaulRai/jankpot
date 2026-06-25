extends AudioStreamPlayer

const MAX_BGM_VOLUME_DB := -6.0206

@export_range(0.0, 10.0, 0.1) var fade_in_duration := 2.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		stream.loop = true

	if not finished.is_connected(_restart_if_needed):
		finished.connect(_restart_if_needed)

	await get_tree().process_frame
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	volume_db = -12.0
	play()

	var fade_tween := create_tween()
	fade_tween.tween_property(
		self,
		"volume_db",
		MAX_BGM_VOLUME_DB,
		fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _restart_if_needed() -> void:
	call_deferred("play")
