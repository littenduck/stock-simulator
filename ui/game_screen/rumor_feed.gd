## Rumor feed, newest first: headline, direction, credibility (single number, or a range with the
## Fact Checker perk), Insider Friend marker and, once revealed, CONFIRMED or DEBUNKED.
class_name GameRumorFeed
extends PanelContainer

const MAX_ENTRIES := 40

var _list: VBoxContainer
var _empty: Label
var _entries: Array[Rumor] = []


@export var show_title: bool = true


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	if show_title:
		box.add_child(GameFmt.label(tr("UI_GAME_RUMORS"), GameColors.MUTED, 14))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "RumorList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_empty = GameFmt.label(tr("UI_GAME_NO_RUMORS"), GameColors.MUTED, 14)

	var s: GameSession = GameManager.session
	if s != null:
		for r in s.news.pending():
			_entries.append(r)
	EventBus.rumor_posted.connect(_on_rumor_posted)
	EventBus.rumor_resolved.connect(_on_rumor_resolved)
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.perks_changed.connect(_on_perks_changed)
	_refresh()


func _refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		if child != _empty:
			child.queue_free()
	if _entries.is_empty():
		_list.add_child(_empty)
		return
	for i in range(_entries.size() - 1, -1, -1):
		_list.add_child(_make_entry(_entries[i]))


func _make_entry(r: Rumor) -> Control:
	var s: GameSession = GameManager.session
	var impact: float = r.event.total_impact if r.event != null else 0.0
	var accent: Color = GameColors.for_change(impact)
	if r.resolved:
		accent = GameColors.UP if r.is_true else GameColors.DOWN
	if r.is_guaranteed and not r.resolved:
		accent = GameColors.GOLD

	var panel := PanelContainer.new()
	panel.set_meta("no_fx", true)
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.CARD
	style.border_color = accent
	style.border_width_left = 4
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	outer.add_child(CompanyBadge.make(_icon_for(r), 32))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	outer.add_child(box)

	var headline: String = tr(r.event.headline_key) if r.event != null else ""
	var target: String = r.target_symbol if r.target_symbol != "" else (r.event.target_sector.capitalize() if r.event != null and r.event.target_sector != "" else "")
	var title := GameFmt.label(("[%s] %s" % [target, headline]) if target != "" else headline, Color.WHITE, 14)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(title)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 10)
	box.add_child(meta)
	var mood := GameDelta.new(13)
	mood.show_icon(GameColors.icon_name(impact), tr("UI_GAME_BULLISH") if impact >= 0.0 else tr("UI_GAME_BEARISH"), GameColors.for_change(impact))
	meta.add_child(mood)
	if r.is_guaranteed:
		var tip := GameDelta.new(13)
		tip.show_icon("star", tr("UI_GAME_INSIDER"), GameColors.GOLD)
		tip.tooltip_text = tr("UI_GAME_INSIDER_TIP")
		tip.mouse_filter = Control.MOUSE_FILTER_STOP
		meta.add_child(tip)
	var status: Control
	if r.resolved:
		var verdict := GameDelta.new(13, true)
		verdict.show_icon("check" if r.is_true else "cross", tr("UI_GAME_CONFIRMED") if r.is_true else tr("UI_GAME_DEBUNKED"), GameColors.UP if r.is_true else GameColors.DOWN)
		status = verdict
	else:
		var left: int = maxi(r.reveal_day - (s.day if s != null else 0), 0)
		status = GameFmt.label(tr("UI_GAME_REVEALS_IN") % left, GameColors.MUTED, 13)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if status is Label:
		(status as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(status)

	var cred := _CredBar.new()
	var fact_checker: bool = s != null and s.mods.has_flag(&"fact_checker")
	cred.fact_checker = fact_checker
	cred.value = r.shown_credibility
	cred.low = r.credibility_low
	cred.high = r.credibility_high
	cred.tint = accent
	cred.custom_minimum_size = Vector2(0, 16)
	cred.tooltip_text = tr("UI_GAME_CRED_TIP_RANGE") if fact_checker else tr("UI_GAME_CRED_TIP")
	box.add_child(cred)
	return panel


## The event's own icon, else the target company's, else the generic one.
func _icon_for(r: Rumor) -> String:
	if r.event != null and r.event.icon != "":
		return r.event.icon
	var s: GameSession = GameManager.session
	if s != null and r.target_symbol != "":
		var c: CompanyDef = s.market.company_of(r.target_symbol)
		if c != null:
			return c.icon
	return ""


func _on_rumor_posted(rumor: Rumor) -> void:
	if rumor not in _entries:
		_entries.append(rumor)
		if _entries.size() > MAX_ENTRIES:
			_entries.remove_at(0)
	_refresh()


func _on_rumor_resolved(rumor: Rumor) -> void:
	if rumor not in _entries:
		_entries.append(rumor)
	_refresh()


func _on_day_advanced(_day: int) -> void:
	_refresh()


func _on_perks_changed() -> void:
	_refresh()


## Thin bar: the shown credibility as a fill, or the Fact Checker range as a band, with a % label.
class _CredBar extends Control:
	var value: float = 0.5
	var low: float = 0.0
	var high: float = 1.0
	var fact_checker: bool = false
	var tint: Color = Color.WHITE

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var label: String = ("%d–%d%%" % [roundi(low * 100.0), roundi(high * 100.0)]) if fact_checker else ("%d%%" % roundi(value * 100.0))
		var label_w: float = 66.0
		var bar := Rect2(0, size.y * 0.5 - 4, size.x - label_w, 8)
		draw_rect(bar, GameColors.TRACK)
		if fact_checker:
			var a: float = bar.position.x + bar.size.x * clampf(low, 0.0, 1.0)
			var b: float = bar.position.x + bar.size.x * clampf(high, 0.0, 1.0)
			draw_rect(Rect2(a, bar.position.y, maxf(b - a, 3.0), bar.size.y), tint)
		else:
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y)), tint)
		draw_string(font, Vector2(size.x - label_w + 8, size.y - 2), label, HORIZONTAL_ALIGNMENT_LEFT, label_w, 13, GameColors.MUTED)
