## Colours shared by the flat theme and by code that tints things (rarity, up/down).
class_name UiPalette
extends RefCounted

const BG := Color("#0f141a")
const PANEL := Color("#1a222c")
const PANEL_RAISED := Color("#232e3b")
const BORDER := Color("#344253")
const TEXT := Color("#e6edf3")
const MUTED := Color("#8b98a8")
const ACCENT := Color("#4c9ffe")
const UP := Color("#3fb950")
const DOWN := Color("#f85149")
const GOLD := Color("#e3b341")
const DIM := Color(0.0, 0.0, 0.0, 0.62)

## Text on the light Kenney panels.
const INK := Color("#232130")
const INK_MUTED := Color("#5d6270")
const INK_UP := Color("#2a8a3c")
const INK_DOWN := Color("#c0392b")

const RARITY_COMMON := Color("#5d6270")
const RARITY_RARE := Color("#1f6fc4")
const RARITY_LEGENDARY := Color("#b9770e")


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
