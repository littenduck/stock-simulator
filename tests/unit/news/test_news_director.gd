extends TestCase


func _company(symbol: String, sector: String) -> CompanyDef:
	var c := CompanyDef.new()
	c.symbol = symbol
	c.sector = sector
	return c


func _market(rng: RandomNumberGenerator) -> MarketSim:
	return MarketSim.new([_company("AAA", "tech"), _company("BBB", "space")], GbmPriceModel.new(), rng)


func _event(id: String, sector: String, symbol := "", chance := 1.0, truth := 0.6) -> NewsEventDef:
	var e := NewsEventDef.new()
	e.id = id
	e.headline_key = "NEWS_" + id
	e.target_sector = sector
	e.target_symbol = symbol
	e.daily_chance = chance
	e.truth_chance = truth
	e.cooldown_days = 10
	return e


func _setup(pool: Array[NewsEventDef], seed_value := 1) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return [NewsDirector.new(pool, rng), _market(rng), rng]


func test_roll_creates_pending_rumor() -> void:
	var s := _setup([_event("a", "tech")] as Array[NewsEventDef])
	var d: NewsDirector = s[0]
	var out := d.roll(1, RunModifiers.new(), s[1])
	assert_eq(out.size(), 1)
	assert_eq(d.pending().size(), 1)
	var r := out[0]
	assert_eq(r.posted_day, 1)
	assert_true(r.reveal_day >= 2 and r.reveal_day <= 4, "delay 1..3")
	assert_true(r.shown_credibility >= 0.05 and r.shown_credibility <= 0.95)
	assert_false(r.resolved)


func test_due_resolves_and_removes() -> void:
	var s := _setup([_event("a", "tech")] as Array[NewsEventDef])
	var d: NewsDirector = s[0]
	var r: Rumor = d.roll(1, RunModifiers.new(), s[1])[0]
	assert_eq(d.due(r.reveal_day - 1).size(), 0)
	var due := d.due(r.reveal_day)
	assert_eq(due.size(), 1)
	assert_true(due[0].resolved)
	assert_eq(d.pending().size(), 0)
	assert_eq(d.due(r.reveal_day).size(), 0, "only once")


func test_cooldown_and_min_day() -> void:
	var e := _event("a", "tech")
	e.min_day = 5
	var s := _setup([e] as Array[NewsEventDef])
	var d: NewsDirector = s[0]
	var mods := RunModifiers.new()
	assert_eq(d.roll(4, mods, s[1]).size(), 0, "before min_day")
	assert_eq(d.roll(5, mods, s[1]).size(), 1)
	assert_eq(d.roll(6, mods, s[1]).size(), 0, "cooldown")
	assert_eq(d.roll(14, mods, s[1]).size(), 0, "cooldown until day 15")
	assert_eq(d.roll(15, mods, s[1]).size(), 1)


func test_only_targets_present_in_market() -> void:
	var pool: Array[NewsEventDef] = [
		_event("consumer", "consumer"),
		_event("sym", "tech", "ZZZZ"),
		_event("ok_sym", "tech", "BBB"),
	]
	var s := _setup(pool)
	var d: NewsDirector = s[0]
	var out := d.roll(1, RunModifiers.new(), s[1])
	assert_eq(out.size(), 1)
	assert_eq(out[0].event.id, "ok_sym")
	assert_eq(out[0].target_symbol, "BBB")
	d.roll(20, RunModifiers.new(), s[1])
	for r in d.pending():
		assert_true(r.event.id != "consumer" and r.event.id != "sym")


func test_market_wide_always_eligible() -> void:
	var s := _setup([_event("all", "all")] as Array[NewsEventDef])
	assert_eq((s[0] as NewsDirector).roll(1, RunModifiers.new(), s[1]).size(), 1)
	assert_eq((s[0].pending()[0] as Rumor).target_symbol, "")


func test_max_per_day_and_fairness() -> void:
	var pool: Array[NewsEventDef] = [_event("a", "tech"), _event("b", "tech"), _event("c", "tech")]
	var counts := {"a": 0, "b": 0, "c": 0}
	for seed_value in 300:
		var s := _setup(pool, seed_value)
		var out: Array[Rumor] = (s[0] as NewsDirector).roll(1, RunModifiers.new(), s[1])
		assert_eq(out.size(), NewsDirector.MAX_PER_DAY)
		counts[out[0].event.id] += 1
	for k in counts:
		assert_true(counts[k] > 60, "event %s picked %d of 300" % [k, counts[k]])


func test_same_seed_same_rumors() -> void:
	var pool: Array[NewsEventDef] = [_event("a", "tech", "", 0.5), _event("b", "space", "", 0.5)]
	var logs: Array = []
	for i in 2:
		var s := _setup(pool, 42)
		var log: Array = []
		for day in range(1, 40):
			for r in (s[0] as NewsDirector).roll(day, RunModifiers.new(), s[1]):
				log.append([day, r.event.id, r.is_true, r.reveal_day, r.shown_credibility])
		logs.append(log)
	assert_true(logs[0].size() > 3)
	assert_eq(logs[0], logs[1])


func test_truth_statistics() -> void:
	var e := _event("a", "tech", "", 1.0, 0.7)
	e.cooldown_days = 0
	var s := _setup([e] as Array[NewsEventDef], 11)
	var d: NewsDirector = s[0]
	var truths := 0
	var cred_sum := 0.0
	var n := 2000
	for day in n:
		var r: Rumor = d.roll(day, RunModifiers.new(), s[1])[0]
		truths += 1 if r.is_true else 0
		cred_sum += r.shown_credibility
	assert_almost(float(truths) / n, 0.7, 0.04, "truth rate")
	assert_almost(cred_sum / n, 0.7, 0.03, "mean shown credibility")


func test_truth_bonuses() -> void:
	var e := _event("a", "tech", "", 1.0, 0.5)
	var mods := RunModifiers.new()
	var s := _setup([e] as Array[NewsEventDef])
	assert_almost(NewsDirector.truth_probability(e, mods, s[1]), 0.5)
	mods.rumor_truth_bonus = -0.1
	mods.sector_truth_bonus = {"tech": 0.15, "space": 0.15}
	assert_almost(NewsDirector.truth_probability(e, mods, s[1]), 0.55)
	var single := _event("b", "space", "AAA", 1.0, 0.98)
	mods.rumor_truth_bonus = 0.0
	assert_almost(NewsDirector.truth_probability(single, mods, s[1]), 1.0, 0.0001, "clamped, uses tech sector of AAA")
	var d := _event("c", "all", "", 1.0, 0.5)
	assert_almost(NewsDirector.truth_probability(d, mods, s[1]), 0.5, 0.0001, "no sector bonus for market-wide")


func test_sector_bonus_changes_rate() -> void:
	var e := _event("a", "tech", "", 1.0, 0.4)
	e.cooldown_days = 0
	var s := _setup([e] as Array[NewsEventDef], 5)
	var mods := RunModifiers.new()
	mods.sector_truth_bonus = {"tech": 0.15}
	var truths := 0
	for day in 1500:
		truths += 1 if (s[0] as NewsDirector).roll(day, mods, s[1])[0].is_true else 0
	assert_almost(float(truths) / 1500.0, 0.55, 0.04)


func test_early_bird_lead_days() -> void:
	var s := _setup([_event("a", "tech")] as Array[NewsEventDef], 9)
	var s2 := _setup([_event("a", "tech")] as Array[NewsEventDef], 9)
	var mods := RunModifiers.new()
	mods.rumor_lead_days = 1
	var plain: Rumor = (s[0] as NewsDirector).roll(1, RunModifiers.new(), s[1])[0]
	var early: Rumor = (s2[0] as NewsDirector).roll(1, mods, s2[1])[0]
	assert_eq(early.reveal_day, plain.reveal_day + 1)
	assert_eq(early.is_true, plain.is_true, "perk does not change the draw order")


func test_fact_checker_range_contains_truth_probability() -> void:
	var e := _event("a", "tech", "", 1.0, 0.6)
	e.cooldown_days = 0
	var s := _setup([e] as Array[NewsEventDef])
	var mods := RunModifiers.new()
	mods.set_flag(&"fact_checker")
	for day in 50:
		var r: Rumor = (s[0] as NewsDirector).roll(day, mods, s[1])[0]
		assert_true(r.credibility_low <= 0.6 and r.credibility_high >= 0.6)
		assert_true(r.credibility_high - r.credibility_low <= 0.2001)
	var plain: Rumor = (s[0] as NewsDirector).roll(100, RunModifiers.new(), s[1])[0]
	assert_eq(plain.credibility_low, 0.0)
	assert_eq(plain.credibility_high, 1.0)


func test_insider_friend_guarantees_true_every_ten_days() -> void:
	var e := _event("a", "tech", "", 0.05, 0.0)    # truth 0: only the perk can make it true
	e.cooldown_days = 0
	var s := _setup([e] as Array[NewsEventDef], 3)
	var d: NewsDirector = s[0]
	var mods := RunModifiers.new()
	mods.set_flag(&"insider_friend")
	var guaranteed_days: Array[int] = []
	for day in range(1, 61):
		for r in d.roll(day, mods, s[1]):
			if r.is_guaranteed:
				guaranteed_days.append(day)
				assert_true(r.is_true)
			else:
				assert_false(r.is_true)
	assert_eq(guaranteed_days.size(), 6, "one per 10 days")
	for i in range(1, guaranteed_days.size()):
		assert_true(guaranteed_days[i] - guaranteed_days[i - 1] >= 10)
	# without the perk nothing is guaranteed
	var s2 := _setup([e] as Array[NewsEventDef], 3)
	for day in range(1, 61):
		for r in (s2[0] as NewsDirector).roll(day, RunModifiers.new(), s2[1]):
			assert_false(r.is_guaranteed)


func test_save_load_roundtrip() -> void:
	var pool: Array[NewsEventDef] = [_event("a", "tech", "", 0.5), _event("b", "space", "", 0.5)]
	var s := _setup(pool, 21)
	var d: NewsDirector = s[0]
	for day in range(1, 12):
		d.roll(day, RunModifiers.new(), s[1])
	var data: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	var d2 := NewsDirector.new(pool, RandomNumberGenerator.new())
	d2.load_dict(data)
	assert_eq(d2.pending().size(), d.pending().size())
	for i in d.pending().size():
		var a: Dictionary = d2.pending()[i].to_dict()
		var b: Dictionary = d.pending()[i].to_dict()
		for k in b:
			if b[k] is float:
				assert_almost(a[k], b[k], 0.000001, k)
			else:
				assert_eq(a[k], b[k], k)
	assert_eq(d2.to_dict()["cooldowns"], d.to_dict()["cooldowns"])
	assert_eq(d2.to_dict()["last_insider_day"], d.to_dict()["last_insider_day"])


func test_any_symbol_template_picks_stock_of_sector() -> void:
	var tpl := _event("pick", "tech", NewsDirector.ANY_SYMBOL)
	tpl.cooldown_days = 0
	var companies: Array[CompanyDef] = [_company("AAA", "tech"), _company("BBB", "tech"), _company("CCC", "space")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var market := MarketSim.new(companies, GbmPriceModel.new(), rng)
	var d := NewsDirector.new([tpl] as Array[NewsEventDef], rng)
	var seen := {}
	for day in 100:
		var r: Rumor = d.roll(day, RunModifiers.new(), market)[0]
		assert_true(r.target_symbol in ["AAA", "BBB"], "symbol of the sector")
		assert_eq(r.event.target_symbol, r.target_symbol, "event copy carries the symbol")
		assert_eq(tpl.target_symbol, NewsDirector.ANY_SYMBOL, "template untouched")
		seen[r.target_symbol] = true
	assert_eq(seen.size(), 2, "both stocks get picked")
	# no stock of the sector in the market => never eligible
	var only_space := MarketSim.new([_company("CCC", "space")] as Array[CompanyDef], GbmPriceModel.new(), rng)
	assert_eq(NewsDirector.new([tpl] as Array[NewsEventDef], rng).roll(1, RunModifiers.new(), only_space).size(), 0)


func test_any_symbol_survives_save_load_and_hits_only_that_stock() -> void:
	var tpl := _event("pick", "tech", NewsDirector.ANY_SYMBOL)
	tpl.total_impact = 0.2
	tpl.duration_days = 1
	var companies: Array[CompanyDef] = [_company("AAA", "tech"), _company("BBB", "tech")]
	for c in companies:
		c.start_price = 100.0
		c.annual_volatility = 0.0001
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var market := MarketSim.new(companies, GbmPriceModel.new(), rng)
	var d := NewsDirector.new([tpl] as Array[NewsEventDef], rng)
	var r: Rumor = d.roll(1, RunModifiers.new(), market)[0]
	var d2 := NewsDirector.new([tpl] as Array[NewsEventDef], rng)
	d2.load_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	var loaded := d2.pending()[0]
	assert_eq(loaded.target_symbol, r.target_symbol)
	market.apply_news(loaded.event, 1.0)
	market.step()
	var other := "BBB" if r.target_symbol == "AAA" else "AAA"
	assert_almost(market.price_of(r.target_symbol), 120.0, 0.5)
	assert_almost(market.price_of(other), 100.0, 0.5)
