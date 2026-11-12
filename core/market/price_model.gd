## Abstract price model (strategy pattern). Subclasses override next_price().
## CONTRACT: signature frozen. Owner of the body: market-engine.
class_name PriceModel
extends RefCounted


## Returns the next day's price. extra_drift = news driven extra daily return (0.03 = +3%).
## Must use the injected rng, never global randf().
func next_price(current: float, company: CompanyDef, extra_drift: float, rng: RandomNumberGenerator) -> float:
	push_error("PriceModel.next_price() must be overridden")
	return current
