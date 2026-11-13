## The four seats side by side: rank, character, net worth, streak. Fired seats are greyed out.
class_name StandingsBar
extends PanelContainer

var _row: HBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	margin.add_child(_row)
	EventBus.portfolio_changed.connect(_refresh)
	EventBus.prices_updated.connect(_refresh)
	EventBus.table_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _row == null:
		return
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for entry in t.standings():
		_row.add_child(_chip(entry["seat"] as Seat, int(entry["rank"]), float(entry["net_worth"])))


func _chip(seat: Seat, rank: int, net_worth: float) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := TableUi.column(panel, 0, 6)
	var name_color := GameColors.GOLD if seat.is_human else Color.WHITE
	if not seat.alive:
		name_color = GameColors.MUTED
	var title := "#%d  %s" % [rank, TableUi.seat_name(seat, self)]
	if seat.is_human:
		title += "  (" + tr("TABLE_YOU") + ")"
	box.add_child(GameFmt.label(title, name_color, 15))
	var detail := GameFmt.money(net_worth, 0)
	var detail_color := Color.WHITE
	if not seat.alive:
		detail = tr("TABLE_FIRED")
		detail_color = GameColors.DOWN
	elif seat.streak >= 2:
		detail += "   " + tr("TABLE_STREAK") % seat.streak
		detail_color = GameColors.GOLD
	box.add_child(GameFmt.label(detail, detail_color, 14))
	return panel
