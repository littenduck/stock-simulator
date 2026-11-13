## Two pop-ups of a table day. After the reveal button: everybody's bets, flipped over one by one (Double Dan can
## double here). After the day resolves: the verdict stamp slams down, the screen flashes, a win throws confetti.
class_name TableOverlay
extends Control

enum Mode { NONE, REVEAL, RESULT }

const ROW_STEP := 0.24
const STAMP_DELAY := 0.4
const STAMP_GAP := 1.35

var _mode: Mode = Mode.NONE
var _panel: PanelContainer
var _body: VBoxContainer
var _dim: ColorRect
var _play_intro: bool = false


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


# ---------------------------------------------------------------- reveal

func _on_revealed(_entries: Array) -> void:
	_mode = Mode.REVEAL
	_play_intro = true
	_refresh_reveal()
	show()
	TableFx.sfx(&"order_placed")
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
	var rows: Array[Control] = []
	for entry in t.last_reveal:
		var row := _reveal_row(t, entry)
		_body.add_child(row)
		rows.append(row)
	var extras: Array[Control] = []
	if t.can_double(0):
		var dbl := GameFmt.button(tr("TABLE_DOUBLE"))
		dbl.custom_minimum_size = Vector2(0, 44)
		dbl.pressed.connect(func() -> void:
			t.double_down(0)
			TableFx.sfx(&"stamp")
			GameManager.table_refresh())
		_body.add_child(dbl)
		extras.append(dbl)
	var go := GameFmt.button(tr("TABLE_BTN_CONTINUE") + "  [Space]")
	go.custom_minimum_size = Vector2(0, 44)
	go.pressed.connect(GameManager.next_day)
	_body.add_child(go)
	extras.append(go)
	if _play_intro:
		_play_intro = false
		_animate_reveal(rows, extras)


## The bets turn over one after another: each row fades in with a tick and its call pops big.
func _animate_reveal(rows: Array[Control], extras: Array[Control]) -> void:
	var at := 0.3
	for row in rows:
		row.modulate.a = 0.0
		var tw := row.create_tween()
		tw.tween_interval(at)
		tw.tween_callback(func() -> void: TableFx.sfx(&"reveal_tick"))
		tw.tween_property(row, "modulate:a", 1.0, 0.1)
		TableFx.pop(row.get_child(1) as Control, 2.2, at)
		at += ROW_STEP
	for e in extras:
		e.modulate.a = 0.0
		var tw2 := e.create_tween()
		tw2.tween_interval(at + 0.1)
		tw2.tween_property(e, "modulate:a", 1.0, 0.25)


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


# ---------------------------------------------------------------- result

func _on_resolved(report: TableReport) -> void:
	var t := TableUi.session()
	if t == null:
		return
	_mode = Mode.RESULT
	_clear()
	_body.add_child(GameFmt.label(tr("TABLE_RESULT_TITLE") % report.day, Color.WHITE, 22))
	var at := STAMP_DELAY
	for rumor in report.resolved_table:
		_body.add_child(_verdict(t, rumor, report, at))
		at += STAMP_GAP
	for fired_id in report.fired_seats:
		var seat := t.seats[fired_id]
		var text := tr("TABLE_YOU_FIRED") if seat.is_human else tr("TABLE_FIRED_NOTE") % TableUi.seat_name(seat, self)
		_body.add_child(TableUi.wrapped(text, GameColors.DOWN, 16))
	if report.quarter_ended > 0 and not report.finished:
		_body.add_child(TableUi.wrapped(tr("TABLE_QUARTER_END") % report.quarter_ended, GameColors.GOLD, 15))
	var extras: Array[Control] = []
	if report.boss_announced != null:
		var boss := TableUi.wrapped(tr("TABLE_BOSS_NEW") + "\n" + report.boss_announced.headline(tr, t.market), GameColors.GOLD, 15)
		_body.add_child(boss)
		extras.append(boss)
	var ok := GameFmt.button(tr("TABLE_OK") + "  [Space]")
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(_close)
	_body.add_child(ok)
	extras.append(ok)
	for e in extras:
		e.modulate.a = 0.0
		e.create_tween().tween_property(e, "modulate:a", 1.0, 0.3).set_delay(at)
	show()
	TableFx.sfx(&"order_placed")
	UiFx.bounce_in(_panel, 0.0)


func _verdict(t: TableSession, rumor: TableRumor, report: TableReport, delay: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var color := GameColors.UP if rumor.came_true else GameColors.DOWN
	var mine := _mine(report, rumor)
	var stamps := HBoxContainer.new()
	stamps.add_theme_constant_override("separation", 12)
	box.add_child(stamps)
	var stamp := TableFx.make_stamp(tr("TABLE_CONFIRMED") if rumor.came_true else tr("TABLE_DEBUNKED"), color, 32)
	stamps.add_child(stamp)
	TableFx.slam(stamp, delay, _impact.bind(color, 0.32, rumor.is_boss(), mine))
	if rumor.planted:
		var planted := TableFx.make_stamp(tr("TABLE_PLANTED"), TableFx.PLANTED_COLOR, 24)
		stamps.add_child(planted)
		TableFx.slam(planted, delay + 0.55, _impact.bind(TableFx.PLANTED_COLOR, 0.18, false, {}))
	var headline := TableUi.wrapped(rumor.headline(tr, t.market), Color.WHITE, 15)
	headline.modulate.a = 0.0
	headline.create_tween().tween_property(headline, "modulate:a", 1.0, 0.3)
	box.add_child(headline)
	box.add_child(GameFmt.label(tr("TABLE_MOVE") % ("%+.2f%%" % (rumor.move(t.market) * 100.0)), GameColors.MUTED, 13))
	var result := GameFmt.label("", GameColors.MUTED, 18)
	box.add_child(result)
	if mine.is_empty():
		result.text = tr("TABLE_NO_BET")
	else:
		var net: float = mine["net"]
		var win := net > 0.0
		result.add_theme_color_override("font_color", GameColors.UP if win else GameColors.DOWN)
		result.text = ""
		var tw := result.create_tween()
		tw.tween_interval(delay + 0.3)
		tw.tween_method(func(v: float) -> void:
			result.text = (tr("TABLE_YOU_WON") if win else tr("TABLE_YOU_LOST")) % GameFmt.money(v, 0), 0.0, absf(net), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void: TableFx.pop(result, 1.25))
	return box


## Your own bet on this rumor: {"net": profit or loss}, or {} when you passed.
func _mine(report: TableReport, rumor: TableRumor) -> Dictionary:
	for p in report.payouts:
		if int(p["seat"]) == 0 and int(p["rumor"]) == rumor.id:
			return {"net": float(p["payout"]) - float(p["premium"])}
	return {}


## The stamp has landed: thud, flash, the card jolts; your own win throws confetti, a loss sounds sour.
func _impact(color: Color, strength: float, boss: bool, mine: Dictionary) -> void:
	TableFx.sfx(&"stamp")
	TableFx.flash(self, color, strength + (0.12 if boss else 0.0), 0.5)
	TableFx.jolt(_panel, 1.09 if boss else 1.05)
	if mine.is_empty():
		return
	var net: float = mine["net"]
	var timer := get_tree().create_timer(0.14)
	timer.timeout.connect(func() -> void:
		TableFx.sfx(&"win" if net > 0.0 else &"lose")
		if net > 0.0 and is_inside_tree():
			TableFx.confetti(self, _panel.global_position + Vector2(_panel.size.x * 0.5, 30.0), 70 if boss else 44))


func _clear() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
