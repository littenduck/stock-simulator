extends TestCase
## Quantity box rules and the "type 10, click Buy, no Enter" fix. Everything here is autoload-free.


func test_parse_accepts_plain_integers_only() -> void:
	assert_eq(OrderEntry.parse("10"), 10)
	assert_eq(OrderEntry.parse(" 25 "), 25)
	assert_eq(OrderEntry.parse("1,000"), 1000)
	assert_eq(OrderEntry.parse("0"), 0)
	assert_eq(OrderEntry.parse(""), -1)
	assert_eq(OrderEntry.parse("abc"), -1)
	assert_eq(OrderEntry.parse("1.5"), -1)
	assert_eq(OrderEntry.parse("-3"), -1)
	assert_eq(OrderEntry.parse("10x"), -1)


func test_status_messages() -> void:
	assert_eq(OrderEntry.status("10", 50), OrderEntry.Status.OK)
	assert_eq(OrderEntry.status("", 50), OrderEntry.Status.EMPTY)
	assert_eq(OrderEntry.status("abc", 50), OrderEntry.Status.NOT_A_NUMBER)
	assert_eq(OrderEntry.status("0", 50), OrderEntry.Status.ZERO)
	assert_eq(OrderEntry.status("51", 50), OrderEntry.Status.OVER_MAX)
	assert_eq(OrderEntry.status("5", 0, true), OrderEntry.Status.NOTHING_TO_TRADE)
	assert_eq(OrderEntry.status("99999999", 50), OrderEntry.Status.TOO_BIG)
	assert_eq(OrderEntry.status("500", -1), OrderEntry.Status.OK, "unknown max never complains")


func test_hard_limit_blocks_but_soft_limit_only_warns() -> void:
	assert_false(OrderEntry.is_submittable(OrderEntry.Status.OVER_MAX, true))
	assert_true(OrderEntry.is_submittable(OrderEntry.Status.OVER_MAX, false))
	assert_false(OrderEntry.is_submittable(OrderEntry.Status.ZERO, false))
	assert_false(OrderEntry.is_submittable(OrderEntry.Status.NOT_A_NUMBER, false))
	assert_true(OrderEntry.is_submittable(OrderEntry.Status.OK, true))
	assert_ne_text(OrderEntry.message_key(OrderEntry.Status.OVER_MAX, true), OrderEntry.message_key(OrderEntry.Status.OVER_MAX, false))
	assert_eq(OrderEntry.message_key(OrderEntry.Status.OK, true), "")


func assert_ne_text(a: String, b: String) -> void:
	assert_true(a != b, "%s should differ from %s" % [a, b])


func test_quick_chips_math() -> void:
	assert_eq(OrderEntry.stepped("5", 1), 6)
	assert_eq(OrderEntry.stepped("5", 10), 15)
	assert_eq(OrderEntry.stepped("abc", 10), 10)
	assert_eq(OrderEntry.stepped("1", -1), 1, "never below one share")
	assert_eq(OrderEntry.fraction_of(80, 0.25), 20)
	assert_eq(OrderEntry.fraction_of(80, 0.5), 40)
	assert_eq(OrderEntry.fraction_of(80, 1.0), 80)
	assert_eq(OrderEntry.fraction_of(2, 0.25), 1, "at least one share")
	assert_eq(OrderEntry.fraction_of(0, 0.5), 1)


func test_typing_ten_then_buy_without_enter_orders_ten() -> void:
	var input := SharesInput.new()
	input.line_edit.text = "10"          # what typing does: the text changes, nobody presses Enter
	input.line_edit.text_changed.emit("10")
	assert_eq(input.shares(), 10, "box value is live")
	var order: Order = OrderEntry.build_order(Order.Dir.BUY, Order.Kind.MARKET, "NVDE", input.line_edit.text, 0.0)
	assert_not_null(order)
	assert_eq(order.shares, 10, "Buy right after typing orders 10 shares")
	assert_eq(order.side, Order.Dir.BUY)
	assert_eq(order.symbol, "NVDE")
	input.free()


func test_shares_reads_the_box_text_even_without_a_change_signal() -> void:
	# Even if no signal reached the panel, a Buy press reads the text itself.
	var input := SharesInput.new()
	input.line_edit.clear()
	input.line_edit.insert_text_at_caret("1")
	input.line_edit.insert_text_at_caret("0")
	assert_eq(input.line_edit.text, "10")
	assert_eq(input.shares(), 10)
	assert_true(input.is_submittable())
	input.free()


func test_shares_input_chips_steppers_and_validation() -> void:
	var input := SharesInput.new()
	input.max_shares = 80
	input.set_shares(10)
	assert_eq(input.shares(), 10)
	input._on_chip("plus1")
	assert_eq(input.shares(), 11)
	input._on_chip("plus10")
	assert_eq(input.shares(), 21)
	input._on_chip("pct25")
	assert_eq(input.shares(), 20)
	input._on_chip("pct50")
	assert_eq(input.shares(), 40)
	input._on_chip("max")
	assert_eq(input.shares(), 80)
	assert_true(input.is_submittable())
	input.line_edit.text = "81"
	input.line_edit.text_changed.emit("81")
	assert_false(input.is_submittable(), "above a hard max disables Buy")
	assert_true(input.get_node("ErrorLabel").text != "", "inline message shown")
	input.hard_limit = false
	assert_true(input.is_submittable(), "soft limit only warns")
	input.line_edit.text = "0"
	assert_false(input.is_submittable())
	input.line_edit.text = "abc"
	assert_false(input.is_submittable())
	assert_eq(input.shares(), -1)
	input.free()


func test_build_order_kinds_and_invalid_text() -> void:
	var limit: Order = OrderEntry.build_order(Order.Dir.SELL, Order.Kind.LIMIT, "AMB", "3", 12.5)
	assert_eq(limit.kind, Order.Kind.LIMIT)
	assert_almost(limit.trigger_price, 12.5)
	assert_eq(limit.shares, 3)
	var stop: Order = OrderEntry.build_order(Order.Dir.SELL, Order.Kind.STOP, "AMB", "3", 9.0)
	assert_eq(stop.kind, Order.Kind.STOP)
	assert_true(OrderEntry.build_order(Order.Dir.BUY, Order.Kind.MARKET, "AMB", "abc", 0.0) == null)
	assert_true(OrderEntry.build_order(Order.Dir.BUY, Order.Kind.MARKET, "AMB", "0", 0.0) == null)
	assert_true(OrderEntry.build_order(Order.Dir.BUY, Order.Kind.MARKET, "", "5", 0.0) == null)
