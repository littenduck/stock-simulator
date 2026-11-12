## Geometric Brownian motion price model.
## STUB (market-engine): price stays flat until implemented.
class_name GbmPriceModel
extends PriceModel


func next_price(current: float, _company: CompanyDef, _extra_drift: float, _rng: RandomNumberGenerator) -> float:
	return current
