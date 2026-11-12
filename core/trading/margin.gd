## Maintenance margin check and forced liquidation.
## CONTRACT: signature frozen. Owner of the body: trading-engine.
## STUB: never liquidates.
class_name Margin
extends RefCounted


## If equity / gross exposure < mods.maintenance_margin: cancel all orders, close all positions at
## market prices and return true. Iron Hands (flag &"iron_hands") skips the first one:
## sets mods.iron_hands_used = true and returns false.
static func check(_portfolio: Portfolio, _market: MarketSim, _book: OrderBook, _mods: RunModifiers) -> bool:
	return false
