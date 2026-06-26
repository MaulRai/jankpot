class_name CardSlot
extends Control

@onready var slot_texture: TextureRect = %SlotTexture
@onready var card_container: Control = %CardContainer

var _pulse_tween: Tween

func set_drop_target_active(active: bool) -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	slot_texture.modulate = Color.WHITE
	slot_texture.scale = Vector2.ONE
	slot_texture.pivot_offset = slot_texture.size * 0.5

	if not active:
		return

	slot_texture.modulate = Color(0.58, 0.76, 1.0, 1.0)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(slot_texture, "modulate", Color(0.7, 0.86, 1.0, 0.82), 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.parallel().tween_property(slot_texture, "scale", Vector2(1.018, 1.018), 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(slot_texture, "modulate", Color(0.52, 0.72, 1.0, 1.0), 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.parallel().tween_property(slot_texture, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func place_card(card_view: CardView) -> void:
	if card_view.get_parent():
		card_view.get_parent().remove_child(card_view)
	card_view.top_level = false
	card_container.add_child(card_view)
	card_view.position = Vector2.ZERO
	card_view.rotation_degrees = 0.0
	card_view.scale = Vector2(1.0, 1.0)

func get_card_target_global_position() -> Vector2:
	return card_container.global_position

func get_card() -> CardView:
	if card_container.get_child_count() == 0:
		return null
	return card_container.get_child(0) as CardView

func clear_slot() -> void:
	for child in card_container.get_children():
		child.queue_free()
