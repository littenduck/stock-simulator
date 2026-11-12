## Statistics over many seeds: does a 60-day run feel plausible? Prints the numbers, asserts sane ranges.
extends TestCase

const RUNS := 500
const DAYS := 60
const UNLOCKED: Array[StringName] = [&"company_moon", &"company_olde", &"company_extra_1", &"company_extra_2", &"company_extra_3"]


func _simulate(seed_value: int, unlocked: Array[StringName]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var market := MarketSim.new(MarketSim.draw_companies(ContentDb.companies(), 6, rng, unlocked), GbmPriceModel.new(), rng)
	var director := NewsDirector.new(ContentDb.news(), rng)
	var mods := RunModifiers.new()
	var rumors := 0
	var rumor_days := 0
	var true_rumors := 0
	for day in range(1, DAYS + 1):
		for r in director.due(day):
			market.apply_news(r.event, r.impact_scale())
		market.step()
		var fresh := director.roll(day, mods, market)
		rumors += fresh.size()
		rumor_days += 1 if fresh.size() > 0 else 0
		for r in fresh:
			true_rumors += 1 if r.is_true else 0
	var ratios: Array[float] = []
	var worst_day := 0.0
	for s in market.symbols():
		ratios.append(market.price_of(s) / market.company_of(s).start_price)
		var h := market.history_of(s)
		for i in range(1, h.size()):
			worst_day = minf(worst_day, h[i] / h[i - 1] - 1.0)
	return {"rumors": rumors, "rumor_days": rumor_days, "true": true_rumors, "ratios": ratios, "worst_day": worst_day}


func _stats(unlocked: Array[StringName], label: String) -> Dictionary:
	var rumors := 0
	var rumor_days := 0
	var truths := 0
	var n := 0
	var below_half := 0
	var above_double := 0
	var above_quad := 0
	var log_sum := 0.0
	var min_r := 1e9
	var max_r := 0.0
	var worst := 0.0
	var per_run: Array[int] = []
	for seed_value in RUNS:
		var r := _simulate(seed_value + 1000, unlocked)
		rumors += r["rumors"]
		rumor_days += r["rumor_days"]
		truths += r["true"]
		per_run.append(r["rumors"])
		worst = minf(worst, r["worst_day"])
		for x in r["ratios"]:
			n += 1
			below_half += 1 if x < 0.5 else 0
			above_double += 1 if x > 2.0 else 0
			above_quad += 1 if x > 4.0 else 0
			log_sum += log(x)
			min_r = minf(min_r, x)
			max_r = maxf(max_r, x)
	per_run.sort()
	var out := {
		"rumors_per_run": float(rumors) / RUNS,
		"rumor_day_share": float(rumor_days) / (RUNS * DAYS),
		"true_share": float(truths) / maxf(1.0, rumors),
		"p5_rumors": per_run[RUNS / 20], "p95_rumors": per_run[RUNS - RUNS / 20],
		"below_half": float(below_half) / n, "above_double": float(above_double) / n, "above_quad": float(above_quad) / n,
		"geo_mean": exp(log_sum / n), "min": min_r, "max": max_r, "worst_day": worst,
	}
	print("BALANCE [%s] %s" % [label, JSON.stringify(out)])
	return out


func test_starter_pool_statistics() -> void:
	var s := _stats([], "starters")
	assert_true(s["rumors_per_run"] >= 24.0 and s["rumors_per_run"] <= 40.0, "rumors per run %f" % s["rumors_per_run"])
	assert_true(s["p5_rumors"] >= 15, "quietest 5%% of runs still has rumors: %d" % s["p5_rumors"])
	assert_true(s["true_share"] > 0.5 and s["true_share"] < 0.7, "true share %f" % s["true_share"])
	assert_true(s["geo_mean"] > 0.85 and s["geo_mean"] < 1.15, "typical stock stays near its start: %f" % s["geo_mean"])
	assert_true(s["below_half"] < 0.10, "too many halvings: %f" % s["below_half"])
	assert_true(s["above_double"] < 0.12, "too many doublings: %f" % s["above_double"])
	assert_true(s["above_quad"] < 0.02, "too many 4x: %f" % s["above_quad"])
	assert_true(s["min"] >= GbmPriceModel.MIN_PRICE)
	assert_true(s["worst_day"] > -0.6, "single day crash too deep: %f" % s["worst_day"])


func test_full_pool_statistics() -> void:
	var s := _stats(UNLOCKED, "all unlocked")
	assert_true(s["rumors_per_run"] >= 24.0 and s["rumors_per_run"] <= 40.0, "rumors per run %f" % s["rumors_per_run"])
	assert_true(s["geo_mean"] > 0.8 and s["geo_mean"] < 1.2, "geo mean %f" % s["geo_mean"])
	assert_true(s["above_quad"] < 0.04, "too many 4x: %f" % s["above_quad"])
	assert_true(s["min"] >= GbmPriceModel.MIN_PRICE)
