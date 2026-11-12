extends TestCase


func _drafter(seed_value: int) -> PerkDrafter:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return PerkDrafter.new(ContentDb.perks(), rng)


func _ids(perks: Array[PerkDef]) -> Array:
	return perks.map(func(p: PerkDef) -> StringName: return p.id)


func test_offer_has_count_distinct_unowned() -> void:
	var owned: Array[PerkDef] = [ContentDb.perk_by_id(&"low_fees"), ContentDb.perk_by_id(&"iron_hands")]
	for s in 20:
		var offer := _drafter(s).offer(owned, 4)
		assert_eq(offer.size(), 4)
		var ids := _ids(offer)
		for id in ids:
			assert_eq(ids.count(id), 1, "no duplicates")
			assert_true(id != &"low_fees" and id != &"iron_hands", "not owned")


func test_same_seed_same_offers() -> void:
	var none: Array[PerkDef] = []
	for s in 10:
		assert_eq(_ids(_drafter(s).offer(none, 3)), _ids(_drafter(s).offer(none, 3)))


func test_offer_is_capped_by_pool() -> void:
	var owned: Array[PerkDef] = ContentDb.perks().slice(0, 13)
	assert_eq(_drafter(1).offer(owned, 3).size(), 2)
	var all: Array[PerkDef] = ContentDb.perks()
	assert_eq(_drafter(1).offer(all, 3).size(), 0)


func test_rarity_weights_roughly_60_30_10() -> void:
	# First pick of each draw follows the weights: per-perk 60/6, 30/5, 10/4 => 0.5/ 0.375 ... computed below.
	var none: Array[PerkDef] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var d := PerkDrafter.new(ContentDb.perks(), rng)
	var counts := [0, 0, 0]
	var n := 6000
	for i in n:
		counts[d.offer(none, 1)[0].rarity] += 1
	# Perks per rarity: 6 common, 5 rare, 4 legendary; weights apply per perk: 360 / 150 / 40 of 550.
	assert_almost(counts[0] / float(n), 360.0 / 550.0, 0.03, "common")
	assert_almost(counts[1] / float(n), 150.0 / 550.0, 0.03, "rare")
	assert_almost(counts[2] / float(n), 40.0 / 550.0, 0.02, "legendary")


func test_zero_or_negative_count_returns_empty() -> void:
	var none: Array[PerkDef] = []
	assert_eq(_drafter(1).offer(none, 0).size(), 0)
	assert_eq(_drafter(1).offer(none, -2).size(), 0)


func test_offer_does_not_mutate_inputs() -> void:
	var owned: Array[PerkDef] = [ContentDb.perk_by_id(&"low_fees")]
	var pool_size := ContentDb.perks().size()
	_drafter(3).offer(owned, 3)
	assert_eq(owned.size(), 1)
	assert_eq(ContentDb.perks().size(), pool_size)


func test_six_drafts_in_a_row_never_repeat() -> void:
	var d := _drafter(99)
	var owned: Array[PerkDef] = []
	for i in 6:
		var offer := d.offer(owned, 3)
		assert_eq(offer.size(), 3)
		for p in offer:
			assert_false(p in owned, "offered an owned perk")
		owned.append(offer[0])
	assert_eq(owned.size(), 6)
