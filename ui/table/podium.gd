## The end of the run: the four players on a podium, built from the bottom up. The winner jumps with a crown while the
## confetti falls, second and third clap, last shakes their head. Everybody's final net worth rolls up under them.
## If you won, YOU WIN is stamped across the screen. Space (or a click) closes it.
class_name Podium
extends Control

signal finished

const COL_W := 230.0
const COLORS := [Color("#ffd23f"), Color("#c9d1d9"), Color("#d08a4a"), Color("#8d8a94")]
## Heights of the pedestals by place (1st is the tallest).
const HEIGHTS := [190.0, 130.0, 90.0, 56.0]
## The left-to-right order of the places: 2nd, 1st, 3rd, 4th.
const LAYOUT := [1, 0, 2, 3]
const MOVES := ["jump", "emote-yes", "emote-yes", "emote-no"]

var _session: TableSession
var _skipped: bool = false
var _ready_to_close: bool = false
var _age: float = 0.0
var _progress: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _winner_stamp: Control


static func play(host: Control, session: TableSession) -> void:
	var podium := Podium.new()
	podium._session = session
	host.add_child(podium)
	await podium.finished
	podium.queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("no_fx", true)
	z_index = 58
	modulate.a = 0.0
	_run()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("next_day") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed)
	if pressed and _ready_to_close:
		_skipped = true
		get_viewport().set_input_as_handled()


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	SkyArt.sky(self, rect, Color("#241a4d"), Color("#e8856b"))
	SkyArt.stars(self, rect, 30, _age * 2.0, 11)
	var base_y := size.y * 0.8
	# A soft spotlight over the winner.
	var cx := size.x * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 40, 0), Vector2(cx + 40, 0), Vector2(cx + 190, base_y), Vector2(cx - 190, base_y)]), Color(1, 0.95, 0.7, 0.10 * _progress[0]))
	for slot in 4:
		var place: int = LAYOUT[slot]
		var x := size.x * 0.5 + (float(slot) - 1.5) * COL_W
		var h: float = HEIGHTS[place] * _progress[place]
		draw_rect(Rect2(x - COL_W * 0.42, base_y - h, COL_W * 0.84, h), COLORS[place].darkened(0.1))
		draw_rect(Rect2(x - COL_W * 0.42, base_y - h, COL_W * 0.84, 10.0), COLORS[place].lightened(0.25))
		if h > 30.0:
			draw_string(ThemeDB.fallback_font, Vector2(x - 14.0, base_y - h + 66.0), str(place + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 54, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(0, base_y, size.x, size.y - base_y), Color("#1b1233"))


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _run() -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	await get_tree().process_frame
	await get_tree().process_frame
	var standings := _session.standings()
	var base_y := size.y * 0.8
	var holders: Array[Control] = []
	# From the bottom of the table up: 4th, 3rd, 2nd, then the winner.
	for place in [3, 2, 1, 0]:
		var entry: Dictionary = standings[place]
		var seat: Seat = entry["seat"]
		var slot: int = LAYOUT.find(place)
		var x := size.x * 0.5 + (float(slot) - 1.5) * COL_W
		var column := _make_column(seat, float(entry["net_worth"]), place, x, base_y)
		add_child(column)
		TableFx.sfx(&"board_drop")
		var rise := create_tween()
		rise.tween_method(func(v: float) -> void: _progress[place] = v, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await _wait(0.5)
		# The character steps onto the pedestal and makes its move.
		column.visible = true
		TableFx.pop(column, 0.4, 0.0)
		var model: Node3D = column.get_meta("model") if column.has_meta("model") else null
		if model != null:
			_play_move(model, MOVES[place], place == 0)
		if place == 0:
			_celebrate(column, x, base_y - HEIGHTS[0])
		else:
			TableFx.sfx(&"slot_land")
		var net: Label = column.find_child("Net", true, false)
		var roll := create_tween()
		roll.tween_method(func(v: float) -> void: net.text = GameFmt.money(v, 0), _session.config.character.start_cash, float(entry["net_worth"]), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await _wait(0.9 if place > 0 else 0.5)
		holders.append(column)
	# Did you win?
	var you_won := (standings[0]["seat"] as Seat).is_human
	var banner := GameFmt.label(tr("TABLE_PODIUM_WIN") if you_won else tr("TABLE_PODIUM_PLACE") % _session.human_rank(), Color("#fff6e0") if not you_won else Color("#ffd23f"), 72 if you_won else 34)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 30)
	add_child(banner)
	if you_won:
		banner.pivot_offset = banner.size * 0.5
		TableFx.pop(banner, 3.0, 0.0)
		TableFx.sfx(&"stamp")
		TableFx.shake(get_tree().current_scene as Control, 14.0, 0.5)
		TableFx.confetti(self, Vector2(size.x * 0.5, 120.0), 140, 0.0)
	else:
		TableFx.pop(banner, 1.6, 0.0)
	var hint := GameFmt.label(tr("TABLE_SKILL_CONTINUE"), Color(1, 1, 1, 0.85), 16)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	add_child(hint)
	_ready_to_close = true
	var waited := 0.0
	while not _skipped:
		await get_tree().process_frame
		waited += get_process_delta_time()
		hint.modulate.a = 0.55 + 0.45 * absf(sin(waited * 4.0))
		if you_won and fmod(waited, 2.2) < get_process_delta_time():
			TableFx.confetti(self, Vector2(randf_range(size.x * 0.3, size.x * 0.7), 40.0), 40, 0.0)
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.3)
	await out.finished
	finished.emit()


## One place: the character on the pedestal with name and net worth under it (the model is a live 3D render).
func _make_column(seat: Seat, net_worth: float, place: int, x: float, base_y: float) -> Control:
	var column := Control.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size = Vector2(COL_W, 360)
	column.position = Vector2(x - COL_W * 0.5, base_y - HEIGHTS[place] - 300.0)
	column.pivot_offset = Vector2(COL_W * 0.5, 300.0)
	column.visible = false
	var id := String(seat.character.id)
	var model := CharacterModel.make(id)
	var view := Control.new()
	view.custom_minimum_size = Vector2(COL_W, 300)
	view.size = Vector2(COL_W, 300)
	column.add_child(view)
	if model != null:
		var vp := CharacterModel.make_viewport(model, Vector2i(int(COL_W) * 2, 600))
		view.add_child(vp)
		var tex := TextureRect.new()
		tex.texture = vp.get_texture()
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(tex)
		column.set_meta("model", model)
	else:
		view.add_child(PortraitView.make(id, 12))
	var box := VBoxContainer.new()
	box.position = Vector2(0, 306.0 + HEIGHTS[place] - 10.0)
	box.size = Vector2(COL_W, 60)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(box)
	var name_label := GameFmt.label(TableUi.seat_name(seat, self), Color("#fff6e0") if not seat.is_human else Color("#ffd23f"), 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var net := GameFmt.label(GameFmt.money(net_worth, 0), Color("#fff6e0"), 18)
	net.name = "Net"
	net.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(net)
	box.position.y = 300.0 + 6.0
	return column


func _play_move(model: Node3D, move: String, loop: bool) -> void:
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim == null or not anim.has_animation(move):
		return
	anim.get_animation(move).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim.play(move)
	if not loop:
		anim.animation_finished.connect(func(_n: StringName) -> void:
			if anim.has_animation("idle"):
				anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
				anim.play("idle"), CONNECT_ONE_SHOT)


## The winner: a crown, a fanfare and confetti from both sides.
func _celebrate(column: Control, x: float, top_y: float) -> void:
	var crown := RankingBoard._PixelCrown.new()
	crown.size = Vector2(64, 40)
	crown.custom_minimum_size = Vector2(64, 40)
	crown.position = Vector2(COL_W * 0.5 - 32.0, -10.0)
	column.add_child(crown)
	TableFx.sfx(&"fanfare")
	TableFx.confetti(self, Vector2(x - 160.0, top_y), 90, 0.55)
	TableFx.confetti(self, Vector2(x + 160.0, top_y), 90, -0.55)
