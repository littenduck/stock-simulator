## Abstract price model (strategy pattern). Subclasses override next_price().
## CONTRACT: signature frozen. Owner of the body: market-engine.
class_name PriceModel
extends RefCounted


## Returns the next day's price. extra_drift = news driven extra daily return (0.03 = +3%).
## Must use the injected rng, never global randf().
func next_price(current: float, company: CompanyDef, extra_drift: float, rng: RandomNumberGenerator) -> float:
	push_error("PriceModel.next_price() must be overridden")
	return current


## Returns the next day's candle as [open, high, low, close] (always low <= open,close <= high).
## `step` = trading days since day 0 (1 for the first step), `vol_mult` = RunModifiers.volatility_mult.
## Default: close from next_price(), open/high/low synthesized deterministically (no extra rng draws, so the
## draw order of a run is identical to the plain next_price() flow).
func next_ohlc(current: float, company: CompanyDef, extra_drift: float, rng: RandomNumberGenerator, _step: int, _vol_mult: float) -> PackedFloat32Array:
	var close := next_price(current, company, extra_drift, rng)
	return synth_candle(current, close, company.annual_volatility)


## Real return between two run days (absolute steps) when the model knows the future (historical replay).
## NAN = unknown (random models). Used to make daily rumors line up with what really happens.
func peek_return(_company: CompanyDef, _from_step: int, _to_step: int) -> float:
	return NAN


## Builds a plausible candle around prev_close -> close. Wick sizes derive from a hash of the two prices, so the
## result is deterministic without touching any rng. `annual_vol` scales the wicks.
static func synth_candle(prev_close: float, close: float, annual_vol: float) -> PackedFloat32Array:
	var h: int = hash(Vector2(prev_close, close))
	var u1 := float(h & 1023) / 1023.0
	var u2 := float((h >> 10) & 1023) / 1023.0
	var u3 := float((h >> 20) & 1023) / 1023.0
	var daily := annual_vol / sqrt(252.0)
	var open := prev_close * (1.0 + (u3 - 0.5) * 0.3 * daily)
	var top := maxf(open, close)
	var bottom := minf(open, close)
	var high := top * (1.0 + daily * 0.6 * u1)
	var low := maxf(0.0001, bottom * (1.0 - daily * 0.6 * u2))
	return PackedFloat32Array([open, high, low, close])
