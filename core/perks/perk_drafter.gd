## Draws perk options weighted by rarity (60/30/10), never offering owned perks.
## CONTRACT: public signatures frozen. Owner of the body: meta-progression.
## Deterministic: same pool order + same RNG state + same inputs = same offer.
class_name PerkDrafter
extends RefCounted

const WEIGHTS := {
	PerkDef.Rarity.COMMON: 60.0,
	PerkDef.Rarity.RARE: 30.0,
	PerkDef.Rarity.LEGENDARY: 10.0,
}

var _pool: Array[PerkDef] = []
var _rng: RandomNumberGenerator


func _init(pool: Array[PerkDef], rng: RandomNumberGenerator) -> void:
	_pool = pool
	_rng = rng


func offer(owned: Array[PerkDef], count: int) -> Array[PerkDef]:
	var candidates: Array[PerkDef] = []
	for p in _pool:
		if p not in owned and p not in candidates:
			candidates.append(p)
	var picks: Array[PerkDef] = []
	while picks.size() < count and not candidates.is_empty():
		var weights := PackedFloat32Array()
		for p in candidates:
			weights.append(float(WEIGHTS.get(p.rarity, 1.0)))
		var index := _rng.rand_weighted(weights)
		picks.append(candidates[index])
		candidates.remove_at(index)
	return picks
