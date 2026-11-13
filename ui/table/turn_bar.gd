## The bar at the bottom: where the turn is (four steps as dots), the only button that moves the turn (Next, green,
## active only in "Market open"), a warning when you have not chosen yet, and what your character's skill is doing.
class_name TurnBar
extends PanelContainer

enum Step { PRE, OPEN, AFTER, NEXT }

const STEP_KEYS := ["TABLE_STEP_PRE", "TABLE_STEP_OPEN", "TABLE_STEP_AFTER", "TABLE_STEP_NEXT"]
const WAIT_KEYS := ["TABLE_WAIT_PRE", "", "TABLE_WAIT_AFTER", "TABLE_WAIT_NEXT"]
const SIDE_WIDTH := 270.0
const INK := Color("#2b2540")
const DONE_GREEN := Color("#3fb950")
const NOW_GOLD := Color("#e3b341")

var step: int = Step.PRE
var _left: VBoxContainer
var _dots: HBoxContainer
var _warn: Label
var _next: Button


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	_left = VBoxContainer.new()
	_left.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left.add_theme_constant_override("separation", 0)
	row.add_child(_left)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 3)
	row.add_child(center)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 0)
	center.add_child(_dots)
	var action := HBoxContainer.new()
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	action.add_theme_constant_override("separation", 12)
	center.add_child(action)
	_warn = GameFmt.label(tr("TABLE_NO_CALL_WARN"), Color("#c77d0a"), 13)
	action.add_child(_warn)
	_next = GameFmt.button(tr("TABLE_NEXT"))
	_next.theme_type_variation = &"PrimaryButton"
	_next.custom_minimum_size = Vector2(190, 38)
	_next.add_theme_font_size_override("font_size", 17)
	_next.icon = TableUi.arrow_right()
	_next.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next.expand_icon = false
	_next.tooltip_text = tr("TABLE_NEXT_TIP")
	_next.pressed.connect(func() -> void: GameManager.next_day())
	action.add_child(_next)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	row.add_child(spacer)
	EventBus.table_step.connect(_on_step)
	EventBus.table_revealed.connect(func(_e: Array) -> void: _on_step(Step.AFTER))
	EventBus.table_resolved.connect(func(_r: TableReport) -> void: _on_step(Step.NEXT))
	EventBus.table_changed.connect(_refresh)
	EventBus.day_advanced.connect(func(_d: int) -> void: _refresh())
	_refresh()


func _on_step(new_step: int) -> void:
	step = new_step
	_refresh()


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _dots == null:
		return
	_build_dots()
	var can_act := step == Step.OPEN and t.phase == TableSession.Phase.ACTION and t.human().alive and not t.is_finished()
	_next.disabled = not can_act
	var waiting := not (can_act or step == Step.OPEN)
	_next.text = tr(WAIT_KEYS[step]) if waiting else tr("TABLE_NEXT")
	_next.icon = null if waiting else TableUi.arrow_right()
	_warn.visible = can_act and not t.calls.has(0) and not t.copy_targets.has(0)
	_build_skill(t)


func _build_dots() -> void:
	for child in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	for i in STEP_KEYS.size():
		if i > 0:
			_dots.add_child(_line(i <= step))
		_dots.add_child(_dot(i))


func _line(done: bool) -> Control:
	var line := ColorRect.new()
	line.color = DONE_GREEN if done else Color("#8d8a94")
	line.custom_minimum_size = Vector2(46, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _dot(i: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := ColorRect.new()
	var size := 16.0 if i == step else 11.0
	mark.custom_minimum_size = Vector2(size, size)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if i < step:
		mark.color = DONE_GREEN
	elif i == step:
		mark.color = NOW_GOLD
	else:
		mark.color = Color("#bdb8a8")
	box.add_child(mark)
	var label := GameFmt.label("%d  %s" % [i + 1, tr(STEP_KEYS[i])], INK if i <= step else Color("#8d8a94"), 15 if i == step else 13)
	box.add_child(label)
	return box


## What the character's skill is doing today (the old skill bar, now at the left of this one).
func _build_skill(t: TableSession) -> void:
	for child in _left.get_children():
		_left.remove_child(child)
		child.queue_free()
	var seat := t.human()
	var open := step == Step.OPEN and t.phase == TableSession.Phase.ACTION and seat.alive and not t.is_finished()
	_left.add_child(GameFmt.label(TableUi.seat_name(seat, self), GameColors.GOLD, 14))
	var text := ""
	if seat.has_flag(&"copilot"):
		var target := int(t.copy_targets.get(0, -1))
		text = tr("TABLE_COPILOT_ON") % TableUi.seat_name(t.seats[target], self) if target >= 0 else tr("TABLE_COPILOT_OFF")
	elif seat.has_flag(&"insider"):
		var hint := t.insider_hint()
		if hint != null:
			text = tr("TABLE_INSIDER_HINT") + ": " + hint.headline(tr, t.market)
		else:
			text = tr("TABLE_FLIP_USED") if seat.skill_used else tr("TABLE_NO_HINT")
	elif seat.has_flag(&"double_down"):
		text = tr("TABLE_DAN_USED") if seat.skill_used else tr("TABLE_DAN_HINT")
	else:
		text = tr("CHAR_%s_PASSIVE" % String(seat.character.id).to_upper())
	var label := TableUi.wrapped(text, Color("#5d5870"), 12)
	label.custom_minimum_size = Vector2(SIDE_WIDTH - 10.0, 0)
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	_left.add_child(label)
	if seat.has_flag(&"insider") and t.insider_hint() != null:
		var flip := CheckButton.new()
		flip.text = tr("TABLE_FLIP")
		flip.focus_mode = Control.FOCUS_NONE
		flip.disabled = not open
		flip.button_pressed = bool(t.flip_armed.get(0, false))
		flip.toggled.connect(func(on: bool) -> void:
			t.arm_flip(on)
			GameManager.table_refresh())
		_left.add_child(flip)


## Space is the shortcut for Next, but only when the button can be pressed and no pop-up is in front.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_day") and _next != null and not _next.disabled and _next.visible and not TableUi.modal_open:
		get_viewport().set_input_as_handled()
		_next.pressed.emit()
