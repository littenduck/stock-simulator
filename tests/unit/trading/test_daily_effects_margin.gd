extends TestCase


func _m() -> MarketSim:
	return TradingHelpers.market({"AAA": 100.0, "BBB": 50.0, "CCC": 20.0, "DDD": 10.0})


func test_negative_cash_interest() -> void:
	var p := Portfolio.new(-1000.0)
	var r := DailyEffects.apply(p, _m(), RunModifiers.new())
	assert_almost(r["interest"], -0.2)
	assert_almost(p.cash, -1000.2)


func test_positive_cash_interest() -> void:
	var mods := RunModifiers.new()
	mods.cash_interest_daily = 0.0005
	var p := Portfolio.new(1000.0)
	DailyEffects.apply(p, _m(), mods)
	assert_almost(p.cash, 1000.5)


func test_borrow_fee() -> void:
	var p := Portfolio.new(0.0)
	p.apply_fill("AAA", -10, 100.0, 0.0)  # cash 1000, short 1000
	var r := DailyEffects.apply(p, _m(), RunModifiers.new())
	assert_almost(r["borrow_fee"], 0.2)
	assert_almost(p.cash, 1000.0 + 1000.0 * 0.0 - 0.2 + r["interest"])


func test_dividends() -> void:
	var mods := RunModifiers.new()
	mods.long_dividend_daily = 0.0003
	mods.dividend_mult = 2.0
	var p := Portfolio.new(0.0)
	p.apply_fill("AAA", 10, 100.0, 0.0)
	p.cash = 0.0
	var r := DailyEffects.apply(p, _m(), mods)
	assert_almost(r["dividends"], 1000.0 * 0.0003 * 2.0)
	assert_almost(p.cash, r["dividends"])


func test_diversifier() -> void:
	var mods := RunModifiers.new()
	mods.set_flag(&"diversifier")
	var p := Portfolio.new(1000.0)
	p.apply_fill("AAA", 1, 100.0, 0.0)
	p.apply_fill("BBB", 1, 50.0, 0.0)
	p.apply_fill("CCC", 1, 20.0, 0.0)
	var m := _m()
	assert_almost(DailyEffects.apply(p, m, mods)["bonus"], 0.0, 0.0001, "3 holdings")
	p.apply_fill("DDD", -1, 10.0, 0.0)
	var eq := p.net_worth(m)
	var r := DailyEffects.apply(p, m, mods)
	assert_almost(r["bonus"], eq * 0.001, 0.0001, "4 distinct incl. shorts")


func _risky() -> Array:
	var m := _m()
	var p := Portfolio.new(1000.0)
	p.apply_fill("AAA", -20, 100.0, 0.0)  # cash 3000, short 2000: equity 1000, ratio 0.5
	var b := OrderBook.new()
	b.place(Order.limit(Order.Dir.BUY, "AAA", 1, 1.0))
	return [m, p, b, RunModifiers.new()]


func test_no_liquidation_when_healthy() -> void:
	var a := _risky()
	assert_false(Margin.check(a[1], a[0], a[2], a[3]))
	assert_eq(a[2].pending().size(), 1)
	assert_false(Margin.check(Portfolio.new(10.0), a[0], a[2], a[3]), "no exposure")


func test_liquidation_below_threshold() -> void:
	var a := _risky()
	a[0].set_price("AAA", 120.0)  # short 2400, equity 600, ratio 0.25 < 0.30
	assert_true(Margin.check(a[1], a[0], a[2], a[3]))
	assert_true(a[1].positions.is_empty())
	assert_eq(a[2].pending().size(), 0, "orders cancelled")
	assert_almost(a[1].cash, 600.0)


func test_exact_threshold_not_liquidated() -> void:
	var a := _risky()
	a[3].maintenance_margin = 0.5
	assert_false(Margin.check(a[1], a[0], a[2], a[3]))


func test_iron_hands_once() -> void:
	var a := _risky()
	a[3].set_flag(&"iron_hands")
	a[0].set_price("AAA", 120.0)
	assert_false(Margin.check(a[1], a[0], a[2], a[3]), "spared once")
	assert_true(a[3].iron_hands_used)
	assert_eq(a[1].shares_of("AAA"), -20)
	assert_true(Margin.check(a[1], a[0], a[2], a[3]), "second time liquidates")
