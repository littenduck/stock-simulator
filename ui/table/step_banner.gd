## A banner that sweeps across the screen when the turn moves to a new part of the day, painted as that time of the
## day: PRE-MARKET is dawn (the sun rises), MARKET OPEN is daytime (the sun), AFTER-MARKET is night (moon and stars).
## The turn over to the next day has its own full-screen scene (DayTransition). The banner never blocks the mouse.
class_name StepBanner
extends Control

const HINT_KEYS := ["TABLE_BANNER_PRE", "TABLE_BANNER_OPEN", "TABLE_BANNER_AFTER"]
const TIME_KEYS := ["TABLE_BANNER_DAWN", "TABLE_BANNER_DAY", "TABLE_BANNER_NIGHT"]
const SLIDE := 0.35
const HOLD := 0.95
const SIZE := Vector2(620, 132)

var _banner: Control
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("no_fx", true)


## Shows the banner for every step the turn bar moves to.
func watch(bar: TurnBar) -> void:
	bar.stepped.connect(show_step)


func show_step(step: int) -> void:
	if step < 0 or step >= HINT_KEYS.size() or not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _banner != null:
		_banner.queue_free()
	var sky := _Sky.new()
	sky.step = step
	sky.custom_minimum_size = SIZE
	sky.size = SIZE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_meta("no_fx", true)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 170.0
	box.offset_right = -20.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(box)
	var tag := GameFmt.label("%s %d / 4  ·  %s" % [tr("TABLE_BANNER_STEP"), step + 1, tr(TIME_KEYS[step])], Color(1, 1, 1, 0.85), 14)
	box.add_child(tag)
	box.add_child(GameFmt.label(tr(TurnBar.STEP_KEYS[step]).to_upper(), Color("#fff6e0"), 44))
	box.add_child(GameFmt.label(tr(HINT_KEYS[step]), Color(1, 1, 1, 0.9), 16))
	add_child(sky)
	_banner = sky
	var rest := Vector2((size.x - SIZE.x) * 0.5, size.y * 0.13)
	sky.position = Vector2(-SIZE.x - 40.0, rest.y)
	sky.rotation = -0.03
	TableFx.sfx(&"slot_land")
	_tween = create_tween()
	_tween.tween_property(sky, "position:x", rest.x, SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(sky, "rotation", 0.0, SLIDE)
	_tween.parallel().tween_property(sky, "motion", 1.0, SLIDE + HOLD)
	_tween.tween_interval(HOLD)
	_tween.tween_property(sky, "position:x", size.x + 40.0, SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(sky.queue_free)


## The painted banner: a sky with the sun rising, the sun, or the moon and stars.
class _Sky extends Control:
	var step: int = 0
	## 0..1 over the life of the banner: the sun rises, the rays turn, the stars blink.
	var motion: float = 0.0:
		set(value):
			motion = value
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		SkyArt.sky(self, rect, SkyArt.SKY_TOP[step], SkyArt.SKY_BOTTOM[step])
		var clip := rect.grow(-4.0)
		var center := Vector2(84.0, size.y * 0.5)
		match step:
			0:
				# Dawn: the sun climbs from behind the horizon.
				var horizon := size.y - 16.0
				var rise := lerpf(horizon + 34.0, horizon - 22.0, ease(motion, 0.4))
				SkyArt.sun(self, Vector2(84.0, rise), 26.0, Rect2(clip.position, Vector2(clip.size.x, horizon - clip.position.y)), SkyArt.SUN_DAWN, motion)
				SkyArt.ground(self, rect.grow(-4.0), Color("#1b1233"))
			1:
				SkyArt.sun(self, center, 28.0, clip, SkyArt.SUN, motion)
			2:
				SkyArt.stars(self, clip, 14, motion * 4.0)
				SkyArt.moon(self, Vector2(84.0, size.y * 0.5 - 4.0), 28.0, clip)
		draw_rect(rect, Color("#fff6e0"), false, 4.0)
		draw_rect(rect.grow(-4.0), Color(0, 0, 0, 0.35), false, 2.0)
