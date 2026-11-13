## Dev tool: draws every company badge (icon on its tile) into one PNG so the artwork can be reviewed at a glance.
##   godot --headless --path . --script res://tools/icon_sheet.gd -- <output.png>
## Cells run left to right, top to bottom, in the order printed on the console (sorted by ticker).
extends SceneTree

const SCALE := 8
const COLUMNS := 6
const GAP := 6


func _initialize() -> void:
	var out_path := "/tmp/company_icons.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	var companies := ContentDb.companies()
	companies.sort_custom(func(a: CompanyDef, b: CompanyDef) -> bool: return a.symbol < b.symbol)
	var cell := PixelIcons.BADGE_SIZE * SCALE
	var rows := ceili(float(companies.size()) / COLUMNS)
	var sheet := Image.create(COLUMNS * (cell + GAP) + GAP, rows * (cell + GAP) + GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#e8e2d0"))
	for i in companies.size():
		var c := companies[i]
		var badge := PixelIcons.badge_image(c.icon, c.sector)
		badge.resize(cell, cell, Image.INTERPOLATE_NEAREST)
		var x := GAP + (i % COLUMNS) * (cell + GAP)
		var y := GAP + (i / COLUMNS) * (cell + GAP)
		sheet.blend_rect(badge, Rect2i(0, 0, cell, cell), Vector2i(x, y))
		print("%d: %s (%s)" % [i, c.symbol, c.icon])
	sheet.save_png(out_path)
	print("saved ", out_path)
	quit()
