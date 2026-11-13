## Five simple trade buttons for the selected stock: buy 1/4, 1/2, 3/4 or all of your cash, sell half or everything,
## and swap one stock for another. Share counts are worked out by TableSession; the old order forms stay in the core.
class_name TradePanel
extends PanelContainer

var symbol: String = "":
	set(value):
		symbol = value
		_refresh()

var _title: Label
var _status: Label
var _buy_buttons: Array[Button] = []
var _sell_half: Button
var _sell_all: Button
var _swap_target: OptionButton
var _swap_button: Button


func _ready() -> void:
	var box := TableUi.column(self, 4, 6)
	_title = GameFmt.label("", Color.WHITE, 15)    # kept for the refresh code, not shown
	var buy_row := _row(box, "TABLE_BUY")
	for pair in [["TABLE_Q1", 0.25], ["TABLE_Q2", 0.5], ["TABLE_Q3", 0.75], ["TABLE_ALL_IN", 1.0]]:
		var b := GameFmt.button(tr(pair[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_buy.bind(float(pair[1])))
		buy_row.add_child(b)
		_buy_buttons.append(b)
	var sell_row := _row(box, "TABLE_SELL")
	_sell_half = GameFmt.button(tr("TABLE_SELL_HALF"))
	_sell_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_half.pressed.connect(_sell.bind(0.5))
	_sell_all = GameFmt.button(tr("TABLE_SELL_ALL"))
	_sell_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_all.pressed.connect(_sell.bind(1.0))
	sell_row.add_child(_sell_half)
	sell_row.add_child(_sell_all)
	_swap_target = OptionButton.new()
	_swap_target.focus_mode = Control.FOCUS_NONE
	_swap_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_row.add_child(_swap_target)
	_swap_button = GameFmt.button(tr("TABLE_SWAP_BTN"))
	_swap_button.pressed.connect(_swap)
	sell_row.add_child(_swap_button)
	_status = TableUi.wrapped("", GameColors.MUTED, 12)
	_status.visible = false
	box.add_child(_status)
	EventBus.portfolio_changed.connect(_refresh)
	EventBus.table_changed.connect(_refresh)
	EventBus.prices_updated.connect(_refresh)
	_refresh()


## A line with a short caption on the left; the buttons are added to the returned row.
func _row(parent: VBoxContainer, caption_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var caption := GameFmt.label(tr(caption_key), GameColors.MUTED, 12)
	caption.custom_minimum_size = Vector2(34, 0)
	row.add_child(caption)
	parent.add_child(row)
	return row


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _title == null or symbol == "" or not t.market.has_symbol(symbol):
		return
	_title.text = "%s  %s" % [symbol, GameFmt.price(t.market.price_of(symbol))]
	var seat := t.human()
	var open := t.phase == TableSession.Phase.ACTION and seat.alive and not t.is_finished()
	var price := t.market.price_of(symbol)
	for b in _buy_buttons:
		b.disabled = not open or seat.portfolio.cash < price
	var held := seat.portfolio.shares_of(symbol)
	var locked := seat.mods.locked_symbol == symbol
	_sell_half.disabled = not open or held <= 0 or locked
	_sell_all.disabled = _sell_half.disabled
	var selected_target := _swap_target.get_item_text(_swap_target.selected) if _swap_target.item_count > 0 else ""
	_swap_target.clear()
	for s in t.market.symbols():
		if s != symbol:
			_swap_target.add_item(s)
			if s == selected_target:
				_swap_target.select(_swap_target.item_count - 1)
	_swap_button.disabled = not open or held <= 0 or locked or _swap_target.item_count == 0
	if locked:
		_show(tr("TRADE_ERR_LOCKED"), GameColors.WARN)


func _buy(fraction: float) -> void:
	var t := TableUi.session()
	_report(t.buy_fraction(0, symbol, fraction), "TABLE_BOUGHT")


func _sell(fraction: float) -> void:
	var t := TableUi.session()
	_report(t.sell_fraction(0, symbol, fraction), "TABLE_SOLD")


func _swap() -> void:
	var t := TableUi.session()
	var target := _swap_target.get_item_text(_swap_target.selected)
	var res := t.swap(0, symbol, target)
	if res.ok:
		_show(tr("TABLE_SWAPPED") % [symbol, target], GameColors.UP)
		GameManager.table_refresh()
	else:
		_show(tr(res.reason), GameColors.DOWN)


func _report(res: TradeResult, key: String) -> void:
	if not res.ok:
		_show(tr(res.reason), GameColors.DOWN)
		return
	_show(tr(key) % [res.shares, res.order.symbol, GameFmt.price(res.price)], GameColors.UP)
	GameManager.table_refresh()


func _show(text: String, color: Color) -> void:
	if _status != null:
		_status.text = text
		_status.visible = text != ""
		GameFmt.tint(_status, color)
