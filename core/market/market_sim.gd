## Runtime market: current prices, history and active news shocks for the companies of one run.
## CONTRACT: public signatures frozen. Owner of the body: market-engine.
class_name MarketSim
extends RefCounted

## Holds the pre-game lookback (GameSession.PRE_GAME_DAYS = 30) plus a full 60-day run (+ day 0) with room to spare.
const MAX_HISTORY := 91

var _companies: Array[CompanyDef] = []
var _model: PriceModel
var _rng: RandomNumberGenerator
var _prices: Dictionary = {}     ## symbol -> float
var _history: Dictionary = {}    ## symbol -> PackedFloat32Array (closes)
## symbol -> {"open","high","low": PackedFloat32Array}, parallel to _history (the close lives in _history).
var _candles: Dictionary = {}
## symbol -> number of leading entries of the history that are pre-game real lookback (before day 0).
var _lookback: Dictionary = {}
## Trading days simulated since day 0 (what the price model sees as `step`).
var _steps: int = 0
## Active news shocks in registration order: {"symbol": String, "daily": float, "days": int}.
var _shocks: Array[Dictionary] = []
## Set by the session from RunModifiers.volatility_mult (difficulty 4 = 1.2).
var volatility_mult: float = 1.0
var _scaled: Dictionary = {}     ## symbol -> CompanyDef copy with scaled volatility


func _init(companies: Array[CompanyDef], model: PriceModel, rng: RandomNumberGenerator) -> void:
	_companies = companies
	_model = model
	_rng = rng
	for c in companies:
		_prices[c.symbol] = c.start_price
		_history[c.symbol] = PackedFloat32Array([c.start_price])
		_candles[c.symbol] = {"open": PackedFloat32Array([c.start_price]), "high": PackedFloat32Array([c.start_price]), "low": PackedFloat32Array([c.start_price])}
		_lookback[c.symbol] = 0


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


## Closing prices, oldest first, including today. May start with pre-game lookback entries, see lookback_of().
## Index of today = size - 1; index of day d (while not trimmed by MAX_HISTORY) = lookback_of(symbol) + d.
func history_of(symbol: String) -> PackedFloat32Array:
	return _history.get(symbol, PackedFloat32Array())


## Candles parallel to history_of(): {"open","high","low","close"}, each a PackedFloat32Array of the same size.
## Invariant: low <= open, close <= high. close is identical to history_of(symbol).
func candles_of(symbol: String) -> Dictionary:
	var c: Dictionary = _candles.get(symbol, {})
	return {
		"open": c.get("open", PackedFloat32Array()),
		"high": c.get("high", PackedFloat32Array()),
		"low": c.get("low", PackedFloat32Array()),
		"close": history_of(symbol),
	}


## How many leading entries of history_of()/candles_of() are real pre-game days (0 for pure GBM runs).
## Shrinks only if MAX_HISTORY trims the oldest entries.
func lookback_of(symbol: String) -> int:
	return int(_lookback.get(symbol, 0))


## Trading days simulated so far (0 on day 0).
func step_count() -> int:
	return _steps


## Replaces a symbol's series with real bars (oldest first, each [open, high, low, close]); the LAST bar is day 0.
## Earlier bars become the pre-game lookback. Price becomes the last close. Call before the first step().
func init_series(symbol: String, bars: Array) -> void:
	if not _prices.has(symbol) or bars.is_empty():
		return
	if bars.size() > MAX_HISTORY:
		bars = bars.slice(bars.size() - MAX_HISTORY)
	var o := PackedFloat32Array()
	var hi := PackedFloat32Array()
	var lo := PackedFloat32Array()
	var cl := PackedFloat32Array()
	for b in bars:
		var bar: PackedFloat32Array = b
		o.append(bar[0])
		hi.append(bar[1])
		lo.append(bar[2])
		cl.append(bar[3])
	_history[symbol] = cl
	_candles[symbol] = {"open": o, "high": hi, "low": lo}
	_lookback[symbol] = bars.size() - 1
	_prices[symbol] = cl[cl.size() - 1]


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
	var c: Dictionary = _candles[symbol]
	var i := h.size() - 1
	var hi: PackedFloat32Array = c["high"]
	var lo: PackedFloat32Array = c["low"]
	hi[i] = maxf(hi[i], price)
	lo[i] = minf(lo[i], price)
	c["high"] = hi
	c["low"] = lo


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
func _with_volatility(c: CompanyDef) -> CompanyDef:
	if is_equal_approx(volatility_mult, 1.0):
		return c
	var cached: CompanyDef = _scaled.get(c.symbol)
	if cached == null or not is_equal_approx(cached.annual_volatility, c.annual_volatility * volatility_mult):
		cached = c.duplicate()
		cached.annual_volatility = c.annual_volatility * volatility_mult
		_scaled[c.symbol] = cached
	return cached


func step() -> void:
	_steps += 1
	for c in _companies:
		var extra := _consume_shocks(c.symbol)
		var bar: PackedFloat32Array = _model.next_ohlc(_prices[c.symbol], _with_volatility(c), extra, _rng, _steps, volatility_mult)
		_prices[c.symbol] = bar[3]
		_append_bar(c.symbol, bar)
	var remaining: Array[Dictionary] = []
	for sh in _shocks:
		sh["days"] = int(sh["days"]) - 1
		if int(sh["days"]) > 0:
			remaining.append(sh)
	_shocks = remaining


func _append_bar(symbol: String, bar: PackedFloat32Array) -> void:
	var h: PackedFloat32Array = _history[symbol]
	var cd: Dictionary = _candles[symbol]
	var o: PackedFloat32Array = cd["open"]
	var hi: PackedFloat32Array = cd["high"]
	var lo: PackedFloat32Array = cd["low"]
	h.append(bar[3])
	o.append(bar[0])
	hi.append(bar[1])
	lo.append(bar[2])
	if h.size() > MAX_HISTORY:
		var drop := h.size() - MAX_HISTORY
		h = h.slice(drop)
		o = o.slice(drop)
		hi = hi.slice(drop)
		lo = lo.slice(drop)
		_lookback[symbol] = maxi(0, int(_lookback.get(symbol, 0)) - drop)
	_history[symbol] = h
	cd["open"] = o
	cd["high"] = hi
	cd["low"] = lo


func to_dict() -> Dictionary:
	var hist := {}
	var cand := {}
	for symbol in _history:
		hist[symbol] = Array(_history[symbol])
		var cd: Dictionary = _candles[symbol]
		cand[symbol] = {"open": Array(cd["open"]), "high": Array(cd["high"]), "low": Array(cd["low"])}
	return {"prices": _prices.duplicate(), "history": hist, "candles": cand, "lookback": _lookback.duplicate(), "steps": _steps, "shocks": _shocks.duplicate(true)}


func load_dict(data: Dictionary) -> void:
	var prices: Dictionary = data.get("prices", {})
	var hist: Dictionary = data.get("history", {})
	var cand: Dictionary = data.get("candles", {})
	var lookback: Dictionary = data.get("lookback", {})
	_steps = int(data.get("steps", maxi(0, _first_history_size_minus_one(hist))))
	for c in _companies:
		if prices.has(c.symbol):
			_prices[c.symbol] = float(prices[c.symbol])
		if hist.has(c.symbol) and not (hist[c.symbol] as Array).is_empty():
			var closes := PackedFloat32Array(hist[c.symbol])
			_history[c.symbol] = closes
			_lookback[c.symbol] = clampi(int(lookback.get(c.symbol, 0)), 0, closes.size() - 1)
			_candles[c.symbol] = _candles_from_save(cand.get(c.symbol, {}), closes, c)
	_shocks = []
	for sh in data.get("shocks", []):
		if _prices.has(String(sh["symbol"])):
			_shocks.append({"symbol": String(sh["symbol"]), "daily": float(sh["daily"]), "days": int(sh["days"])})


## Saved candles when they match the closes, otherwise (old saves) synthesized from the closes.
func _candles_from_save(saved: Dictionary, closes: PackedFloat32Array, c: CompanyDef) -> Dictionary:
	var o := PackedFloat32Array(saved.get("open", []))
	var hi := PackedFloat32Array(saved.get("high", []))
	var lo := PackedFloat32Array(saved.get("low", []))
	if o.size() == closes.size() and hi.size() == closes.size() and lo.size() == closes.size():
		return {"open": o, "high": hi, "low": lo}
	o = PackedFloat32Array([closes[0]])
	hi = PackedFloat32Array([closes[0]])
	lo = PackedFloat32Array([closes[0]])
	for i in range(1, closes.size()):
		var bar := PriceModel.synth_candle(closes[i - 1], closes[i], c.annual_volatility)
		o.append(bar[0])
		hi.append(bar[1])
		lo.append(bar[2])
	return {"open": o, "high": hi, "low": lo}


func _first_history_size_minus_one(hist: Dictionary) -> int:
	for k in hist:
		return (hist[k] as Array).size() - 1 - int((_lookback.get(k, 0)))
	return 0


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
