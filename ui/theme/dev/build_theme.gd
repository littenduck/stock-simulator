## Dev tool: regenerates ui/theme/main_theme.tres from the Kenney Pixel UI Pack art.
## Run (after build_assets.gd): godot --headless --path . --script res://ui/theme/dev/build_theme.gd
## Look: light Kenney panels, coloured Kenney buttons, Godot's default font.
extends SceneTree

const OUT_PATH := "res://ui/theme/main_theme.tres"
const ART := "res://ui/theme/assets/ui_2x/"
const MARGIN := 12  ## 9-slice margin of the 2x art


func _init() -> void:
	var t := Theme.new()
	t.default_font_size = 16
	_base(t)
	_buttons(t)
	_variations(t)
	var err := ResourceSaver.save(t, OUT_PATH)
	print("theme saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _tex(art: String, pad_h: int = 16, pad_v: int = 8, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.modulate_color = tint
	s.texture = load(ART + art + ".png")
	s.set_texture_margin_all(MARGIN)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v + 4
	s.draw_center = true
	return s


func _focus() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = UiPalette.INK
	s.set_border_width_all(3)
	s.set_corner_radius_all(4)
	return s


func _base(t: Theme) -> void:
	t.set_color("font_color", "Label", UiPalette.INK)
	t.set_constant("line_spacing", "Label", 3)
	t.set_stylebox("panel", "Panel", _tex("colored_grey", 20, 16, UiPalette.PANEL_TINT))
	t.set_stylebox("panel", "PanelContainer", _tex("colored_grey", 28, 20, UiPalette.PANEL_TINT))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 16)
	t.set_constant("v_separation", "GridContainer", 8)


## `selected` is the look of a toggled-on / held button (green for plain buttons, so a chosen toggle stands out).
func _button_look(t: Theme, type_name: String, base: String, selected: String = "") -> void:
	var sel := selected if selected != "" else base
	t.set_stylebox("normal", type_name, _tex("colored_" + base))
	t.set_stylebox("hover", type_name, _tex("colored_" + base))
	t.set_stylebox("pressed", type_name, _tex("colored_%s_pressed" % sel))
	t.set_stylebox("hover_pressed", type_name, _tex("colored_%s_pressed" % sel))
	t.set_stylebox("disabled", type_name, _tex("colored_grey_pressed"))
	t.set_stylebox("focus", type_name, _focus())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, type_name, Color.WHITE)
	t.set_color("font_disabled_color", type_name, UiPalette.INK_MUTED)
	t.set_color("font_outline_color", type_name, UiPalette.INK)
	t.set_constant("outline_size", type_name, 4)


func _buttons(t: Theme) -> void:
	_button_look(t, "Button", "blue", "green")
	_button_look(t, "OptionButton", "blue", "green")


func _variations(t: Theme) -> void:
	# Labels (all dark: they sit on the light panels).
	_label_var(t, "TitleLabel", 56, UiPalette.INK)
	_label_var(t, "HeaderLabel", 28, UiPalette.INK)
	_label_var(t, "SubtleLabel", 14, UiPalette.INK_MUTED)
	_label_var(t, "PositiveLabel", 16, UiPalette.INK_UP)
	_label_var(t, "NegativeLabel", 16, UiPalette.INK_DOWN)
	_label_var(t, "BigNumberLabel", 64, UiPalette.INK)
	_label_var(t, "RarityCommonLabel", 14, UiPalette.RARITY_COMMON)
	_label_var(t, "RarityRareLabel", 14, UiPalette.RARITY_RARE)
	_label_var(t, "RarityLegendaryLabel", 14, UiPalette.RARITY_LEGENDARY)

	# Buttons.
	t.set_type_variation("AccentButton", "Button")
	_button_look(t, "AccentButton", "green")
	t.set_font_size("font_size", "AccentButton", 20)
	t.set_type_variation("DangerButton", "Button")
	_button_look(t, "DangerButton", "red")
	t.set_type_variation("BigMenuButton", "Button")
	_button_look(t, "BigMenuButton", "blue")
	t.set_font_size("font_size", "BigMenuButton", 22)

	# Panels.
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _tex("ancient_tan", 20, 14))
	t.set_type_variation("DialogPanel", "PanelContainer")
	t.set_stylebox("panel", "DialogPanel", _tex("colored_grey", 36, 28, UiPalette.PANEL_TINT))

	# Selectable cards: light panels. Selected = green outline, rarity = outline colour.
	_card_var(t, "SelectCard", "ancient_tan", "outline_green")
	_card_var(t, "PerkCardCommon", "ancient_tan", "outline_green")
	_card_var(t, "PerkCardRare", "outline_blue", "outline_blue")
	_card_var(t, "PerkCardLegendary", "outline_yellow", "outline_yellow")


func _label_var(t: Theme, name: String, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


func _card_var(t: Theme, name: String, normal: String, pressed: String) -> void:
	t.set_type_variation(name, "Button")
	t.set_stylebox("normal", name, _tex(normal, 16, 14))
	t.set_stylebox("hover", name, _tex(pressed, 16, 14))
	t.set_stylebox("pressed", name, _tex(pressed, 16, 14))
	t.set_stylebox("hover_pressed", name, _tex(pressed, 16, 14))
	t.set_stylebox("disabled", name, _tex("colored_grey_pressed", 16, 14))
	t.set_stylebox("focus", name, _focus())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		t.set_color(c, name, UiPalette.INK)
