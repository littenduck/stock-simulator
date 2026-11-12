## Shared builders for trading tests.
class_name TradingHelpers
extends RefCounted


static func market(prices: Dictionary) -> MarketSim:
	var companies: Array[CompanyDef] = []
	for s in prices.keys():
		var c := CompanyDef.new()
		c.symbol = s
		c.start_price = prices[s]
		companies.append(c)
	return MarketSim.new(companies, PriceModel.new(), RandomNumberGenerator.new())
