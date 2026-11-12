## Queue of pending LIMIT / STOP orders and the daily matching.
## CONTRACT: public signatures frozen. Owner of the body: trading-engine.
## Rules: docs/implementation-plan.md section 13.8.
class_name OrderBook
extends RefCounted

var _orders: Array[Order] = []
var _next_id: int = 1


## Adds a LIMIT/STOP order, assigns order.id and returns it.
## Returns 0 (and does not queue) for a null order, a MARKET order, shares <= 0 or a trigger_price <= 0.
func place(order: Order) -> int:
	if order == null or order.kind == Order.Kind.MARKET or order.shares <= 0 or order.trigger_price <= 0.0:
		return 0
	order.id = _next_id
	_next_id += 1
	_orders.append(order)
	return order.id


func cancel(order_id: int) -> bool:
	for i in _orders.size():
		if _orders[i].id == order_id:
			_orders.remove_at(i)
			return true
	return false


func cancel_all() -> void:
	_orders.clear()


func pending() -> Array[Order]:
	return _orders


## Checks every pending order against today's close in id order. Returns one TradeResult per
## triggered order (ok = filled, !ok = voided). Triggered orders leave the book.
## Fills at the close; LIMIT orders get mods.limit_price_improvement in the player's favour;
## STOP orders pay no fee with the stop_guard flag.
func process(market: MarketSim, portfolio: Portfolio, mods: RunModifiers) -> Array[TradeResult]:
	var results: Array[TradeResult] = []
	var ordered: Array[Order] = _orders.duplicate()
	ordered.sort_custom(func(a: Order, b: Order) -> bool: return a.id < b.id)
	for o in ordered:
		if not market.has_symbol(o.symbol):
			_orders.erase(o)
			results.append(TradeResult.fail(TradeService.ERR_UNKNOWN_SYMBOL, o))
			continue
		var close: float = market.price_of(o.symbol)
		if not _triggered(o, close):
			continue
		_orders.erase(o)
		var price: float = close
		if o.kind == Order.Kind.LIMIT:
			var k: float = mods.limit_price_improvement
			price = close * (1.0 - k) if o.side == Order.Dir.BUY else close * (1.0 + k)
		var fee: float = absf(o.shares * price) * mods.effective_fee_rate()
		if o.kind == Order.Kind.STOP and mods.has_flag(&"stop_guard"):
			fee = 0.0
		results.append(TradeService.execute_at(o, price, fee, market, portfolio, mods))
	return results


static func _triggered(o: Order, close: float) -> bool:
	match o.kind:
		Order.Kind.LIMIT:
			return close <= o.trigger_price if o.side == Order.Dir.BUY else close >= o.trigger_price
		Order.Kind.STOP:
			return close >= o.trigger_price if o.side == Order.Dir.BUY else close <= o.trigger_price
	return false


func to_dict() -> Dictionary:
	var out: Array[Dictionary] = []
	for o in _orders:
		out.append(o.to_dict())
	return {"next_id": _next_id, "orders": out}


func load_dict(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	_orders.clear()
	for d in data.get("orders", []):
		_orders.append(Order.from_dict(d))
