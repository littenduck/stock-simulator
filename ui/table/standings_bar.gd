## The four seats side by side: rank, character, net worth, streak. Fired seats are greyed out.
class_name StandingsBar
extends PanelContainer

var _row: HBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0)
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
	var first := true
	for entry in t.standings():
		if not first:
			_row.add_child(VSeparator.new())
		first = false
		_row.add_child(_chip(entry["seat"] as Seat, int(entry["rank"]), float(entry["net_worth"])))


func _chip(seat: Seat, rank: int, net_worth: float) -> Control:
	var row := _SeatChip.new()
	row.seat = seat
	row.tooltip_text = String(seat.character.id)    # any text turns the tooltip on; _SeatChip draws its own
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var portrait := PortraitView.make(String(seat.character.id), 1.9)
	if not seat.alive:
		portrait.modulate = Color(1, 1, 1, 0.4)
	row.add_child(portrait)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
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
	return row


## One player of the bar. Hover it for the character: portrait, name and both skills with their windows of the day.
class _SeatChip extends HBoxContainer:
	var seat: Seat

	func _make_custom_tooltip(_for_text: String) -> Object:
		if seat == null or seat.character == null:
			return null
		var key := String(seat.character.id).to_upper()
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"DialogPanel"
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 6)
		panel.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		margin.add_child(row)
		row.add_child(PortraitView.make(String(seat.character.id), 6))
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(380, 0)
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		col.add_child(GameFmt.label(TableUi.seat_name(seat, self), Color("#2b2540"), 22))
		col.add_child(_wrapped(tr(seat.character.description_key), Color("#5d5870"), 14))
		for part in [["TABLE_PASSIVE", "CHAR_%s_PASSIVE"], ["TABLE_ACTIVE", "CHAR_%s_ACTIVE"]]:
			col.add_child(GameFmt.label(tr(part[0]).to_upper(), Color("#c77d0a"), 13))
			col.add_child(_wrapped(tr(part[1] % key), Color("#2b2540"), 15))
		if seat.is_human and seat.skill_used:
			col.add_child(GameFmt.label(tr("TABLE_SKILL_SPENT"), GameColors.DOWN, 14))
		return panel

	## A wrapped line with a fixed width: a tooltip has no parent to give it one, so it would wrap at one letter.
	func _wrapped(text: String, color: Color, size: int) -> Label:
		var l := TableUi.wrapped(text, color, size)
		l.custom_minimum_size = Vector2(380, 0)
		return l
