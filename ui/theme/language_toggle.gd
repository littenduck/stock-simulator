## Two small buttons, "EN" and "中": the language of the game, changeable at any time. The labels are not translated
## (each one is written in its own language). Choosing one saves it, switches the text and rebuilds the screen you are on,
## because most of the text is written into the widgets when they are built. While an animation plays the toggle waits.
class_name LanguageToggle
extends HBoxContainer

const LANGUAGES := [["en", "EN"], ["zh", "中"]]

var _buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	var group := ButtonGroup.new()
	for entry in LANGUAGES:
		var b := Button.new()
		b.text = entry[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 32)
		b.tooltip_text = "English" if entry[0] == "en" else "简体中文"
		b.button_pressed = GameSettings.language() == entry[0]
		b.pressed.connect(_choose.bind(String(entry[0])))
		add_child(b)
		_buttons[entry[0]] = b
	set_process(true)


func _process(_delta: float) -> void:
	var locked := _is_locked()
	for key in _buttons:
		(_buttons[key] as Button).disabled = locked


## No switching while the game plays an animation or a pop-up is open: the screen is rebuilt on a switch.
func _is_locked() -> bool:
	return TableUi.modal_open or TableUi.skill_busy or TableUi.locks > 0


func _choose(code: String) -> void:
	if code == GameSettings.language() or _is_locked():
		return
	GameSettings.set_language(code)
	get_tree().reload_current_scene()
