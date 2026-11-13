## Dev harness: all pixel icons as badges at several sizes. Shot: -- --shot=/path.png
extends Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#efe6d2")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.position = Vector2(24, 24)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	add_child(grid)
	for n in PixelIcons.names():
		var box := VBoxContainer.new()
		var row := HBoxContainer.new()
		row.add_child(CompanyBadge.make(n, 64))
		row.add_child(CompanyBadge.make(n, 36))
		row.add_child(CompanyBadge.make(n, 24))
		box.add_child(row)
		var l := Label.new()
		l.text = n
		box.add_child(l)
		grid.add_child(box)
	DevFake.shot_if_requested(self)
