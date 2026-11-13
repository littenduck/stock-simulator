# Stock Simulator

A turn-based stock Roguelike. **Table mode** (new): a quick game of 7 days (one quarter), or 14 or 28 days (2 or 4 quarters): you and three rivals bet every day on one
funny rumor (BELIEVE / BULLSHIT / PASS), a Boss rumor ends every quarter, and six characters
(Insider Inu, Copilot Cody, Double Dan, Saving Son, Goldfish Gus, Hodl Hana) each bend the rules. See [docs/table-mode.md](docs/table-mode.md).
The classic 60-day game (6 of 30 real-world-flavored companies in 4 sectors, a perk every 10 days) is still in the code. Web build first; Steam later.

- Licence: source-available, noncommercial use only (PolyForm Noncommercial 1.0.0), see [LICENSE.txt](LICENSE.txt) and [CREDITS.txt](CREDITS.txt)
- Version: single source is `config/version` under `[application]` in [project.godot](project.godot) (shown in the main menu corner); releases are tagged `v<version>`

## Features

- **Real market history.** Prices replay real market history 2022-2026 with company names altered by one letter
  (Nvideo, Pineapple, Tezla, Macro Hard, ...); events are fictional rumors layered on top. Every run picks one start date
  (from the run seed) and all six stocks replay the same calendar window, so sectors move together like they did
  in real life. News shocks multiply on top of the real path and persist.
- **Candlestick charts** (green up, red down, wicks, hover OHLC) with a line toggle, about 30 days of real lookback
  before day 0, and the run's calendar date in the top bar.
- **Rumors -> confirmed or debunked.** Pop-up news cards when a rumor appears and when it resolves.
- **Perk draft** every 10 days: a pop-up with three (or four) rarity cards (common, rare, legendary).
- **Orders:** market, limit and stop; margin trading (short selling and leverage) is a setting, off by default.
- **Pixel icon per company** drawn in code (no image or font assets), local high scores, unlockable characters,
  companies and difficulty levels, auto-saved run, music and sound effects.
- Keyboard: Space next day, B / S buy and sell ticket, 1-6 pick a stock, Enter submit, Esc menu.

## Data

`data/market/history.csv` holds daily open/high/low/close for the 30 real tickers (about 1,200 trading days,
split-adjusted, all tickers aligned on the same dates). Refresh it with:

```bash
python3 tools/fetch_history.py      # needs network; rewrites data/market/history.csv
scripts/test.sh                     # re-run the tests after a refresh
```

The roster and the one-letter name changes are in `docs/iteration2-spec.md`. The price data comes from Yahoo
Finance for personal, non-commercial prototyping; see `CREDITS.txt` before any public release.

- Engine: Godot 4.7 (GDScript, Compatibility renderer)
- Game design: [docs/game-design.md](docs/game-design.md)
- Implementation plan: [docs/implementation-plan.md](docs/implementation-plan.md) (section 13 overrides 1-12)
- Overall plan: [docs/plan.md](docs/plan.md)

## Real market data

Prices replay real market history (daily OHLC, 2022-2026) from `data/market/history.csv`. Each run picks one
random window of 60 trading days (the same calendar dates for every company) plus about 30 days of lookback.
Companies are real stocks with joke names (Nvideo, Macro Hard, Pineapple, Foogl, SpaceZ, Tezla, Starducks, ...); each company file maps to its real ticker through `history_key`. Late listings (SanDisk 2025, SpaceX 2026) only appear in windows where they have data, and every run draws at least one space or finance company. News events are
fictional rumors layered on top of the real price path.

Refresh the data (needs network) with `python3 tools/fetch_history.py`; it rewrites `data/market/history.csv`. Note: the stored prices are modified, scaled to 1/10 of the real quotes (percentage moves are unchanged), so they are processed data, not original Yahoo values.
The export preset ships the CSV (`include_filter="data/market/*.csv"`). See [CREDITS.txt](CREDITS.txt) for the data source.

## Run

```bash
godot --path .                 # play
scripts/test.sh                # import + all tests (no addons needed)
godot --headless --path . --script res://tools/qa_runs.gd   # 42 full autoplayed runs through GameManager (QA)
godot --headless --path . --export-release "Web" build/web/index.html   # web build (needs export templates)
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
