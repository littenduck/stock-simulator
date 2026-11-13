## The animation of a character skill. When a skill takes effect in front of the table, everybody waits for its
## animation to finish (Space skips it); the screen is locked meanwhile. Each skill has its own look:
##   insider_tip   an eye opens on a dark screen (only its owner sees it: the skill is hidden)
##   hodl_buy      pixel diamonds rain down
##   copilot       a beam of dashes runs from the copied seat to the copier
##   double_down   a huge x2 slams down with a burst of coins and a shake
##   interest      coins drift up
##   goldfish_odds bubbles rise
##   hodl_sector   sparkles blink
## Hidden skills (the Insider's) are only played for their owner; their effect comes out later in the usual way.
class_name SkillFx
extends Control

const COINS := Color("#ffd23f")

var kind: StringName = &""
## 0..1 over the life of the animation.
var t: float = 0.0:
	set(value):
		t = value
		queue_redraw()
var _skipped: bool = false
var _done: bool = false


## Plays every event that may be seen (public ones, and your own hidden ones), one after another.
static func play_all(host: Control, events: Array[Dictionary], session: TableSession) -> void:
	for e in events:
		if bool(e["public"]) or int(e["seat"]) == 0:
			await play(host, e, session)


static func play(host: Control, event: Dictionary, session: TableSession) -> void:
	var fx := SkillFx.new()
	host.add_child(fx)
	await fx.run(event, session)
	fx.queue_free()


func run(event: Dictionary, session: TableSession) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("no_fx", true)
	z_index = 60
	var skill: StringName = event["skill"]
	kind = skill
	var seat: Seat = session.seats[int(event["seat"])]
	var title_key := ""
	var body := ""
	var accent := COINS
	var duration := 1.6
	match skill:
		TableSkills.INSIDER_TIP:
			title_key = "TABLE_SKILL_TIP"
			var hint := session.tomorrow_rumor
			body = tr("TABLE_SKILL_TIP_BODY") if hint == null else tr("TABLE_SKILL_TIP_BODY") + "\n" + hint.headline(tr, session.market)
			accent = Color("#b57bee")
			duration = 2.0
		TableSkills.HODL_BUY:
			title_key = "TABLE_SKILL_HODL"
			body = tr("TABLE_SKILL_HODL_BODY") % [int(event["amount"]), seat.mods.locked_symbol]
			accent = Color("#7fd6ff")
			duration = 2.0
		TableSkills.COPILOT:
			title_key = "TABLE_SKILL_COPY"
			var target: Seat = session.seats[int(event["target"])]
			body = tr("TABLE_SKILL_COPY_BODY") % [TableUi.seat_name(seat, self), TableUi.seat_name(target, self)]
			accent = Color("#4aa3ff")
			duration = 1.7
		TableSkills.DOUBLE_DOWN:
			title_key = "TABLE_SKILL_DOUBLE"
			body = tr("TABLE_SKILL_DOUBLE_BODY") % [TableUi.seat_name(seat, self), GameFmt.money(float(event["amount"]), 0)]
			accent = Color("#f85149")
			duration = 1.9
		TableSkills.INTEREST:
			title_key = "TABLE_SKILL_INTEREST"
			body = tr("TABLE_SKILL_INTEREST_BODY") % [TableUi.seat_name(seat, self), GameFmt.money(float(event["amount"]), 2)]
			accent = Color("#3fb950")
			duration = 1.6
		TableSkills.GOLDFISH_ODDS:
			title_key = "TABLE_SKILL_GOLDFISH"
			body = tr("TABLE_SKILL_ODDS_BODY") % [TableUi.seat_name(seat, self), float(event["amount"])]
			accent = Color("#ff9244")
			duration = 1.3
		TableSkills.HODL_SECTOR:
			title_key = "TABLE_SKILL_SECTOR"
			body = tr("TABLE_SKILL_ODDS_BODY") % [TableUi.seat_name(seat, self), float(event["amount"])]
			accent = Color("#7fd6ff")
			duration = 1.3
		_:
			return
	var was_modal := TableUi.modal_open
	TableUi.modal_open = true
	TableUi.set_busy(true)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var card := _card(seat, tr(title_key), body, accent)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	add_child(center)
	card.modulate.a = 0.0
	await get_tree().process_frame
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.4, 0.4)
	var intro := create_tween().set_parallel(true)
	intro.tween_property(dim, "color:a", 0.5 if skill == TableSkills.INSIDER_TIP else 0.3, 0.2)
	intro.tween_property(card, "modulate:a", 1.0, 0.12)
	intro.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TableFx.sfx(&"stamp")
	if skill == TableSkills.DOUBLE_DOWN:
		_slam_double(card)
	var life := create_tween()
	life.tween_property(self, "t", 1.0, duration)
	var waited := 0.0
	while waited < duration and not _skipped:
		await get_tree().process_frame
		waited += get_process_delta_time()
	life.kill()
	var out := create_tween().set_parallel(true)
	out.tween_property(card, "modulate:a", 0.0, 0.2)
	out.tween_property(dim, "color:a", 0.0, 0.2)
	await out.finished
	TableUi.set_busy(false)
	TableUi.modal_open = was_modal
	_done = true


func _unhandled_input(event: InputEvent) -> void:
	if not _done and (event.is_action_pressed("next_day") or event.is_action_pressed("ui_accept")):
		_skipped = true
		get_viewport().set_input_as_handled()


func _card(seat: Seat, title: String, body: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.custom_minimum_size = Vector2(560, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.self_modulate = Color.WHITE.lerp(accent, 0.1)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	row.add_child(PortraitView.make(String(seat.character.id), 6))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	col.add_child(GameFmt.label(title, accent.darkened(0.3), 30))
	col.add_child(TableUi.wrapped(body, Color("#2b2540"), 16))
	return panel


## The x2 comes down like a stamp: a flash, a shake of the whole screen and coins from the card.
func _slam_double(card: Control) -> void:
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		TableFx.flash(self, Color("#f85149"), 0.3, 0.5)
		var scene := get_tree().current_scene as Control
		if scene != null:
			TableFx.shake(scene, 16.0, 0.5)
		TableFx.confetti(self, card.global_position + card.size * 0.5, 80, 0.0)
		TableFx.sfx(&"win"))


# ---------------------------------------------------------------- the looks

func _draw() -> void:
	var s := size
	match kind:
		TableSkills.INSIDER_TIP:
			_draw_eye(s)
		TableSkills.HODL_BUY:
			_draw_falling(s, 22, Color("#7fd6ff"), Color("#ffffff"), true)
		TableSkills.COPILOT:
			_draw_beam(s)
		TableSkills.DOUBLE_DOWN:
			_draw_times_two(s)
		TableSkills.INTEREST:
			_draw_rising_coins(s)
		TableSkills.GOLDFISH_ODDS:
			_draw_bubbles(s)
		TableSkills.HODL_SECTOR:
			_draw_sparkles(s)


func _draw_eye(s: Vector2) -> void:
	var c := Vector2(s.x * 0.5, s.y * 0.2)
	var open := clampf(t * 4.0, 0.0, 1.0)
	var cell := 10.0
	for gy in range(-5, 6):
		var k := 1.0 - pow(float(gy) / 5.5, 2.0)
		var half := 120.0 * sqrt(maxf(k, 0.0)) * (0.2 + 0.8 * open)
		if absf(float(gy)) / 5.0 > open + 0.05:
			continue
		draw_rect(Rect2(c.x - half, c.y + gy * cell, half * 2.0, cell), Color("#f4efe0"))
	if open > 0.4:
		SkyArt.disc(self, c, 44.0, Color("#2f80e0"), Rect2(Vector2.ZERO, s))
		SkyArt.disc(self, c, 20.0, Color("#0e1230"), Rect2(Vector2.ZERO, s))
		draw_rect(Rect2(c + Vector2(-18, -20), Vector2(10, 10)), Color.WHITE)
	draw_rect(Rect2(0, s.y * 0.2 - 3.0 + fmod(t * s.y, s.y * 0.1), s.x, 2.0), Color(1, 1, 1, 0.12))


func _draw_falling(s: Vector2, count: int, a: Color, b: Color, diamonds: bool) -> void:
	for i in count:
		var x := fmod(float(i) * 97.0 + 31.0, s.x)
		var speed := 0.6 + fmod(float(i) * 0.37, 0.8)
		var y := fmod(t * s.y * speed * 1.3 + float(i) * 53.0, s.y + 40.0) - 20.0
		var r := 12.0 + fmod(float(i) * 3.0, 12.0)
		var col := a if i % 2 == 0 else b
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - r), Vector2(x + r * 0.7, y), Vector2(x, y + r), Vector2(x - r * 0.7, y)]), col)
		draw_rect(Rect2(x - 1.0, y - r * 0.5, 3.0, 3.0), Color(1, 1, 1, 0.9))


func _draw_beam(s: Vector2) -> void:
	var y := s.y * 0.5 + 100.0
	var x0 := s.x * 0.3
	var x1 := s.x * 0.7
	for i in 12:
		var f := fposmod(float(i) / 12.0 + t * 1.6, 1.0)
		var x := lerpf(x0, x1, f)
		draw_rect(Rect2(x - 10.0, y - 3.0, 20.0, 6.0), Color(0.29, 0.64, 1.0, 0.25 + 0.75 * f))
	draw_colored_polygon(PackedVector2Array([Vector2(x1 + 8.0, y), Vector2(x1 - 12.0, y - 14.0), Vector2(x1 - 12.0, y + 14.0)]), Color("#4aa3ff"))


func _draw_times_two(s: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var pop := clampf(t * 5.0, 0.0, 1.0)
	var size_px := int(lerpf(380.0, 220.0, ease(pop, 0.3)))
	var text := "x2"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var pos := Vector2((s.x - w) * 0.5, s.y * 0.5 + 230.0)
	draw_string(font, pos + Vector2(6, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, 0.5 * pop))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1.0, 0.82, 0.25, pop))


func _draw_rising_coins(s: Vector2) -> void:
	for i in 14:
		var x := fmod(float(i) * 83.0 + 40.0, s.x)
		var y := s.y - fposmod(t * s.y * (0.5 + fmod(float(i) * 0.31, 0.6)) + float(i) * 41.0, s.y + 40.0) + 20.0
		SkyArt.disc(self, Vector2(x, y), 22.0, Color("#b8860b"), Rect2(Vector2.ZERO, s))
		SkyArt.disc(self, Vector2(x, y), 17.0, COINS, Rect2(Vector2.ZERO, s))
		draw_rect(Rect2(x - 3.0, y - 10.0, 6.0, 20.0), Color("#b8860b"))


func _draw_bubbles(s: Vector2) -> void:
	for i in 12:
		var x := fmod(float(i) * 113.0 + 60.0, s.x) + sin(t * 6.0 + float(i)) * 12.0
		var y := s.y - fposmod(t * s.y * (0.6 + fmod(float(i) * 0.23, 0.5)) + float(i) * 67.0, s.y + 40.0) + 20.0
		draw_arc(Vector2(x, y), 16.0 + fmod(float(i) * 3.0, 14.0), 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.85), 4.0)
		draw_rect(Rect2(x - 3.0, y - 5.0, 3.0, 3.0), Color(1, 1, 1, 0.9))


func _draw_sparkles(s: Vector2) -> void:
	for i in 14:
		var p := Vector2(fmod(float(i) * 151.0 + 37.0, s.x), fmod(float(i) * 89.0 + 23.0, s.y))
		var k := absf(sin(t * 7.0 + float(i) * 1.3))
		var r := 8.0 + 22.0 * k
		var col := Color(0.5, 0.84, 1.0, 0.3 + 0.7 * k)
		draw_rect(Rect2(p.x - r, p.y - 3.0, r * 2.0, 6.0), col)
		draw_rect(Rect2(p.x - 3.0, p.y - r, 6.0, r * 2.0), col)
