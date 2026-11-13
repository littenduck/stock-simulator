## Dev tool: renders the six table characters as transparent 192x192 busts from the Kenney Mini Characters pack
## (CC0, https://kenney.nl/assets/mini-characters) into ui/theme/portraits/<character id>.png.
##   godot --path . --script res://tools/kenney_portraits.gd -- <glb folder> <output folder> [sheet.png]
## Each character is the pack model that looks most like the role; a few props (sunglasses, fishbowl, diamond) are added.
extends SceneTree

const CELL := 192
const ORDER := ["saving_son", "goldfish_gus", "hodl_hana", "copilot_cody", "double_dan", "insider_inu"]
const MODELS := {
	"saving_son": "character-male-a",
	"goldfish_gus": "character-male-b",
	"hodl_hana": "character-female-e",
	"copilot_cody": "character-soldier",
	"double_dan": "character-male-e",
	"insider_inu": "character-male-d",
}

var _dir := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_run.call_deferred(a[0], a[1], a[2] if a.size() > 2 else "")


func _run(dir_path: String, out_dir: String, sheet_path: String) -> void:
	_dir = dir_path
	DirAccess.make_dir_recursive_absolute(out_dir)
	var sheet := Image.create(3 * CELL, 2 * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#d9d2bd"))
	for i in ORDER.size():
		var id: String = ORDER[i]
		var img := await _bust(id)
		if img == null:
			continue
		img.save_png("%s/%s.png" % [out_dir, id])
		sheet.blend_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i((i % 3) * CELL, (i / 3) * CELL))
		print("saved ", id)
	if sheet_path != "":
		sheet.save_png(sheet_path)
	quit()


func _load(name: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file("%s/%s.glb" % [_dir, name], state) != OK:
		print("cannot load ", name)
		return null
	return doc.generate_scene(state)


## Flat, see-through colour (no lighting, so glass never turns grey).
func _glass(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _solid(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	return m


func _blob(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scale: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)


func _props(id: String, model: Node3D) -> void:
	match id:
		"insider_inu":
			var shades := _load("aid-sunglasses")
			if shades != null:
				shades.position = Vector3(0, 0.505, 0.12)
				shades.scale = Vector3.ONE * 1.0
				model.add_child(shades)
		"goldfish_gus":
			var bowl := SphereMesh.new()
			bowl.radius = 0.31
			bowl.height = 0.62
			_blob(model, bowl, _glass(Color(0.7, 0.95, 1.0, 0.16)), Vector3(0, 0.56, 0.0))
			var rim := TorusMesh.new()
			rim.inner_radius = 0.255
			rim.outer_radius = 0.31
			_blob(model, rim, _glass(Color(0.85, 0.98, 1.0, 0.85)), Vector3(0, 0.3, 0.0))
			var shine := SphereMesh.new()
			shine.radius = 0.03
			shine.height = 0.06
			_blob(model, shine, _glass(Color(1, 1, 1, 0.9)), Vector3(-0.2, 0.74, 0.25), Vector3(1.0, 2.6, 0.5))
			var fish := SphereMesh.new()
			fish.radius = 0.045
			fish.height = 0.09
			_blob(model, fish, _solid(Color("#f5963a")), Vector3(0.17, 0.77, 0.24), Vector3(1.5, 1.0, 0.8))
			_blob(model, fish, _solid(Color("#e5484d")), Vector3(0.25, 0.77, 0.24), Vector3(0.6, 1.2, 0.5))
		"hodl_hana":
			var gem := SphereMesh.new()
			gem.radius = 0.055
			gem.height = 0.11
			gem.radial_segments = 4
			gem.rings = 2
			var m := _solid(Color("#8eeef2"))
			m.emission_enabled = true
			m.emission = Color("#4aa3ff")
			m.emission_energy_multiplier = 0.6
			_blob(model, gem, m, Vector3(0, 0.285, 0.13), Vector3(1.0, 1.4, 0.7))


func _bust(id: String) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var model := _load(MODELS[id])
	if model == null:
		return null
	vp.add_child(model)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim != null and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.4, true)
		anim.pause()
	_props(id, model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.7
	vp.add_child(cam)
	cam.position = Vector3(0, 0.5, 3)
	cam.look_at(Vector3(0, 0.5, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 20, 0)
	vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.72, 0.78)
	vp.add_child(env)
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
