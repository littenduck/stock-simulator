## The thin bar at the bottom, one row: what your character's skill is doing (left), where the turn is (four steps as
## dots), a warning when you have not chosen yet, and Next, the only button that moves the turn.
## Next works in three steps: pre-market (opens the market once the news has landed), market open (reveals the bets)
## and after-market (lets the day turn over). Space is its shortcut.
class_name TurnBar
extends PanelContainer

enum Step { PRE, OPEN, AFTER, NEXT }

const STEP_KEYS := ["TABLE_STEP_PRE", "TABLE_STEP_OPEN", "TABLE_STEP_AFTER", "TABLE_STEP_NEXT"]
const WAIT_KEYS := ["TABLE_WAIT_PRE", "", "", "TABLE_WAIT_NEXT"]
const SIDE_WIDTH := 250.0
const INK := Color("#2b2540")
const DONE_GREEN := Color("#3fb950")
const NOW_GOLD := Color("#e3b341")

var step: int = Step.PRE
## The show of this step is over, so Next may be pressed.
var _ready_next: bool = false
var _left: VBoxContainer
var _dots: HBoxContainer
var _warn: Label
var _next: Button


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 2)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	_left = VBoxContainer.new()
	_left.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left.add_theme_constant_override("separation", 0)
	row.add_child(_left)
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	row.add_child(center)
	_dots = HBoxContainer.new()
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots.add_theme_constant_override("separation", 0)
	center.add_child(_dots)
	_warn = GameFmt.label(tr("TABLE_NO_CALL_WARN"), Color("#c77d0a"), 13)
	_warn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_warn)
	_next = GameFmt.button(tr("TABLE_NEXT"))
	_next.theme_type_variation = &"PrimaryButton"
	_next.custom_minimum_size = Vector2(170, 36)
	_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next.add_theme_font_size_override("font_size", 17)
	_next.icon = TableUi.arrow_right()
	_next.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next.expand_icon = false
	_next.tooltip_text = tr("TABLE_NEXT_TIP")
	_next.pressed.connect(_on_next_pressed)
	center.add_child(_next)
	EventBus.table_step.connect(_on_step)
	EventBus.table_step_ready.connect(_on_ready)
	EventBus.table_revealed.connect(func(_e: Array) -> void: _on_step(Step.AFTER))
	EventBus.table_resolved.connect(func(_r: TableReport) -> void: _on_step(Step.NEXT))
	EventBus.table_changed.connect(_refresh)
	EventBus.day_advanced.connect(func(_d: int) -> void: _refresh())
	_refresh()


func _on_step(new_step: int) -> void:
	step = new_step
	TableUi.current_step = new_step
	# Market open and after-market wait for the player at once; pre-market waits for its news to land.
	_ready_next = new_step == Step.OPEN or new_step == Step.AFTER
	_refresh()
	EventBus.table_changed.emit()    # the trade window, the feed and the card re-check whether they may be used


func _on_ready(ready_step: int) -> void:
	if ready_step == step:
		_ready_next = true
		_refresh()


## Next moves the turn one step on: 1 to 2 only changes the screen, 2 reveals the bets, 3 lets the day turn over.
func _on_next_pressed() -> void:
	match step:
		Step.PRE:
			_on_step(Step.OPEN)
		Step.OPEN, Step.AFTER:
			GameManager.next_day()


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _dots == null:
		return
	_build_dots()
	var alive := t.human().alive and not t.is_finished()
	var can_press := _ready_next and alive and step != Step.NEXT
	if step == Step.OPEN:
		can_press = can_press and t.phase == TableSession.Phase.ACTION
	elif step == Step.AFTER:
		can_press = can_press and t.phase == TableSession.Phase.REVEALED
	_next.disabled = not can_press
	_next.text = tr("TABLE_NEXT") if can_press else tr(WAIT_KEYS[step] if WAIT_KEYS[step] != "" else "TABLE_NEXT")
	_next.icon = TableUi.arrow_right() if can_press else null
	_warn.visible = can_press and step == Step.OPEN and not t.calls.has(0) and not t.copy_targets.has(0)
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
	line.custom_minimum_size = Vector2(34, 2)
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
	box.add_child(GameFmt.label("%d  %s" % [i + 1, tr(STEP_KEYS[i])], INK if i <= step else Color("#8d8a94"), 15 if i == step else 13))
	return box


## What the character's skill is doing today: the name (with the FLIP switch for an Insider with a tip) and one line.
func _build_skill(t: TableSession) -> void:
	for child in _left.get_children():
		_left.remove_child(child)
		child.queue_free()
	var seat := t.human()
	var open := step == Step.OPEN and t.phase == TableSession.Phase.ACTION and seat.alive and not t.is_finished()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(GameFmt.label(TableUi.seat_name(seat, self), GameColors.GOLD, 14))
	var text := ""
	if seat.has_flag(&"copilot"):
		var target := int(t.copy_targets.get(0, -1))
		text = tr("TABLE_COPILOT_ON") % TableUi.seat_name(t.seats[target], self) if target >= 0 else tr("TABLE_COPILOT_OFF")
	elif seat.has_flag(&"insider"):
		var hint := t.insider_hint()
		if hint != null:
			text = tr("TABLE_INSIDER_HINT") + ": " + hint.headline(tr, t.market)
			var flip := CheckButton.new()
			flip.text = tr("TABLE_FLIP")
			flip.focus_mode = Control.FOCUS_NONE
			flip.disabled = not open
			flip.button_pressed = bool(t.flip_armed.get(0, false))
			flip.toggled.connect(func(on: bool) -> void:
				t.arm_flip(on)
				GameManager.table_refresh())
			head.add_child(flip)
		else:
			text = tr("TABLE_FLIP_USED") if seat.skill_used else tr("TABLE_NO_HINT")
	elif seat.has_flag(&"double_down"):
		text = tr("TABLE_DAN_USED") if seat.skill_used else tr("TABLE_DAN_HINT")
	else:
		text = tr("CHAR_%s_PASSIVE" % String(seat.character.id).to_upper())
	_left.add_child(head)
	var label := GameFmt.label(text, Color("#5d5870"), 12)
	label.custom_minimum_size = Vector2(SIDE_WIDTH - 10.0, 0)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	_left.add_child(label)


## Space is the shortcut for Next, but only when the button can be pressed and no pop-up is in front.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_day") and _next != null and not _next.disabled and _next.visible and not TableUi.modal_open:
		get_viewport().set_input_as_handled()
		_next.pressed.emit()
