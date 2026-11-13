## Two pop-ups of a table day. After the reveal button: everybody's bets side by side (Double Dan can double here).
## After the day resolves: verdicts with a stamp, your payout, firings and the new Boss rumor.
class_name TableOverlay
extends Control

enum Mode { NONE, REVEAL, RESULT }

var _mode: Mode = Mode.NONE
var _panel: PanelContainer
var _body: VBoxContainer
var _dim: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"DialogPanel"
	_panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(_panel)
	_body = TableUi.column(_panel, 8)
	hide()
	EventBus.table_revealed.connect(_on_revealed)
	EventBus.table_resolved.connect(_on_resolved)
	EventBus.table_changed.connect(_refresh_reveal)


## In the result pop-up Space only closes it, so the verdicts can be read before the next day starts.
func _input(event: InputEvent) -> void:
	if _mode == Mode.RESULT and visible and (event.is_action_pressed("next_day") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	_mode = Mode.NONE
	hide()


func _on_revealed(_entries: Array) -> void:
	_mode = Mode.REVEAL
	_refresh_reveal()
	show()
	if is_inside_tree():
		UiFx.bounce_in(_panel, 0.0)


func _refresh_reveal() -> void:
	if _mode != Mode.REVEAL:
		return
	var t := TableUi.session()
	if t == null:
		return
	_clear()
	_body.add_child(GameFmt.label(tr("TABLE_REVEAL_TITLE"), Color.WHITE, 22))
	_body.add_child(TableUi.wrapped(t.today_rumor.headline(tr, t.market), GameColors.MUTED, 15))
	for entry in t.last_reveal:
		_body.add_child(_reveal_row(t, entry))
	if t.can_double(0):
		var dbl := GameFmt.button(tr("TABLE_DOUBLE"))
		dbl.custom_minimum_size = Vector2(0, 44)
		dbl.pressed.connect(func() -> void:
			t.double_down(0)
			GameManager.table_refresh())
		_body.add_child(dbl)
	var go := GameFmt.button(tr("TABLE_BTN_CONTINUE") + "  [Space]")
	go.custom_minimum_size = Vector2(0, 44)
	go.pressed.connect(GameManager.next_day)
	_body.add_child(go)


func _reveal_row(t: TableSession, entry: Dictionary) -> Control:
	var seat := t.seats[int(entry["seat"])]
	var side := int(entry["side"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := GameFmt.label(TableUi.seat_name(seat, self) + (" (" + tr("TABLE_BOSS_TAG") + ")" if bool(entry["boss"]) else ""), GameColors.GOLD if seat.is_human else Color.WHITE, 16)
	name_label.custom_minimum_size = Vector2(200, 0)
	row.add_child(name_label)
	var call_label := GameFmt.label(tr(TableUi.side_key(side)), TableUi.side_color(side), 16)
	call_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(call_label)
	var detail := ""
	if side != RumorTier.Side.PASS:
		detail = "%s   x%.2f" % [GameFmt.money(float(entry["premium"]), 0), float(entry["odds"])]
		var bet := t.daily_bet_of(seat.id) if not bool(entry["boss"]) else t.boss_bet_of(seat.id)
		if int(entry["copied_from"]) >= 0:
			detail += "   " + tr("TABLE_COPIED") % TableUi.seat_name(t.seats[int(entry["copied_from"])], self)
		if bet != null and bet.doubled:
			detail += "   " + tr("TABLE_DOUBLED")
	row.add_child(GameFmt.label(detail, Color.WHITE, 15))
	return row


func _on_resolved(report: TableReport) -> void:
	var t := TableUi.session()
	if t == null:
		return
	_mode = Mode.RESULT
	_clear()
	_body.add_child(GameFmt.label(tr("TABLE_RESULT_TITLE") % report.day, Color.WHITE, 22))
	for rumor in report.resolved_table:
		_body.add_child(_verdict(t, rumor, report))
	for fired_id in report.fired_seats:
		var seat := t.seats[fired_id]
		var text := tr("TABLE_YOU_FIRED") if seat.is_human else tr("TABLE_FIRED_NOTE") % TableUi.seat_name(seat, self)
		_body.add_child(TableUi.wrapped(text, GameColors.DOWN, 16))
	if report.quarter_ended > 0 and not report.finished:
		_body.add_child(TableUi.wrapped(tr("TABLE_QUARTER_END") % report.quarter_ended, GameColors.GOLD, 15))
	if report.boss_announced != null:
		_body.add_child(TableUi.wrapped(tr("TABLE_BOSS_NEW") + "\n" + report.boss_announced.headline(tr, t.market), GameColors.GOLD, 15))
	var ok := GameFmt.button(tr("TABLE_OK") + "  [Space]")
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(_close)
	_body.add_child(ok)
	show()
	if is_inside_tree():
		UiFx.bounce_in(_panel, 0.0)


func _verdict(t: TableSession, rumor: TableRumor, report: TableReport) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var stamp := tr("TABLE_CONFIRMED") if rumor.came_true else tr("TABLE_DEBUNKED")
	if rumor.planted:
		stamp += "  ·  " + tr("TABLE_PLANTED")
	box.add_child(GameFmt.label(stamp, GameColors.UP if rumor.came_true else GameColors.DOWN, 20))
	box.add_child(TableUi.wrapped(rumor.headline(tr, t.market), Color.WHITE, 15))
	box.add_child(GameFmt.label(tr("TABLE_MOVE") % ("%+.2f%%" % (rumor.move(t.market) * 100.0)), GameColors.MUTED, 13))
	var mine := ""
	var mine_color := GameColors.MUTED
	for p in report.payouts:
		if int(p["seat"]) == 0 and int(p["rumor"]) == rumor.id:
			var net := float(p["payout"]) - float(p["premium"])
			mine = (tr("TABLE_YOU_WON") if net > 0.0 else tr("TABLE_YOU_LOST")) % GameFmt.money(absf(net), 0)
			mine_color = GameColors.UP if net > 0.0 else GameColors.DOWN
	if mine == "":
		mine = tr("TABLE_NO_BET")
	box.add_child(GameFmt.label(mine, mine_color, 16))
	return box


func _clear() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
