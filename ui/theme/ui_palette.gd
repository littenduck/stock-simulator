## Colours used by code and the theme generator (the panels/buttons themselves come from the Kenney art).
class_name UiPalette
extends RefCounted

const BG := Color("#0f141a")

## Text on the light Kenney panels.
const INK := Color("#232130")
const INK_MUTED := Color("#5d6270")
const INK_UP := Color("#2a8a3c")
const INK_DOWN := Color("#c0392b")

const RARITY_COMMON := Color("#5d6270")
const RARITY_RARE := Color("#1f6fc4")
const RARITY_LEGENDARY := Color("#b9770e")

## Sector ("race") theme colours, like the factions of a card game: each sector has a main colour (borders, badges),
## a soft tint (card and row backgrounds on the cream panels) and a deep tone (text and outlines on the tint).
## They avoid the up/down green and red, the rarity colours and the avg-cost gold, so a frame never looks like a signal.
const SECTOR_TECH := Color("#1ea7d6")          ## circuit cyan
const SECTOR_TECH_SOFT := Color("#dff3fa")
const SECTOR_TECH_DEEP := Color("#0f6f91")
const SECTOR_SPACE := Color("#7b4fd6")         ## nebula violet
const SECTOR_SPACE_SOFT := Color("#ebe3fb")
const SECTOR_SPACE_DEEP := Color("#4d2b9e")
const SECTOR_CONSUMER := Color("#ee62a6")      ## shop pink
const SECTOR_CONSUMER_SOFT := Color("#fde4f1")
const SECTOR_CONSUMER_DEEP := Color("#a3195f")
const SECTOR_FINANCE := Color("#18a999")       ## vault teal
const SECTOR_FINANCE_SOFT := Color("#d9f3ef")
const SECTOR_FINANCE_DEEP := Color("#0d6f64")
const SECTOR_NEUTRAL := Color("#5d6270")
const SECTOR_NEUTRAL_SOFT := Color("#e6e3dc")
const SECTOR_NEUTRAL_DEEP := Color("#3b3f4a")


## Main colour of a CompanyDef.sector ("tech", "space", "consumer", "finance"); neutral grey for anything else.
static func sector_color(sector: String) -> Color:
	match sector:
		"tech":
			return SECTOR_TECH
		"space":
			return SECTOR_SPACE
		"consumer":
			return SECTOR_CONSUMER
		"finance":
			return SECTOR_FINANCE
		_:
			return SECTOR_NEUTRAL


## Soft background tint of a sector.
static func sector_soft(sector: String) -> Color:
	match sector:
		"tech":
			return SECTOR_TECH_SOFT
		"space":
			return SECTOR_SPACE_SOFT
		"consumer":
			return SECTOR_CONSUMER_SOFT
		"finance":
			return SECTOR_FINANCE_SOFT
		_:
			return SECTOR_NEUTRAL_SOFT


## Deep tone of a sector for text and outlines drawn on the soft tint.
static func sector_deep(sector: String) -> Color:
	match sector:
		"tech":
			return SECTOR_TECH_DEEP
		"space":
			return SECTOR_SPACE_DEEP
		"consumer":
			return SECTOR_CONSUMER_DEEP
		"finance":
			return SECTOR_FINANCE_DEEP
		_:
			return SECTOR_NEUTRAL_DEEP


## `rarity` is a PerkDef.Rarity value.
static func rarity_color(rarity: int) -> Color:
	match rarity:
		PerkDef.Rarity.RARE:
			return RARITY_RARE
		PerkDef.Rarity.LEGENDARY:
			return RARITY_LEGENDARY
		_:
			return RARITY_COMMON


## Localization key of the rarity name.
static func rarity_key(rarity: int) -> String:
	match rarity:
		PerkDef.Rarity.RARE:
			return "UI_FLOW_RARITY_RARE"
		PerkDef.Rarity.LEGENDARY:
			return "UI_FLOW_RARITY_LEGENDARY"
		_:
			return "UI_FLOW_RARITY_COMMON"
