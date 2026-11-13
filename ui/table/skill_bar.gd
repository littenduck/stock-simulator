## One strip at the bottom (where the perk bar used to be): your character and what its skill is doing today.
class_name SkillBar
extends PanelContainer

var _row: HBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	margin.add_child(_row)
	EventBus.table_changed.connect(_refresh)
	EventBus.day_advanced.connect(func(_d: int) -> void: _refresh())
	EventBus.table_revealed.connect(func(_e: Array) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _row == null:
		return
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	var seat := t.human()
	var open := t.phase == TableSession.Phase.ACTION and seat.alive and not t.is_finished()
	_row.add_child(GameFmt.label(TableUi.seat_name(seat, self), GameColors.GOLD, 15))
	var key := String(seat.character.id).to_upper()
	if seat.has_flag(&"copilot"):
		_row.add_child(TableUi.wrapped(tr("TABLE_COPILOT"), Color.WHITE, 13))
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.disabled = not open
		pick.add_item(tr("TABLE_COPY_NONE"))
		pick.set_item_metadata(0, -1)
		var selected := 0
		for other in t.seats:
			if other.id == 0 or not other.alive:
				continue
			pick.add_item(TableUi.seat_name(other, self))
			pick.set_item_metadata(pick.item_count - 1, other.id)
			if int(t.copy_targets.get(0, -1)) == other.id:
				selected = pick.item_count - 1
		pick.select(selected)
		pick.item_selected.connect(func(index: int) -> void:
			t.set_copy_target(int(pick.get_item_metadata(index)))
			GameManager.table_refresh())
		_row.add_child(pick)
	elif seat.has_flag(&"insider"):
		var hint := t.insider_hint()
		if hint != null:
			_row.add_child(TableUi.wrapped(tr("TABLE_INSIDER_HINT") + ": " + hint.headline(tr, t.market), Color.WHITE, 13))
			var flip := CheckButton.new()
			flip.text = tr("TABLE_FLIP")
			flip.focus_mode = Control.FOCUS_NONE
			flip.disabled = not open
			flip.button_pressed = bool(t.flip_armed.get(0, false))
			flip.toggled.connect(func(on: bool) -> void:
				t.arm_flip(on)
				GameManager.table_refresh())
			_row.add_child(flip)
		else:
			_row.add_child(TableUi.wrapped(tr("TABLE_FLIP_USED") if seat.skill_used else tr("TABLE_NO_HINT"), GameColors.MUTED, 13))
	elif seat.has_flag(&"double_down"):
		_row.add_child(TableUi.wrapped(tr("TABLE_DAN_USED") if seat.skill_used else tr("TABLE_DAN_HINT"), GameColors.MUTED, 13))
	else:
		_row.add_child(TableUi.wrapped(tr("CHAR_%s_PASSIVE" % key), GameColors.MUTED, 13))
