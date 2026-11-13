## The scene between two days: the screen turns to night, the moon sets, the sun comes up, and the day counter
## flips from the day that ended to the new one. About two seconds; then the game shows again.
class_name DayTransition
extends Control

signal finished

const DURATION := 2.4

var from_day: int = 0
var to_day: int = 1
var total_days: int = 30
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()
var _fade: float = 0.0
var _number: Label
var _flipped: bool = false


static func play(host: Control, p_from: int, p_to: int, p_total: int) -> void:
	var scene := DayTransition.new()
	scene.from_day = p_from
	scene.to_day = p_to
	scene.total_days = p_total
	host.add_child(scene)
	await scene.finished
	scene.queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("no_fx", true)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var head := GameFmt.label(tr(TurnBar.STEP_KEYS[3]).to_upper(), Color(1, 1, 1, 0.85), 22)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	_number = GameFmt.label(tr("TABLE_DAY_OF") % [from_day, total_days], Color("#fff6e0"), 64)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_number)
	modulate.a = 0.0
	_run()


func _run() -> void:
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.3)
	TableFx.sfx(&"next_day")
	var sweep := create_tween()
	sweep.tween_property(self, "progress", 1.0, DURATION - 0.7).set_delay(0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.2 + (DURATION - 0.7) * 0.5).timeout
	_number.text = tr("TABLE_DAY_OF") % [to_day, total_days]
	_flipped = true
	TableFx.pop(_number, 1.4, 0.0)
	TableFx.sfx(&"reveal_tick")
	await get_tree().create_timer((DURATION - 0.7) * 0.5 + 0.1).timeout
	TableFx.sfx(&"slot_land")
	await get_tree().create_timer(0.3).timeout
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.4)
	await out.finished
	finished.emit()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Night turns to dawn.
	SkyArt.sky(self, rect, SkyArt.SKY_TOP[2].lerp(SkyArt.SKY_TOP[0], progress), SkyArt.SKY_BOTTOM[2].lerp(SkyArt.SKY_BOTTOM[0], progress))
	if progress < 0.8:
		SkyArt.stars(self, rect, 40, progress * 6.0)
	var horizon := size.y * 0.72
	var sky_clip := Rect2(Vector2.ZERO, Vector2(size.x, horizon))
	# The moon sets on the left, the sun comes up on the right.
	var moon_y := lerpf(size.y * 0.28, horizon + 70.0, progress)
	SkyArt.moon(self, Vector2(size.x * 0.22, moon_y), 44.0, sky_clip)
	var sun_y := lerpf(horizon + 70.0, size.y * 0.3, progress)
	SkyArt.sun(self, Vector2(size.x * 0.78, sun_y), 44.0, sky_clip, SkyArt.SUN_DAWN, progress)
	SkyArt.ground(self, rect, Color("#1b1233"), size.y - horizon)
