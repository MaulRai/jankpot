class_name EffectKeyword
extends RefCounted

const KEYWORD_COLORS := {
	"Luck": "#B77DFF",
	"Reveal": "#66CCFF",
	"Bleed": "#FF5555",
	"Shield": "#8FD7FF",
	"Cup-a-Joe": "#D7A56A",
	"Conceal": "#AAAAFF",
	"Downgrade": "#D5A86E",
	"Fragile": "#FF9DB5",
}

const KEYWORD_DESCRIPTIONS := {
	"Luck": "Adds to the probability of chance-based weapon effects.",
	"Reveal": "Shows hidden enemy information.",
	"Bleed": "Deals 1 damage at the end of the next turn, then disappears.",
	"Shield": "Blocks 1 damage, then disappears.",
	"Cup-a-Joe": "This turn, if your card wins, its damage executes twice.",
	"Conceal": "Disables or hides an option.",
	"Downgrade": "Becomes its basic weapon for the rest of the current battle.",
	"Fragile": "Temporarily disappears for the rest of the current battle after it breaks.",
}

static func get_color(keyword: String) -> String:
	return KEYWORD_COLORS.get(keyword, "#FFFFFF")

static func get_description(keyword: String) -> String:
	return KEYWORD_DESCRIPTIONS.get(keyword, "")
