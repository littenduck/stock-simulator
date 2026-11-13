## The status line under the Buy button describes the last action only: editing the ticket clears it.
extends TestCase


func _panel() -> GameOrderPanel:
	var panel := GameOrderPanel.new()
	panel._ready()  # not in a tree: builds the children, _refresh() returns early without a session
	return panel


func _stale(panel: GameOrderPanel) -> void:
	panel._set_status("Exceeds your maximum leverage", Color.RED)
	assert_eq(panel._status.text, "Exceeds your maximum leverage", "precondition")


func test_side_change_clears_status() -> void:
	var p := _panel()
	_stale(p)
	p._on_sell_toggled(true)
	assert_eq(p._status.text, "", "sell")
	_stale(p)
	p._on_buy_toggled(true)
	assert_eq(p._status.text, "", "buy")
	p.free()


func test_shares_kind_and_symbol_change_clear_status() -> void:
	var p := _panel()
	_stale(p)
	p._shares.line_edit.text = "5"
	p._shares._on_text_changed("5")
	assert_eq(p._status.text, "", "shares")
	_stale(p)
	p._on_kind_selected(1)
	assert_eq(p._status.text, "", "kind")
	_stale(p)
	p.symbol = "ABC"
	assert_eq(p._status.text, "", "symbol")
	p.free()


func test_success_message_replaces_stale_error() -> void:
	var p := _panel()
	_stale(p)
	var o := Order.market(Order.Dir.BUY, "ABC", 1)
	p._report_fill(TradeResult.success(o, 10.0, 0.1))
	assert_true(p._status.text.length() > 0 and "leverage" not in p._status.text, "fill text shown")
	p.free()
