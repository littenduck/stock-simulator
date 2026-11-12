## Runtime market: current prices, history and active news shocks for the companies of one run.
## CONTRACT: public signatures frozen. Owner of the body: market-engine.
## STUB: prices are flat; step() and apply_news() do nothing yet.
class_name MarketSim
extends RefCounted

const MAX_HISTORY := 80

var _companies: Array[CompanyDef] = []
var _model: PriceModel
var _rng: RandomNumberGenerator
var _prices: Dictionary = {}     ## symbol -> float
var _history: Dictionary = {}    ## symbol -> PackedFloat32Array


func _init(companies: Array[CompanyDef], model: PriceModel, rng: RandomNumberGenerator) -> void:
	_companies = companies
	_model = model
	_rng = rng
	for c in companies:
		_prices[c.symbol] = c.start_price
		_history[c.symbol] = PackedFloat32Array([c.start_price])


## Draws `count` companies from `pool` using rng (deterministic for a given seed).
## Only companies whose unlock_id is empty or in `unlocked` are eligible.
static func draw_companies(pool: Array[CompanyDef], count: int, rng: RandomNumberGenerator, unlocked: Array[StringName] = []) -> Array[CompanyDef]:
	var eligible: Array[CompanyDef] = []
	for c in pool:
		if c.unlock_id == &"" or c.unlock_id in unlocked:
			eligible.append(c)
	return eligible.slice(0, count)


## Symbols in a stable order (same as the companies passed to _init).
func symbols() -> Array[String]:
	var out: Array[String] = []
	for c in _companies:
		out.append(c.symbol)
	return out


func sectors() -> Array[String]:
	var out: Array[String] = []
	for c in _companies:
		if c.sector not in out:
			out.append(c.sector)
	return out


func has_symbol(symbol: String) -> bool:
	return _prices.has(symbol)


func company_of(symbol: String) -> CompanyDef:
	for c in _companies:
		if c.symbol == symbol:
			return c
	return null


func price_of(symbol: String) -> float:
	return _prices.get(symbol, 0.0)


## Closing prices, oldest first, including today.
func history_of(symbol: String) -> PackedFloat32Array:
	return _history.get(symbol, PackedFloat32Array())


## Today's change vs yesterday as a fraction (0.02 = +2%).
func day_change(symbol: String) -> float:
	var h: PackedFloat32Array = history_of(symbol)
	if h.size() < 2:
		return 0.0
	return h[h.size() - 1] / h[h.size() - 2] - 1.0


## Test/tool seam: force a price (also overwrites today's history entry).
func set_price(symbol: String, price: float) -> void:
	_prices[symbol] = price
	var h: PackedFloat32Array = _history[symbol]
	h[h.size() - 1] = price
	_history[symbol] = h


## Registers a news shock. scale = 1.0 for a true rumor, event.denial_impact_ratio for a debunked one.
func apply_news(_event: NewsEventDef, _scale: float = 1.0) -> void:
	pass


## Advances one trading day.
func step() -> void:
	pass


func to_dict() -> Dictionary:
	return {"prices": _prices.duplicate(), "history": {}, "shocks": []}


func load_dict(_data: Dictionary) -> void:
	pass
