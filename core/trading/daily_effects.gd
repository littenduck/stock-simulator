## End-of-day money effects: loan interest, borrow fee, cash interest, dividends, Diversifier.
## CONTRACT: signature frozen. Owner of the body: trading-engine.
## STUB: does nothing.
class_name DailyEffects
extends RefCounted


## Applies the effects to `portfolio` and returns the amounts:
## {"interest": float, "borrow_fee": float, "dividends": float, "bonus": float}
static func apply(_portfolio: Portfolio, _market: MarketSim, _mods: RunModifiers) -> Dictionary:
	return {"interest": 0.0, "borrow_fee": 0.0, "dividends": 0.0, "bonus": 0.0}
