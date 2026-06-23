class_name EffectKeyword
extends RefCounted

const KEYWORD_COLORS := {
	"Damage": "#FF7777",
	"Luck": "#B77DFF",
	"Reveal": "#66CCFF",
	"Bleed": "#FF5555",
	"Conceal": "#AAAAFF",
}

const KEYWORD_DESCRIPTIONS := {
	"Damage": "Reduces enemy HP.",
	"Luck": "Increases chance-based effects.",
	"Reveal": "Shows hidden enemy information.",
	"Bleed": "Deals damage at the end of turns.",
	"Conceal": "Disables or hides an option.",
}

static func get_color(keyword: String) -> String:
	return KEYWORD_COLORS.get(keyword, "#FFFFFF")

static func get_description(keyword: String) -> String:
	return KEYWORD_DESCRIPTIONS.get(keyword, "")
