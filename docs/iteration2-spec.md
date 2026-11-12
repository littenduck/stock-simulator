# Iteration 2 spec (leader: main session; executed linearly by sub-agents)

User goals: (1) real-world-flavored tickers instead of unreadable fictional ones, (2) real historical price
data replayed in each run, (3) prettier, game-like UI with animation, (4) candlestick charts, (5) pop-up
dialogs for perk drafts (3 distinct rarity cards) and for news events, (6) a fix for the buy/sell quantity
box (typing "10" then pressing Buy must buy 10, without needing Enter). Gameplay rules stay unchanged.
Everything in the repo may be edited (including formerly "frozen" files) as long as tests pass.

## Roster (revised: 30 companies, 4 sectors)
Real companies with joke names chosen by the project owner (name = a pun on the real one; ticker = a short
pun/abbreviation). Sectors (mechanics): tech, space, consumer (retail, food, cars, entertainment, gaming), finance
(fintech and crypto). Health and energy were dropped. Icons are names the UI must draw (feat/02 adds the new ones:
disk, bear, satellite, moon, blocks, game, ticket; chip/window/fruit/magnifier/people/rocket/box/car/play/cart/coffee/soda/coin exist).
Each run draws 6 companies; at least one is space or finance. Late listings (SNDK 2025-02, SPCX 2026-06, LUNR 2023-02)
only appear in windows where they have data.

| real | ticker | display name | sector | icon |
|---|---|---|---|---|
| AMC | AAC | AAA Cinema | consumer | ticket |
| AMZN | AMZG | Amazing | consumer | box |
| AMD | AND | Advanced Nano Device | tech | chip |
| COIN | BAIT | Coinbait | finance | coin |
| RBLX | BOBX | Boblox | consumer | blocks |
| AVGO | BVGO | Brovago Comm | tech | chip |
| COST | CSGO | Costgo | consumer | cart |
| GOOGL | FOGO | Foogl | tech | magnifier |
| ASTS | FSTS | Fast Spacemobile | space | satellite |
| GME | GMB | Game Blip | consumer | game |
| HOOD | HOOK | Robinhook | finance | coin |
| KO | KEKO | Keko Cola | consumer | soda |
| LCID | LBIC | Lubric Motor | consumer | car |
| SOFI | LOFI | Lofi | finance | coin |
| LUNR | LUNA | Lunatic Machine | space | moon |
| META | MEGA | Mega | tech | people |
| MSFT | MHDR | Macro Hard | tech | window |
| MRVL | MRBL | Marbble | tech | chip |
| MU | MUN | Mucron | tech | disk |
| NFLX | NUTX | Nutflix | consumer | play |
| NVDA | NVDO | Nvideo | tech | chip |
| PLTR | PLBR | Polarbear | tech | bear |
| PEP | POPS | Popsi Cola | consumer | soda |
| AAPL | PPLE | Pineapple | tech | fruit |
| RIVN | RIBN | Ribbon | consumer | car |
| RKLB | RKLP | Rocket Lap | space | rocket |
| SBUX | SDUX | Starducks | consumer | coffee |
| SNDK | SNDH | Sandish | tech | disk |
| SPCX | SPCZ | SpaceZ | space | rocket |
| TSLA | TZLA | Tezla | consumer | car |

## Real data
`data/market/history.csv` (already fetched by `tools/fetch_history.py`): header `date,<REAL>_o,_h,_l,_c,...`,
1220 trading days 2022-01-03..2026-11-11, all 24 tickers aligned on the same dates, split-adjusted.
A run picks (with the run rng, so it is deterministic per seed) ONE start index; all companies in the run use the
SAME calendar window (day 0 = that date, 61 consecutive rows, so 60 steps), plus up to ~30 rows of real
lookback shown as pre-game chart history. Sim price = replay of the real daily returns, then news shocks
multiply on top (shock effects persist, the real path continues from there). Real-world headlines are NOT
needed to match: events are fictional rumors about the renamed companies and layer over the real path.
Starting price = real close on the start date (so prices look familiar).

## Steps (strictly sequential, each step ends with `scripts/test.sh` green and a commit by the leader)
1. DATA + CORE: CompanyDef gets `icon` (+ keep sector); 24 company .tres replacing the 20 old ones; localization;
   HistoricalPriceModel + candle (open/high/low/close) support in MarketSim (`candles_of(symbol)`), session picks
   window, exposes `date_of_day(day)`; save/load keeps the window; GBM model remains for tests/tools and synthesizes OHLC.
   Update all tests/tools that referenced old symbols.
2. NEWS: rewrite events to the new roster (sector events keep ids; symbol-targeted events for the star companies;
   pick_* and headlines in rumor tone, mention renamed companies, fun but readable), update localization + tests.
3. UI THEME + CHART: pixel icon system (code-drawn 16x16 bitmaps, no binary assets), icons beside tickers in list,
   chart header, order panel, portfolio; candlestick chart (green/red, wicks, hover OHLC) with line toggle; game-like
   visual refresh (palette, panels, gradients, button feedback, number tween, hover/press animations, top bar shows date).
4. POPUPS + UX: perk draft as animated modal with 3 rarity-styled cards (common/rare/epic distinct borders, glow,
   pop-in stagger, hover lift); news events as animated pop-up toasts/modals when a rumor appears and when it resolves;
   order quantity fix (value committed on text change; Buy/Sell/Max buttons, quick +1/+10/+25%/Max chips).
5. QA + POLISH: run the app, screenshot every screen, fix visual/functional defects, final review.

## Scoring (leader, 1-5 per criterion; a step passes at 5/5 on all)
Correctness (tests green, no runtime errors), spec coverage, visual/UX quality, code quality, no regressions.
