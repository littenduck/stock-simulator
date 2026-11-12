## Fixed up/down colours and arrows (game design decision #14: green up, red down, arrows for colour-blind players).
class_name GameColors
extends RefCounted

static var UP := Color("#3fb950")
static var DOWN := Color("#f85149")
static var FLAT := Color("#8b949e")
static var WARN := Color("#d29922")
static var GOLD := Color("#e3b341")
static var MUTED := Color("#8b949e")

## Chart helpers and card tint; the skin changes these together with the colours above.
static var GRID := Color(1, 1, 1, 0.08)
static var CROSSHAIR := Color(1, 1, 1, 0.35)
static var CARD := Color(1, 1, 1, 0.04)
static var TRACK := Color(1, 1, 1, 0.12)

const ARROW_UP := "▲"
const ARROW_DOWN := "▼"
const ARROW_FLAT := "–"

const EPSILON := 0.00005


static func for_change(change: float) -> Color:
	if change > EPSILON:
		return UP
	if change < -EPSILON:
		return DOWN
	return FLAT


static func arrow(change: float) -> String:
	if change > EPSILON:
		return ARROW_UP
	if change < -EPSILON:
		return ARROW_DOWN
	return ARROW_FLAT


## "▲ 1.25%" for a fraction (0.0125).
static func pct_text(change: float) -> String:
	return "%s %.2f%%" % [arrow(change), absf(change) * 100.0]
