## Pending limit / stop orders with a cancel button each.
class_name GamePendingOrdersView
extends PanelContainer

signal stock_selected(symbol: String)

var _list: VBoxContainer
var _refresh_queued: bool = false
var _empty: Label


@export var show_title: bool = true


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	if show_title:
		box.add_child(GameFmt.label(tr("UI_GAME_PENDING_ORDERS"), GameColors.MUTED, 14))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "OrderList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_empty = GameFmt.label(tr("UI_GAME_NO_PENDING"), GameColors.MUTED, 14)
	_list.add_child(_empty)

	EventBus.order_placed.connect(_on_order_placed)
	EventBus.order_cancelled.connect(_on_order_cancelled)
	EventBus.order_filled.connect(_on_order_filled)
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	_refresh()


## Several signals fire per action/day; rebuild once per frame.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	var s: GameSession = GameManager.session
	if s == null or not is_node_ready():
		return
	for child in _list.get_children():
		if child != _empty:
			_list.remove_child(child)
			child.queue_free()
	var orders: Array[Order] = s.book.pending()
	_empty.visible = orders.is_empty()
	for order in orders:
		_list.add_child(_make_row(order))


func _make_row(order: Order) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var is_buy: bool = order.side == Order.Dir.BUY
	var kind_text: String = tr("UI_GAME_KIND_LIMIT") if order.kind == Order.Kind.LIMIT else tr("UI_GAME_KIND_STOP")
	var company: CompanyDef = GameManager.session.market.company_of(order.symbol) if GameManager.session != null else null
	row.add_child(CompanyBadge.make(company.icon if company != null else "", 32, company.sector if company != null else ""))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var head := tr("UI_GAME_BUY") if is_buy else tr("UI_GAME_SELL")
	text.add_child(GameFmt.label("%s %d %s" % [head, order.shares, order.symbol], GameColors.UP if is_buy else GameColors.DOWN, 14))
	text.add_child(GameFmt.label("%s @ %s" % [kind_text, GameFmt.price(order.trigger_price)], GameColors.MUTED, 13))
	row.add_child(text)
	var cancel := GameFmt.button("")
	cancel.icon = GameIcons.tex("cross")
	cancel.expand_icon = true
	cancel.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel.custom_minimum_size = Vector2(36, 32)
	cancel.tooltip_text = tr("UI_GAME_CANCEL_TIP") % order.id
	cancel.pressed.connect(_on_cancel_pressed.bind(order.id))
	row.add_child(cancel)
	return row


func _on_cancel_pressed(order_id: int) -> void:
	GameCommands.cancel_order(order_id)
	_queue_refresh()


func _on_order_placed(_order: Order) -> void:
	_queue_refresh()


func _on_order_cancelled(_order_id: int) -> void:
	_queue_refresh()


func _on_order_filled(_order: Order, _result: TradeResult) -> void:
	_queue_refresh()


func _on_day_advanced(_day: int) -> void:
	_queue_refresh()


func _on_portfolio_changed() -> void:
	_queue_refresh()
