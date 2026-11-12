## End-of-day money effects: loan interest, borrow fee, cash interest, dividends, Diversifier.
## CONTRACT: signature frozen. Owner of the body: trading-engine.
class_name DailyEffects
extends RefCounted

const DIVERSIFIER_MIN_HOLDINGS := 4
const DIVERSIFIER_RATE := 0.001


## Applies the effects to `portfolio` and returns the amounts:
## {"interest": float, "borrow_fee": float, "dividends": float, "bonus": float}
## interest is signed (negative = loan interest paid, positive = cash interest earned);
## borrow_fee is the positive amount charged; dividends and bonus are positive amounts received.
static func apply(portfolio: Portfolio, market: MarketSim, mods: RunModifiers) -> Dictionary:
	var equity: float = portfolio.net_worth(market)
	var interest := 0.0
	if portfolio.cash < 0.0:
		interest = portfolio.cash * mods.loan_rate_daily
	elif portfolio.cash > 0.0:
		interest = portfolio.cash * mods.cash_interest_daily
	var borrow_fee: float = portfolio.short_value(market) * mods.borrow_rate_daily
	var dividends: float = portfolio.long_value(market) * mods.long_dividend_daily * mods.dividend_mult
	var bonus := 0.0
	if mods.has_flag(&"diversifier") and equity > 0.0:
		var distinct := 0
		for s in portfolio.held_symbols():
			if portfolio.shares_of(s) != 0:
				distinct += 1
		if distinct >= DIVERSIFIER_MIN_HOLDINGS:
			bonus = equity * DIVERSIFIER_RATE
	portfolio.cash += interest - borrow_fee + dividends + bonus
	return {"interest": interest, "borrow_fee": borrow_fee, "dividends": dividends, "bonus": bonus}
