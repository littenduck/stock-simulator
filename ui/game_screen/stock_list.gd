## The run's stocks (up to 6) with price, day change and held shares. Click or press 1-6 to select.
## Vertical watchlist rows.
class_name GameStockList
extends PanelContainer

signal stock_selected(symbol: String)

@export var show_title: bool = true
@export var show_names: bool = true
@export var row_height: int = 58

var _rows: Dictionary = {}       ## symbol -> {"button","price","change","held"}
var _group := ButtonGroup.new()
var _box: VBoxContainer


func _ready() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	if show_title:
		_box.add_child(GameFmt.label(tr("UI_GAME_STOCKS"), GameColors.MUTED, 14))
	var s: GameSession = GameManager.session
	if s != null:
		for symbol in s.market.symbols():
			_add_row(symbol)
	EventBus.prices_updated.connect(_on_prices_updated)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	_refresh()


func select(symbol: String) -> void:
	if _rows.has(symbol):
		var button := _rows[symbol]["button"] as Button
		var was: bool = button.button_pressed
		for other: String in _rows:
			(_rows[other]["button"] as Button).set_pressed_no_signal(other == symbol)
		if not was:
			(_rows[symbol]["badge"] as CompanyBadge).bounce()


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


func _add_row(symbol: String) -> void:
	var s: GameSession = GameManager.session
	var button := _new_button(symbol)
	button.custom_minimum_size = Vector2(0, row_height)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.set_meta("fx_hover", 1.025)
	var company: CompanyDef = s.market.company_of(symbol)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_inset(button).add_child(row)

	if company != null:
		# Thin sector-coloured stripe on the left edge of the row (sector theme colour).
		var stripe := ColorRect.new()
		stripe.color = UiPalette.sector_color(company.sector)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		stripe.offset_right = 4.0
		stripe.offset_top = 4.0
		stripe.offset_bottom = -4.0
		stripe.set_meta("no_fx", true)
		button.add_child(stripe)
	var badge := CompanyBadge.make(company.icon if company != null else "", 40, company.sector if company != null else "")
	row.add_child(badge)

	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 6)
	left.add_child(top_row)
	var ticker := GameFmt.label(symbol, Color.WHITE, 18)
	top_row.add_child(ticker)
	var spark := _Spark.new()
	spark.custom_minimum_size = Vector2(34, 18)
	spark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(spark)
	if show_names:
		var full_name: String = tr(company.display_name) if company != null else ""
		var name_label := GameFmt.label(full_name, GameColors.MUTED, 12)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size = Vector2(40, 0)
		left.add_child(name_label)
		button.tooltip_text = "%s (%s)" % [full_name, symbol]
	var held := GameFmt.label("", GameColors.GOLD, 12)
	held.clip_text = true
	held.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	held.custom_minimum_size = Vector2(40, 0)
	left.add_child(held)

	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	row.add_child(right)
	var price := GameFmt.label("", Color.WHITE, 17)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.custom_minimum_size = Vector2(78, 0)  # room for "1,484.53"
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.set_meta("no_fx", true)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	var change := GameDelta.new(12, true)
	chip.add_child(change)
	right.add_child(price)
	right.add_child(chip)
	_rows[symbol] = {"button": button, "price": price, "change": change, "chip": chip, "held": held, "badge": badge, "spark": spark}


func _refresh() -> void:
	var s: GameSession = GameManager.session
	if s == null:
		return
	for symbol: String in _rows:
		var r: Dictionary = _rows[symbol]
		var change: float = s.market.day_change(symbol)
		(r["price"] as Label).text = GameFmt.price(s.market.price_of(symbol))
		(r["change"] as GameDelta).show_change(change)
		var tone: Color = GameColors.for_change(change)
		var chip_box := StyleBoxFlat.new()
		chip_box.bg_color = Color(tone.r, tone.g, tone.b, 0.16)
		chip_box.set_corner_radius_all(8)
		chip_box.content_margin_left = 6
		chip_box.content_margin_right = 6
		chip_box.content_margin_top = 0
		chip_box.content_margin_bottom = 0
		(r["chip"] as PanelContainer).add_theme_stylebox_override("panel", chip_box)
		var spark := r["spark"] as _Spark
		spark.values = s.market.history_of(symbol)
		spark.tone = tone if tone != GameColors.FLAT else GameColors.MUTED
		spark.queue_redraw()
		var shares: int = s.portfolio.shares_of(symbol)
		var hl := r["held"] as Label
		# "16 @ 153.69": shares held and the average price paid. The tooltip spells it out.
		if shares != 0:
			var avg: float = float(s.portfolio.positions.get(symbol, {}).get("avg_cost", 0.0))
			hl.text = "%d @ %s" % [shares, GameFmt.price(avg)]
			(r["button"] as Control).tooltip_text = "%s\n%s" % [(r["button"] as Control).tooltip_text.get_slice("\n", 0), tr("UI_GAME_HELD_AVG") % [absi(shares), GameFmt.price(avg)]]
		else:
			hl.text = ""
			(r["button"] as Control).tooltip_text = (r["button"] as Control).tooltip_text.get_slice("\n", 0)
		hl.visible = shares != 0
		hl.add_theme_color_override("font_color", GameColors.GOLD if shares > 0 else GameColors.DOWN)


func _on_row_pressed(symbol: String) -> void:
	stock_selected.emit(symbol)


func _on_prices_updated() -> void:
	_refresh()


func _on_portfolio_changed() -> void:
	_refresh()


## Tiny line chart of the last closes.
class _Spark extends Control:
	const POINTS := 24
	var values := PackedFloat32Array()
	var tone: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: int = mini(values.size(), POINTS)
		if n < 2:
			return
		var first: int = values.size() - n
		var lo: float = values[first]
		var hi: float = values[first]
		for i in range(first, values.size()):
			lo = minf(lo, values[i])
			hi = maxf(hi, values[i])
		var pts := PackedVector2Array()
		for i in n:
			var x: float = 2.0 + (size.x - 4.0) * float(i) / float(n - 1)
			var y: float = 2.0 + (size.y - 4.0) * (1.0 - (values[first + i] - lo) / maxf(hi - lo, 0.0001))
			pts.append(Vector2(x, y))
		draw_polyline(pts, tone, 1.8, true)
		draw_circle(pts[n - 1], 2.2, tone)
