## The language button: a small globe with the current language. It opens a short list in the panel style (upwards when
## the button is in the lower half of the window, otherwise downwards) with every language written in its own name. To add a
## language put a row in LANGUAGES and a column in the localization tables. Choosing one saves it, switches the text and
## rebuilds the screen you are on, because most of the text is written into the widgets when they are built. While an
## animation plays or a pop-up is open the button waits.
class_name LanguageToggle
extends Button

## [code, name in its own language, short label on the button]
const LANGUAGES := [["en", "English", "EN"], ["zh", "中文", "中"]]

static var _globe: ImageTexture = null

var _overlay: Control


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	icon = globe()
	expand_icon = false
	custom_minimum_size = Vector2(76, 34)
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pressed.connect(_toggle_list)
	_update_label()
	set_process(true)


func _process(_delta: float) -> void:
	disabled = TableUi.modal_open or TableUi.skill_busy or TableUi.locks > 0


func _update_label() -> void:
	for entry in LANGUAGES:
		if entry[0] == GameSettings.language():
			text = " " + String(entry[2])


## A small pixel globe, drawn here (like the arrow of the Next button).
static func globe() -> ImageTexture:
	if _globe == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var ink := Color("#232130")
		var sea := Color("#2f80e0")
		var land := Color("#3fb950")
		var shine := Color("#9fd4ff")
		for y in 16:
			for x in 16:
				var d := Vector2(x - 7.5, y - 7.5).length()
				if d <= 7.6:
					img.set_pixel(x, y, ink if d > 6.6 else sea)
		for p in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6),
				Vector2i(9, 8), Vector2i(10, 8), Vector2i(11, 8), Vector2i(9, 9), Vector2i(10, 9), Vector2i(10, 10),
				Vector2i(11, 10), Vector2i(10, 11), Vector2i(7, 11), Vector2i(8, 11), Vector2i(7, 12)]:
			img.set_pixelv(p, land)
		for p in [Vector2i(4, 7), Vector2i(4, 8), Vector2i(5, 8)]:
			img.set_pixelv(p, shine)
		img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		_globe = ImageTexture.create_from_image(img)
	return _globe


func _toggle_list() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_close_list()
		return
	_open_list()


func _open_list() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	# A transparent sheet over the whole screen catches a click anywhere else and closes the list.
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 100
	_overlay.set_meta("no_fx", true)
	_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_list())
	root.add_child(_overlay)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.set_meta("no_fx", true)
	var column := TableUi.column(panel, 6, 8)
	for entry in LANGUAGES:
		var b := Button.new()
		b.text = String(entry[1])
		b.custom_minimum_size = Vector2(maxf(size.x, 130.0), 34)
		b.focus_mode = Control.FOCUS_NONE
		if entry[0] == GameSettings.language():
			# The language in use is green (the menus call that button style AccentButton, the game screens PrimaryButton).
			b.theme_type_variation = &"AccentButton" if has_theme_stylebox("normal", "AccentButton") else &"PrimaryButton"
		b.pressed.connect(_choose.bind(String(entry[0])))
		column.add_child(b)
	_overlay.add_child(panel)
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.size = panel.get_combined_minimum_size()
	var rect := get_global_rect()
	var window := get_viewport_rect().size
	var up := rect.get_center().y > window.y * 0.5
	var x := clampf(rect.position.x, 6.0, window.x - panel.size.x - 6.0)
	var y := rect.position.y - panel.size.y - 4.0 if up else rect.end.y + 4.0
	panel.position = Vector2(x, y)


func _close_list() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _unhandled_input(event: InputEvent) -> void:
	if _overlay != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_list()


func _choose(code: String) -> void:
	_close_list()
	if code == GameSettings.language():
		return
	GameSettings.set_language(code)
	get_tree().reload_current_scene()
