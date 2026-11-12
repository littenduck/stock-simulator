extends TestCase


func _setup() -> Array:
	return [TradingHelpers.market({"AAA": 100.0}), Portfolio.new(10000.0), RunModifiers.new(), OrderBook.new()]


func _run(a: Array) -> Array[TradeResult]:
	return a[3].process(a[0], a[1], a[2])


func test_limit_buy_triggers_at_or_below() -> void:
	var a := _setup()
	a[3].place(Order.limit(Order.Dir.BUY, "AAA", 10, 95.0))
	assert_eq(_run(a).size(), 0, "100 > 95")
	a[0].set_price("AAA", 95.0)
	var res := _run(a)
	assert_eq(res.size(), 1)
	assert_true(res[0].ok)
	assert_almost(res[0].price, 95.0)
	assert_eq(a[3].pending().size(), 0)


func test_limit_sell_triggers_at_or_above() -> void:
	var a := _setup()
	TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 10), a[0], a[1], a[2])
	a[3].place(Order.limit(Order.Dir.SELL, "AAA", 10, 110.0))
	assert_eq(_run(a).size(), 0)
	a[0].set_price("AAA", 111.0)
	assert_true(_run(a)[0].ok)
	assert_eq(a[1].shares_of("AAA"), 0)


func test_stop_sell_and_buy() -> void:
	var a := _setup()
	TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 10), a[0], a[1], a[2])
	a[3].place(Order.stop(Order.Dir.SELL, "AAA", 10, 90.0))
	assert_eq(_run(a).size(), 0)
	a[0].set_price("AAA", 90.0)
	assert_true(_run(a)[0].ok)
	var b := _setup()
	b[3].place(Order.stop(Order.Dir.BUY, "AAA", 5, 110.0))
	assert_eq(_run(b).size(), 0)
	b[0].set_price("AAA", 115.0)
	var res := _run(b)
	assert_true(res[0].ok)
	assert_almost(res[0].price, 115.0, 0.0001, "fills at close")


func test_stop_guard_no_fee_and_market_maker() -> void:
	var a := _setup()
	a[2].set_flag(&"stop_guard")
	a[3].place(Order.stop(Order.Dir.BUY, "AAA", 5, 90.0))
	var res := _run(a)
	assert_almost(res[0].fee, 0.0)
	var b := _setup()
	b[2].limit_price_improvement = 0.01
	b[3].place(Order.limit(Order.Dir.BUY, "AAA", 5, 105.0))
	res = _run(b)
	assert_almost(res[0].price, 99.0, 0.0001, "1% better for buyer")
	var c := _setup()
	c[2].limit_price_improvement = 0.01
	TradeService.execute(Order.market(Order.Dir.BUY, "AAA", 5), c[0], c[1], c[2])
	c[3].place(Order.limit(Order.Dir.SELL, "AAA", 5, 95.0))
	assert_almost(_run(c)[0].price, 101.0, 0.0001, "1% better for seller")


func test_void_when_cannot_afford() -> void:
	var a := _setup()
	a[1].cash = 100.0
	a[3].place(Order.limit(Order.Dir.BUY, "AAA", 50, 105.0))
	var res := _run(a)
	assert_false(res[0].ok)
	assert_eq(res[0].reason, TradeService.ERR_NOT_ENOUGH_CASH)
	assert_eq(a[3].pending().size(), 0, "voided order leaves the book")
	assert_eq(a[1].shares_of("AAA"), 0)


func test_id_order_determinism() -> void:
	var a := _setup()
	a[1].cash = 1100.0
	var id1: int = a[3].place(Order.limit(Order.Dir.BUY, "AAA", 10, 105.0))
	var id2: int = a[3].place(Order.limit(Order.Dir.BUY, "AAA", 10, 105.0))
	assert_true(id2 > id1)
	var res := _run(a)
	assert_eq(res.size(), 2)
	assert_eq(res[0].order.id, id1)
	assert_true(res[0].ok, "first by id gets the cash")
	assert_false(res[1].ok, "second is voided")


func test_cancel_and_round_trip() -> void:
	var a := _setup()
	var id: int = a[3].place(Order.stop(Order.Dir.SELL, "AAA", 3, 80.0))
	a[3].place(Order.limit(Order.Dir.BUY, "AAA", 2, 70.0))
	var other := OrderBook.new()
	other.load_dict(a[3].to_dict())
	assert_eq(other.pending().size(), 2)
	assert_eq(other.place(Order.limit(Order.Dir.BUY, "AAA", 1, 1.0)), 3, "next id kept")
	assert_true(a[3].cancel(id))
	assert_false(a[3].cancel(id))
	a[3].cancel_all()
	assert_eq(a[3].pending().size(), 0)
