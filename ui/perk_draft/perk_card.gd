## One perk card of the draft pop-up. The look depends on the rarity:
##   common    plain cream card, grey frame
##   rare      blue frame, soft pulsing glow, a small shimmer sweeping over it
##   legendary gold double frame, strong glow, a bright shine sweep and twinkling sparkles
## Every animated value is a plain property (appear, hover, chosen, dim, burst) so the dialog can tween it.
## Contains no autoload access: it only needs a PerkDef and the node tree.
class_name PerkCard
extends Button

const CARD_SIZE := Vector2(236, 268)

var perk: PerkDef
var index: int = 0
## False while the dialog is still flying the cards in (hover and clicks do nothing).
var interactive: bool = false

## 0 = off screen below, 1 = in place.
var appear: float = 1.0:
	set(value):
		appear = value
		_apply_transform()
## Selection: the chosen card grows, the others fade (dim).
var chosen: float = 0.0:
	set(value):
		chosen = value
		_apply_transform()
var dim: float = 0.0:
	set(value):
		dim = value
		_apply_transform()
## 0..1 expanding ring when the card is picked.
var burst: float = 0.0:
	set(value):
		burst = value
		if _fx != null:
			_fx.queue_redraw()

var _hover: float = 0.0
var _hover_target: float = 0.0
var _tilt: float = 0.0
var _tilt_target: float = 0.0
var _time: float = 0.0
var _fly_side: float = 1.0
var _sparkles: Array[Dictionary] = []
var _fx: Control
var _badge: CompanyBadge


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	clip_text = false
	flat = true
	set_meta("fx_off", true)  # UiFx must not scale this card as well
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_on_resized)


## Builds the content. Call before adding to the tree.
func setup(p_perk: PerkDef, p_index: int, title_text: String, desc_text: String, rarity_text: String) -> void:
	perk = p_perk
	index = p_index
	_fly_side = -1.0 if p_index % 2 == 0 else 1.0
	var rarity: int = perk.rarity
	var accent: Color = _accent(rarity)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	# Rarity ribbon.
	var ribbon_row := HBoxContainer.new()
	ribbon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ribbon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ribbon_row)
	var ribbon := PanelContainer.new()
	ribbon.set_meta("no_fx", true)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = accent
	rs.set_corner_radius_all(4)
	rs.content_margin_left = 12
	rs.content_margin_right = 12
	rs.content_margin_top = 2
	rs.content_margin_bottom = 2
	rs.border_color = accent.darkened(0.35)
	rs.border_width_bottom = 2
	ribbon.add_theme_stylebox_override("panel", rs)
	var rl := Label.new()
	rl.text = rarity_text.to_upper()
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rl.add_theme_font_size_override("font_size", 13)
	rl.add_theme_color_override("font_color", Color.WHITE)
	rl.add_theme_color_override("font_outline_color", accent.darkened(0.5))
	rl.add_theme_constant_override("outline_size", 3)
	ribbon.add_child(rl)
	ribbon_row.add_child(ribbon)

	var badge_row := CenterContainer.new()
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge_row)
	_badge = CompanyBadge.make(PixelIcons.perk_icon(String(perk.id)), 72)
	badge_row.add_child(_badge)

	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UiPalette.INK)
	box.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(accent.r, accent.g, accent.b, 0.55)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)

	var desc := Label.new()
	desc.text = desc_text
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.max_lines_visible = 4
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", UiPalette.INK_MUTED)
	box.add_child(desc)

	# Key hint chip in the top-left corner.
	var key := Label.new()
	key.text = str(index + 1)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.position = Vector2(10, 6)
	key.add_theme_font_size_override("font_size", 14)
	key.add_theme_color_override("font_color", accent.darkened(0.2))
	add_child(key)

	_fx = _FxLayer.new()
	_fx.card = self
	add_child(_fx)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + index * 77 + rarity
	var count: int = 7 if rarity == PerkDef.Rarity.LEGENDARY else (3 if rarity == PerkDef.Rarity.RARE else 0)
	for i in count:
		_sparkles.append({
			"pos": Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.06, 0.94)),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.6, 3.2),
			"size": rng.randf_range(5.0, 9.0) if rarity == PerkDef.Rarity.LEGENDARY else rng.randf_range(3.0, 5.0),
		})
	_time = rng.randf() * 3.0
	set_process(true)
	_apply_transform()


static func _accent(rarity: int) -> Color:
	match rarity:
		PerkDef.Rarity.RARE:
			return Color("#2f7fd6")
		PerkDef.Rarity.LEGENDARY:
			return Color("#e0a000")
		_:
			return Color("#8d8a94")


func _ready() -> void:
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size * 0.5


func _process(delta: float) -> void:
	_time += delta
	_hover = move_toward(_hover, _hover_target, delta * 7.0)
	_tilt = lerpf(_tilt, _tilt_target, minf(delta * 10.0, 1.0))
	_apply_transform()
	queue_redraw()
	_fx.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _hover_target > 0.0 and size.x > 0.0:
		var m := event as InputEventMouseMotion
		# Tilt towards the pointer: right of centre leans right.
		_tilt_target = clampf((m.position.x / size.x - 0.5) * 0.07, -0.04, 0.04)


func _on_mouse_entered() -> void:
	if interactive and chosen == 0.0:
		_hover_target = 1.0


func _on_mouse_exited() -> void:
	_hover_target = 0.0
	_tilt_target = 0.0


## Keyboard focus counts as hover (same lift).
func set_focus_lift(on: bool) -> void:
	if on and interactive and chosen == 0.0:
		_hover_target = 1.0
	elif not on and not is_hovered():
		_hover_target = 0.0


func _apply_transform() -> void:
	if perk == null:
		return
	var land: float = clampf(appear, 0.0, 1.0)
	var lift: float = _hover * 14.0 + chosen * 18.0
	position = Vector2(0.0, (1.0 - appear) * 260.0 - lift)
	rotation = (1.0 - appear) * 0.22 * _fly_side + _tilt * (1.0 - chosen)
	var s: float = (0.82 + 0.18 * appear) * (1.0 + 0.05 * _hover) * (1.0 + 0.16 * chosen) * (1.0 - 0.18 * dim)
	scale = Vector2(s, s)
	modulate.a = clampf(land * 1.8, 0.0, 1.0) * (1.0 - dim)
	z_index = 5 if (chosen > 0.0 or _hover > 0.0) else 0


func _draw() -> void:
	var rarity: int = perk.rarity if perk != null else PerkDef.Rarity.COMMON
	var accent: Color = _accent(rarity)
	var rect := Rect2(Vector2.ZERO, size)
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.2)
	var glow_boost: float = 1.0 + _hover * 0.9 + chosen * 1.2
	var body := StyleBoxFlat.new()
	body.set_corner_radius_all(12)
	match rarity:
		PerkDef.Rarity.LEGENDARY:
			body.bg_color = Color("#fff1c4")
			body.set_border_width_all(5)
			body.border_color = Color("#e0a000")
			body.shadow_color = Color(1.0, 0.72, 0.1, (0.30 + 0.22 * pulse) * glow_boost)
			body.shadow_size = int(20 + 10 * pulse)
		PerkDef.Rarity.RARE:
			body.bg_color = Color("#e9f2fc")
			body.set_border_width_all(4)
			body.border_color = Color("#2f7fd6")
			body.shadow_color = Color(0.2, 0.5, 0.95, (0.22 + 0.14 * pulse) * glow_boost)
			body.shadow_size = int(14 + 6 * pulse)
		_:
			body.bg_color = Color("#f6edd9")
			body.set_border_width_all(3)
			body.border_color = Color("#8d8a94")
			body.shadow_color = Color(0, 0, 0, 0.25 + 0.1 * _hover)
			body.shadow_size = 8
			body.shadow_offset = Vector2(0, 4)
	draw_style_box(body, rect)
	# Soft top sheen on every card.
	var sheen := PackedColorArray([Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	var inset: float = body.border_width_left + 1.0
	draw_polygon(PackedVector2Array([Vector2(inset, inset), Vector2(size.x - inset, inset), Vector2(size.x - inset, size.y * 0.35), Vector2(inset, size.y * 0.35)]), sheen)
	if rarity == PerkDef.Rarity.LEGENDARY:
		# Inner thin line gives the double frame.
		var inner := StyleBoxFlat.new()
		inner.draw_center = false
		inner.set_border_width_all(2)
		inner.border_color = Color(1.0, 0.86, 0.35, 0.9)
		inner.set_corner_radius_all(8)
		draw_style_box(inner, rect.grow(-8.0))
	if has_focus():
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(3)
		ring.border_color = UiPalette.ACCENT
		ring.set_corner_radius_all(14)
		draw_style_box(ring, rect.grow(5.0))


## Shine sweep, sparkles and the pick burst, drawn above the card's contents.
class _FxLayer extends Control:
	var card: PerkCard

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if card == null or card.perk == null:
			return
		var rarity: int = card.perk.rarity
		var t: float = card._time
		if rarity == PerkDef.Rarity.LEGENDARY:
			_sweep(fposmod(t / 2.4, 1.0), 46.0, 0.55, Color(1.0, 0.98, 0.85))
		elif rarity == PerkDef.Rarity.RARE:
			_sweep(fposmod(t / 3.8, 1.0), 26.0, 0.30, Color(0.85, 0.94, 1.0))
		for sp: Dictionary in card._sparkles:
			var k: float = sin(t * float(sp["speed"]) + float(sp["phase"]))
			if k <= 0.2:
				continue
			var a: float = (k - 0.2) / 0.8
			var p: Vector2 = (sp["pos"] as Vector2) * size
			var r: float = float(sp["size"]) * (0.5 + 0.5 * a) * (1.0 + card._hover * 0.5)
			var col: Color = Color(1.0, 0.95, 0.6, a) if rarity == PerkDef.Rarity.LEGENDARY else Color(0.8, 0.92, 1.0, a * 0.9)
			_star(p, r, col)
		if card.burst > 0.0 and card.burst < 1.0:
			var b: float = card.burst
			var ring_col: Color = PerkCard._accent(rarity).lightened(0.3)
			ring_col.a = (1.0 - b) * 0.9
			draw_arc(size * 0.5, lerpf(40.0, size.x * 0.9, b), 0.0, TAU, 48, ring_col, 4.0 * (1.0 - b) + 1.0)
			for i in 8:
				var ang: float = TAU * i / 8.0 + 0.4
				var from: Vector2 = size * 0.5 + Vector2(cos(ang), sin(ang)) * lerpf(30.0, size.x * 0.55, b)
				var to: Vector2 = from + Vector2(cos(ang), sin(ang)) * 16.0 * (1.0 - b)
				draw_line(from, to, Color(1, 0.95, 0.7, 1.0 - b), 3.0)

	## Diagonal bright band travelling left to right, clipped to the card.
	func _sweep(phase: float, width: float, strength: float, col: Color) -> void:
		# Rest between sweeps: the band only runs during the first 55 % of the cycle.
		var run: float = phase / 0.55
		if run > 1.0:
			return
		var x: float = lerpf(-width * 2.0, size.x + width * 2.0, run)
		var skew: float = size.y * 0.45
		var band := PackedVector2Array([Vector2(x, 0), Vector2(x + width, 0), Vector2(x + width - skew, size.y), Vector2(x - skew, size.y)])
		var clip := PackedVector2Array([Vector2(4, 4), Vector2(size.x - 4, 4), Vector2(size.x - 4, size.y - 4), Vector2(4, size.y - 4)])
		var parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(band, clip)
		for poly in parts:
			if poly.size() >= 3:
				draw_colored_polygon(poly, Color(col.r, col.g, col.b, strength * sin(run * PI)))

	func _star(p: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array([
			p + Vector2(0, -r), p + Vector2(r * 0.22, -r * 0.22), p + Vector2(r, 0), p + Vector2(r * 0.22, r * 0.22),
			p + Vector2(0, r), p + Vector2(-r * 0.22, r * 0.22), p + Vector2(-r, 0), p + Vector2(-r * 0.22, -r * 0.22),
		])
		draw_colored_polygon(pts, col)
