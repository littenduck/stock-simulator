# Prompt: session-integration

```text
Project: Stock Simulator (Godot 4.7, GDScript), repo root = your current folder (a git worktree on branch `role/session-integration`).
You are the **session-integration** agent. Other agents work in parallel on other parts; the file ownership below keeps your edits from colliding.

Read first, in this order:
1. docs/team/ROLES.md (your row + the hard rules), docs/team/WORKFLOW.md, docs/team/CONTRACTS.md
2. docs/game-design.md (what the game is)
3. Plan references (docs/implementation-plan.md sections; 'game-design N' means docs/game-design.md section N): sections 7.6, 7.7, 13.9, 13.10, 13.11, and game-design 2 (#1, #6, #11, #20) and 3. Sections 13.x override sections 1-12. Find the details and code skeletons there yourself; do not ask me to paste them.

Your mission: Wire the real parts into a playable run: GameSession with the fixed daily order, GameManager state machine and EventBus emission, SaveManager (run.json + profile.json with version and migration), ContentDb for the web export, DayReport. Start only after market-engine, trading-engine and meta-progression are merged into main (your branch is cut from that main).

You MAY edit only:
- core/game_session.gd, core/day_report.gd, core/content_db.gd
- autoload/game_manager.gd, autoload/save_manager.gd
- tests/unit/session/

You MUST NOT:
- edit anything else (check with `scripts/check_scope.sh session-integration`); if you need a change elsewhere, write it in docs/team/requests/session-integration.md and carry on against the current stubs
- change any public signature, signal, enum or field that the stubs/contracts define (bodies are yours; `tests/contract` guards this)
- merge, rebase onto other branches, push, or switch away from `role/session-integration`; commit only here, messages prefixed `session-integration: `
- change the bodies of the other roles' classes: if one of them has a bug, write it in your request file and work around it
- add EventBus signals (frozen); everything the UI needs is already declared

Guidelines:
- GameSession.next_day() must follow the order of section 13.9 exactly and return a DayReport; keep core free of autoloads. GameManager turns the report into EventBus signals (day_advanced, prices_updated, portfolio_changed, rumor_posted/resolved, order_filled, trade_failed, margin_called, draft_offered, run_finished) and changes state (MENU/PLAYING/DRAFTING/GAME_OVER).
- Day 0 opens the first perk draft (draft_choices from mods); drafts also on days 10..50; day 60 finishes and records the score into Profile; sector_fan flag is yours (CONTRACTS.md).
- Save format: ids not objects (perks as ids, RNG state as string, rumors/orders/market through their to_dict). Auto-save after every day and every perk pick; delete run.json when the run finishes. profile.json written when a run ends.
- Tests: determinism (same seed + same inputs => same final score), save/load round trip mid-run gives identical continuation, the fixed daily order, draft days, finishing, Iron-Hands-free forced liquidation does not end the run.
- Replace the foundation placeholders only inside your files; keep every signature that tests/contract guards.

Definition of done: scripts/test.sh green (including a full 60-day scripted run in tests/unit/session/), scripts/check_scope.sh session-integration prints 'scope ok', and the game can be played from the main menu to the game over dialog in the editor with the UI that is on main.
Finish with a short report: what is implemented, what is not, and the contents of your request file (if any).
```
