## Small shared UI animations: hover/press feedback for every button, counting numbers with a colour
## flash, staggered fade-in of a screen's children and the fade that covers a scene change.
## Nothing here changes game state.
class_name UiFx
extends RefCounted

const HOVER_SCALE := 1.04
const PRESS_SCALE := 0.95

static var _installed: bool = false


## Gives every Button of the tree (existing and future ones) hover/press feedback. Call once from a screen's _ready.
static func install(tree: SceneTree) -> void:
	if _installed or tree == null:
		return
	_installed = true
	tree.node_added.connect(_on_node_added)
	_walk(tree.root)


static func _walk(node: Node) -> void:
	if node is BaseButton:
		juice(node as BaseButton)
	for child in node.get_children():
		_walk(child)


static func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		juice(node as BaseButton)


## Hover = grow + brighten, press = squash. Read per event from meta so widgets can tune it:
## "fx_hover" (scale on hover), "fx_off" (true = skip).
static func juice(b: BaseButton) -> void:
	if b.has_meta("fx_on"):
		return
	b.set_meta("fx_on", true)
	b.mouse_entered.connect(_to_state.bind(b, 1))
	b.mouse_exited.connect(_to_state.bind(b, 0))
	b.button_down.connect(_to_state.bind(b, 2))
	b.button_up.connect(_on_button_up.bind(b))
	b.resized.connect(_update_pivot.bind(b))
	_update_pivot(b)


static func _update_pivot(b: Control) -> void:
	b.pivot_offset = b.size * 0.5


static func _on_button_up(b: BaseButton) -> void:
	_to_state(b, 1 if b.is_hovered() else 0)


static func _to_state(b: BaseButton, state: int) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or bool(b.get_meta("fx_off", false)):
		return
	if b.disabled and state != 0:
		return
	var hover: float = float(b.get_meta("fx_hover", HOVER_SCALE))
	var target_scale: float = 1.0
	var target_mod := Color.WHITE
	match state:
		1:
			target_scale = hover
			target_mod = Color(1.1, 1.1, 1.1)
		2:
			target_scale = PRESS_SCALE
			target_mod = Color(0.92, 0.92, 0.92)
	if b.has_meta("fx_tween"):
		var old: Tween = b.get_meta("fx_tween")
		if old != null and old.is_valid():
			old.kill()
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "scale", Vector2(target_scale, target_scale), 0.14 if state != 0 else 0.18).set_trans(Tween.TRANS_BACK if state == 1 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "self_modulate", target_mod, 0.12)
	b.set_meta("fx_tween", tw)


## Counts a label from its shown number to `to` (formatted with `fmt: Callable(float) -> String`) and flashes
## it green (up) or red (down). `base` is the resting colour (Color.WHITE = theme colour).
static func count_label(l: Label, to: float, fmt: Callable, base: Color = Color.WHITE, duration: float = 0.6) -> void:
	var animate: bool = l.is_inside_tree() and l.has_meta("fx_value")
	var from: float = float(l.get_meta("fx_shown", to)) if animate else to
	l.set_meta("fx_value", to)
	if l.has_meta("fx_tween"):
		var old: Tween = l.get_meta("fx_tween")
		if old != null and old.is_valid():
			old.kill()
	if not animate or is_equal_approx(from, to):
		l.set_meta("fx_shown", to)
		l.text = fmt.call(to)
		GameFmt.tint(l, base)
		return
	var flash: Color = GameColors.UP if to > from else GameColors.DOWN
	var tw := l.create_tween()
	tw.tween_method(func(v: float) -> void:
		l.set_meta("fx_shown", v)
		l.text = fmt.call(v), from, to, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	l.add_theme_color_override("font_color", flash)
	var fade := l.create_tween()
	fade.tween_interval(duration)
	fade.tween_method(func(t: float) -> void:
		var rest: Color = base if base != Color.WHITE else l.get_theme_color("font_color", "Label")
		l.add_theme_color_override("font_color", flash.lerp(rest, t)), 0.0, 1.0, 0.5)
	fade.tween_callback(func() -> void: GameFmt.tint(l, base))
	tw.finished.connect(func() -> void:
		l.set_meta("fx_shown", to)
		l.text = fmt.call(to))
	l.set_meta("fx_tween", tw)


## Fades and slides the direct children of `parent` in one after another.
static func stagger_in(parent: Node, step: float = 0.07, rise: float = 14.0, first_delay: float = 0.05) -> void:
	var i: int = 0
	for child in parent.get_children():
		if not (child is Control):
			continue
		var c := child as Control
		if not c.visible:
			continue
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(first_delay + step * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.28)
		var shift := c.create_tween()
		shift.tween_interval(first_delay + step * i)
		var base: Vector2 = c.position
		if parent is Container:
			# Containers own the position: use a transform offset instead.
			c.pivot_offset = c.size * 0.5
			c.scale = Vector2(0.94, 0.94)
			shift.tween_property(c, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			c.position = base + Vector2(0, rise)
			shift.tween_property(c, "position", base, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1


## Bouncing drop-in for a title: starts above and squashes into place.
static func bounce_in(c: Control, delay: float = 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(0.6, 0.6)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.55).set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static var _changing: bool = false
static var _pending_path: String = ""


## Fades the screen to the backdrop colour, switches scene, then fades the new scene in. Await it when code
## must run after the new scene exists. Skips the fade in headless runs (tests) and queues a different scene
## requested while one change is under way.
static func change_scene(tree: SceneTree, path: String, fade_out: float = 0.18) -> void:
	if tree == null or (_changing and path == _pending_path):
		return  # a double click must not load the scene twice
	while _changing:
		await tree.process_frame
	_changing = true
	_pending_path = path
	var cover: CanvasLayer = null
	if DisplayServer.get_name() != "headless" and tree.root != null:
		cover = CanvasLayer.new()
		cover.layer = 99
		var rect := ColorRect.new()
		rect.color = Color("#1d1630")
		rect.color.a = 0.0
		rect.mouse_filter = Control.MOUSE_FILTER_STOP  # no clicks while the old scene leaves
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		cover.add_child(rect)
		tree.root.add_child(cover)
		var tw := rect.create_tween()
		tw.tween_property(rect, "color:a", 1.0, fade_out).set_trans(Tween.TRANS_QUAD)
		await tw.finished
	tree.change_scene_to_file(path)
	fade_from_black(tree)
	if cover != null:
		cover.queue_free()
	_changing = false


## Covers the freshly loaded scene with a solid layer that fades out. Call right after changing scene.
static func fade_from_black(tree: SceneTree, duration: float = 0.35) -> void:
	if tree == null or tree.root == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.color = Color("#1d1630")
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	tree.root.add_child(layer)
	var tw := rect.create_tween()
	tw.tween_interval(0.04)
	tw.tween_property(rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(layer.queue_free)
