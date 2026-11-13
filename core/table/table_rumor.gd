## One table-mode rumor: a claim that a stock (or a sector, for Boss rumors) will go up or down.
## It is TRUE when the real price moved the way the claim says between the day it was shown and the day it resolves;
## it never moves a price itself. Daily rumors resolve the next day, Boss rumors three days later.
class_name TableRumor
extends RefCounted

enum Kind { DAILY, BOSS }

const BOSS_DAYS := 3

var id: int = 0
var kind: Kind = Kind.DAILY
var headline_key: String = ""
## True: the headline holds a %s for the company name (GenericRumors). False: the key is a data/news headline.
var generic: bool = false
var event_id: String = ""
## +1 claims a rise, -1 a fall.
var claim_dir: int = 1
var tier: int = RumorTier.Tier.MEDIUM
## Stocks the claim is about (one for a daily rumor, a sector or all stocks for a Boss rumor).
var symbols: Array[String] = []
var visible_day: int = 0
var resolve_day: int = 1
## symbol -> price on the day the rumor became visible.
var base_prices: Dictionary = {}
## An Insider flipped it: on reveal it is stamped as planted (nobody learns by whom).
var planted: bool = false
var resolved: bool = false
var came_true: bool = false


func is_boss() -> bool:
	return kind == Kind.BOSS


func primary_symbol() -> String:
	return symbols[0] if not symbols.is_empty() else ""


## Marks the day the rumor is shown: remembers today's prices and sets the resolve day.
func activate(day: int, market: MarketSim) -> void:
	visible_day = day
	resolve_day = day + (BOSS_DAYS if kind == Kind.BOSS else 1)
	base_prices = {}
	for s in symbols:
		base_prices[s] = market.price_of(s)


## Average move of the claimed stocks since the rumor was shown (0.02 = +2%).
func move(market: MarketSim) -> float:
	if symbols.is_empty():
		return 0.0
	var total := 0.0
	for s in symbols:
		var base: float = float(base_prices.get(s, 0.0))
		if base > 0.0:
			total += market.price_of(s) / base - 1.0
	return total / float(symbols.size())


## Truth by the real move: an unchanged price counts as up.
func evaluate(market: MarketSim) -> bool:
	return (claim_dir > 0) == (move(market) >= 0.0)


## Final text. Daily generic rumors get the company name in.
func headline(translate: Callable, market: MarketSim) -> String:
	var text: String = translate.call(headline_key)
	if generic:
		var c := market.company_of(primary_symbol())
		var company_name: String = translate.call(c.display_name) if c != null else primary_symbol()
		return text % company_name
	return text


func to_dict() -> Dictionary:
	return {
		"id": id, "kind": int(kind), "headline_key": headline_key, "generic": generic, "event_id": event_id,
		"claim_dir": claim_dir, "tier": tier, "symbols": symbols.duplicate(), "visible_day": visible_day,
		"resolve_day": resolve_day, "base_prices": base_prices.duplicate(), "planted": planted,
		"resolved": resolved, "came_true": came_true,
	}


static func from_dict(d: Dictionary) -> TableRumor:
	var r := TableRumor.new()
	r.id = int(d.get("id", 0))
	r.kind = int(d.get("kind", 0)) as Kind
	r.headline_key = String(d.get("headline_key", ""))
	r.generic = bool(d.get("generic", false))
	r.event_id = String(d.get("event_id", ""))
	r.claim_dir = int(d.get("claim_dir", 1))
	r.tier = int(d.get("tier", 1))
	for s in d.get("symbols", []):
		r.symbols.append(String(s))
	r.visible_day = int(d.get("visible_day", 0))
	r.resolve_day = int(d.get("resolve_day", 1))
	var bp: Dictionary = d.get("base_prices", {})
	for s in bp:
		r.base_prices[String(s)] = float(bp[s])
	r.planted = bool(d.get("planted", false))
	r.resolved = bool(d.get("resolved", false))
	r.came_true = bool(d.get("came_true", false))
	return r
