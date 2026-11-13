## The trade window under the chart. Two rows of big buttons, with the money on every one:
## Buy 1/4, 1/2, 3/4 or all of your cash (the button says what it will cost), Sell half or everything (what you get).
class_name TradePanel
extends PanelContainer

const BUY_STEPS := [["TABLE_Q1", 0.25], ["TABLE_Q2", 0.5], ["TABLE_Q3", 0.75], ["TABLE_ALL_IN", 1.0]]
const SELL_STEPS := [["TABLE_SELL_HALF", 0.5], ["TABLE_SELL_ALL", 1.0]]

var symbol: String = "":
	set(value):
		symbol = value
		_refresh()

var _title: Label
var _status: Label
var _buy_buttons: Array[Button] = []
var _sell_buttons: Array[Button] = []


func _ready() -> void:
	var box := TableUi.column(self, 8, 10)
	_title = GameFmt.label("", Color.WHITE, 17)
	box.add_child(_title)
	var buy_row := _row(box, "TABLE_BUY")
	for step in BUY_STEPS:
		var b := _big_button(tr(step[0]))
		b.pressed.connect(_buy.bind(float(step[1])))
		buy_row.add_child(b)
		_buy_buttons.append(b)
	var sell_row := _row(box, "TABLE_SELL")
	for step in SELL_STEPS:
		var b := _big_button(tr(step[0]))
		b.pressed.connect(_sell.bind(float(step[1])))
		sell_row.add_child(b)
		_sell_buttons.append(b)
	_status = TableUi.wrapped("", GameColors.MUTED, 13)
	_status.visible = false
	box.add_child(_status)
	EventBus.portfolio_changed.connect(_refresh)
	EventBus.table_changed.connect(_refresh)
	EventBus.prices_updated.connect(_refresh)
	_refresh()


func _big_button(text: String) -> Button:
	var b := GameFmt.button(text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 15)
	return b


## A line with a short caption on the left; the buttons are added to the returned row.
func _row(parent: VBoxContainer, caption_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var caption := GameFmt.label(tr(caption_key), GameColors.MUTED, 14)
	caption.custom_minimum_size = Vector2(40, 0)
	row.add_child(caption)
	parent.add_child(row)
	return row


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _title == null or symbol == "" or not t.market.has_symbol(symbol):
		return
	var seat := t.human()
	var open := t.phase == TableSession.Phase.ACTION and seat.alive and not t.is_finished()
	var held := seat.portfolio.shares_of(symbol)
	var avg: float = float(seat.portfolio.positions.get(symbol, {}).get("avg_cost", 0.0))
	_title.text = "%s  %s    %s" % [symbol, GameFmt.price(t.market.price_of(symbol)),
			(tr("TABLE_HOLDING") % [held, GameFmt.price(avg)]) if held != 0 else tr("TABLE_HOLDING_NONE")]
	for i in _buy_buttons.size():
		var preview := t.buy_preview(0, symbol, float(BUY_STEPS[i][1]))
		var shares := int(preview["shares"])
		_buy_buttons[i].text = "%s\n%s" % [tr(BUY_STEPS[i][0]), (tr("TABLE_COST") % [GameFmt.money(float(preview["cost"]), 0), shares]) if shares > 0 else "-"]
		_buy_buttons[i].disabled = not open or shares <= 0
	var locked := seat.mods.locked_symbol == symbol
	for i in _sell_buttons.size():
		var preview := t.sell_preview(0, symbol, float(SELL_STEPS[i][1]))
		var shares := int(preview["shares"])
		_sell_buttons[i].text = "%s\n%s" % [tr(SELL_STEPS[i][0]), (tr("TABLE_GAIN") % [GameFmt.money(float(preview["proceeds"]), 0), shares]) if shares > 0 else "-"]
		_sell_buttons[i].disabled = not open or shares <= 0 or locked
	if locked:
		_show(tr("TRADE_ERR_LOCKED"), GameColors.WARN)


func _buy(fraction: float) -> void:
	_report(TableUi.session().buy_fraction(0, symbol, fraction), "TABLE_BOUGHT")


func _sell(fraction: float) -> void:
	_report(TableUi.session().sell_fraction(0, symbol, fraction), "TABLE_SOLD")


func _report(res: TradeResult, key: String) -> void:
	if not res.ok:
		_show(tr(res.reason), GameColors.DOWN)
		return
	_show(tr(key) % [res.shares, res.order.symbol, GameFmt.price(res.price)], GameColors.UP)
	EventBus.order_filled.emit(res.order, res)    # the buy / sell sound
	GameManager.table_refresh()


func _show(text: String, color: Color) -> void:
	if _status != null:
		_status.text = text
		_status.visible = text != ""
		GameFmt.tint(_status, color)
