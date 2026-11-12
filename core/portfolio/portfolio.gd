## Player account: cash + positions. Records only; makes no rule decisions.
## shares < 0 is a short position, cash < 0 is borrowed money.
## CONTRACT: public signatures frozen. Owner of the body: trading-engine.
## STUB: bookkeeping only; valuation helpers return 0 until implemented.
class_name Portfolio
extends RefCounted

var cash: float = 0.0
## symbol -> {"shares": int, "avg_cost": float}
var positions: Dictionary = {}


func _init(start_cash: float = 0.0) -> void:
	cash = start_cash


func shares_of(symbol: String) -> int:
	return positions.get(symbol, {}).get("shares", 0)


func held_symbols() -> Array[String]:
	var out: Array[String] = []
	for s in positions.keys():
		out.append(s)
	return out


## Applies a fill. signed_shares > 0 buys, < 0 sells. Cash changes by -(signed_shares * price) - fee.
func apply_fill(_symbol: String, _signed_shares: int, _price: float, _fee: float) -> void:
	push_warning("STUB Portfolio.apply_fill")


func long_value(_market: MarketSim) -> float:
	return 0.0


func short_value(_market: MarketSim) -> float:
	return 0.0


## cash + long_value - short_value
func net_worth(_market: MarketSim) -> float:
	return cash


## long_value + short_value
func gross_exposure(_market: MarketSim) -> float:
	return 0.0


## Closes every position at market prices.
func liquidate_all(_market: MarketSim) -> void:
	push_warning("STUB Portfolio.liquidate_all")


func to_dict() -> Dictionary:
	return {"cash": cash, "positions": positions.duplicate(true)}


func load_dict(data: Dictionary) -> void:
	cash = float(data.get("cash", 0.0))
	positions = data.get("positions", {}).duplicate(true)
