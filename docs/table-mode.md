# Table mode (branch feat/05-characters)

You and three computer seats trade the same market for **30 days = 3 quarters of 10 days**. Every day one rumor is
shown, everybody secretly bets on it, and the bets are revealed together. The classic 60-day game is still in the
code (`RunConfig.Mode.CLASSIC`) but the menu now starts table runs only.

## One turn (four steps, shown as dots in the bar at the bottom)

1. **Pre-market.** The new day opens at its new price. The verdict on yesterday's rumor lands (stamp, payouts, ranking),
   then today's news window pops up and flies into the rumor feed.
2. **Market open.** The only step that waits for you: buy and sell, open the rumor card (click the feed entry or the blue
   Choose button) and pick **BELIEVE** (Buy Call), **BULLSHIT** (Buy Put) or **PASS**, use your skill. Then press **Next**
   (Space is the shortcut). Pressing it with no call counts as PASS.
3. **After-market.** Everybody's bets are revealed together (manual by default: press Next (or Space) to reveal; a setting makes it automatic). Only skills work now,
   such as Double Down. Trading is closed, so nobody can trade on what they just saw.
4. **Next day.** The price moves and the day turns over, back to step 1.

A rumor is **true** when the real price moved the way it claimed between the day it was shown and the next day (the Boss
rumor: three days later). Rumors never move prices themselves.

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

The picker numbers them: 01 Saving Son, 02 Double Dan, 03 Hodl Hana, 04 Goldfish Gus, 05 Copilot Cody, 06 Insider Inu. There is no easy / hard label.
Portraits are renders of the free Kenney Mini Characters pack (CC0): the stock models, except Saving Son (lighter skin) and Goldfish Gus (painted goldfish orange with red fins). See `CREDITS.txt` and `tools/kenney_portraits.gd`.

Every skill belongs to a window of the day (`core/table/table_skills.gd`). Outside its window it cannot be used, and
when it takes effect in front of the table it plays its own animation (`ui/table/skill_fx.gd`) while everybody waits;
Space skips it. Hidden skills (the Insider's) are only seen by their owner until their effect comes out.

| Character | Window | Rules | Animation |
|---|---|---|---|
| Insider Inu | Pre-market | Once a quarter, on one random day, she learns tomorrow's rumor is TRUE (hidden). | An eye opens (only she sees it). |
| | Market open | Once a quarter she can FLIP that rumor (hidden). Next day it is published as the opposite and stamped planted when it resolves; nobody learns by whom. | The planted stamp at the verdict. |
| Copilot Cody | Market open | Every day he may COPILOT one rival; after-market he holds the same option at the normal odds. | A beam runs from the copied seat to Cody. |
| Double Dan | After-market | Once a quarter, when the bets are revealed, he doubles his own option. | A huge x2 slams down. |
| Saving Son | Next day | His cash earns 0.5% interest. | Coins drift up. |
| Goldfish Gus | Market open / After-market | No credibility tiers and no chart, only today's price; his options pay +0.3 odds. | Bubbles rise. |
| Hodl Hana | Pre-market (day 1) / After-market | Half her cash is already in the best stock of the pre-game weeks (bought at its low, head start capped at x1.8 by `HODL_MAX_GAIN`), never sold; options in its sector pay +0.5 odds. | Diamonds rain down; sparkles for the sector bonus. |

The four windows are pre-market (news), market open (trade and call), after-market (the reveal) and next day (the
market moves). `TableSession.window` tracks them; in a real game (`strict_windows`) trading, calls and skills only work
in their own window.

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

## The opening of a new run

A new run does not show everything at once; Space skips it, and the "Opening animation" switch in Settings turns it
off (on by default). Continued runs skip it.

0. **The rivals, on the character screen.** After you press Start, a frame runs over the six characters like an arcade
   pick, fast and then slower, and lands on the three rivals one after another. Only then does the game open
   (`ui/table/rival_roll.gd`; the session is made first with `GameManager.prepare_run`, the screen opens with `enter_run`).

The top bar, the standings and the turn bar are always on screen. The three boards in between are thrown down one by
one, each with a thud, and then filled in:

1. **The four players, 3 seconds each.** A live 3D character (Kenney Mini Characters, `ui/theme/models/`) makes its
   move, then its passive and active skills are stuck on.
2. **The left board** drops in; the same arcade pick runs over all 30 companies and the six land in its list.
3. **The middle board** (chart and trade are one board) drops in; the first stock's 30 days are drawn bar by bar.
4. **The right board** drops in empty; the first news comes in and is pasted onto it.

Every skill animation waits for Space (or a click) before the next one plays, so the text can be read.

Code: `ui/table/table_opening.gd` (the director), `slot_pick.gd` (the arcade pick), `character_model.gd` (3D models).

Every time the turn moves to a new step a banner sweeps across the screen ("PRE-MARKET", "MARKET OPEN", "AFTER-MARKET", "NEXT DAY") with a line about what happens now (`ui/table/step_banner.gd`).

## The feed (right board)

Newest first, three kinds of entries: **rumors** (today's rumor with your call, the open Boss rumor under it, then every
resolved rumor with its stamp), **summary** (one card per day: what everybody played, what it paid) and **skills** (a line
whenever a public skill was played; the Insider's hidden skills never show). The log lives in `TableSession.feed_log`
and is saved with the run.

## The night between two days

After the verdict the screen turns to night (`ui/table/day_transition.gd`): your net worth rolls to its new value, a
face-down card for the new rumor arrives (its border colour is the credibility; Goldfish Gus sees grey) with two
countdowns (the Boss rumor, the end of the quarter), the moon sets and the sun comes up and the day counter flips. The card
stays face down: what the rumor is about is only told the next morning with the news. The first three days play the whole
scene (about 4 seconds), later days a short version (about 3). Space skips it. The four players then stretch awake.

## Quarter board and podium

At the end of quarters 1 and 2 `RankingBoard` shows the four players in last quarter's order, rolls their net worth and
swaps them place by place; a new leader gets the crown. After day 30 `Podium` builds a podium from the bottom up with the
3D characters (the winner jumps, a crown and confetti; YOU WIN when it is you) and only then does the game-over dialog open.

## Sounds

All sounds come from the four Kenney packs in `audio/`. `AudioFeedback.SFX` maps an event to several files; each play
picks one (never the same twice in a row) and bends the pitch a little. Every skill, banner and board has its own family.

## Languages

English and Simplified Chinese; the buttons "EN" and "中" are in the bottom-left of the main menu, at the top of Settings
and in the top bar during a game, and the choice is saved (`GameSettings.language()`, first start follows the computer's
language). A switch rebuilds the screen you are on, because most text is written into the widgets when they are built; it
waits while an animation or pop-up is open. Texts are in `localization/*.csv` (columns `keys,en,zh`); to translate a new
string add the row with both columns and run `godot --headless --path . --import`. The font (Fusion Pixel 12px, OFL) draws
both languages (`ui/theme/fonts/`, licences next to it); every Chinese glyph in the tables was checked to exist in it.

