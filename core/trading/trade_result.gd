## Outcome of executing or placing an order. On failure `reason` is a localization key.
## CONTRACT: frozen.
class_name TradeResult
extends RefCounted

var ok: bool = false
var reason: String = ""
var order: Order
var shares: int = 0
var price: float = 0.0
var fee: float = 0.0
## True when a LIMIT/STOP order was accepted into the order book but not filled yet.
var pending: bool = false


static func success(p_order: Order, p_price: float, p_fee: float) -> TradeResult:
	var r := TradeResult.new()
	r.ok = true
	r.order = p_order
	r.shares = p_order.shares
	r.price = p_price
	r.fee = p_fee
	return r


static func queued(p_order: Order) -> TradeResult:
	var r := TradeResult.new()
	r.ok = true
	r.pending = true
	r.order = p_order
	return r


static func fail(p_reason: String, p_order: Order = null) -> TradeResult:
	var r := TradeResult.new()
	r.reason = p_reason
	r.order = p_order
	return r
