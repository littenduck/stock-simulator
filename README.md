# Stock Simulator

A turn-based stock Roguelike (60 trading days, 6 of 30 real-world-flavored companies in 4 sectors (tech, space, consumer, finance), a perk every 10 days,
rumors that come true or not). Web build first; Steam later.

- Version: v0.1
- Engine: Godot 4.7 (GDScript, Compatibility renderer)
- Game design: [docs/game-design.md](docs/game-design.md)
- Implementation plan: [docs/implementation-plan.md](docs/implementation-plan.md) (section 13 overrides 1-12)
- Overall plan: [docs/plan.md](docs/plan.md)

## Real market data

Prices replay real market history (daily OHLC, 2022-2026) from `data/market/history.csv`. Each run picks one
random window of 60 trading days (the same calendar dates for every company) plus about 30 days of lookback.
Companies are real stocks with joke names (Nvideo, Macro Hard, Pineapple, Foogl, SpaceZ, Tezla, Starducks, ...); each company file maps to its real ticker through `history_key`. Late listings (SanDisk 2025, SpaceX 2026) only appear in windows where they have data, and every run draws at least one space or finance company. News events are
fictional rumors layered on top of the real price path.

Refresh the data (needs network) with `python3 tools/fetch_history.py`; it rewrites `data/market/history.csv`.
The export preset ships the CSV (`include_filter="data/market/*.csv"`). See [CREDITS.md](CREDITS.md) for the data source.

## Run

```bash
godot --path .                 # play / open the stub flow
scripts/test.sh                # import + all tests (no addons needed)
```

## Team workflow (parallel agents)

Roles, file ownership, contracts and the per-role prompts: [docs/team/](docs/team/)
([ROLES](docs/team/ROLES.md), [WORKFLOW](docs/team/WORKFLOW.md), [CONTRACTS](docs/team/CONTRACTS.md),
[prompts](docs/team/prompts/)).

```
autoload/    EventBus, GameManager, SaveManager          core/   pure rules (no nodes)
data/        defs (Resource classes) + .tres content     ui/     scenes and scripts
localization one CSV per owner                           tests/  unit, contract, integration
scripts/     test, scope check, worktree + merge helpers tools/  headless balance tool
```
