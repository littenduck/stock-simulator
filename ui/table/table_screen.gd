## Table-mode play screen, three columns: the stocks on the left (shares held and average price are in the list),
## the chart and the trade window in the middle, the rumor feed on the right. A turn bar at the bottom shows the four
## steps of the day and holds the Next button.
##   1 Pre-market: the verdict on yesterday's rumor, then today's news flies into the feed.
##   2 Market open: you trade and choose BELIEVE / BULLSHIT / PASS (open the card from the feed), then press Next.
##   3 After-market: everybody's bets are revealed.   4 Next day: the price moves, back to step 1.
extends Control

var selected_symbol: String = ""

@onready var _top_bar: GameTopBar = %TopBar
@onready var _stock_list: GameStockList = %StockList
@onready var _chart: GamePriceChart = %PriceChart
@onready var _trade: TradePanel = %TradePanel
@onready var _menu: GamePauseMenu = %PauseMenu
@onready var _chart_card: Control = %ChartCard
@onready var _blind_note: Label = %BlindNote
@onready var _overlay: TableOverlay = %TableOverlay
@onready var _feed: Control = %Feed
@onready var _overlays: Control = $Overlays

var _card_due: bool = false
var _boss_shown_id: int = -1


func _init() -> void:
	theme = GameSkins.pixel()


func _ready() -> void:
	UiFx.install(get_tree())
	PanelFx.decorate_tree($Layout)
	_stock_list.stock_selected.connect(select_symbol)
	_top_bar.menu_requested.connect(_menu.toggle)
	var t := TableUi.session()
	if t != null:
		var symbols: Array[String] = t.market.symbols()
		if not symbols.is_empty():
			select_symbol(symbols[0])
		# Goldfish Gus forgets everything but today: no chart.
		var blind := t.human().has_flag(&"goldfish")
		_chart_card.visible = not blind
		_blind_note.visible = blind
	EventBus.prices_updated.connect(_update_blind_note)
	EventBus.table_resolved.connect(func(report: TableReport) -> void: _card_due = not report.finished)
	_overlay.result_closed.connect(_on_result_closed)
	_update_blind_note()
	var banner := StepBanner.new()    # sweeps across the screen whenever the turn changes step
	add_child(banner)
	banner.watch(%TurnBar)
	_start_of_screen()


## A new run opens with the pre-market of day 0. A continued run goes straight on from where it was saved.
func _start_of_screen() -> void:
	var t := TableUi.session()
	if t == null or t.is_finished():
		return
	TableUi.modal_open = false
	if t.phase == TableSession.Phase.REVEALED:
		# Saved between the reveal and the verdict: let the day resolve.
		EventBus.table_step.emit(TurnBar.Step.AFTER)
		get_tree().create_timer(0.8).timeout.connect(GameManager.next_day)
	elif t.calls.has(0) or t.copy_targets.has(0) or t.day > 0:
		EventBus.table_step.emit(TurnBar.Step.OPEN)
	elif GameSettings.opening_enabled() and GameManager.opening_pending:
		GameManager.opening_pending = false
		_play_opening()
	else:
		_begin_day(0.8)


## The opening of a new run: everything is hidden, then rivals, players, stocks, chart and feed come in one by one.
## When it is over (or skipped) the first day starts as usual.
func _play_opening() -> void:
	var opening := TableOpening.new()
	add_child(opening)
	opening.prepare({"stock_list": _stock_list, "chart_card": _chart_card, "chart": _chart, "trade": _trade,
			"feed": _feed, "turn_bar": %TurnBar})
	opening.play()
	await opening.finished
	opening.queue_free()
	_begin_day(0.3)


func select_symbol(symbol: String) -> void:
	selected_symbol = symbol
	_chart.symbol = symbol
	_trade.symbol = symbol
	_stock_list.select(symbol)
	_update_blind_note()


func _update_blind_note() -> void:
	var t := TableUi.session()
	if t == null or not _blind_note.visible or selected_symbol == "":
		return
	_blind_note.text = tr("TABLE_BLIND_NOTE") % [selected_symbol, GameFmt.money(t.market.price_of(selected_symbol))]


func _on_result_closed() -> void:
	if _card_due:
		_card_due = false
		var t := TableUi.session()
		if t != null:
			# The day turns over: night to dawn, the day counter flips, and only then the pre-market begins.
			await DayTransition.play(self, t.day - 1, t.day, t.config.trading_days)
			await SkillFx.play_all(self, t.take_skill_events(TableSkills.Slot.NEXT_DAY), t)
		_begin_day(0.3)


## Pre-market, after the verdict: today's news pops up and flies into the feed (the Boss rumor too, when a new one
## opens), then the market is open and the turn waits for you.
func _begin_day(delay: float) -> void:
	EventBus.table_step.emit(TurnBar.Step.PRE)
	# The PRE-MARKET banner has the screen first; the news comes in once it has swept past.
	await get_tree().create_timer(maxf(delay, 1.5)).timeout
	var t := TableUi.session()
	if t == null or not is_inside_tree():
		return
	await _play_news(false)
	t = TableUi.session()
	if t != null and t.boss_rumor != null and t.boss_rumor.id != _boss_shown_id and t.boss_bet_of(0) == null:
		_boss_shown_id = t.boss_rumor.id
		await _play_news(true)
	# Pre-market skills (an Insider's tip, Hana's first purchase) play before the market can open.
	t = TableUi.session()
	if t != null:
		await SkillFx.play_all(self, t.take_skill_events(TableSkills.Slot.PRE_MARKET), t)
	EventBus.table_step_ready.emit(TurnBar.Step.PRE)    # the news is in the feed: Next opens the market


## The news window: it pops up in the middle, waits a moment, then shrinks and flies into the rumor feed.
func _play_news(boss: bool) -> void:
	var t := TableUi.session()
	if t == null:
		return
	var rumor := t.boss_rumor if boss else t.today_rumor
	if rumor == null:
		return
	var window := PanelContainer.new()
	window.theme_type_variation = &"DialogPanel"
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.custom_minimum_size = Vector2(420, 0)
	# The frame takes the colour of the news: purple for the Boss, green for a rise, red for a fall.
	var accent := Color("#b57bee") if boss else (Color("#3fb950") if rumor.claim_dir > 0 else Color("#f85149"))
	window.self_modulate = Color.WHITE.lerp(accent, 0.07)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(col)
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.custom_minimum_size = Vector2(0, 8)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.set_meta("no_fx", true)
	col.add_child(stripe)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var company: CompanyDef = t.market.company_of(rumor.primary_symbol())
	if company != null:
		row.add_child(CompanyBadge.make(company.icon, 60, company.sector))
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)
	var tag_text := (tr("TABLE_BOSS_TAG") + " " + tr("TABLE_NEWS")).to_upper() if boss else tr("TABLE_NEWS")
	text_col.add_child(GameFmt.label(tag_text, accent.darkened(0.25), 16))
	var headline := TableUi.wrapped(rumor.headline(tr, t.market), Color("#2b2540"), 18)
	headline.visible_ratio = 0.0
	text_col.add_child(headline)
	_overlays.add_child(window)
	await get_tree().process_frame
	window.size = window.get_combined_minimum_size()
	window.position = Vector2((size.x - window.size.x) * 0.5, size.y * 0.30)
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.2, 0.2)
	window.rotation = 0.12
	window.modulate.a = 0.0
	TableFx.sfx(&"rumor_posted")
	var pop := window.create_tween().set_parallel(true)
	pop.tween_property(window, "modulate:a", 1.0, 0.1)
	pop.tween_property(window, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(window, "rotation", -0.03, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	var type := headline.create_tween()
	type.tween_property(headline, "visible_ratio", 1.0, clampf(headline.text.length() * 0.02, 0.5, 1.2))
	await type.finished
	await get_tree().create_timer(1.0).timeout
	# Fly into the feed.
	var target := _feed.global_position + Vector2(_feed.size.x * 0.5, 80.0) - window.size * 0.5
	var fly := window.create_tween().set_parallel(true)
	fly.tween_property(window, "position", target - global_position, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(window, "scale", Vector2(0.28, 0.28), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(window, "rotation", 0.0, 0.6)
	fly.tween_property(window, "modulate:a", 0.0, 0.2).set_delay(0.45)
	await fly.finished
	window.queue_free()
	TableFx.sfx(&"reveal_tick")
	TableFx.flash(self, Color("#e3b341"), 0.12, 0.4)
	EventBus.table_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	if GameManager.state == GameManager.State.GAME_OVER:
		return
	var t := TableUi.session()
	if t == null:
		return
	var symbols: Array[String] = t.market.symbols()
	for i in mini(symbols.size(), 6):
		if event.is_action_pressed("select_stock_%d" % (i + 1)):
			select_symbol(symbols[i])
			get_viewport().set_input_as_handled()
			return
