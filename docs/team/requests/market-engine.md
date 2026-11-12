# Requests from market-engine

1. **Done with the lead's approval:** `tests/unit/test_foundation.gd` asserted `has_symbol("NOVA")`, which depends
   on the seed now that `draw_companies` really draws; it now checks the number of drawn companies instead.
2. **Unlock ids (meta-progression / session-integration):** the 5 unlockable companies use
   `co_lunaris` (LNRVS), `co_oldegate` (OLDGT), `co_quantora` (QNTRM), `co_tidalon` (TDLNH), `co_aurelix` (AURXL).
   `Profile.record_run` must grant them or they never appear (`GameSession` passes the unlocked ids to
   `MarketSim.draw_companies`).
3. **Tickers:** all invented, 5 letters (real common stocks practically never have 5 letters), but nobody
   has checked them against a live exchange list. Do a quick lookup before release.
4. **Resolving rumors (session-integration):** on reveal call `market.apply_news(r.event, r.impact_scale())`
   (use `r.event`, not the pool template: for "pick a random stock of the sector" templates `r.event` is a copy
   carrying the chosen ticker, also after a save/load). `due(day)` uses `reveal_day <= day`.
5. **Template convention:** `target_symbol == "any"` (`NewsDirector.ANY_SYMBOL`) with a `target_sector` means
   "one random stock of that sector in the market". Fixed tickers only fire when that ticker was drawn.
