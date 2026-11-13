## Small effects for the table screen: a rubber stamp that slams down, a screen flash, a jolt, a confetti burst.
## Everything is a tween or a one-shot particle node that frees itself; nothing here keeps state.
class_name TableFx
extends RefCounted

const PLANTED_COLOR := Color("#b57bee")


static func sfx(name: StringName) -> void:
	EventBus.sfx_requested.emit(name)


## A bordered, tilted stamp. Invisible until slam() is called, but it already takes its place in the layout.
static func make_stamp(text: String, color: Color, font_size: int = 30) -> PanelContainer:
	var stamp := PanelContainer.new()
	stamp.set_meta("no_fx", true)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.14)
	sb.border_color = color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	stamp.add_theme_stylebox_override("panel", sb)
	stamp.add_child(GameFmt.label(text, color, font_size))
	stamp.rotation = deg_to_rad(-6.0)
	stamp.modulate.a = 0.0
	return stamp


## After `delay` the stamp appears huge and drops to its size; `on_impact` runs the moment it lands.
static func slam(stamp: Control, delay: float, on_impact: Callable) -> void:
	var resting := stamp.rotation
	var tw := stamp.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		stamp.pivot_offset = stamp.size * 0.5
		stamp.scale = Vector2(5.4, 5.4)
		stamp.rotation = resting - 0.55)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(stamp, "rotation", resting, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(stamp, "modulate:a", 1.0, 0.08)
	tw.tween_callback(on_impact)
	# After the hit it bounces once.
	tw.tween_property(stamp, "scale", Vector2(1.14, 1.14), 0.06)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shakes a control that is not inside a container (the whole screen) and puts it back.
static func shake(c: Control, strength: float = 12.0, duration: float = 0.5) -> void:
	var base := c.position
	var tw := c.create_tween()
	tw.tween_method(func(t: float) -> void:
		var k := (1.0 - t) * strength
		c.position = base + Vector2(randf_range(-k, k), randf_range(-k, k)), 0.0, 1.0, duration)
	tw.tween_callback(func() -> void: c.position = base)


## Scale pop for a label or button: starts big (or small) and springs into place after `delay`.
static func pop(c: Control, from_scale: float, delay: float = 0.0) -> void:
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2(from_scale, from_scale))
	tw.tween_property(c, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The whole screen blinks a colour and fades back.
static func flash(root: Control, color: Color, strength: float = 0.3, duration: float = 0.45) -> void:
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, strength)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rect)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)


## A hit on the card: it swells for a moment and wobbles.
static func jolt(c: Control, strength: float = 1.05) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(strength, strength), 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var wobble := c.create_tween()
	var k := (strength - 1.0) * 0.9 + 0.02
	wobble.tween_property(c, "rotation", k, 0.05)
	wobble.tween_property(c, "rotation", -k * 0.8, 0.08)
	wobble.tween_property(c, "rotation", k * 0.4, 0.08)
	wobble.tween_property(c, "rotation", 0.0, 0.1)


## A burst of little coins and sparks from `origin` (in `root`'s coordinates). Frees itself when it is done.
static func confetti(root: Control, origin: Vector2, amount: int = 90, aim: float = 0.0) -> void:
	var p := CPUParticles2D.new()
	p.position = origin
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 1.6
	p.explosiveness = 0.96
	p.direction = Vector2(aim, -1).normalized()
	p.spread = 55.0
	p.initial_velocity_min = 320.0
	p.initial_velocity_max = 620.0
	p.gravity = Vector2(0, 640)
	p.angular_velocity_min = -280.0
	p.angular_velocity_max = 280.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 11.0
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.34, 0.67, 1.0])
	colors.colors = PackedColorArray([Color("#ffd23f"), Color("#3fb950"), Color("#4aa3ff"), Color("#ff7eb6")])
	p.color_initial_ramp = colors
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	root.add_child(p)
	p.finished.connect(p.queue_free)
