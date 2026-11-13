## Deals the rumors of a table-mode run.
## The shown tier decides how likely a rumor is to be true. With real history the factory looks at what the stock
## really does next and picks a headline whose claim fits or contradicts it, so truth is decided by the market and
## no rumor ever has to move a price. Without a known future (random price model) truth is left to chance.
class_name RumorFactory
extends RefCounted

const RECENT_SYMBOLS := 3
const SPECIFIC_CHANCE := 0.6


## A daily single-stock rumor shown on `day` (it resolves on day + 1).
## force_truth: -1 = tier decides, 1 = must be true (Insider day), 0 = must be false.
## `recent` is a rolling list of used event ids / generic keys / "sym:XXXX" markers the factory reads and extends.
static func make_daily(day: int, market: MarketSim, events: Array[NewsEventDef], recent: Array, rng: RandomNumberGenerator, force_truth: int, id: int) -> TableRumor:
	var tier: int = rng.rand_weighted(PackedFloat32Array(RumorTier.WEIGHTS))
	var want_true: bool = rng.randf() < RumorTier.truth_chance(tier)
	if force_truth == 1:
		want_true = true
	elif force_truth == 0:
		want_true = false
	var symbol := _pick_symbol(market, recent, rng)
	var ret: float = market.peek_return(symbol, day, day + 1)
	var claim: int
	if is_nan(ret):
		claim = 1 if rng.randf() < 0.5 else -1
	else:
		var up := ret >= 0.0
		claim = (1 if up else -1) if want_true else (-1 if up else 1)
	return make_with_claim(symbol, claim, tier, events, recent, rng, id)


## A daily rumor about `symbol` that claims `claim` (+1 up / -1 down). Used directly when an Insider flips a rumor.
static func make_with_claim(symbol: String, claim: int, tier: int, events: Array[NewsEventDef], recent: Array, rng: RandomNumberGenerator, id: int) -> TableRumor:
	var r := TableRumor.new()
	r.id = id
	r.kind = TableRumor.Kind.DAILY
	r.claim_dir = claim
	r.tier = tier
	r.symbols = [symbol]
	var specific := _specific_events(symbol, claim, events, recent)
	if not specific.is_empty() and rng.randf() < SPECIFIC_CHANCE:
		var e: NewsEventDef = specific[rng.randi_range(0, specific.size() - 1)]
		r.headline_key = e.headline_key
		r.event_id = e.id
		r.generic = false
	else:
		var keys := GenericRumors.keys(claim)
		var fresh: Array[String] = []
		for k in keys:
			if k not in recent:
				fresh.append(k)
		if fresh.is_empty():
			fresh = keys
		var key: String = fresh[rng.randi_range(0, fresh.size() - 1)]
		r.headline_key = key
		r.event_id = key
		r.generic = true
	_remember(recent, r.event_id)
	_remember(recent, "sym:" + symbol)
	return r


## A Boss rumor shown on `day`: a sector or market wide claim that resolves on day + 3.
static func make_boss(day: int, market: MarketSim, events: Array[NewsEventDef], recent: Array, rng: RandomNumberGenerator, id: int) -> TableRumor:
	var tier: int = rng.rand_weighted(PackedFloat32Array(RumorTier.WEIGHTS))
	var want_true: bool = rng.randf() < RumorTier.truth_chance(tier)
	var pool: Array[NewsEventDef] = []
	for e in events:
		if e.target_symbol == "" and (e.target_sector == "all" or e.target_sector in market.sectors()):
			pool.append(e)
	if pool.is_empty():
		return null
	var fitting: Array[NewsEventDef] = []
	var unused: Array[NewsEventDef] = []
	for e in pool:
		if e.id in recent:
			continue
		unused.append(e)
		var hit := market.symbols_hit_by(e)
		var total := 0.0
		var known := 0
		for s in hit:
			var ret: float = market.peek_return(s, day, day + TableRumor.BOSS_DAYS)
			if not is_nan(ret):
				total += ret
				known += 1
		if known == 0:
			fitting.append(e)
		else:
			var claim_up: bool = e.total_impact >= 0.0
			var is_true: bool = claim_up == (total / float(known) >= 0.0)
			if is_true == want_true:
				fitting.append(e)
	var choices: Array[NewsEventDef] = fitting if not fitting.is_empty() else (unused if not unused.is_empty() else pool)
	var picked: NewsEventDef = choices[rng.randi_range(0, choices.size() - 1)]
	var r := TableRumor.new()
	r.id = id
	r.kind = TableRumor.Kind.BOSS
	r.headline_key = picked.headline_key
	r.event_id = picked.id
	r.claim_dir = 1 if picked.total_impact >= 0.0 else -1
	r.tier = tier
	r.symbols = market.symbols_hit_by(picked)
	_remember(recent, picked.id)
	return r


## Same stock, opposite claim, same tier: what an Insider publishes instead of the true rumor.
static func flipped(original: TableRumor, events: Array[NewsEventDef], recent: Array, rng: RandomNumberGenerator, id: int) -> TableRumor:
	var r := make_with_claim(original.primary_symbol(), -original.claim_dir, original.tier, events, recent, rng, id)
	r.planted = true
	return r


static func _pick_symbol(market: MarketSim, recent: Array, rng: RandomNumberGenerator) -> String:
	var all := market.symbols()
	var fresh: Array[String] = []
	var last_symbols: Array[String] = []
	for item in recent:
		if String(item).begins_with("sym:"):
			last_symbols.append(String(item).substr(4))
	last_symbols = last_symbols.slice(maxi(0, last_symbols.size() - RECENT_SYMBOLS))
	for s in all:
		if s not in last_symbols:
			fresh.append(s)
	var pool: Array[String] = fresh if not fresh.is_empty() else all
	return pool[rng.randi_range(0, pool.size() - 1)]


## Data rumors about this stock with the right direction that were not used lately.
static func _specific_events(symbol: String, claim: int, events: Array[NewsEventDef], recent: Array) -> Array[NewsEventDef]:
	var out: Array[NewsEventDef] = []
	for e in events:
		if e.id in recent:
			continue
		if (e.total_impact >= 0.0) != (claim > 0):
			continue
		if e.target_symbol == symbol:
			out.append(e)
	return out


static func _remember(recent: Array, item: String) -> void:
	recent.append(item)
	while recent.size() > 14:
		recent.remove_at(0)
