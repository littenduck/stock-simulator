## Order ticket: market / limit / stop, buy or sell (selling beyond holdings opens a short).
## Builds an Order and sends it through GameCommands (GameManager). Never decides rules:
## the numbers shown here are estimates, the engine's answer is shown as-is.
class_name GameOrderPanel
extends PanelContainer

var symbol: String = "":
	set(value):
		var changed: bool = value != symbol
		symbol = value
		if changed:
			_reset_trigger()
		_refresh()

var _side: Order.Dir = Order.Dir.BUY
var _title: Label
var _position: Label
var _buy: Button
var _sell: Button
var _kind: OptionButton
var _shares: SpinBox
var _max: Button
var _trigger_row: HBoxContainer
var _trigger: SpinBox
var _hint: Label
var _effect: Label
var _estimate: Label
var _submit: Button
var _status: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_title = GameFmt.label("", Color.WHITE, 20)
	box.add_child(_title)
	_position = GameFmt.label("", GameColors.MUTED, 13)
	box.add_child(_position)

	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 6)
	box.add_child(sides)
	var group := ButtonGroup.new()
	_buy = _side_button(group, tr("UI_GAME_BUY") + " [B]", true)
	_sell = _side_button(group, tr("UI_GAME_SELL_SHORT") + " [S]", false)
	_buy.toggled.connect(_on_buy_toggled)
	_sell.toggled.connect(_on_sell_toggled)
	sides.add_child(_buy)
	sides.add_child(_sell)

	_kind = OptionButton.new()
	_kind.name = "KindOption"
	_kind.focus_mode = Control.FOCUS_NONE
	_kind.add_item(tr("UI_GAME_KIND_MARKET"), Order.Kind.MARKET)
	_kind.add_item(tr("UI_GAME_KIND_LIMIT"), Order.Kind.LIMIT)
	_kind.add_item(tr("UI_GAME_KIND_STOP"), Order.Kind.STOP)
	_kind.item_selected.connect(_on_kind_selected)
	box.add_child(_labelled_row(tr("UI_GAME_ORDER_TYPE"), _kind))

	var shares_row := HBoxContainer.new()
	shares_row.add_theme_constant_override("separation", 6)
	_shares = SpinBox.new()
	_shares.name = "SharesSpinBox"
	_shares.min_value = 1
	_shares.max_value = 1000000
	_shares.step = 1
	_shares.value = 1
	_shares.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shares.value_changed.connect(_on_shares_changed)
	_shares.get_line_edit().text_submitted.connect(_on_shares_submitted)
	_max = GameFmt.button(tr("UI_GAME_MAX"))
	_max.tooltip_text = tr("UI_GAME_MAX_TIP")
	_max.pressed.connect(_on_max_pressed)
	shares_row.add_child(_shares)
	shares_row.add_child(_max)
	box.add_child(_labelled_row(tr("UI_GAME_SHARES"), shares_row))

	_trigger = SpinBox.new()
	_trigger.name = "TriggerSpinBox"
	_trigger.min_value = 0.01
	_trigger.max_value = 1000000
	_trigger.step = 0.01
	_trigger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trigger.value_changed.connect(_on_trigger_changed)
	_trigger_row = _labelled_row(tr("UI_GAME_TRIGGER_PRICE"), _trigger)
	box.add_child(_trigger_row)
	_hint = GameFmt.label("", GameColors.MUTED, 12)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)

	_effect = GameFmt.label("", Color.WHITE, 13)
	box.add_child(_effect)
	_estimate = GameFmt.label("", GameColors.MUTED, 13)
	box.add_child(_estimate)

	_submit = GameFmt.button("")
	_submit.name = "SubmitButton"
	_submit.custom_minimum_size = Vector2(0, 42)
	_submit.pressed.connect(_on_submit_pressed)
	box.add_child(_submit)
	_status = GameFmt.label("", GameColors.MUTED, 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 34)
	box.add_child(_status)

	EventBus.prices_updated.connect(_on_prices_updated)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	EventBus.trade_failed.connect(_on_trade_failed)
	EventBus.order_filled.connect(_on_order_filled)
	EventBus.perks_changed.connect(_on_perks_changed)
	_refresh()


## B / S shortcuts: choose the side and jump into the share box (Enter submits).
func start_ticket(side: Order.Dir) -> void:
	(_buy if side == Order.Dir.BUY else _sell).button_pressed = true
	_shares.get_line_edit().grab_focus()
	_shares.get_line_edit().select_all()


func _side_button(group: ButtonGroup, text: String, pressed: bool) -> Button:
	var b := GameFmt.button(text)
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = pressed
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 36)
	return b


func _labelled_row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := GameFmt.label(caption, GameColors.MUTED, 14)
	l.custom_minimum_size = Vector2(96, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _kind_id() -> int:
	return _kind.get_selected_id()


func _price_now() -> float:
	var s: GameSession = GameManager.session
	return s.market.price_of(symbol) if s != null and symbol != "" else 0.0


func _reset_trigger() -> void:
	if _trigger != null:
		_trigger.set_value_no_signal(snappedf(_price_now(), 0.01))


func _fee_rate() -> float:
	var s: GameSession = GameManager.session
	return s.mods.effective_fee_rate() if s != null else 0.0


func _refresh() -> void:
	if not is_node_ready():
		return
	var s: GameSession = GameManager.session
	if s == null or symbol == "":
		return
	var price: float = _price_now()
	var pos: int = s.portfolio.shares_of(symbol)
	var is_buy: bool = _side == Order.Dir.BUY
	var kind: int = _kind_id()
	var n: int = int(_shares.value)

	_title.text = "%s  @ %s" % [symbol, GameFmt.price(price)]
	if pos > 0:
		_position.text = tr("UI_GAME_POSITION_LONG") % [pos, GameFmt.price(float(s.portfolio.positions[symbol].get("avg_cost", 0.0)))]
	elif pos < 0:
		_position.text = tr("UI_GAME_POSITION_SHORT") % [-pos, GameFmt.price(float(s.portfolio.positions[symbol].get("avg_cost", 0.0)))]
	else:
		_position.text = tr("UI_GAME_POSITION_NONE")

	_trigger_row.visible = kind != Order.Kind.MARKET
	_hint.visible = kind != Order.Kind.MARKET
	if kind == Order.Kind.LIMIT:
		_hint.text = tr("UI_GAME_HINT_LIMIT_BUY") if is_buy else tr("UI_GAME_HINT_LIMIT_SELL")
	elif kind == Order.Kind.STOP:
		_hint.text = tr("UI_GAME_HINT_STOP_BUY") if is_buy else tr("UI_GAME_HINT_STOP_SELL")

	var effect_key: String
	var effect_color: Color = Color.WHITE
	if is_buy:
		if pos >= 0:
			effect_key = "UI_GAME_EFFECT_OPEN_LONG"
		elif n <= -pos:
			effect_key = "UI_GAME_EFFECT_COVER_SHORT"
		else:
			effect_key = "UI_GAME_EFFECT_COVER_THEN_LONG"
	else:
		if pos <= 0:
			effect_key = "UI_GAME_EFFECT_OPEN_SHORT"
			effect_color = GameColors.WARN
		elif n <= pos:
			effect_key = "UI_GAME_EFFECT_CLOSE_LONG"
		else:
			effect_key = "UI_GAME_EFFECT_CLOSE_THEN_SHORT"
			effect_color = GameColors.WARN
	var text: String = tr(effect_key)
	var opens_short: bool = not is_buy and n > maxi(pos, 0)
	if opens_short and not s.mods.can_short:
		text = tr("UI_GAME_SHORT_DISABLED")
		effect_color = GameColors.DOWN
	_effect.text = text
	GameFmt.tint(_effect, effect_color)

	var ref_price: float = price if kind == Order.Kind.MARKET else _trigger.value
	var value: float = ref_price * n
	_estimate.text = tr("UI_GAME_ESTIMATE") % [GameFmt.money(value), GameFmt.money(value * _fee_rate())]

	var side_text: String = tr("UI_GAME_BUY") if is_buy else tr("UI_GAME_SELL")
	_submit.text = "%s %d %s" % [side_text, n, symbol]
	_submit.theme_type_variation = &"BuyButton" if is_buy else &"SellButton"


func _on_buy_toggled(pressed: bool) -> void:
	if pressed:
		_side = Order.Dir.BUY
		_refresh()


func _on_sell_toggled(pressed: bool) -> void:
	if pressed:
		_side = Order.Dir.SELL
		_refresh()


func _on_kind_selected(_index: int) -> void:
	_reset_trigger()
	_refresh()


func _on_shares_changed(_value: float) -> void:
	_refresh()


func _on_trigger_changed(_value: float) -> void:
	_refresh()


func _on_shares_submitted(_text: String) -> void:
	_shares.apply()
	_on_submit_pressed()
	_shares.get_line_edit().release_focus()


## Estimate only: cash for buys, holdings (or leverage headroom for shorts) for sells.
func _on_max_pressed() -> void:
	var s: GameSession = GameManager.session
	if s == null or symbol == "":
		return
	var price: float = _price_now()
	var unit: float = maxf(price * (1.0 + _fee_rate()), 0.0001)
	var pos: int = s.portfolio.shares_of(symbol)
	var m: int
	if _side == Order.Dir.BUY:
		m = int(floor(maxf(s.portfolio.cash, 0.0) / unit))
		if pos < 0:
			m = maxi(m, -pos)
	elif pos > 0:
		m = pos
	else:
		var headroom: float = s.portfolio.net_worth(s.market) * s.mods.max_leverage - s.portfolio.gross_exposure(s.market)
		m = int(floor(maxf(headroom, 0.0) / unit)) if s.mods.can_short else 0
	_shares.value = maxi(m, 1)


func _on_submit_pressed() -> void:
	if symbol == "":
		return
	var n: int = int(_shares.value)
	var kind: int = _kind_id()
	if n <= 0:
		_set_status(tr("UI_GAME_ERR_SHARES"), GameColors.DOWN)
		return
	var order: Order
	match kind:
		Order.Kind.LIMIT:
			order = Order.limit(_side, symbol, n, _trigger.value)
		Order.Kind.STOP:
			order = Order.stop(_side, symbol, n, _trigger.value)
		_:
			order = Order.market(_side, symbol, n)
	var result: TradeResult = GameCommands.submit_order(order)
	if result == null:
		return
	if not result.ok:
		_set_status(tr(result.reason), GameColors.DOWN)
	elif result.pending:
		_set_status(tr("UI_GAME_ORDER_QUEUED") % [order.id, symbol], GameColors.GOLD)
	else:
		_report_fill(result)


func _report_fill(result: TradeResult) -> void:
	var side_text: String = tr("UI_GAME_BOUGHT") if result.order.side == Order.Dir.BUY else tr("UI_GAME_SOLD")
	_set_status(tr("UI_GAME_FILLED") % [side_text, result.shares, result.order.symbol, GameFmt.price(result.price), GameFmt.price(result.fee)], GameColors.UP)


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _on_trade_failed(reason: String) -> void:
	_set_status(tr(reason), GameColors.DOWN)


func _on_order_filled(order: Order, result: TradeResult) -> void:
	# Only pending orders fill later; immediate fills are reported by _on_submit_pressed.
	if order.id != 0 and result.ok:
		_report_fill(result)


func _on_prices_updated() -> void:
	_refresh()


func _on_portfolio_changed() -> void:
	_refresh()


func _on_perks_changed() -> void:
	_refresh()
