## Every rule number that perks, characters and difficulty may change.
## Rule code reads numbers only from here. Does not store per-run progress except iron_hands_used.
## CONTRACT: frozen. Fields may only be added by the lead.
class_name RunModifiers
extends RefCounted

var fee_rate := 0.001                ## base fee rate (fraction of traded value)
var fee_mult := 1.0                  ## Low Fees = 0.5, Market Maker = 0.0
var max_leverage := 1.0              ## gross exposure / equity limit
var maintenance_margin := 0.30       ## equity / gross exposure below this => forced liquidation
var borrow_rate_daily := 0.0002      ## daily fee on short market value
var loan_rate_daily := 0.0002        ## daily interest on negative cash
var cash_interest_daily := 0.0       ## Savings Account = 0.0005
var long_dividend_daily := 0.0       ## Dividend Hunter = 0.0003
var dividend_mult := 1.0             ## Value Investor = 2.0
var rumor_lead_days := 0             ## Early Bird = 1
var rumor_truth_bonus := 0.0         ## difficulty lowers it
var sector_truth_bonus: Dictionary = {}  ## sector (String) -> float, Sector Fan
var draft_choices := 3               ## Second Opinion = 4
var score_mult := 1.0                ## Compounder = 1.1
var limit_price_improvement := 0.0   ## Market Maker = 0.01
var can_short := true                ## Value Investor = false
var volatility_mult := 1.0           ## difficulty 4 = 1.2; MarketSim multiplies every company's volatility by it
var iron_hands_used := false         ## runtime state, saved by the session

var _flags: Dictionary = {}          ## StringName -> true


func apply(perk: PerkDef) -> void:
	_apply_effects(perk.effects, perk.id)
	for flag in perk.flags:
		_flags[flag] = true


func apply_effects(effects: Array[PerkEffectDef], flags: Array[StringName], source: StringName) -> void:
	_apply_effects(effects, source)
	for flag in flags:
		_flags[flag] = true


func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


func set_flag(flag: StringName) -> void:
	_flags[flag] = true


func effective_fee_rate() -> float:
	return fee_rate * fee_mult


func _apply_effects(effects: Array[PerkEffectDef], source: StringName) -> void:
	for effect in effects:
		if not (effect.stat in self):
			push_error("%s references unknown RunModifiers field '%s'" % [source, effect.stat])
			continue
		var current: float = get(effect.stat)
		match effect.op:
			PerkEffectDef.Op.ADD:
				set(effect.stat, current + effect.value)
			PerkEffectDef.Op.MULTIPLY:
				set(effect.stat, current * effect.value)
			PerkEffectDef.Op.SET:
				set(effect.stat, effect.value)
