## All state and rules of one run. Pure logic: no scene tree, no autoloads, no global RNG.
## CONTRACT: public signatures frozen. Owner of the body: session-integration.
## Fixed order of next_day(): docs/implementation-plan.md section 13.9.
class_name GameSession
extends RefCounted

const SAVE_VERSION := 1
const SECTOR_FAN_BONUS := 0.15
## Real trading days shown as chart history before day 0 (clamped by the start of the data).
const PRE_GAME_DAYS := 30

var config: RunConfig
var day: int = 0
var market: MarketSim
var portfolio: Portfolio
var book: OrderBook
var news: NewsDirector
var mods: RunModifiers
var owned_perks: Array[PerkDef] = []
## Perk options waiting for choose_perk(); empty when no draft is open.
var pending_draft: Array[PerkDef] = []
## One entry per executed trade: {"day","side","symbol","shares","price","fee"}.
var trade_log: Array[Dictionary] = []
## Row of data/market/history.csv that is day 0 of this run (same calendar window for every company);
## -1 = no real data (pure GBM run, e.g. loaded from an old save or missing history file).
var window_start: int = -1

var _rng := RandomNumberGenerator.new()
var _perk_pool: Array[PerkDef] = []
var _drafter: PerkDrafter
var _finished: bool = false
var _sector_fan_sector: String = ""
var _history: HistoryData


func _init(p_config: RunConfig, company_pool: Array[CompanyDef], perk_pool: Array[PerkDef], news_pool: Array[NewsEventDef], unlocked: Array[StringName] = []) -> void:
	config = p_config
	_rng.seed = p_config.seed_value
	_perk_pool = perk_pool
	_drafter = PerkDrafter.new(perk_pool, _rng)
	mods = ModifiersBuilder.build(p_config, owned_perks)
	_history = HistoryData.default()
	# Companies first, then a window in which every drawn company has enough real data (late listings such as
	# SpaceX only fit recent windows), so each company is equally likely to appear.
	var pool := _with_enough_history(company_pool, _history)
	var drawn := MarketSim.draw_companies(pool, RunConfig.COMPANIES_PER_RUN, _rng, unlocked)
	_ensure_small_sectors(drawn, pool, unlocked, _rng)
	window_start = _pick_window(_history, _rng, drawn)
	_build_market(drawn)
	market.volatility_mult = mods.volatility_mult
	portfolio = Portfolio.new(p_config.character.start_cash)
	book = OrderBook.new()
	news = NewsDirector.new(news_pool, _rng)


## Sectors with few companies; every run gets at least one of them so their rumors always matter.
const GUARANTEED_SECTORS: Array[String] = ["space", "finance"]


## Companies whose real data covers lookback + a full run. A company without real data stays (GBM fallback).
static func _with_enough_history(pool: Array[CompanyDef], history: HistoryData) -> Array[CompanyDef]:
	if history == null:
		return pool
	var out: Array[CompanyDef] = []
	for c in pool:
		if c.history_key == "" or not history.has_key(c.history_key) \
				or history.first_row(c.history_key) + PRE_GAME_DAYS <= history.row_count() - 1 - RunConfig.TRADING_DAYS:
			out.append(c)
	return out


## If the draw has no company of GUARANTEED_SECTORS, swaps the last drawn one for a random eligible one.
static func _ensure_small_sectors(drawn: Array[CompanyDef], pool: Array[CompanyDef], unlocked: Array[StringName], rng: RandomNumberGenerator) -> void:
	if drawn.size() < 2:
		return
	for c in drawn:
		if c.sector in GUARANTEED_SECTORS:
			return
	var candidates: Array[CompanyDef] = []
	for c in pool:
		if c.sector in GUARANTEED_SECTORS and (c.unlock_id == &"" or c.unlock_id in unlocked):
			candidates.append(c)
	candidates.sort_custom(func(a: CompanyDef, b: CompanyDef) -> bool: return a.symbol < b.symbol)
	if not candidates.is_empty():
		drawn[drawn.size() - 1] = candidates[rng.randi_range(0, candidates.size() - 1)]


## Deterministic start row from the run rng: leaves PRE_GAME_DAYS of real data before it for every drawn company
## and TRADING_DAYS rows after it. Returns -1 when there is no (or too little) history.
static func _pick_window(history: HistoryData, rng: RandomNumberGenerator, companies: Array[CompanyDef]) -> int:
	if history == null:
		return -1
	var lo := PRE_GAME_DAYS
	for c in companies:
		if c.history_key != "" and history.has_key(c.history_key):
			lo = maxi(lo, history.first_row(c.history_key) + PRE_GAME_DAYS)
	var hi := history.row_count() - 1 - RunConfig.TRADING_DAYS
	if hi < lo:
		return -1
	return rng.randi_range(lo, hi)


## Creates the MarketSim for `companies` using the real-history model when a window is set, GBM otherwise,
## and loads the real closes (plus lookback candles) as the starting series.
func _build_market(companies: Array[CompanyDef]) -> void:
	if window_start >= 0 and _history != null:
		market = MarketSim.new(companies, HistoricalPriceModel.new(_history, window_start), _rng)
		for c in companies:
			if c.history_key == "" or not _history.has_key(c.history_key):
				continue
			var bars: Array = []
			for row in range(window_start - PRE_GAME_DAYS, window_start + 1):
				var b := _history.bar(c.history_key, row)
				bars.append(PackedFloat32Array([b[0], b[1], b[2], b[3]]))
			market.init_series(c.symbol, bars)
	else:
		market = MarketSim.new(companies, GbmPriceModel.new(), _rng)
	market.volatility_mult = mods.volatility_mult if mods != null else 1.0


## ISO date (YYYY-MM-DD) of a trading day of this run (0 = start date; negative = pre-game lookback).
## "" when the run has no real calendar (GBM fallback).
func date_of_day(day_index: int) -> String:
	if window_start < 0 or _history == null:
		return ""
	return _history.date_at(window_start + clampi(day_index, -PRE_GAME_DAYS, RunConfig.TRADING_DAYS))


## Opens the day-0 perk draft and returns its options.
func start() -> Array[PerkDef]:
	_open_draft()
	return pending_draft


## Advances one trading day. Do not call while pending_draft is non-empty.
func next_day() -> DayReport:
	var report := DayReport.new()
	if _finished:
		report.day = day
		report.finished = true
		return report
	# 1. day counter
	day += 1
	report.day = day
	# 2. rumors due today change the market (true: full impact; false: small reverse impact)
	for r in news.due(day):
		r.resolved = true
		market.apply_news(r.event, r.impact_scale())
		report.resolved_rumors.append(r)
	# 3. new closing prices
	market.step()
	# 4. pending limit / stop orders
	for res in book.process(market, portfolio, mods):
		report.fills.append(res)
		if res.ok:
			_log_trade(res)
	# 5. interest, borrow fee, dividends, Diversifier
	DailyEffects.apply(portfolio, market, mods)
	# 6. margin check (forced liquidation)
	report.margin_called = Margin.check(portfolio, market, book, mods)
	report.finished = day >= RunConfig.TRADING_DAYS
	# 7. new rumors
	if not report.finished:
		report.new_rumors = news.roll(day, mods, market)
	# 8. perk draft
	if not report.finished and day % RunConfig.DRAFT_EVERY_DAYS == 0:
		_open_draft()
		report.draft_offer = pending_draft.duplicate()
	# 9. settlement
	if report.finished:
		book.cancel_all()
		_finished = true
	return report


## MARKET orders execute immediately; LIMIT/STOP go into the order book.
func submit(order: Order) -> TradeResult:
	if order == null or _finished:
		return TradeResult.fail(TradeService.ERR_INVALID_SHARES, order)
	if order.kind == Order.Kind.MARKET:
		var res := TradeService.execute(order, market, portfolio, mods)
		if res.ok:
			_log_trade(res)
		return res
	if not market.has_symbol(order.symbol):
		return TradeResult.fail(TradeService.ERR_UNKNOWN_SYMBOL, order)
	if book.place(order) == 0:
		return TradeResult.fail(TradeService.ERR_INVALID_SHARES, order)
	return TradeResult.queued(order)


func cancel_order(order_id: int) -> bool:
	return book.cancel(order_id)


func choose_perk(perk: PerkDef) -> void:
	if perk == null:
		return
	owned_perks.append(perk)
	pending_draft.clear()
	if perk.flags.has(&"sector_fan") and _sector_fan_sector == "":
		var sectors := market.sectors()
		if not sectors.is_empty():
			_sector_fan_sector = sectors[_rng.randi_range(0, sectors.size() - 1)]
	_rebuild_mods()


func net_worth() -> float:
	return portfolio.net_worth(market)


## Final score = net worth * mods.score_mult.
func score() -> float:
	return net_worth() * mods.score_mult


func is_finished() -> bool:
	return _finished


func to_dict() -> Dictionary:
	var perk_ids: Array = []
	for p in owned_perks:
		perk_ids.append(String(p.id))
	var draft_ids: Array = []
	for p in pending_draft:
		draft_ids.append(String(p.id))
	return {
		"version": SAVE_VERSION,
		"day": day,
		"seed": config.seed_value,
		"character": String(config.character.id),
		"difficulty": config.difficulty,
		"margin_enabled": config.margin_enabled,
		"rng_seed": str(_rng.seed),
		"rng_state": str(_rng.state),
		"companies": market.symbols(),
		"perks": perk_ids,
		"pending_draft": draft_ids,
		"sector_fan_sector": _sector_fan_sector,
		"iron_hands_used": mods.iron_hands_used,
		"finished": _finished,
		"window_start": window_start,
		"start_date": date_of_day(0),
		"market": market.to_dict(),
		"portfolio": portfolio.to_dict(),
		"book": book.to_dict(),
		"news": news.to_dict(),
		"trade_log": trade_log.duplicate(true),
	}


## Brings an older save dictionary up to SAVE_VERSION. Returns {} if it cannot be used.
static func migrate(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var v := int(data.get("version", 0))
	if v < 1 or v > SAVE_VERSION:
		return {}
	return data


## Rebuilds the RunConfig stored in a save (character looked up through ContentDb).
static func config_from_dict(data: Dictionary) -> RunConfig:
	var character := ContentDb.character_by_id(StringName(String(data.get("character", ""))))
	if character == null:
		return null
	var c := RunConfig.make(character, int(data.get("difficulty", 1)), int(data.get("seed", 1)), bool(data.get("margin_enabled", false)))
	return c


static func _window_has_data(history: HistoryData, companies: Array[CompanyDef], ws: int) -> bool:
	for c in companies:
		if c.history_key != "" and history.has_key(c.history_key) and history.first_row(c.history_key) > ws - PRE_GAME_DAYS:
			return false
	return true


## Rebuilds a session from a saved dictionary using the same content pools.
static func from_dict(data: Dictionary, config: RunConfig, company_pool: Array[CompanyDef], perk_pool: Array[PerkDef], news_pool: Array[NewsEventDef]) -> GameSession:
	var d := migrate(data)
	if d.is_empty() or config == null:
		return null
	var s := GameSession.new(config, company_pool, perk_pool, news_pool)
	# Same companies as the saved run (the drawn set depended on the profile's unlocks).
	var drawn: Array[CompanyDef] = []
	for sym in d.get("companies", []):
		for c in company_pool:
			if c.symbol == String(sym):
				drawn.append(c)
				break
	if drawn.is_empty():
		return null
	# Saves from before real history have no window: they continue as GBM runs (market.load_dict synthesizes candles).
	var ws := int(d.get("window_start", -1))
	if s._history == null or ws < PRE_GAME_DAYS or ws + RunConfig.TRADING_DAYS >= s._history.row_count() \
			or not _window_has_data(s._history, drawn, ws) \
			or (d.has("start_date") and s._history.date_at(ws) != String(d["start_date"])):
		ws = -1
	s.window_start = ws
	s._build_market(drawn)
	s._sector_fan_sector = String(d.get("sector_fan_sector", ""))
	for id in d.get("perks", []):
		var p := _find_perk(perk_pool, StringName(String(id)))
		if p != null:
			s.owned_perks.append(p)
	for id in d.get("pending_draft", []):
		var p := _find_perk(perk_pool, StringName(String(id)))
		if p != null:
			s.pending_draft.append(p)
	s.mods = ModifiersBuilder.build(config, s.owned_perks)
	s.mods.iron_hands_used = bool(d.get("iron_hands_used", false))
	s._apply_sector_fan()
	s.market.volatility_mult = s.mods.volatility_mult
	s.market.load_dict(d.get("market", {}))
	s.portfolio.load_dict(d.get("portfolio", {}))
	s.book.load_dict(d.get("book", {}))
	s.news.load_dict(d.get("news", {}))
	s.trade_log.assign(d.get("trade_log", []))
	s.day = int(d.get("day", 0))
	s._finished = bool(d.get("finished", false))
	s._rng.seed = int(String(d.get("rng_seed", str(config.seed_value))))
	s._rng.state = int(String(d.get("rng_state", "0")))
	return s


static func _find_perk(pool: Array[PerkDef], id: StringName) -> PerkDef:
	for p in pool:
		if p.id == id:
			return p
	return null


func _open_draft() -> void:
	pending_draft = _drafter.offer(owned_perks, mods.draft_choices)


func _rebuild_mods() -> void:
	var used := mods.iron_hands_used
	mods = ModifiersBuilder.build(config, owned_perks)
	mods.iron_hands_used = used
	_apply_sector_fan()
	market.volatility_mult = mods.volatility_mult


func _apply_sector_fan() -> void:
	if _sector_fan_sector != "":
		mods.sector_truth_bonus[_sector_fan_sector] = SECTOR_FAN_BONUS


func _log_trade(res: TradeResult) -> void:
	var o := res.order
	trade_log.append({
		"day": day,
		"side": "buy" if o.side == Order.Dir.BUY else "sell",
		"symbol": o.symbol,
		"shares": res.shares,
		"price": res.price,
		"fee": res.fee,
	})
