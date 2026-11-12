# Requests from market-engine

1. **Unlock ids (meta-progression / session-integration):** the 5 unlockable companies use these
   `unlock_id`s: `co_lunaris` (LNRV, wild), `co_oldegate` (OLDG, ultra stable), `co_quantora` (QNTR),
   `co_tidalon` (TDLN), `co_aurelix` (AURX). `Profile.record_run` must grant them for them to ever appear
   (`GameSession` passes `profile.unlocked` keys to `MarketSim.draw_companies`).
2. **Ticker check:** tickers are invented, but I could not check them against a live exchange list offline.
   Please do a quick real-world lookup before release.
3. **Draw changes the stub order:** `draw_companies` now shuffles (sorted by symbol first, then Fisher-Yates
   with the run rng). Tests must not assume the first N pool companies, e.g. `test_foundation`'s `has_symbol("NOVA")`
   passes today only because the stub session builds the market from the full pool.
4. **Resolving rumors (session-integration):** on reveal call `market.apply_news(r.event, r.impact_scale())`;
   `due(day)` uses `reveal_day <= day`. Single-stock templates carry fixed tickers and only fire when that
   ticker is in the drawn market.
