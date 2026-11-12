## Dev harness: every theme type variation on one page.
extends Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UiPalette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	for v in ["TitleLabel", "HeaderLabel", "SubtleLabel", "PositiveLabel", "NegativeLabel", "RarityCommonLabel", "RarityRareLabel", "RarityLegendaryLabel"]:
		var l := Label.new()
		l.text = "%s  ▲ $12,345" % v
		l.theme_type_variation = v
		if v == "TitleLabel":
			l.text = "Title"
		box.add_child(l)
	var row := HBoxContainer.new()
	box.add_child(row)
	for v in ["", "AccentButton", "DangerButton", "BigMenuButton"]:
		var b := Button.new()
		b.text = v if v != "" else "Button"
		b.theme_type_variation = v
		row.add_child(b)
	var off := Button.new()
	off.text = "Disabled"
	off.disabled = true
	row.add_child(off)
	var cards := HBoxContainer.new()
	box.add_child(cards)
	for v in ["PerkCardCommon", "PerkCardRare", "PerkCardLegendary", "SelectCard"]:
		var b := Button.new()
		b.text = v
		b.theme_type_variation = v
		b.custom_minimum_size = Vector2(200, 100)
		cards.add_child(b)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var pl := Label.new()
	pl.text = "CardPanel"
	panel.add_child(pl)
	box.add_child(panel)
	DevFake.shot_if_requested(self)
