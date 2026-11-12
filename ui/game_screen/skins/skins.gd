## Visual skin of the game screen: Kenney Pixel UI pack, matching ui-flow's theme. Builds a Theme and
## sets the GameColors palette. Theme type variations used by the widgets: PrimaryButton, BuyButton, SellButton,
## RowButton, ChartPanel, DialogPanel.
class_name GameSkins
extends RefCounted

const PIXEL_DIR := "res://ui/game_screen/skins/pixel/"


## Kenney Pixel UI pack, matching ui-flow's theme: light panels, ink text, coloured buttons.
static func pixel() -> Theme:
	var ink := Color("#232130")
	GameColors.UP = Color("#2a8a3c")
	GameColors.DOWN = Color("#c0392b")
	GameColors.FLAT = Color("#5d6270")
	GameColors.MUTED = Color("#5d6270")
	GameColors.GOLD = Color("#b9770e")
	GameColors.WARN = Color("#b9770e")
	GameColors.GRID = Color(0, 0, 0, 0.10)
	GameColors.CROSSHAIR = Color(0, 0, 0, 0.45)
	GameColors.CARD = Color(1, 1, 1, 0.45)
	GameColors.TRACK = Color(0, 0, 0, 0.15)
	var t := Theme.new()
	t.set_color("font_color", "Label", ink)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_stylebox("panel", "PanelContainer", _tex("colored_grey", 20, 14, 10))
	t.set_type_variation("ChartPanel", "PanelContainer")
	t.set_stylebox("panel", "ChartPanel", StyleBoxEmpty.new())
	t.set_type_variation("DialogPanel", "PanelContainer")
	t.set_stylebox("panel", "DialogPanel", _tex("colored_grey", 36, 28, 22))

	_pixel_button(t, "Button", "Button", "blue", "green")
	_pixel_button(t, "OptionButton", "OptionButton", "blue", "blue")
	_pixel_button(t, "PrimaryButton", "Button", "green", "green")
	_pixel_button(t, "BuyButton", "Button", "green", "green")
	_pixel_button(t, "SellButton", "Button", "red", "red")
	t.set_type_variation("RowButton", "Button")
	for state in ["normal", "hover"]:
		t.set_stylebox(state, "RowButton", _tex("ancient_tan", 12, 10, 4))
	for state in ["pressed", "hover_pressed"]:
		t.set_stylebox(state, "RowButton", _tex("outline_green", 12, 10, 4))
	t.set_stylebox("focus", "RowButton", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "RowButton", ink)

	var field := StyleBoxFlat.new()
	field.bg_color = Color("#fbfbfb")
	field.border_color = ink
	field.set_border_width_all(2)
	field.set_corner_radius_all(3)
	field.content_margin_left = 8
	field.content_margin_right = 8
	field.content_margin_top = 4
	field.content_margin_bottom = 4
	for state in ["normal", "focus", "read_only"]:
		t.set_stylebox(state, "LineEdit", field)
	t.set_color("font_color", "LineEdit", ink)
	t.set_color("caret_color", "LineEdit", ink)

	var none := StyleBoxEmpty.new()
	t.set_stylebox("panel", "Tree", none)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color("#1fa7e2", 0.28)
	sel.set_corner_radius_all(3)
	t.set_stylebox("selected", "Tree", sel)
	t.set_stylebox("selected_focus", "Tree", sel)
	var head := StyleBoxFlat.new()
	head.bg_color = Color("#d3c093")
	head.content_margin_left = 4
	head.content_margin_right = 4
	head.content_margin_top = 4
	head.content_margin_bottom = 4
	for state in ["title_button_normal", "title_button_hover", "title_button_pressed"]:
		t.set_stylebox(state, "Tree", head)
	t.set_color("font_color", "Tree", ink)
	t.set_color("title_button_color", "Tree", ink)
	t.set_color("font_selected_color", "Tree", ink)
	t.set_color("guide_color", "Tree", Color(0, 0, 0, 0))
	t.set_constant("v_separation", "Tree", 6)

	var tip := _tex("ancient_tan", 12, 10, 6)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", ink)
	return t


static func _tex(name: String, _unused: int, cm_h: int, cm_v: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(PIXEL_DIR + name + ".png") as Texture2D
	s.texture_margin_left = 12
	s.texture_margin_right = 12
	s.texture_margin_top = 12
	s.texture_margin_bottom = 12
	s.content_margin_left = cm_h
	s.content_margin_right = cm_h
	s.content_margin_top = cm_v
	s.content_margin_bottom = cm_v + 2
	return s


static func _pixel_button(t: Theme, type_name: String, base: String, look: String, selected: String) -> void:
	if type_name != base:
		t.set_type_variation(type_name, base)
	t.set_stylebox("normal", type_name, _tex("colored_" + look, 12, 14, 8))
	t.set_stylebox("hover", type_name, _tex("colored_" + look, 12, 14, 8))
	t.set_stylebox("pressed", type_name, _tex("colored_%s_pressed" % selected, 12, 14, 8))
	t.set_stylebox("hover_pressed", type_name, _tex("colored_%s_pressed" % selected, 12, 14, 8))
	t.set_stylebox("disabled", type_name, _tex("colored_grey_pressed", 12, 14, 8))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, type_name, Color.WHITE)
	t.set_color("font_disabled_color", type_name, Color("#5d6270"))
	t.set_color("font_outline_color", type_name, Color("#232130"))
	t.set_constant("outline_size", type_name, 4)
