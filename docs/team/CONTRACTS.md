# Contracts (v0.1)

Frozen interfaces between roles. The code in the repo is the source of truth for signatures
(`tests/contract/test_contracts.gd` fails if a frozen method disappears or changes its argument count);
this file adds the **meaning**. Details of the rules live in `docs/implementation-plan.md`
(sections 13.x override 1-12) and `docs/game-design.md`.

## Dependency direction

`ui → autoload (GameManager, SaveManager, EventBus) → core → data`. Notifications upward go through `EventBus` only.

## Who implements what

| Class / file | Implemented by | Used by |
|---|---|---|
| `MarketSim`, `PriceModel`, `GbmPriceModel`, `NewsDirector` | market-engine | session, trading (read prices) |
| `Portfolio`, `TradeService`, `OrderBook`, `DailyEffects`, `Margin` | trading-engine | session |
| `PerkDrafter`, `ModifiersBuilder`, `Difficulty`, `Profile`, perk/character `.tres` | meta-progression | session, ui-flow |
| `GameSession`, `DayReport`, `ContentDb`, `GameManager`, `SaveManager` | session-integration | every UI role |
| `EventBus`, `RunModifiers`, `RunConfig`, `Order`, `TradeResult`, `Rumor`, `data/defs/*` | **lead (frozen)** | everyone |

Stubs in the repo already compile and have the final signatures; replace the bodies, keep the signatures.
`MarketSim` and `Portfolio` stubs are minimal-but-usable so other roles can write tests early
(`MarketSim.set_price()` is a permanent test seam).

## What UI roles may call

Read (never mutate): `GameManager.state`, `GameManager.session` and below
(`session.day`, `.market.symbols()/price_of()/history_of()/day_change()/company_of()`,
`.portfolio.cash/positions/net_worth(market)`, `.book.pending()`, `.news.pending()`, `.mods`,
`.owned_perks`, `.pending_draft`, `.net_worth()`, `.score()`), `SaveManager.profile`, `ContentDb.*`.

Commands: `GameManager.start_run(RunConfig)`, `continue_run()`, `has_saved_run()`, `next_day()`,
`submit_order(Order) -> TradeResult`, `cancel_order(id)`, `choose_perk(PerkDef)`, `abandon_run()`,
`go_to_menu()`, `open_scene(path)`.

Notifications: connect to `EventBus` signals (see `autoload/event_bus.gd`). Handlers are named `_on_<signal>`.
Because the real GameManager arrives in wave 2, UI roles develop against a small dev harness of their own
(for example a scene under their folder that builds a `GameSession` by hand and emits the EventBus signals).

Scene wiring owned by the lead: `ui/game_screen/game_screen.tscn` contains `Overlays/PerkDraftDialog`,
`Overlays/GameOverDialog` (ui-flow's scenes) and `AudioFeedback` (release-qa's scene). `ui-gameplay` must keep
those three instances. Both dialogs start hidden and show themselves from EventBus signals.

## Perk and character flags

Numeric perks use `RunModifiers` fields. These need code and are checked with `mods.has_flag(...)`:

| Flag | Perk | Checked by |
|---|---|---|
| `fact_checker` | Fact Checker | ui-gameplay (show `credibility_low..high` instead of one number) |
| `stop_guard` | Stop Guard | trading-engine (stop orders have no fee) |
| `insider_friend` | Insider Friend | market-engine (every 10 days one guaranteed-true, marked rumor: `Rumor.is_guaranteed`) |
| `iron_hands` | Iron Hands | trading-engine (`Margin.check`, uses `mods.iron_hands_used`) |
| `diversifier` | Diversifier | trading-engine (`DailyEffects`: 4+ distinct holdings => +0.1% equity per day) |
| `sector_fan` | Sector Fan | session-integration (on pick: choose a sector with the run RNG, `mods.sector_truth_bonus[sector] = 0.15`) |
| `no_short` | Value Investor | none: use `mods.can_short = false` through an effect |

Pure number perks: Low Fees (`fee_mult` x0.5), Savings Account (`cash_interest_daily` +0.0005), Early Bird
(`rumor_lead_days` +1), Margin Account (`max_leverage` +1), Cheap Borrow (`borrow_rate_daily`, `loan_rate_daily` x0.5),
Dividend Hunter (`long_dividend_daily` +0.0003), Second Opinion (`draft_choices` +1), Compounder (`score_mult` x1.1),
Market Maker (`fee_mult` set 0, `limit_price_improvement` +0.01).

## Localization

One CSV per owner (`keys,en`), all pre-registered in `project.godot`. Key prefixes:
`UI_FLOW_*` (ui-flow), `UI_GAME_*` (ui-gameplay), `TRADE_ERR_*` (trading-engine), `COMPANY_*` and `NEWS_*`
(market-engine), `PERK_*` and `CHAR_*` (meta-progression). After editing a CSV run
`godot --headless --path . --import` so the `.translation` file is regenerated (commit it).

## Determinism

Everything random in `core/` uses the single `RandomNumberGenerator` created by `GameSession` from
`RunConfig.seed_value`. Iterate arrays and files in a stable order. Same seed + same inputs = same run.

## Changing a contract

Write the request in `docs/team/requests/<role>.md` (what, why, proposed signature). Keep coding against the
old signature. The lead changes the contract on `main` and tells the roles to `git merge main`.
