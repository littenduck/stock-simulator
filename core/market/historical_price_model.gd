## Replays the real daily returns of a stock from HistoryData, on the same calendar window for every company.
## price(step) = price(step-1) * (real_close[row]/real_close[row-1])^vol_mult * (1 + extra_drift), row = window_start + step.
## So news shocks multiply on top of the real path and persist; the real path continues from the shocked price.
## Candles use the same factors on the real open/high/low (relative to the previous real close).
## No rng draws are made while real data is available. Companies without data (or steps past the end of the
## history) fall back to GBM so the model never fails.
class_name HistoricalPriceModel
extends PriceModel

var history: HistoryData
## Row of the history that is day 0 of the run.
var window_start: int = 0
var _fallback := GbmPriceModel.new()


func _init(p_history: HistoryData = null, p_window_start: int = 0) -> void:
	history = p_history
	window_start = p_window_start


func has_data(company: CompanyDef) -> bool:
	return history != null and company.history_key != "" and history.has_key(company.history_key)


func peek_return(company: CompanyDef, from_step: int, to_step: int) -> float:
	if not has_data(company):
		return NAN
	var r0 := window_start + from_step
	var r1 := window_start + to_step
	if r0 < 0 or r1 >= history.row_count() or r1 <= r0:
		return NAN
	return history.close_at(company.history_key, r1) / history.close_at(company.history_key, r0) - 1.0


## Plain close-only API (used by generic callers); honors news, no volatility scaling info.
func next_price(current: float, company: CompanyDef, extra_drift: float, rng: RandomNumberGenerator) -> float:
	return _fallback.next_price(current, company, extra_drift, rng)


func next_ohlc(current: float, company: CompanyDef, extra_drift: float, rng: RandomNumberGenerator, step: int, vol_mult: float) -> PackedFloat32Array:
	var row := window_start + step
	if not has_data(company) or row < 1 or row >= history.row_count():
		var close := _fallback.next_price(current, company, extra_drift, rng)
		return synth_candle(current, close, company.annual_volatility)
	var prev_close := history.close_at(company.history_key, row - 1)
	var b := history.bar(company.history_key, row)
	var news := maxf(0.0, 1.0 + extra_drift)
	var out := PackedFloat32Array()
	for i in 4:
		var factor := exp(vol_mult * log(b[i] / prev_close)) if vol_mult != 1.0 else b[i] / prev_close
		out.append(maxf(GbmPriceModel.MIN_PRICE, current * factor * news))
	return out
