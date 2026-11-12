## Fixed up/down colours and arrows (game design decision #14: green up, red down, arrows for colour-blind players).
class_name GameColors
extends RefCounted

const UP := Color("#3fb950")
const DOWN := Color("#f85149")
const FLAT := Color("#8b949e")
const WARN := Color("#d29922")
const GOLD := Color("#e3b341")
const MUTED := Color("#8b949e")

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
