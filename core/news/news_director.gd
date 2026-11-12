## Decides which rumors appear each day. Never changes prices (the session does that).
## CONTRACT: public signatures frozen. Owner of the body: market-engine.
##
## Draw order per roll() (all from the injected rng, stable):
##   1. one randf() per eligible event in pool order (does it fire?)
##   2. if more events fired than MAX_PER_DAY: randi_range() to drop random ones
##   3. Insider Friend only: randi_range() to pick a forced event when none fired
##   4. per created rumor: randi_range() to pick the stock when the template is "any" (resolve target), then
##   5. per created rumor: randf() truth, randfn() credibility noise, randf_range() range offset, randi_range() delay
class_name NewsDirector
extends RefCounted

const MAX_PER_DAY := 1
const MIN_DELAY_DAYS := 1
const MAX_DELAY_DAYS := 3
const CREDIBILITY_NOISE := 0.15
const CREDIBILITY_MIN := 0.05
const CREDIBILITY_MAX := 0.95
## Fact Checker: half width of the shown credibility range.
const RANGE_HALF_WIDTH := 0.1
const RANGE_OFFSET := 0.05
const INSIDER_INTERVAL_DAYS := 10
## Template convention: target_symbol == "any" means "one random stock of target_sector that is in the market".
## roll() resolves it by drawing from rng and stores a copy of the event with the concrete symbol in the Rumor.
const ANY_SYMBOL := "any"

var _pool: Array[NewsEventDef] = []
var _rng: RandomNumberGenerator
var _pending: Array[Rumor] = []
var _cooldown_until: Dictionary = {}    ## event id -> first day it may fire again
var _last_insider_day: int = 0


func _init(pool: Array[NewsEventDef], rng: RandomNumberGenerator) -> void:
	_pool = pool
	_rng = rng


## New rumors posted today (also remembered as pending until revealed).
func roll(day: int, mods: RunModifiers, market: MarketSim) -> Array[Rumor]:
	var m: RunModifiers = mods if mods != null else RunModifiers.new()
	var fired: Array[NewsEventDef] = []
	for event in _pool:
		if not _can_fire(event, day, market):
			continue
		if _rng.randf() < event.daily_chance:
			fired.append(event)
	while fired.size() > MAX_PER_DAY:
		fired.remove_at(_rng.randi_range(0, fired.size() - 1))

	var insider_due: bool = m.has_flag(&"insider_friend") and day - _last_insider_day >= INSIDER_INTERVAL_DAYS
	if insider_due and fired.is_empty():
		var candidates: Array[NewsEventDef] = []
		for event in _pool:
			if _can_fire(event, day, market):
				candidates.append(event)
		if not candidates.is_empty():
			fired.append(candidates[_rng.randi_range(0, candidates.size() - 1)])

	var out: Array[Rumor] = []
	for template in fired:
		var event := _resolve_target(template, market)
		var guaranteed := insider_due and out.is_empty()
		out.append(_make_rumor(event, day, m, market, guaranteed))
		_cooldown_until[event.id] = day + event.cooldown_days    # same id for template and copy
		if guaranteed:
			_last_insider_day = day
	_pending.append_array(out)
	return out


## Pending rumors whose reveal_day has arrived; marks them resolved and removes them from pending.
func due(day: int) -> Array[Rumor]:
	var out: Array[Rumor] = []
	var rest: Array[Rumor] = []
	for r in _pending:
		if r.reveal_day <= day:
			r.resolved = true
			out.append(r)
		else:
			rest.append(r)
	_pending = rest
	return out


## Rumors still waiting for their reveal day.
func pending() -> Array[Rumor]:
	return _pending


func to_dict() -> Dictionary:
	var pend: Array = []
	for r in _pending:
		pend.append(r.to_dict())
	return {"cooldowns": _cooldown_until.duplicate(), "pending": pend, "last_insider_day": _last_insider_day}


func load_dict(data: Dictionary) -> void:
	_cooldown_until = {}
	var cd: Dictionary = data.get("cooldowns", {})
	for id in cd:
		_cooldown_until[String(id)] = int(cd[id])
	_last_insider_day = int(data.get("last_insider_day", 0))
	_pending = []
	for d in data.get("pending", []):
		var event := _event_by_id(String(d.get("event_id", "")))
		if event == null:
			continue
		if event.target_symbol == ANY_SYMBOL and String(d.get("target_symbol", "")) != "":
			event = _with_symbol(event, String(d["target_symbol"]))
		var r := Rumor.new()
		r.event = event
		r.target_symbol = String(d.get("target_symbol", ""))
		r.posted_day = int(d.get("posted_day", 0))
		r.reveal_day = int(d.get("reveal_day", 0))
		r.is_true = bool(d.get("is_true", false))
		r.shown_credibility = float(d.get("shown_credibility", 0.5))
		r.credibility_low = float(d.get("credibility_low", 0.0))
		r.credibility_high = float(d.get("credibility_high", 1.0))
		r.is_guaranteed = bool(d.get("is_guaranteed", false))
		r.resolved = bool(d.get("resolved", false))
		_pending.append(r)


## True probability that a rumor is true, for display and tests.
static func truth_probability(event: NewsEventDef, mods: RunModifiers, market: MarketSim) -> float:
	var p := event.truth_chance + mods.rumor_truth_bonus
	var sector := _sector_of(event, market)
	if sector != "":
		p += float(mods.sector_truth_bonus.get(sector, 0.0))
	return clampf(p, 0.0, 1.0)


func _make_rumor(event: NewsEventDef, day: int, mods: RunModifiers, market: MarketSim, guaranteed: bool) -> Rumor:
	var truth := 1.0 if guaranteed else truth_probability(event, mods, market)
	var r := Rumor.new()
	r.event = event
	r.target_symbol = event.target_symbol
	r.posted_day = day
	var roll := _rng.randf()    # always drawn, so the draw count does not depend on the perk
	r.is_true = guaranteed or roll < truth
	r.shown_credibility = clampf(truth + _rng.randfn(0.0, CREDIBILITY_NOISE), CREDIBILITY_MIN, CREDIBILITY_MAX)
	var offset := _rng.randf_range(-RANGE_OFFSET, RANGE_OFFSET)
	if mods.has_flag(&"fact_checker"):
		r.credibility_low = clampf(truth + offset - RANGE_HALF_WIDTH, 0.0, 1.0)
		r.credibility_high = clampf(truth + offset + RANGE_HALF_WIDTH, 0.0, 1.0)
	r.reveal_day = day + _rng.randi_range(MIN_DELAY_DAYS, MAX_DELAY_DAYS) + mods.rumor_lead_days
	r.is_guaranteed = guaranteed
	return r


## Templates with ANY_SYMBOL become a copy aimed at one random market stock of their sector.
func _resolve_target(template: NewsEventDef, market: MarketSim) -> NewsEventDef:
	if template.target_symbol != ANY_SYMBOL:
		return template
	var candidates: Array[String] = []
	for symbol in market.symbols():
		if market.company_of(symbol).sector == template.target_sector:
			candidates.append(symbol)
	return _with_symbol(template, candidates[_rng.randi_range(0, candidates.size() - 1)])


static func _with_symbol(template: NewsEventDef, symbol: String) -> NewsEventDef:
	var copy: NewsEventDef = template.duplicate()
	copy.target_symbol = symbol
	return copy


func _can_fire(event: NewsEventDef, day: int, market: MarketSim) -> bool:
	if day < event.min_day or day < int(_cooldown_until.get(event.id, 0)):
		return false
	return _targets_market(event, market)


## Only symbols/sectors that exist in this run's market may be targeted.
static func _targets_market(event: NewsEventDef, market: MarketSim) -> bool:
	if event.target_symbol == ANY_SYMBOL:
		return event.target_sector in market.sectors()
	if event.target_symbol != "":
		return market.has_symbol(event.target_symbol)
	if event.target_sector == "all":
		return true
	return event.target_sector != "" and event.target_sector in market.sectors()


static func _sector_of(event: NewsEventDef, market: MarketSim) -> String:
	if event.target_symbol != "" and event.target_symbol != ANY_SYMBOL:
		var c := market.company_of(event.target_symbol)
		return c.sector if c != null else ""
	if event.target_sector == "all":
		return ""
	return event.target_sector


func _event_by_id(id: String) -> NewsEventDef:
	for e in _pool:
		if e.id == id:
			return e
	return null
