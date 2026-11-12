# Roles and file ownership (v0.1)

One role = one session = one branch `role/<name>`. A role may change **only** the paths listed for it
(`scripts/owners.txt` is the machine-readable copy; `scripts/check_scope.sh <role>` enforces it).
Anything in `scripts/frozen.txt` (contracts, `project.godot`, `docs/`, `scripts/`, tests infrastructure)
belongs to the **lead** (you / the main session).

Waves: roles in the same wave never wait for each other because they only meet through the stubs and
signatures in [CONTRACTS.md](CONTRACTS.md).

| Wave | Role (session name) | Mission | Owns (may edit) | Plan sections |
|---|---|---|---|---|
| 1 | `market-engine` | Price model, market simulation, company draw, rumors, 15+5 companies, 30 news events | `core/market/` `core/news/` (except `rumor.gd`) `data/companies/` `data/news/` `localization/companies.*` `localization/news.*` `tests/unit/market/` `tests/unit/news/` | 7.1, 7.2, 7.5, 13.6 |
| 1 | `trading-engine` | Portfolio, orders, margin/leverage/short, order book, daily interest/dividends, forced liquidation | `core/portfolio/` `core/trading/` (except `order.gd`, `trade_result.gd`) `localization/errors.*` `tests/unit/portfolio/` `tests/unit/trading/` | 7.3, 7.4, 13.7, 13.8 |
| 1 | `meta-progression` | Perk drafter, modifiers builder, 15 perks, 3 characters, difficulty, Profile (unlocks + top 10) | `core/perks/perk_drafter.gd` `core/perks/modifiers_builder.gd` `core/meta/` `data/perks/` `data/characters/` `localization/perks.*` `localization/characters.*` `tests/unit/perks/` `tests/unit/meta/` | 13.5, game-design 5.2-5.4, 7 |
| 1 | `ui-gameplay` | The in-run screen: top bar, price chart, order panel, portfolio, pending orders, rumor feed, perk bar | `ui/game_screen/` `localization/ui_game.*` | 7.8, 13.3, 13.10 |
| 1 | `ui-flow` | Menus and dialogs: main menu, run setup, perk draft dialog, game over dialog, high scores, theme | `ui/main_menu/` `ui/run_setup/` `ui/perk_draft/` `ui/high_scores/` `ui/game_over/` `ui/theme/` `localization/ui_flow.*` | 7.8, 13.3 |
| 1 | `release-qa` | Web export preset, CI, audio hookup + assets, CREDITS/LICENSE, balance tool skeleton | `tools/` `tests/integration/` `.github/` `export_presets.cfg` `audio/` `ui/audio/` `CREDITS.md` `LICENSE` `docs/release/` | 7.11, 9, 13.12 |
| 2 | `session-integration` | GameSession (daily order), GameManager, SaveManager, ContentDb, DayReport, saves + profile files | `core/game_session.gd` `core/day_report.gd` `core/content_db.gd` `autoload/game_manager.gd` `autoload/save_manager.gd` `tests/unit/session/` | 7.6, 7.7, 13.9-13.11 |
| 3 | `release-qa` (again) | Run the balance tool, integration tests, fix export issues | same as above | 13.12, 13.13 M7 |

Start `session-integration` only after the wave-1 branches that it depends on (`market-engine`,
`trading-engine`, `meta-progression`) are merged into `main`; it then works against the real classes.
The two UI roles and `release-qa` can be merged at any time.

## Hard rules for every role

1. Touch only your own paths. If you need something outside them, write it to
   `docs/team/requests/<role>.md` (that file is yours) and keep working against the current contract.
2. Never change a public signature listed in [CONTRACTS.md](CONTRACTS.md). Bodies are yours.
3. `core/` stays pure: no `EventBus`, `GameManager`, `get_node`, `get_tree`, no global `randf()`/`randi()`
   (use the injected `RandomNumberGenerator`).
4. UI only reads state and sends commands through `GameManager`; it never mutates `core/` objects.
5. Every behaviour you add under `core/` needs a test file under your `tests/unit/<area>/`.
6. Static typing everywhere, Tab indentation, Godot style guide (plan section 8).
7. Strings shown to players are localization keys (`tr()`), added to **your** CSV only.
8. Before reporting done: `scripts/test.sh` is green and `scripts/check_scope.sh <role>` prints `scope ok`.
