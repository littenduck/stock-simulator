# Prompt: trading-engine

```text
Project: Stock Simulator (Godot 4.7, GDScript), repo root = your current folder (a git worktree on branch `role/trading-engine`).
You are the **trading-engine** agent. Other agents work in parallel on other parts; the file ownership below keeps your edits from colliding.

Read first, in this order:
1. docs/team/ROLES.md (your row + the hard rules), docs/team/WORKFLOW.md, docs/team/CONTRACTS.md
2. docs/game-design.md (what the game is)
3. Plan references (docs/implementation-plan.md sections; 'game-design N' means docs/game-design.md section N): sections 7.3, 7.4, 13.7, 13.8, 13.9 (steps 4-6), and game-design 2 (#9) and 8 (D, E, F). Sections 13.x override sections 1-12. Find the details and code skeletons there yourself; do not ask me to paste them.

Your mission: Implement all money rules: bookkeeping with long/short/negative cash, market orders, the unified margin and leverage rule, limit/stop orders, daily interest/borrow/dividend effects, forced liquidation.

You MAY edit only:
- core/portfolio/, core/trading/ (but NOT core/trading/order.gd and trade_result.gd, they are frozen)
- localization/errors.csv (all TRADE_ERR_* messages)
- tests/unit/portfolio/, tests/unit/trading/

You MUST NOT:
- edit anything else (check with `scripts/check_scope.sh trading-engine`); if you need a change elsewhere, write it in docs/team/requests/trading-engine.md and carry on against the current stubs
- change any public signature, signal, enum or field that the stubs/contracts define (bodies are yours; `tests/contract` guards this)
- merge, rebase onto other branches, push, or switch away from `role/trading-engine`; commit only here, messages prefixed `trading-engine: `
- touch MarketSim or news code (use MarketSim only through its public methods; `set_price()` exists for your tests)

Guidelines:
- Implement Portfolio, TradeService.execute, OrderBook (place/cancel/process in id order, fills at the close price, voiding with trade_failed reason), DailyEffects, Margin.check (including Iron Hands).
- Read all rule numbers from RunModifiers; never hard-code fee or leverage values. Flags: stop_guard, iron_hands, diversifier; Market Maker uses limit_price_improvement.
- Tests must cover: buy/sell, opening and covering shorts, over-leverage rejection, short disabled, negative cash interest, borrow fee, dividends, liquidation threshold, Iron Hands once, limit/stop trigger rules for both sides, order determinism, to_dict/load_dict round trip.
- Money maths in float is fine, but compare with tolerance in tests; shares are int.

Definition of done: scripts/test.sh green and scripts/check_scope.sh trading-engine prints 'scope ok'; every rule in sections 13.7-13.8 has at least one test.
Finish with a short report: what is implemented, what is not, and the contents of your request file (if any).
```
