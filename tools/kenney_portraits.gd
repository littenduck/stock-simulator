## Dev tool: renders the six table characters as transparent 192x192 busts from the Kenney Mini Characters pack
## (CC0, https://kenney.nl/assets/mini-characters) into ui/theme/portraits/<character id>.png.
##   godot --path . --script res://tools/kenney_portraits.gd -- <glb folder> <output folder> [sheet.png]
## Each character is the pack model that looks most like the role, used as it is. The only changes: Saving Son gets the
## light skin tone of the other default characters, and Goldfish Gus gets a goldfish head.
extends SceneTree

const CELL := 192
const ORDER := ["saving_son", "goldfish_gus", "hodl_hana", "copilot_cody", "double_dan", "insider_inu"]
const MODELS := {
	"saving_son": "character-male-a",
	"goldfish_gus": "character-male-b",
	"hodl_hana": "character-female-e",
	"copilot_cody": "character-robot",
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


## Every model paints from the same 8x8 colour grid (64 px cells). Cells (1,4) and (1,5) are the dark skin tone and its
## shadow; copy the light tone of cells (2,4) and (2,5) over them, for this model only.
func _light_skin(model: Node3D) -> void:
	for part in ["head-mesh", "body-mesh"]:
		var mi: MeshInstance3D = model.find_child(part, true, false)
		var mat := (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		var img: Image = mat.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		for row in [4, 5]:
			img.fill_rect(Rect2i(64, row * 64, 64, 64), img.get_pixel(2 * 64 + 32, row * 64 + 32))
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mi.set_surface_override_material(0, mat)


func _fish_head(model: Node3D) -> void:
	(model.find_child("head-mesh", true, false) as MeshInstance3D).visible = false
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.2
	var orange := _solid(Color("#f5963a"))
	var red := _solid(Color("#e5484d"))
	_blob(model, ball, orange, Vector3(0, 0.57, 0.02), Vector3(1.7, 1.75, 1.6))          # the head
	_blob(model, ball, _solid(Color("#ffb868")), Vector3(0, 0.5, 0.1), Vector3(1.2, 0.9, 0.8))   # lighter cheeks
	_blob(model, ball, red, Vector3(0, 0.77, -0.02), Vector3(0.5, 1.1, 0.5))             # crest fin on top
	for s in [-1.0, 1.0]:
		_blob(model, ball, red, Vector3(0.19 * s, 0.55, 0.0), Vector3(0.35, 1.0, 0.7))   # side fins
		_blob(model, ball, _solid(Color.WHITE), Vector3(0.085 * s, 0.63, 0.14), Vector3(0.62, 0.62, 0.5))   # eyes
		_blob(model, ball, _solid(Color("#2b2540")), Vector3(0.09 * s, 0.63, 0.165), Vector3(0.3, 0.3, 0.3))
	_blob(model, ball, _solid(Color("#c9402a")), Vector3(0, 0.49, 0.175), Vector3(0.55, 0.3, 0.3))    # little mouth


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
	if id == "saving_son":
		_light_skin(model)
	elif id == "goldfish_gus":
		_fish_head(model)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim != null and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.4, true)
		anim.pause()
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
