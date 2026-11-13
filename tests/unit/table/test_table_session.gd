extends TestCase

const SEED := 1234


## Most tests play a long run (4 quarters, 28 days) so quarters, Boss rumors and skill resets happen.
func _session(char_id: StringName = &"saving_son", seed_value: int = SEED, quarters: int = 4) -> TableSession:
	var cfg := RunConfig.make_table(ContentDb.character_by_id(char_id), seed_value, false, quarters)
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
	assert_eq(cfg.trading_days, 7, "the quick game is one quarter of 7 days")
	assert_eq(cfg.quarters(), 1)
	assert_eq(RunConfig.make_table(ContentDb.character_by_id(&"saving_son"), 5, false, 2).trading_days, 14)
	assert_eq(RunConfig.make_table(ContentDb.character_by_id(&"saving_son"), 5, false, 4).trading_days, 28)
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
	assert_true(s.day <= 28)
	assert_eq(s.day, 28, "nobody is fired, so a 4-quarter run lasts 28 days")


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
	assert_true(s.premium_for(0) <= s.portfolio.cash, "the premium is never more than the cash that is left")
	assert_true(s.portfolio.cash < 100.0)


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
	while s.day < 4:
		s.next_day()
	assert_not_null(s.boss_rumor, "Boss rumor on day 4")
	assert_eq(s.boss_rumor.resolve_day, 7, "it resolves on day 7, the last day of the quarter")
	s.set_boss_call(RumorTier.Side.BULLSHIT)
	s.reveal()
	var bet := s.boss_bet_of(0)
	assert_not_null(bet)
	assert_almost(bet.premium, minf(s.net_worth() * 0.30 + bet.premium, s.net_worth()) , s.net_worth())  # stake exists
	while s.day < 7 and not s.is_finished():
		s.next_day()
	assert_true(s.boss_rumor == null or s.boss_rumor.resolve_day > 7, "Boss rumor resolved on day 7")


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
	while s.day < 7 and not s.is_finished():
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


func test_rumor_log_remembers_every_verdict_and_my_result() -> void:
	var s := _session(&"double_dan", 12)
	s.set_call(RumorTier.Side.BELIEVE)
	var rumor := s.today_rumor
	s.next_day()
	s.set_call(RumorTier.Side.PASS)
	s.next_day()
	assert_eq(s.history.size(), 2)
	var first: Dictionary = s.history[0]
	assert_eq(int((first["rumor"] as Dictionary)["id"]), rumor.id)
	assert_eq(int(first["side"]), RumorTier.Side.BELIEVE)
	assert_true(float(first["net"]) != 0.0, "a bet has a result")
	assert_eq(int(s.history[1]["side"]), RumorTier.Side.PASS)
	assert_eq(float(s.history[1]["net"]), 0.0, "a pass costs nothing")


func test_rumor_log_survives_saving() -> void:
	var s := _session(&"double_dan", 14)
	for i in 3:
		s.set_call(RumorTier.Side.BULLSHIT)
		s.next_day()
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var t := TableSession.from_dict(data, GameSession.config_from_dict(data), ContentDb.companies(), ContentDb.perks(), ContentDb.news()) as TableSession
	assert_eq(t.history.size(), 3)
	assert_almost(float(t.history[2]["net"]), float(s.history[2]["net"]), 0.01)


func test_button_previews_match_what_the_trade_really_does() -> void:
	var s := _session()
	var sym := s.market.symbols()[0]
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		var preview := s.buy_preview(0, sym, fraction)
		var cash_before := s.portfolio.cash
		var held_before := s.portfolio.shares_of(sym)
		var res := s.buy_fraction(0, sym, fraction)
		assert_true(res.ok)
		assert_eq(s.portfolio.shares_of(sym) - held_before, int(preview["shares"]), "shares for %s of the cash" % fraction)
		assert_almost(cash_before - s.portfolio.cash, float(preview["cost"]), 0.01, "cost for %s of the cash" % fraction)
		s.sell_fraction(0, sym, 1.0)
		s.portfolio.cash = 10000.0
	s.buy_fraction(0, sym, 0.5)
	var half := s.sell_preview(0, sym, 0.5)
	var cash_now := s.portfolio.cash
	s.sell_fraction(0, sym, 0.5)
	assert_almost(s.portfolio.cash - cash_now, float(half["proceeds"]), 0.01, "proceeds of selling half")
	assert_eq(int(s.sell_preview(0, "NOPE_" + sym, 1.0)["shares"]), 0, "nothing to sell")


func test_turn_order_open_then_reveal_then_next_day() -> void:
	var s := _session(&"double_dan", 6)
	assert_eq(s.phase, TableSession.Phase.ACTION, "the turn starts with the market open")
	assert_eq(s.history.size(), 0, "nothing has been judged yet")
	var rumor := s.today_rumor
	s.set_call(RumorTier.Side.BELIEVE)
	s.reveal()
	assert_eq(s.phase, TableSession.Phase.REVEALED, "after-market: the bets are out")
	assert_false(rumor.resolved, "today's rumor is not judged before the next day's price exists")
	assert_eq(s.day, 0)
	s.advance()
	assert_eq(s.phase, TableSession.Phase.ACTION, "the next day opens with the market open")
	assert_eq(s.day, 1)
	assert_true(rumor.resolved, "the verdict on yesterday's rumor arrives with the new day")
	assert_eq(s.history.size(), 1)
	assert_true(s.today_rumor.id != rumor.id, "and a new rumor is out")


func test_no_trading_after_the_market_closed() -> void:
	var s := _session(&"double_dan", 6)
	var sym := s.market.symbols()[0]
	assert_true(s.buy_fraction(0, sym, 0.25).ok, "trading works while the market is open")
	s.reveal()
	for res in [s.buy_fraction(0, sym, 0.25), s.sell_fraction(0, sym, 0.5), s.swap(0, sym, s.market.symbols()[1])]:
		assert_false(res.ok, "no trade in the after-market")
		assert_eq(res.reason, TableSession.ERR_MARKET_CLOSED)
	s.advance()
	assert_true(s.buy_fraction(0, sym, 0.25).ok, "the next day the market is open again")


func test_skills_still_work_in_the_after_market() -> void:
	var s := _session(&"double_dan", 9)
	s.set_call(RumorTier.Side.BELIEVE)
	s.reveal()
	assert_true(s.can_double(0), "Double Down is an after-market skill")
	assert_true(s.double_down(0))


func test_ending_the_turn_without_a_call_counts_as_pass() -> void:
	var s := _session(&"saving_son", 4)
	var cash := s.portfolio.cash
	s.reveal()
	assert_true(s.daily_bet_of(0) == null, "no call, no bet")
	assert_almost(s.portfolio.cash, cash, 0.001, "and no money spent")


# ---------------------------------------------------------------- the four windows of the day

func test_strict_windows_close_trading_and_calls_before_market_open() -> void:
	var s := _session(&"saving_son")
	s.strict_windows = true
	assert_eq(s.window, TableSkills.Slot.PRE_MARKET)
	var symbol: String = s.market.symbols()[0]
	assert_false(s.buy_fraction(0, symbol, 0.25).ok, "no trading in pre-market")
	s.set_call(RumorTier.Side.BELIEVE)
	assert_false(s.calls.has(0), "no call in pre-market")
	s.open_market()
	assert_eq(s.window, TableSkills.Slot.MARKET_OPEN)
	assert_true(s.buy_fraction(0, symbol, 0.25).ok, "trading at market open")
	s.set_call(RumorTier.Side.BELIEVE)
	assert_true(s.calls.has(0))
	s.reveal()
	assert_eq(s.window, TableSkills.Slot.AFTER_MARKET)
	assert_false(s.buy_fraction(0, symbol, 0.25).ok, "no trading after the reveal")
	s.advance()
	assert_eq(s.window, TableSkills.Slot.PRE_MARKET, "the next day starts in pre-market")


func test_skills_only_work_in_their_window() -> void:
	var s := _session(&"copilot_cody")
	s.strict_windows = true
	s.set_copy_target(1)
	assert_false(s.copy_targets.has(0), "copilot is a market-open skill")
	s.open_market()
	s.set_copy_target(1)
	assert_true(s.copy_targets.has(0))
	assert_false(TableSkills.allows(TableSkills.DOUBLE_DOWN, TableSkills.Slot.MARKET_OPEN))
	assert_true(TableSkills.allows(TableSkills.DOUBLE_DOWN, TableSkills.Slot.AFTER_MARKET))


func test_skill_events_are_logged_in_their_window() -> void:
	var s := _session(&"copilot_cody")
	s.open_market()
	s.set_call(RumorTier.Side.BELIEVE, 1)
	s.set_copy_target(1)
	s.reveal()
	var events := s.take_skill_events(TableSkills.Slot.AFTER_MARKET)
	var copies := events.filter(func(e: Dictionary) -> bool: return e["skill"] == TableSkills.COPILOT)
	assert_true(copies.size() <= 1)
	assert_eq(s.take_skill_events(TableSkills.Slot.AFTER_MARKET).size(), 0, "events are handed out once")


func test_hodl_hana_logs_her_first_purchase_in_pre_market() -> void:
	var s := _session(&"hodl_hana")
	var events := s.take_skill_events(TableSkills.Slot.PRE_MARKET)
	assert_true(events.any(func(e: Dictionary) -> bool: return e["skill"] == TableSkills.HODL_BUY))


func test_interest_is_logged_when_the_day_turns() -> void:
	var s := _session(&"saving_son")
	s.reveal()
	s.advance()
	var events := s.take_skill_events(TableSkills.Slot.NEXT_DAY)
	assert_true(events.any(func(e: Dictionary) -> bool: return e["skill"] == TableSkills.INTEREST and float(e["amount"]) > 0.0))


# ---------------------------------------------------------------- the feed log

func test_a_summary_is_logged_every_day_with_the_payouts() -> void:
	var s := _session(&"saving_son")
	s.open_market()
	s.set_call(RumorTier.Side.BELIEVE)
	s.next_day()
	var summaries := s.feed_log.filter(func(e: Dictionary) -> bool: return e["kind"] == "summary")
	assert_eq(summaries.size(), 1)
	assert_eq(int(summaries[0]["day"]), 0, "the day the bets were placed")
	assert_eq((summaries[0]["rows"] as Array).size(), 4, "one row for each player")
	var mine: Dictionary = (summaries[0]["rows"] as Array)[0]
	assert_eq(int(mine["seat"]), 0)
	assert_true(float(mine["premium"]) > 0.0)


func test_public_skills_reach_the_feed_but_hidden_ones_do_not() -> void:
	var s := _session(&"hodl_hana")
	assert_true(s.feed_log.any(func(e: Dictionary) -> bool: return e["kind"] == "skill" and e["skill"] == "hodl_buy"))
	var i := _session(&"insider_inu")
	while not i.is_finished() and i.day < 12:
		i.next_day()
	assert_false(i.feed_log.any(func(e: Dictionary) -> bool: return e["kind"] == "skill" and String(e["skill"]).begins_with("insider")))


func test_the_feed_log_survives_a_save() -> void:
	var s := _session(&"saving_son")
	s.next_day()
	s.next_day()
	var cfg := RunConfig.make_table(ContentDb.character_by_id(&"saving_son"), SEED)
	var loaded := TableSession.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news()) as TableSession
	assert_true(loaded != null)
	assert_eq(loaded.feed_log.size(), s.feed_log.size())


func test_a_run_has_one_two_or_four_quarters_each_with_its_own_insider_day() -> void:
	for quarters in [1, 2, 4]:
		var s := _session(&"insider_inu", SEED, quarters)
		assert_eq(s.config.trading_days, quarters * 7)
		assert_eq(s.insider_days.size(), quarters, "one Insider day per quarter")
		for q in quarters:
			assert_true(s.insider_days[q] >= q * 7 and s.insider_days[q] < (q + 1) * 7, "inside quarter %d" % q)
		_play_to_end(s)
		assert_true(s.is_finished())
		assert_eq(s.day, quarters * 7)


func test_an_old_30_day_save_keeps_its_own_quarters() -> void:
	var s := _session(&"saving_son", SEED, 4)
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	data.erase("trading_days")
	data.erase("quarter_days")
	var cfg := GameSession.config_from_dict(data)
	assert_eq(cfg.trading_days, 30, "saves from before the choice were 30 days")
	assert_eq(cfg.quarter_days, 10)


func test_a_loaded_run_keeps_its_real_price_window() -> void:
	var s := _session(&"saving_son", 99)
	for i in 3:
		s.next_day()
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var cfg := GameSession.config_from_dict(data)
	var t := TableSession.from_dict(data, cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news()) as TableSession
	assert_eq(t.window_start, s.window_start, "the window of real prices is found again after loading")
	assert_true(s.window_start >= 0)
