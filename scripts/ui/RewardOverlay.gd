class_name RewardOverlay
extends Control

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")

signal reward_selected(card: CardDef)

@export var card_scene: PackedScene

@onready var choices_container: HBoxContainer = %Choices
@onready var highlight_title: Label = %HighlightTitle
@onready var highlight_description: RichTextLabel = %HighlightDescription

func _ready() -> void:
	visible = false

func show_choices(choices: Array[CardDef]) -> void:
	for child in choices_container.get_children():
		child.queue_free()
	for card_data in choices:
		_add_choice(card_data)
	if not choices.is_empty():
		_show_highlight(choices[0])
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
	card_view.set_drag_enabled(false)
	card_view.card_clicked.connect(_select_reward.bind(card_data))
	card_view.card_hovered.connect(_on_card_hovered.bind(card_data))
	wrapper.add_child(card_view)

func _select_reward(_card_view: CardView, card_data: CardDef) -> void:
	hide_overlay()
	reward_selected.emit(card_data)

func _on_card_hovered(_card_view: CardView, card_data: CardDef) -> void:
	_show_highlight(card_data)

func _show_highlight(card_data: CardDef) -> void:
	highlight_title.text = "%s  •  %s  •  $%d" % [
		card_data.card_name,
		card_data.rarity,
		card_data.price,
	]
	var details := card_data.brief_description
	for keyword in card_data.keywords:
		var description := EffectKeyword.get_description(keyword)
		if not description.is_empty():
			details += "\n[color=%s]%s[/color]: %s" % [
				EffectKeyword.get_color(keyword),
				keyword,
				description,
			]
	highlight_description.text = details

func _rarity_color(rarity: String) -> Color:
	match rarity:
		WeaponCatalogData.RARITY_COMMON:
			return Color("#D8D8D8")
		WeaponCatalogData.RARITY_UNCOMMON:
			return Color("#67C587")
		WeaponCatalogData.RARITY_RARE:
			return Color("#C884FF")
	return Color.WHITE
