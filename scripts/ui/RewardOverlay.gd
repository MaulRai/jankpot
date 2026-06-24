class_name RewardOverlay
extends Control

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

signal reward_selected(card: CardDef)

@export var card_scene: PackedScene

@onready var choices_container: HBoxContainer = %Choices

func _ready() -> void:
	visible = false

func show_choices(choices: Array[CardDef]) -> void:
	for child in choices_container.get_children():
		child.queue_free()
	for card_data in choices:
		_add_choice(card_data)
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)

func hide_overlay() -> void:
	visible = false

func _add_choice(card_data: CardDef) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(180.0, 300.0)
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	choices_container.add_child(wrapper)

	var rarity_label := Label.new()
	rarity_label.text = "%s  •  $%d" % [card_data.rarity, card_data.price]
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 16)
	rarity_label.modulate = _rarity_color(card_data.rarity)
	wrapper.add_child(rarity_label)

	var card_view: CardView = card_scene.instantiate()
	card_view.set_card_data(card_data)
	card_view.set_interaction_enabled(false)
	wrapper.add_child(card_view)

	var choose_button := Button.new()
	choose_button.text = "Choose"
	choose_button.custom_minimum_size = Vector2(160.0, 38.0)
	choose_button.pressed.connect(_select_reward.bind(card_data))
	wrapper.add_child(choose_button)

func _select_reward(card_data: CardDef) -> void:
	hide_overlay()
	reward_selected.emit(card_data)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		WeaponCatalogData.RARITY_COMMON:
			return Color("#D8D8D8")
		WeaponCatalogData.RARITY_UNCOMMON:
			return Color("#67C587")
		WeaponCatalogData.RARITY_RARE:
			return Color("#C884FF")
	return Color.WHITE
