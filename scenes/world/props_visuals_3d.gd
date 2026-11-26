extends RefCounted
## Procedural sculpted mesh & PBR visual enhancers for 3D props, wisps, relics, and secret foliage veils.

const MeshFactory3D = preload("res://scenes/common/mesh_factory_3d.gd")
const SHADER_FOLIAGE: Shader = preload("res://resources/shaders/foliage_sway_3d.gdshader")
const TEX_FERN_CARD: Texture2D = preload("res://assets/textures3d/fern_frond_card.png")
const TEX_BRANCH_CARD: Texture2D = preload("res://assets/textures3d/foliage_branch_card.png")
const MAT_STONE: StandardMaterial3D = preload("res://resources/materials3d/ancient_stone.tres")
const MAT_FILIGREE: StandardMaterial3D = preload("res://resources/materials3d/metal_filigree.tres")
const MAT_CRYSTAL: StandardMaterial3D = preload("res://resources/materials3d/crystal_prism.tres")
const MAT_RUNE: StandardMaterial3D = preload("res://resources/materials3d/rune_stone.tres")
const MAT_CLOAK: StandardMaterial3D = preload("res://resources/materials3d/char_cloak.tres")


static func enhance_flying_wisp(wisp: Node3D) -> void:
	var vis := wisp.get_node_or_null("Visuals") as Node3D
	if not vis:
		return

	var core := vis.get_node_or_null("CoreMesh") as MeshInstance3D
	if core:
		core.mesh = MeshFactory3D.build_rune_shard_mesh(0.32, 0.78, 9)

	var orbit_ring := vis.get_node_or_null("OrbitRing") as MeshInstance3D
	if orbit_ring:
		orbit_ring.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.56, 0.67, 0.045, 24)
		orbit_ring.material_override = MAT_FILIGREE

	# Counter-rotating inner gyro-ring
	var inner_ring := MeshInstance3D.new()
	inner_ring.name = "InnerRing"
	inner_ring.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.42, 0.49, 0.035, 20)
	inner_ring.rotation = Vector3(deg_to_rad(52.0), 0.0, deg_to_rad(24.0))
	inner_ring.material_override = MAT_CRYSTAL
	vis.add_child(inner_ring)

	# Carved stone cowl & antlers above the wisp core
	var cowl := MeshInstance3D.new()
	cowl.name = "StoneCowl"
	cowl.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.05, 0.04), "rx": 0.42, "rz": 0.44, "v": 0.0},
		{"center": Vector3(0.0, 0.24, 0.08), "rx": 0.34, "rz": 0.36, "v": 0.55},
		{"center": Vector3(0.0, 0.46, 0.16), "rx": 0.09, "rz": 0.12, "v": 1.0},
	], 10, true, 4, 0.03)
	cowl.position = Vector3(0.0, 0.14, 0.0)
	cowl.material_override = MAT_STONE
	vis.add_child(cowl)

	for side in [-1.0, 1.0]:
		var antler := MeshInstance3D.new()
		antler.name = "AntlerL" if side < 0.0 else "AntlerR"
		antler.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, 0.0, 0.0), "rx": 0.055, "rz": 0.055, "v": 0.0},
			{"center": Vector3(side * 0.18, 0.26, -0.04), "rx": 0.036, "rz": 0.036, "v": 0.55},
			{"center": Vector3(side * 0.26, 0.54, 0.04), "rx": 0.012, "rz": 0.012, "v": 1.0},
		], 6, true)
		antler.position = Vector3(side * 0.22, 0.36, 0.02)
		antler.material_override = MAT_RUNE
		vis.add_child(antler)

	# Flapping spectral mantle wings
	var wing_mat := StandardMaterial3D.new()
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing_mat.albedo_color = Color(0.24, 0.78, 0.84, 0.76)
	wing_mat.emission_enabled = true
	wing_mat.emission = Color(0.18, 0.74, 0.82, 1.0)
	wing_mat.emission_energy_multiplier = 1.25
	wing_mat.roughness = 0.45

	var wing_mesh := MeshFactory3D.build_curved_cloak_mesh(0.14, 0.36, 0.72, 4, 5)
	for side_info in [["WingLeft", -1.0], ["WingRight", 1.0]]:
		var w_pivot := Node3D.new()
		w_pivot.name = String(side_info[0])
		var s := float(side_info[1])
		w_pivot.position = Vector3(s * 0.34, 0.14, 0.08)
		w_pivot.rotation = Vector3(deg_to_rad(18.0), s * deg_to_rad(14.0), -s * 1.05)
		var wm := MeshInstance3D.new()
		wm.mesh = wing_mesh
		wm.material_override = wing_mat
		w_pivot.add_child(wm)
		vis.add_child(w_pivot)

	# 4 waving spectral tendrils hanging beneath the wisp
	var tendril_mesh := MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, 0.0, 0.0), "rx": 0.055, "rz": 0.055, "v": 0.0},
		{"center": Vector3(0.02, -0.34, 0.03), "rx": 0.036, "rz": 0.036, "v": 0.5},
		{"center": Vector3(-0.02, -0.72, 0.0), "rx": 0.008, "rz": 0.008, "v": 1.0},
	], 6, true)
	for ti in 4:
		var ang := float(ti) * TAU * 0.25 + 0.4
		var td := MeshInstance3D.new()
		td.name = "Tendril_%d" % ti
		td.mesh = tendril_mesh
		td.position = Vector3(cos(ang) * 0.2, -0.32, sin(ang) * 0.2)
		td.material_override = MAT_CLOAK
		vis.add_child(td)

	# Diegetic floating HP pips above wisp
	var pips_root := Node3D.new()
	pips_root.name = "HpPips"
	pips_root.position = Vector3(0.0, 1.08, 0.0)
	vis.add_child(pips_root)

	var pip_mat := StandardMaterial3D.new()
	pip_mat.albedo_color = Color(1.0, 0.42, 0.38, 1.0)
	pip_mat.emission_enabled = true
	pip_mat.emission = Color(1.0, 0.32, 0.28, 1.0)
	pip_mat.emission_energy_multiplier = 2.6
	pip_mat.roughness = 0.2

	var pip_mesh := MeshFactory3D.build_rune_shard_mesh(0.06, 0.16, 5)
	for pi in 4:
		var pip := MeshInstance3D.new()
		pip.name = "Pip_%d" % pi
		pip.mesh = pip_mesh
		pip.material_override = pip_mat
		pips_root.add_child(pip)


static func enhance_crystal(crystal: Node3D) -> void:
	var vp := crystal.get_node_or_null("VisualPivot") as Node3D
	if not vp:
		return
	for child in vp.get_children():
		child.queue_free()
	var cluster := MeshInstance3D.new()
	cluster.name = "CrystalCluster"
	cluster.mesh = MeshFactory3D.build_crystal_cluster_mesh()
	cluster.material_override = MAT_CRYSTAL
	vp.add_child(cluster)

	var halo := MeshInstance3D.new()
	halo.name = "RuneHalo"
	halo.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.36, 0.41, 0.024, 18)
	halo.rotation.x = deg_to_rad(68.0)
	halo.material_override = MAT_FILIGREE
	vp.add_child(halo)


static func enhance_healing_orb(orb: Node3D) -> Dictionary:
	var result := {}
	var vp := orb.get_node_or_null("VisualPivot") as Node3D
	if not vp:
		return result

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.75, 1.0, 0.82, 1.0)
	ring_mat.metallic = 0.72
	ring_mat.roughness = 0.24
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.28, 0.96, 0.58, 1.0)
	ring_mat.emission_energy_multiplier = 1.4

	var ring1 := MeshInstance3D.new()
	ring1.name = "OrbitRing1"
	ring1.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.42, 0.48, 0.028, 22)
	ring1.rotation = Vector3(deg_to_rad(32.0), 0.0, deg_to_rad(18.0))
	ring1.material_override = ring_mat
	vp.add_child(ring1)

	var ring2 := MeshInstance3D.new()
	ring2.name = "OrbitRing2"
	ring2.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.52, 0.58, 0.026, 22)
	ring2.rotation = Vector3(deg_to_rad(-44.0), deg_to_rad(25.0), 0.0)
	ring2.material_override = MAT_FILIGREE
	vp.add_child(ring2)

	result["ring1"] = ring1
	result["ring2"] = ring2
	return result


static func enhance_golden_compass(compass: Node3D) -> Dictionary:
	var result := {}
	var vp := compass.get_node_or_null("VisualPivot") as Node3D
	if not vp:
		return result

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.84, 0.34, 1.0)
	gold_mat.metallic = 0.94
	gold_mat.roughness = 0.18
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.95, 0.72, 0.2, 1.0)
	gold_mat.emission_energy_multiplier = 0.9

	var bezel := vp.get_node_or_null("Bezel") as MeshInstance3D
	if bezel:
		bezel.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.46, 0.64, 0.12, 32)
		bezel.rotation = Vector3.ZERO
		bezel.material_override = gold_mat

	var outer_gimbal := MeshInstance3D.new()
	outer_gimbal.name = "OuterGimbal"
	outer_gimbal.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.72, 0.82, 0.055, 32)
	outer_gimbal.rotation = Vector3(deg_to_rad(28.0), deg_to_rad(18.0), 0.0)
	outer_gimbal.material_override = MAT_FILIGREE
	vp.add_child(outer_gimbal)

	var inner_gimbal := MeshInstance3D.new()
	inner_gimbal.name = "InnerGimbal"
	inner_gimbal.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.62, 0.70, 0.045, 28)
	inner_gimbal.rotation = Vector3(deg_to_rad(-36.0), 0.0, deg_to_rad(32.0))
	inner_gimbal.material_override = gold_mat
	vp.add_child(inner_gimbal)

	var rose := MeshInstance3D.new()
	rose.name = "CompassRose"
	rose.mesh = MeshFactory3D.build_compass_rose_mesh(0.42, 0.14)
	rose.position = Vector3(0.0, 0.0, 0.09)
	rose.material_override = gold_mat
	vp.add_child(rose)

	result["outer_gimbal"] = outer_gimbal
	result["inner_gimbal"] = inner_gimbal
	result["rose"] = rose
	return result


static func build_hidden_foliage_curtain(cover_group: Node3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_FOLIAGE
	mat.set_shader_parameter("foliage_tex", TEX_FERN_CARD)
	mat.set_shader_parameter("tint", Color(1.0, 1.0, 1.0, 1.0))
	mat.set_shader_parameter("wind_speed", 1.8)
	mat.set_shader_parameter("wind_strength", 0.16)
	mat.set_shader_parameter("emissive_spores", 1.1)

	if not cover_group:
		return mat

	for child in cover_group.get_children():
		child.queue_free()

	var branch_mat := mat.duplicate() as ShaderMaterial
	branch_mat.set_shader_parameter("foliage_tex", TEX_BRANCH_CARD)

	var offsets: Array[Vector3] = [
		Vector3(-1.8, 1.25, 0.35),
		Vector3(-0.6, 1.45, -0.25),
		Vector3(0.6, 1.4, 0.25),
		Vector3(1.8, 1.2, -0.2),
		Vector3(0.0, 2.2, 0.0),
	]
	for i in offsets.size():
		var bush := MeshInstance3D.new()
		bush.name = "FoliageVeil_%d" % i
		bush.mesh = MeshFactory3D.build_shrub_cluster_mesh(1.65, 14, 21 + i * 7)
		bush.position = offsets[i]
		bush.material_override = mat
		cover_group.add_child(bush)

	return mat
