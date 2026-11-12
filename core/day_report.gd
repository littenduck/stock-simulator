## Everything that happened during GameSession.next_day(). GameManager turns it into EventBus signals.
## CONTRACT: fields frozen. Owner of the body: session-integration.
class_name DayReport
extends RefCounted

var day: int = 0
var new_rumors: Array[Rumor] = []
var resolved_rumors: Array[Rumor] = []
## Results of LIMIT/STOP orders that triggered today (ok = filled, !ok = voided).
var fills: Array[TradeResult] = []
var margin_called: bool = false
## Non-empty when a perk draft starts (day 10, 20, ..., 50). Array of PerkDef.
var draft_offer: Array[PerkDef] = []
var finished: bool = false
