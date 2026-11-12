## Main play screen: composes TopBar, PriceChart, StockList, OrderPanel, PortfolioView,
## PendingOrdersView, RumorFeed and PerkBar. Keeps the UI-only 'selected stock' state.
## The Overlays node (draft dialog, game over dialog, audio) is wired by the lead: do not remove it.
extends Control

var selected_symbol: String = ""

@onready var _top_bar: GameTopBar = %TopBar
@onready var _stock_list: GameStockList = %StockList
@onready var _chart: GamePriceChart = %PriceChart
@onready var _order_panel: GameOrderPanel = %OrderPanel
@onready var _portfolio: GamePortfolioView = %PortfolioView
@onready var _pending: GamePendingOrdersView = %PendingOrdersView
@onready var _menu: GamePauseMenu = %PauseMenu


func _init() -> void:
	theme = GameSkins.pixel()


func _ready() -> void:
	_stock_list.stock_selected.connect(select_symbol)
	_portfolio.stock_selected.connect(select_symbol)
	_top_bar.menu_requested.connect(_menu.toggle)
	var s: GameSession = GameManager.session
	if s != null:
		var symbols: Array[String] = s.market.symbols()
		if not symbols.is_empty():
			select_symbol(symbols[0])


func select_symbol(symbol: String) -> void:
	selected_symbol = symbol
	_chart.symbol = symbol
	_order_panel.symbol = symbol
	_stock_list.select(symbol)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	if GameManager.state == GameManager.State.DRAFTING or GameManager.state == GameManager.State.GAME_OVER:
		return
	var s: GameSession = GameManager.session
	if s == null:
		return
	var symbols: Array[String] = s.market.symbols()
	for i in mini(symbols.size(), 6):
		if event.is_action_pressed("select_stock_%d" % (i + 1)):
			select_symbol(symbols[i])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("buy"):
		_order_panel.start_ticket(Order.Dir.BUY)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("sell"):
		_order_panel.start_ticket(Order.Dir.SELL)
		get_viewport().set_input_as_handled()
