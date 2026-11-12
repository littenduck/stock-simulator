## Line chart of one stock plus a header. Draws average cost and pending-order trigger lines.
## Read-only: reads GameManager.session and redraws on EventBus.prices_updated.
class_name GamePriceChart
extends VBoxContainer

const MARGIN_LEFT := 62.0
const MARGIN_RIGHT := 14.0
const MARGIN_TOP := 10.0
const MARGIN_BOTTOM := 24.0

var symbol: String = "":
	set(value):
		symbol = value
		_hover_index = -1
		_refresh()

var _title: Label
var _company: Label
var _price: Label
var _change: Label
var _range: Label
var _canvas: Control
var _hover_index: int = -1
var _plot := Rect2()
var _lo: float = 0.0
var _hi: float = 1.0


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	add_child(head)
	_title = GameFmt.label("", Color.WHITE, 28)
	_company = GameFmt.label("", GameColors.MUTED, 16)
	_company.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_company.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price = GameFmt.label("", Color.WHITE, 28)
	_change = GameFmt.label("", Color.WHITE, 18)
	_change.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_range = GameFmt.label("", GameColors.MUTED, 13)
	_range.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for n: Control in [_title, _company, _range, _price, _change]:
		head.add_child(n)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(frame)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.custom_minimum_size = Vector2(200, 140)
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


func _refresh() -> void:
	if not is_node_ready():
		return
	var s: GameSession = GameManager.session
	if s != null and symbol != "":
		var company: CompanyDef = s.market.company_of(symbol)
		var change: float = s.market.day_change(symbol)
		_title.text = symbol
		_company.text = "%s · %s" % [tr(company.display_name), company.sector.capitalize()] if company != null else ""
		_price.text = GameFmt.price(s.market.price_of(symbol))
		_change.text = GameColors.pct_text(change)
		_change.add_theme_color_override("font_color", GameColors.for_change(change))
		var h: PackedFloat32Array = s.market.history_of(symbol)
		if h.size() > 0:
			_range.text = tr("UI_GAME_HIGH_LOW") % [_max_of(h), _min_of(h)]
	_canvas.queue_redraw()


func _max_of(h: PackedFloat32Array) -> float:
	var m: float = h[0]
	for p in h:
		m = maxf(m, p)
	return m


func _min_of(h: PackedFloat32Array) -> float:
	var m: float = h[0]
	for p in h:
		m = minf(m, p)
	return m


func _on_canvas_draw() -> void:
	var s: GameSession = GameManager.session
	var font: Font = get_theme_default_font()
	var fs: int = 13
	if s == null or symbol == "":
		return
	var history: PackedFloat32Array = s.market.history_of(symbol)
	var n: int = history.size()
	var w: float = _canvas.size.x
	var h: float = _canvas.size.y
	_plot = Rect2(MARGIN_LEFT, MARGIN_TOP, maxf(w - MARGIN_LEFT - MARGIN_RIGHT, 10.0), maxf(h - MARGIN_TOP - MARGIN_BOTTOM, 10.0))
	if n < 2:
		_canvas.draw_string(font, Vector2(MARGIN_LEFT, h * 0.5), tr("UI_GAME_NO_HISTORY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GameColors.MUTED)
		return

	var lo: float = _min_of(history)
	var hi: float = _max_of(history)
	var avg_cost: float = 0.0
	var position: Dictionary = s.portfolio.positions.get(symbol, {})
	if not position.is_empty() and int(position.get("shares", 0)) != 0:
		avg_cost = float(position.get("avg_cost", 0.0))
	var triggers: Array[Order] = []
	for o in s.book.pending():
		if o.symbol == symbol:
			triggers.append(o)
	# Keep avg cost and triggers inside the visible range only when they are near the price action.
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
	var pad: float = maxf((hi - lo) * 0.08, hi * 0.002)
	lo -= pad
	hi += pad
	_lo = lo
	_hi = hi

	var grid_color := Color(1, 1, 1, 0.08)
	for i in 5:
		var t: float = i / 4.0
		var y: float = _plot.position.y + _plot.size.y * t
		_canvas.draw_line(Vector2(_plot.position.x, y), Vector2(_plot.end.x, y), grid_color, 1.0)
		var value: float = hi - (hi - lo) * t
		_canvas.draw_string(font, Vector2(4, y + 5), GameFmt.price(value), HORIZONTAL_ALIGNMENT_LEFT, MARGIN_LEFT - 8, fs, GameColors.MUTED)

	var points := PackedVector2Array()
	for i in n:
		points.append(_point(i, n, history[i]))
	var up: bool = history[n - 1] >= history[0]
	var color: Color = GameColors.UP if up else GameColors.DOWN
	var area := PackedVector2Array(points)
	area.append(Vector2(points[n - 1].x, _plot.end.y))
	area.append(Vector2(points[0].x, _plot.end.y))
	var fill := Color(color.r, color.g, color.b, 0.10)
	if not Geometry2D.triangulate_polygon(area).is_empty():
		_canvas.draw_colored_polygon(area, fill)
	_canvas.draw_polyline(points, color, 2.5, true)
	_canvas.draw_circle(points[n - 1], 4.5, color)

	var first_day: int = maxi(s.day - (n - 1), 0)
	_canvas.draw_string(font, Vector2(_plot.position.x, h - 6), "%s %d" % [tr("UI_GAME_DAY"), first_day], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameColors.MUTED)
	_canvas.draw_string(font, Vector2(_plot.end.x - 80, h - 6), "%s %d" % [tr("UI_GAME_DAY"), s.day], HORIZONTAL_ALIGNMENT_RIGHT, 80, fs, GameColors.MUTED)

	if avg_cost >= lo and avg_cost <= hi and avg_cost > 0.0:
		_dashed(avg_cost, GameColors.GOLD, tr("UI_GAME_AVG_COST_SHORT") + " " + GameFmt.price(avg_cost), font, fs)
	for o in triggers:
		if o.trigger_price >= lo and o.trigger_price <= hi:
			var kind_text: String = tr("UI_GAME_KIND_LIMIT") if o.kind == Order.Kind.LIMIT else tr("UI_GAME_KIND_STOP")
			var side_text: String = tr("UI_GAME_BUY") if o.side == Order.Dir.BUY else tr("UI_GAME_SELL")
			_dashed(o.trigger_price, Color("#58a6ff"), "%s %s %s" % [side_text, kind_text, GameFmt.price(o.trigger_price)], font, fs)

	if _hover_index >= 0 and _hover_index < n:
		var hp: Vector2 = points[_hover_index]
		_canvas.draw_line(Vector2(hp.x, _plot.position.y), Vector2(hp.x, _plot.end.y), Color(1, 1, 1, 0.35), 1.0)
		_canvas.draw_circle(hp, 4.0, Color.WHITE)
		var day_no: int = first_day + _hover_index
		var text: String = "%s %d  %s" % [tr("UI_GAME_DAY"), day_no, GameFmt.price(history[_hover_index])]
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		var tx: float = clampf(hp.x - tw * 0.5, _plot.position.x, _plot.end.x - tw)
		_canvas.draw_rect(Rect2(tx, _plot.position.y, tw, 22), Color(0, 0, 0, 0.75))
		_canvas.draw_string(font, Vector2(tx + 6, _plot.position.y + 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _point(i: int, n: int, value: float) -> Vector2:
	var x: float = _plot.position.x + _plot.size.x * i / float(n - 1)
	var y: float = _plot.position.y + _plot.size.y * (1.0 - (value - _lo) / maxf(_hi - _lo, 0.0001))
	return Vector2(x, y)


func _dashed(value: float, color: Color, text: String, font: Font, fs: int) -> void:
	var y: float = _plot.position.y + _plot.size.y * (1.0 - (value - _lo) / maxf(_hi - _lo, 0.0001))
	var x: float = _plot.position.x
	while x < _plot.end.x:
		_canvas.draw_line(Vector2(x, y), Vector2(minf(x + 6.0, _plot.end.x), y), color, 1.5)
		x += 11.0
	_canvas.draw_string(font, Vector2(_plot.position.x + 6, y - 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var s: GameSession = GameManager.session
		if s == null or symbol == "":
			return
		var n: int = s.market.history_of(symbol).size()
		if n < 2 or _plot.size.x <= 0.0:
			return
		var t: float = ((event as InputEventMouseMotion).position.x - _plot.position.x) / _plot.size.x
		_hover_index = clampi(roundi(t * (n - 1)), 0, n - 1)
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
