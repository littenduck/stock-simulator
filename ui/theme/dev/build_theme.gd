## Dev tool: regenerates ui/theme/main_theme.tres.
## Run: godot --headless --path . --script res://ui/theme/dev/build_theme.gd
extends SceneTree

const OUT_PATH := "res://ui/theme/main_theme.tres"


func _init() -> void:
	var t := Theme.new()
	t.default_font_size = 16
	_base(t)
	_buttons(t)
	_variations(t)
	var err := ResourceSaver.save(t, OUT_PATH)
	print("theme saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 6, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


func _focus_box() -> StyleBoxFlat:
	var s := _box(Color.TRANSPARENT, UiPalette.ACCENT, 2, 6, 10)
	return s


func _base(t: Theme) -> void:
	t.set_color("font_color", "Label", UiPalette.TEXT)
	t.set_constant("line_spacing", "Label", 3)
	t.set_stylebox("panel", "Panel", _box(UiPalette.PANEL, UiPalette.BORDER, 1, 8, 12))
	t.set_stylebox("panel", "PanelContainer", _box(UiPalette.PANEL, UiPalette.BORDER, 1, 8, 16))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 16)
	t.set_constant("v_separation", "GridContainer", 8)
	t.set_color("font_color", "LineEdit", UiPalette.TEXT)
	t.set_stylebox("normal", "LineEdit", _box(UiPalette.BG, UiPalette.BORDER, 1))
	t.set_stylebox("focus", "LineEdit", _focus_box())


func _buttons(t: Theme) -> void:
	for type_name in ["Button", "OptionButton", "CheckBox"]:
		t.set_color("font_color", type_name, UiPalette.TEXT)
		t.set_color("font_hover_color", type_name, Color.WHITE)
		t.set_color("font_pressed_color", type_name, Color.WHITE)
		t.set_color("font_focus_color", type_name, Color.WHITE)
		t.set_color("font_disabled_color", type_name, UiPalette.MUTED.darkened(0.25))
	t.set_stylebox("normal", "Button", _box(UiPalette.PANEL_RAISED, UiPalette.BORDER, 1))
	t.set_stylebox("hover", "Button", _box(UiPalette.PANEL_RAISED.lightened(0.12), UiPalette.ACCENT, 1))
	t.set_stylebox("pressed", "Button", _box(UiPalette.ACCENT.darkened(0.45), UiPalette.ACCENT, 1))
	t.set_stylebox("disabled", "Button", _box(UiPalette.PANEL, UiPalette.BORDER.darkened(0.3), 1))
	t.set_stylebox("focus", "Button", _focus_box())
	t.set_stylebox("normal", "OptionButton", _box(UiPalette.PANEL_RAISED, UiPalette.BORDER, 1))


func _variations(t: Theme) -> void:
	# Labels.
	_label_var(t, "TitleLabel", 56, UiPalette.TEXT)
	_label_var(t, "HeaderLabel", 28, UiPalette.TEXT)
	_label_var(t, "SubtleLabel", 14, UiPalette.MUTED)
	_label_var(t, "PositiveLabel", 16, UiPalette.UP)
	_label_var(t, "NegativeLabel", 16, UiPalette.DOWN)
	_label_var(t, "BigNumberLabel", 64, UiPalette.TEXT)
	_label_var(t, "RarityCommonLabel", 14, UiPalette.RARITY_COMMON)
	_label_var(t, "RarityRareLabel", 14, UiPalette.RARITY_RARE)
	_label_var(t, "RarityLegendaryLabel", 14, UiPalette.RARITY_LEGENDARY)

	# Buttons.
	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", _box(UiPalette.ACCENT.darkened(0.25), UiPalette.ACCENT, 1))
	t.set_stylebox("hover", "AccentButton", _box(UiPalette.ACCENT.darkened(0.1), UiPalette.ACCENT.lightened(0.3), 1))
	t.set_stylebox("pressed", "AccentButton", _box(UiPalette.ACCENT.darkened(0.45), UiPalette.ACCENT, 1))
	t.set_font_size("font_size", "AccentButton", 20)
	t.set_type_variation("DangerButton", "Button")
	t.set_stylebox("normal", "DangerButton", _box(UiPalette.DOWN.darkened(0.5), UiPalette.DOWN, 1))
	t.set_stylebox("hover", "DangerButton", _box(UiPalette.DOWN.darkened(0.3), UiPalette.DOWN, 1))
	t.set_type_variation("BigMenuButton", "Button")
	t.set_font_size("font_size", "BigMenuButton", 22)
	t.set_stylebox("normal", "BigMenuButton", _box(UiPalette.PANEL_RAISED, UiPalette.BORDER, 1, 6, 16))
	t.set_stylebox("hover", "BigMenuButton", _box(UiPalette.PANEL_RAISED.lightened(0.12), UiPalette.ACCENT, 1, 6, 16))
	t.set_stylebox("pressed", "BigMenuButton", _box(UiPalette.ACCENT.darkened(0.45), UiPalette.ACCENT, 1, 6, 16))
	t.set_stylebox("disabled", "BigMenuButton", _box(UiPalette.PANEL, UiPalette.BORDER.darkened(0.3), 1, 6, 16))
	t.set_stylebox("focus", "BigMenuButton", _box(Color.TRANSPARENT, UiPalette.ACCENT, 2, 6, 16))

	# Panels.
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _box(UiPalette.PANEL_RAISED, UiPalette.BORDER, 1, 10, 18))
	t.set_type_variation("DialogPanel", "PanelContainer")
	t.set_stylebox("panel", "DialogPanel", _box(UiPalette.PANEL, UiPalette.BORDER, 2, 12, 28))

	# Selectable cards: Button variations, one per rarity plus a plain selectable card.
	_card_var(t, "PerkCardCommon", UiPalette.RARITY_COMMON)
	_card_var(t, "PerkCardRare", UiPalette.RARITY_RARE)
	_card_var(t, "PerkCardLegendary", UiPalette.RARITY_LEGENDARY)
	_card_var(t, "SelectCard", UiPalette.ACCENT)


func _label_var(t: Theme, name: String, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


## A big button used as a card. Border colour = `accent`; thick when hovered, focused or toggled.
func _card_var(t: Theme, name: String, accent: Color) -> void:
	t.set_type_variation(name, "Button")
	var base := UiPalette.PANEL_RAISED
	t.set_stylebox("normal", name, _box(base, accent.darkened(0.45), 2, 10, 16))
	t.set_stylebox("hover", name, _box(base.lightened(0.1), accent, 3, 10, 16))
	t.set_stylebox("pressed", name, _box(accent.darkened(0.6), accent, 3, 10, 16))
	t.set_stylebox("hover_pressed", name, _box(accent.darkened(0.55), accent, 3, 10, 16))
	t.set_stylebox("disabled", name, _box(UiPalette.PANEL, UiPalette.BORDER.darkened(0.3), 1, 10, 16))
	t.set_stylebox("focus", name, _box(Color.TRANSPARENT, Color.WHITE, 3, 10, 16))
