extends TestCase


func _mk() -> MarketSim:
	return TradingHelpers.market({"AAA": 100.0, "BBB": 50.0})


func test_buy_sell_bookkeeping() -> void:
	var m := _mk()
	var p := Portfolio.new(10000.0)
	p.apply_fill("AAA", 10, 100.0, 1.0)
	assert_almost(p.cash, 8999.0)
	assert_eq(p.shares_of("AAA"), 10)
	p.apply_fill("AAA", 10, 120.0, 0.0)
	assert_almost(p.positions["AAA"]["avg_cost"], 110.0)
	p.apply_fill("AAA", -5, 130.0, 0.0)
	assert_almost(p.positions["AAA"]["avg_cost"], 110.0, 0.0001, "avg unchanged on reduce")
	p.apply_fill("AAA", -15, 100.0, 0.0)
	assert_false(p.positions.has("AAA"), "removed at zero")
	assert_eq(p.shares_of("ZZZ"), 0)


func test_short_and_flip() -> void:
	var p := Portfolio.new(1000.0)
	p.apply_fill("AAA", -10, 100.0, 0.0)
	assert_eq(p.shares_of("AAA"), -10)
	assert_almost(p.cash, 2000.0)
	p.apply_fill("AAA", -5, 80.0, 0.0)
	assert_almost(p.positions["AAA"]["avg_cost"], (100.0 * 10 + 80.0 * 5) / 15.0)
	p.apply_fill("AAA", 20, 90.0, 0.0)
	assert_eq(p.shares_of("AAA"), 5)
	assert_almost(p.positions["AAA"]["avg_cost"], 90.0, 0.0001, "flip uses fill price")


func test_valuation() -> void:
	var m := _mk()
	var p := Portfolio.new(1000.0)
	p.apply_fill("AAA", 10, 100.0, 0.0)  # long 1000, cash 0
	p.apply_fill("BBB", -20, 50.0, 0.0)  # short 1000, cash 1000
	assert_almost(p.long_value(m), 1000.0)
	assert_almost(p.short_value(m), 1000.0)
	assert_almost(p.net_worth(m), 1000.0)
	assert_almost(p.gross_exposure(m), 2000.0)
	m.set_price("BBB", 60.0)
	assert_almost(p.net_worth(m), 800.0)


func test_liquidate_all() -> void:
	var m := _mk()
	var p := Portfolio.new(1000.0)
	p.apply_fill("AAA", 5, 100.0, 0.0)
	p.apply_fill("BBB", -10, 50.0, 0.0)
	var nw := p.net_worth(m)
	p.liquidate_all(m)
	assert_true(p.positions.is_empty())
	assert_almost(p.cash, nw)


func test_round_trip() -> void:
	var p := Portfolio.new(500.0)
	p.apply_fill("AAA", 3, 100.0, 0.5)
	p.apply_fill("BBB", -4, 50.0, 0.0)
	var q := Portfolio.new()
	q.load_dict(p.to_dict())
	assert_almost(q.cash, p.cash)
	assert_eq(q.shares_of("AAA"), 3)
	assert_eq(q.shares_of("BBB"), -4)
	assert_almost(q.positions["AAA"]["avg_cost"], 100.0)
