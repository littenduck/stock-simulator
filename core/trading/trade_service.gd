## The only place that decides whether a market trade is allowed and executes it.
## CONTRACT: public signatures frozen. Owner of the body: trading-engine.
## Rules: docs/implementation-plan.md section 13.7 (unified margin rule).
class_name TradeService
extends RefCounted

const ERR_INVALID_SHARES := "TRADE_ERR_INVALID_SHARES"
const ERR_UNKNOWN_SYMBOL := "TRADE_ERR_UNKNOWN_SYMBOL"
const ERR_NOT_ENOUGH_CASH := "TRADE_ERR_NOT_ENOUGH_CASH"
const ERR_SHORT_DISABLED := "TRADE_ERR_SHORT_DISABLED"
const ERR_OVER_LEVERAGE := "TRADE_ERR_OVER_LEVERAGE"
const ERR_NOT_IMPLEMENTED := "TRADE_ERR_NOT_IMPLEMENTED"

const _EPS := 1e-9


## Executes a MARKET order at today's close. Buying while short covers the short; selling more than
## held opens a short. Mutates `portfolio` only when the trade is allowed.
static func execute(order: Order, market: MarketSim, portfolio: Portfolio, mods: RunModifiers) -> TradeResult:
	if order == null or not market.has_symbol(order.symbol):
		return TradeResult.fail(ERR_UNKNOWN_SYMBOL, order)
	var price: float = market.price_of(order.symbol)
	var fee: float = absf(order.shares * price) * mods.effective_fee_rate()
	return execute_at(order, price, fee, market, portfolio, mods)


## Same checks and bookkeeping as execute(), at an explicit fill price and fee
## (used by OrderBook for limit / stop fills).
static func execute_at(order: Order, price: float, fee: float, market: MarketSim, portfolio: Portfolio, mods: RunModifiers) -> TradeResult:
	if order == null or not market.has_symbol(order.symbol):
		return TradeResult.fail(ERR_UNKNOWN_SYMBOL, order)
	if order.shares <= 0:
		return TradeResult.fail(ERR_INVALID_SHARES, order)
	var signed: int = order.shares if order.side == Order.Dir.BUY else -order.shares
	var old_shares: int = portfolio.shares_of(order.symbol)
	var new_shares: int = old_shares + signed
	if new_shares < 0 and new_shares < old_shares and not mods.can_short:
		return TradeResult.fail(ERR_SHORT_DISABLED, order)

	# Trial: the account after the fill.
	var cash_after: float = portfolio.cash - signed * price - fee
	var long_v := 0.0
	var short_v := 0.0
	for s in portfolio.held_symbols():
		var n: int = portfolio.shares_of(s)
		if s == order.symbol:
			n = new_shares
		var p: float = market.price_of(s)
		if n > 0:
			long_v += n * p
		else:
			short_v += -n * p
	if not portfolio.positions.has(order.symbol):
		if new_shares > 0:
			long_v += new_shares * price
		elif new_shares < 0:
			short_v += -new_shares * price
	var gross_after: float = long_v + short_v
	var gross_before: float = portfolio.gross_exposure(market)
	var equity_after: float = cash_after + long_v - short_v

	# Without leverage you cannot borrow cash to buy.
	if signed > 0 and cash_after < -_EPS and mods.max_leverage <= 1.0 + _EPS and gross_after > gross_before:
		return TradeResult.fail(ERR_NOT_ENOUGH_CASH, order)
	# Trades that do not increase exposure are always allowed (reducing risk).
	if gross_after > gross_before + _EPS:
		if equity_after <= 0.0 or gross_after > equity_after * mods.max_leverage + _EPS:
			return TradeResult.fail(ERR_OVER_LEVERAGE, order)
	portfolio.apply_fill(order.symbol, signed, price, fee)
	return TradeResult.success(order, price, fee)
