## Geometric Brownian motion price model.
## P(t+1) = P(t) * exp((mu - sigma^2/2) * dt + sigma * sqrt(dt) * Z) * (1 + extra_drift), Z ~ N(0, 1).
## Exactly one rng draw per call, so the draw order of a run stays stable.
class_name GbmPriceModel
extends PriceModel

const TRADING_DAYS_PER_YEAR := 252.0
## Prices never fall below this (a stock must be able to recover and stay tradable).
const MIN_PRICE := 0.01


func next_price(current: float, company: CompanyDef, extra_drift: float, rng: RandomNumberGenerator) -> float:
	var dt := 1.0 / TRADING_DAYS_PER_YEAR
	var mu := company.annual_drift
	var sigma := company.annual_volatility
	var z := rng.randfn(0.0, 1.0)
	var growth := (mu - 0.5 * sigma * sigma) * dt + sigma * sqrt(dt) * z
	return maxf(MIN_PRICE, current * exp(growth) * maxf(0.0, 1.0 + extra_drift))
