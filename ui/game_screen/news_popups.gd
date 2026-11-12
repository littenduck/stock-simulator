## News pop-ups: a card pops in when a rumor is posted (headline, Bullish/Bearish tag, resolves-in-N-days)
## and a stamped card when one resolves (CONFIRMED / DEBUNKED). Cards stack at the top of the chart area,
## auto-dismiss after a few seconds (or on click), queue when there are many, and never block the order
## panel, the Next Day button or the keyboard: only the cards themselves take the mouse.
class_name GameNewsPopups
extends Control

enum Kind { POSTED, RESOLVED }

const MAX_VISIBLE := 2
const CARD_SIZE := Vector2(404, 108)
const GAP := 8.0
const LIFETIME := 4.2
const TOP := 206.0
## Fallback gap between the cards and the right screen edge (the order panel column) if it cannot be found.
const RIGHT_RESERVED := 432.0

const BULL := Color("#47d36f")
const BEAR := Color("#ff6b63")
const BASE := Color("#2a2147")

var _queue: Array[Dictionary] = []
var _active: Array[Control] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	EventBus.rumor_posted.connect(_on_rumor_posted)
	EventBus.rumor_resolved.connect(_on_rumor_resolved)
	resized.connect(_relayout.bind(false))


func popup_count() -> int:
	return _active.size()


func queued_count() -> int:
	return _queue.size()


## Adds a pop-up to the queue (dev shots and tests call this directly).
func enqueue(kind: Kind, rumor: Rumor, session: GameSession = null) -> void:
	_queue.append({"kind": kind, "rumor": rumor, "session": session})
	_pump()


func clear_all() -> void:
	_queue.clear()
	for c in _active.duplicate():
		c.queue_free()
	_active.clear()


func _on_rumor_posted(rumor: Rumor) -> void:
	var s: GameSession = GameManager.session
	# Only news of today: the game scene re-announces older pending rumors when a saved run is loaded.
	if s != null and rumor.posted_day < s.day:
		return
	enqueue(Kind.POSTED, rumor, s)


func _on_rumor_resolved(rumor: Rumor) -> void:
	enqueue(Kind.RESOLVED, rumor, GameManager.session)


func _pump() -> void:
	while _active.size() < MAX_VISIBLE and not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		_show(item)


func _show(item: Dictionary) -> void:
	var rumor: Rumor = item["rumor"]
	var card := _Popup.new()
	card.kind = item["kind"]
	card.rumor = rumor
	card.session = item["session"]
	# A long backlog shortens the stay so the news never runs far behind the game.
	card.lifetime = LIFETIME if _queue.size() < 2 else 2.6
	card.closed.connect(_on_closed.bind(card))
	card.size = CARD_SIZE
	add_child(card)
	_active.append(card)
	card.position = _slot_position(_active.size() - 1) + Vector2(70, -10)
	_relayout(true)
	card.play_in()


func _on_closed(card: Control) -> void:
	_active.erase(card)
	card.queue_free()
	_relayout(true)
	_pump()


## Left edge of the order panel column: the cards stay to its left so Buy/Sell and Next Day are never covered.
func _right_limit() -> float:
	var panel: Control = owner.find_child("OrderPanel", true, false) as Control if owner != null else null
	if panel != null and panel.is_inside_tree() and panel.size.x > 0.0:
		return panel.global_position.x - 10.0
	return size.x - RIGHT_RESERVED


func _slot_position(i: int) -> Vector2:
	return Vector2(maxf(_right_limit() - CARD_SIZE.x, 8.0), TOP + i * (CARD_SIZE.y + GAP))


func _relayout(animated: bool) -> void:
	for i in _active.size():
		var card := _active[i]
		var target: Vector2 = _slot_position(i)
		if animated and card.is_inside_tree() and card.get("arrived"):
			var tw := card.create_tween()
			tw.tween_property(card, "position", target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		elif not animated:
			card.position = target
		else:
			card.set("slot_target", target)


## One pop-up card.
class _Popup extends Control:
	signal closed

	var kind: Kind = Kind.POSTED
	var rumor: Rumor
	var session: GameSession
	var lifetime: float = LIFETIME
	var arrived: bool = false
	var slot_target: Vector2 = Vector2.ZERO
	var _age: float = 0.0
	var _hovered: bool = false
	var _closing: bool = false
	var _accent: Color = BULL
	var _stamp: Control
	var _bar: Control

	func _ready() -> void:
		set_meta("no_fx", true)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pivot_offset = CARD_SIZE * 0.5
		mouse_entered.connect(func() -> void: _hovered = true)
		mouse_exited.connect(func() -> void: _hovered = false)
		_build()
		modulate.a = 0.0

	func _impact() -> float:
		return rumor.event.total_impact if rumor.event != null else 0.0

	func _build() -> void:
		var resolved: bool = kind == Kind.RESOLVED
		var bullish: bool = _impact() >= 0.0
		_accent = BULL if bullish else BEAR
		if resolved:
			_accent = BULL if rumor.is_true else BEAR
		var style := StyleBoxFlat.new()
		style.bg_color = BASE.lerp(_accent, 0.2)
		style.border_color = _accent
		style.set_border_width_all(3)
		style.border_width_left = 8
		style.set_corner_radius_all(10)
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = 12
		style.shadow_offset = Vector2(0, 5)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 10
		var panel := PanelContainer.new()
		panel.set_meta("no_fx", true)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)

		var outer := HBoxContainer.new()
		outer.add_theme_constant_override("separation", 12)
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(outer)
		var badge := CompanyBadge.make(_icon_name(), 58)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		outer.add_child(badge)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(col)

		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(top)
		var caption := _label(tr("UI_NEWS_POPUP_RESOLVED") if resolved else tr("UI_NEWS_POPUP_RUMOR"), 11, Color(1, 1, 1, 0.6))
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(caption)
		if rumor.is_guaranteed and not resolved:
			var tip := _label(tr("UI_NEWS_POPUP_INSIDER"), 11, Color("#ffd23f"))
			top.add_child(tip)
		top.add_child(_tag(bullish))

		var headline := _label(_headline(), 14, Color.WHITE)
		headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		headline.max_lines_visible = 2
		headline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		headline.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(headline)

		var bottom := HBoxContainer.new()
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(bottom)
		if resolved:
			var sub := _label(tr("UI_NEWS_POPUP_TRUE") if rumor.is_true else tr("UI_NEWS_POPUP_FALSE"), 12, Color(1, 1, 1, 0.75))
			sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bottom.add_child(sub)
		else:
			var left: int = maxi(rumor.reveal_day - (session.day if session != null else rumor.posted_day), 0)
			var when := _label(tr("UI_GAME_REVEALS_IN") % left, 12, Color(1, 1, 1, 0.8))
			when.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bottom.add_child(when)
			bottom.add_child(_label("%d%%" % roundi(rumor.shown_credibility * 100.0), 12, Color(1, 1, 1, 0.6)))

		# Time left bar along the bottom edge.
		_bar = Control.new()
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.draw.connect(_draw_bar)
		add_child(_bar)
		_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_bar.offset_top = -7.0
		_bar.offset_left = 14.0
		_bar.offset_right = -12.0
		_bar.offset_bottom = -4.0

		if resolved:
			_stamp = _make_stamp()
			add_child(_stamp)

	func _draw_bar() -> void:
		var frac: float = clampf(1.0 - _age / lifetime, 0.0, 1.0)
		_bar.draw_rect(Rect2(Vector2.ZERO, _bar.size), Color(0, 0, 0, 0.25))
		_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(_bar.size.x * frac, _bar.size.y)), Color(_accent.r, _accent.g, _accent.b, 0.85))

	func _make_stamp() -> Control:
		var stamp := PanelContainer.new()
		stamp.set_meta("no_fx", true)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = BASE.darkened(0.25)
		sb.border_color = _accent
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		stamp.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamp.add_child(row)
		var icon := TextureRect.new()
		icon.texture = GameIcons.tex("check" if rumor.is_true else "cross")
		icon.modulate = _accent
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row.add_child(_label((tr("UI_GAME_CONFIRMED") if rumor.is_true else tr("UI_GAME_DEBUNKED")).to_upper(), 18, _accent))
		stamp.rotation = -0.12
		stamp.modulate.a = 0.0
		return stamp

	func _tag(bullish: bool) -> Control:
		var tag := PanelContainer.new()
		tag.set_meta("no_fx", true)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = BULL if bullish else BEAR
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.22)
		sb.border_color = col
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 6
		sb.content_margin_right = 7
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		tag.add_theme_stylebox_override("panel", sb)
		var d := GameDelta.new(12)
		d.show_icon("up" if bullish else "down", tr("UI_GAME_BULLISH") if bullish else tr("UI_GAME_BEARISH"), col)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(d)
		return tag

	static func _label(text: String, font_size: int, color: Color) -> Label:
		var l := Label.new()
		l.text = text
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", color)
		return l

	func _headline() -> String:
		var headline: String = tr(rumor.event.headline_key) if rumor.event != null else ""
		var target: String = rumor.target_symbol
		if target == "" and rumor.event != null and rumor.event.target_sector != "":
			target = rumor.event.target_sector.capitalize()
		return ("[%s] %s" % [target, headline]) if target != "" else headline

	func _icon_name() -> String:
		if rumor.event != null and rumor.event.icon != "":
			return rumor.event.icon
		if session != null and rumor.target_symbol != "":
			var c: CompanyDef = session.market.company_of(rumor.target_symbol)
			if c != null:
				return c.icon
		return ""

	## Slide in from the right with an overshoot, then a short wobble (resolved: the stamp slams down).
	func play_in() -> void:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var target: Vector2 = slot_target if slot_target != Vector2.ZERO else position
		scale = Vector2(0.85, 0.85)
		rotation = 0.05
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.16)
		tw.tween_property(self, "position", target, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var wobble := create_tween()
		wobble.tween_property(self, "rotation", -0.035, 0.14).set_trans(Tween.TRANS_SINE)
		wobble.tween_property(self, "rotation", 0.02, 0.12).set_trans(Tween.TRANS_SINE)
		wobble.tween_property(self, "rotation", -0.008, 0.1).set_trans(Tween.TRANS_SINE)
		wobble.tween_property(self, "rotation", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
		wobble.tween_callback(func() -> void: arrived = true)
		if _stamp != null:
			_stamp.reset_size()
			_stamp.position = Vector2(CARD_SIZE.x - _stamp.size.x - 14, CARD_SIZE.y - _stamp.size.y - 2)
			_stamp.pivot_offset = _stamp.size * 0.5
			_stamp.scale = Vector2(3.2, 3.2)
			_stamp.modulate.a = 0.0
			var st := create_tween()
			st.tween_interval(0.42)
			st.tween_property(_stamp, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			st.parallel().tween_property(_stamp, "modulate:a", 1.0, 0.12)
			st.tween_callback(_stamp_impact)

	## The stamp lands: the whole card jolts.
	func _stamp_impact() -> void:
		if not is_inside_tree():
			return
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.04, 1.04), 0.05)
		tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		if _closing or modulate.a < 0.5:
			return
		if not _hovered:
			_age += delta
		_bar.queue_redraw()
		if _age >= lifetime:
			dismiss()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			dismiss()

	func dismiss() -> void:
		if _closing:
			return
		_closing = true
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.tween_property(self, "position:x", position.x + 50.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func() -> void: closed.emit())
