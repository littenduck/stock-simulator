## Holdings table (long and short), account summary and margin health. Click a row to select the stock.
class_name GamePortfolioView
extends PanelContainer

signal stock_selected(symbol: String)

var _summary: GridContainer
var _values: Dictionary = {}     ## key -> Label
var _cells: Dictionary = {}      ## key -> summary cell
var _margin: Label
var _tree: Tree
var _empty: Label


@export var show_title: bool = true


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	if show_title:
		box.add_child(GameFmt.label(tr("UI_GAME_PORTFOLIO"), GameColors.MUTED, 14))

	_summary = GridContainer.new()
	_summary.columns = 4
	_summary.add_theme_constant_override("h_separation", 18)
	box.add_child(_summary)
	for key in ["cash", "long", "short", "worth"]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(GameFmt.label(tr("UI_GAME_SUM_" + key.to_upper()), GameColors.MUTED, 12))
		var v := GameFmt.label("", Color.WHITE, 16)
		cell.add_child(v)
		_summary.add_child(cell)
		_values[key] = v
		_cells[key] = cell
	_margin = GameFmt.label("", GameColors.MUTED, 13)
	box.add_child(_margin)

	_tree = Tree.new()
	_tree.name = "HoldingsTree"
	_tree.columns = 5
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.focus_mode = Control.FOCUS_NONE
	var titles: Array[String] = ["UI_GAME_COL_SYMBOL", "UI_GAME_COL_SHARES", "UI_GAME_COL_AVG", "UI_GAME_COL_PRICE", "UI_GAME_COL_PNL"]
	for i in titles.size():
		_tree.set_column_title(i, tr(titles[i]))
		_tree.set_column_expand(i, true)
		if i > 0:
			_tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in titles.size():
		_tree.set_column_expand_ratio(i, 3 if i == 4 else 3 if i == 0 else 2)
		_tree.set_column_custom_minimum_width(i, 64 if i == 4 else 82 if i == 0 else 34 if i == 1 else 54)
	_tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tree.add_theme_constant_override("icon_max_width", PixelIcons.BADGE_SIZE)
	_tree.item_selected.connect(_on_item_selected)
	box.add_child(_tree)
	_empty = GameFmt.label(tr("UI_GAME_NO_POSITIONS"), GameColors.MUTED, 14)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_empty)

	EventBus.prices_updated.connect(_on_prices_updated)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	EventBus.perks_changed.connect(_on_prices_updated)
	_refresh()


func _refresh() -> void:
	var s: GameSession = GameManager.session
	if s == null or not is_node_ready():
		return
	var p: Portfolio = s.portfolio
	(_values["cash"] as Label).text = GameFmt.money(p.cash)
	GameFmt.tint(_values["cash"] as Label, GameColors.DOWN if p.cash < 0.0 else Color.WHITE)
	(_values["long"] as Label).text = GameFmt.money(p.long_value(s.market))
	(_values["short"] as Label).text = GameFmt.money(p.short_value(s.market))
	var equity: float = p.net_worth(s.market)
	(_values["worth"] as Label).text = GameFmt.money(equity)

	var show_margin: bool = GameFmt.margin_on(s.mods)
	(_cells["short"] as Control).visible = show_margin or p.short_value(s.market) > 0.0
	_margin.visible = show_margin
	var gross: float = p.gross_exposure(s.market)
	if gross > 0.0:
		var ratio: float = equity / gross
		var floor_ratio: float = s.mods.maintenance_margin
		_margin.text = tr("UI_GAME_MARGIN_STATUS") % [ratio * 100.0, floor_ratio * 100.0, gross / maxf(equity, 0.01)]
		var danger: bool = ratio < floor_ratio * 1.25
		_margin.add_theme_color_override("font_color", GameColors.DOWN if danger else GameColors.MUTED)
	else:
		_margin.text = tr("UI_GAME_MARGIN_NONE")
		_margin.add_theme_color_override("font_color", GameColors.MUTED)

	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var count: int = 0
	for symbol in s.market.symbols():
		var shares: int = p.shares_of(symbol)
		if shares == 0:
			continue
		count += 1
		var avg: float = float(p.positions[symbol].get("avg_cost", 0.0))
		var price: float = s.market.price_of(symbol)
		# Long gains when price rises; a short gains when it falls.
		var pnl_pct: float = (price - avg) / avg * signf(float(shares)) if avg > 0.0 else 0.0
		var pnl_cash: float = (price - avg) * shares
		var item: TreeItem = _tree.create_item(root)
		item.set_metadata(0, symbol)
		item.set_text(0, symbol)
		var held_company: CompanyDef = s.market.company_of(symbol)
		item.set_icon(0, PixelIcons.badge_texture(held_company.icon if held_company != null else "", held_company.sector if held_company != null else ""))
		item.set_text(1, str(shares))
		item.set_text(2, GameFmt.price(avg))
		item.set_text(3, GameFmt.price(price))
		item.set_text(4, GameColors.pct_value(pnl_pct))
		item.set_icon(4, GameIcons.tex(GameColors.icon_name(pnl_pct)))
		item.set_icon_max_width(4, 12)
		item.set_icon_modulate(4, GameColors.for_change(pnl_pct))
		item.set_custom_color(4, GameColors.for_change(pnl_pct))
		item.set_tooltip_text(4, GameFmt.signed_money(pnl_cash))
		item.set_tooltip_text(1, tr("UI_GAME_SHORT_TAG") if shares < 0 else "")
		if shares < 0:
			item.set_custom_color(1, GameColors.WARN)
		for c in range(1, 5):
			item.set_text_alignment(c, HORIZONTAL_ALIGNMENT_RIGHT)
	_tree.visible = count > 0
	_empty.visible = count == 0


func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item != null:
		stock_selected.emit(String(item.get_metadata(0)))


func _on_prices_updated() -> void:
	_refresh()


func _on_portfolio_changed() -> void:
	_refresh()
