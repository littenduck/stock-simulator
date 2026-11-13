## A banner that sweeps across the screen whenever the turn moves to a new step: "PRE-MARKET", "MARKET OPEN",
## "AFTER-MARKET", "NEXT DAY", with a line about what happens now. It never blocks the mouse and is gone in a second.
class_name StepBanner
extends Control

const COLORS := [Color("#2f7fd6"), Color("#3fb950"), Color("#c77d0a"), Color("#8b5cc4")]
const HINT_KEYS := ["TABLE_BANNER_PRE", "TABLE_BANNER_OPEN", "TABLE_BANNER_AFTER", "TABLE_BANNER_NEXT"]
const SLIDE := 0.28
const HOLD := 0.75

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
	if step < 0 or step >= COLORS.size() or not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _banner != null:
		_banner.queue_free()
	var color: Color = COLORS[step]
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("no_fx", true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.45)
	sb.border_color = color.lightened(0.35)
	sb.set_border_width_all(4)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var tag := GameFmt.label("%s %d / 4" % [tr("TABLE_BANNER_STEP"), step + 1], color.lightened(0.5), 14)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	var title := GameFmt.label(tr(TurnBar.STEP_KEYS[step]).to_upper(), Color("#f4efe0"), 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := GameFmt.label(tr(HINT_KEYS[step]), Color(1, 1, 1, 0.8), 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	add_child(panel)
	_banner = panel
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.size = panel.get_combined_minimum_size()
	var rest := Vector2((size.x - panel.size.x) * 0.5, size.y * 0.14)
	panel.position = Vector2(-panel.size.x - 40.0, rest.y)
	panel.rotation = -0.03
	TableFx.sfx(&"slot_land")
	_tween = create_tween()
	_tween.tween_property(panel, "position:x", rest.x, SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(panel, "rotation", 0.0, SLIDE)
	_tween.tween_interval(HOLD)
	_tween.tween_property(panel, "position:x", size.x + 40.0, SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(panel.queue_free)
