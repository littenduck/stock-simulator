## A table-mode run: you and three computer seats trade the same market for 3 quarters of 10 days.
## Each day one rumor is shown; everybody secretly bets on it (BELIEVE = Buy Call, BULLSHIT = Buy Put, or PASS),
## trades, and may use a skill. Then all bets are revealed together and the day resolves.
## A quarter ends with a review (the last place is fired) and a Boss rumor three days before it.
##
## Flow of one day:  ACTION --reveal()--> REVEALED --advance()--> ACTION of the next day.
## next_day() runs both steps at once (tests, tools, a quick skip).
class_name TableSession
extends GameSession

enum Phase { ACTION, REVEALED, OVER }

const DAILY_RATE := 0.10
const BOSS_RATE := 0.30
const MIN_PREMIUM := 5.0
## Off: the quarter review no longer fires anybody. The code stays so the rule can come back.
const FIRE_LAST_PLACE := false
const HODL_CASH_SHARE := 0.5
## Hodl Hana never starts with more than this multiple of her stock position: the cost is raised to price / this.
const HODL_MAX_GAIN := 1.8

var seats: Array[Seat] = []
var phase: Phase = Phase.ACTION
## Shown to everybody today; resolves tomorrow.
var today_rumor: TableRumor
## Already dealt for tomorrow; only an Insider may know it (and flip it).
var tomorrow_rumor: TableRumor
var boss_rumor: TableRumor
## seat id -> RumorTier.Side, set during the action phase.
var calls: Dictionary = {}
var boss_calls: Dictionary = {}
## Copilot seat id -> seat id it copies today.
var copy_targets: Dictionary = {}
## Insider seat id -> true when the Insider wants to publish the opposite of tomorrow's (true) rumor.
var flip_armed: Dictionary = {}
var bets: Array[TableBet] = []
var boss_bets: Array[TableBet] = []
## Days (one per quarter) on which an Insider learns that tomorrow's rumor is true.
var insider_days: Array[int] = []
var human_fired: bool = false
## What was shown at the last reveal: [{"seat","side","premium","odds","copied_from","boss"}].
var last_reveal: Array[Dictionary] = []

var _events: Array[NewsEventDef] = []
var _roster: Array[CharacterDef] = []
var _recent: Array = []
var _next_rumor_id: int = 1
var _fired_order: Array[int] = []


func _init(p_config: RunConfig, company_pool: Array[CompanyDef], perk_pool: Array[PerkDef], news_pool: Array[NewsEventDef], unlocked: Array[StringName] = [], p_roster: Array[CharacterDef] = []) -> void:
	super._init(p_config, company_pool, perk_pool, news_pool, unlocked)
	_events = news_pool
	_roster = p_roster if not p_roster.is_empty() else _default_roster()


static func _default_roster() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for c in ContentDb.characters():
		if c.table_role:
			out.append(c)
	return out


## Seats the table, deals the first rumors. There is no perk draft in table mode.
func start() -> Array[PerkDef]:
	_seat_players()
	_pick_insider_days()
	for seat in seats:
		if seat.has_flag(&"hodl"):
			_grant_hodl_stock(seat)
	today_rumor = RumorFactory.make_daily(0, market, _events, _recent, _rng, -1, _new_rumor_id())
	today_rumor.activate(0, market)
	_deal_tomorrow()
	return pending_draft


# ---------------------------------------------------------------- queries

func human() -> Seat:
	return seats[0]


func quarter() -> int:
	return mini(day / RunConfig.QUARTER_DAYS + 1, 3)


## Days left in the current quarter, counting today (10 on the first day of a quarter).
func days_left_in_quarter() -> int:
	return RunConfig.QUARTER_DAYS - day % RunConfig.QUARTER_DAYS


func sector_of(symbol: String) -> String:
	var c := market.company_of(symbol)
	return c.sector if c != null else ""


## Real dates stay hidden until the run is over (blind market).
func date_of_day(day_index: int) -> String:
	return super.date_of_day(day_index) if _finished else ""


func daily_bet_of(seat_id: int) -> TableBet:
	for b in bets:
		if b.seat_id == seat_id:
			return b
	return null


func boss_bet_of(seat_id: int) -> TableBet:
	for b in boss_bets:
		if b.seat_id == seat_id:
			return b
	return null


func call_of(seat_id: int) -> int:
	return int(calls.get(seat_id, RumorTier.Side.PASS))


## Premium a seat would pay right now: a share of net worth, never more than its cash.
func premium_for(seat_id: int, boss: bool = false) -> float:
	var seat := seats[seat_id]
	var rate := BOSS_RATE if boss else DAILY_RATE
	var premium := minf(rate * seat.portfolio.net_worth(market), seat.portfolio.cash)
	return premium if premium >= MIN_PREMIUM else 0.0


## Effective odds of a bet, with the character bonuses. A copied bet has the normal odds.
func odds_for(seat: Seat, rumor: TableRumor, side: int) -> float:
	var odds := RumorTier.odds(side, rumor.tier) + seat.mods.bet_odds_bonus
	if seat.mods.locked_symbol != "" and seat.mods.sector_odds_bonus > 0.0 \
			and sector_of(rumor.primary_symbol()) == sector_of(seat.mods.locked_symbol):
		odds += seat.mods.sector_odds_bonus
	return odds


## Seats sorted by rank: the living by net worth, then the fired ones, the latest fired first.
func standings() -> Array[Dictionary]:
	var alive: Array[Seat] = []
	for s in seats:
		if s.alive:
			alive.append(s)
	alive.sort_custom(func(a: Seat, b: Seat) -> bool:
		return a.portfolio.net_worth(market) > b.portfolio.net_worth(market))
	var out: Array[Dictionary] = []
	for s in alive:
		out.append({"seat": s, "net_worth": s.portfolio.net_worth(market)})
	for i in range(_fired_order.size() - 1, -1, -1):
		var s: Seat = seats[_fired_order[i]]
		out.append({"seat": s, "net_worth": s.portfolio.net_worth(market)})
	for i in out.size():
		out[i]["rank"] = i + 1
	return out


func human_rank() -> int:
	for e in standings():
		if (e["seat"] as Seat).is_human:
			return int(e["rank"])
	return seats.size()


## True while the seat is an Insider with a hint about tomorrow's rumor and its skill is unused.
func can_flip(seat_id: int) -> bool:
	var seat := seats[seat_id]
	return seat.alive and seat.has_flag(&"insider") and not seat.skill_used \
			and tomorrow_rumor != null and seat.knowledge.has(tomorrow_rumor.id) and not tomorrow_rumor.planted


## The rumor the human Insider knows to be true (tomorrow's), or null.
func insider_hint() -> TableRumor:
	return tomorrow_rumor if can_flip(0) else null


func can_double(seat_id: int) -> bool:
	var seat := seats[seat_id]
	return phase == Phase.REVEALED and seat.alive and seat.has_flag(&"double_down") and not seat.skill_used \
			and daily_bet_of(seat_id) != null and seat.portfolio.cash >= MIN_PREMIUM


# ---------------------------------------------------------------- actions of the human (seat 0) and shared helpers

func set_call(side: int, seat_id: int = 0) -> void:
	if phase == Phase.ACTION and seats[seat_id].alive:
		calls[seat_id] = side
		copy_targets.erase(seat_id)


func set_boss_call(side: int, seat_id: int = 0) -> void:
	if phase == Phase.ACTION and boss_rumor != null and boss_bet_of(seat_id) == null:
		boss_calls[seat_id] = side


## Copilot: copy another seat's call today (-1 = stop copying).
func set_copy_target(target_id: int, seat_id: int = 0) -> void:
	if phase != Phase.ACTION or not seats[seat_id].has_flag(&"copilot"):
		return
	if target_id < 0 or target_id == seat_id:
		copy_targets.erase(seat_id)
	else:
		copy_targets[seat_id] = target_id


func arm_flip(on: bool, seat_id: int = 0) -> void:
	if phase == Phase.ACTION and (not on or can_flip(seat_id)):
		flip_armed[seat_id] = on


## Buys with a share of the seat's cash (0.25 / 0.5 / 0.75 / 1.0).
func buy_fraction(seat_id: int, symbol: String, fraction: float) -> TradeResult:
	return buy_amount(seat_id, symbol, seats[seat_id].portfolio.cash * clampf(fraction, 0.0, 1.0))


func buy_amount(seat_id: int, symbol: String, amount: float) -> TradeResult:
	var seat := seats[seat_id]
	if not market.has_symbol(symbol):
		return TradeResult.fail(TradeService.ERR_UNKNOWN_SYMBOL)
	var price := market.price_of(symbol)
	var shares := floori(minf(amount, seat.portfolio.cash) / (price * (1.0 + seat.mods.effective_fee_rate())))
	if shares <= 0:
		return TradeResult.fail(TradeService.ERR_NOT_ENOUGH_CASH)
	return _trade(seat, Order.market(Order.Dir.BUY, symbol, shares))


## Sells a share of the position (0.5 = half, 1.0 = everything).
func sell_fraction(seat_id: int, symbol: String, fraction: float) -> TradeResult:
	var seat := seats[seat_id]
	var held := seat.portfolio.shares_of(symbol)
	if held <= 0:
		return TradeResult.fail(TradeService.ERR_INVALID_SHARES)
	var shares := held if fraction >= 0.999 else maxi(1, floori(held * fraction))
	return _trade(seat, Order.market(Order.Dir.SELL, symbol, shares))


## Sells everything in `from_symbol` and puts the proceeds into `to_symbol`.
func swap(seat_id: int, from_symbol: String, to_symbol: String) -> TradeResult:
	if from_symbol == to_symbol:
		return TradeResult.fail(TradeService.ERR_INVALID_SHARES)
	var sold := sell_fraction(seat_id, from_symbol, 1.0)
	if not sold.ok:
		return sold
	return buy_amount(seat_id, to_symbol, sold.shares * sold.price - sold.fee)


## Dan's skill, between the reveal and the result: doubles his daily option.
func double_down(seat_id: int = 0) -> bool:
	if not can_double(seat_id):
		return false
	var seat := seats[seat_id]
	var bet := daily_bet_of(seat_id)
	var extra := minf(bet.premium, seat.portfolio.cash)
	seat.portfolio.cash -= extra
	bet.premium += extra
	bet.doubled = true
	seat.skill_used = true
	return true


# ---------------------------------------------------------------- the day

## Step 1: computer seats decide, everything is locked and revealed together.
func reveal() -> Array[Dictionary]:
	if phase != Phase.ACTION or _finished:
		return last_reveal
	NpcBrain.decide(self, _rng)
	bets.clear()
	last_reveal = []
	for seat in seats:
		if not seat.alive:
			continue
		var side := _final_call(seat)
		var copied_from: int = int(copy_targets.get(seat.id, -1)) if seat.has_flag(&"copilot") else -1
		var bet := _lock_bet(seat, today_rumor, side, DAILY_RATE, copied_from)
		if bet != null:
			bets.append(bet)
		else:
			seat.streak = 0
		last_reveal.append(_reveal_entry(seat, bet, false))
		var boss_side := int(boss_calls.get(seat.id, RumorTier.Side.PASS))
		if boss_rumor != null and boss_side != RumorTier.Side.PASS and boss_bet_of(seat.id) == null:
			var boss_bet := _lock_bet(seat, boss_rumor, boss_side, BOSS_RATE, -1)
			if boss_bet != null:
				boss_bets.append(boss_bet)
				last_reveal.append(_reveal_entry(seat, boss_bet, true))
	phase = Phase.REVEALED
	return last_reveal


## Step 2: the market moves, bets pay out, the review may fire someone, the next rumor is shown.
func advance() -> TableReport:
	if phase == Phase.ACTION:
		reveal()
	var report := TableReport.new()
	if _finished:
		report.day = day
		report.finished = true
		return report
	NpcBrain.after_reveal(self, _rng)
	_apply_flips()
	day += 1
	report.day = day
	market.step()
	_settle(today_rumor, bets, report)
	if boss_rumor != null and boss_rumor.resolve_day == day:
		_settle(boss_rumor, boss_bets, report)
		boss_rumor = null
		boss_bets.clear()
	for seat in seats:
		DailyEffects.apply(seat.portfolio, market, seat.mods)
	report.margin_called = Margin.check(portfolio, market, book, mods)
	if day % RunConfig.QUARTER_DAYS == 0:
		_review(report)
	report.finished = day >= config.trading_days or human_fired
	if report.finished:
		_finished = true
		phase = Phase.OVER
		book.cancel_all()
		return report
	_open_next_day(report)
	return report


## Both steps at once.
func next_day() -> DayReport:
	reveal()
	return advance()


# ---------------------------------------------------------------- internals

## Table mode has no perks: the characters replace them. The perk code stays in the core for the classic game.
func _open_draft() -> void:
	pending_draft = []


func choose_perk(_perk: PerkDef) -> void:
	pass



func _new_rumor_id() -> int:
	_next_rumor_id += 1
	return _next_rumor_id - 1


func _trade(seat: Seat, order: Order) -> TradeResult:
	var res := TradeService.execute(order, market, seat.portfolio, seat.mods)
	if res.ok and seat.is_human:
		_log_trade(res)
	return res


func _seat_players() -> void:
	seats = []
	var human_seat := _make_seat(0, config.character)
	human_seat.is_human = true
	human_seat.portfolio = portfolio
	human_seat.mods = mods
	seats.append(human_seat)
	var others: Array[CharacterDef] = []
	for c in _roster:
		if c.id != config.character.id:
			others.append(c)
	others.sort_custom(func(a: CharacterDef, b: CharacterDef) -> bool: return String(a.id) < String(b.id))
	for i in range(others.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := others[i]
		others[i] = others[j]
		others[j] = tmp
	for i in mini(RunConfig.TABLE_SEATS - 1, others.size()):
		var seat := _make_seat(i + 1, others[i])
		var cfg := RunConfig.make_table(others[i], config.seed_value, config.fees_enabled)
		seat.mods = ModifiersBuilder.build(cfg, [])
		seat.portfolio = Portfolio.new(others[i].start_cash)
		seats.append(seat)


func _make_seat(id: int, character: CharacterDef) -> Seat:
	var seat := Seat.new()
	seat.id = id
	seat.character = character
	return seat


## One random day per quarter on which an Insider learns tomorrow's rumor is true. Needs a known future.
func _pick_insider_days() -> void:
	insider_days = []
	var symbols := market.symbols()
	if symbols.is_empty() or is_nan(market.peek_return(symbols[0], 0, 1)):
		return
	var last_day := config.trading_days - 2
	for q in 3:
		var first := q * RunConfig.QUARTER_DAYS
		insider_days.append(_rng.randi_range(first, mini(first + RunConfig.QUARTER_DAYS - 2, last_day)))


## Hodl Hana: half the cash is already in the stock that rose most in the pre-game weeks, bought at its low.
func _grant_hodl_stock(seat: Seat) -> void:
	var best := ""
	var best_low := 0.0
	var best_ratio := 0.0
	for symbol in market.symbols():
		var closes := market.history_of(symbol)
		var look := market.lookback_of(symbol)
		if look < 2:
			continue
		var low := closes[0]
		for i in range(0, look + 1):
			low = minf(low, closes[i])
		var ratio := closes[look] / maxf(low, 0.0001)
		if ratio > best_ratio:
			best_ratio = ratio
			best = symbol
			best_low = low
	if best == "":
		best = market.symbols()[0]
		best_low = market.price_of(best) * 0.7
	best_low = maxf(best_low, market.price_of(best) / HODL_MAX_GAIN)
	var shares := floori(seat.character.start_cash * HODL_CASH_SHARE / best_low)
	seat.portfolio.apply_fill(best, shares, best_low, 0.0)
	seat.mods.locked_symbol = best


## Deals the rumor for the day after today. On an Insider day it is true, and the Insider is told.
func _deal_tomorrow() -> void:
	if day + 1 > config.trading_days - 1:
		tomorrow_rumor = null
		return
	var insider_day := day in insider_days
	tomorrow_rumor = RumorFactory.make_daily(day + 1, market, _events, _recent, _rng, 1 if insider_day else -1, _new_rumor_id())
	if insider_day:
		for seat in seats:
			if seat.alive and seat.has_flag(&"insider"):
				seat.knowledge[tomorrow_rumor.id] = true


func _apply_flips() -> void:
	for seat in seats:
		if flip_armed.get(seat.id, false) and can_flip(seat.id):
			var original := tomorrow_rumor
			tomorrow_rumor = RumorFactory.flipped(original, _events, _recent, _rng, _new_rumor_id())
			seat.knowledge.erase(original.id)
			seat.knowledge[tomorrow_rumor.id] = false
			seat.skill_used = true
	flip_armed = {}


## The side a seat really plays: a Copilot copies its target's call.
func _final_call(seat: Seat) -> int:
	if seat.has_flag(&"copilot") and copy_targets.has(seat.id):
		var target := int(copy_targets[seat.id])
		if target >= 0 and target < seats.size() and seats[target].alive and not seats[target].has_flag(&"copilot"):
			return call_of(target)
		return RumorTier.Side.PASS
	return call_of(seat.id)


func _lock_bet(seat: Seat, rumor: TableRumor, side: int, rate: float, copied_from: int) -> TableBet:
	if side == RumorTier.Side.PASS or rumor == null:
		return null
	var premium := premium_for(seat.id, rate == BOSS_RATE)
	if premium <= 0.0:
		return null
	seat.portfolio.cash -= premium
	var bet := TableBet.new()
	bet.seat_id = seat.id
	bet.rumor_id = rumor.id
	bet.side = side
	bet.premium = premium
	bet.copied_from = copied_from
	bet.odds = odds_for(seat, rumor, side)
	return bet


func _reveal_entry(seat: Seat, bet: TableBet, boss: bool) -> Dictionary:
	return {
		"seat": seat.id, "boss": boss,
		"side": bet.side if bet != null else RumorTier.Side.PASS,
		"premium": bet.premium if bet != null else 0.0,
		"odds": bet.odds if bet != null else 0.0,
		"copied_from": bet.copied_from if bet != null else -1,
	}


func _settle(rumor: TableRumor, list: Array[TableBet], report: TableReport) -> void:
	rumor.came_true = rumor.evaluate(market)
	rumor.resolved = true
	report.resolved_table.append(rumor)
	for b in list:
		var seat := seats[b.seat_id]
		var pay := b.payout(rumor.came_true)
		seat.portfolio.cash += pay
		seat.streak = seat.streak + 1 if pay > 0.0 else 0
		report.payouts.append({
			"seat": b.seat_id, "rumor": rumor.id, "boss": rumor.is_boss(), "side": b.side,
			"premium": b.premium, "payout": pay, "won": pay > 0.0,
		})


## Quarter review: skills reset, and (when FIRE_LAST_PLACE is on) the last place is fired after the first two quarters.
func _review(report: TableReport) -> void:
	report.quarter_ended = day / RunConfig.QUARTER_DAYS
	for seat in seats:
		seat.skill_used = false
	if not FIRE_LAST_PLACE or day >= config.trading_days:
		return
	var worst: Seat = null
	for seat in seats:
		if seat.alive and (worst == null or seat.portfolio.net_worth(market) < worst.portfolio.net_worth(market)):
			worst = seat
	if worst == null:
		return
	worst.alive = false
	worst.fired_day = day
	_fired_order.append(worst.id)
	report.fired_seats.append(worst.id)
	if worst.is_human:
		human_fired = true
		report.human_fired = true


## The tomorrow rumor becomes today's; a new one is dealt; a Boss rumor may start.
func _open_next_day(report: TableReport) -> void:
	today_rumor = tomorrow_rumor
	today_rumor.activate(day, market)
	_deal_tomorrow()
	if day % RunConfig.QUARTER_DAYS == RunConfig.QUARTER_DAYS - TableRumor.BOSS_DAYS:
		boss_rumor = RumorFactory.make_boss(day, market, _events, _recent, _rng, _new_rumor_id())
		if boss_rumor != null:
			boss_rumor.activate(day, market)
			report.boss_announced = boss_rumor
	calls = {}
	boss_calls = {}
	copy_targets = {}
	phase = Phase.ACTION


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	var d := super.to_dict()
	var seat_data: Array = []
	for s in seats:
		seat_data.append(s.to_dict())
	d["table"] = {
		"phase": int(phase), "seats": seat_data,
		"today": today_rumor.to_dict() if today_rumor != null else {},
		"tomorrow": tomorrow_rumor.to_dict() if tomorrow_rumor != null else {},
		"boss": boss_rumor.to_dict() if boss_rumor != null else {},
		"calls": calls.duplicate(), "boss_calls": boss_calls.duplicate(), "copy_targets": copy_targets.duplicate(),
		"flip_armed": flip_armed.duplicate(),
		"bets": bets.map(func(b: TableBet) -> Dictionary: return b.to_dict()),
		"boss_bets": boss_bets.map(func(b: TableBet) -> Dictionary: return b.to_dict()),
		"insider_days": insider_days.duplicate(), "recent": _recent.duplicate(), "next_id": _next_rumor_id,
		"fired_order": _fired_order.duplicate(), "human_fired": human_fired,
	}
	return d


static func from_dict(data: Dictionary, config: RunConfig, company_pool: Array[CompanyDef], perk_pool: Array[PerkDef], news_pool: Array[NewsEventDef]) -> GameSession:
	var d := migrate(data)
	if d.is_empty() or config == null or not d.has("table"):
		return null
	var s := TableSession.new(config, company_pool, perk_pool, news_pool)
	if not s._restore(d, config, company_pool, perk_pool):
		return null
	s._restore_table(d["table"])
	return s


func _restore_table(t: Dictionary) -> void:
	phase = int(t.get("phase", 0)) as Phase
	seats = []
	for sd in t.get("seats", []):
		var seat := _make_seat(int(sd["id"]), ContentDb.character_by_id(StringName(String(sd["character"]))))
		seat.is_human = bool(sd.get("human", false))
		seat.alive = bool(sd.get("alive", true))
		seat.fired_day = int(sd.get("fired_day", -1))
		seat.streak = int(sd.get("streak", 0))
		seat.skill_used = bool(sd.get("skill_used", false))
		for k in (sd.get("knowledge", {}) as Dictionary):
			seat.knowledge[int(k)] = bool(sd["knowledge"][k])
		if seat.is_human:
			seat.portfolio = portfolio
			seat.mods = mods
		else:
			seat.portfolio = Portfolio.new()
			seat.portfolio.load_dict(sd.get("portfolio", {}))
			seat.mods = ModifiersBuilder.build(RunConfig.make_table(seat.character, config.seed_value, config.fees_enabled), [])
		seat.mods.locked_symbol = String(sd.get("locked", ""))
		seats.append(seat)
	today_rumor = _rumor_or_null(t.get("today", {}))
	tomorrow_rumor = _rumor_or_null(t.get("tomorrow", {}))
	boss_rumor = _rumor_or_null(t.get("boss", {}))
	calls = _int_dict(t.get("calls", {}))
	boss_calls = _int_dict(t.get("boss_calls", {}))
	copy_targets = _int_dict(t.get("copy_targets", {}))
	flip_armed = _int_dict(t.get("flip_armed", {}))
	bets.assign((t.get("bets", []) as Array).map(func(x: Dictionary) -> TableBet: return TableBet.from_dict(x)))
	boss_bets.assign((t.get("boss_bets", []) as Array).map(func(x: Dictionary) -> TableBet: return TableBet.from_dict(x)))
	insider_days.assign((t.get("insider_days", []) as Array).map(func(x: Variant) -> int: return int(x)))
	_recent = (t.get("recent", []) as Array).duplicate()
	_next_rumor_id = int(t.get("next_id", 1))
	_fired_order.assign((t.get("fired_order", []) as Array).map(func(x: Variant) -> int: return int(x)))
	human_fired = bool(t.get("human_fired", false))


static func _rumor_or_null(d: Dictionary) -> TableRumor:
	return TableRumor.from_dict(d) if not d.is_empty() else null


static func _int_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[int(k)] = src[k]
	return out
