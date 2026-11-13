## The night between two days. The screen turns to night and, in order:
##   1 your net worth rolls to its new value (the first days only),
##   2 a face-down card arrives for tomorrow's rumor, its border showing how credible the rumor is, with two small
##     countdowns (the Boss rumor, the end of the quarter),
##   3 the moon sets and the sun comes up, the day counter flips.
## The card stays face down: what the rumor is about is only told the next morning, with the news.
## Space skips all of it. The first days play the whole thing (about 4 seconds), later days a short version (about 3).
class_name DayTransition
extends Control

signal finished

const FULL_DAYS := 3
const NIGHT := 0.0

var from_day: int = 0
var to_day: int = 1
var total_days: int = 30
var info: Dictionary = {}
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()
var _skipped: bool = false
var _number: Label
var _recap: Label
var _card: PanelContainer
var _chips: HBoxContainer
var _short: bool = false


## `info`: net_from, net_to, tier (-1 = hidden), boss_days, quarter_days.
static func play(host: Control, p_from: int, p_to: int, p_total: int, p_info: Dictionary = {}) -> void:
	var scene := DayTransition.new()
	scene.from_day = p_from
	scene.to_day = p_to
	scene.total_days = p_total
	scene.info = p_info
	host.add_child(scene)
	await scene.finished
	scene.queue_free()


func _ready() -> void:
	TableUi.locks += 1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("no_fx", true)
	_short = to_day > FULL_DAYS
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var head := GameFmt.label(tr(TurnBar.STEP_KEYS[3]).to_upper(), Color(1, 1, 1, 0.85), 22)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	_number = GameFmt.label(tr("TABLE_DAY_OF") % [from_day, total_days], Color("#fff6e0"), 56)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_number)
	_recap = GameFmt.label(" ", Color("#fff6e0"), 20)
	_recap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_recap)
	var middle := HBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 22)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(middle)
	_card = _make_card()
	_card.modulate.a = 0.0
	middle.add_child(_card)
	_chips = HBoxContainer.new()
	var chip_col := VBoxContainer.new()
	chip_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_col.add_theme_constant_override("separation", 6)
	chip_col.modulate.a = 0.0
	chip_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(chip_col)
	_chips = null
	chip_col.set_meta("is_chips", true)
	var boss_days := int(info.get("boss_days", -1))
	if boss_days >= 0:
		chip_col.add_child(_chip(tr("TABLE_NIGHT_BOSS") % boss_days if boss_days > 0 else tr("TABLE_NIGHT_BOSS_NOW"), Color("#b57bee")))
	chip_col.add_child(_chip(tr("TABLE_NIGHT_QUARTER") % int(info.get("quarter_days", 0)), Color("#4aa3ff")))
	modulate.a = 0.0
	_run(chip_col)


func _chip(text: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.set_meta("no_fx", true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.border_color = color
	sb.set_border_width_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(GameFmt.label(text, Color("#fff6e0"), 16))
	return panel


## The card, face down: a dark back whose border colour is how credible tomorrow's rumor is.
func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 120)
	card.set_meta("no_fx", true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_back(card)
	var label := GameFmt.label("?", Color("#fff6e0"), 64)
	label.name = "Face"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(label)
	return card


func _style_back(card: PanelContainer) -> void:
	var tier := int(info.get("tier", -1))
	var color := Color("#8d8a94") if tier < 0 else TableUi.tier_color(tier)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1b1830")
	sb.border_color = color
	sb.set_border_width_all(6)
	card.add_theme_stylebox_override("panel", sb)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_day") or event.is_action_pressed("ui_accept"):
		_skipped = true
		get_viewport().set_input_as_handled()


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0 and not _skipped:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _run(chip_col: Control) -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	TableFx.sfx(&"next_day")
	await _wait(0.3)
	# 1 Your net worth rolls to its new value.
	if not _short and info.has("net_to") and not _skipped:
		var from := float(info["net_from"])
		var to := float(info["net_to"])
		var roll := create_tween()
		roll.tween_method(func(v: float) -> void:
			_recap.text = tr("TABLE_NIGHT_NET") % [GameFmt.money(v, 0), ("+" if to >= from else "-") + GameFmt.money(absf(v - from), 0)], from, to, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		TableFx.sfx(&"reveal_tick")
		await _wait(1.2)
	# 2 The face-down card arrives with the two countdowns.
	if not _skipped:
		_card.pivot_offset = _card.size * 0.5
		_card.scale = Vector2(1.4, 1.4)
		_card.rotation = -0.08
		var drop := create_tween().set_parallel(true)
		drop.tween_property(_card, "modulate:a", 1.0, 0.1)
		drop.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop.tween_property(_card, "rotation", 0.0, 0.3)
		TableFx.sfx(&"night_card")
		await _wait(0.35)
		create_tween().tween_property(chip_col, "modulate:a", 1.0, 0.3)
		await _wait(0.5 if _short else 0.9)
	# 3 The moon sets, the sun comes up, the day counter flips.
	var sweep_time := 0.9 if _short else 1.3
	if not _skipped:
		create_tween().tween_property(self, "progress", 1.0, sweep_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _wait(sweep_time * 0.5)
		_number.text = tr("TABLE_DAY_OF") % [to_day, total_days]
		TableFx.pop(_number, 1.4, 0.0)
		TableFx.sfx(&"reveal_tick")
		await _wait(sweep_time * 0.5 + 0.1)
	progress = 1.0
	await _wait(0.5)
	await _wait(0.1)
	create_tween().tween_property(self, "modulate:a", 0.0, 0.35)
	await _wait(0.35)
	if _skipped:
		modulate.a = 0.0
	TableUi.locks = maxi(TableUi.locks - 1, 0)
	finished.emit()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Night turns to dawn.
	SkyArt.sky(self, rect, SkyArt.SKY_TOP[2].lerp(SkyArt.SKY_TOP[0], progress), SkyArt.SKY_BOTTOM[2].lerp(SkyArt.SKY_BOTTOM[0], progress))
	if progress < 0.8:
		SkyArt.stars(self, rect, 40, progress * 6.0)
	var horizon := size.y * 0.78
	var sky_clip := Rect2(Vector2.ZERO, Vector2(size.x, horizon))
	# The moon sets on the left, the sun comes up on the right.
	var moon_y := lerpf(size.y * 0.3, horizon + 70.0, progress)
	SkyArt.moon(self, Vector2(size.x * 0.1, moon_y), 44.0, sky_clip)
	var sun_y := lerpf(horizon + 70.0, size.y * 0.3, progress)
	SkyArt.sun(self, Vector2(size.x * 0.9, sun_y), 44.0, sky_clip, SkyArt.SUN_DAWN, progress)
	SkyArt.ground(self, rect, Color("#1b1233"), size.y - horizon)
