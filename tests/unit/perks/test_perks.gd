## One test per perk, character and difficulty level: build modifiers and check the changed numbers/flags.
extends TestCase

const PERK_IDS: Array[StringName] = [
	&"low_fees", &"savings_account", &"early_bird", &"fact_checker", &"stop_guard", &"sector_fan",
	&"margin_account", &"cheap_borrow", &"diversifier", &"dividend_hunter", &"second_opinion",
	&"insider_friend", &"iron_hands", &"compounder", &"market_maker",
]


func _build(perk_id: StringName = &"", character_id: StringName = &"rookie", difficulty: int = 1) -> RunModifiers:
	var cfg := RunConfig.make(ContentDb.character_by_id(character_id), difficulty, 1, true)
	var owned: Array[PerkDef] = []
	if perk_id != &"":
		owned.append(ContentDb.perk_by_id(perk_id))
	return ModifiersBuilder.build(cfg, owned)


func test_all_perks_and_characters_load_with_localization() -> void:
	assert_eq(ContentDb.perks().size(), 15, "perk count")
	assert_eq(ContentDb.characters().size(), 3, "character count")
	for id in PERK_IDS:
		var p := ContentDb.perk_by_id(id)
		assert_not_null(p, "perk %s" % id)
		if p != null:
			assert_eq(p.title_key, "PERK_%s_TITLE" % String(id).to_upper())
	var csv := FileAccess.get_file_as_string("res://localization/perks.csv")
	for p in ContentDb.perks():
		assert_true(csv.contains(p.title_key + ","), "csv has " + p.title_key)
		assert_true(csv.contains(p.description_key + ","), "csv has " + p.description_key)
	var ccsv := FileAccess.get_file_as_string("res://localization/characters.csv")
	for c in ContentDb.characters():
		assert_true(ccsv.contains(c.title_key + ","), "csv has " + c.title_key)
		assert_true(ccsv.contains(c.description_key + ","), "csv has " + c.description_key)


func test_rarity_counts() -> void:
	var counts := [0, 0, 0]
	for p in ContentDb.perks():
		counts[p.rarity] += 1
	assert_eq(counts, [6, 5, 4])


func test_low_fees() -> void:
	assert_almost(_build(&"low_fees").effective_fee_rate(), 0.0005)


func test_savings_account() -> void:
	assert_almost(_build(&"savings_account").cash_interest_daily, 0.0005)


func test_early_bird() -> void:
	assert_eq(_build(&"early_bird").rumor_lead_days, 1)


func test_fact_checker() -> void:
	assert_true(_build(&"fact_checker").has_flag(&"fact_checker"))
	assert_false(_build().has_flag(&"fact_checker"))


func test_stop_guard() -> void:
	assert_true(_build(&"stop_guard").has_flag(&"stop_guard"))


func test_sector_fan() -> void:
	assert_true(_build(&"sector_fan").has_flag(&"sector_fan"))


func test_margin_account() -> void:
	assert_almost(_build(&"margin_account").max_leverage, 2.0)


func test_cheap_borrow() -> void:
	var m := _build(&"cheap_borrow")
	assert_almost(m.borrow_rate_daily, 0.0001)
	assert_almost(m.loan_rate_daily, 0.0001)


func test_diversifier() -> void:
	assert_true(_build(&"diversifier").has_flag(&"diversifier"))


func test_dividend_hunter() -> void:
	assert_almost(_build(&"dividend_hunter").long_dividend_daily, 0.0003)


func test_second_opinion() -> void:
	assert_eq(_build(&"second_opinion").draft_choices, 4)


func test_insider_friend() -> void:
	assert_true(_build(&"insider_friend").has_flag(&"insider_friend"))


func test_iron_hands() -> void:
	var m := _build(&"iron_hands")
	assert_true(m.has_flag(&"iron_hands"))
	assert_false(m.iron_hands_used)


func test_compounder() -> void:
	assert_almost(_build(&"compounder").score_mult, 1.1)


func test_market_maker() -> void:
	var m := _build(&"market_maker")
	assert_almost(m.effective_fee_rate(), 0.0)
	assert_almost(m.limit_price_improvement, 0.01)


func test_market_maker_wins_over_low_fees_in_any_order() -> void:
	var cfg := RunConfig.make(ContentDb.character_by_id(&"rookie"), 1, 1, true)
	var owned: Array[PerkDef] = [ContentDb.perk_by_id(&"low_fees"), ContentDb.perk_by_id(&"market_maker")]
	assert_almost(ModifiersBuilder.build(cfg, owned).effective_fee_rate(), 0.0)


func test_rookie_changes_nothing() -> void:
	var m := _build()
	var base := RunModifiers.new()
	assert_almost(m.fee_rate, base.fee_rate)
	assert_almost(m.max_leverage, 1.0)
	assert_true(m.can_short)
	assert_eq(ContentDb.character_by_id(&"rookie").start_cash, 10000.0)


func test_day_trader() -> void:
	var c := ContentDb.character_by_id(&"day_trader")
	assert_eq(c.start_cash, 8000.0)
	assert_eq(c.unlock_id, Profile.UNLOCK_CHAR_DAY_TRADER)
	var m := _build(&"", &"day_trader")
	assert_almost(m.max_leverage, 2.0)
	assert_almost(m.effective_fee_rate(), 0.0005)


func test_day_trader_does_not_double_apply_low_fees() -> void:
	var cfg := RunConfig.make(ContentDb.character_by_id(&"day_trader"), 1, 1, true)
	var owned: Array[PerkDef] = [ContentDb.perk_by_id(&"low_fees")]
	assert_almost(ModifiersBuilder.build(cfg, owned).effective_fee_rate(), 0.0005)


func test_value_investor() -> void:
	var c := ContentDb.character_by_id(&"value_investor")
	assert_eq(c.start_cash, 12000.0)
	assert_eq(c.unlock_id, Profile.UNLOCK_CHAR_VALUE_INVESTOR)
	var m := _build(&"", &"value_investor")
	assert_false(m.can_short)
	assert_almost(m.dividend_mult, 2.0)


func test_difficulty_levels_are_cumulative() -> void:
	var base := RunModifiers.new()
	var m1 := _build(&"", &"rookie", 1)
	assert_almost(m1.fee_rate, base.fee_rate)
	assert_eq(m1.draft_choices, 3)
	var m2 := _build(&"", &"rookie", 2)
	assert_almost(m2.fee_rate, base.fee_rate * 1.5)
	assert_almost(m2.rumor_truth_bonus, 0.0)
	var m3 := _build(&"", &"rookie", 3)
	assert_almost(m3.fee_rate, base.fee_rate * 1.5)
	assert_almost(m3.rumor_truth_bonus, -0.10)
	assert_almost(m3.maintenance_margin, 0.30)
	assert_almost(m3.volatility_mult, 1.0)
	var m4 := _build(&"", &"rookie", 4)
	assert_almost(m4.maintenance_margin, 0.40)
	assert_almost(m4.volatility_mult, 1.2)
	assert_eq(m4.draft_choices, 3)
	var m5 := _build(&"", &"rookie", 5)
	assert_eq(m5.draft_choices, 2)
	assert_almost(m5.maintenance_margin, 0.40)


func test_second_opinion_offsets_difficulty_5() -> void:
	assert_eq(_build(&"second_opinion", &"rookie", 5).draft_choices, 3)


func test_value_investor_can_short_stays_a_real_bool() -> void:
	var m := _build(&"", &"value_investor")
	assert_eq(typeof(m.can_short), TYPE_BOOL, "can_short must remain a bool after the SET effect")
	assert_eq(m.can_short, false)
	assert_eq(typeof(_build().can_short), TYPE_BOOL)


func test_rebuild_from_ids_is_identical_and_order_independent() -> void:
	var cfg := RunConfig.make(ContentDb.character_by_id(&"day_trader"), 4, 1, true)
	var a: Array[PerkDef] = [ContentDb.perk_by_id(&"margin_account"), ContentDb.perk_by_id(&"cheap_borrow"), ContentDb.perk_by_id(&"compounder")]
	var b: Array[PerkDef] = [a[2], a[0], a[1]]
	var m1 := ModifiersBuilder.build(cfg, a)
	var m2 := ModifiersBuilder.build(cfg, b)
	var m3 := ModifiersBuilder.build(cfg, a)
	for stat in ["fee_rate", "fee_mult", "max_leverage", "maintenance_margin", "borrow_rate_daily", "loan_rate_daily", "score_mult", "draft_choices"]:
		assert_almost(m1.get(stat), m2.get(stat), 0.000001, "order independent " + stat)
		assert_almost(m1.get(stat), m3.get(stat), 0.000001, "rebuild " + stat)
	assert_almost(m1.max_leverage, 3.0, 0.000001, "day trader +1, margin account +1")


func test_difficulty_clamps_out_of_range_levels() -> void:
	var low := RunModifiers.new()
	Difficulty.apply(0, low)
	assert_almost(low.fee_rate, RunModifiers.new().fee_rate)
	var high := RunModifiers.new()
	var max_mods := RunModifiers.new()
	Difficulty.apply(99, high)
	Difficulty.apply(Difficulty.MAX_LEVEL, max_mods)
	assert_almost(high.maintenance_margin, max_mods.maintenance_margin)
	assert_eq(high.draft_choices, max_mods.draft_choices)


func test_difficulty_5_with_every_draft_perk_combination_keeps_two_choices_minimum() -> void:
	assert_true(_build(&"", &"rookie", 5).draft_choices >= 2)
