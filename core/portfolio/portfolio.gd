## Player account: cash + positions. Records only; makes no rule decisions.
## shares < 0 is a short position, cash < 0 is borrowed money.
## CONTRACT: public signatures frozen. Owner of the body: trading-engine.
class_name Portfolio
extends RefCounted

var cash: float = 0.0
## symbol -> {"shares": int, "avg_cost": float}
var positions: Dictionary = {}


func _init(start_cash: float = 0.0) -> void:
	cash = start_cash


func shares_of(symbol: String) -> int:
	return int(positions.get(symbol, {}).get("shares", 0))


func held_symbols() -> Array[String]:
	var out: Array[String] = []
	for s in positions.keys():
		out.append(s)
	return out


## Applies a fill. signed_shares > 0 buys, < 0 sells. Cash changes by -(signed_shares * price) - fee.
## Average cost: weighted when adding to a position, unchanged when reducing, `price` for the part
## that flips through zero. A position that reaches zero is removed.
func apply_fill(symbol: String, signed_shares: int, price: float, fee: float) -> void:
	if signed_shares == 0:
		return
	cash -= float(signed_shares) * price + fee
	var old: int = shares_of(symbol)
	var old_avg: float = float(positions.get(symbol, {}).get("avg_cost", 0.0))
	var now: int = old + signed_shares
	if now == 0:
		positions.erase(symbol)
		return
	var avg: float = old_avg
	if old == 0 or (old > 0) != (now > 0):
		avg = price
	elif absi(now) > absi(old):
		avg = (old_avg * absi(old) + price * absi(signed_shares)) / float(absi(now))
	positions[symbol] = {"shares": now, "avg_cost": avg}


func long_value(market: MarketSim) -> float:
	var total := 0.0
	for s in positions.keys():
		var n: int = shares_of(s)
		if n > 0:
			total += n * market.price_of(s)
	return total


func short_value(market: MarketSim) -> float:
	var total := 0.0
	for s in positions.keys():
		var n: int = shares_of(s)
		if n < 0:
			total += -n * market.price_of(s)
	return total


## cash + long_value - short_value
func net_worth(market: MarketSim) -> float:
	return cash + long_value(market) - short_value(market)


## long_value + short_value
func gross_exposure(market: MarketSim) -> float:
	return long_value(market) + short_value(market)


## Closes every position at market prices (no fee).
func liquidate_all(market: MarketSim) -> void:
	for s in held_symbols():
		apply_fill(s, -shares_of(s), market.price_of(s), 0.0)


func to_dict() -> Dictionary:
	return {"cash": cash, "positions": positions.duplicate(true)}


func load_dict(data: Dictionary) -> void:
	cash = float(data.get("cash", 0.0))
	positions = {}
	var src: Dictionary = data.get("positions", {})
	for s in src.keys():
		var p: Dictionary = src[s]
		positions[String(s)] = {"shares": int(p.get("shares", 0)), "avg_cost": float(p.get("avg_cost", 0.0))}
