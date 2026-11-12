extends TestCase


func _setup(cash: float = 10000.0) -> Array:
	return [TradingHelpers.market({"AAA": 100.0, "BBB": 50.0}), Portfolio.new(cash), RunModifiers.new()]


func test_buy_and_sell() -> void:
	var a := _setup()
	var r := TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 10), a[0], a[1], a[2])
	assert_true(r.ok)
	assert_almost(r.fee, 1.0, 0.0001, "0.1% of 1000")
	assert_almost(a[1].cash, 10000.0 - 1000.0 - 1.0)
	assert_eq(a[1].shares_of("AAA"), 10)
	r = TradeService.execute(Order.market(Order.Dir.SELL, "AAA", 10), a[0], a[1], a[2])
	assert_true(r.ok)
	assert_eq(a[1].shares_of("AAA"), 0)


func test_invalid_and_unknown() -> void:
	var a := _setup()
	assert_eq(TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 0), a[0], a[1], a[2]).reason, TradeService.ERR_INVALID_SHARES)
	assert_eq(TradeService.execute(Order.market(Order.Dir.BUY, "ZZZ", 1), a[0], a[1], a[2]).reason, TradeService.ERR_UNKNOWN_SYMBOL)


func test_not_enough_cash_without_leverage() -> void:
	var a := _setup(500.0)
	var r := TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 10), a[0], a[1], a[2])
	assert_false(r.ok)
	assert_eq(r.reason, TradeService.ERR_NOT_ENOUGH_CASH)
	assert_almost(a[1].cash, 500.0, 0.0001, "unchanged on failure")


func test_open_and_cover_short() -> void:
	var a := _setup()
	var r := TradeService.execute(Order.market(Order.Dir.SELL, "AAA", 50), a[0], a[1], a[2])
	assert_true(r.ok, "short 5000 vs equity 10000")
	assert_eq(a[1].shares_of("AAA"), -50)
	a[0].set_price("AAA", 90.0)
	r = TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 50), a[0], a[1], a[2])
	assert_true(r.ok)
	assert_eq(a[1].shares_of("AAA"), 0)
	assert_true(a[1].cash > 10000.0, "profit on short")


func test_over_leverage_rejected() -> void:
	var a := _setup()
	var r := TradeService.execute(Order.market(Order.Dir.SELL, "AAA", 150), a[0], a[1], a[2])
	assert_false(r.ok)
	assert_eq(r.reason, TradeService.ERR_OVER_LEVERAGE)
	assert_eq(a[1].shares_of("AAA"), 0)
	a[2].max_leverage = 2.0
	r = TradeService.execute(Order.market(Order.Dir.SELL, "AAA", 150), a[0], a[1], a[2])
	assert_true(r.ok, "leverage 2 allows it")


func test_leverage_buy_uses_negative_cash() -> void:
	var a := _setup()
	a[2].max_leverage = 2.0
	var r := TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 150), a[0], a[1], a[2])
	assert_true(r.ok)
	assert_true(a[1].cash < 0.0)
	r = TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 100), a[0], a[1], a[2])
	assert_false(r.ok)
	assert_eq(r.reason, TradeService.ERR_OVER_LEVERAGE)


func test_short_disabled() -> void:
	var a := _setup()
	a[2].can_short = false
	var r := TradeService.execute(Order.market(Order.Dir.SELL, "AAA", 1), a[0], a[1], a[2])
	assert_false(r.ok)
	assert_eq(r.reason, TradeService.ERR_SHORT_DISABLED)
	TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 5), a[0], a[1], a[2])
	r = TradeService.execute(Order.market(Order.Dir.SELL, "AAA", 5), a[0], a[1], a[2])
	assert_true(r.ok, "selling held shares still fine")
	r = TradeService.execute(Order.market(Order.Dir.SELL, "AAA", 6), a[0], a[1], a[2])
	assert_false(r.ok)


func test_fee_uses_mods() -> void:
	var a := _setup()
	a[2].fee_mult = 0.0
	var r := TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 10), a[0], a[1], a[2])
	assert_almost(r.fee, 0.0)
