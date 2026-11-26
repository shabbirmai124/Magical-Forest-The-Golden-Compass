extends RefCounted
## Builds realistic anatomical proportions & sculpted fantasy-ranger gear for the Explorer Hero:
## sculpted cranium/jawline & natural facial features, draped ranger cowl hood & rolled collar,
## flowing pleated cloth cape with velocity shader, fitted brigandine leather cuirass & split coat-tail,
## hip sword scabbard & mana flask, sculpted trousers & knee-high riding boots,
## wrought-iron lantern cage (shadow-clean), and fullered diamond-section Rune Broadsword.

const MeshFactory3D = preload("res://scenes/common/mesh_factory_3d.gd")
const SHADER_CLOAK: Shader = preload("res://resources/shaders/cloak_cloth_3d.gdshader")
const TEX_CLOAK_ALB: Texture2D = preload("res://assets/textures3d/char_cloak_albedo.png")
const TEX_CLOAK_N: Texture2D = preload("res://assets/textures3d/char_cloak_n.png")
const MAT_FILIGREE: StandardMaterial3D = preload("res://resources/materials3d/metal_filigree.tres")
const MAT_CLOAK: StandardMaterial3D = preload("res://resources/materials3d/char_cloak.tres")
const MAT_LEATHER: StandardMaterial3D = preload("res://resources/materials3d/char_leather.tres")
const MAT_CRYSTAL: StandardMaterial3D = preload("res://resources/materials3d/crystal_prism.tres")


static func enhance_explorer(player: Node3D) -> ShaderMaterial:
	var bp := player.get_node_or_null("VisualRig/BodyPivot") as Node3D
	if not bp:
		return null

	var cloak_mat := ShaderMaterial.new()
	cloak_mat.shader = SHADER_CLOAK
	cloak_mat.set_shader_parameter("albedo_tex", TEX_CLOAK_ALB)
	cloak_mat.set_shader_parameter("normal_tex", TEX_CLOAK_N)
	cloak_mat.set_shader_parameter("move_speed_norm", 0.0)

	var wool_dark := StandardMaterial3D.new()
	wool_dark.albedo_color = Color(0.11, 0.13, 0.14, 1.0)
	wool_dark.roughness = 0.92
	wool_dark.specular = 0.2

	var tunic_mat := StandardMaterial3D.new()
	tunic_mat.albedo_texture = TEX_CLOAK_ALB
	tunic_mat.normal_enabled = true
	tunic_mat.normal_texture = TEX_CLOAK_N
	tunic_mat.albedo_color = Color(0.76, 0.88, 0.82, 1.0)
	tunic_mat.roughness = 0.88
	tunic_mat.uv1_scale = Vector3(2.2, 2.2, 2.2)

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.84, 0.65, 0.52, 1.0)
	skin_mat.roughness = 0.56
	skin_mat.specular = 0.35
	skin_mat.rim_enabled = true
	skin_mat.rim = 0.18

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.17, 0.11, 0.07, 1.0)
	hair_mat.roughness = 0.72

	# Sculpted upper tunic & waist-down ranger coat-tail so torso blends cleanly into hips
	var torso := bp.get_node_or_null("Torso") as MeshInstance3D
	if torso:
		torso.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, -0.34, 0.01), "rx": 0.215, "rz": 0.175, "v": 0.0},
			{"center": Vector3(0.0, -0.14, 0.0), "rx": 0.175, "rz": 0.145, "v": 0.32},
			{"center": Vector3(0.0, 0.06, -0.01), "rx": 0.21, "rz": 0.16, "v": 0.65},
			{"center": Vector3(0.0, 0.24, 0.0), "rx": 0.23, "rz": 0.16, "v": 0.9},
			{"center": Vector3(0.0, 0.31, 0.0), "rx": 0.115, "rz": 0.105, "v": 1.0},
		], 16, true, 0, 0.0, false, true)
		torso.position = Vector3(0.0, 1.15, 0.0)
		torso.scale = Vector3.ONE
		torso.material_override = tunic_mat

	# Fitted Leather Brigandine Cuirass
	var vest := bp.get_node_or_null("LeatherVest") as MeshInstance3D
	if vest:
		vest.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, -0.18, 0.0), "rx": 0.188, "rz": 0.155, "v": 0.0},
			{"center": Vector3(0.0, -0.04, -0.01), "rx": 0.182, "rz": 0.15, "v": 0.35},
			{"center": Vector3(0.0, 0.11, -0.015), "rx": 0.228, "rz": 0.172, "v": 0.72},
			{"center": Vector3(0.0, 0.22, 0.0), "rx": 0.212, "rz": 0.155, "v": 1.0},
		], 16, true, 4, 0.018, false, true)
		vest.position = Vector3(0.0, 1.15, 0.0)
		vest.material_override = MAT_LEATHER

	# Neck & sculpted scarf collar
	var neck := MeshInstance3D.new()
	neck.name = "Neck"
	neck.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.06, 0.0), "rx": 0.072, "rz": 0.072, "v": 0.0},
		{"center": Vector3(0.0, 0.08, -0.005), "rx": 0.064, "rz": 0.066, "v": 1.0},
	], 12, true)
	neck.position = Vector3(0.0, 1.47, 0.0)
	neck.material_override = skin_mat
	bp.add_child(neck)

	# Flowing pleated cloth cloak + fitted shoulder mantle
	var cloak_pivot := bp.get_node_or_null("CloakPivot") as Node3D
	if cloak_pivot:
		for child in cloak_pivot.get_children():
			child.queue_free()
		var cape := MeshInstance3D.new()
		cape.name = "SculptedCape"
		cape.mesh = MeshFactory3D.build_curved_cloak_mesh(0.46, 0.94, 1.14, 10, 12)
		cape.material_override = cloak_mat
		cloak_pivot.add_child(cape)

		var mantlet := MeshInstance3D.new()
		mantlet.name = "ShoulderMantlet"
		mantlet.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, -0.14, -0.02), "rx": 0.34, "rz": 0.26, "v": 0.0},
			{"center": Vector3(0.0, 0.04, 0.0), "rx": 0.26, "rz": 0.21, "v": 1.0},
		], 14, false, 6, 0.028, false, true)
		mantlet.position = Vector3(0.0, 0.05, -0.14)
		mantlet.material_override = MAT_CLOAK
		cloak_pivot.add_child(mantlet)

	# Engraved brass belt buckle, hip mana flask & leather sword scabbard
	var buckle := bp.get_node_or_null("Buckle") as MeshInstance3D
	if buckle:
		buckle.material_override = MAT_FILIGREE

	var brooch := MeshInstance3D.new()
	brooch.name = "CompassBrooch"
	brooch.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.032, 0.058, 0.022, 16)
	brooch.position = Vector3(-0.07, 1.24, -0.175)
	brooch.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	brooch.material_override = MAT_FILIGREE
	bp.add_child(brooch)

	var potion := MeshInstance3D.new()
	potion.name = "ManaFlask"
	potion.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.075, 0.0), "rx": 0.038, "rz": 0.038, "v": 0.0},
		{"center": Vector3(0.0, -0.01, 0.0), "rx": 0.044, "rz": 0.044, "v": 0.5},
		{"center": Vector3(0.0, 0.045, 0.0), "rx": 0.018, "rz": 0.018, "v": 0.85},
		{"center": Vector3(0.0, 0.07, 0.0), "rx": 0.022, "rz": 0.022, "v": 1.0},
	], 10, true)
	potion.position = Vector3(0.24, 0.82, -0.08)
	potion.rotation.z = deg_to_rad(-8.0)
	potion.material_override = MAT_CRYSTAL
	bp.add_child(potion)

	var scabbard := MeshInstance3D.new()
	scabbard.name = "SwordScabbard"
	scabbard.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.34, 0.0), "rx": 0.024, "rz": 0.014, "v": 0.0},
		{"center": Vector3(0.0, 0.32, 0.0), "rx": 0.038, "rz": 0.02, "v": 1.0},
	], 8, true)
	scabbard.position = Vector3(0.22, 0.64, 0.1)
	scabbard.rotation = Vector3(deg_to_rad(32.0), 0.0, deg_to_rad(10.0))
	scabbard.material_override = MAT_LEATHER
	bp.add_child(scabbard)

	# Realistic sculpted anatomical head, hair, brow, eyes with sclera+iris, nose & draped ranger hood
	var hg := bp.get_node_or_null("HeadGroup") as Node3D
	if hg:
		var head := hg.get_node_or_null("Head") as MeshInstance3D
		if head:
			head.mesh = MeshFactory3D.build_sculpted_head_mesh()
			head.scale = Vector3.ONE
			head.material_override = skin_mat
		var bangs := hg.get_node_or_null("HairBangs") as MeshInstance3D
		if bangs:
			bangs.mesh = MeshFactory3D.build_lofted_tube_mesh([
				{"center": Vector3(0.0, -0.02, -0.02), "rx": 0.118, "rz": 0.128, "v": 0.0},
				{"center": Vector3(0.0, 0.055, -0.01), "rx": 0.122, "rz": 0.132, "v": 0.6},
				{"center": Vector3(0.0, 0.105, 0.01), "rx": 0.088, "rz": 0.105, "v": 1.0},
			], 14, true, 6, 0.04, false, true)
			bangs.position = Vector3(0.0, 0.045, 0.008)
			bangs.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)
			bangs.scale = Vector3.ONE
			bangs.material_override = hair_mat
		var hood := hg.get_node_or_null("Hood") as MeshInstance3D
		if hood:
			hood.mesh = MeshFactory3D.build_ranger_hood_mesh()
			hood.position = Vector3(0.0, 0.02, 0.018)
			hood.rotation = Vector3(deg_to_rad(-6.0), 0.0, 0.0)
			hood.scale = Vector3.ONE
			hood.material_override = cloak_mat
		var nose := hg.get_node_or_null("Nose") as MeshInstance3D
		if nose:
			nose.position = Vector3(0.0, -0.022, -0.142)
			nose.scale = Vector3(0.07, 0.12, 0.08)
			nose.material_override = skin_mat
		var sclera_mat := StandardMaterial3D.new()
		sclera_mat.albedo_color = Color(0.92, 0.92, 0.9, 1.0)
		sclera_mat.roughness = 0.25
		for eye_side in [["EyeLeft", -0.042], ["EyeRight", 0.042]]:
			var ex := float(eye_side[1])
			var eye := hg.get_node_or_null(eye_side[0]) as MeshInstance3D
			if eye:
				eye.position = Vector3(ex, 0.012, -0.128)
				eye.scale = Vector3(0.052, 0.044, 0.036)
				var mat_e := StandardMaterial3D.new()
				mat_e.albedo_color = Color(0.14, 0.34, 0.38)
				mat_e.roughness = 0.12
				mat_e.metallic = 0.18
				eye.material_override = mat_e
			var brow := MeshInstance3D.new()
			brow.name = "Brow_" + String(eye_side[0])
			brow.mesh = BoxMesh.new()
			(brow.mesh as BoxMesh).size = Vector3(0.046, 0.01, 0.018)
			brow.position = Vector3(ex, 0.044, -0.13)
			brow.rotation.z = deg_to_rad(6.0 if ex < 0.0 else -6.0)
			brow.material_override = hair_mat
			hg.add_child(brow)

	# Articulated trousers, knee guards & knee-jointed riding boots
	for leg_name in ["LeftLegPivot", "RightLegPivot"]:
		var lp := bp.get_node_or_null(leg_name) as Node3D
		if lp:
			var thigh := lp.get_node_or_null("Thigh") as MeshInstance3D
			if thigh:
				thigh.mesh = MeshFactory3D.build_lofted_tube_mesh([
					{"center": Vector3(0.0, -0.21, 0.0), "rx": 0.068, "rz": 0.072, "v": 0.0},
					{"center": Vector3(0.0, 0.0, 0.0), "rx": 0.088, "rz": 0.092, "v": 0.55},
					{"center": Vector3(0.0, 0.21, 0.0), "rx": 0.1, "rz": 0.104, "v": 1.0},
				], 12, true)
				thigh.position = Vector3(0.0, -0.21, 0.0)
				thigh.material_override = wool_dark
			var knee_pivot := Node3D.new()
			knee_pivot.name = "KneePivot"
			knee_pivot.position = Vector3(0.0, -0.42, 0.0)
			lp.add_child(knee_pivot)
			var kpad := MeshInstance3D.new()
			kpad.name = "KneePad"
			kpad.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.072, 0.062, 0.055), 55)
			kpad.position = Vector3(0.0, 0.01, -0.045)
			kpad.material_override = MAT_LEATHER
			knee_pivot.add_child(kpad)
			var boot := lp.get_node_or_null("Boot") as MeshInstance3D
			if boot:
				lp.remove_child(boot)
				knee_pivot.add_child(boot)
				boot.mesh = MeshFactory3D.build_ranger_boot_mesh(0.44)
				boot.position = Vector3(0.0, 0.0, 0.0)
				boot.material_override = MAT_LEATHER

	# Articulated sleeves, elbow joints, leather vambraces, gloved hands & swinging iron lantern
	var la := bp.get_node_or_null("LeftArmPivot") as Node3D
	if la:
		var arm_l := la.get_node_or_null("Arm") as MeshInstance3D
		if arm_l:
			arm_l.mesh = MeshFactory3D.build_lofted_tube_mesh([
				{"center": Vector3(0.0, -0.14, 0.0), "rx": 0.062, "rz": 0.062, "v": 0.0},
				{"center": Vector3(0.0, 0.04, 0.0), "rx": 0.076, "rz": 0.076, "v": 0.55},
				{"center": Vector3(0.0, 0.16, 0.0), "rx": 0.086, "rz": 0.086, "v": 1.0},
			], 10, true)
			arm_l.position = Vector3(0.0, -0.12, -0.02)
			arm_l.rotation = Vector3.ZERO
			arm_l.material_override = tunic_mat
		var l_elbow := Node3D.new()
		l_elbow.name = "ElbowPivot"
		l_elbow.position = Vector3(0.0, -0.24, -0.03)
		la.add_child(l_elbow)

		var bracer_l := MeshInstance3D.new()
		bracer_l.name = "LeftBracer"
		bracer_l.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, -0.18, 0.0), "rx": 0.052, "rz": 0.052, "v": 0.0},
			{"center": Vector3(0.0, 0.02, 0.0), "rx": 0.066, "rz": 0.066, "v": 1.0},
		], 10, true)
		bracer_l.position = Vector3(0.0, -0.04, -0.04)
		bracer_l.rotation.x = deg_to_rad(28.0)
		bracer_l.material_override = MAT_LEATHER
		l_elbow.add_child(bracer_l)

		var glove_l := MeshInstance3D.new()
		glove_l.name = "LeftGlove"
		glove_l.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.054, 0.05, 0.064), 41)
		glove_l.position = Vector3(-0.015, -0.2, -0.15)
		glove_l.material_override = MAT_LEATHER
		l_elbow.add_child(glove_l)

		var lantern_swing := Node3D.new()
		lantern_swing.name = "LanternSwingPivot"
		lantern_swing.position = Vector3(-0.02, -0.21, -0.17)
		l_elbow.add_child(lantern_swing)

		for ln_part in ["LanternTop", "LanternCore", "LanternBase"]:
			var part_mi := la.get_node_or_null(ln_part) as MeshInstance3D
			if part_mi:
				var rel_y := part_mi.position.y + 0.43
				la.remove_child(part_mi)
				lantern_swing.add_child(part_mi)
				part_mi.position = Vector3(0.0, rel_y, 0.0)
				part_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var cage := MeshInstance3D.new()
		cage.name = "LanternIronCage"
		cage.mesh = MeshFactory3D.build_lantern_cage_mesh(0.115, 0.26)
		cage.position = Vector3(0.0, -0.19, 0.0)
		cage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cage.material_override = MAT_FILIGREE
		lantern_swing.add_child(cage)

		var bail := MeshInstance3D.new()
		bail.name = "LanternBail"
		bail.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.045, 0.068, 0.018, 14)
		bail.position = Vector3(0.0, 0.0, 0.0)
		bail.rotation = Vector3(0.0, 0.0, PI * 0.5)
		bail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bail.material_override = MAT_FILIGREE
		lantern_swing.add_child(bail)

		var l_light := la.get_node_or_null("LanternLight") as OmniLight3D
		if l_light:
			l_light.shadow_enabled = false
			l_light.light_energy = 2.15
			l_light.omni_range = 15.0

	# Right arm elbow + bracer + ornate fullered Rune Broadsword
	var ra := bp.get_node_or_null("RightArmPivot") as Node3D
	if ra:
		var arm_r := ra.get_node_or_null("Arm") as MeshInstance3D
		if arm_r:
			arm_r.mesh = MeshFactory3D.build_lofted_tube_mesh([
				{"center": Vector3(0.0, -0.14, 0.0), "rx": 0.062, "rz": 0.062, "v": 0.0},
				{"center": Vector3(0.0, 0.04, 0.0), "rx": 0.076, "rz": 0.076, "v": 0.55},
				{"center": Vector3(0.0, 0.16, 0.0), "rx": 0.086, "rz": 0.086, "v": 1.0},
			], 10, true)
			arm_r.position = Vector3(0.0, -0.12, -0.02)
			arm_r.rotation = Vector3.ZERO
			arm_r.material_override = tunic_mat
		var r_elbow := Node3D.new()
		r_elbow.name = "ElbowPivot"
		r_elbow.position = Vector3(0.0, -0.24, -0.03)
		ra.add_child(r_elbow)

		var bracer_r := MeshInstance3D.new()
		bracer_r.name = "RightBracer"
		bracer_r.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, -0.18, 0.0), "rx": 0.052, "rz": 0.052, "v": 0.0},
			{"center": Vector3(0.0, 0.02, 0.0), "rx": 0.066, "rz": 0.066, "v": 1.0},
		], 10, true)
		bracer_r.position = Vector3(0.0, -0.04, -0.04)
		bracer_r.rotation.x = deg_to_rad(28.0)
		bracer_r.material_override = MAT_LEATHER
		r_elbow.add_child(bracer_r)

		var glove_r := MeshInstance3D.new()
		glove_r.name = "RightGlove"
		glove_r.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.054, 0.05, 0.064), 42)
		glove_r.position = Vector3(0.015, -0.18, -0.15)
		glove_r.material_override = MAT_LEATHER
		r_elbow.add_child(glove_r)

		var guard := ra.get_node_or_null("Guard") as MeshInstance3D
		if guard:
			ra.remove_child(guard)
			r_elbow.add_child(guard)
			guard.mesh = MeshFactory3D.build_lofted_tube_mesh([
				{"center": Vector3(-0.22, 0.0, 0.0), "rx": 0.024, "rz": 0.032, "v": 0.0},
				{"center": Vector3(0.0, 0.0, 0.0), "rx": 0.052, "rz": 0.046, "v": 0.5},
				{"center": Vector3(0.22, 0.0, 0.0), "rx": 0.024, "rz": 0.032, "v": 1.0},
			], 8, true)
			guard.position = Vector3(0.02, -0.17, -0.20)
			guard.material_override = MAT_FILIGREE
		var blade := ra.get_node_or_null("SwordBlade") as MeshInstance3D
		if blade:
			ra.remove_child(blade)
			r_elbow.add_child(blade)
			blade.mesh = MeshFactory3D.build_sculpted_sword_mesh()
			blade.position = Vector3(0.02, -0.17, -0.20)
			blade.rotation = Vector3(deg_to_rad(14.0), 0.0, 0.0)
		var grip := MeshInstance3D.new()
		grip.name = "SwordGrip"
		grip.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, 0.0, -0.02), "rx": 0.022, "rz": 0.026, "v": 0.0},
			{"center": Vector3(0.0, 0.0, 0.14), "rx": 0.02, "rz": 0.024, "v": 1.0},
		], 8, true)
		grip.position = Vector3(0.02, -0.17, -0.14)
		grip.rotation = Vector3(deg_to_rad(104.0), 0.0, 0.0)
		grip.material_override = MAT_LEATHER
		r_elbow.add_child(grip)

		var gem := MeshInstance3D.new()
		gem.name = "HiltGem"
		gem.mesh = MeshFactory3D.build_rune_shard_mesh(0.032, 0.085, 3)
		gem.position = Vector3(0.02, -0.17, -0.02)
		gem.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		gem.material_override = MAT_CRYSTAL
		r_elbow.add_child(gem)

	return cloak_mat
