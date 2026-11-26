extends RefCounted
## Builds ultra-detailed sculpted Treant-Golem anatomy for the Forest Guardian Boss:
## fissured ancient oak bark trunk & roots, craggy rocky visor mask, branching organic antlers
## with mossy foliage clumps, 4-clawed articulated gauntlets, 8 faceted orbital rune spires,
## and expanding telegraph/shockwave ring meshes.

const MeshFactory3D = preload("res://scenes/common/mesh_factory_3d.gd")
const MAT_BARK: StandardMaterial3D = preload("res://resources/materials3d/oak_bark.tres")
const MAT_STONE: StandardMaterial3D = preload("res://resources/materials3d/ancient_stone.tres")
const MAT_RUNE: StandardMaterial3D = preload("res://resources/materials3d/rune_stone.tres")
const MAT_CRYSTAL: StandardMaterial3D = preload("res://resources/materials3d/crystal_prism.tres")
const SHADER_FOLIAGE: Shader = preload("res://resources/shaders/foliage_sway_3d.gdshader")
const TEX_BRANCH: Texture2D = preload("res://assets/textures3d/foliage_branch_card.png")


static func enhance_guardian(boss: Node3D) -> Dictionary:
	var vis := boss.get_node_or_null("Visuals") as Node3D
	if not vis:
		return {}

	var is_astral: bool = ("max_hp" in boss and int(boss.get("max_hp")) >= 14)

	var foliage_mat := ShaderMaterial.new()
	foliage_mat.shader = SHADER_FOLIAGE
	foliage_mat.set_shader_parameter("foliage_tex", TEX_BRANCH)
	foliage_mat.set_shader_parameter("wind_speed", 1.3)
	foliage_mat.set_shader_parameter("wind_strength", 0.08)
	if is_astral:
		foliage_mat.set_shader_parameter("tint", Color(0.55, 0.92, 1.0, 1.0))

	# Replace plain cylinder Torso with twisted gnarled treant trunk & chest ribs
	var torso := vis.get_node_or_null("Torso") as MeshInstance3D
	if torso:
		torso.mesh = MeshFactory3D.build_gnarled_trunk_mesh(2.85, 1.05, 0.85, 77)
		torso.position = Vector3(0.0, -1.35, 0.0)
		torso.material_override = MAT_RUNE if is_astral else MAT_BARK

	# Carved chest rib plates flanking the glowing heart core
	for sgn in [-1.0, 1.0]:
		var rib := MeshInstance3D.new()
		rib.name = "ChestRibL" if sgn < 0.0 else "ChestRibR"
		rib.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.42, 0.72, 0.34), 25 if sgn < 0.0 else 37)
		rib.position = Vector3(sgn * 0.62, 0.2, -0.72)
		rib.rotation = Vector3(0.1, sgn * -0.32, sgn * 0.22)
		rib.material_override = MAT_STONE
		vis.add_child(rib)

	# Replace blocky MaskHead with craggy sculpted stone visor
	var mask := vis.get_node_or_null("MaskHead") as MeshInstance3D
	if mask:
		mask.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.68, 0.62, 0.56), 19)
		mask.material_override = MAT_RUNE if is_astral else MAT_STONE

	# Mossy / astral crown canopy tufts atop head & shoulders
	var brow := vis.get_node_or_null("BrowCrest") as MeshInstance3D
	if brow:
		brow.mesh = MeshFactory3D.build_foliage_canopy_cluster_mesh(0.95, 12, 401)
		brow.material_override = foliage_mat
		brow.position = Vector3(0.0, 2.02, -0.1)

	for sh_name in ["ShoulderLeft", "ShoulderRight"]:
		var sh := vis.get_node_or_null(sh_name) as MeshInstance3D
		if sh:
			sh.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.68, 0.55, 0.62), 31 if sh_name == "ShoulderLeft" else 43)
			sh.material_override = MAT_RUNE if is_astral else MAT_STONE
			var moss_tuft := MeshInstance3D.new()
			moss_tuft.mesh = MeshFactory3D.build_foliage_canopy_cluster_mesh(0.75, 10, 502)
			moss_tuft.position = Vector3(0.0, 0.42, 0.0)
			moss_tuft.material_override = foliage_mat
			sh.add_child(moss_tuft)

	# Articulated Upper Arms connecting shoulders down to heavy stone gauntlets
	for idx in 2:
		var sgn := -1.0 if idx == 0 else 1.0
		var uarm := MeshInstance3D.new()
		uarm.name = "UpperArmLeft" if idx == 0 else "UpperArmRight"
		uarm.mesh = MeshFactory3D.build_gnarled_trunk_mesh(1.15, 0.28, 0.24, 61 + idx)
		uarm.position = Vector3(sgn * 1.68, 0.72, -0.08)
		uarm.rotation = Vector3(0.14, 0.0, sgn * 0.16 + PI)
		uarm.material_override = MAT_RUNE if is_astral else MAT_BARK
		vis.add_child(uarm)

	# Curved branching organic Antlers + side twigs
	for idx in 2:
		var sgn := -1.0 if idx == 0 else 1.0
		var aname := "AntlerLeft" if idx == 0 else "AntlerRight"
		var ant := vis.get_node_or_null(aname) as MeshInstance3D
		if ant:
			ant.mesh = MeshFactory3D.build_branch_bough_mesh(1.95, 0.14, 0.035, 11 + idx)
			ant.position = Vector3(sgn * 0.55, 1.82, 0.0)
			ant.rotation = Vector3(-0.18, 0.0, sgn * -0.45)
			ant.material_override = MAT_BARK

	# Hanging twisted root tendrils beneath floating core
	for r_name in ["Root1", "Root2", "Root3"]:
		var rt := vis.get_node_or_null(r_name) as MeshInstance3D
		if rt:
			rt.mesh = MeshFactory3D.build_branch_bough_mesh(1.25, 0.16, 0.02, r_name.hash())
			rt.position.y = -1.28
			rt.rotation.x += PI
			rt.material_override = MAT_BARK

	# Faceted rocky gauntlets + glowing chest rune core
	for f_name in ["FistLeft", "FistRight"]:
		var fist := vis.get_node_or_null(f_name) as MeshInstance3D
		if fist:
			fist.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.45, 0.52, 0.45), f_name.hash())
			fist.material_override = MAT_RUNE if is_astral else MAT_STONE

	var core := vis.get_node_or_null("ChestCore") as MeshInstance3D
	if core:
		core.mesh = MeshFactory3D.build_rune_shard_mesh(0.48, 1.18, 7)

	# Replace box shards with 8 faceted beveled rune spires
	var shards := vis.get_node_or_null("OrbitShards") as Node3D
	if shards:
		for child in shards.get_children():
			child.queue_free()
		for i in 8:
			var ang := (float(i) / 8.0) * TAU
			var sh_mi := MeshInstance3D.new()
			sh_mi.mesh = MeshFactory3D.build_rune_shard_mesh(0.22, 0.72, i + 1)
			sh_mi.position = Vector3(cos(ang) * 2.55, sin(ang * 2.0) * 0.35, sin(ang) * 2.55)
			sh_mi.rotation = Vector3(0.2, -ang, 0.15)
			sh_mi.material_override = MAT_CRYSTAL if (is_astral or i % 2 == 1) else MAT_RUNE
			shards.add_child(sh_mi)

	# Ground Shockwave & Telegraph warning ring at boss arena ground level
	var shock_mat := StandardMaterial3D.new()
	shock_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock_mat.albedo_color = Color(0.35, 0.88, 1.0, 0.88) if is_astral else Color(0.28, 0.96, 0.75, 0.88)
	shock_mat.emission_enabled = true
	shock_mat.emission = Color(0.3, 0.85, 1.0, 1.0) if is_astral else Color(0.22, 0.98, 0.78, 1.0)
	shock_mat.emission_energy_multiplier = 3.4

	var ring := MeshInstance3D.new()
	ring.name = "TelegraphRing"
	ring.mesh = MeshFactory3D.build_telegraph_ring_mesh(1.9, 2.35, 36)
	ring.material_override = shock_mat
	ring.visible = false
	ring.top_level = true
	boss.add_child(ring)

	return {
		"telegraph_ring": ring,
		"shock_mat": shock_mat,
	}
