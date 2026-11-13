## Pure maths of the price chart (no nodes, no autoloads), so it can be unit tested.
class_name ChartMath
extends RefCounted

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


## Lowest low / highest high of candles[from..to] (inclusive) as Vector2(lo, hi). Candles = dict of
## open/high/low/close PackedFloat32Arrays. Falls back to closes when high/low are missing.
static func range_of(candles: Dictionary, from: int, to: int) -> Vector2:
	var highs: PackedFloat32Array = candles.get("high", PackedFloat32Array())
	var lows: PackedFloat32Array = candles.get("low", PackedFloat32Array())
	var closes: PackedFloat32Array = candles.get("close", PackedFloat32Array())
	if highs.size() != closes.size() or lows.size() != closes.size():
		highs = closes
		lows = closes
	var lo: float = INF
	var hi: float = -INF
	for i in range(maxi(from, 0), mini(to, closes.size() - 1) + 1):
		lo = minf(lo, lows[i])
		hi = maxf(hi, highs[i])
	if lo == INF:
		return Vector2(0.0, 1.0)
	return Vector2(lo, hi)


## Widens (lo, hi) with a 8% pad and guarantees a non-zero span.
static func padded(lo: float, hi: float) -> Vector2:
	var pad: float = maxf((hi - lo) * 0.08, maxf(absf(hi), 1.0) * 0.002)
	return Vector2(lo - pad, hi + pad)


static func y_of(value: float, lo: float, hi: float, top: float, height: float) -> float:
	return top + height * (1.0 - (value - lo) / maxf(hi - lo, 0.0001))


## Centre x of candle `i` of `n` in a plot of width `w` starting at `left` (each candle owns a slot).
static func x_of(i: int, n: int, left: float, w: float) -> float:
	return left + w * (float(i) + 0.5) / float(maxi(n, 1))


## Candle index under x (clamped), the inverse of x_of.
static func index_at(x: float, n: int, left: float, w: float) -> int:
	if n <= 0 or w <= 0.0:
		return -1
	return clampi(int(floor((x - left) / w * n)), 0, n - 1)


## Candle body width for a slot width: 70% of it, at least 1 px, at most 18 px.
static func body_width(n: int, w: float) -> float:
	return clampf(w / float(maxi(n, 1)) * 0.7, 1.0, 18.0)


## `count` evenly spaced "nice" tick values covering [lo, hi] (steps of 1/2/2.5/5 x 10^k).
static func nice_ticks(lo: float, hi: float, count: int = 5) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var span: float = maxf(hi - lo, 0.0001)
	var raw: float = span / float(maxi(count - 1, 1))
	var mag: float = pow(10.0, floor(log(raw) / log(10.0)))
	var step: float = mag
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		step = m * mag
		if step >= raw / 1.4:
			break
	var v: float = ceil(lo / step) * step
	while v <= hi + step * 0.0001:
		out.append(v)
		v += step
	return out


## "2024-03-04" -> "Mar 4". Returns "" for empty / malformed dates.
static func short_date(iso: String) -> String:
	var parts: PackedStringArray = iso.split("-")
	if parts.size() != 3:
		return ""
	var month: int = int(parts[1])
	if month < 1 or month > 12:
		return ""
	return "%s %d" % [MONTHS[month - 1], int(parts[2])]


## "2024-03-04" -> "Mar 4, 2024".
static func long_date(iso: String) -> String:
	var short: String = short_date(iso)
	if short == "":
		return ""
	return "%s, %s" % [short, iso.substr(0, 4)]


## Evenly spread candle indexes for x-axis labels (first and last included when count >= 2).
static func label_indices(n: int, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if n <= 0:
		return out
	if n == 1 or count <= 1:
		out.append(0)
		return out
	var k: int = mini(count, n)
	for j in k:
		out.append(roundi(float(j) * (n - 1) / float(k - 1)))
	return out


## Animated candle: grows from a flat open to the real bar as t goes 0 -> 1.
static func grown(open: float, high: float, low: float, close: float, t: float) -> PackedFloat32Array:
	return PackedFloat32Array([open, open + (high - open) * t, open - (open - low) * t, open + (close - open) * t])
