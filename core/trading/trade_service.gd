## The only place that decides whether a market trade is allowed and executes it.
## CONTRACT: public signatures frozen. Owner of the body: trading-engine.
## Rules: docs/implementation-plan.md section 13.7 (unified margin rule).
## STUB: always fails until implemented.
class_name TradeService
extends RefCounted

const ERR_INVALID_SHARES := "TRADE_ERR_INVALID_SHARES"
const ERR_UNKNOWN_SYMBOL := "TRADE_ERR_UNKNOWN_SYMBOL"
const ERR_NOT_ENOUGH_CASH := "TRADE_ERR_NOT_ENOUGH_CASH"
const ERR_SHORT_DISABLED := "TRADE_ERR_SHORT_DISABLED"
const ERR_OVER_LEVERAGE := "TRADE_ERR_OVER_LEVERAGE"
const ERR_NOT_IMPLEMENTED := "TRADE_ERR_NOT_IMPLEMENTED"


## Executes a MARKET order at today's close. Buying while short covers the short; selling more than
## held opens a short. Mutates `portfolio` only when the trade is allowed.
static func execute(order: Order, _market: MarketSim, _portfolio: Portfolio, _mods: RunModifiers) -> TradeResult:
	return TradeResult.fail(ERR_NOT_IMPLEMENTED, order)
