# Requests from trading-engine

No contract change needed. Notes for the lead / other roles:

1. **Value Investor (meta-progression)**: "long dividends doubled" is `mods.dividend_mult = 2.0`, but
   `DailyEffects` pays `long_value * long_dividend_daily * dividend_mult`. The base `long_dividend_daily`
   is 0.0, so the doubling does nothing unless the character/perk also sets a base dividend
   (e.g. `long_dividend_daily = 0.0003`). Please decide in the character data.
2. **Session (13.9 step 4)**: `OrderBook.place()` now returns 0 and queues nothing for an invalid order
   (null, MARKET kind, shares <= 0, trigger_price <= 0). Treat 0 as failure.
3. **Session**: day-60 expiry of pending orders is not done in OrderBook; call `book.cancel_all()` at the end.
4. `DailyEffects.apply` returns `interest` signed (negative = paid); `borrow_fee`, `dividends`, `bonus` are positive.
5. Added public helper `TradeService.execute_at(order, price, fee, market, portfolio, mods)` (no frozen signature changed).
