## Dev harness for the game screen. Builds a GameSession by hand (dev market, dev portfolio, tiny
## order matching) and emits the EventBus signals the real GameManager will emit later.
## Run:   godot --path . res://ui/game_screen/dev/dev_harness.tscn
## Shot:  godot --path . res://ui/game_screen/dev/dev_harness.tscn --resolution 1280x720 -- --shot=/tmp/a.png
## Keys:  Space next day | F1 post rumor | F2 Fact Checker | F3 Insider Friend | F4 margin call | F5 short ban
extends Node

const SCREEN := preload("res://ui/game_screen/game_screen.tscn")

var _session: GameSession
var _rng := RandomNumberGenerator.new()
var _screen: Control
var _rumor_serial: int = 0


## Random-walk market with 25 days of history, overriding the stub MarketSim.
class DevMarket extends MarketSim:
	var _dev_rng: RandomNumberGenerator
	var _dev_prices: Dictionary = {}
	var _dev_hist: Dictionary = {}

	func _init(companies: Array[CompanyDef], rng: RandomNumberGenerator) -> void:
		super._init(companies, PriceModel.new(), rng)
		_dev_rng = rng
		for c in companies:
			_dev_prices[c.symbol] = c.start_price
			_dev_hist[c.symbol] = PackedFloat32Array([c.start_price])
		for i in 24:
			step()

	func step() -> void:
		for c in _companies:
			var h: PackedFloat32Array = _dev_hist[c.symbol]
			var ret: float = _dev_rng.randfn(c.annual_drift / 252.0, c.annual_volatility / sqrt(252.0))
			var p: float = maxf(_dev_prices[c.symbol] * exp(ret), 1.0)
			_dev_prices[c.symbol] = p
			h.append(p)
			_dev_hist[c.symbol] = h

	func price_of(symbol: String) -> float:
		return _dev_prices.get(symbol, 0.0)

	func history_of(symbol: String) -> PackedFloat32Array:
		return _dev_hist.get(symbol, PackedFloat32Array())

	func day_change(symbol: String) -> float:
		var h: PackedFloat32Array = history_of(symbol)
		return h[h.size() - 1] / h[h.size() - 2] - 1.0 if h.size() > 1 else 0.0


## Portfolio with the bookkeeping and valuation the real one will provide.
class DevPortfolio extends Portfolio:
	func apply_fill(symbol: String, signed_shares: int, price: float, fee: float) -> void:
		cash -= signed_shares * price + fee
		var pos: Dictionary = positions.get(symbol, {"shares": 0, "avg_cost": price})
		var old: int = pos["shares"]
		var now: int = old + signed_shares
		if now == 0:
			positions.erase(symbol)
			return
		if old == 0 or signf(old) != signf(now):
			pos["avg_cost"] = price
		elif absi(now) > absi(old):
			pos["avg_cost"] = (pos["avg_cost"] * absi(old) + price * absi(signed_shares)) / absi(now)
		pos["shares"] = now
		positions[symbol] = pos

	func long_value(market: MarketSim) -> float:
		var v: float = 0.0
		for s: String in positions:
			v += maxi(positions[s]["shares"], 0) * market.price_of(s)
		return v

	func short_value(market: MarketSim) -> float:
		var v: float = 0.0
		for s: String in positions:
			v += maxi(-int(positions[s]["shares"]), 0) * market.price_of(s)
		return v

	func net_worth(market: MarketSim) -> float:
		return cash + long_value(market) - short_value(market)

	func gross_exposure(market: MarketSim) -> float:
		return long_value(market) + short_value(market)


func _ready() -> void:
	_rng.seed = 7
	var character := CharacterDef.new()
	character.id = &"dev"
	character.start_cash = 10000.0
	var companies: Array[CompanyDef] = [
		_company("NOVA", "tech", 80.0, 0.12, 0.55), _company("FINX", "finance", 45.0, 0.07, 0.30),
		_company("GRNE", "energy", 32.0, 0.05, 0.45), _company("MEDI", "health", 120.0, 0.09, 0.25),
		_company("SHOP", "consumer", 60.0, 0.06, 0.35), _company("CLDX", "tech", 210.0, 0.10, 0.50),
	]
	var no_perks: Array[PerkDef] = []
	var no_news: Array[NewsEventDef] = []
	_session = GameSession.new(RunConfig.make(character, 1, 123), companies, no_perks, no_news)
	_session.market = DevMarket.new(companies, _rng)
	_session.portfolio = DevPortfolio.new(character.start_cash)
	_session.mods.max_leverage = 2.0
	_session.day = 0

	GameManager.session = _session
	GameManager.state = GameManager.State.PLAYING
	GameCommands.submit_override = _submit
	GameCommands.next_day_override = _next_day
	GameCommands.cancel_override = _cancel

	var args: Dictionary = _parse_args()
	_seed_demo(int(args.get("days", 22)))
	_screen = SCREEN.instantiate()
	add_child(_screen)
	if args.has("tour"):
		await _tour(String(args["tour"]))
		get_tree().quit()
		return
	if args.has("smoke"):
		await _smoke()
	if args.has("shot"):
		await get_tree().create_timer(0.7).timeout
		get_viewport().get_texture().get_image().save_png(String(args["shot"]))
		get_tree().quit()


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


func _company(symbol: String, sector: String, price: float, drift: float, vol: float) -> CompanyDef:
	var c := CompanyDef.new()
	c.symbol = symbol
	c.display_name = symbol
	c.sector = sector
	c.start_price = price
	c.annual_drift = drift
	c.annual_volatility = vol
	return c


func _seed_demo(days: int) -> void:
	for i in days:
		_advance(false)
	_submit(Order.market(Order.Dir.BUY, "NOVA", 30))
	_submit(Order.market(Order.Dir.SELL, "GRNE", 120))
	_submit(Order.market(Order.Dir.BUY, "MEDI", 8))
	_submit(Order.limit(Order.Dir.BUY, "FINX", 40, _session.market.price_of("FINX") * 0.92))
	_submit(Order.stop(Order.Dir.SELL, "NOVA", 30, _session.market.price_of("NOVA") * 0.88))
	_submit(Order.stop(Order.Dir.BUY, "GRNE", 120, _session.market.price_of("GRNE") * 1.12))
	_post_rumor("UI_GAME_DEV_NEWS_1", "NOVA", 0.2, 3, 0.78, false)
	_post_rumor("UI_GAME_DEV_NEWS_2", "", -0.12, 2, 0.41, false, "energy")
	_post_rumor("UI_GAME_DEV_NEWS_3", "", -0.05, 1, 0.55, false, "all")
	var done := _post_rumor("UI_GAME_DEV_NEWS_4", "FINX", 0.15, 0, 0.66, false)
	done.resolved = true
	done.is_true = true
	_session.owned_perks.append(_perk("UI_GAME_DEV_PERK_FEES", "UI_GAME_DEV_PERK_FEES_DESC", PerkDef.Rarity.COMMON))


func _perk(title: String, desc: String, rarity: PerkDef.Rarity) -> PerkDef:
	var p := PerkDef.new()
	p.title_key = title
	p.description_key = desc
	p.rarity = rarity
	return p


func _post_rumor(headline: String, symbol: String, impact: float, in_days: int, cred: float, guaranteed: bool, sector: String = "") -> Rumor:
	var r := Rumor.new()
	r.event = NewsEventDef.new()
	r.event.id = "dev_%d" % _rumor_serial
	r.event.headline_key = headline
	r.event.total_impact = impact
	r.event.target_sector = sector
	_rumor_serial += 1
	r.target_symbol = symbol
	r.posted_day = _session.day
	r.reveal_day = _session.day + in_days
	r.shown_credibility = cred
	r.credibility_low = clampf(cred - 0.12, 0.0, 1.0)
	r.credibility_high = clampf(cred + 0.12, 0.0, 1.0)
	r.is_guaranteed = guaranteed
	r.is_true = guaranteed or _rng.randf() < cred
	_session.news.pending().append(r)
	EventBus.rumor_posted.emit(r)
	return r


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_day"):
		_next_day()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F1:
				_post_rumor("UI_GAME_DEV_NEWS_1", "CLDX", 0.1, 2, _rng.randf_range(0.3, 0.9), false)
			KEY_F2:
				_session.mods.set_flag(&"fact_checker")
				_session.owned_perks.append(_perk("UI_GAME_DEV_PERK_FACT", "UI_GAME_DEV_PERK_FACT_DESC", PerkDef.Rarity.RARE))
				EventBus.perks_changed.emit()
			KEY_F3:
				_session.mods.set_flag(&"insider_friend")
				_session.owned_perks.append(_perk("UI_GAME_DEV_PERK_INSIDER", "UI_GAME_DEV_PERK_INSIDER_DESC", PerkDef.Rarity.LEGENDARY))
				_post_rumor("UI_GAME_DEV_NEWS_1", "NOVA", 0.25, 2, 1.0, true)
				EventBus.perks_changed.emit()
			KEY_F4:
				EventBus.margin_called.emit()
			KEY_F5:
				_session.mods.can_short = false


func _next_day() -> void:
	_advance(true)


func _advance(emit: bool) -> void:
	_session.day += 1
	_session.market.step()
	for r in _session.news.pending().duplicate():
		if r.reveal_day <= _session.day:
			r.resolved = true
			_session.news.pending().erase(r)
			if emit:
				EventBus.rumor_resolved.emit(r)
	for o in _session.book.pending().duplicate():
		var price: float = _session.market.price_of(o.symbol)
		var hit: bool = (price <= o.trigger_price) if (o.kind == Order.Kind.LIMIT) == (o.side == Order.Dir.BUY) else (price >= o.trigger_price)
		if hit:
			_session.book.cancel(o.id)
			var res := _fill(o, price)
			if emit:
				EventBus.order_filled.emit(o, res)
	if emit:
		EventBus.day_advanced.emit(_session.day)
		EventBus.prices_updated.emit()
		EventBus.portfolio_changed.emit()
		if _rng.randf() < 0.5:
			var syms: Array[String] = _session.market.symbols()
			_post_rumor("UI_GAME_DEV_NEWS_1", syms[_rng.randi() % syms.size()], _rng.randf_range(-0.2, 0.2), 1 + _rng.randi() % 3, _rng.randf_range(0.3, 0.9), false)


func _fill(order: Order, price: float) -> TradeResult:
	var fee: float = price * order.shares * _session.mods.effective_fee_rate()
	_session.portfolio.apply_fill(order.symbol, order.shares if order.side == Order.Dir.BUY else -order.shares, price, fee)
	return TradeResult.success(order, price, fee)


func _submit(order: Order) -> TradeResult:
	var price: float = _session.market.price_of(order.symbol)
	var result: TradeResult
	var pos: int = _session.portfolio.shares_of(order.symbol)
	if order.side == Order.Dir.SELL and order.shares > maxi(pos, 0) and not _session.mods.can_short:
		result = TradeResult.fail("UI_GAME_DEV_ERR_SHORT", order)
	elif order.side == Order.Dir.BUY and order.kind == Order.Kind.MARKET and order.shares * price > _session.portfolio.cash * _session.mods.max_leverage + 1.0:
		result = TradeResult.fail("UI_GAME_DEV_ERR_CASH", order)
	elif order.kind == Order.Kind.MARKET:
		result = _fill(order, price)
	else:
		_session.book.place(order)
		result = TradeResult.queued(order)
		EventBus.order_placed.emit(order)
	if not result.ok:
		EventBus.trade_failed.emit(result.reason)
	else:
		EventBus.portfolio_changed.emit()
	return result


func _cancel(order_id: int) -> bool:
	var ok: bool = _session.book.cancel(order_id)
	if ok:
		EventBus.order_cancelled.emit(order_id)
	return ok


## Drives the screen through input actions and buttons, prints PASS/FAIL lines.
func _smoke() -> void:
	await get_tree().process_frame
	var fails: int = 0
	await _press("select_stock_3")
	fails += _check("select 3 -> GRNE", _screen.selected_symbol == "GRNE")
	var day: int = _session.day
	await _press("next_day")
	fails += _check("space advances day", _session.day == day + 1)
	await _press("open_menu")
	fails += _check("esc opens menu", _screen.get_node("%PauseMenu").visible)
	await _press("next_day")
	fails += _check("space blocked while menu open", _session.day == day + 1)
	await _press("open_menu")
	fails += _check("esc closes menu", not _screen.get_node("%PauseMenu").visible)
	var panel: GameOrderPanel = _screen.get_node("%OrderPanel")
	await _press("sell")
	fails += _check("S selects sell side", panel._side == Order.Dir.SELL)
	await _press("buy")
	fails += _check("B selects buy side", panel._side == Order.Dir.BUY)
	var cash: float = _session.portfolio.cash
	panel._shares.value = 5
	panel._submit.pressed.emit()
	fails += _check("market buy fills", _session.portfolio.shares_of("GRNE") == -115 and _session.portfolio.cash < cash)
	panel._kind.select(1)
	panel._on_kind_selected(1)
	panel._shares.value = 3
	panel._submit.pressed.emit()
	await get_tree().process_frame
	fails += _check("limit queues", _session.book.pending().size() == 4)
	_screen._pending._on_cancel_pressed(_session.book.pending()[3].id)
	fails += _check("cancel removes", _session.book.pending().size() == 3)
	panel._kind.select(0)
	panel._on_kind_selected(0)
	panel._shares.value = 999999
	panel._submit.pressed.emit()
	fails += _check("failure is shown", panel._status.text != "" and panel._status.get_theme_color("font_color") == GameColors.DOWN)
	print("SMOKE %s" % ("OK" if fails == 0 else "%d FAILED" % fails))


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame


func _check(label: String, ok: bool) -> int:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	return 0 if ok else 1


func _snap(dir: String, name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("saved ", name)


## Plays a short session with real input: trades, 8 days, perks, margin call, menu.
func _tour(dir: String) -> void:
	await get_tree().process_frame
	await _snap(dir, "tour_1_start")
	await _press("select_stock_6")
	var panel: GameOrderPanel = _screen.get_node("%OrderPanel")
	await _press("buy")
	panel._shares.value = 10
	panel._submit.pressed.emit()
	panel._kind.select(1)
	panel._on_kind_selected(1)
	await _press("sell")
	panel._trigger.value = snappedf(_session.market.price_of("CLDX") * 1.1, 0.01)
	panel._shares.value = 5
	panel._submit.pressed.emit()
	await _snap(dir, "tour_2_after_orders")
	for i in 8:
		await _press("next_day")
	await _snap(dir, "tour_3_day_30")
	await _press("buy")
	var f2 := InputEventKey.new()
	f2.keycode = KEY_F3
	f2.pressed = true
	Input.parse_input_event(f2)
	await get_tree().process_frame
	EventBus.margin_called.emit()
	await _snap(dir, "tour_4_insider_margin")
	await _press("open_menu")
	await _snap(dir, "tour_5_menu")
