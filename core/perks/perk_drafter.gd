## Draws perk options weighted by rarity (60/30/10), never offering owned perks.
## CONTRACT: public signatures frozen. Owner of the body: meta-progression.
## STUB: returns the first `count` unowned perks.
class_name PerkDrafter
extends RefCounted

var _pool: Array[PerkDef] = []
var _rng: RandomNumberGenerator


func _init(pool: Array[PerkDef], rng: RandomNumberGenerator) -> void:
	_pool = pool
	_rng = rng


func offer(owned: Array[PerkDef], count: int) -> Array[PerkDef]:
	var out: Array[PerkDef] = []
	for p in _pool:
		if p not in owned and out.size() < count:
			out.append(p)
	return out
