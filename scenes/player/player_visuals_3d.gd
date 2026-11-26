extends RefCounted
## Builds ultra-realistic anatomical proportions & layered PBR dark-fantasy ranger gear for the Explorer Hero:
## sculpted cranium/cheekbones/jawline, sclera + luminous irises + pupils, sculpted ears & brow ridge,
## woven neck scarf & draped multi-fold ranger cowl hood, flowing pleated cloth cape with velocity shader,
## quilted gambeson tunic, riveted leather brigandine cuirass with diagonal baldric & live Golden Compass brooch,
## articulated layered pauldrons with brass filigree trim, hip pouches, mana flask & brass-chape sword scabbard,
## reinforced cuisses, riveted knee poleyns, sculpted greaves & riding boots, articulated vambraces & gauntlets,
## wrought-iron lantern with glowing inner filament, and fullered diamond Rune Broadsword with glowing fuller channel.

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
	wool_dark.albedo_color = Color(0.11, 0.13, 0.145, 1.0)
	wool_dark.roughness = 0.90
	wool_dark.specular = 0.22

	var scarf_mat := StandardMaterial3D.new()
	scarf_mat.albedo_texture = TEX_CLOAK_ALB
	scarf_mat.normal_enabled = true
	scarf_mat.normal_texture = TEX_CLOAK_N
	scarf_mat.albedo_color = Color(0.22, 0.36, 0.33, 1.0)
	scarf_mat.roughness = 0.88
	scarf_mat.uv1_scale = Vector3(3.0, 3.0, 3.0)

	var tunic_mat := StandardMaterial3D.new()
	tunic_mat.albedo_texture = TEX_CLOAK_ALB
	tunic_mat.normal_enabled = true
	tunic_mat.normal_texture = TEX_CLOAK_N
	tunic_mat.albedo_color = Color(0.76, 0.88, 0.82, 1.0)
	tunic_mat.roughness = 0.86
	tunic_mat.uv1_scale = Vector3(2.4, 2.4, 2.4)

	var dark_steel_mat := StandardMaterial3D.new()
	dark_steel_mat.albedo_color = Color(0.24, 0.27, 0.31, 1.0)
	dark_steel_mat.metallic = 0.84
	dark_steel_mat.roughness = 0.32
	dark_steel_mat.specular = 0.65

	var burnished_gold := StandardMaterial3D.new()
	burnished_gold.albedo_color = Color(0.96, 0.78, 0.32, 1.0)
	burnished_gold.metallic = 0.94
	burnished_gold.roughness = 0.20
	burnished_gold.emission_enabled = true
	burnished_gold.emission = Color(0.86, 0.64, 0.16, 1.0)
	burnished_gold.emission_energy_multiplier = 0.55

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.84, 0.65, 0.52, 1.0)
	skin_mat.roughness = 0.54
	skin_mat.specular = 0.36
	skin_mat.rim_enabled = true
	skin_mat.rim = 0.22
	skin_mat.rim_tint = 0.35

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.16, 0.105, 0.068, 1.0)
	hair_mat.roughness = 0.68

	var rune_blade_glow := StandardMaterial3D.new()
	rune_blade_glow.albedo_color = Color(0.55, 0.96, 1.0, 1.0)
	rune_blade_glow.emission_enabled = true
	rune_blade_glow.emission = Color(0.32, 0.92, 1.0, 1.0)
	rune_blade_glow.emission_energy_multiplier = 2.6

	# Sculpted upper tunic & waist-down ranger coat-tail so torso blends cleanly into hips
	var torso := bp.get_node_or_null("Torso") as MeshInstance3D
	if torso:
		torso.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, -0.35, 0.01), "rx": 0.22, "rz": 0.178, "v": 0.0},
			{"center": Vector3(0.0, -0.14, 0.0), "rx": 0.176, "rz": 0.146, "v": 0.32},
			{"center": Vector3(0.0, 0.07, -0.012), "rx": 0.214, "rz": 0.162, "v": 0.66},
			{"center": Vector3(0.0, 0.245, 0.0), "rx": 0.236, "rz": 0.164, "v": 0.9},
			{"center": Vector3(0.0, 0.315, 0.0), "rx": 0.115, "rz": 0.105, "v": 1.0},
		], 18, true, 0, 0.0, false, true)
		torso.position = Vector3(0.0, 1.15, 0.0)
		torso.scale = Vector3.ONE
		torso.material_override = tunic_mat

	# Fitted Leather Brigandine Cuirass with sculpted chest contours
	var vest := bp.get_node_or_null("LeatherVest") as MeshInstance3D
	if vest:
		vest.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, -0.18, 0.0), "rx": 0.19, "rz": 0.156, "v": 0.0},
			{"center": Vector3(0.0, -0.04, -0.01), "rx": 0.184, "rz": 0.152, "v": 0.35},
			{"center": Vector3(0.0, 0.11, -0.018), "rx": 0.232, "rz": 0.176, "v": 0.72},
			{"center": Vector3(0.0, 0.225, 0.0), "rx": 0.216, "rz": 0.158, "v": 1.0},
		], 18, true, 4, 0.016, false, true)
		vest.position = Vector3(0.0, 1.15, 0.0)
		vest.material_override = MAT_LEATHER

	# Steel gorget / collar plate & diagonal leather baldric across torso
	var gorget := MeshInstance3D.new()
	gorget.name = "SteelGorget"
	gorget.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.05, -0.008), "rx": 0.175, "rz": 0.145, "v": 0.0},
		{"center": Vector3(0.0, 0.045, 0.0), "rx": 0.128, "rz": 0.118, "v": 1.0},
	], 16, true)
	gorget.position = Vector3(0.0, 1.385, 0.0)
	gorget.material_override = dark_steel_mat
	bp.add_child(gorget)

	var baldric := MeshInstance3D.new()
	baldric.name = "ChestBaldric"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.058, 0.56, 0.365)
	baldric.mesh = bm
	baldric.position = Vector3(0.0, 1.16, -0.005)
	baldric.rotation = Vector3(0.0, 0.0, deg_to_rad(-34.0))
	baldric.material_override = MAT_LEATHER
	bp.add_child(baldric)

	# Neck & layered woven ranger scarf collar
	var neck := MeshInstance3D.new()
	neck.name = "Neck"
	neck.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.06, 0.0), "rx": 0.072, "rz": 0.072, "v": 0.0},
		{"center": Vector3(0.0, 0.08, -0.005), "rx": 0.064, "rz": 0.066, "v": 1.0},
	], 14, true)
	neck.position = Vector3(0.0, 1.47, 0.0)
	neck.material_override = skin_mat
	bp.add_child(neck)

	var scarf := MeshInstance3D.new()
	scarf.name = "RangerScarf"
	scarf.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.055, -0.006), "rx": 0.142, "rz": 0.132, "v": 0.0},
		{"center": Vector3(0.0, 0.005, -0.01), "rx": 0.128, "rz": 0.122, "v": 0.55},
		{"center": Vector3(0.0, 0.055, -0.004), "rx": 0.104, "rz": 0.102, "v": 1.0},
	], 16, true, 6, 0.012, false, true)
	scarf.position = Vector3(0.0, 1.445, 0.0)
	scarf.material_override = scarf_mat
	bp.add_child(scarf)

	# Flowing pleated cloth cloak + fitted shoulder mantle
	var cloak_pivot := bp.get_node_or_null("CloakPivot") as Node3D
	if cloak_pivot:
		for child in cloak_pivot.get_children():
			child.queue_free()
		var cape := MeshInstance3D.new()
		cape.name = "SculptedCape"
		cape.mesh = MeshFactory3D.build_curved_cloak_mesh(0.48, 0.98, 1.18, 12, 14)
		cape.material_override = cloak_mat
		cloak_pivot.add_child(cape)

		var mantlet := MeshInstance3D.new()
		mantlet.name = "ShoulderMantlet"
		mantlet.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, -0.15, -0.02), "rx": 0.35, "rz": 0.27, "v": 0.0},
			{"center": Vector3(0.0, 0.04, 0.0), "rx": 0.265, "rz": 0.215, "v": 1.0},
		], 16, false, 8, 0.024, false, true)
		mantlet.position = Vector3(0.0, 0.05, -0.14)
		mantlet.material_override = MAT_CLOAK
		cloak_pivot.add_child(mantlet)

	# Engraved brass belt buckle, waist pouches, live Golden Compass relic brooch, mana flask & scabbard
	var buckle := bp.get_node_or_null("Buckle") as MeshInstance3D
	if buckle:
		buckle.material_override = burnished_gold

	for pouch_side in [-1.0, 1.0]:
		var pouch := MeshInstance3D.new()
		pouch.name = "BeltPouchL" if pouch_side < 0.0 else "BeltPouchR"
		pouch.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.058, 0.072, 0.044), 31 if pouch_side < 0.0 else 37)
		pouch.position = Vector3(pouch_side * 0.205, 0.89, -0.05)
		pouch.material_override = MAT_LEATHER
		bp.add_child(pouch)

	# Active Golden Compass Brooch on Chest (rotates live needle toward objective!)
	var brooch_root := Node3D.new()
	brooch_root.name = "CompassBrooch"
	brooch_root.position = Vector3(-0.075, 1.245, -0.184)
	brooch_root.rotation = Vector3(deg_to_rad(82.0), 0.0, 0.0)
	bp.add_child(brooch_root)

	var brooch_ring := MeshInstance3D.new()
	brooch_ring.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.038, 0.064, 0.022, 20)
	brooch_ring.material_override = burnished_gold
	brooch_root.add_child(brooch_ring)

	var brooch_dial := MeshInstance3D.new()
	var dcm := CylinderMesh.new()
	dcm.top_radius = 0.042
	dcm.bottom_radius = 0.042
	dcm.height = 0.012
	brooch_dial.mesh = dcm
	var dial_mat := StandardMaterial3D.new()
	dial_mat.albedo_color = Color(0.08, 0.12, 0.15, 1.0)
	dial_mat.roughness = 0.18
	dial_mat.metallic = 0.35
	brooch_dial.material_override = dial_mat
	brooch_root.add_child(brooch_dial)

	var brooch_needle := MeshInstance3D.new()
	brooch_needle.name = "CompassBroochNeedle"
	var nm := BoxMesh.new()
	nm.size = Vector3(0.014, 0.016, 0.072)
	brooch_needle.mesh = nm
	brooch_needle.position = Vector3(0.0, 0.012, 0.0)
	var needle_mat := StandardMaterial3D.new()
	needle_mat.albedo_color = Color(1.0, 0.9, 0.38, 1.0)
	needle_mat.emission_enabled = true
	needle_mat.emission = Color(1.0, 0.82, 0.25, 1.0)
	needle_mat.emission_energy_multiplier = 2.8
	brooch_needle.material_override = needle_mat
	brooch_root.add_child(brooch_needle)

	var potion := MeshInstance3D.new()
	potion.name = "ManaFlask"
	potion.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.075, 0.0), "rx": 0.038, "rz": 0.038, "v": 0.0},
		{"center": Vector3(0.0, -0.01, 0.0), "rx": 0.044, "rz": 0.044, "v": 0.5},
		{"center": Vector3(0.0, 0.045, 0.0), "rx": 0.018, "rz": 0.018, "v": 0.85},
		{"center": Vector3(0.0, 0.07, 0.0), "rx": 0.022, "rz": 0.022, "v": 1.0},
	], 12, true)
	potion.position = Vector3(0.245, 0.82, -0.08)
	potion.rotation.z = deg_to_rad(-8.0)
	potion.material_override = MAT_CRYSTAL
	bp.add_child(potion)

	var scabbard := MeshInstance3D.new()
	scabbard.name = "SwordScabbard"
	scabbard.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.36, 0.0), "rx": 0.022, "rz": 0.013, "v": 0.0},
		{"center": Vector3(0.0, 0.33, 0.0), "rx": 0.038, "rz": 0.02, "v": 1.0},
	], 10, true)
	scabbard.position = Vector3(0.225, 0.64, 0.1)
	scabbard.rotation = Vector3(deg_to_rad(32.0), 0.0, deg_to_rad(10.0))
	scabbard.material_override = MAT_LEATHER
	bp.add_child(scabbard)

	var chape := MeshInstance3D.new()
	chape.name = "ScabbardChape"
	chape.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0.0, -0.38, 0.0), "rx": 0.012, "rz": 0.008, "v": 0.0},
		{"center": Vector3(0.0, -0.26, 0.0), "rx": 0.028, "rz": 0.017, "v": 1.0},
	], 8, true)
	chape.material_override = burnished_gold
	scabbard.add_child(chape)

	# Ultra-realistic sculpted anatomical head, ears, hair, arched brows, layered sclera + iris + pupil, nose & draped ranger hood
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
				{"center": Vector3(0.0, -0.022, -0.02), "rx": 0.118, "rz": 0.128, "v": 0.0},
				{"center": Vector3(0.0, 0.055, -0.01), "rx": 0.124, "rz": 0.134, "v": 0.6},
				{"center": Vector3(0.0, 0.108, 0.01), "rx": 0.088, "rz": 0.105, "v": 1.0},
			], 16, true, 6, 0.036, false, true)
			bangs.position = Vector3(0.0, 0.045, 0.008)
			bangs.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)
			bangs.scale = Vector3.ONE
			bangs.material_override = hair_mat
		var hood := hg.get_node_or_null("Hood") as MeshInstance3D
		if hood:
			hood.mesh = MeshFactory3D.build_ranger_hood_mesh()
			hood.position = Vector3(0.0, 0.022, 0.018)
			hood.rotation = Vector3(deg_to_rad(-6.0), 0.0, 0.0)
			hood.scale = Vector3.ONE
			hood.material_override = cloak_mat
		var nose := hg.get_node_or_null("Nose") as MeshInstance3D
		if nose:
			nose.position = Vector3(0.0, -0.02, -0.14)
			nose.scale = Vector3(0.062, 0.115, 0.078)
			nose.material_override = skin_mat

		for ear_side in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			ear.name = "EarL" if ear_side < 0.0 else "EarR"
			ear.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.018, 0.038, 0.024), 19)
			ear.position = Vector3(ear_side * 0.112, -0.008, -0.008)
			ear.material_override = skin_mat
			hg.add_child(ear)

		var sclera_mat := StandardMaterial3D.new()
		sclera_mat.albedo_color = Color(0.94, 0.93, 0.91, 1.0)
		sclera_mat.roughness = 0.18

		var pupil_mat := StandardMaterial3D.new()
		pupil_mat.albedo_color = Color(0.03, 0.04, 0.05, 1.0)
		pupil_mat.roughness = 0.08

		var sclera_mesh := SphereMesh.new()
		sclera_mesh.radius = 0.023
		sclera_mesh.height = 0.040

		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.0085
		pupil_mesh.height = 0.017

		for eye_side in [["EyeLeft", -0.042], ["EyeRight", 0.042]]:
			var ex := float(eye_side[1])
			var sclera := MeshInstance3D.new()
			sclera.name = "Sclera_" + String(eye_side[0])
			sclera.mesh = sclera_mesh
			sclera.position = Vector3(ex, 0.012, -0.118)
			sclera.scale = Vector3(1.15, 0.85, 0.72)
			sclera.material_override = sclera_mat
			hg.add_child(sclera)

			var eye := hg.get_node_or_null(eye_side[0]) as MeshInstance3D
			if eye:
				eye.position = Vector3(ex, 0.012, -0.132)
				eye.scale = Vector3(0.034, 0.032, 0.024)
				var mat_e := StandardMaterial3D.new()
				mat_e.albedo_color = Color(0.18, 0.44, 0.42, 1.0)
				mat_e.roughness = 0.09
				mat_e.metallic = 0.15
				mat_e.emission_enabled = true
				mat_e.emission = Color(0.12, 0.36, 0.34, 1.0)
				mat_e.emission_energy_multiplier = 0.35
				eye.material_override = mat_e

			var pupil := MeshInstance3D.new()
			pupil.name = "Pupil_" + String(eye_side[0])
			pupil.mesh = pupil_mesh
			pupil.position = Vector3(ex, 0.012, -0.139)
			pupil.material_override = pupil_mat
			hg.add_child(pupil)

			var brow := MeshInstance3D.new()
			brow.name = "Brow_" + String(eye_side[0])
			var brm := BoxMesh.new()
			brm.size = Vector3(0.048, 0.011, 0.018)
			brow.mesh = brm
			brow.position = Vector3(ex, 0.043, -0.131)
			brow.rotation.z = deg_to_rad(7.0 if ex < 0.0 else -7.0)
			brow.material_override = hair_mat
			hg.add_child(brow)

	# Articulated trousers, reinforced leather thigh cuisses, riveted steel knee poleyns & sculpted riding boots
	for leg_name in ["LeftLegPivot", "RightLegPivot"]:
		var lp := bp.get_node_or_null(leg_name) as Node3D
		if lp:
			var thigh := lp.get_node_or_null("Thigh") as MeshInstance3D
			if thigh:
				thigh.mesh = MeshFactory3D.build_lofted_tube_mesh([
					{"center": Vector3(0.0, -0.21, 0.0), "rx": 0.068, "rz": 0.072, "v": 0.0},
					{"center": Vector3(0.0, 0.0, 0.0), "rx": 0.09, "rz": 0.094, "v": 0.55},
					{"center": Vector3(0.0, 0.21, 0.0), "rx": 0.102, "rz": 0.106, "v": 1.0},
				], 14, true)
				thigh.position = Vector3(0.0, -0.21, 0.0)
				thigh.material_override = wool_dark

			var cuisse := MeshInstance3D.new()
			cuisse.name = "ThighCuisse"
			cuisse.mesh = MeshFactory3D.build_lofted_tube_mesh([
				{"center": Vector3(0.0, -0.09, -0.015), "rx": 0.078, "rz": 0.072, "v": 0.0},
				{"center": Vector3(0.0, 0.08, -0.012), "rx": 0.094, "rz": 0.088, "v": 1.0},
			], 12, true)
			cuisse.position = Vector3(0.0, -0.20, -0.008)
			cuisse.material_override = MAT_LEATHER
			lp.add_child(cuisse)

			var knee_pivot := Node3D.new()
			knee_pivot.name = "KneePivot"
			knee_pivot.position = Vector3(0.0, -0.42, 0.0)
			lp.add_child(knee_pivot)

			var kpad := MeshInstance3D.new()
			kpad.name = "KneePad"
			kpad.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.074, 0.066, 0.058), 55)
			kpad.position = Vector3(0.0, 0.01, -0.048)
			kpad.material_override = dark_steel_mat
			knee_pivot.add_child(kpad)

			var ktrim := MeshInstance3D.new()
			ktrim.name = "KneeTrim"
			ktrim.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.022, 0.036, 0.012, 12)
			ktrim.position = Vector3(0.0, 0.01, -0.098)
			ktrim.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			ktrim.material_override = burnished_gold
			knee_pivot.add_child(ktrim)

			var boot := lp.get_node_or_null("Boot") as MeshInstance3D
			if boot:
				lp.remove_child(boot)
				knee_pivot.add_child(boot)
				boot.mesh = MeshFactory3D.build_ranger_boot_mesh(0.44)
				boot.position = Vector3(0.0, 0.0, 0.0)
				boot.material_override = MAT_LEATHER

	# Articulated sleeves, layered pauldrons, elbow joints, vambraces, gauntlets & swinging wrought-iron lantern
	var la := bp.get_node_or_null("LeftArmPivot") as Node3D
	if la:
		_add_layered_pauldron(la, -1.0, dark_steel_mat, burnished_gold)
		var arm_l := la.get_node_or_null("Arm") as MeshInstance3D
		if arm_l:
			arm_l.mesh = MeshFactory3D.build_lofted_tube_mesh([
				{"center": Vector3(0.0, -0.14, 0.0), "rx": 0.062, "rz": 0.062, "v": 0.0},
				{"center": Vector3(0.0, 0.04, 0.0), "rx": 0.076, "rz": 0.076, "v": 0.55},
				{"center": Vector3(0.0, 0.16, 0.0), "rx": 0.088, "rz": 0.088, "v": 1.0},
			], 12, true)
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
			{"center": Vector3(0.0, 0.02, 0.0), "rx": 0.068, "rz": 0.068, "v": 1.0},
		], 12, true)
		bracer_l.position = Vector3(0.0, -0.04, -0.04)
		bracer_l.rotation.x = deg_to_rad(28.0)
		bracer_l.material_override = MAT_LEATHER
		l_elbow.add_child(bracer_l)

		var bracer_l_band := MeshInstance3D.new()
		bracer_l_band.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.052, 0.066, 0.02, 14)
		bracer_l_band.position = Vector3(0.0, -0.13, -0.09)
		bracer_l_band.rotation.x = deg_to_rad(28.0)
		bracer_l_band.material_override = burnished_gold
		l_elbow.add_child(bracer_l_band)

		var glove_l := MeshInstance3D.new()
		glove_l.name = "LeftGlove"
		glove_l.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.054, 0.048, 0.066), 41)
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
		bail.material_override = burnished_gold
		lantern_swing.add_child(bail)

		var l_light := la.get_node_or_null("LanternLight") as OmniLight3D
		if l_light:
			l_light.shadow_enabled = false
			l_light.light_energy = 2.35
			l_light.omni_range = 16.5

	# Right arm pauldron + elbow + vambrace + ornate fullered Rune Broadsword with glowing fuller channel
	var ra := bp.get_node_or_null("RightArmPivot") as Node3D
	if ra:
		_add_layered_pauldron(ra, 1.0, dark_steel_mat, burnished_gold)
		var arm_r := ra.get_node_or_null("Arm") as MeshInstance3D
		if arm_r:
			arm_r.mesh = MeshFactory3D.build_lofted_tube_mesh([
				{"center": Vector3(0.0, -0.14, 0.0), "rx": 0.062, "rz": 0.062, "v": 0.0},
				{"center": Vector3(0.0, 0.04, 0.0), "rx": 0.076, "rz": 0.076, "v": 0.55},
				{"center": Vector3(0.0, 0.16, 0.0), "rx": 0.088, "rz": 0.088, "v": 1.0},
			], 12, true)
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
			{"center": Vector3(0.0, 0.02, 0.0), "rx": 0.068, "rz": 0.068, "v": 1.0},
		], 12, true)
		bracer_r.position = Vector3(0.0, -0.04, -0.04)
		bracer_r.rotation.x = deg_to_rad(28.0)
		bracer_r.material_override = MAT_LEATHER
		r_elbow.add_child(bracer_r)

		var bracer_r_band := MeshInstance3D.new()
		bracer_r_band.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.052, 0.066, 0.02, 14)
		bracer_r_band.position = Vector3(0.0, -0.13, -0.09)
		bracer_r_band.rotation.x = deg_to_rad(28.0)
		bracer_r_band.material_override = burnished_gold
		r_elbow.add_child(bracer_r_band)

		var glove_r := MeshInstance3D.new()
		glove_r.name = "RightGlove"
		glove_r.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.054, 0.048, 0.066), 42)
		glove_r.position = Vector3(0.015, -0.18, -0.15)
		glove_r.material_override = MAT_LEATHER
		r_elbow.add_child(glove_r)

		var guard := ra.get_node_or_null("Guard") as MeshInstance3D
		if guard:
			ra.remove_child(guard)
			r_elbow.add_child(guard)
			guard.mesh = MeshFactory3D.build_lofted_tube_mesh([
				{"center": Vector3(-0.24, 0.01, -0.02), "rx": 0.022, "rz": 0.03, "v": 0.0},
				{"center": Vector3(0.0, 0.0, 0.0), "rx": 0.056, "rz": 0.048, "v": 0.5},
				{"center": Vector3(0.24, 0.01, -0.02), "rx": 0.022, "rz": 0.03, "v": 1.0},
			], 10, true)
			guard.position = Vector3(0.02, -0.17, -0.20)
			guard.material_override = burnished_gold

		var blade := ra.get_node_or_null("SwordBlade") as MeshInstance3D
		if blade:
			ra.remove_child(blade)
			r_elbow.add_child(blade)
			blade.mesh = MeshFactory3D.build_sculpted_sword_mesh()
			blade.position = Vector3(0.02, -0.17, -0.20)
			blade.rotation = Vector3(deg_to_rad(14.0), 0.0, 0.0)

			var fuller := MeshInstance3D.new()
			fuller.name = "RuneFullerGlow"
			var fm := BoxMesh.new()
			fm.size = Vector3(0.018, 0.022, 0.72)
			fuller.mesh = fm
			fuller.position = Vector3(0.0, 0.0, -0.44)
			fuller.material_override = rune_blade_glow
			blade.add_child(fuller)

		var grip := MeshInstance3D.new()
		grip.name = "SwordGrip"
		grip.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0.0, 0.0, -0.02), "rx": 0.022, "rz": 0.026, "v": 0.0},
			{"center": Vector3(0.0, 0.0, 0.14), "rx": 0.02, "rz": 0.024, "v": 1.0},
		], 10, true)
		grip.position = Vector3(0.02, -0.17, -0.14)
		grip.rotation = Vector3(deg_to_rad(104.0), 0.0, 0.0)
		grip.material_override = MAT_LEATHER
		r_elbow.add_child(grip)

		var gem := MeshInstance3D.new()
		gem.name = "HiltGem"
		gem.mesh = MeshFactory3D.build_rune_shard_mesh(0.034, 0.09, 3)
		gem.position = Vector3(0.02, -0.17, -0.02)
		gem.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		gem.material_override = MAT_CRYSTAL
		r_elbow.add_child(gem)

	return cloak_mat


static func _add_layered_pauldron(arm_pivot: Node3D, side_sgn: float, steel_mat: StandardMaterial3D, trim_mat: StandardMaterial3D) -> void:
	var cap := MeshInstance3D.new()
	cap.name = "PauldronCap"
	cap.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.115, 0.088, 0.118), 71 if side_sgn < 0.0 else 73)
	cap.position = Vector3(side_sgn * 0.03, 0.045, -0.01)
	cap.rotation = Vector3(0.0, 0.0, -side_sgn * deg_to_rad(18.0))
	cap.material_override = steel_mat
	arm_pivot.add_child(cap)

	var lame := MeshInstance3D.new()
	lame.name = "PauldronLame"
	lame.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.098, 0.056, 0.105), 79 if side_sgn < 0.0 else 83)
	lame.position = Vector3(side_sgn * 0.042, -0.022, -0.01)
	lame.rotation = Vector3(0.0, 0.0, -side_sgn * deg_to_rad(14.0))
	lame.material_override = MAT_LEATHER
	arm_pivot.add_child(lame)

	var trim := MeshInstance3D.new()
	trim.name = "PauldronTrim"
	trim.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.068, 0.084, 0.016, 16)
	trim.position = Vector3(side_sgn * 0.055, 0.025, -0.01)
	trim.rotation = Vector3(0.0, 0.0, PI * 0.5 - side_sgn * deg_to_rad(22.0))
	trim.material_override = trim_mat
	arm_pivot.add_child(trim)
