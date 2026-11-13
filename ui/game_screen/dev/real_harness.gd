## Integration harness: uses the REAL core classes (ContentDb, MarketSim, NewsDirector, TradeService,
## OrderBook, Portfolio) and plays the day order of plan section 13.9 by hand, because GameSession /
## GameManager are not implemented yet. Meant to be run on a checkout where the wave-1 branches are merged.
## Run: godot --path . res://ui/game_screen/dev/real_harness.tscn -- --days=15 --shot=/path.png [--tour=/dir]
extends Node

var _session: GameSession
var _screen: Control


func _ready() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var character: CharacterDef = ContentDb.characters()[0]
	for c in ContentDb.characters():
		if c.id == &"rookie":
			character = c
	var config := RunConfig.make(character, 1, int(args.get("seed", 321)))
	_session = GameSession.new(config, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	_session.mods.max_leverage = maxf(_session.mods.max_leverage, 2.0)
	GameManager.session = _session
	GameManager.state = GameManager.State.PLAYING
	GameCommands.submit_override = _submit
	GameCommands.next_day_override = _next_day
	GameCommands.cancel_override = _cancel
	for i in int(args.get("days", 12)):
		_advance(false)
	_screen = (load("res://ui/game_screen/game_screen.tscn") as PackedScene).instantiate()
	add_child(_screen)
	await get_tree().create_timer(0.5).timeout
	var symbols: Array[String] = _session.market.symbols()
	print("symbols: ", symbols)
	_trade(Order.market(Order.Dir.BUY, symbols[0], 20))
	_trade(Order.market(Order.Dir.SELL, symbols[1], 15))
	_trade(Order.limit(Order.Dir.BUY, symbols[2], 10, _session.market.price_of(symbols[2]) * 0.95))
	_trade(Order.stop(Order.Dir.SELL, symbols[0], 20, _session.market.price_of(symbols[0]) * 0.9))
	for i in 3:
		_next_day()
	await get_tree().create_timer(0.5).timeout
	print("day=%d cash=%.2f net=%.2f pending=%d rumors=%d" % [_session.day, _session.portfolio.cash, _session.net_worth(), _session.book.pending().size(), _session.news.pending().size()])
	var chart: GamePriceChart = _screen.find_child("PriceChart", true, false) as GamePriceChart
	if args.has("select"):
		_screen.select_symbol(symbols[int(args["select"])])
	if args.has("line"):  # --line=1
		chart.set_mode(GamePriceChart.Mode.LINE)
	if args.has("advance_shot"):
		# Capture mid-growth of the newest candle.
		_next_day()
		await get_tree().create_timer(float(args["advance_shot"])).timeout
	if args.has("hover"):
		await get_tree().process_frame
		var ev := InputEventMouseMotion.new()
		ev.position = Vector2(float(args["hover"]), 100)
		chart._on_canvas_gui_input(ev)
		await get_tree().process_frame
	if args.has("shot"):
		get_viewport().get_texture().get_image().save_png(String(args["shot"]))
	get_tree().quit()


func _trade(order: Order) -> void:
	var r: TradeResult = _submit(order)
	print("order %s %s x%d -> ok=%s pending=%s reason=%s" % [order.side, order.symbol, order.shares, r.ok, r.pending, r.reason])


func _submit(order: Order) -> TradeResult:
	var result: TradeResult
	if order.kind == Order.Kind.MARKET:
		result = TradeService.execute(order, _session.market, _session.portfolio, _session.mods)
	else:
		order.id = _session.book.place(order)
		result = TradeResult.queued(order)
		EventBus.order_placed.emit(order)
	if result.ok:
		EventBus.portfolio_changed.emit()
	else:
		EventBus.trade_failed.emit(result.reason)
	return result


func _cancel(order_id: int) -> bool:
	var ok: bool = _session.book.cancel(order_id)
	if ok:
		EventBus.order_cancelled.emit(order_id)
	return ok


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_day"):
		_next_day()


func _next_day() -> void:
	_advance(true)


func _advance(emit: bool) -> void:
	var s := _session
	s.day += 1
	for r in s.news.due(s.day):
		s.market.apply_news(r.event, r.impact_scale())
		r.resolved = true
		if emit:
			EventBus.rumor_resolved.emit(r)
	s.market.step()
	for res in s.book.process(s.market, s.portfolio, s.mods):
		if emit:
			if res.ok:
				EventBus.order_filled.emit(res.order, res)
			else:
				EventBus.trade_failed.emit(res.reason)
	var fresh: Array[Rumor] = s.news.roll(s.day, s.mods, s.market)
	if emit:
		EventBus.day_advanced.emit(s.day)
		EventBus.prices_updated.emit()
		EventBus.portfolio_changed.emit()
		for r in fresh:
			EventBus.rumor_posted.emit(r)
