## Decides which rumors appear each day. Never changes prices (the session does that).
## CONTRACT: public signatures frozen. Owner of the body: market-engine.
## STUB: never produces rumors yet.
class_name NewsDirector
extends RefCounted

var _pool: Array[NewsEventDef] = []
var _rng: RandomNumberGenerator
var _pending: Array[Rumor] = []


func _init(pool: Array[NewsEventDef], rng: RandomNumberGenerator) -> void:
	_pool = pool
	_rng = rng


## New rumors posted today (also remembered as pending until revealed).
func roll(_day: int, _mods: RunModifiers, _market: MarketSim) -> Array[Rumor]:
	return []


## Pending rumors whose reveal_day == day; marks them resolved.
func due(_day: int) -> Array[Rumor]:
	return []


## Rumors still waiting for their reveal day.
func pending() -> Array[Rumor]:
	return _pending


func to_dict() -> Dictionary:
	return {"cooldowns": {}, "pending": []}


func load_dict(_data: Dictionary) -> void:
	pass
