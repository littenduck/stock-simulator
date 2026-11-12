## Queue of pending LIMIT / STOP orders and the daily matching.
## CONTRACT: public signatures frozen. Owner of the body: trading-engine.
## Rules: docs/implementation-plan.md section 13.8.
## STUB: stores orders but never fills them.
class_name OrderBook
extends RefCounted

var _orders: Array[Order] = []
var _next_id: int = 1


## Adds a LIMIT/STOP order, assigns order.id and returns it.
func place(order: Order) -> int:
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
func process(_market: MarketSim, _portfolio: Portfolio, _mods: RunModifiers) -> Array[TradeResult]:
	return []


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
