## State of one rumor. Truth is decided when it is created (deterministic); revealed on reveal_day.
## CONTRACT: fields frozen.
class_name Rumor
extends RefCounted

var event: NewsEventDef
## Concrete target ticker ("" if the event is sector or market wide).
var target_symbol: String = ""
var posted_day: int = 0
var reveal_day: int = 0
var is_true: bool = false
## Credibility shown to the player (true probability + noise).
var shown_credibility: float = 0.5
## Range shown instead of a single number when the Fact Checker perk (flag &"fact_checker") is owned.
var credibility_low: float = 0.0
var credibility_high: float = 1.0
## Insider Friend perk: guaranteed true and marked in the UI.
var is_guaranteed: bool = false
var resolved: bool = false


## Scale to pass to MarketSim.apply_news() when this rumor resolves.
func impact_scale() -> float:
	return 1.0 if is_true else event.denial_impact_ratio


func to_dict() -> Dictionary:
	return {
		"event_id": event.id if event else "",
		"target_symbol": target_symbol,
		"posted_day": posted_day,
		"reveal_day": reveal_day,
		"is_true": is_true,
		"shown_credibility": shown_credibility,
		"credibility_low": credibility_low,
		"credibility_high": credibility_high,
		"is_guaranteed": is_guaranteed,
		"resolved": resolved,
	}
