## Two pop-ups of a table day. After the reveal button: everybody's bets, flipped over one by one (Double Dan can
## double here). After the day resolves: the verdict stamp slams down, the screen flashes, a win throws confetti.
class_name TableOverlay
extends Control

signal result_closed

enum Mode { NONE, REVEAL, RESULT }

const ROW_STEP := 0.24
const STAMP_DELAY := 0.4
const STAMP_GAP := 1.35
## The pause between pressing Next and the verdict (step 4, Next day, shows on the bar meanwhile).
const RESULT_DELAY := 0.6
## How long the revealed bets stay on screen before the day resolves by itself.
const AUTO_HOLD := 1.3

var _mode: Mode = Mode.NONE
var _panel: PanelContainer
var _body: VBoxContainer
var _dim: ColorRect
var _play_intro: bool = false
var _auto_token: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if _mode == Mode.RESULT and event is InputEventMouseButton and event.pressed:
			_close())
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


## Space (or Enter) moves a pop-up on: it closes the verdict, or skips the wait after the bets are revealed.
func _input(event: InputEvent) -> void:
	if not visible or not (event.is_action_pressed("next_day") or event.is_action_pressed("ui_accept")):
		return
	if _mode == Mode.RESULT:
		get_viewport().set_input_as_handled()
		_close()
	elif _mode == Mode.REVEAL:
		var t := TableUi.session()
		if t != null and t.phase == TableSession.Phase.REVEALED:
			get_viewport().set_input_as_handled()
			GameManager.next_day()


func _set_modal(on: bool) -> void:
	TableUi.modal_open = on
	visible = on
	if on:
		# The dim stops above the bottom bar, so the Next button stays in reach.
		var bar := get_tree().current_scene.get_node_or_null("%TurnBar") as Control
		_dim.offset_bottom = -(bar.size.y + 10.0) if bar != null else 0.0


func _close() -> void:
	var was_result := _mode == Mode.RESULT
	_mode = Mode.NONE
	_set_modal(false)
	if was_result:
		result_closed.emit()


# ---------------------------------------------------------------- reveal

func _on_revealed(_entries: Array) -> void:
	_mode = Mode.REVEAL
	_play_intro = true
	_refresh_reveal()
	_set_modal(true)
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
	var auto_on := GameSettings.auto_reveal() and not t.can_double(0)
	if not auto_on:
		var hint := GameFmt.label(tr("TABLE_PRESS_NEXT"), Color("#c77d0a"), 15)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.add_child(hint)
		extras.append(hint)
	if auto_on:
		var note := GameFmt.label(tr("TABLE_AUTO_NOTE"), GameColors.MUTED, 12)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.add_child(note)
	var intro_time := 0.3 + ROW_STEP * rows.size()
	if _play_intro:
		_play_intro = false
		_animate_reveal(rows, extras)
		if auto_on:
			_schedule_auto(intro_time + AUTO_HOLD)
	elif auto_on:
		_schedule_auto(1.2)


## Resolves the day after `seconds`, unless the player already did, the screen moved on, or Dan still has a choice.
func _schedule_auto(seconds: float) -> void:
	_auto_token += 1
	var token := _auto_token
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		var t := TableUi.session()
		if token != _auto_token or t == null or _mode != Mode.REVEAL or not visible:
			return
		if t.phase == TableSession.Phase.REVEALED and not t.can_double(0):
			GameManager.next_day())


## The bets turn over one after another: each row fades in with a tick and its call pops big.
func _animate_reveal(rows: Array[Control], extras: Array[Control]) -> void:
	var at := 0.3
	for row in rows:
		row.modulate.a = 0.0
		var tw := row.create_tween()
		tw.tween_interval(at)
		tw.tween_callback(func() -> void: TableFx.sfx(&"reveal_tick"))
		tw.tween_property(row, "modulate:a", 1.0, 0.1)
		TableFx.pop(row.get_child(1) as Control, 3.4, at)
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
	_auto_token += 1
	_mode = Mode.NONE
	_set_modal(false)
	await get_tree().create_timer(RESULT_DELAY).timeout    # the "Next day" beat before the verdict
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
	var ok := GameFmt.button(tr("TABLE_OK"))
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(_close)
	_body.add_child(ok)
	extras.append(ok)
	for e in extras:
		e.modulate.a = 0.0
		e.create_tween().tween_property(e, "modulate:a", 1.0, 0.3).set_delay(at)
	_set_modal(true)
	EventBus.table_step.emit(TurnBar.Step.PRE)
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
	TableFx.slam(stamp, delay, _impact.bind(color, 0.42, rumor.is_boss(), mine))
	if rumor.planted:
		var planted := TableFx.make_stamp(tr("TABLE_PLANTED"), TableFx.PLANTED_COLOR, 24)
		stamps.add_child(planted)
		TableFx.slam(planted, delay + 0.6, _impact.bind(TableFx.PLANTED_COLOR, 0.3, false, {}))
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


## The stamp has landed: thud, flash, the whole screen shakes and the card jolts. Your own win throws confetti from both
## sides, a loss flashes red twice and shakes harder.
func _impact(color: Color, strength: float, boss: bool, mine: Dictionary) -> void:
	TableFx.sfx(&"stamp")
	var lost := not mine.is_empty() and float(mine["net"]) <= 0.0
	TableFx.flash(self, color, strength + (0.18 if boss else 0.0), 0.65)
	TableFx.jolt(_panel, 1.16 if boss else 1.09)
	var scene := get_tree().current_scene as Control
	if scene != null:
		TableFx.shake(scene, (30.0 if boss else 15.0) + (8.0 if lost else 0.0), 0.55)
	if mine.is_empty():
		return
	var net: float = mine["net"]
	var timer := get_tree().create_timer(0.14)
	timer.timeout.connect(func() -> void:
		TableFx.sfx(&"win" if net > 0.0 else &"lose")
		if not is_inside_tree():
			return
		if net > 0.0:
			var top := _panel.global_position.y + 30.0
			var amount := 160 if boss else 90
			TableFx.confetti(self, Vector2(_panel.global_position.x + 40.0, top + 40.0), amount, 0.55)
			TableFx.confetti(self, Vector2(_panel.global_position.x + _panel.size.x - 40.0, top + 40.0), amount, -0.55)
			TableFx.confetti(self, Vector2(_panel.global_position.x + _panel.size.x * 0.5, top), amount, 0.0)
		else:
			TableFx.flash(self, GameColors.DOWN, 0.5, 0.5))


func _clear() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
