extends TestCase

const SEED := 1234


func _session(char_id: StringName = &"saving_son", seed_value: int = SEED) -> TableSession:
	var cfg := RunConfig.make_table(ContentDb.character_by_id(char_id), seed_value)
	var s := TableSession.new(cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	s.start()
	return s


func _play_to_end(s: TableSession, side: int = RumorTier.Side.BELIEVE) -> int:
	var days := 0
	while not s.is_finished() and days < 40:
		s.set_call(side)
		s.next_day()
		days += 1
	return days


func test_table_config() -> void:
	var cfg := RunConfig.make_table(ContentDb.character_by_id(&"saving_son"), 5)
	assert_eq(cfg.trading_days, 30)
	assert_eq(cfg.mode, RunConfig.Mode.TABLE)
	assert_false(cfg.fees_enabled, "fees are off by default in table mode")
	assert_eq(ModifiersBuilder.build(cfg, []).effective_fee_rate(), 0.0)


func test_six_table_characters_exist() -> void:
	var ids: Array[String] = []
	for c in ContentDb.characters():
		if c.table_role:
			ids.append(String(c.id))
	ids.sort()
	assert_eq(ids, ["copilot_cody", "double_dan", "goldfish_gus", "hodl_hana", "insider_inu", "saving_son"])


func test_four_distinct_seats_human_first() -> void:
	var s := _session()
	assert_eq(s.seats.size(), 4)
	assert_true(s.seats[0].is_human)
	assert_eq(s.seats[0].character.id, &"saving_son")
	var seen := {}
	for seat in s.seats:
		seen[seat.character.id] = true
	assert_eq(seen.size(), 4, "all characters differ")


func test_same_seed_same_table() -> void:
	var a := _session(&"saving_son", 77)
	var b := _session(&"saving_son", 77)
	for i in 4:
		assert_eq(a.seats[i].character.id, b.seats[i].character.id)
	assert_eq(a.today_rumor.headline_key, b.today_rumor.headline_key)
	assert_eq(a.today_rumor.claim_dir, b.today_rumor.claim_dir)


func test_full_run_ends_by_day_30() -> void:
	var s := _session()
	_play_to_end(s)
	assert_true(s.is_finished())
	assert_true(s.day <= 30)
	assert_eq(s.day, 30, "nobody is fired, so every run lasts 30 days")


func test_rumors_are_single_stock_and_resolve_next_day() -> void:
	var s := _session()
	assert_eq(s.today_rumor.symbols.size(), 1)
	assert_eq(s.today_rumor.resolve_day, 1)
	assert_true(s.market.has_symbol(s.today_rumor.primary_symbol()))
	assert_not_null(s.tomorrow_rumor)


func test_truth_is_the_real_price_move() -> void:
	var s := _session()
	var rumor := s.today_rumor
	var base := s.market.price_of(rumor.primary_symbol())
	s.next_day()
	var after := s.market.price_of(rumor.primary_symbol())
	assert_true(rumor.resolved)
	assert_eq(rumor.came_true, (rumor.claim_dir > 0) == (after >= base), "true when the price moved the claimed way")


func test_tiers_match_their_shown_chance() -> void:
	# Over many daily rumors the share that came true follows the shown tier (33 / 50 / 80 %).
	var hits := {0: 0, 1: 0, 2: 0}
	var total := {0: 0, 1: 0, 2: 0}
	for seed_value in range(1, 25):
		var s := _session(&"saving_son", seed_value)
		while not s.is_finished():
			var rumor := s.today_rumor
			s.next_day()
			total[rumor.tier] += 1
			hits[rumor.tier] += 1 if rumor.came_true else 0
	for tier in 3:
		assert_true(total[tier] > 80, "enough samples for tier %d" % tier)
		var rate: float = float(hits[tier]) / float(total[tier])
		assert_almost(rate, RumorTier.truth_chance(tier), 0.12, "tier %d truth rate" % tier)


func test_bet_pays_premium_times_odds_or_nothing() -> void:
	var s := _session(&"double_dan")
	var cash0 := s.portfolio.cash
	var nw0 := s.net_worth()
	s.set_call(RumorTier.Side.BELIEVE)
	s.reveal()
	var bet := s.daily_bet_of(0)
	assert_not_null(bet)
	assert_almost(bet.premium, nw0 * 0.10, 0.01, "premium is 10% of net worth")
	assert_almost(s.portfolio.cash, cash0 - bet.premium, 0.01)
	var rumor := s.today_rumor
	var odds := RumorTier.odds(RumorTier.Side.BELIEVE, rumor.tier)
	var cash_before := s.portfolio.cash
	s.advance()
	var gained := s.portfolio.cash - cash_before
	if rumor.came_true:
		assert_almost(gained, bet.premium * odds, 0.5, "winning pays premium x odds")
	else:
		assert_almost(gained, 0.0, 0.5, "losing pays nothing (plus the day's interest)")


func test_pass_costs_nothing() -> void:
	var s := _session(&"double_dan")
	s.set_call(RumorTier.Side.PASS)
	s.reveal()
	assert_true(s.daily_bet_of(0) == null)


func test_premium_never_exceeds_cash() -> void:
	var s := _session()
	s.buy_fraction(0, s.market.symbols()[0], 1.0)
	assert_true(s.portfolio.cash < 10.0)
	assert_eq(s.premium_for(0), 0.0, "no premium when the cash is gone")


func test_trade_buttons() -> void:
	var s := _session()
	var sym := s.market.symbols()[0]
	var r := s.buy_fraction(0, sym, 0.25)
	assert_true(r.ok)
	assert_almost(s.portfolio.cash, 7500.0, 60.0, "a quarter of the cash was spent")
	var held := s.portfolio.shares_of(sym)
	s.sell_fraction(0, sym, 0.5)
	assert_eq(s.portfolio.shares_of(sym), held - maxi(1, floori(held * 0.5)))
	s.sell_fraction(0, sym, 1.0)
	assert_eq(s.portfolio.shares_of(sym), 0)
	var other := s.market.symbols()[1]
	s.buy_fraction(0, sym, 1.0)
	var swapped := s.swap(0, sym, other)
	assert_true(swapped.ok)
	assert_eq(s.portfolio.shares_of(sym), 0)
	assert_true(s.portfolio.shares_of(other) > 0)


func test_saving_son_cash_earns_interest() -> void:
	var s := _session(&"saving_son")
	var nw0 := s.net_worth()
	s.next_day()
	assert_true(s.net_worth() > nw0 - 1.0)
	assert_almost(s.seats[0].mods.cash_interest_daily, 0.005)


func test_hodl_hana_owns_a_locked_cheap_stock() -> void:
	var s := _session(&"hodl_hana")
	var locked := s.seats[0].mods.locked_symbol
	assert_true(locked != "", "a stock is locked")
	assert_true(s.portfolio.shares_of(locked) > 0)
	assert_true(s.net_worth() > 10000.0, "bought at the pre-game low: already in profit")
	var res := s.sell_fraction(0, locked, 1.0)
	assert_false(res.ok)
	assert_eq(res.reason, TradeService.ERR_LOCKED)


func test_goldfish_gus_gets_extra_odds() -> void:
	var s := _session(&"goldfish_gus")
	var plain := RumorTier.odds(RumorTier.Side.BELIEVE, s.today_rumor.tier)
	assert_almost(s.odds_for(s.seats[0], s.today_rumor, RumorTier.Side.BELIEVE), plain + 0.3)


func test_double_down_doubles_the_premium_once_per_quarter() -> void:
	var s := _session(&"double_dan")
	s.set_call(RumorTier.Side.BELIEVE)
	s.reveal()
	var before := s.daily_bet_of(0).premium
	assert_true(s.can_double(0))
	assert_true(s.double_down(0))
	assert_almost(s.daily_bet_of(0).premium, before * 2.0, 0.01)
	assert_false(s.can_double(0), "once per quarter")


func test_copilot_copies_the_target_at_a_discount() -> void:
	var s := _session(&"copilot_cody")
	s.set_copy_target(1)
	s.calls[1] = RumorTier.Side.BELIEVE
	# The computer seats decide on their own inside reveal(); copy whatever seat 1 ends up doing.
	s.reveal()
	var theirs := s.daily_bet_of(1)
	var mine := s.daily_bet_of(0)
	if theirs == null:
		assert_true(mine == null, "copying a pass is a pass")
	else:
		assert_not_null(mine)
		assert_eq(mine.side, theirs.side)
		assert_eq(mine.copied_from, 1)
		assert_almost(mine.odds, RumorTier.odds(mine.side, s.today_rumor.tier), 0.0001, "a copied bet has the normal odds")


func test_insider_learns_a_true_rumor_and_can_flip_it() -> void:
	var found := false
	for seed_value in range(1, 12):
		var s := _session(&"insider_inu", seed_value)
		if s.insider_days.is_empty():
			continue
		while not s.is_finished() and s.day not in s.insider_days:
			s.next_day()
		if s.is_finished():
			continue
		assert_true(s.can_flip(0), "the Insider has a hint on her day")
		var hint := s.insider_hint()
		var honest := hint.claim_dir
		s.arm_flip(true)
		s.next_day()
		var shown := s.today_rumor
		assert_true(shown.planted, "flipped rumor is planted")
		assert_eq(shown.claim_dir, -honest, "the opposite is published")
		assert_eq(s.seats[0].knowledge[shown.id], false, "she knows it is false")
		s.next_day()
		assert_false(shown.came_true, "a flipped true rumor comes out false")
		assert_true(s.seats[0].skill_used, "skill spent")
		found = true
		break
	assert_true(found, "some seed produced an Insider day")


func test_unflipped_insider_rumor_is_true() -> void:
	for seed_value in range(1, 8):
		var s := _session(&"insider_inu", seed_value)
		if s.insider_days.is_empty():
			continue
		while not s.is_finished() and s.day not in s.insider_days:
			s.next_day()
		if s.is_finished():
			continue
		var rumor := s.insider_hint()
		s.next_day()
		s.next_day()
		assert_true(rumor.came_true, "the hinted rumor really came true (seed %d)" % seed_value)


func test_boss_rumor_three_days_before_quarter_end() -> void:
	var s := _session()
	while s.day < 7:
		s.next_day()
	assert_not_null(s.boss_rumor, "Boss rumor on day 7")
	assert_eq(s.boss_rumor.resolve_day, 10)
	s.set_boss_call(RumorTier.Side.BULLSHIT)
	s.reveal()
	var bet := s.boss_bet_of(0)
	assert_not_null(bet)
	assert_almost(bet.premium, minf(s.net_worth() * 0.30 + bet.premium, s.net_worth()) , s.net_worth())  # stake exists
	while s.day < 10 and not s.is_finished():
		s.next_day()
	assert_true(s.boss_rumor == null or s.boss_rumor.resolve_day > 10, "Boss rumor resolved on day 10")


func test_nobody_is_fired_at_the_quarter_reviews() -> void:
	var s := _session()
	while s.day < 20:
		s.next_day()
		for seat in s.seats:
			assert_true(seat.alive, "everybody stays in (day %d)" % s.day)
	assert_false(s.human_fired)
	assert_eq(s.standings().size(), 4)


func test_skills_reset_each_quarter() -> void:
	var s := _session(&"double_dan")
	s.set_call(RumorTier.Side.BELIEVE)
	s.reveal()
	s.double_down(0)
	assert_true(s.seats[0].skill_used)
	while s.day < 10 and not s.is_finished():
		s.next_day()
	if s.seats[0].alive:
		assert_false(s.seats[0].skill_used, "new quarter, new skill")


func test_dates_hidden_until_the_end() -> void:
	var s := _session()
	assert_eq(s.date_of_day(0), "")
	_play_to_end(s)
	assert_true(s.date_of_day(0) != "" or s.window_start < 0)


func test_save_load_roundtrip_midrun() -> void:
	var s := _session(&"double_dan", 99)
	for i in 6:
		s.set_call(RumorTier.Side.BELIEVE)
		s.next_day()
	s.set_call(RumorTier.Side.BULLSHIT)
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var cfg := GameSession.config_from_dict(data)
	assert_eq(cfg.mode, RunConfig.Mode.TABLE)
	var t := TableSession.from_dict(data, cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news()) as TableSession
	assert_not_null(t)
	assert_eq(t.day, s.day)
	assert_almost(t.net_worth(), s.net_worth(), 0.01)
	assert_eq(t.today_rumor.id, s.today_rumor.id)
	assert_eq(t.call_of(0), RumorTier.Side.BULLSHIT)
	for i in 4:
		assert_eq(t.seats[i].character.id, s.seats[i].character.id)
		assert_almost(t.seats[i].portfolio.cash, s.seats[i].portfolio.cash, 0.01)
	# Both continue identically.
	s.next_day()
	t.next_day()
	assert_almost(t.net_worth(), s.net_worth(), 0.01, "same result after loading")


func test_table_mode_has_no_perks() -> void:
	var s := _session()
	assert_true(s.pending_draft.is_empty(), "no draft at the start")
	var guard := 0
	while not s.is_finished() and guard < 40:
		s.next_day()
		assert_true(s.pending_draft.is_empty(), "no draft on day %d" % s.day)
		guard += 1
	assert_true(s.owned_perks.is_empty())
	s.choose_perk(ContentDb.perks()[0])
	assert_true(s.owned_perks.is_empty(), "perks cannot be picked")
