## Headless balance tool: plays many seeded runs with simple bot strategies and prints CSV.
## Usage: godot --headless --path . --script res://tools/balance_sim.gd -- --runs=200 [--character=rookie]
## Output (stdout): strategy,seed,final_score,final_net_worth,start_cash,won   (won = score >= start_cash * target; default --target=1.5)
## The design docs define no win condition (score ranking only), so "won" is an assumed target multiple.
## Summary per strategy goes to stderr: win rate, mean, median, p10, p90.
##
## STUB STATUS (until session-integration lands): GameSession.next_day() only counts days and
## Portfolio/TradeService are stubs, so every strategy scores the same and win rates are meaningless.
## The tool is written against the final public API (GameSession, Order, MarketSim) and needs no change
## once the real bodies arrive. Perk drafts are answered by picking a random option with the bot RNG.
extends SceneTree

const STRATEGIES: Array[String] = ["hold_cash", "buy_and_hold_all", "buy_best_rumor", "random_trader"]


func _init() -> void:
	var runs := _arg_int("--runs", 200)
	var char_id := _arg_str("--character", "rookie")
	var character := ContentDb.character_by_id(StringName(char_id))
	if character == null:
		printerr("unknown character: " + char_id)
		quit(2)
		return
	var target := _arg_str("--target", "1.5").to_float()
	print("strategy,seed,final_score,final_net_worth,start_cash,won")
	for strategy in STRATEGIES:
		var scores: Array[float] = []
		var wins := 0
		for seed_value in range(1, runs + 1):
			var s := _new_session(character, seed_value)
			_play(s, strategy, seed_value)
			var won := s.score() >= character.start_cash * target
			wins += int(won)
			scores.append(s.score())
			print("%s,%d,%.2f,%.2f,%.2f,%s" % [strategy, seed_value, s.score(), s.net_worth(), character.start_cash, won])
		scores.sort()
		printerr("%-18s win %.1f%%  mean %.0f  median %.0f  p10 %.0f  p90 %.0f" % [strategy, 100.0 * wins / runs, _mean(scores), _pct(scores, 0.5), _pct(scores, 0.1), _pct(scores, 0.9)])
	quit()


func _new_session(character: CharacterDef, seed_value: int) -> GameSession:
	var cfg := RunConfig.make(character, 1, seed_value)
	var s := GameSession.new(cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	s.start()
	return s


func _play(s: GameSession, strategy: String, seed_value: int) -> void:
	var bot := RandomNumberGenerator.new()
	bot.seed = seed_value * 7919
	_answer_draft(s, bot)
	if strategy == "buy_and_hold_all" and not s.market.symbols().is_empty():
		var each := s.portfolio.cash / s.market.symbols().size()
		for symbol in s.market.symbols():
			_buy_max(s, symbol, each)
	var guard := 0
	while not s.is_finished() and guard < 1000:
		guard += 1
		var report := s.next_day()
		if report == null:
			break
		if not report.draft_offer.is_empty():
			s.pending_draft.assign(report.draft_offer)
		_answer_draft(s, bot)
		match strategy:
			"buy_best_rumor":
				for rumor in report.new_rumors:
					_react_to_rumor(s, rumor)
			"random_trader":
				_random_trade(s, bot)


func _answer_draft(s: GameSession, bot: RandomNumberGenerator) -> void:
	if s.pending_draft.is_empty():
		return
	s.choose_perk(s.pending_draft[bot.randi() % s.pending_draft.size()])


func _buy_max(s: GameSession, symbol: String, budget: float) -> void:
	var price := s.market.price_of(symbol)
	if price <= 0.0:
		return
	var shares := int(budget / (price * 1.01))
	if shares > 0:
		s.submit(Order.market(Order.Dir.BUY, symbol, shares))


## Buys the rumor's target when the event is positive and the shown credibility is at least 0.5.
func _react_to_rumor(s: GameSession, rumor: Rumor) -> void:
	if rumor.event == null or rumor.event.total_impact <= 0.0 or rumor.shown_credibility < 0.5:
		return
	if rumor.target_symbol == "" or not s.market.has_symbol(rumor.target_symbol):
		return
	_buy_max(s, rumor.target_symbol, s.portfolio.cash * 0.5)


func _random_trade(s: GameSession, bot: RandomNumberGenerator) -> void:
	var symbols := s.market.symbols()
	if symbols.is_empty():
		return
	var symbol := symbols[bot.randi() % symbols.size()]
	if bot.randf() < 0.5:
		_buy_max(s, symbol, s.portfolio.cash * 0.2)
	else:
		var held := s.portfolio.shares_of(symbol)
		if held > 0:
			s.submit(Order.market(Order.Dir.SELL, symbol, held))


func _mean(sorted_values: Array[float]) -> float:
	var total := 0.0
	for v in sorted_values:
		total += v
	return total / maxf(1.0, sorted_values.size())


func _pct(sorted_values: Array[float], q: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return sorted_values[clampi(int(q * (sorted_values.size() - 1)), 0, sorted_values.size() - 1)]


func _arg_int(name: String, fallback: int) -> int:
	return _arg_str(name, str(fallback)).to_int()


func _arg_str(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="):
			return arg.get_slice("=", 1)
	return fallback
