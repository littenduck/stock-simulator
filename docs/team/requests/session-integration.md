# Requests from session-integration

1. **ui-gameplay bug, blocks smooth play (`ui/game_screen/rumor_feed.gd:_refresh`)**: `_refresh()` does
   `_list.remove_child(child); child.queue_free()` for every child, which also frees the shared `_empty` label;
   the next `_refresh()` with no rumors re-adds the freed label ("Cannot call method 'queue_free' on a null value",
   "Attempt to connect nonexistent signal ..."). It fires on the very first `day_advanced` of a run with an empty feed.
   Fix: skip `_empty` when clearing (`if child != _empty`) or create a new label each time.
   In a headless run with the real game screen the engine also stalled after day 5 (not investigated further; the
   same flow with the game scene replaced by a stub ran all 60 days fine), so please check this screen first.
2. **Value Investor dividend (meta-progression data)**: `long_dividend_daily` base is 0.0 for the characters unless
   a perk adds it (Dividend Hunter), so `dividend_mult = 2.0` does nothing for Value Investor alone.
3. **PerkDrafter / margin_enabled (meta-progression)**: `PerkDrafter.offer(owned, count)` has no margin flag, so
   with margin off the draft can still offer margin-only perks (margin_account, cheap_borrow, iron_hands, value_investor).
   Session passes nothing extra; it needs a `margin_enabled` parameter or `PerkDef.requires_margin`.
4. **Test runner (lead)**: tests that touch `GameManager`/`SaveManager` cannot run under `--script` (no autoloads),
   so tests/unit/session covers GameSession only (incl. JSON save round trip). GameManager/SaveManager were checked by
   a throwaway scene script (start -> draft -> trades -> 60 days -> game over -> profile.json written, run.json deleted).
5. **Design note**: `GameManager.start_run` / `continue_run` change scene, wait two frames, then re-emit
   `day_advanced`, `prices_updated`, `portfolio_changed`, `perks_changed`, the pending rumors/orders and (if open)
   `draft_offered`, because the game screen's nodes only connect to EventBus in their `_ready`.
6. **Orders voided at fill time** (`DayReport.fills` entries with `ok == false`) emit `order_cancelled(order.id)` and
   `trade_failed(reason)` so the pending list drops them.
