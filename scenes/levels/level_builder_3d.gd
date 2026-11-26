extends Node3D
## Deterministic 3D World & Adventure RPG Stage Builder (Pure Godot 4 / gl_compatibility WebGL2).
## Builds full 220m x 220m sculpted terrain valleys (Stages 1-3) and floating celestial sanctuary
## islands (Stage 4) with accurate StaticBody3D trimesh collision, 180+ MultiMesh trees,
## guaranteed ground snapping via get_terrain_height(x, z), rich Frame-1 landmarks,
## story NPCs, quests, chests, shards, Rune Pillars, Lore Runestones, traps, enemies, and bosses.

const Props3D = preload("res://scenes/world/props_visuals_3d.gd")
const NPC_SCRIPT = preload("res://scenes/world/npc_3d.gd")
const SHARD_SCRIPT = preload("res://scenes/world/sunlit_shard_3d.gd")
const CHEST_SCRIPT = preload("res://scenes/world/chest_3d.gd")
const WAYSHRINE_SCRIPT = preload("res://scenes/world/wayshrine_3d.gd")
const PORTAL_SCRIPT = preload("res://scenes/world/level_exit_3d.gd")
const RUNE_PILLAR_SCRIPT = preload("res://scenes/world/rune_pillar_3d.gd")
const LORE_STONE_SCRIPT = preload("res://scenes/world/lore_runestone_3d.gd")
const ASTRAL_BRIDGE_SCRIPT = preload("res://scenes/world/astral_bridge_3d.gd")
const SPIKE_SCRIPT = preload("res://scenes/world/spike_trap_3d.gd")
const THORN_SCRIPT = preload("res://scenes/world/timed_thorn_trap_3d.gd")
const STALKER_SCRIPT = preload("res://scenes/enemies/moss_stalker_3d.gd")
const SPITTER_SCRIPT = preload("res://scenes/enemies/thorn_spitter_3d.gd")
const GOLEM_SCRIPT = preload("res://scenes/enemies/stone_golem_3d.gd")
const WRAITH_SCRIPT = preload("res://scenes/enemies/astral_wraith_3d.gd")
const BOSS_VAELTHORN_SCRIPT = preload("res://scenes/enemies/boss_guardian_3d.gd")
const BOSS_AURELIUS_SCRIPT = preload("res://scenes/enemies/boss_astral_sovereign_3d.gd")

@export_enum("level_1", "level_2", "level_3", "level_4") var layout_id: String = "level_1"
@export var level_title: String = "Stage 1 — Whispering Moss Woods"
@export var level_index: int = 0
@export var show_controls_hint: bool = true

var _world_root: Node3D = null
var _entities_root: Node3D = null
var _player_node: Node3D = null
var _spawn_pos: Vector3 = Vector3(0.0, 0.5, 74.0)


func _ready() -> void:
	add_to_group("level_controller")

	# Remove any leftover narrow fallback road plank so only the real full 3D world renders
	var fb: Node = get_node_or_null("FallbackRoad")
	if fb:
		fb.queue_free()

	_world_root = get_node_or_null("WorldGeometry") as Node3D
	if not _world_root:
		_world_root = Node3D.new()
		_world_root.name = "WorldGeometry"
		add_child(_world_root)

	_entities_root = Node3D.new()
	_entities_root.name = "StageEntities"
	add_child(_entities_root)

	_player_node = get_node_or_null("Player3D") as Node3D

	_configure_atmosphere()

	match layout_id:
		"level_1":
			_build_stage_1_whispering_woods()
		"level_2":
			_build_stage_2_thornhollow_ruins()
		"level_3":
			_build_stage_3_boss_sanctum()
		"level_4":
			_build_stage_4_astral_sanctuary()
		_:
			_build_stage_1_whispering_woods()

	if _player_node and is_instance_valid(_player_node):
		_player_node.global_position = _spawn_pos
		_player_node.rotation = Vector3.ZERO

	GameManager.on_level_ready(level_index, _spawn_pos)

	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_level_banner"):
		hud.show_level_banner(level_title, show_controls_hint)


func _configure_atmosphere() -> void:
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun: DirectionalLight3D = get_node_or_null("MoonLight") as DirectionalLight3D
	if we and we.environment:
		var env: Environment = we.environment.duplicate() as Environment
		we.environment = env
		env.ssr_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.volumetric_fog_enabled = false
		env.glow_enabled = true
		env.fog_enabled = true
		match layout_id:
			"level_1":
				env.fog_light_color = Color(0.08, 0.22, 0.24, 1.0)
				env.fog_density = 0.0058
				env.ambient_light_color = Color(0.26, 0.48, 0.46, 1.0)
				env.ambient_light_energy = 0.92
				if sun:
					sun.light_color = Color(0.76, 0.92, 0.88, 1.0)
					sun.light_energy = 1.35
			"level_2":
				env.fog_light_color = Color(0.11, 0.14, 0.28, 1.0)
				env.fog_density = 0.0072
				env.ambient_light_color = Color(0.32, 0.36, 0.56, 1.0)
				env.ambient_light_energy = 0.88
				if sun:
					sun.light_color = Color(0.72, 0.8, 1.0, 1.0)
					sun.light_energy = 1.28
			"level_3":
				env.fog_light_color = Color(0.08, 0.16, 0.2, 1.0)
				env.fog_density = 0.0054
				env.ambient_light_color = Color(0.28, 0.44, 0.48, 1.0)
				env.ambient_light_energy = 0.9
				if sun:
					sun.light_color = Color(0.78, 0.9, 0.95, 1.0)
					sun.light_energy = 1.35
			"level_4":
				env.fog_light_color = Color(0.12, 0.2, 0.42, 1.0)
				env.fog_density = 0.0032
				env.ambient_light_color = Color(0.42, 0.54, 0.84, 1.0)
				env.ambient_light_energy = 1.05
				if sun:
					sun.light_color = Color(0.95, 0.96, 1.0, 1.0)
					sun.light_energy = 1.5


# ==============================================================================
# DETERMINISTIC TERRAIN HEIGHT & ROAD FUNCTIONS (GROUND-TRUTH FOR MESH + PROPS)
# ==============================================================================

func _path_center_x(z: float) -> float:
	match layout_id:
		"level_1":
			var taper: float = clampf(1.0 - maxf(absf(z) - 55.0, 0.0) / 24.0, 0.0, 1.0)
			return sin(z * 0.048) * 10.5 * taper
		"level_2":
			var taper2: float = clampf(1.0 - maxf(absf(z) - 58.0, 0.0) / 22.0, 0.0, 1.0)
			return sin(z * 0.055 + 0.8) * 8.5 * taper2
		_:
			return 0.0


func _sstep(e0: float, e1: float, x: float) -> float:
	var t: float = clampf((x - e0) / maxf(e1 - e0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _side_glades_for_stage() -> Array:
	if layout_id == "level_1":
		return [
			{"x": -34.0, "z": 36.0, "r": 12.0},  # West Lantern Glade (Chest 1)
			{"x": 36.0, "z": -6.0, "r": 13.0},   # East Pond Glade (Chest 2)
			{"x": -34.0, "z": -42.0, "r": 12.0}, # North-West Ruin Hollow (Chest 3)
		]
	elif layout_id == "level_2":
		return [
			{"x": -38.0, "z": 32.0, "r": 14.0},  # Courtyard 1 (Rune Pillar 1)
			{"x": 40.0, "z": -4.0, "r": 15.0},   # Courtyard 2 (Rune Pillar 2)
			{"x": -36.0, "z": -42.0, "r": 14.0}, # Courtyard 3 (Rune Pillar 3)
		]
	return []


func _walkable_weight(x: float, z: float) -> float:
	var rx: float = _path_center_x(z)
	var dx: float = absf(x - rx)
	var w: float = 0.0
	if z >= -82.0 and z <= 84.0:
		w = maxf(w, 1.0 - _sstep(3.4, 6.2, dx))
	# Spawn plaza & portal plaza
	var d_spawn: float = Vector2(x, z - 74.0).length()
	w = maxf(w, 1.0 - _sstep(9.0, 14.0, d_spawn))
	var d_portal: float = Vector2(x, z + 72.0).length()
	w = maxf(w, 1.0 - _sstep(10.0, 15.0, d_portal))

	for g_var in _side_glades_for_stage():
		var g: Dictionary = g_var
		var gx: float = float(g["x"])
		var gz: float = float(g["z"])
		var gr: float = float(g["r"])
		var dg: float = Vector2(x - gx, z - gz).length()
		w = maxf(w, 1.0 - _sstep(gr * 0.72, gr * 1.15, dg))
		# Connecting branch trail from main road to glade
		var min_x: float = minf(rx, gx) - 1.5
		var max_x: float = maxf(rx, gx) + 1.5
		if x >= min_x and x <= max_x:
			w = maxf(w, (1.0 - _sstep(2.6, 4.8, absf(z - gz))) * 0.95)
	return clampf(w, 0.0, 1.0)


func get_terrain_height(x: float, z: float) -> float:
	if layout_id == "level_4":
		return 0.0
	if layout_id == "level_3":
		# Flat approach bridge & circular 50m boss colosseum ringed by raised earth wall
		var d_arena: float = Vector2(x, z + 18.0).length()
		var on_bridge: float = 1.0 - _sstep(6.0, 10.0, absf(x)) if (z >= 14.0 and z <= 78.0) else 0.0
		var in_arena: float = 1.0 - _sstep(38.0, 48.0, d_arena)
		var flat_mask: float = maxf(on_bridge, in_arena)
		var rim_h: float = maxf(d_arena - 46.0, 0.0) * 0.42 + maxf(absf(x) - 52.0, 0.0) * 0.35
		return rim_h * (1.0 - flat_mask)

	# Stages 1 & 2: Full 220m x 220m sculpted valley with rolling hills & natural cliff border
	var walk_w: float = _walkable_weight(x, z)
	var base_undul: float = sin(x * 0.055 + z * 0.045) * 1.6 + cos(x * 0.11 - z * 0.08) * 0.95
	var edge_dist: float = maxf(maxf(absf(x) - 72.0, absf(z) - 82.0), 0.0)
	var perimeter_cliff: float = pow(edge_dist, 1.38) * 0.36
	var hill_h: float = maxf(base_undul + 1.8, 0.25) + perimeter_cliff
	var path_roll: float = sin(z * 0.032) * 0.65 if layout_id == "level_1" else sin(z * 0.04) * 1.15
	return lerpf(path_roll + hill_h, path_roll, walk_w)


func sample_road_point(z_pos: float) -> Vector3:
	var rx: float = _path_center_x(z_pos)
	return Vector3(rx, get_terrain_height(rx, z_pos), z_pos)


func get_compass_target_info() -> Dictionary:
	var ppos: Vector3 = _player_node.global_position if (_player_node and is_instance_valid(_player_node)) else _spawn_pos
	if QuestManager:
		var info: Dictionary = QuestManager.get_active_compass_target(ppos)
		return {"pos": info.get("position", ppos + Vector3(0.0, 0.0, -40.0)), "label": String(info.get("label", "Objective"))}
	return {"pos": ppos + Vector3(0.0, 0.0, -40.0), "label": "Objective"}


func _build_sculpted_terrain(half_size: float, step: float, moss_col: Color, path_col: Color, cliff_col: Color) -> void:
	## Builds a watertight, vertex-colored 220m x 220m heightmap mesh with exact StaticBody3D trimesh collision.
	var n: int = int(round((half_size * 2.0) / step))
	var vert_count: int = (n + 1) * (n + 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(vert_count)
	norms.resize(vert_count)
	cols.resize(vert_count)
	uvs.resize(vert_count)

	var stride: int = n + 1
	for ix in range(n + 1):
		var x: float = lerpf(-half_size, half_size, float(ix) / float(n))
		for iz in range(n + 1):
			var z: float = lerpf(-half_size, half_size, float(iz) / float(n))
			var y: float = get_terrain_height(x, z)
			var idx: int = ix * stride + iz
			verts[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(x * 0.08, z * 0.08)

			var walk_w: float = _walkable_weight(x, z)
			var checker: float = 0.92 + 0.08 * sin(x * 1.4) * cos(z * 1.4)
			var edge_w: float = clampf((y - 5.0) / 8.0, 0.0, 1.0)
			var c_ground: Color = moss_col.lerp(cliff_col, edge_w)
			var c_final: Color = c_ground.lerp(path_col * checker, walk_w)
			cols[idx] = c_final

	for ix in range(n + 1):
		var x: float = lerpf(-half_size, half_size, float(ix) / float(n))
		for iz in range(n + 1):
			var z: float = lerpf(-half_size, half_size, float(iz) / float(n))
			var idx: int = ix * stride + iz
			var yl: float = verts[(ix - 1) * stride + iz].y if ix > 0 else get_terrain_height(x - step, z)
			var yr: float = verts[(ix + 1) * stride + iz].y if ix < n else get_terrain_height(x + step, z)
			var yb: float = verts[ix * stride + (iz - 1)].y if iz > 0 else get_terrain_height(x, z - step)
			var yf: float = verts[ix * stride + (iz + 1)].y if iz < n else get_terrain_height(x, z + step)
			var vx: Vector3 = Vector3(2.0 * step, yr - yl, 0.0)
			var vz: Vector3 = Vector3(0.0, yf - yb, 2.0 * step)
			norms[idx] = vz.cross(vx).normalized()

	var indices := PackedInt32Array()
	indices.resize(n * n * 6)
	var k: int = 0
	for ix in n:
		for iz in n:
			var i00: int = ix * stride + iz
			var i10: int = (ix + 1) * stride + iz
			var i11: int = (ix + 1) * stride + (iz + 1)
			var i01: int = ix * stride + (iz + 1)
			indices[k] = i00; k += 1
			indices[k] = i10; k += 1
			indices[k] = i11; k += 1
			indices[k] = i00; k += 1
			indices[k] = i11; k += 1
			indices[k] = i01; k += 1

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.metallic = 0.02

	var tbody := StaticBody3D.new()
	tbody.name = "SculptedTerrain"
	tbody.collision_layer = 1
	tbody.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	tbody.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	tbody.add_child(col)
	_world_root.add_child(tbody)

	# Invisible safety boundary walls around outer perimeter so player can never leave the world
	for cfg in [
		[Vector3(-half_size + 14.0, 12.0, 0.0), Vector3(3.0, 40.0, half_size * 2.0)],
		[Vector3(half_size - 14.0, 12.0, 0.0), Vector3(3.0, 40.0, half_size * 2.0)],
		[Vector3(0.0, 12.0, -half_size + 12.0), Vector3(half_size * 2.0, 40.0, 3.0)],
		[Vector3(0.0, 12.0, half_size - 12.0), Vector3(half_size * 2.0, 40.0, 3.0)],
	]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.position = cfg[0]
		var wc := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = cfg[1]
		wc.shape = wb
		wall.add_child(wc)
		_world_root.add_child(wall)


func _populate_dense_forest_multimesh(seed_val: int, tree_count: int, foliage_col: Color, oak_col: Color, rock_col: Color, mush_col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var pine_xforms: Array = []
	var oak_xforms: Array = []
	var bush_xforms: Array = []
	var rock_xforms: Array = []
	var mush_xforms: Array = []

	var attempts: int = tree_count * 3
	for i in attempts:
		if pine_xforms.size() + oak_xforms.size() >= tree_count:
			break
		var x: float = rng.randf_range(-96.0, 96.0)
		var z: float = rng.randf_range(-96.0, 96.0)
		if _walkable_weight(x, z) > 0.22:
			continue
		var y: float = get_terrain_height(x, z) - 0.15
		var sc: float = rng.randf_range(0.88, 1.55)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * sc), Vector3(x, y, z))
		if (i % 3) != 0:
			pine_xforms.append(xf)
		else:
			oak_xforms.append(xf)

		# Solid trunk collider for trees close to walkable paths
		if absf(x - _path_center_x(z)) < 28.0:
			var tcol_body := StaticBody3D.new()
			tcol_body.collision_layer = 1
			tcol_body.collision_mask = 0
			tcol_body.position = Vector3(x, y + 2.4 * sc, z)
			var tcol := CollisionShape3D.new()
			var tcs := CylinderShape3D.new()
			tcs.radius = 0.5 * sc
			tcs.height = 5.0 * sc
			tcol.shape = tcs
			tcol_body.add_child(tcol)
			_world_root.add_child(tcol_body)

	for i in 135:
		var x: float = rng.randf_range(-88.0, 88.0)
		var z: float = rng.randf_range(-88.0, 88.0)
		if _walkable_weight(x, z) > 0.35:
			continue
		var y: float = get_terrain_height(x, z)
		var sc: float = rng.randf_range(0.75, 1.45)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * sc), Vector3(x, y, z))
		var r: int = i % 10
		if r < 5:
			bush_xforms.append(xf)
		elif r < 8:
			rock_xforms.append(xf)
		else:
			mush_xforms.append(xf)

	var bark_mat := Props3D.make_mat(Color(0.24, 0.16, 0.11, 1.0), 0.92)
	var pine_mat := Props3D.make_mat(foliage_col, 0.85)
	var oak_mat := Props3D.make_mat(oak_col, 0.85)
	var bush_mat := Props3D.make_mat(foliage_col.lightened(0.08), 0.88)
	var rock_mat := Props3D.make_mat(rock_col, 0.9)
	var mush_mat := Props3D.make_mat(mush_col, 0.28, 0.0, mush_col, 2.4)

	Props3D.spawn_multimesh(_world_root, pine_xforms, Props3D.build_pine_trunk_mesh(), bark_mat)
	Props3D.spawn_multimesh(_world_root, pine_xforms, Props3D.build_pine_canopy_mesh(), pine_mat)
	Props3D.spawn_multimesh(_world_root, oak_xforms, Props3D.build_oak_trunk_mesh(), bark_mat)
	Props3D.spawn_multimesh(_world_root, oak_xforms, Props3D.build_oak_canopy_mesh(), oak_mat)
	Props3D.spawn_multimesh(_world_root, bush_xforms, Props3D.build_bush_mesh(), bush_mat)
	Props3D.spawn_multimesh(_world_root, rock_xforms, Props3D.build_rock_mesh(), rock_mat)
	Props3D.spawn_multimesh(_world_root, mush_xforms, Props3D.build_mushroom_cluster_mesh(), mush_mat)


# ==============================================================================
# ENTITY SPAWN HELPERS (GUARANTEED GROUND SNAPPING!)
# ==============================================================================

func _spawn_npc(pos_xz: Vector2, cfg: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.set_script(NPC_SCRIPT)
	for k in cfg.keys():
		n.set(String(k), cfg[k])
	_entities_root.add_child(n)
	n.global_position = Vector3(pos_xz.x, get_terrain_height(pos_xz.x, pos_xz.y), pos_xz.y)
	return n


func _spawn_shard(pos_xz: Vector2, counts_for_quest: bool = true) -> Node3D:
	var s := Node3D.new()
	s.set_script(SHARD_SCRIPT)
	s.set("counts_for_quest", counts_for_quest)
	_entities_root.add_child(s)
	s.global_position = Vector3(pos_xz.x, get_terrain_height(pos_xz.x, pos_xz.y) + 1.1, pos_xz.y)
	return s


func _spawn_chest(pos_xz: Vector2, chest_name: String, quest_key: String, vit_up: bool = false) -> Node3D:
	var c := Node3D.new()
	c.set_script(CHEST_SCRIPT)
	c.set("chest_name", chest_name)
	c.set("quest_step_key", quest_key)
	c.set("grants_vitality_upgrade", vit_up)
	_entities_root.add_child(c)
	c.global_position = Vector3(pos_xz.x, get_terrain_height(pos_xz.x, pos_xz.y), pos_xz.y)
	return c


func _spawn_wayshrine(pos_xz: Vector2, s_name: String, s_msg: String, quest_key: String) -> Area3D:
	var w := Area3D.new()
	w.set_script(WAYSHRINE_SCRIPT)
	w.set("shrine_name", s_name)
	w.set("shrine_message", s_msg)
	w.set("quest_step_key", quest_key)
	_entities_root.add_child(w)
	w.global_position = Vector3(pos_xz.x, get_terrain_height(pos_xz.x, pos_xz.y), pos_xz.y)
	return w


func _spawn_portal(pos_xz: Vector2, p_name: String, next_lbl: String, quest_key: String, dormant: bool = true) -> Area3D:
	var p := Area3D.new()
	p.set_script(PORTAL_SCRIPT)
	p.set("portal_name", p_name)
	p.set("next_stage_label", next_lbl)
	p.set("quest_step_key", quest_key)
	p.set("starts_dormant", dormant)
	_entities_root.add_child(p)
	p.global_position = Vector3(pos_xz.x, get_terrain_height(pos_xz.x, pos_xz.y), pos_xz.y)
	return p


func _spawn_enemy(script_res: Script, pos_xz: Vector2, quest_key: String) -> CharacterBody3D:
	var e := CharacterBody3D.new()
	e.set_script(script_res)
	e.set("quest_step_key", quest_key)
	_entities_root.add_child(e)
	e.global_position = Vector3(pos_xz.x, get_terrain_height(pos_xz.x, pos_xz.y) + 0.1, pos_xz.y)
	return e


func _spawn_spike(pos_xz: Vector2) -> void:
	var sp := Area3D.new()
	sp.set_script(SPIKE_SCRIPT)
	_entities_root.add_child(sp)
	sp.global_position = Vector3(pos_xz.x, get_terrain_height(pos_xz.x, pos_xz.y), pos_xz.y)


func _spawn_thorn(pos_xz: Vector2, phase_off: float = 0.0) -> void:
	var th := Area3D.new()
	th.set_script(THORN_SCRIPT)
	th.set("phase_offset", phase_off)
	_entities_root.add_child(th)
	th.global_position = Vector3(pos_xz.x, get_terrain_height(pos_xz.x, pos_xz.y), pos_xz.y)


# ==============================================================================
# STAGE 1 — WHISPERING MOSS WOODS (RICH FRAME-1 COMPOSITION)
# ==============================================================================

func _build_stage_1_whispering_woods() -> void:
	_spawn_pos = Vector3(0.0, get_terrain_height(0.0, 74.0) + 0.25, 74.0)
	_build_sculpted_terrain(110.0, 2.5, Color(0.11, 0.29, 0.17, 1.0), Color(0.36, 0.39, 0.36, 1.0), Color(0.18, 0.22, 0.24, 1.0))
	_populate_dense_forest_multimesh(101, 210, Color(0.08, 0.31, 0.19, 1.0), Color(0.13, 0.38, 0.22, 1.0), Color(0.28, 0.33, 0.34, 1.0), Color(0.32, 0.94, 0.92, 1.0))

	# FRAME-1 COMPOSITION (Z = 64 -> 22 directly ahead of player at Z = 74!):
	# 1. Campfire + Elder Sylvan (10m ahead) + Signpost
	Props3D.spawn_campfire(_world_root, Vector3(-2.6, get_terrain_height(-2.6, 63.0), 63.0), true)
	var sylvan_lines: Array[String] = [
		"Welcome, young Explorer. The Whispering Moss Woods grow dim as corruption spreads from the Heart of the Grove.",
		"Your Golden Compass still remembers the light! Press [G] at any time to send a Compass Pulse guiding you toward your active quest and revealing hidden chests.",
		"Gather 5 Sunlit Shards along the forest trail, drive back the 3 corrupted Moss Stalkers, and ignite the Ancient Wayshrine ahead to unseal the Grove Portal.",
		"Also—if you explore the 3 branching side glades, you will find 3 Lost Lantern Treasure Chests that permanently boost your Vitality!"
	]
	var sylvan_repeat: Array[String] = [
		"Press [G] whenever you wish the Golden Compass fireflies to illuminate your path, or [Q] to open your Quest Journal."
	]
	_spawn_npc(Vector2(2.6, 63.5), {
		"npc_name": "Elder Sylvan",
		"npc_role": "Keeper of the Whispering Woods",
		"quest_step_key": "talk_sylvan",
		"side_quest_id": "s1_side",
		"robe_color": Color(0.12, 0.34, 0.22, 1.0),
		"accent_color": Color(1.0, 0.84, 0.3, 1.0),
		"dialogue_lines": sylvan_lines,
		"repeat_lines": sylvan_repeat,
	})
	Props3D.spawn_signpost(_world_root, Vector3(4.5, get_terrain_height(4.5, 58.0), 58.0), 15.0)

	# 2. Ancient Stone Archways framing the trail (22m ahead & north trail)
	var arch1_x: float = _path_center_x(52.0)
	Props3D.spawn_stone_archway(_world_root, Vector3(arch1_x, get_terrain_height(arch1_x, 52.0), 52.0), 9.4, 6.2, 0.0)
	var arch2_x: float = _path_center_x(-24.0)
	Props3D.spawn_stone_archway(_world_root, Vector3(arch2_x, get_terrain_height(arch2_x, -24.0), -24.0), 9.4, 6.2, 0.0)

	# 3. Lantern posts along the winding trail (cap dynamic OmniLights <= 6 for WebGL2!)
	var light_budget: int = 0
	for i in range(9):
		var lz: float = 64.0 - float(i) * 16.0
		var rx: float = _path_center_x(lz)
		var sgn: float = -1.0 if (i % 2 == 0) else 1.0
		var lx: float = rx + sgn * 4.8
		var use_light: bool = (i % 2 == 0) and light_budget < 5
		if use_light:
			light_budget += 1
		Props3D.spawn_lantern_post(_world_root, Vector3(lx, get_terrain_height(lx, lz), lz), 0.0 if sgn < 0.0 else PI, use_light)

	# Fallen logs & Shimmering Pond in East Glade
	Props3D.spawn_fallen_log(_world_root, Vector3(-9.5, get_terrain_height(-9.5, 42.0), 42.0), 0.45)
	Props3D.spawn_pond(_world_root, Vector3(42.0, get_terrain_height(42.0, -6.0) + 0.08, -6.0), 8.2)
	Props3D.spawn_ruin_pillar(_world_root, Vector3(-38.0, get_terrain_height(-38.0, -46.0), -46.0), 5.8)
	Props3D.spawn_ruin_pillar(_world_root, Vector3(-28.0, get_terrain_height(-28.0, -46.0), -46.0), 4.6)

	# 4. Towering Ancient Wayshrine spire visible 52m ahead at Z = 20 (plus backup shrine at -54)
	_spawn_wayshrine(Vector2(_path_center_x(20.0) + 4.5, 20.0), "Ancient Wayshrine", "Whispering Woods Wayshrine Ignited! Vitality Restored & Checkpoint Saved.", "ignite_wayshrine_1")
	_spawn_wayshrine(Vector2(_path_center_x(-54.0) - 4.5, -54.0), "North Grove Wayshrine", "North Grove Checkpoint Saved!", "ignite_wayshrine_1")

	# 5. Collectible Sunlit Shards (6 placed; Main Quest requires 5)
	for pt in [
		Vector2(_path_center_x(46.0), 46.0),
		Vector2(_path_center_x(30.0) - 1.5, 30.0),
		Vector2(-24.0, 36.0),
		Vector2(_path_center_x(2.0) + 1.5, 2.0),
		Vector2(26.0, -6.0),
		Vector2(_path_center_x(-34.0), -34.0),
	]:
		_spawn_shard(pt, true)

	# 6. 3 Hidden Forest Treasure Chests in the 3 branching side glades (Side Quest: Lost Lantern Relics)
	_spawn_chest(Vector2(-35.0, 36.0), "West Glade Lantern Chest", "open_chests_1", false)
	_spawn_chest(Vector2(34.0, -2.0), "Moonpond Relic Chest", "open_chests_1", false)
	_spawn_chest(Vector2(-34.0, -42.0), "Ruin Hollow Treasure Chest", "open_chests_1", false)

	# 7. Corrupted Moss Stalkers (4 placed; Main Quest requires 3)
	for ep in [
		Vector2(_path_center_x(12.0), 12.0),
		Vector2(_path_center_x(-14.0) - 2.0, -14.0),
		Vector2(_path_center_x(-38.0) + 2.5, -38.0),
		Vector2(-26.0, -40.0),
	]:
		_spawn_enemy(STALKER_SCRIPT, ep, "defeat_stalkers")

	# 8. Iron Spike Traps off-center along trail
	_spawn_spike(Vector2(_path_center_x(-2.0) - 2.2, -2.0))
	_spawn_spike(Vector2(_path_center_x(-28.0) + 2.2, -28.0))

	# 9. Sealed Grove Portal at north end (unlocks automatically when Main Quest steps finish)
	_spawn_portal(Vector2(0.0, -72.0), "Grove Portal", "Thornhollow Ancient Ruins", "enter_portal_1", true)


# ==============================================================================
# STAGE 2 — THORNHOLLOW ANCIENT RUINS
# ==============================================================================

func _build_stage_2_thornhollow_ruins() -> void:
	_spawn_pos = Vector3(0.0, get_terrain_height(0.0, 74.0) + 0.25, 74.0)
	_build_sculpted_terrain(110.0, 2.5, Color(0.14, 0.21, 0.24, 1.0), Color(0.32, 0.34, 0.42, 1.0), Color(0.16, 0.18, 0.28, 1.0))
	_populate_dense_forest_multimesh(202, 190, Color(0.1, 0.22, 0.28, 1.0), Color(0.16, 0.26, 0.32, 1.0), Color(0.26, 0.29, 0.36, 1.0), Color(0.55, 0.72, 1.0, 1.0))

	# Campfire + Wandering Cartographer at entrance
	Props3D.spawn_campfire(_world_root, Vector3(-2.8, get_terrain_height(-2.8, 63.0), 63.0), true)
	var cart_lines: Array[String] = [
		"Ah, bearer of the Golden Compass! Welcome to Thornhollow Ancient Ruins.",
		"The Sanctum Gate to the north is sealed by 3 Ancient Rune Pillars hidden across the side courtyards. Awaken all three with [E]!",
		"Watch your footing—timed thorn traps guard the bridges, and Thorn Spitters & Stone Golems patrol the stonework.",
		"If you spot 3 glowing Lore Runestones in the ruins, read them to recover my lost notes and sharpen your Forest Blade!"
	]
	_spawn_npc(Vector2(2.8, 63.5), {
		"npc_name": "Wandering Cartographer",
		"npc_role": "Scholar of Thornhollow",
		"quest_step_key": "talk_cartographer",
		"side_quest_id": "s2_side",
		"robe_color": Color(0.24, 0.22, 0.42, 1.0),
		"accent_color": Color(0.42, 0.88, 1.0, 1.0),
		"dialogue_lines": cart_lines,
		"repeat_lines": ["Use [G] Compass Pulse to locate the 3 Ancient Rune Pillars and hidden Lore Runestones."],
	})

	# Ruin Arches & Pillars
	for az in [50.0, 10.0, -30.0]:
		var rx: float = _path_center_x(az)
		Props3D.spawn_stone_archway(_world_root, Vector3(rx, get_terrain_height(rx, az), az), 10.0, 6.8, 0.0, Color(0.45, 0.82, 1.0, 1.0))

	var light_budget: int = 0
	for i in range(8):
		var lz: float = 60.0 - float(i) * 18.0
		var rx: float = _path_center_x(lz)
		var sgn: float = -1.0 if (i % 2 == 0) else 1.0
		var use_l: bool = (i % 2 == 0) and light_budget < 4
		if use_l:
			light_budget += 1
		Props3D.spawn_lantern_post(_world_root, Vector3(rx + sgn * 5.0, get_terrain_height(rx + sgn * 5.0, lz), lz), 0.0 if sgn < 0.0 else PI, use_l)

	# 3 Ancient Rune Pillars in the 3 Ruin Courtyards
	var pillar_coords: Array[Vector2] = [Vector2(-38.0, 32.0), Vector2(40.0, -4.0), Vector2(-36.0, -42.0)]
	for i in pillar_coords.size():
		var pt: Vector2 = pillar_coords[i]
		var rp := Node3D.new()
		rp.set_script(RUNE_PILLAR_SCRIPT)
		rp.set("pillar_index", i + 1)
		_entities_root.add_child(rp)
		rp.global_position = Vector3(pt.x, get_terrain_height(pt.x, pt.y), pt.y)
		# Frame courtyard with broken pillars
		Props3D.spawn_ruin_pillar(_world_root, Vector3(pt.x - 5.5, get_terrain_height(pt.x - 5.5, pt.y + 4.0), pt.y + 4.0), 5.2)
		Props3D.spawn_ruin_pillar(_world_root, Vector3(pt.x + 5.5, get_terrain_height(pt.x + 5.5, pt.y - 4.0), pt.y - 4.0), 4.4)

	# 3 Ancient Lore Runestones (Side Quest: Cartographer's Lost Notes)
	var lore_data: Array = [
		{"pos": Vector2(-24.0, 38.0), "title": "Lore Runestone I", "lines": ["The Compass was forged from fallen starlight to guide guardians when shadows choke the canopy."]},
		{"pos": Vector2(26.0, -10.0), "title": "Lore Runestone II", "lines": ["Vaelthorn once protected the Heart of the Grove until dark thorns pierced his core."]},
		{"pos": Vector2(-24.0, -48.0), "title": "Lore Runestone III", "lines": ["Beyond the Sanctum lies the Astral Canopy—only the Compass Pulse [G] can reveal its starlit bridges."]},
	]
	for ld_var in lore_data:
		var ld: Dictionary = ld_var
		var lp: Vector2 = ld["pos"]
		var ls := Node3D.new()
		ls.set_script(LORE_STONE_SCRIPT)
		ls.set("rune_title", String(ld["title"]))
		ls.set("lore_lines", ld["lines"])
		_entities_root.add_child(ls)
		ls.global_position = Vector3(lp.x, get_terrain_height(lp.x, lp.y), lp.y)

	# Timed Thorn Traps along the ruins road
	_spawn_thorn(Vector2(_path_center_x(26.0), 26.0), 0.0)
	_spawn_thorn(Vector2(_path_center_x(-12.0), -12.0), 1.4)
	_spawn_thorn(Vector2(_path_center_x(-48.0), -48.0), 0.7)

	# Enemies: 3 Thorn Spitters + 2 Corrupted Stone Golems (Main Quest needs 4)
	_spawn_enemy(SPITTER_SCRIPT, Vector2(-28.0, 32.0), "defeat_ruin_foes")
	_spawn_enemy(SPITTER_SCRIPT, Vector2(28.0, -4.0), "defeat_ruin_foes")
	_spawn_enemy(GOLEM_SCRIPT, Vector2(_path_center_x(4.0), 4.0), "defeat_ruin_foes")
	_spawn_enemy(GOLEM_SCRIPT, Vector2(-26.0, -42.0), "defeat_ruin_foes")
	_spawn_enemy(STALKER_SCRIPT, Vector2(_path_center_x(-26.0), -26.0), "defeat_ruin_foes")

	# Shards & Treasure Chests
	for sp in [Vector2(_path_center_x(38.0), 38.0), Vector2(36.0, 4.0), Vector2(_path_center_x(-36.0), -36.0)]:
		_spawn_shard(sp, false)
	_spawn_chest(Vector2(44.0, -8.0), "Thornhollow Vault Chest", "", true)

	# Thornhollow Wayshrine & Boss Sanctum Portal
	_spawn_wayshrine(Vector2(_path_center_x(-56.0) + 4.5, -56.0), "Thornhollow Wayshrine", "Thornhollow Checkpoint Saved & Vitality Restored!", "ignite_wayshrine_2")
	_spawn_portal(Vector2(0.0, -72.0), "Sanctum Portal", "Heart of the Grove (Boss)", "enter_portal_2", true)


# ==============================================================================
# STAGE 3 — HEART OF THE GROVE (BOSS SANCTUM)
# ==============================================================================

func _build_stage_3_boss_sanctum() -> void:
	_spawn_pos = Vector3(0.0, 0.3, 66.0)
	_build_sculpted_terrain(105.0, 2.5, Color(0.09, 0.22, 0.22, 1.0), Color(0.26, 0.32, 0.34, 1.0), Color(0.14, 0.18, 0.2, 1.0))
	_populate_dense_forest_multimesh(303, 140, Color(0.06, 0.26, 0.24, 1.0), Color(0.1, 0.32, 0.28, 1.0), Color(0.22, 0.26, 0.3, 1.0), Color(0.24, 0.96, 0.78, 1.0))

	# Approach lanterns + Grove Spirit NPC + Pre-Boss Wayshrine
	Props3D.spawn_stone_archway(_world_root, Vector3(0.0, 0.0, 32.0), 12.0, 7.6, 0.0, Color(0.28, 0.98, 0.72, 1.0))
	Props3D.spawn_lantern_post(_world_root, Vector3(-5.5, 0.0, 56.0), 0.0, true)
	Props3D.spawn_lantern_post(_world_root, Vector3(5.5, 0.0, 44.0), PI, true)

	var spirit_lines: Array[String] = [
		"Brave Explorer—before you lies the Heart of the Grove, where Vaelthorn now rages in corruption.",
		"I restore your Vitality and Compass Energy. Watch the red ground rings: dodge his Thorn Waves, JUMP over his Phase II Shockwave Ring, and strike hard when he staggers in Phase III!",
		"Use the 6 ancient stone pillars for cover, and claim victory to open the Astral Rift!"
	]
	_spawn_npc(Vector2(-4.2, 54.0), {
		"npc_name": "Grove Spirit",
		"npc_role": "Voice of the Ancient Roots",
		"quest_step_key": "talk_spirit",
		"robe_color": Color(0.18, 0.62, 0.58, 1.0),
		"accent_color": Color(0.45, 1.0, 0.85, 1.0),
		"dialogue_lines": spirit_lines,
		"repeat_lines": ["May the Grove heal you. Jump over Vaelthorn's expanding fire ring!"],
		"heals_on_talk": true,
	})
	_spawn_wayshrine(Vector2(4.6, 52.0), "Sanctum Wayshrine", "Pre-Boss Checkpoint Saved & Full Vitality Restored!", "")

	# 50m Circular Boss Colosseum (centered at Z = -18): 6 stone cover pillars + colossal glowing roots
	var arena_center := Vector3(0.0, 0.0, -18.0)
	var root_mat := Props3D.make_mat(Color(0.14, 0.42, 0.44, 1.0), 0.6, 0.0, Color(0.18, 0.88, 0.75, 1.0), 1.4)
	for i in 6:
		var ang: float = (float(i) / 6.0) * TAU + 0.3
		var ppos: Vector3 = arena_center + Vector3(cos(ang) * 16.5, 0.0, sin(ang) * 16.5)
		Props3D.spawn_ruin_pillar(_world_root, ppos, 6.2, Color(0.24, 0.32, 0.36, 1.0))

	for i in 12:
		var ang: float = (float(i) / 12.0) * TAU
		var rpos: Vector3 = arena_center + Vector3(cos(ang) * 34.0, 0.0, sin(ang) * 34.0)
		var root_spire := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.35
		rm.bottom_radius = 1.65
		rm.height = 14.0
		rm.radial_segments = 7
		root_spire.mesh = rm
		root_spire.position = rpos + Vector3(0.0, 6.5, 0.0)
		root_spire.rotation = Vector3(sin(ang) * 0.25, 0.0, -cos(ang) * 0.25)
		root_spire.material_override = root_mat
		_world_root.add_child(root_spire)

	# Boss: Vaelthorn, Corrupted Forest Guardian
	var boss := CharacterBody3D.new()
	boss.set_script(BOSS_VAELTHORN_SCRIPT)
	_entities_root.add_child(boss)
	boss.global_position = Vector3(0.0, 0.2, -22.0)

	# Chest with Healing Herb before arena + Dormant Astral Rift Portal behind boss
	_spawn_chest(Vector2(-7.5, 42.0), "Sanctum Supply Chest", "", false)
	_spawn_portal(Vector2(0.0, -54.0), "Astral Rift Portal", "Astral Canopy Sanctuary", "enter_portal_3", true)


# ==============================================================================
# STAGE 4 — ASTRAL CANOPY SANCTUARY (FLOATING CELESTIAL ISLANDS & LIGHT BRIDGES)
# ==============================================================================

func _build_stage_4_astral_sanctuary() -> void:
	_spawn_pos = Vector3(0.0, 0.4, 72.0)

	var marble_mat := Props3D.make_mat(Color(0.82, 0.86, 0.96, 1.0), 0.35, 0.2)
	var gold_mat := Props3D.make_mat(Color(1.0, 0.86, 0.34, 1.0), 0.25, 0.8, Color(1.0, 0.82, 0.26, 1.0), 0.9)

	# 3 Floating Celestial Sanctuary Islands with golden trim rings
	var islands: Array = [
		{"z": 66.0, "r": 16.0},   # Island 1: Astral Weaver Hub
		{"z": 22.0, "r": 18.0},   # Island 2: Starlight Bastion
		{"z": -34.0, "r": 26.0},  # Island 3: Sovereign Dais (Final Boss)
	]
	for isl_var in islands:
		var isl: Dictionary = isl_var
		var iz: float = float(isl["z"])
		var ir: float = float(isl["r"])

		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(0.0, -1.0, iz)
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = ir
		cs.height = 2.0
		col.shape = cs
		body.add_child(col)

		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = ir
		dm.bottom_radius = ir * 0.72
		dm.height = 2.0
		dm.radial_segments = 24
		disc.mesh = dm
		disc.material_override = marble_mat
		body.add_child(disc)

		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = ir - 0.5
		tm.outer_radius = ir + 0.15
		tm.rings = 32
		tm.ring_segments = 6
		rim.mesh = tm
		rim.position = Vector3(0.0, 1.05, 0.0)
		rim.material_override = gold_mat
		body.add_child(rim)
		_world_root.add_child(body)

	# Celestial Arches on islands
	Props3D.spawn_stone_archway(_world_root, Vector3(0.0, 0.0, 52.0), 10.0, 6.8, 0.0, Color(1.0, 0.88, 0.36, 1.0))
	Props3D.spawn_stone_archway(_world_root, Vector3(0.0, 0.0, 6.0), 10.0, 6.8, 0.0, Color(1.0, 0.88, 0.36, 1.0))

	# 2 Hidden Astral Light Bridges revealed & solidified by Golden Compass Pulse [G]!
	var b1 := Node3D.new()
	b1.set_script(ASTRAL_BRIDGE_SCRIPT)
	b1.set("bridge_length", 13.0)
	b1.set("bridge_index", 1)
	_entities_root.add_child(b1)
	b1.global_position = Vector3(0.0, 0.0, 45.0)

	var b2 := Node3D.new()
	b2.set_script(ASTRAL_BRIDGE_SCRIPT)
	b2.set("bridge_length", 14.0)
	b2.set("bridge_index", 2)
	_entities_root.add_child(b2)
	b2.global_position = Vector3(0.0, 0.0, -3.0)

	# Island 1: Astral Weaver NPC + Wayshrine
	var weaver_lines: Array[String] = [
		"Welcome to the Astral Canopy Sanctuary, Guardian of the Compass!",
		"I awaken your Golden Compass to its true celestial radiance. Press [G] near each shimmering chasm ahead to solidify the 2 Hidden Astral Light Bridges!",
		"At the final Sovereign Dais awaits Aurelius. When he raises his Golden Aegis Shield, unleash your Compass Pulse [G] to shatter it for double damage!"
	]
	_spawn_npc(Vector2(-3.5, 62.0), {
		"npc_name": "Astral Weaver",
		"npc_role": "Archivist of the Starlit Canopy",
		"quest_step_key": "talk_weaver",
		"robe_color": Color(0.18, 0.28, 0.62, 1.0),
		"accent_color": Color(1.0, 0.9, 0.42, 1.0),
		"dialogue_lines": weaver_lines,
		"repeat_lines": ["Press [G] to illuminate the Astral Light Bridges and shatter Aurelius's shield!"],
		"heals_on_talk": true,
	})
	_spawn_wayshrine(Vector2(4.2, 62.0), "Astral Entry Wayshrine", "Astral Canopy Checkpoint Saved!", "")

	# Island 2: Astral Wraiths + Treasure Chest + Wayshrine + Shards
	_spawn_enemy(WRAITH_SCRIPT, Vector2(-7.0, 22.0), "")
	_spawn_enemy(WRAITH_SCRIPT, Vector2(7.0, 22.0), "")
	_spawn_chest(Vector2(0.0, 29.0), "Celestial Star Chest", "", true)
	_spawn_wayshrine(Vector2(10.0, 14.0), "Starlight Bastion Wayshrine", "Pre-Finale Checkpoint Saved!", "")
	_spawn_shard(Vector2(-4.0, 16.0), false)
	_spawn_shard(Vector2(4.0, 16.0), false)

	# Island 3: Sovereign Dais + Aurelius Final Boss!
	for i in 8:
		var ang: float = (float(i) / 8.0) * TAU
		Props3D.spawn_ruin_pillar(_world_root, Vector3(cos(ang) * 22.0, 0.0, -34.0 + sin(ang) * 22.0), 7.5, Color(0.84, 0.88, 0.98, 1.0))

	var final_boss := CharacterBody3D.new()
	final_boss.set_script(BOSS_AURELIUS_SCRIPT)
	_entities_root.add_child(final_boss)
	final_boss.global_position = Vector3(0.0, 0.3, -38.0)
