extends RefCounted
## Clean, stylized WebGL2-safe procedural 3D environment & landmark asset builders.
## Uses vertex-colored / StandardMaterial3D meshes + MultiMeshInstance3D so 200+ trees,
## rocks, ferns, and landmarks stay locked at 60 FPS inside the Godot 4 Web Editor.


static func make_mat(col: Color, rough: float = 0.85, met: float = 0.0, emit_col: Color = Color.BLACK, emit_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = met
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m


static func build_pine_trunk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.42
	cm.height = 5.4
	cm.radial_segments = 7
	st.append_from(cm, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.7, 0.0)))
	return st.commit()


static func build_pine_canopy_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers: Array = [
		{"y": 4.2, "r": 2.45, "h": 3.4},
		{"y": 6.4, "r": 1.92, "h": 3.0},
		{"y": 8.3, "r": 1.32, "h": 2.6},
	]
	for t_var in tiers:
		var t: Dictionary = t_var
		var cone := CylinderMesh.new()
		cone.top_radius = 0.04
		cone.bottom_radius = float(t["r"])
		cone.height = float(t["h"])
		cone.radial_segments = 7
		st.append_from(cone, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, float(t["y"]), 0.0)))
	return st.commit()


static func build_oak_trunk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.62
	cm.height = 4.6
	cm.radial_segments = 8
	st.append_from(cm, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.3, 0.0)))
	return st.commit()


static func build_oak_canopy_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var puffs: Array = [
		{"pos": Vector3(0.0, 5.8, 0.0), "r": 2.4},
		{"pos": Vector3(-1.45, 5.1, 0.8), "r": 1.65},
		{"pos": Vector3(1.5, 5.2, -0.7), "r": 1.75},
		{"pos": Vector3(0.2, 5.3, -1.4), "r": 1.55},
		{"pos": Vector3(-0.4, 5.2, 1.45), "r": 1.5},
	]
	for p_var in puffs:
		var p: Dictionary = p_var
		var sp := SphereMesh.new()
		sp.radius = float(p["r"])
		sp.height = float(p["r"]) * 1.55
		sp.radial_segments = 8
		sp.rings = 5
		st.append_from(sp, 0, Transform3D(Basis.IDENTITY, p["pos"]))
	return st.commit()


static func build_bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for off in [Vector3(0.0, 0.55, 0.0), Vector3(-0.55, 0.42, 0.32), Vector3(0.52, 0.44, -0.28)]:
		var sp := SphereMesh.new()
		sp.radius = 0.72
		sp.height = 1.05
		sp.radial_segments = 7
		sp.rings = 4
		st.append_from(sp, 0, Transform3D(Basis.IDENTITY, off))
	return st.commit()


static func build_rock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 1.35
	sp.radial_segments = 7
	sp.rings = 4
	st.append_from(sp, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(1.15, 0.78, 0.95)), Vector3(0.0, 0.4, 0.0)))
	return st.commit()


static func build_mushroom_cluster_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cfg in [
		{"p": Vector3(0.0, 0.45, 0.0), "r": 0.36, "h": 0.45},
		{"p": Vector3(-0.34, 0.3, 0.22), "r": 0.24, "h": 0.3},
		{"p": Vector3(0.32, 0.34, -0.18), "r": 0.26, "h": 0.34},
	]:
		var pos: Vector3 = cfg["p"]
		var cap := SphereMesh.new()
		cap.radius = float(cfg["r"])
		cap.height = float(cfg["r"]) * 0.85
		cap.radial_segments = 8
		cap.rings = 4
		st.append_from(cap, 0, Transform3D(Basis.IDENTITY, pos))
	return st.commit()


static func spawn_multimesh(parent: Node3D, xforms: Array, mesh_res: Mesh, mat: Material) -> MultiMeshInstance3D:
	if xforms.is_empty() or not mesh_res:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_res
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)
	return mmi


static func spawn_campfire(parent: Node3D, pos: Vector3, add_light: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	root.position = pos
	parent.add_child(root)

	var stone_mat := make_mat(Color(0.32, 0.36, 0.38, 1.0), 0.92)
	var wood_mat := make_mat(Color(0.28, 0.16, 0.09, 1.0), 0.92)
	var fire_mat := make_mat(Color(1.0, 0.62, 0.18, 1.0), 0.2, 0.0, Color(1.0, 0.52, 0.12, 1.0), 3.6)

	for i in 8:
		var ang: float = (float(i) / 8.0) * TAU
		var rock := MeshInstance3D.new()
		var rm := SphereMesh.new()
		rm.radius = 0.24
		rm.height = 0.34
		rm.radial_segments = 6
		rock.mesh = rm
		rock.position = Vector3(cos(ang) * 0.82, 0.14, sin(ang) * 0.82)
		rock.material_override = stone_mat
		root.add_child(rock)

	for ang_deg in [25.0, 85.0, 145.0]:
		var log_m := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.09
		lm.bottom_radius = 0.11
		lm.height = 1.25
		lm.radial_segments = 6
		log_m.mesh = lm
		log_m.position = Vector3(0.0, 0.18, 0.0)
		log_m.rotation = Vector3(PI * 0.44, deg_to_rad(ang_deg), 0.0)
		log_m.material_override = wood_mat
		root.add_child(log_m)

	var flame := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.04
	fm.bottom_radius = 0.38
	fm.height = 0.92
	fm.radial_segments = 7
	flame.mesh = fm
	flame.position = Vector3(0.0, 0.56, 0.0)
	flame.material_override = fire_mat
	root.add_child(flame)

	if add_light:
		var lt := OmniLight3D.new()
		lt.position = Vector3(0.0, 1.2, 0.0)
		lt.light_color = Color(1.0, 0.68, 0.3, 1.0)
		lt.light_energy = 3.2
		lt.omni_range = 16.0
		root.add_child(lt)
	return root


static func spawn_lantern_post(parent: Node3D, pos: Vector3, yaw_rad: float = 0.0, add_light: bool = false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw_rad
	parent.add_child(root)

	var wood_mat := make_mat(Color(0.28, 0.19, 0.12, 1.0), 0.9)
	var iron_mat := make_mat(Color(0.18, 0.2, 0.24, 1.0), 0.45, 0.7)
	var bulb_mat := make_mat(Color(1.0, 0.9, 0.48, 1.0), 0.2, 0.0, Color(1.0, 0.82, 0.32, 1.0), 3.6)

	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.14
	pm.height = 3.1
	pm.radial_segments = 6
	post.mesh = pm
	post.position = Vector3(0.0, 1.55, 0.0)
	post.material_override = wood_mat
	root.add_child(post)

	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.85, 0.1, 0.1)
	arm.mesh = am
	arm.position = Vector3(0.36, 2.92, 0.0)
	arm.material_override = iron_mat
	root.add_child(arm)

	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.18
	bm.height = 0.36
	bm.radial_segments = 8
	bulb.mesh = bm
	bulb.position = Vector3(0.68, 2.66, 0.0)
	bulb.material_override = bulb_mat
	root.add_child(bulb)

	if add_light:
		var lt := OmniLight3D.new()
		lt.position = Vector3(0.68, 2.66, 0.0)
		lt.light_color = Color(1.0, 0.82, 0.42, 1.0)
		lt.light_energy = 2.4
		lt.omni_range = 15.0
		root.add_child(lt)
	return root


static func spawn_stone_archway(parent: Node3D, pos: Vector3, width: float = 9.0, height: float = 6.2, yaw_rad: float = 0.0, rune_color: Color = Color(0.38, 0.95, 0.82, 1.0)) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw_rad
	parent.add_child(root)

	var stone_mat := make_mat(Color(0.28, 0.34, 0.36, 1.0), 0.88)
	var rune_mat := make_mat(rune_color, 0.25, 0.1, rune_color, 2.4)
	var half_w: float = width * 0.5

	for sgn in [-1.0, 1.0]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(sgn * half_w, height * 0.5, 0.0)
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.65
		cs.height = height
		col.shape = cs
		body.add_child(col)

		var pil := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.52
		pm.bottom_radius = 0.68
		pm.height = height
		pm.radial_segments = 8
		pil.mesh = pm
		pil.material_override = stone_mat
		body.add_child(pil)
		root.add_child(body)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(width + 2.2, 1.1, 1.45)
	lintel.mesh = lm
	lintel.position = Vector3(0.0, height + 0.45, 0.0)
	lintel.material_override = stone_mat
	root.add_child(lintel)

	var gem := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.46
	gm.height = 0.95
	gem.mesh = gm
	gem.position = Vector3(0.0, height + 0.5, 0.0)
	gem.material_override = rune_mat
	root.add_child(gem)
	return root


static func spawn_signpost(parent: Node3D, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(root)

	var wood_mat := make_mat(Color(0.34, 0.22, 0.12, 1.0), 0.88)
	var gold_mat := make_mat(Color(0.98, 0.82, 0.3, 1.0), 0.3, 0.6, Color(0.95, 0.78, 0.25, 1.0), 0.8)

	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.12
	pm.height = 2.3
	pm.radial_segments = 6
	post.mesh = pm
	post.position = Vector3(0.0, 1.15, 0.0)
	post.material_override = wood_mat
	root.add_child(post)

	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.25, 0.34, 0.1)
	board.mesh = bm
	board.position = Vector3(0.35, 1.92, 0.0)
	board.material_override = wood_mat
	root.add_child(board)

	var arrow := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.01
	am.bottom_radius = 0.18
	am.height = 0.32
	am.radial_segments = 4
	arrow.mesh = am
	arrow.position = Vector3(1.08, 1.92, 0.0)
	arrow.rotation.z = -PI * 0.5
	arrow.material_override = gold_mat
	root.add_child(arrow)
	return root


static func spawn_ruin_pillar(parent: Node3D, pos: Vector3, height: float = 5.5, stone_col: Color = Color(0.28, 0.34, 0.38, 1.0)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.75
	cs.height = height
	col.shape = cs
	col.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(col)

	var mat := make_mat(stone_col, 0.86)
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.62
	sm.bottom_radius = 0.76
	sm.height = height
	sm.radial_segments = 8
	shaft.mesh = sm
	shaft.position = Vector3(0.0, height * 0.5, 0.0)
	shaft.material_override = mat
	body.add_child(shaft)

	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.8, 0.42, 1.8)
	cap.mesh = cm
	cap.position = Vector3(0.0, height + 0.18, 0.0)
	cap.material_override = mat
	body.add_child(cap)
	return body


static func spawn_fallen_log(parent: Node3D, pos: Vector3, yaw_rad: float = 0.4) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw_rad
	parent.add_child(root)
	var bark_mat := make_mat(Color(0.26, 0.17, 0.11, 1.0), 0.92)
	var log_m := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.34
	lm.bottom_radius = 0.44
	lm.height = 4.4
	lm.radial_segments = 7
	log_m.mesh = lm
	log_m.position = Vector3(0.0, 0.34, 0.0)
	log_m.rotation.z = PI * 0.5
	log_m.material_override = bark_mat
	root.add_child(log_m)
	return root


static func spawn_pond(parent: Node3D, pos: Vector3, radius: float = 11.0) -> MeshInstance3D:
	var pond := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = radius
	pm.bottom_radius = radius
	pm.height = 0.12
	pm.radial_segments = 20
	pond.mesh = pm
	pond.position = pos
	var wmat := StandardMaterial3D.new()
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color = Color(0.12, 0.52, 0.68, 0.82)
	wmat.roughness = 0.12
	wmat.metallic = 0.25
	wmat.emission_enabled = true
	wmat.emission = Color(0.08, 0.36, 0.48, 1.0)
	wmat.emission_energy_multiplier = 0.65
	pond.material_override = wmat
	parent.add_child(pond)
	return pond


# Backwards-compatible helper hooks
static func enhance_flying_wisp(_wisp: Node3D) -> void:
	pass

static func enhance_crystal(_crystal: Node3D) -> void:
	pass

static func enhance_healing_orb(_orb: Node3D) -> Dictionary:
	return {}

static func enhance_golden_compass(_compass: Node3D) -> Dictionary:
	return {}

static func build_hidden_foliage_curtain(_cover_group: Node3D) -> ShaderMaterial:
	return null
