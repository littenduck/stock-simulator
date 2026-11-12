## Visual skins for the game screen. Each builds a Theme (and sets the GameColors palette) for one
## variant scene. Theme type variations used by the widgets: PrimaryButton, BuyButton, SellButton,
## RowButton, ChartPanel, DialogPanel.
class_name GameSkins
extends RefCounted

const PIXEL_DIR := "res://ui/game_screen/skins/pixel/"


## Robinhood-style dark: near-black, flat, pill buttons, bright green / orange-red.
static func dark() -> Theme:
	GameColors.UP = Color("#00c805")
	GameColors.DOWN = Color("#ff5000")
	GameColors.FLAT = Color("#8f949c")
	GameColors.MUTED = Color("#8f949c")
	GameColors.GOLD = Color("#f5c542")
	GameColors.WARN = Color("#f5a623")
	GameColors.GRID = Color(1, 1, 1, 0.07)
	GameColors.CROSSHAIR = Color(1, 1, 1, 0.4)
	GameColors.CARD = Color(1, 1, 1, 0.05)
	GameColors.TRACK = Color(1, 1, 1, 0.12)
	return _flat({
		"text": Color.WHITE, "muted": GameColors.MUTED, "surface": Color("#131517"), "hover": Color("#1f2226"),
		"pressed": Color("#2b2f35"), "control": Color("#1c1f23"), "primary": Color.WHITE, "primary_text": Color.BLACK,
		"buy": Color("#00c805"), "sell": Color("#ff5000"), "pill_text": Color.BLACK, "sell_text": Color.WHITE,
		"dialog": Color("#1c1f23"), "radius": 14,
	})


## Robinhood-style light: white page, light grey cards, black primary pill.
static func light() -> Theme:
	GameColors.UP = Color("#00a63a")
	GameColors.DOWN = Color("#e5400a")
	GameColors.FLAT = Color("#6b7280")
	GameColors.MUTED = Color("#6b7280")
	GameColors.GOLD = Color("#b07a00")
	GameColors.WARN = Color("#c77700")
	GameColors.GRID = Color(0, 0, 0, 0.07)
	GameColors.CROSSHAIR = Color(0, 0, 0, 0.4)
	GameColors.CARD = Color(0, 0, 0, 0.045)
	GameColors.TRACK = Color(0, 0, 0, 0.10)
	return _flat({
		"text": Color("#0f1114"), "muted": GameColors.MUTED, "surface": Color("#f3f4f6"), "hover": Color("#e8eaed"),
		"pressed": Color("#d9dce1"), "control": Color("#e6e8ec"), "primary": Color("#0f1114"), "primary_text": Color.WHITE,
		"buy": Color("#00b43c"), "sell": Color("#f0501e"), "pill_text": Color.WHITE, "sell_text": Color.WHITE,
		"dialog": Color.WHITE, "radius": 14,
	})


static func _box(color: Color, radius: int, margin_h: int = 12, margin_v: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


static func _button(t: Theme, type_name: String, base: String, normal: Color, hover: Color, pressed: Color, font: Color, radius: int, pressed_font: Color = Color(0, 0, 0, 0)) -> void:
	if type_name != base:
		t.set_type_variation(type_name, base)
	t.set_stylebox("normal", type_name, _box(normal, radius))
	t.set_stylebox("hover", type_name, _box(hover, radius))
	t.set_stylebox("pressed", type_name, _box(pressed, radius))
	t.set_stylebox("hover_pressed", type_name, _box(pressed, radius))
	t.set_stylebox("disabled", type_name, _box(normal.darkened(0.2) if normal.a > 0.0 else normal, radius))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	var pf: Color = pressed_font if pressed_font.a > 0.0 else font
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, type_name, font)
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, type_name, pf)
	t.set_color("font_disabled_color", type_name, font.darkened(0.4))


static func _flat(p: Dictionary) -> Theme:
	var t := Theme.new()
	var r: int = p["radius"]
	var text: Color = p["text"]
	t.set_color("font_color", "Label", text)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_stylebox("panel", "PanelContainer", _box(p["surface"], r, 14, 10))
	t.set_type_variation("ChartPanel", "PanelContainer")
	t.set_stylebox("panel", "ChartPanel", _box(Color(0, 0, 0, 0), 0, 0, 0))
	t.set_type_variation("DialogPanel", "PanelContainer")
	t.set_stylebox("panel", "DialogPanel", _box(p["dialog"], r + 4, 24, 20))

	_button(t, "Button", "Button", p["control"], p["hover"], p["pressed"], text, 22)
	_button(t, "OptionButton", "OptionButton", p["control"], p["hover"], p["control"], text, 12)
	t.set_stylebox("normal", "Button", _box(p["control"], 22, 16, 8))
	_button(t, "RowButton", "Button", Color(0, 0, 0, 0), p["hover"], p["pressed"], text, 12)
	_button(t, "PrimaryButton", "Button", p["primary"], (p["primary"] as Color).lightened(0.15), (p["primary"] as Color).darkened(0.15), p["primary_text"], 22)
	_button(t, "BuyButton", "Button", p["buy"], (p["buy"] as Color).lightened(0.12), (p["buy"] as Color).darkened(0.12), p["pill_text"], 24)
	_button(t, "SellButton", "Button", p["sell"], (p["sell"] as Color).lightened(0.12), (p["sell"] as Color).darkened(0.12), p["sell_text"], 24)
	for v in ["BuyButton", "SellButton", "PrimaryButton"]:
		t.set_font_size("font_size", v, 17)

	var field: StyleBoxFlat = _box(p["control"], 10, 10, 6)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", text)
	t.set_color("caret_color", "LineEdit", text)
	t.set_color("selection_color", "LineEdit", Color(GameColors.UP, 0.35))

	t.set_stylebox("panel", "Tree", _box(Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("selected", "Tree", _box(p["hover"], 8, 4, 2))
	t.set_stylebox("selected_focus", "Tree", _box(p["hover"], 8, 4, 2))
	t.set_stylebox("title_button_normal", "Tree", _box(Color(0, 0, 0, 0), 0, 4, 4))
	t.set_stylebox("title_button_hover", "Tree", _box(Color(0, 0, 0, 0), 0, 4, 4))
	t.set_stylebox("title_button_pressed", "Tree", _box(Color(0, 0, 0, 0), 0, 4, 4))
	t.set_color("font_color", "Tree", text)
	t.set_color("title_button_color", "Tree", p["muted"])
	t.set_color("font_selected_color", "Tree", text)
	t.set_color("guide_color", "Tree", Color(0, 0, 0, 0))
	t.set_color("relationship_line_color", "Tree", Color(0, 0, 0, 0))
	t.set_constant("v_separation", "Tree", 6)

	# Tabs: plain text, selected one underlined.
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = text
	under.border_width_bottom = 2
	under.content_margin_left = 12
	under.content_margin_right = 12
	under.content_margin_top = 6
	under.content_margin_bottom = 6
	var plain: StyleBoxFlat = _box(Color(0, 0, 0, 0), 0, 12, 6)
	t.set_stylebox("tab_selected", "TabContainer", under)
	t.set_stylebox("tab_unselected", "TabContainer", plain)
	t.set_stylebox("tab_hovered", "TabContainer", plain)
	t.set_stylebox("tab_focus", "TabContainer", under)
	t.set_stylebox("panel", "TabContainer", _box(Color(0, 0, 0, 0), 0, 0, 6))
	t.set_color("font_selected_color", "TabContainer", text)
	t.set_color("font_unselected_color", "TabContainer", p["muted"])
	t.set_color("font_hovered_color", "TabContainer", text)
	t.set_font_size("font_size", "TabContainer", 16)

	var tip := _box(p["dialog"], 8, 10, 6)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", text)
	return t


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
