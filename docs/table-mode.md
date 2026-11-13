# Table mode (branch feat/05-characters)

You and three computer seats trade the same market for **30 days = 3 quarters of 10 days**. Every day one rumor is
shown, everybody secretly bets on it, and the bets are revealed together. The classic 60-day game is still in the
code (`RunConfig.Mode.CLASSIC`) but the menu now starts table runs only.

## One day

1. **Rumor.** One single-stock rumor with a credibility tier: Low (33%), Medium (50%) or High (80%).
2. **Action phase** (secret): bet **BELIEVE** (Buy Call), **BULLSHIT** (Buy Put) or **PASS**; trade; use a skill.
3. **Reveal** (Space): all bets side by side. Double Dan may double here.
4. **Resolve** (Space): the market moves. A rumor is **true** when the real price moved the way it claimed since it was
   shown (unchanged counts as up). Rumors never move prices themselves.

A bet costs 10% of net worth (never more than your cash) and pays `stake x odds` if right, nothing if wrong.
Odds: BELIEVE low x3 / medium x2 / high x1.25, BULLSHIT low x1.5 / medium x2 / high x5. They are fair for the tier
percentages, so the edge comes from reading the market and from the characters.

## Quarters

- **Boss rumor** on days 7, 17, 27: sector or market wide, resolves 3 days later (the review day), stake 30%.
- **Review** after day 10 and 20: nobody is fired any more (`FIRE_LAST_PLACE` is off; the code is still there). The run
  always lasts 30 days and the final standings by net worth decide.
- Active skills are once per quarter and come back at each review.
- The calendar date is hidden during the run and shown on the game over screen (blind market).

## Characters (`data/characters/*.tres`, flags drive the code)

The picker lists them from easy to hard: Saving Son, Goldfish Gus, Hodl Hana, Copilot Cody, Double Dan, Insider Inu.
Portraits are renders of the free Kenney Mini Characters pack (CC0), see `CREDITS.txt` and `tools/kenney_portraits.gd`.

| Character | Rules |
|---|---|
| Insider Inu | One random day per quarter she learns tomorrow's rumor is true; she can FLIP it (publish the opposite). The flipped rumor is stamped planted when it resolves. |
| Copilot Cody | Each day may COPILOT one player: same bet at the normal odds. |
| Double Dan | Once a quarter, after the reveal, doubles his own option. |
| Saving Son | Cash earns 0.5% a day. |
| Goldfish Gus | No credibility, odds or chart, only today's price; winning options pay +0.3 odds. |
| Hodl Hana | Starts with half her cash in the best stock of the pre-game weeks (bought at its low, head start capped at x1.8 by `HODL_MAX_GAIN`), can never sell it; same-sector rumors pay +0.5 odds. |

## Where things are

- `core/table/` rules: `TableSession` (the day loop, saving), `RumorFactory` (deals rumors that fit real prices),
  `RumorTier`, `TableRumor`, `TableBet`, `Seat`, `NpcBrain`, `GenericRumors`, `TableReport`.
- `ui/table/` screen: `table_screen.tscn`, `TableHud` (rumor and bet buttons), `TradePanel` (1/4, 1/2, 3/4, all in,
  sell half, out, swap), `StandingsBar`, `TableOverlay` (reveal and result pop-ups).
- The old order tickets, limit/stop orders, margin and perks are untouched in the core but not shown in table mode.
- Trading fees are a Settings switch for table runs (off by default).
- `tools/table_shot.gd` plays a run in a window and saves screenshots (it backs up and restores your run and profile).

## Not done yet

Perks (switched off in table mode, the characters replace them), the delayed public positions, an Insider tip for the Boss rumor, player-planted rumors
by other characters, real-money odds mode (odds scaled by the actual price move).
