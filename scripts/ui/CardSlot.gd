class_name CardSlot
extends Control

@onready var slot_texture: TextureRect = %SlotTexture
@onready var card_container: Control = %CardContainer

func place_card(card_view: CardView) -> void:
	if card_view.get_parent():
		card_view.get_parent().remove_child(card_view)
	card_container.add_child(card_view)
	card_view.position = Vector2.ZERO
	card_view.rotation_degrees = 0.0
	card_view.scale = Vector2(1.0, 1.0)

func clear_slot() -> void:
	for child in card_container.get_children():
		child.queue_free()
