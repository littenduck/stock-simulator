## When each character skill may be used, and who gets to see it. The day has four windows:
## pre-market (the news comes in), market open (trade and call), after-market (the bets are revealed) and next day
## (the market moves and everything is paid out). A skill belongs to one window, or to ANY.
## `hidden` skills stay secret to everybody but their owner until their effect comes out; the others are played in front
## of the whole table, and everybody waits for the animation.
class_name TableSkills
extends RefCounted

enum Slot { ANY, PRE_MARKET, MARKET_OPEN, AFTER_MARKET, NEXT_DAY }

const INSIDER_TIP := &"insider_tip"
const INSIDER_FLIP := &"insider_flip"
const FLIP_REVEALED := &"flip_revealed"
const COPILOT := &"copilot"
const DOUBLE_DOWN := &"double_down"
const INTEREST := &"interest"
const GOLDFISH_ODDS := &"goldfish_odds"
const HODL_BUY := &"hodl_buy"
const HODL_SECTOR := &"hodl_sector"

## skill -> {"windows": [Slot...], "hidden": bool, "active": bool (the player chooses to use it)}
const DEFS := {
	INSIDER_TIP: {"windows": [Slot.PRE_MARKET], "hidden": true, "active": false},
	INSIDER_FLIP: {"windows": [Slot.MARKET_OPEN], "hidden": true, "active": true},
	FLIP_REVEALED: {"windows": [Slot.NEXT_DAY], "hidden": false, "active": false},
	COPILOT: {"windows": [Slot.MARKET_OPEN], "hidden": false, "active": true},
	DOUBLE_DOWN: {"windows": [Slot.AFTER_MARKET], "hidden": false, "active": true},
	INTEREST: {"windows": [Slot.NEXT_DAY], "hidden": false, "active": false},
	GOLDFISH_ODDS: {"windows": [Slot.AFTER_MARKET], "hidden": false, "active": false},
	HODL_BUY: {"windows": [Slot.PRE_MARKET], "hidden": false, "active": false},
	HODL_SECTOR: {"windows": [Slot.AFTER_MARKET], "hidden": false, "active": false},
}

const WINDOW_KEYS := ["TABLE_WIN_ANY", "TABLE_STEP_PRE", "TABLE_STEP_OPEN", "TABLE_STEP_AFTER", "TABLE_STEP_NEXT"]


## True when `skill` may be used (or may take effect) in `window`.
static func allows(skill: StringName, window: int) -> bool:
	if not DEFS.has(skill):
		return true
	var windows: Array = DEFS[skill]["windows"]
	return windows.has(Slot.ANY) or windows.has(window)


static func is_hidden(skill: StringName) -> bool:
	return bool(DEFS.get(skill, {}).get("hidden", false))


## The windows of a skill as translation keys, e.g. ["TABLE_STEP_AFTER"].
static func window_keys(skill: StringName) -> Array[String]:
	var out: Array[String] = []
	for w in DEFS.get(skill, {}).get("windows", []):
		out.append(WINDOW_KEYS[int(w)])
	return out
