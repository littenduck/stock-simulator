## Maintenance margin check and forced liquidation.
## CONTRACT: signature frozen. Owner of the body: trading-engine.
class_name Margin
extends RefCounted


## If equity / gross exposure < mods.maintenance_margin: cancel all orders, close all positions at
## market prices and return true. Iron Hands (flag &"iron_hands") skips the first one:
## sets mods.iron_hands_used = true and returns false.
static func check(portfolio: Portfolio, market: MarketSim, book: OrderBook, mods: RunModifiers) -> bool:
	var gross: float = portfolio.gross_exposure(market)
	if gross <= 0.0:
		return false
	if portfolio.net_worth(market) / gross >= mods.maintenance_margin:
		return false
	if mods.has_flag(&"iron_hands") and not mods.iron_hands_used:
		mods.iron_hands_used = true
		return false
	book.cancel_all()
	portfolio.liquidate_all(market)
	return true
