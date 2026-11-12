## Runtime market: current prices, history and active news shocks for the companies of one run.
## CONTRACT: public signatures frozen. Owner of the body: market-engine.
class_name MarketSim
extends RefCounted

const MAX_HISTORY := 80

var _companies: Array[CompanyDef] = []
var _model: PriceModel
var _rng: RandomNumberGenerator
var _prices: Dictionary = {}     ## symbol -> float
var _history: Dictionary = {}    ## symbol -> PackedFloat32Array
## Active news shocks in registration order: {"symbol": String, "daily": float, "days": int}.
var _shocks: Array[Dictionary] = []


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
	# Sort by symbol so the draw does not depend on file load order, then Fisher-Yates with rng.
	eligible.sort_custom(func(a: CompanyDef, b: CompanyDef) -> bool: return a.symbol < b.symbol)
	for i in range(eligible.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: CompanyDef = eligible[i]
		eligible[i] = eligible[j]
		eligible[j] = tmp
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
## The total impact (total_impact * scale) is compounded evenly over duration_days; it starts with the next step().
func apply_news(event: NewsEventDef, scale: float = 1.0) -> void:
	var total := event.total_impact * scale
	var days := maxi(1, event.duration_days)
	var daily := pow(maxf(0.01, 1.0 + total), 1.0 / float(days)) - 1.0
	for c in _companies:
		if _is_affected(c, event):
			_shocks.append({"symbol": c.symbol, "daily": daily, "days": days})


## Advances one trading day.
func step() -> void:
	for c in _companies:
		var extra := _consume_shocks(c.symbol)
		var price: float = _model.next_price(_prices[c.symbol], c, extra, _rng)
		_prices[c.symbol] = price
		var h: PackedFloat32Array = _history[c.symbol]
		h.append(price)
		if h.size() > MAX_HISTORY:
			h = h.slice(h.size() - MAX_HISTORY)
		_history[c.symbol] = h
	var remaining: Array[Dictionary] = []
	for sh in _shocks:
		sh["days"] = int(sh["days"]) - 1
		if int(sh["days"]) > 0:
			remaining.append(sh)
	_shocks = remaining


func to_dict() -> Dictionary:
	var hist := {}
	for symbol in _history:
		hist[symbol] = Array(_history[symbol])
	return {"prices": _prices.duplicate(), "history": hist, "shocks": _shocks.duplicate(true)}


func load_dict(data: Dictionary) -> void:
	var prices: Dictionary = data.get("prices", {})
	var hist: Dictionary = data.get("history", {})
	for c in _companies:
		if prices.has(c.symbol):
			_prices[c.symbol] = float(prices[c.symbol])
		if hist.has(c.symbol) and not (hist[c.symbol] as Array).is_empty():
			_history[c.symbol] = PackedFloat32Array(hist[c.symbol])
	_shocks = []
	for sh in data.get("shocks", []):
		if _prices.has(String(sh["symbol"])):
			_shocks.append({"symbol": String(sh["symbol"]), "daily": float(sh["daily"]), "days": int(sh["days"])})


func _is_affected(company: CompanyDef, event: NewsEventDef) -> bool:
	if event.target_symbol != "":
		return event.target_symbol == company.symbol
	if event.target_sector == "all":
		return true
	return event.target_sector != "" and event.target_sector == company.sector


## Combined extra drift of all active shocks for one symbol today.
func _consume_shocks(symbol: String) -> float:
	var factor := 1.0
	for sh in _shocks:
		if sh["symbol"] == symbol:
			factor *= 1.0 + float(sh["daily"])
	return factor - 1.0
