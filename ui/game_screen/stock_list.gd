## The run's stocks (up to 6) with price, day change and held shares. Click or press 1-6 to select.
## Vertical watchlist rows by default; `horizontal` turns them into compact chips.
class_name GameStockList
extends PanelContainer

signal stock_selected(symbol: String)

@export var horizontal: bool = false
@export var show_title: bool = true
@export var show_names: bool = true
@export var row_height: int = 58

var _rows: Dictionary = {}       ## symbol -> {"button","price","change","held"}
var _group := ButtonGroup.new()
var _box: BoxContainer


func _ready() -> void:
	if horizontal:
		_box = HBoxContainer.new()
		_box.add_theme_constant_override("separation", 6)
	else:
		_box = VBoxContainer.new()
		_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	if show_title and not horizontal:
		_box.add_child(GameFmt.label(tr("UI_GAME_STOCKS"), GameColors.MUTED, 14))
	var s: GameSession = GameManager.session
	if s != null:
		for symbol in s.market.symbols():
			if horizontal:
				_add_chip(symbol)
			else:
				_add_row(symbol)
	EventBus.prices_updated.connect(_on_prices_updated)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	_refresh()


func select(symbol: String) -> void:
	if _rows.has(symbol):
		(_rows[symbol]["button"] as Button).set_pressed_no_signal(true)


func _new_button(symbol: String) -> Button:
	var button := Button.new()
	button.name = "Row_" + symbol
	button.toggle_mode = true
	button.button_group = _group
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"RowButton"
	button.pressed.connect(_on_row_pressed.bind(symbol))
	_box.add_child(button)
	return button


func _inset(button: Button) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8 if side in ["left", "right"] else 2)
	button.add_child(margin)
	return margin


## Compact chip: symbol on top, price and change below.
func _add_chip(symbol: String) -> void:
	var button := _new_button(symbol)
	button.custom_minimum_size = Vector2(0, row_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	_inset(button).add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sym := GameFmt.label(symbol, Color.WHITE, 16)
	sym.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var held := GameFmt.label("", GameColors.GOLD, 12)
	head.add_child(sym)
	head.add_child(held)
	col.add_child(head)
	var price := GameFmt.label("", Color.WHITE, 13)
	var change := GameFmt.label("", Color.WHITE, 12)
	col.add_child(price)
	col.add_child(change)
	_rows[symbol] = {"button": button, "price": price, "change": change, "held": held}


func _add_row(symbol: String) -> void:
	var s: GameSession = GameManager.session
	var button := _new_button(symbol)
	button.custom_minimum_size = Vector2(0, row_height)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset(button).add_child(row)

	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)
	left.add_child(GameFmt.label(symbol, Color.WHITE, 18))
	if show_names:
		var company: CompanyDef = s.market.company_of(symbol)
		var name_label := GameFmt.label(tr(company.display_name) if company != null else "", GameColors.MUTED, 12)
		name_label.clip_text = true
		name_label.custom_minimum_size = Vector2(110, 0)
		left.add_child(name_label)

	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	row.add_child(right)
	var price := GameFmt.label("", Color.WHITE, 18)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var change := GameFmt.label("", Color.WHITE, 13)
	change.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var held := GameFmt.label("", GameColors.GOLD, 12)
	held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(price)
	right.add_child(change)
	right.add_child(held)
	_rows[symbol] = {"button": button, "price": price, "change": change, "held": held}


func _refresh() -> void:
	var s: GameSession = GameManager.session
	if s == null:
		return
	for symbol: String in _rows:
		var r: Dictionary = _rows[symbol]
		var change: float = s.market.day_change(symbol)
		(r["price"] as Label).text = GameFmt.price(s.market.price_of(symbol))
		var cl := r["change"] as Label
		cl.text = GameColors.pct_text(change)
		cl.add_theme_color_override("font_color", GameColors.for_change(change))
		var shares: int = s.portfolio.shares_of(symbol)
		var hl := r["held"] as Label
		if shares > 0:
			hl.text = (tr("UI_GAME_HELD_LONG") % shares) if not horizontal else "●"
		elif shares < 0:
			hl.text = (tr("UI_GAME_HELD_SHORT") % -shares) if not horizontal else "▼"
		else:
			hl.text = ""
		hl.visible = shares != 0
		hl.add_theme_color_override("font_color", GameColors.GOLD)


func _on_row_pressed(symbol: String) -> void:
	stock_selected.emit(symbol)


func _on_prices_updated() -> void:
	_refresh()


func _on_portfolio_changed() -> void:
	_refresh()
