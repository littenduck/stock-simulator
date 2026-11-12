## A trade command. Describes intent only; TradeService / OrderBook execute it.
## CONTRACT: frozen.
class_name Order
extends RefCounted

enum Dir { BUY, SELL }
enum Kind { MARKET, LIMIT, STOP }

## Assigned by OrderBook.place(); 0 = not placed.
var id: int = 0
var side: Dir = Dir.BUY
var kind: Kind = Kind.MARKET
var symbol: String = ""
var shares: int = 0
## Used by LIMIT / STOP.
var trigger_price: float = 0.0


static func market(p_side: Dir, p_symbol: String, p_shares: int) -> Order:
	var o := Order.new()
	o.side = p_side
	o.symbol = p_symbol
	o.shares = p_shares
	return o


static func limit(p_side: Dir, p_symbol: String, p_shares: int, p_trigger: float) -> Order:
	var o := Order.market(p_side, p_symbol, p_shares)
	o.kind = Kind.LIMIT
	o.trigger_price = p_trigger
	return o


static func stop(p_side: Dir, p_symbol: String, p_shares: int, p_trigger: float) -> Order:
	var o := Order.market(p_side, p_symbol, p_shares)
	o.kind = Kind.STOP
	o.trigger_price = p_trigger
	return o


func to_dict() -> Dictionary:
	return {"id": id, "side": side, "kind": kind, "symbol": symbol, "shares": shares, "trigger_price": trigger_price}


static func from_dict(d: Dictionary) -> Order:
	var o := Order.new()
	o.id = int(d.get("id", 0))
	o.side = int(d.get("side", 0)) as Dir
	o.kind = int(d.get("kind", 0)) as Kind
	o.symbol = String(d.get("symbol", ""))
	o.shares = int(d.get("shares", 0))
	o.trigger_price = float(d.get("trigger_price", 0.0))
	return o
