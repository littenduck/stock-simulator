# Requests from ui-gameplay

No contract change is required. Notes for the lead and session-integration, so the real classes fit the screen:

1. **Test runner noise (lead).** `scripts/test.sh` loads every scene through `--script`, where autoloads are not
   registered, so scripts that name `GameManager` / `EventBus` print "Identifier not found" compile errors
   (the test still reports green). Registering autoloads in `tests/run_tests.gd`, or loading scenes in a
   child scene tree, would silence it for every UI role.
2. **GameManager (session-integration).**
   - Emit `EventBus.order_filled` for pending orders that fill during `next_day()` (id != 0). The order panel
     reports them in its status line, and the pending list refreshes on it.
   - Emit `EventBus.order_placed` for queued LIMIT/STOP orders and `order_cancelled` from `cancel_order()`;
     the chart's trigger lines and the pending list depend on both.
   - Set `Rumor.resolved = true` before emitting `rumor_resolved` (the feed reads that flag).
   - Emit `prices_updated` and `portfolio_changed` after every `next_day()` and after every trade.
3. **Portfolio (trading-engine).** The UI reads `positions[symbol]["avg_cost"]` and `["shares"]`, plus
   `long_value()`, `short_value()`, `gross_exposure()` and `net_worth()`.
4. Space = next day is handled only by `GameManager._unhandled_input`. The pause menu swallows it while open.
5. **Missing glyphs in web exports (lead / ui-flow).** Godot's default font has no ▲ ▼ ✔ ✘ ★ ● ✕ and a web export has
   no system fallback font, so these characters show as boxes. The game screen draws them as icons
   (`ui/game_screen/icons.gd`, `delta.gd`). Any other screen that prints them as text should do the same, or ship a font that has them.
6. The game screen ships its own copy of the Kenney Pixel UI slices in `ui/game_screen/skins/pixel/`; once ui-flow is merged
   it could share `ui/theme/assets/` instead.
