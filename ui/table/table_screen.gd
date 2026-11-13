## Table-mode play screen: standings on top, chart and portfolio in the middle, the rumor, the three buttons and
## the trade buttons on the right. Keeps the 'selected stock' like the classic screen does.
extends Control

var selected_symbol: String = ""

@onready var _top_bar: GameTopBar = %TopBar
@onready var _stock_list: GameStockList = %StockList
@onready var _chart: GamePriceChart = %PriceChart
@onready var _trade: TradePanel = %TradePanel
@onready var _portfolio: GamePortfolioView = %PortfolioView
@onready var _menu: GamePauseMenu = %PauseMenu
@onready var _chart_card: Control = %ChartCard
@onready var _blind_note: Label = %BlindNote


func _init() -> void:
	theme = GameSkins.pixel()


func _ready() -> void:
	UiFx.install(get_tree())
	PanelFx.decorate_tree($Layout)
	_stock_list.stock_selected.connect(select_symbol)
	_portfolio.stock_selected.connect(select_symbol)
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
	_update_blind_note()


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
