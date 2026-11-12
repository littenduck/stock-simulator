## All state and rules of one run. Pure logic: no scene tree, no autoloads, no global RNG.
## CONTRACT: public signatures frozen. Owner of the body: session-integration.
## Fixed order of next_day(): docs/implementation-plan.md section 13.9.
## STUB: day counter only.
class_name GameSession
extends RefCounted

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

var _rng := RandomNumberGenerator.new()
var _perk_pool: Array[PerkDef] = []
var _finished: bool = false


func _init(p_config: RunConfig, company_pool: Array[CompanyDef], perk_pool: Array[PerkDef], news_pool: Array[NewsEventDef], unlocked: Array[StringName] = []) -> void:
	config = p_config
	_rng.seed = p_config.seed_value
	_perk_pool = perk_pool
	mods = ModifiersBuilder.build(p_config, owned_perks)
	market = MarketSim.new(MarketSim.draw_companies(company_pool, RunConfig.COMPANIES_PER_RUN, _rng, unlocked), GbmPriceModel.new(), _rng)
	portfolio = Portfolio.new(p_config.character.start_cash)
	book = OrderBook.new()
	news = NewsDirector.new(news_pool, _rng)


## Opens the day-0 perk draft and returns its options.
func start() -> Array[PerkDef]:
	return pending_draft


## Advances one trading day. Do not call while pending_draft is non-empty.
func next_day() -> DayReport:
	day += 1
	var report := DayReport.new()
	report.day = day
	report.finished = day >= RunConfig.TRADING_DAYS
	_finished = report.finished
	return report


## MARKET orders execute immediately; LIMIT/STOP go into the order book.
func submit(order: Order) -> TradeResult:
	return TradeService.execute(order, market, portfolio, mods)


func cancel_order(order_id: int) -> bool:
	return book.cancel(order_id)


func choose_perk(perk: PerkDef) -> void:
	owned_perks.append(perk)
	pending_draft.clear()
	mods = ModifiersBuilder.build(config, owned_perks)


func net_worth() -> float:
	return portfolio.net_worth(market)


## Final score = net worth * mods.score_mult.
func score() -> float:
	return net_worth() * mods.score_mult


func is_finished() -> bool:
	return _finished


func to_dict() -> Dictionary:
	return {"version": 1, "day": day, "seed": config.seed_value}


## Rebuilds a session from a saved dictionary using the same content pools.
static func from_dict(_data: Dictionary, _config: RunConfig, _company_pool: Array[CompanyDef], _perk_pool: Array[PerkDef], _news_pool: Array[NewsEventDef]) -> GameSession:
	push_warning("STUB GameSession.from_dict")
	return null
