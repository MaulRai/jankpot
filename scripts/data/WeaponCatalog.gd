class_name WeaponCatalog
extends RefCounted

const RARITY_BASIC := "Basic"
const RARITY_COMMON := "Common"
const RARITY_UNCOMMON := "Uncommon"
const RARITY_RARE := "Rare"

const EFFECT_QUARTZ := "quartz_block_downgrade"
const EFFECT_BRONZE_RAZOR := "bronze_razor_bonus"
const EFFECT_SCULPTURAL_SHEET := "sculptural_sheet_draw_damage"
const EFFECT_SPIKE_BOULDER := "spiked_boulder_reflect"
const EFFECT_RUSTY_SHEARS := "rusty_shears_bleed"
const EFFECT_MIST_VEIL := "mist_veil_disable"
const EFFECT_RUBY_REGEN := "ruby_regen"
const EFFECT_RUBY_REVIVE := "ruby_revive_fragile"
const EFFECT_GUILLOTINE := "guillotine_blades"
const EFFECT_HATTER_SLIP := "hatter_slip_luck"

static func create_basic(type: CardDef.CardType, instance_id: String = "") -> CardDef:
	var card := CardDef.new()
	card.id = instance_id if not instance_id.is_empty() else "basic_%d" % type
	card.card_type = type
	card.rarity = RARITY_BASIC
	card.price = 0
	card.is_basic = true
	match type:
		CardDef.CardType.ROCK:
			card.card_name = "Rock"
			card.brief_description = "Nothing but a plain rock."
			card.art_path = "res://assets/weapon/rock-1.png"
			card.background_color = Color("#7E91A3")
		CardDef.CardType.PAPER:
			card.card_name = "Paper"
			card.brief_description = "Just an ordinary sheet."
			card.art_path = "res://assets/weapon/paper-1.png"
			card.background_color = Color("#E7DFA4")
		CardDef.CardType.SCISSORS:
			card.card_name = "Scissors"
			card.brief_description = "A simple pair of scissors."
			card.art_path = "res://assets/weapon/scissors-1.png"
			card.background_color = Color("#9A4A4A")
	return card

static func create_weapon(weapon_id: String) -> CardDef:
	var card := CardDef.new()
	card.id = weapon_id
	card.price = 0
	card.is_basic = false
	match weapon_id:
		"quartz":
			_setup(card, CardDef.CardType.ROCK, "Quartz", RARITY_COMMON,
				"On lose, Block 1 DMG. Downgrade.", "res://assets/weapon/rock-2.png",
				["Downgrade"], [EFFECT_QUARTZ])
		"bronze_razor":
			_setup(card, CardDef.CardType.SCISSORS, "Bronze Razor", RARITY_COMMON,
				"On win, 50% chance to deal +1 DMG.", "res://assets/weapon/scissors-2.png",
				["Luck"], [EFFECT_BRONZE_RAZOR])
		"sculptural_sheet":
			_setup(card, CardDef.CardType.PAPER, "Sculptural Sheet", RARITY_COMMON,
				"On draw, deal 1 DMG.", "res://assets/weapon/paper-2.png",
				[], [EFFECT_SCULPTURAL_SHEET])
		"spiked_boulder":
			_setup(card, CardDef.CardType.ROCK, "Spiked Boulder", RARITY_UNCOMMON,
				"When this card takes damage, 50% chance to deal 1 DMG back.",
				"res://assets/weapon/rock-3.png", ["Luck"], [EFFECT_SPIKE_BOULDER])
		"rusty_shears":
			_setup(card, CardDef.CardType.SCISSORS, "Rusty Shears", RARITY_UNCOMMON,
				"On win, apply 1 Bleed.", "res://assets/weapon/scissors-3.png",
				["Bleed"], [EFFECT_RUSTY_SHEARS])
		"mist_veil":
			_setup(card, CardDef.CardType.PAPER, "Mist Veil", RARITY_UNCOMMON,
				"On win, disable the enemy's last option next turn.",
				"res://assets/weapon/paper-3.png", ["Conceal"], [EFFECT_MIST_VEIL])
		"ruby":
			_setup(card, CardDef.CardType.ROCK, "Ruby", RARITY_RARE,
				"On win, regen 1 heart. On death, revive with 1 heart. Fragile.",
				"res://assets/weapon/rock-4.png", ["Fragile"], [EFFECT_RUBY_REGEN, EFFECT_RUBY_REVIVE])
		"guillotine_blades":
			_setup(card, CardDef.CardType.SCISSORS, "Guillotine Blades", RARITY_RARE,
				"On win, deal 3 total DMG. On lose or draw, take 1 self DMG.",
				"res://assets/weapon/scissors-4.png", [], [EFFECT_GUILLOTINE])
		"hatter_slip":
			_setup(card, CardDef.CardType.PAPER, "Hatter Slip", RARITY_RARE,
				"While in hand, chance effects gain +15% Luck. Does not stack.",
				"res://assets/weapon/paper-4.png", ["Luck"], [EFFECT_HATTER_SLIP])
		_:
			return create_basic(CardDef.CardType.ROCK)
	return card

static func generate_reward_choices(
	count: int = 3,
	allowed_types: Array[int] = []
) -> Array[CardDef]:
	var choices: Array[CardDef] = []
	var ids := _all_upgrade_ids()
	ids.shuffle()
	while choices.size() < count:
		var rarity := roll_rarity()
		var candidates: Array[String] = []
		for weapon_id in ids:
			var candidate := create_weapon(weapon_id)
			var type_allowed := allowed_types.is_empty() or candidate.card_type in allowed_types
			if type_allowed and candidate.rarity == rarity and not _contains_weapon(choices, weapon_id):
				candidates.append(weapon_id)
		if candidates.is_empty():
			for weapon_id in ids:
				var candidate := create_weapon(weapon_id)
				var type_allowed := allowed_types.is_empty() or candidate.card_type in allowed_types
				if type_allowed and not _contains_weapon(choices, weapon_id):
					candidates.append(weapon_id)
		if candidates.is_empty():
			break
		choices.append(create_weapon(candidates.pick_random()))
	return choices

static func random_upgrade_for_type(type: CardDef.CardType) -> CardDef:
	var rarity := roll_rarity()
	var candidates: Array[String] = []
	for weapon_id in _all_upgrade_ids():
		var card := create_weapon(weapon_id)
		if card.card_type == type and card.rarity == rarity:
			candidates.append(weapon_id)
	if candidates.is_empty():
		return create_basic(type)
	return create_weapon(candidates.pick_random())

static func roll_rarity() -> String:
	var roll := randi_range(1, 7)
	if roll <= 4:
		return RARITY_COMMON
	if roll <= 6:
		return RARITY_UNCOMMON
	return RARITY_RARE

static func _setup(
	card: CardDef,
	type: CardDef.CardType,
	name: String,
	rarity: String,
	description: String,
	art_path: String,
	keywords: Array[String],
	effects: Array[String]
) -> void:
	card.card_type = type
	card.card_name = name
	card.rarity = rarity
	card.brief_description = description
	card.art_path = art_path
	card.keywords = keywords
	card.effects = effects
	match type:
		CardDef.CardType.ROCK:
			card.background_color = Color("#7E91A3")
		CardDef.CardType.PAPER:
			card.background_color = Color("#E7DFA4")
		CardDef.CardType.SCISSORS:
			card.background_color = Color("#9A4A4A")

static func _all_upgrade_ids() -> Array[String]:
	return [
		"quartz", "bronze_razor", "sculptural_sheet",
		"spiked_boulder", "rusty_shears", "mist_veil",
		"ruby", "guillotine_blades", "hatter_slip",
	]

static func _contains_weapon(cards: Array[CardDef], weapon_id: String) -> bool:
	for card in cards:
		if card.id == weapon_id:
			return true
	return false
