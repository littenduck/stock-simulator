## Table-mode play screen, three columns: the stocks on the left (shares held and average price are in the list),
## the chart and the trade window in the middle, the rumor feed on the right. Every new rumor pops up as a card
## where you choose BELIEVE / BULLSHIT / PASS; the feed then shows what you chose.
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
@onready var _card: RumorCard = %RumorCard

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
	_card.closed.connect(_on_card_closed)
	_update_blind_note()
	# The first rumor of a new run (or of a continued one) pops up once the screen has faded in.
	if t != null and t.phase == TableSession.Phase.ACTION and not t.is_finished():
		get_tree().create_timer(0.7).timeout.connect(_offer_cards)


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


## Today's card first (unless you already chose), then the Boss card when a new one is open.
func _offer_cards() -> void:
	var t := TableUi.session()
	if t == null or t.phase != TableSession.Phase.ACTION:
		return
	if t.calls.has(0) or t.copy_targets.has(0):
		_offer_boss()
	else:
		_card.open(false)


func _offer_boss() -> void:
	var t := TableUi.session()
	if t == null or t.boss_rumor == null or t.boss_bet_of(0) != null or t.boss_rumor.id == _boss_shown_id:
		return
	_boss_shown_id = t.boss_rumor.id
	_card.open(true)


func _on_result_closed() -> void:
	if _card_due:
		_card_due = false
		_offer_cards()


func _on_card_closed(boss: bool) -> void:
	if not boss:
		get_tree().create_timer(0.25).timeout.connect(_offer_boss)


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
