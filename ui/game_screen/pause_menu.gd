## Esc menu: resume or abandon the run. Swallows input while open so Space cannot advance the day.
class_name GamePauseMenu
extends Control

var _abandon: Button
var _confirming: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.theme_type_variation = &"DialogPanel"
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := GameFmt.label(tr("UI_GAME_MENU"), Color.WHITE, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := GameFmt.button(tr("UI_GAME_RESUME"))
	resume.custom_minimum_size = Vector2(0, 44)
	resume.pressed.connect(close)
	box.add_child(resume)
	_abandon = GameFmt.button(tr("UI_GAME_ABANDON"))
	_abandon.custom_minimum_size = Vector2(0, 44)
	_abandon.pressed.connect(_on_abandon_pressed)
	box.add_child(_abandon)


func toggle() -> void:
	if visible:
		close()
	else:
		_confirming = false
		_abandon.text = tr("UI_GAME_ABANDON")
		visible = true


func close() -> void:
	visible = false


func _on_abandon_pressed() -> void:
	if not _confirming:
		_confirming = true
		_abandon.text = tr("UI_GAME_ABANDON_CONFIRM")
		return
	visible = false
	GameManager.abandon_run()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey or event is InputEventAction):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("open_menu"):
			close()
