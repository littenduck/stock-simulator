## Candlestick (or line) chart of one stock plus a header. Draws pre-game lookback bars dimmed behind a
## "run starts" divider, the average cost and pending-order trigger lines, a hover tooltip with the date and
## open/high/low/close, and grows the newest candle when the day advances.
## Read-only: reads GameManager.session and redraws on EventBus.prices_updated.
class_name GamePriceChart
extends VBoxContainer

enum Mode { CANDLES, LINE }

const MARGIN_RIGHT := 64.0
const MARGIN_TOP := 10.0
const MARGIN_BOTTOM := 24.0
const DIM := 0.55
const GROW_TIME := 0.5

## Remembered across stocks and runs while the game is open.
static var mode: Mode = Mode.CANDLES

var symbol: String = "":
	set(value):
		var changed: bool = value != symbol
		symbol = value
		_hover_index = -1
		if changed:
			_known_size = -1
			_stop_growth()
		_refresh()

## 0..1 growth of the newest candle (tweened).
var grow: float = 1.0:
	set(value):
		grow = value
		if _canvas != null:
			_canvas.queue_redraw()

## 0..1 share of the bars drawn, left to right. Only the opening animation sets it below 1.
var reveal: float = 1.0:
	set(value):
		reveal = value
		if _canvas != null:
			_canvas.queue_redraw()

var _badge: CompanyBadge
var _title: Label
var _company: Label
var _price: Label
var _change: GameDelta
var _range: Label
var _candle_btn: Button
var _line_btn: Button
var _canvas: Control
var _hover_index: int = -1
var _plot := Rect2()
var _known_size: int = -1
var _grow_tween: Tween
var _range_from := Vector2.ZERO
var _range_shown := Vector2.ZERO
var _has_range: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	add_child(head)
	_badge = CompanyBadge.make("", 48)
	head.add_child(_badge)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	_title = GameFmt.label("", Color.WHITE, 28)
	_company = GameFmt.label("", GameColors.MUTED, 14)
	_company.clip_text = true
	_company.custom_minimum_size = Vector2(60, 0)
	names.add_child(_title)
	names.add_child(_company)
	head.add_child(names)
	var quote := VBoxContainer.new()
	quote.add_theme_constant_override("separation", -2)
	quote.alignment = BoxContainer.ALIGNMENT_CENTER
	_price = GameFmt.label("", Color.WHITE, 28)
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_change = GameDelta.new(16, true)
	quote.add_child(_price)
	quote.add_child(_change)
	head.add_child(quote)

	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 6)
	add_child(sub)
	_range = GameFmt.label("", GameColors.MUTED, 13)
	_range.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_range.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(_range)
	var group := ButtonGroup.new()
	_candle_btn = _mode_button(group, tr("UI_GAME_CHART_CANDLES"), Mode.CANDLES)
	_line_btn = _mode_button(group, tr("UI_GAME_CHART_LINE"), Mode.LINE)
	sub.add_child(_candle_btn)
	sub.add_child(_line_btn)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.theme_type_variation = &"ChartPanel"
	add_child(frame)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.custom_minimum_size = Vector2(200, 100)
	_canvas.clip_contents = true
	_canvas.draw.connect(_on_canvas_draw)
	_canvas.gui_input.connect(_on_canvas_gui_input)
	_canvas.mouse_exited.connect(_on_canvas_mouse_exited)
	frame.add_child(_canvas)

	EventBus.prices_updated.connect(_on_prices_updated)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	EventBus.order_placed.connect(_on_order_changed)
	EventBus.order_cancelled.connect(_on_order_cancelled)
	_refresh()


func _mode_button(group: ButtonGroup, text: String, value: Mode) -> Button:
	var b := GameFmt.button(text)
	b.name = "ModeButton_%d" % value
	b.toggle_mode = true
	b.button_group = group
	b.theme_type_variation = &"ChipButton"
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(76, 0)
	b.button_pressed = mode == value
	b.toggled.connect(func(on: bool) -> void:
		if on:
			set_mode(value))
	return b


func set_mode(value: Mode) -> void:
	mode = value
	if _candle_btn != null:
		_candle_btn.set_pressed_no_signal(value == Mode.CANDLES)
		_line_btn.set_pressed_no_signal(value == Mode.LINE)
	if _canvas != null:
		_canvas.queue_redraw()


func _refresh() -> void:
	if not is_node_ready():
		return
	var s: GameSession = GameManager.session
	if s != null and symbol != "":
		var company: CompanyDef = s.market.company_of(symbol)
		var change: float = s.market.day_change(symbol)
		_title.text = symbol
		_badge.sector = company.sector if company != null else ""
		_badge.icon_name = company.icon if company != null else ""
		_company.text = "%s · %s" % [tr(company.display_name), company.sector.capitalize()] if company != null else ""
		_company.add_theme_color_override("font_color", UiPalette.sector_deep(company.sector) if company != null else GameColors.MUTED)
		_price.text = GameFmt.price(s.market.price_of(symbol))
		_change.show_change(change)
		var c: Dictionary = s.market.candles_of(symbol)
		var h: PackedFloat32Array = s.market.history_of(symbol)
		if h.size() > 0:
			var r: Vector2 = ChartMath.range_of(c, 0, h.size() - 1)
			_range.text = tr("UI_GAME_HIGH_LOW") % [r.y, r.x]
		_start_growth_if_new_bar(h.size())
	_canvas.queue_redraw()


## A new bar arrived for the same stock: grow it from a flat open to its real shape.
func _start_growth_if_new_bar(n: int) -> void:
	var grew: bool = _known_size > 0 and n == _known_size + 1
	_known_size = n
	if not grew or not is_inside_tree() or not _has_range:
		return
	_stop_growth()
	_range_from = _range_shown
	grow = 0.0
	_grow_tween = create_tween()
	_grow_tween.tween_property(self, "grow", 1.0, GROW_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _stop_growth() -> void:
	if _grow_tween != null and _grow_tween.is_valid():
		_grow_tween.kill()
	_grow_tween = null
	grow = 1.0


## Bars of the shown stock with the newest one possibly mid-growth. {} when there is nothing to draw.
func _bars(s: GameSession) -> Dictionary:
	var closes: PackedFloat32Array = s.market.history_of(symbol)
	var n: int = closes.size()
	if n == 0:
		return {}
	var c: Dictionary = s.market.candles_of(symbol)
	var opens: PackedFloat32Array = c.get("open", PackedFloat32Array())
	var highs: PackedFloat32Array = c.get("high", PackedFloat32Array())
	var lows: PackedFloat32Array = c.get("low", PackedFloat32Array())
	var real: bool = opens.size() == n and highs.size() == n and lows.size() == n
	if not real:
		opens = closes
		highs = closes
		lows = closes
	opens = opens.duplicate()
	highs = highs.duplicate()
	lows = lows.duplicate()
	var closes_shown: PackedFloat32Array = closes.duplicate()
	if grow < 1.0 and n >= 2:
		var g: PackedFloat32Array
		if real:
			g = ChartMath.grown(opens[n - 1], highs[n - 1], lows[n - 1], closes[n - 1], grow)
		else:
			var from_close: float = closes[n - 2]
			var to_close: float = from_close + (closes[n - 1] - from_close) * grow
			g = PackedFloat32Array([from_close, maxf(from_close, to_close), minf(from_close, to_close), to_close])
		opens[n - 1] = g[0]
		highs[n - 1] = g[1]
		lows[n - 1] = g[2]
		closes_shown[n - 1] = g[3]
	return {"open": opens, "high": highs, "low": lows, "close": closes_shown, "real": real}


func _on_canvas_draw() -> void:
	var s: GameSession = GameManager.session
	var font: Font = get_theme_default_font()
	var fs: int = 13
	if s == null or symbol == "":
		return
	var bars: Dictionary = _bars(s)
	var n: int = 0 if bars.is_empty() else (bars["close"] as PackedFloat32Array).size()
	var w: float = _canvas.size.x
	var h: float = _canvas.size.y
	if n < 2:
		_canvas.draw_string(font, Vector2(16, h * 0.5), tr("UI_GAME_NO_HISTORY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GameColors.MUTED)
		return
	var opens: PackedFloat32Array = bars["open"]
	var highs: PackedFloat32Array = bars["high"]
	var lows: PackedFloat32Array = bars["low"]
	var closes: PackedFloat32Array = bars["close"]
	var candles_on: bool = mode == Mode.CANDLES and bool(bars["real"])
	var lookback: int = s.market.lookback_of(symbol)

	# Price range: every bar plus the avg-cost / trigger lines when they are near the price action.
	var span: Vector2 = ChartMath.range_of(bars, 0, n - 1) if candles_on else _close_range(closes)
	var lo: float = span.x
	var hi: float = span.y
	var avg_cost: float = 0.0
	var position: Dictionary = s.portfolio.positions.get(symbol, {})
	if not position.is_empty() and int(position.get("shares", 0)) != 0:
		avg_cost = float(position.get("avg_cost", 0.0))
	var triggers: Array[Order] = []
	for o in s.book.pending():
		if o.symbol == symbol:
			triggers.append(o)
	var near_lo: float = lo - (hi - lo) * 0.6
	var near_hi: float = hi + (hi - lo) * 0.6
	var extras: Array[float] = []
	if avg_cost > 0.0:
		extras.append(avg_cost)
	for o in triggers:
		extras.append(o.trigger_price)
	for e in extras:
		if e >= near_lo and e <= near_hi:
			lo = minf(lo, e)
			hi = maxf(hi, e)
	var padded: Vector2 = ChartMath.padded(lo, hi)
	if grow < 1.0 and _has_range:
		padded = _range_from.lerp(padded, grow)
	lo = padded.x
	hi = padded.y
	_range_shown = padded
	_has_range = true

	var margin_left: float = clampf(font.get_string_size(GameFmt.price(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0, 52.0, 96.0)
	_plot = Rect2(margin_left, MARGIN_TOP, maxf(w - margin_left - MARGIN_RIGHT, 10.0), maxf(h - MARGIN_TOP - MARGIN_BOTTOM, 10.0))

	# Grid and price axis.
	for tick in ChartMath.nice_ticks(lo, hi, 5):
		var y: float = ChartMath.y_of(tick, lo, hi, _plot.position.y, _plot.size.y)
		_canvas.draw_line(Vector2(_plot.position.x, y), Vector2(_plot.end.x, y), GameColors.GRID, 1.0)
		_canvas.draw_string(font, Vector2(4, y + 5), GameFmt.price(tick), HORIZONTAL_ALIGNMENT_LEFT, margin_left - 8, fs, GameColors.MUTED)

	# Pre-game history is dimmed, with a divider where the run starts.
	if lookback > 0 and lookback < n:
		var dx: float = _plot.position.x + _plot.size.x * float(lookback) / float(n)
		_canvas.draw_rect(Rect2(_plot.position.x, _plot.position.y, dx - _plot.position.x, _plot.size.y), Color(0, 0, 0, 0.045))
		_dotted_vertical(dx)
		var tag: String = tr("UI_GAME_TODAY")
		_canvas.draw_string(font, Vector2(dx + 4, _plot.end.y - 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameColors.MUTED)

	var last_color: Color
	var shown: int = n if reveal >= 1.0 else clampi(ceili(float(n) * reveal), 0, n)
	if candles_on:
		var bw: float = ChartMath.body_width(n, _plot.size.x)
		for i in shown:
			var x: float = ChartMath.x_of(i, n, _plot.position.x, _plot.size.x)
			var up: bool = closes[i] >= opens[i]
			var col: Color = GameColors.UP if up else GameColors.DOWN
			if i < lookback:
				col.a = DIM
			var y_hi: float = ChartMath.y_of(highs[i], lo, hi, _plot.position.y, _plot.size.y)
			var y_lo: float = ChartMath.y_of(lows[i], lo, hi, _plot.position.y, _plot.size.y)
			var y_o: float = ChartMath.y_of(opens[i], lo, hi, _plot.position.y, _plot.size.y)
			var y_c: float = ChartMath.y_of(closes[i], lo, hi, _plot.position.y, _plot.size.y)
			_canvas.draw_line(Vector2(x, y_hi), Vector2(x, y_lo), col, maxf(1.0, minf(bw * 0.25, 2.0)))
			var body := Rect2(x - bw * 0.5, minf(y_o, y_c), bw, maxf(absf(y_o - y_c), 2.0))
			_canvas.draw_rect(body, col)
			if bw >= 4.0:
				_canvas.draw_rect(body, Color(0, 0, 0, 0.35 * col.a), false, 1.0)
		last_color = GameColors.UP if closes[n - 1] >= opens[n - 1] else GameColors.DOWN
	else:
		var points := PackedVector2Array()
		for i in maxi(shown, 2):
			points.append(Vector2(ChartMath.x_of(i, n, _plot.position.x, _plot.size.x), ChartMath.y_of(closes[i], lo, hi, _plot.position.y, _plot.size.y)))
		last_color = GameColors.for_change(s.market.day_change(symbol))
		if last_color == GameColors.FLAT:
			last_color = GameColors.UP
		var area := PackedVector2Array(points)
		area.append(Vector2(points[points.size() - 1].x, _plot.end.y))
		area.append(Vector2(points[0].x, _plot.end.y))
		if not Geometry2D.triangulate_polygon(area).is_empty():
			_canvas.draw_colored_polygon(area, Color(last_color.r, last_color.g, last_color.b, 0.12))
		_canvas.draw_polyline(points, last_color, 2.5, true)
		_canvas.draw_circle(points[points.size() - 1], 4.5, last_color)

	# Last-price line and tag in the right margin (not while the opening is still drawing the bars).
	if shown < n:
		return
	var y_last: float = ChartMath.y_of(closes[n - 1], lo, hi, _plot.position.y, _plot.size.y)
	_dotted_horizontal(y_last, last_color)
	var tag_text: String = GameFmt.price(closes[n - 1])
	var tag_size := Vector2(font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0, 20.0)
	var tag_pos := Vector2(_plot.end.x + 4.0, clampf(y_last - 10.0, 0.0, h - MARGIN_BOTTOM - 20.0))
	_canvas.draw_style_box(_pill(last_color, 4), Rect2(tag_pos, tag_size))
	_canvas.draw_string(font, tag_pos + Vector2(5, 15), tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# X axis: dates (or day numbers when the run has no calendar).
	for i in ChartMath.label_indices(n, 5):
		var label: String = _x_label(s, i, lookback)
		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lx: float = clampf(ChartMath.x_of(i, n, _plot.position.x, _plot.size.x) - lw * 0.5, _plot.position.x - 4.0, _plot.end.x - lw + 4.0)
		_canvas.draw_string(font, Vector2(lx, h - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameColors.MUTED)

	if avg_cost >= lo and avg_cost <= hi and avg_cost > 0.0:
		_dashed(avg_cost, lo, hi, GameColors.GOLD, tr("UI_GAME_AVG_COST_SHORT") + " " + GameFmt.price(avg_cost), font, fs)
	for o in triggers:
		if o.trigger_price >= lo and o.trigger_price <= hi:
			var kind_text: String = tr("UI_GAME_KIND_LIMIT") if o.kind == Order.Kind.LIMIT else tr("UI_GAME_KIND_STOP")
			var side_text: String = tr("UI_GAME_BUY") if o.side == Order.Dir.BUY else tr("UI_GAME_SELL")
			_dashed(o.trigger_price, lo, hi, Color("#2f7fd6"), "%s %s %s" % [side_text, kind_text, GameFmt.price(o.trigger_price)], font, fs)

	if _hover_index >= 0 and _hover_index < n:
		_draw_hover(s, bars, lo, hi, lookback, candles_on, font, fs)


func _close_range(closes: PackedFloat32Array) -> Vector2:
	var lo: float = closes[0]
	var hi: float = closes[0]
	for p in closes:
		lo = minf(lo, p)
		hi = maxf(hi, p)
	return Vector2(lo, hi)


func _x_label(s: GameSession, index: int, lookback: int) -> String:
	var day_no: int = index - lookback
	var date: String = ChartMath.short_date(s.date_of_day(day_no))
	if date != "":
		return date
	return "%s %d" % [tr("UI_GAME_DAY"), day_no]


func _pill(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb


func _draw_hover(s: GameSession, bars: Dictionary, lo: float, hi: float, lookback: int, candles_on: bool, font: Font, fs: int) -> void:
	var opens: PackedFloat32Array = bars["open"]
	var highs: PackedFloat32Array = bars["high"]
	var lows: PackedFloat32Array = bars["low"]
	var closes: PackedFloat32Array = bars["close"]
	var n: int = closes.size()
	var i: int = _hover_index
	var x: float = ChartMath.x_of(i, n, _plot.position.x, _plot.size.x)
	var slot: float = _plot.size.x / float(n)
	if candles_on:
		_canvas.draw_rect(Rect2(x - slot * 0.5, _plot.position.y, slot, _plot.size.y), Color(0, 0, 0, 0.07))
	else:
		var py: float = ChartMath.y_of(closes[i], lo, hi, _plot.position.y, _plot.size.y)
		_canvas.draw_line(Vector2(x, _plot.position.y), Vector2(x, _plot.end.y), GameColors.CROSSHAIR, 1.0)
		_canvas.draw_circle(Vector2(x, py), 4.5, Color.WHITE)
		_canvas.draw_arc(Vector2(x, py), 4.5, 0, TAU, 16, GameColors.CROSSHAIR, 1.5)
	var day_no: int = i - lookback
	var date: String = ChartMath.long_date(s.date_of_day(day_no))
	var head: String = date if date != "" else "%s %d" % [tr("UI_GAME_DAY"), day_no]
	if day_no < 0:
		head += "  ·  " + tr("UI_GAME_PREGAME")
	elif date != "":
		head += "  ·  %s %d" % [tr("UI_GAME_DAY"), day_no]
	var line2: String
	if candles_on:
		line2 = tr("UI_GAME_OHLC") % [GameFmt.price(opens[i]), GameFmt.price(highs[i]), GameFmt.price(lows[i]), GameFmt.price(closes[i])]
	else:
		line2 = GameFmt.price(closes[i])
	var tw: float = maxf(font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + 18.0
	var box := _tooltip_box(x, tw, bars, lo, hi)
	var sb := _pill(Color(0.1, 0.09, 0.14, 0.92), 6)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.25)
	_canvas.draw_style_box(sb, box)
	_canvas.draw_string(font, box.position + Vector2(9, 17), head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.7))
	var close_up: bool = closes[i] >= opens[i]
	_canvas.draw_string(font, box.position + Vector2(9, 36), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#7ee08a") if close_up else Color("#ff8a80"))


## The tooltip sits on the half of the plot opposite the pointer (the newest candles are on the right, so a
## pointer on the right never has the box on top of them), and at the top or bottom edge, whichever hides fewer
## candles.
func _tooltip_box(x: float, tw: float, bars: Dictionary, lo: float, hi: float) -> Rect2:
	var h: float = 44.0
	var left_side: bool = x > _plot.position.x + _plot.size.x * 0.5
	var bx: float = _plot.position.x + 8.0 if left_side else _plot.end.x - tw - 8.0
	var top := Rect2(bx, _plot.position.y + 4.0, tw, h)
	var bottom := Rect2(bx, _plot.end.y - h - 4.0, tw, h)
	var highs: PackedFloat32Array = bars["high"]
	var lows: PackedFloat32Array = bars["low"]
	var n: int = highs.size()
	var hits_top: int = 0
	var hits_bottom: int = 0
	for j in n:
		var cx: float = ChartMath.x_of(j, n, _plot.position.x, _plot.size.x)
		if cx < top.position.x or cx > top.end.x:
			continue
		var y_high: float = ChartMath.y_of(highs[j], lo, hi, _plot.position.y, _plot.size.y)
		var y_low: float = ChartMath.y_of(lows[j], lo, hi, _plot.position.y, _plot.size.y)
		if y_high < top.end.y and y_low > top.position.y:
			hits_top += 1
		if y_high < bottom.end.y and y_low > bottom.position.y:
			hits_bottom += 1
	return top if hits_top <= hits_bottom else bottom


func _dotted_vertical(x: float) -> void:
	var y: float = _plot.position.y
	while y < _plot.end.y:
		_canvas.draw_line(Vector2(x, y), Vector2(x, minf(y + 3.0, _plot.end.y)), GameColors.MUTED, 1.0)
		y += 7.0


func _dotted_horizontal(y: float, color: Color) -> void:
	var x: float = _plot.position.x
	var c := Color(color.r, color.g, color.b, 0.6)
	while x < _plot.end.x:
		_canvas.draw_line(Vector2(x, y), Vector2(minf(x + 3.0, _plot.end.x), y), c, 1.0)
		x += 7.0


func _dashed(value: float, lo: float, hi: float, color: Color, text: String, font: Font, fs: int) -> void:
	var y: float = ChartMath.y_of(value, lo, hi, _plot.position.y, _plot.size.y)
	var x: float = _plot.position.x
	while x < _plot.end.x:
		_canvas.draw_line(Vector2(x, y), Vector2(minf(x + 6.0, _plot.end.x), y), color, 1.5)
		x += 11.0
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0
	_canvas.draw_style_box(_pill(Color(1, 1, 1, 0.78), 4), Rect2(_plot.position.x + 4, y - 20, tw, 18))
	_canvas.draw_string(font, Vector2(_plot.position.x + 9, y - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var s: GameSession = GameManager.session
		if s == null or symbol == "":
			return
		var n: int = s.market.history_of(symbol).size()
		if n < 2 or _plot.size.x <= 0.0:
			return
		_hover_index = ChartMath.index_at((event as InputEventMouseMotion).position.x, n, _plot.position.x, _plot.size.x)
		_canvas.queue_redraw()


func _on_canvas_mouse_exited() -> void:
	_hover_index = -1
	_canvas.queue_redraw()


func _on_prices_updated() -> void:
	_refresh()


func _on_portfolio_changed() -> void:
	_refresh()


func _on_order_changed(_order: Order) -> void:
	_refresh()


func _on_order_cancelled(_order_id: int) -> void:
	_refresh()
