@tool
extends Node3D
## Realistic Long Forest Road & Woodland Environment Builder (Pure Godot 4).
## Builds continuous sculpted valley terrain + winding cobblestone/earth roads (100% jump-free!),
## exact trimesh collision, stone-and-timber arched bridges over forest streams, stone kerbstones,
## roadside archways, carved signposts, warm camp braziers, lanterns, multi-species oak & pine
## forest MultiMesh canopies, shrub/fern/grass carpets, ancient ruins, god rays, mist & mountains.

@export_enum("greybox", "level_1", "level_2", "level_3", "level_4") var layout_id: String = "level_1"
@export var level_title: String = "Whispering Canopy Road"
@export var level_index: int = 0
@export var show_controls_hint: bool = false

const SCENE_CRYSTAL: PackedScene = preload("res://scenes/world/crystal_3d.tscn")
const SCENE_HEAL: PackedScene = preload("res://scenes/world/healing_orb_3d.tscn")
const SCENE_WAYSHRINE: PackedScene = preload("res://scenes/world/wayshrine_3d.tscn")
const SCENE_HIDDEN: PackedScene = preload("res://scenes/world/hidden_path_3d.tscn")
const SCENE_SPIKE: PackedScene = preload("res://scenes/world/spike_trap_3d.tscn")
const SCENE_THORN: PackedScene = preload("res://scenes/world/timed_thorn_trap_3d.tscn")
const SCENE_WISP: PackedScene = preload("res://scenes/enemies/flying_wisp_3d.tscn")

const MeshFactory3D = preload("res://scenes/common/mesh_factory_3d.gd")
const MAT_MOSS: StandardMaterial3D = preload("res://resources/materials3d/moss_ground.tres")
const MAT_STONE: StandardMaterial3D = preload("res://resources/materials3d/ancient_stone.tres")
const MAT_RUNE: StandardMaterial3D = preload("res://resources/materials3d/rune_stone.tres")
const MAT_BARK: StandardMaterial3D = preload("res://resources/materials3d/oak_bark.tres")
const MAT_WOOD: StandardMaterial3D = preload("res://resources/materials3d/timber_plank.tres")
const MAT_FILIGREE: StandardMaterial3D = preload("res://resources/materials3d/metal_filigree.tres")

const SHADER_ROAD_TERRAIN: Shader = preload("res://resources/shaders/road_terrain_3d.gdshader")
const SHADER_TERRAIN: Shader = preload("res://resources/shaders/terrain_blend_3d.gdshader")
const SHADER_FOLIAGE: Shader = preload("res://resources/shaders/foliage_sway_3d.gdshader")
const SHADER_MIST: Shader = preload("res://resources/shaders/ground_mist_3d.gdshader")
const SHADER_WATER: Shader = preload("res://resources/shaders/forest_water_3d.gdshader")
const SHADER_RAY: Shader = preload("res://resources/shaders/god_ray_3d.gdshader")
const SHADER_CLOUD: Shader = preload("res://resources/shaders/cloud_bank_3d.gdshader")

const CHUNK_LEN: float = 200.0

const TEX_MOSS_ALB: Texture2D = preload("res://assets/textures3d/moss_ground_albedo.png")
const TEX_MOSS_N: Texture2D = preload("res://assets/textures3d/moss_ground_n.png")
const TEX_MOSS_R: Texture2D = preload("res://assets/textures3d/moss_ground_r.png")
const TEX_SOIL_ALB: Texture2D = preload("res://assets/textures3d/soil_cliff_albedo.png")
const TEX_SOIL_N: Texture2D = preload("res://assets/textures3d/soil_cliff_n.png")
const TEX_SOIL_R: Texture2D = preload("res://assets/textures3d/soil_cliff_r.png")
const TEX_STONE_ALB: Texture2D = preload("res://assets/textures3d/ancient_stone_albedo.png")
const TEX_STONE_N: Texture2D = preload("res://assets/textures3d/ancient_stone_n.png")
const TEX_STONE_R: Texture2D = preload("res://assets/textures3d/ancient_stone_r.png")
const TEX_GRASS_CARD: Texture2D = preload("res://assets/textures3d/grass_tuft_card.png")
const TEX_FERN_CARD: Texture2D = preload("res://assets/textures3d/fern_frond_card.png")
const TEX_BRANCH_CARD: Texture2D = preload("res://assets/textures3d/foliage_branch_card.png")
const TEX_WATER_N: Texture2D = preload("res://assets/textures3d/water_normal.png")

@onready var world_geo: Node3D = $WorldGeometry
@onready var music_player: AudioStreamPlayer = get_node_or_null("MusicPlayer")
@onready var ambience_player: AudioStreamPlayer = get_node_or_null("AmbiencePlayer")
@onready var _player_node: Node3D = get_node_or_null("Player3D")
@onready var _fireflies_node: GPUParticles3D = get_node_or_null("Fireflies")

var _lantern_lights: Array = []
var _lantern_cages: Array = []
var _chunk_nodes: Dictionary = {}
var _chunk_lights: Dictionary = {}
var _chunk_cages: Dictionary = {}
var _chunk_count: int = 1
var _flicker_t: float = 0.0
var _milestone_next_idx: int = 0
var _glow_mush_mat: StandardMaterial3D
var _ember_mat: StandardMaterial3D
var _lantern_bulb_mat: StandardMaterial3D
var _road_terrain_mat: ShaderMaterial
var _terrain_stone_mat: ShaderMaterial
var _grass_mat: ShaderMaterial
var _fern_mat: ShaderMaterial
var _canopy_mat: ShaderMaterial
var _pine_mat: ShaderMaterial
var _mist_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _ray_mat: ShaderMaterial
var _cloud_mat: ShaderMaterial
var _mountain_mat: StandardMaterial3D

var _grass_mesh: ArrayMesh
var _fern_mesh: ArrayMesh
var _shrub_mesh: ArrayMesh
var _oak_trunk_mesh: ArrayMesh
var _oak_canopy_mesh: ArrayMesh
var _pine_trunk_mesh: ArrayMesh
var _pine_canopy_mesh: ArrayMesh
var _kerb_mesh: ArrayMesh
var _cloud_mesh: ArrayMesh
var _sky_island_mesh: ArrayMesh

# Active terrain config populated per layout
var _cfg: Dictionary = {}


func _ready() -> void:
	add_to_group("level_controller")
	_init_procedural_materials()
	if world_geo and world_geo.get_child_count() == 0:
		_build_layout()
	var fb := get_node_or_null("FallbackRoad")
	if fb:
		if Engine.is_editor_hint():
			fb.visible = false
		else:
			fb.queue_free()

	if Engine.is_editor_hint():
		return

	_apply_stage_atmosphere()
	_fit_kill_zone()
	_populate_stage_encounters()
	GameManager.on_level_ready(level_index)
	_setup_audio_loop(music_player)
	_setup_audio_loop(ambience_player)
	GameManager.quality_changed.connect(_apply_graphics_quality)
	_apply_graphics_quality(GameManager.graphics_quality)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_level_banner"):
		hud.show_level_banner(level_title, show_controls_hint)


func _apply_stage_atmosphere() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := get_node_or_null("MoonLight") as DirectionalLight3D
	var is_fwd := RenderingServer.get_current_rendering_method() == "forward_plus"
	if we and we.environment:
		var env := we.environment.duplicate() as Environment
		we.environment = env
		if not is_fwd:
			env.ssr_enabled = false
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.volumetric_fog_enabled = false
		match layout_id:
			"level_1":
				env.fog_light_color = Color(0.08, 0.19, 0.26, 1.0)
				env.fog_density = 0.0052
			"level_2":
				env.fog_light_color = Color(0.12, 0.16, 0.28, 1.0)
				env.fog_density = 0.0064
				if is_fwd:
					env.volumetric_fog_albedo = Color(0.38, 0.48, 0.72, 1.0)
				if sun:
					sun.light_color = Color(0.78, 0.86, 1.0, 1.0)
					sun.light_energy = 1.35
			"level_3":
				env.fog_light_color = Color(0.07, 0.19, 0.24, 1.0)
				env.fog_density = 0.0056
				if sun:
					sun.light_color = Color(0.7, 0.9, 0.96, 1.0)
					sun.light_energy = 1.3
			"level_4":
				env.fog_light_color = Color(0.18, 0.28, 0.48, 1.0)
				env.fog_density = 0.0032
				if is_fwd:
					env.volumetric_fog_density = 0.0055
					env.volumetric_fog_albedo = Color(0.48, 0.68, 0.96, 1.0)
				env.ambient_light_color = Color(0.4, 0.56, 0.8, 1.0)
				env.ambient_light_energy = 0.98
				if sun:
					sun.light_color = Color(0.86, 0.94, 1.0, 1.0)
					sun.light_energy = 1.5


func _fit_kill_zone() -> void:
	var kz := get_node_or_null("KillZone3D") as Node3D
	if not kz:
		return
	var z_min := float(_cfg.get("z_min", -200.0))
	var z_max := float(_cfg.get("z_max", 30.0))
	var z_span := absf(z_max - z_min) + 180.0
	var z_mid := (z_min + z_max) * 0.5
	kz.global_position = Vector3(0.0, -24.0, z_mid)
	var col := kz.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is BoxShape3D:
		var box := (col.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size = Vector3(480.0, 12.0, z_span)
		col.shape = box


func get_road_progress() -> Dictionary:
	var z_start := float(_cfg.get("progress_start_z", 8.0))
	var z_end := float(_cfg.get("progress_end_z", -170.0))
	var total := maxf(absf(z_start - z_end), 1.0)
	if not _player_node or not is_instance_valid(_player_node):
		return {"traveled": 0.0, "total": total, "ratio": 0.0}
	var traveled := clampf(z_start - _player_node.global_position.z, 0.0, total)
	return {"traveled": traveled, "total": total, "ratio": traveled / total}


func sample_road_point(z_pos: float) -> Vector3:
	var rx := _road_center_x(z_pos)
	var ry := _ground_surface_y(rx, z_pos)
	return Vector3(rx, ry, z_pos)


func get_compass_target_info() -> Dictionary:
	var pz := 8.0
	var ppos := Vector3(0.0, 0.0, 8.0)
	if _player_node and is_instance_valid(_player_node):
		ppos = _player_node.global_position
		pz = ppos.z

	# 1. Active collectible Golden Compass takes highest priority
	for child in get_children():
		if child is Area3D and child.name.contains("GoldenCompass"):
			return {"pos": (child as Node3D).global_position, "label": "Golden Compass Relic", "type": "compass"}

	# 2. Nearest unactivated Wayshrine ahead along the road
	var best_shrine: Node3D = null
	var best_s_dist := 999999.0
	for sh_var in get_tree().get_nodes_in_group("wayshrines"):
		var sh := sh_var as Node3D
		if not sh or not is_instance_valid(sh):
			continue
		if sh.has_method("is_activated") and bool(sh.is_activated()):
			continue
		if sh.global_position.z <= pz + 18.0:
			var d := ppos.distance_to(sh.global_position)
			if d < best_s_dist:
				best_s_dist = d
				best_shrine = sh
	if best_shrine and best_s_dist < 620.0:
		return {"pos": best_shrine.global_position, "label": "Ancient Wayshrine", "type": "wayshrine"}

	# 3. Active Stage Boss if present
	var enemies_node := get_node_or_null("Enemies")
	if enemies_node:
		for e in enemies_node.get_children():
			if e is Node3D and "engage_radius" in e and not bool(e.get("is_defeated")):
				var b_lbl := "Astral Guardian" if layout_id == "level_4" else "Forest Guardian"
				return {"pos": (e as Node3D).global_position, "label": b_lbl, "type": "boss"}

	# 4. Stage Exit / Astral Portal
	var exit_node := get_node_or_null("LevelExit3D") as Node3D
	if not exit_node:
		exit_node = get_node_or_null("AstralPortal") as Node3D
	if exit_node and is_instance_valid(exit_node):
		var p_lbl := "Northern Astral Portal" if exit_node.name == "AstralPortal" else "Stage Portal"
		return {"pos": exit_node.global_position, "label": p_lbl, "type": "portal"}

	var z_end := float(_cfg.get("progress_end_z", -4590.0))
	return {"pos": sample_road_point(z_end), "label": "Northern Horizon", "type": "goal"}


func _apply_graphics_quality(lvl: int) -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	var is_fwd := RenderingServer.get_current_rendering_method() == "forward_plus"
	if we and we.environment:
		var env := we.environment
		if is_fwd:
			env.ssao_enabled = (lvl >= 1)
			env.ssil_enabled = (lvl >= 2)
			env.ssr_enabled = (lvl >= 2)
			env.volumetric_fog_enabled = (lvl >= 1)
		else:
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.volumetric_fog_enabled = false
			env.glow_enabled = (lvl >= 1)
	var sun := get_node_or_null("MoonLight") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = (lvl >= 1)


func _init_procedural_materials() -> void:
	_glow_mush_mat = StandardMaterial3D.new()
	_glow_mush_mat.albedo_color = Color(0.45, 0.96, 1.0, 1.0)
	_glow_mush_mat.emission_enabled = true
	_glow_mush_mat.emission = Color(0.25, 0.88, 1.0, 1.0)
	_glow_mush_mat.emission_energy_multiplier = 2.4

	_ember_mat = StandardMaterial3D.new()
	_ember_mat.albedo_color = Color(1.0, 0.56, 0.2, 1.0)
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color(1.0, 0.45, 0.12, 1.0)
	_ember_mat.emission_energy_multiplier = 3.2

	_lantern_bulb_mat = StandardMaterial3D.new()
	_lantern_bulb_mat.albedo_color = Color(1.0, 0.88, 0.5, 1.0)
	_lantern_bulb_mat.emission_enabled = true
	_lantern_bulb_mat.emission = Color(1.0, 0.78, 0.3, 1.0)
	_lantern_bulb_mat.emission_energy_multiplier = 3.2

	_road_terrain_mat = ShaderMaterial.new()
	_road_terrain_mat.shader = SHADER_ROAD_TERRAIN
	_road_terrain_mat.set_shader_parameter("moss_albedo", TEX_MOSS_ALB)
	_road_terrain_mat.set_shader_parameter("moss_normal", TEX_MOSS_N)
	_road_terrain_mat.set_shader_parameter("soil_albedo", TEX_SOIL_ALB)
	_road_terrain_mat.set_shader_parameter("soil_normal", TEX_SOIL_N)
	_road_terrain_mat.set_shader_parameter("stone_albedo", TEX_STONE_ALB)
	_road_terrain_mat.set_shader_parameter("stone_normal", TEX_STONE_N)

	_terrain_stone_mat = ShaderMaterial.new()
	_terrain_stone_mat.shader = SHADER_TERRAIN
	_terrain_stone_mat.set_shader_parameter("top_albedo", TEX_MOSS_ALB)
	_terrain_stone_mat.set_shader_parameter("top_normal", TEX_MOSS_N)
	_terrain_stone_mat.set_shader_parameter("side_albedo", TEX_STONE_ALB)
	_terrain_stone_mat.set_shader_parameter("side_normal", TEX_STONE_N)
	_terrain_stone_mat.set_shader_parameter("tex_scale", 0.24)
	_terrain_stone_mat.set_shader_parameter("moss_threshold", 0.7)

	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = SHADER_FOLIAGE
	_grass_mat.set_shader_parameter("foliage_tex", TEX_GRASS_CARD)
	_grass_mat.set_shader_parameter("wind_speed", 1.8)
	_grass_mat.set_shader_parameter("wind_strength", 0.14)

	_fern_mat = ShaderMaterial.new()
	_fern_mat.shader = SHADER_FOLIAGE
	_fern_mat.set_shader_parameter("foliage_tex", TEX_FERN_CARD)
	_fern_mat.set_shader_parameter("wind_speed", 1.3)
	_fern_mat.set_shader_parameter("wind_strength", 0.11)

	_canopy_mat = ShaderMaterial.new()
	_canopy_mat.shader = SHADER_FOLIAGE
	_canopy_mat.set_shader_parameter("foliage_tex", TEX_BRANCH_CARD)
	_canopy_mat.set_shader_parameter("wind_speed", 1.1)
	_canopy_mat.set_shader_parameter("wind_strength", 0.12)

	_pine_mat = ShaderMaterial.new()
	_pine_mat.shader = SHADER_FOLIAGE
	_pine_mat.set_shader_parameter("foliage_tex", TEX_BRANCH_CARD)
	_pine_mat.set_shader_parameter("tint", Color(0.72, 0.88, 0.84, 1.0))
	_pine_mat.set_shader_parameter("wind_speed", 0.95)
	_pine_mat.set_shader_parameter("wind_strength", 0.08)

	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = SHADER_MIST

	_water_mat = ShaderMaterial.new()
	_water_mat.shader = SHADER_WATER
	_water_mat.set_shader_parameter("water_normal_tex", TEX_WATER_N)

	_ray_mat = ShaderMaterial.new()
	_ray_mat.shader = SHADER_RAY

	_mountain_mat = StandardMaterial3D.new()
	_mountain_mat.albedo_color = Color(0.05, 0.1, 0.15, 1.0)
	_mountain_mat.roughness = 0.96

	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = SHADER_CLOUD

	_grass_mesh = MeshFactory3D.build_crossed_frond_mesh(0.55, 0.92)
	_fern_mesh = MeshFactory3D.build_crossed_frond_mesh(0.92, 1.32)
	_shrub_mesh = MeshFactory3D.build_shrub_cluster_mesh(1.55, 10, 42)
	_oak_trunk_mesh = MeshFactory3D.build_gnarled_trunk_mesh(9.4, 0.92, 0.34, 17)
	_oak_canopy_mesh = MeshFactory3D.build_foliage_canopy_cluster_mesh(4.2, 26, 29)
	_pine_trunk_mesh = MeshFactory3D.build_pine_trunk_mesh(13.5, 0.56, 0.08, 11)
	_pine_canopy_mesh = MeshFactory3D.build_pine_canopy_mesh(13.5, 3.6, 23)
	_kerb_mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.55, 0.24, 0.92), 8)
	_cloud_mesh = MeshFactory3D.build_boulder_mesh(Vector3(16.0, 4.6, 12.0), 99)
	_sky_island_mesh = MeshFactory3D.build_sculpted_island_mesh(Vector3(18.0, 5.2, 18.0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_flicker_t += delta * 5.0
	var pz := _player_node.global_position.z if (_player_node and is_instance_valid(_player_node)) else 0.0
	if _fireflies_node and _player_node and is_instance_valid(_player_node):
		_fireflies_node.global_position = Vector3(_player_node.global_position.x, _player_node.global_position.y + 4.5, pz - 12.0)

	_update_streaming_chunks(false)

	for c_idx in _chunk_lights.keys():
		var arr: Array = _chunk_lights[c_idx]
		for i in arr.size():
			var lt := arr[i] as OmniLight3D
			if lt and is_instance_valid(lt) and absf(lt.global_position.z - pz) < 72.0:
				lt.light_energy = 2.4 + sin(_flicker_t + float(i) * 1.4) * 0.26
	for c_idx in _chunk_cages.keys():
		var carr: Array = _chunk_cages[c_idx]
		for i in carr.size():
			var cg := carr[i] as Node3D
			if cg and is_instance_valid(cg) and absf(cg.global_position.z - pz) < 72.0:
				cg.rotation.z = sin(_flicker_t * 0.36 + float(i) * 1.7) * 0.07
				cg.rotation.x = cos(_flicker_t * 0.28 + float(i) * 2.1) * 0.05
	if _glow_mush_mat:
		_glow_mush_mat.emission_energy_multiplier = 2.25 + sin(_flicker_t * 0.45) * 0.55
	if _ember_mat:
		_ember_mat.emission_energy_multiplier = 3.0 + sin(_flicker_t * 1.1) * 0.7

	if level_index >= 0 and _player_node and is_instance_valid(_player_node):
		var prog := get_road_progress()
		var ratio := float(prog["ratio"])
		if _milestone_next_idx == 0 and ratio >= 0.33:
			_milestone_next_idx = 1
			GameManager.notification_posted.emit("Road Milestone: 1/3 Through %s" % level_title, Color(0.75, 0.96, 0.88))
		elif _milestone_next_idx == 1 and ratio >= 0.66:
			_milestone_next_idx = 2
			GameManager.notification_posted.emit("Road Milestone: 2/3 Through %s" % level_title, Color(0.98, 0.9, 0.58))


func _setup_audio_loop(ap: AudioStreamPlayer) -> void:
	if ap and ap.stream:
		ap.finished.connect(ap.play)
		if not ap.playing:
			ap.play()


# ---------------------------------------------------------------------------
# Continuous Road & Valley Math
# ---------------------------------------------------------------------------

func _road_center_x(z: float) -> float:
	var curve_amp := float(_cfg.get("curve_amp", 0.0))
	if curve_amp <= 0.01:
		return 0.0
	var z_start := float(_cfg.get("curve_start_z", float(_cfg.get("road_start_z", 16.0)) - 14.0))
	var z_end := float(_cfg.get("curve_end_z", float(_cfg.get("road_end_z", -170.0)) + 45.0))
	var span := maxf(z_start - z_end, 1.0)
	var dist := clampf(z_start - z, 0.0, span)
	var end_taper := _sstep(0.0, minf(36.0, span * 0.2), dist) * _sstep(0.0, minf(52.0, span * 0.25), span - dist)
	var phase := float(_cfg.get("curve_phase", 0.0))
	var wave := sin(dist * (TAU / 235.0) + phase) * 0.72 + sin(dist * (TAU / 138.0) + phase * 1.7) * 0.28
	var rivers: Array = _cfg.get("rivers", [])
	for rv_var in rivers:
		var rz := float((rv_var as Dictionary)["z"])
		var d_riv := absf(z - rz)
		if d_riv < 26.0:
			end_taper *= lerpf(0.55, 1.0, _sstep(8.0, 26.0, d_riv))
	return wave * curve_amp * end_taper


func _road_base_y(z: float) -> float:
	var hill_amp := float(_cfg.get("hill_amp", 0.0))
	if hill_amp <= 0.01:
		return 0.0
	var z_start := float(_cfg.get("curve_start_z", float(_cfg.get("road_start_z", 16.0)) - 14.0))
	var z_end := float(_cfg.get("curve_end_z", float(_cfg.get("road_end_z", -170.0)) + 55.0))
	var span := maxf(z_start - z_end, 1.0)
	var dist := clampf(z_start - z, 0.0, span)
	var taper := _sstep(0.0, minf(42.0, span * 0.2), dist) * _sstep(0.0, minf(60.0, span * 0.25), span - dist)
	var rivers: Array = _cfg.get("rivers", [])
	for rv_var in rivers:
		var rz := float((rv_var as Dictionary)["z"])
		var d_riv := absf(z - rz)
		if d_riv < 30.0:
			taper *= _sstep(13.0, 30.0, d_riv)
	var h := (0.5 - 0.5 * cos(dist * (TAU / 320.0))) * 0.75 + (0.5 - 0.5 * cos(dist * (TAU / 185.0) + 1.1)) * 0.25
	return h * hill_amp * taper


func _road_half_width(_z: float) -> float:
	return float(_cfg.get("road_half_w", 6.5))


func _sample_terrain(x: float, z: float) -> Dictionary:
	var rx := _road_center_x(z)
	var dx := absf(x - rx)
	var rw := _road_half_width(z)
	var road_start_z := float(_cfg.get("road_start_z", 16.0))
	var road_end_z := float(_cfg.get("road_end_z", -170.0))

	var y := _road_base_y(z)
	var road_w := 0.0
	var cobble_w := 0.0
	var bank_w := 0.0
	var damp_w := 0.0

	# Main continuous walkable roadbed
	if z <= road_start_z + 12.0 and z >= road_end_z - 16.0:
		var road_mask := 1.0 - _sstep(rw - 0.8, rw + 1.9, dx)
		road_w = maxf(road_w, road_mask)
		cobble_w = maxf(cobble_w, (1.0 - _sstep(rw * 0.45, rw - 0.5, dx)) * float(_cfg.get("cobble_bias", 0.65)))
		var rut := exp(-pow((dx - 1.85) * 1.4, 2.0))
		damp_w = maxf(damp_w, rut * 0.65 * road_mask)
		y -= rut * 0.04 * road_mask

	# Side clearings & walkable branching trails (100% jump-free)
	var clearings: Array = _cfg.get("clearings", [])
	for c_var in clearings:
		var cl: Dictionary = c_var
		var cx := float(cl["x"])
		var cz := float(cl["z"])
		var crx := float(cl["rx"])
		var crz := float(cl["rz"])
		var d_ellipse := sqrt(pow((x - cx) / crx, 2.0) + pow((z - cz) / crz, 2.0))
		var cl_mask := 1.0 - _sstep(0.75, 1.25, d_ellipse)
		if cl_mask > 0.01:
			road_w = maxf(road_w, cl_mask * 0.9)
			if bool(cl.get("stone", false)):
				cobble_w = maxf(cobble_w, cl_mask * 0.92)
		if bool(cl.get("connect", true)):
			var seg_min := minf(rx, cx) - 1.6
			var seg_max := maxf(rx, cx) + 1.6
			if x >= seg_min and x <= seg_max:
				var dz_path := absf(z - cz)
				var path_mask := 1.0 - _sstep(2.8, 4.8, dz_path)
				road_w = maxf(road_w, path_mask * 0.92)
				cobble_w = maxf(cobble_w, path_mask * 0.7)

	# Forest embankments / highland slopes OR celestial cloud drop-off outside road/clearings
	var walkable_mask := maxf(road_w, cobble_w)
	var is_sky_road := bool(_cfg.get("sky_road", false))
	if walkable_mask < 0.99:
		var clear_suppress := 1.0 - _sstep(0.2, 0.85, walkable_mask)
		var out_dist := maxf(dx - (rw + 1.8), 0.0)
		if is_sky_road:
			var edge_drop := clampf(out_dist * 2.5, 0.0, 26.0)
			var back_drop := maxf(z - (road_start_z + 10.0), 0.0) * 1.4
			var front_drop := maxf((road_end_z - 14.0) - z, 0.0) * 1.4
			y -= minf(edge_drop + back_drop + front_drop, 28.0) * clear_suppress
			bank_w = clampf(out_dist * 0.25, 0.0, 1.0) * clear_suppress
		else:
			var hill_dist := maxf(dx - (rw + 2.4), 0.0)
			var is_highland := bool(_cfg.get("highland", false))
			var max_em := 9.2 if is_highland else 5.2
			var hill_h := clampf(hill_dist * (0.24 if is_highland else 0.14), 0.0, max_em)
			var undul := (sin(x * 0.13 + z * 0.09) * 0.72 + cos(x * 0.24 - z * 0.17) * 0.48 + 0.55) * clampf(hill_dist * 0.09, 0.0, 1.2)
			var outer_wall := maxf(dx - 31.0, 0.0) * (0.42 if is_highland else 0.26)
			var back_wall := maxf(z - (road_start_z + 8.0), 0.0) * 0.35
			var front_wall := maxf((road_end_z - 12.0) - z, 0.0) * 0.35
			y += (hill_h + undul + outer_wall + back_wall + front_wall) * clear_suppress
			bank_w = clampf(hill_dist * 0.07, 0.0, 0.85) * clear_suppress

	# River/gorge depressions flowing cleanly UNDER bridges
	var rivers: Array = _cfg.get("rivers", [])
	for r_var in rivers:
		var rv: Dictionary = r_var
		var rz := float(rv["z"])
		var r_half := float(rv.get("half_w", 9.5))
		var r_depth := float(rv.get("depth", 2.6))
		var dz_r := absf(z - rz)
		if dz_r < r_half + 4.0:
			var r_mask := 1.0 - _sstep(r_half * 0.35, r_half + 2.8, dz_r)
			y = lerpf(y, -r_depth, r_mask)
			bank_w = maxf(bank_w, r_mask * 0.9)
			damp_w = maxf(damp_w, r_mask * 0.95)
			road_w *= (1.0 - r_mask)
			cobble_w *= (1.0 - r_mask)

	var col := Color(clampf(road_w, 0.0, 1.0), clampf(cobble_w, 0.0, 1.0), clampf(bank_w, 0.0, 1.0), clampf(damp_w, 0.0, 1.0))
	return {"y": y, "col": col}


func _sstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / maxf(e1 - e0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _ground_surface_y(x: float, z: float) -> float:
	var rivers: Array = _cfg.get("rivers", [])
	for r_var in rivers:
		var rv: Dictionary = r_var
		var rz := float(rv["z"])
		var r_half := float(rv.get("half_w", 9.5))
		var bridge_half := r_half * 1.125 + 1.6
		if absf(z - rz) <= bridge_half and absf(x - _road_center_x(z)) <= 5.6:
			return 0.18
	return float(_sample_terrain(x, z)["y"])


# ---------------------------------------------------------------------------
# Streaming Chunk & Environment Builders
# ---------------------------------------------------------------------------

func _build_continuous_terrain() -> void:
	var z_min := float(_cfg.get("z_min", -195.0))
	var z_max := float(_cfg.get("z_max", 28.0))
	var z_span := absf(z_max - z_min)
	_chunk_count = maxi(int(ceil(z_span / CHUNK_LEN)), 1)

	# Perimeter valley walls along outer corridor & ends so player stays inside the adventure
	var z_mid := (z_min + z_max) * 0.5
	for side in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.position = Vector3(side * 36.0, 6.0, z_mid)
		var wcol := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = Vector3(2.0, 26.0, z_span + 16.0)
		wcol.shape = wbox
		wall.add_child(wcol)
		world_geo.add_child(wall)

	for end_z in [z_min + 6.0, z_max - 6.0]:
		var ewall := StaticBody3D.new()
		ewall.collision_layer = 1
		ewall.collision_mask = 0
		ewall.position = Vector3(0.0, 6.0, end_z)
		var ecol := CollisionShape3D.new()
		var ebox := BoxShape3D.new()
		ebox.size = Vector3(80.0, 26.0, 2.0)
		ecol.shape = ebox
		ewall.add_child(ecol)
		world_geo.add_child(ewall)

	_update_streaming_chunks(true)


func _update_streaming_chunks(build_all: bool) -> void:
	if _chunk_count <= 0 or _cfg.is_empty():
		return
	var z_min := float(_cfg.get("z_min", -195.0))
	var z_max := float(_cfg.get("z_max", 28.0))
	var pz := float(_cfg.get("progress_start_z", 8.0))
	if _player_node and is_instance_valid(_player_node):
		pz = _player_node.global_position.z

	var t_p := clampf((pz - z_min) / maxf(z_max - z_min, 1.0), 0.0, 1.0)
	var p_chunk := clampi(int(floor(t_p * float(_chunk_count))), 0, _chunk_count - 1)
	var is_web_or_compat := OS.has_feature("web") or RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var look_ahead := 2 if is_web_or_compat else 4
	var look_behind := 1 if is_web_or_compat else 2
	var min_c := maxi(p_chunk - look_ahead, 0)
	var max_c := mini(p_chunk + look_behind, _chunk_count - 1)

	# Free distant chunks outside active window
	for existing_k in _active_chunk_keys():
		if existing_k < min_c - 1 or existing_k > max_c + 1:
			var old_node := _chunk_nodes[existing_k] as Node3D
			if old_node and is_instance_valid(old_node):
				old_node.queue_free()
			_chunk_nodes.erase(existing_k)
			_chunk_lights.erase(existing_k)
			_chunk_cages.erase(existing_k)

	# Build missing chunks in priority order (closest to player first)
	var candidates: Array[int] = []
	for c_idx in range(min_c, max_c + 1):
		if not _chunk_nodes.has(c_idx):
			candidates.append(c_idx)
	if candidates.is_empty():
		return

	candidates.sort_custom(func(a: int, b: int) -> bool:
		return absi(a - p_chunk) < absi(b - p_chunk)
	)
	var built_now := 0
	var max_initial := 2 if is_web_or_compat else candidates.size()
	for c_idx in candidates:
		_build_chunk(c_idx)
		built_now += 1
		if not build_all or built_now >= max_initial:
			break


func _active_chunk_keys() -> Array[int]:
	var out: Array[int] = []
	for k in _chunk_nodes.keys():
		out.append(int(k))
	return out


func _build_chunk(c_idx: int) -> void:
	var z_min := float(_cfg.get("z_min", -195.0))
	var z_max := float(_cfg.get("z_max", 28.0))
	var x_half := float(_cfg.get("x_half", 64.0))
	var cz0 := lerpf(z_min, z_max, float(c_idx) / float(_chunk_count))
	var cz1 := lerpf(z_min, z_max, float(c_idx + 1) / float(_chunk_count))

	var chunk := Node3D.new()
	chunk.name = "RoadChunk_%d" % c_idx
	world_geo.add_child(chunk)
	_chunk_nodes[c_idx] = chunk
	_chunk_lights[c_idx] = []
	_chunk_cages[c_idx] = []

	var grid_step := 3.0 if (OS.has_feature("web") or RenderingServer.get_current_rendering_method() == "gl_compatibility") else 2.5
	var terrain_mesh := MeshFactory3D.build_road_valley_terrain_mesh(
		cz0, cz1, x_half, grid_step, grid_step, Callable(self, "_sample_terrain")
	)
	var tbody := StaticBody3D.new()
	tbody.name = "TerrainBody"
	tbody.collision_layer = 1
	tbody.collision_mask = 0
	var tmi := MeshInstance3D.new()
	tmi.mesh = terrain_mesh
	tmi.material_override = _road_terrain_mat
	tbody.add_child(tmi)
	var tcol := CollisionShape3D.new()
	tcol.shape = terrain_mesh.create_trimesh_shape()
	tbody.add_child(tcol)
	chunk.add_child(tbody)

	var is_sky_road := bool(_cfg.get("sky_road", false))
	var is_highland := bool(_cfg.get("highland", false))
	var is_sanctum := bool(_cfg.get("sanctum", false))
	var stone_bridges := is_highland or is_sanctum or is_sky_road
	var rivers: Array = _cfg.get("rivers", [])

	for r_var in rivers:
		var rv: Dictionary = r_var
		var rz := float(rv["z"])
		if rz >= cz0 and rz < cz1:
			var b_len := float(rv.get("half_w", 9.5)) * 2.25
			_add_road_bridge(rz, b_len, 11.6, stone_bridges, chunk, c_idx)
			if is_sky_road:
				_add_mist_sheet(Vector3(0.0, -3.5, rz), Vector2(160.0, 44.0), chunk)
			else:
				_add_moonlit_water(Vector3(0.0, -1.55, rz), Vector2(165.0, 28.0), chunk)
				_add_mist_sheet(Vector3(0.0, -0.55, rz), Vector2(130.0, 32.0), chunk)

	if is_sky_road:
		_build_sky_chunk_details(cz0, cz1, chunk, c_idx)
	else:
		_build_forest_chunk_details(cz0, cz1, chunk, c_idx)

	# Build Boss Colosseums when chunk contains arena center
	var boss_z := float(_cfg.get("boss_arena_z", 99999.0))
	if boss_z < 90000.0 and boss_z >= cz0 and boss_z < cz1:
		_build_colosseum_props(chunk, c_idx, boss_z, is_sky_road)


func _build_forest_chunk_details(cz0: float, cz1: float, chunk: Node3D, c_idx: int) -> void:
	var road_start_z := float(_cfg.get("road_start_z", 16.0))
	var road_end_z := float(_cfg.get("road_end_z", -170.0))
	var rivers: Array = _cfg.get("rivers", [])
	var clearings: Array = _cfg.get("clearings", [])
	var is_highland := bool(_cfg.get("highland", false))
	var is_sanctum := bool(_cfg.get("sanctum", false))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(layout_id) + c_idx * 97 + 303

	# 1. Roadside Stone Kerbstones
	var kerb_xforms: Array = []
	var z_step := 2.8
	var z_top := minf(cz1, road_start_z)
	var z_bot := maxf(cz0, road_end_z)
	var z_cur := floor(z_top / z_step) * z_step
	while z_cur >= z_bot:
		var in_river := false
		for rv_var in rivers:
			var rv: Dictionary = rv_var
			if absf(z_cur - float(rv["z"])) < float(rv.get("half_w", 9.5)) + 2.2:
				in_river = true
				break
		if not in_river:
			var rx := _road_center_x(z_cur)
			var rw := _road_half_width(z_cur)
			var slope_ang := atan2(_road_center_x(z_cur - 2.0) - _road_center_x(z_cur + 2.0), 4.0)
			for sgn in [-1.0, 1.0]:
				var skip_side := false
				for c_var in clearings:
					var cl: Dictionary = c_var
					var cz := float(cl["z"])
					var cx := float(cl["x"])
					if bool(cl.get("connect", true)) and absf(z_cur - cz) < 5.8 and ((cx - rx) * sgn > 0.0):
						skip_side = true
						break
					if not bool(cl.get("connect", true)):
						var crx := float(cl["rx"])
						var crz := float(cl["rz"])
						if sqrt(pow((rx + sgn * rw - cx) / crx, 2.0) + pow((z_cur - cz) / crz, 2.0)) < 1.08:
							skip_side = true
							break
				if not skip_side:
					var kx := rx + sgn * (rw + 0.18)
					var ky := float(_sample_terrain(kx, z_cur)["y"])
					var sc := rng.randf_range(0.92, 1.25)
					var b := Basis(Vector3.UP, -slope_ang + rng.randf_range(-0.08, 0.08)).scaled(Vector3(sc, sc * 0.85, sc))
					kerb_xforms.append(Transform3D(b, Vector3(kx, ky + 0.04, z_cur)))
		z_cur -= z_step
	_spawn_multimesh(kerb_xforms, _kerb_mesh, MAT_STONE, chunk)

	# 2. Multi-Species Forest Trees & Colliders
	var oak_xforms: Array = []
	var pine_xforms: Array = []
	var shrub_xforms: Array = []
	var fern_xforms: Array = []
	var grass_xforms: Array = []

	var chunk_len := absf(cz1 - cz0)
	var tree_density := 0.85 if is_highland else (0.9 if is_sanctum else 1.15)
	var tree_count := int(chunk_len * tree_density)
	for i in tree_count:
		var tz := rng.randf_range(cz0 + 1.0, cz1 - 1.0)
		var rx := _road_center_x(tz)
		var rw := _road_half_width(tz)
		var side := -1.0 if (i % 2 == 0) else 1.0
		var dist := rng.randf_range(rw + 3.0, 44.0)
		var tx := rx + side * dist
		var in_river := false
		for rv_var in rivers:
			var rv: Dictionary = rv_var
			if absf(tz - float(rv["z"])) < float(rv.get("half_w", 9.5)) + 2.5:
				in_river = true
				break
		if in_river:
			continue
		var samp := _sample_terrain(tx, tz)
		var col_c: Color = samp["col"]
		if col_c.r > 0.28 or col_c.g > 0.28:
			continue
		var ty := float(samp["y"]) - 0.18
		var sc := rng.randf_range(0.95, 1.62)
		var rot := rng.randf_range(0.0, TAU)
		var xf := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc), Vector3(tx, ty, tz))
		if is_highland:
			if i % 5 < 4:
				pine_xforms.append(xf)
			else:
				oak_xforms.append(xf)
		else:
			if i % 5 < 3:
				pine_xforms.append(xf)
			else:
				oak_xforms.append(xf)

		if dist < 24.5:
			var tbody := StaticBody3D.new()
			tbody.collision_layer = 1
			tbody.collision_mask = 0
			tbody.position = Vector3(tx, ty + 3.5 * sc, tz)
			var tcol := CollisionShape3D.new()
			var tcs := CylinderShape3D.new()
			tcs.radius = 0.65 * sc
			tcs.height = 7.0 * sc
			tcol.shape = tcs
			tbody.add_child(tcol)
			chunk.add_child(tbody)

	_spawn_multimesh(oak_xforms, _oak_trunk_mesh, MAT_BARK, chunk)
	_spawn_multimesh(oak_xforms, _oak_canopy_mesh, _canopy_mat, chunk)
	_spawn_multimesh(pine_xforms, _pine_trunk_mesh, MAT_BARK, chunk)
	_spawn_multimesh(pine_xforms, _pine_canopy_mesh, _pine_mat, chunk)

	# 3. Woodland Shrubs, Ferns & Grass Carpet
	var grass_total := int(chunk_len * 3.1)
	for i in grass_total:
		var gz := rng.randf_range(cz0 + 0.5, cz1 - 0.5)
		var gx := _road_center_x(gz) + rng.randf_range(-34.0, 34.0)
		var samp := _sample_terrain(gx, gz)
		var c: Color = samp["col"]
		var gy := float(samp["y"]) - 0.04
		if c.r > 0.52 or c.g > 0.52 or gy < -0.64:
			continue
		var sc := rng.randf_range(0.75, 1.4)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * sc), Vector3(gx, gy, gz))
		var roll := i % 10
		if roll < 2:
			shrub_xforms.append(xf)
		elif roll < 5:
			fern_xforms.append(xf)
		else:
			grass_xforms.append(xf)

	_spawn_multimesh(shrub_xforms, _shrub_mesh, _canopy_mat, chunk)
	_spawn_multimesh(fern_xforms, _fern_mesh, _fern_mat, chunk)
	_spawn_multimesh(grass_xforms, _grass_mesh, _grass_mat, chunk)

	# 4. Chunk Landmarks, Lanterns, Archways, Ruins, Braziers, Boulders & God Rays
	_populate_chunk_landmarks(cz0, cz1, chunk, c_idx)


func _add_guardrail_segment(p0: Vector3, p1: Vector3, chunk: Node3D, kerb_xforms: Array) -> void:
	var dx := p1.x - p0.x
	var dz := p1.z - p0.z
	var seg_len := sqrt(dx * dx + dz * dz)
	if seg_len < 0.25:
		return
	var yaw := atan2(dx, dz)
	var mid := (p0 + p1) * 0.5
	var gbody := StaticBody3D.new()
	gbody.collision_layer = 1
	gbody.collision_mask = 0
	gbody.position = Vector3(mid.x, mid.y + 1.0, mid.z)
	gbody.rotation.y = yaw
	var gcol := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(0.75, 2.4, seg_len + 0.35)
	gcol.shape = gbox
	gbody.add_child(gcol)
	chunk.add_child(gbody)

	var steps := maxi(int(ceil(seg_len / 2.6)), 1)
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		var kp := p0.lerp(p1, t)
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(1.1, 1.45, 1.15))
		kerb_xforms.append(Transform3D(b, Vector3(kp.x, kp.y + 0.16, kp.z)))


func _build_sky_chunk_details(cz0: float, cz1: float, chunk: Node3D, c_idx: int) -> void:
	## Stage 4 Celestial Sky-Road: stone balustrade kerbs + safety shoulders,
	## billowing 3D cloudbanks right beside & under the road, floating sky-islands, and starlit ruins.
	var road_start_z := float(_cfg.get("road_start_z", 16.0))
	var road_end_z := float(_cfg.get("road_end_z", -4920.0))
	var boss_z := float(_cfg.get("boss_arena_z", 99999.0))
	var rivers: Array = _cfg.get("rivers", [])
	var clearings: Array = _cfg.get("clearings", [])

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(layout_id) + c_idx * 131 + 707

	# 1. Carved Stone Parapet Kerbs + Invisible Shoulder Guardrails
	var kerb_xforms: Array = []
	var grass_xforms: Array = []
	var z_step := 2.6
	var z_top := minf(cz1, road_start_z)
	var effective_end := maxf(road_end_z, boss_z + 24.0) if boss_z < 90000.0 else road_end_z
	var z_bot := maxf(cz0, effective_end)
	var z_cur := floor(z_top / z_step) * z_step
	while z_cur >= z_bot:
		var in_river := false
		for rv_var in rivers:
			var rv: Dictionary = rv_var
			var rh := float(rv.get("half_w", 9.5))
			if absf(z_cur - float(rv["z"])) < rh * 1.125 + 2.2:
				in_river = true
				break
		if not in_river:
			var rx := _road_center_x(z_cur)
			var rw := _road_half_width(z_cur)
			var slope_ang := atan2(_road_center_x(z_cur - 2.0) - _road_center_x(z_cur + 2.0), 4.0)
			for sgn in [-1.0, 1.0]:
				var skip_side := false
				for c_var in clearings:
					var cl: Dictionary = c_var
					var cz := float(cl["z"])
					var cx := float(cl["x"])
					var crx := float(cl["rx"])
					var crz := float(cl["rz"])
					if sqrt(pow((rx + sgn * rw - cx) / crx, 2.0) + pow((z_cur - cz) / crz, 2.0)) < 1.08:
						skip_side = true
						break
					if bool(cl.get("connect", true)) and absf(z_cur - cz) < 4.3 and ((cx - rx) * sgn > 0.0):
						skip_side = true
						break
				if not skip_side:
					var kx := rx + sgn * (rw + 0.15)
					var ky := float(_sample_terrain(kx, z_cur)["y"])
					var b := Basis(Vector3.UP, -slope_ang).scaled(Vector3(1.1, 1.45, 1.15))
					kerb_xforms.append(Transform3D(b, Vector3(kx, ky + 0.16, z_cur)))

					# Safety shoulder guardrail collider so player stays securely on the sky-road
					var gbody := StaticBody3D.new()
					gbody.collision_layer = 1
					gbody.collision_mask = 0
					gbody.position = Vector3(rx + sgn * (rw + 0.75), ky + 1.0, z_cur)
					gbody.rotation.y = -slope_ang
					var gcol := CollisionShape3D.new()
					var gbox := BoxShape3D.new()
					gbox.size = Vector3(0.7, 2.2, z_step + 0.4)
					gcol.shape = gbox
					gbody.add_child(gcol)
					chunk.add_child(gbody)
		z_cur -= z_step

	# 1b. Chasm Bridge Corner Funnel Guardrails (seamlessly link wide sky-road to 11.6m bridges)
	for rv_var in rivers:
		var rv: Dictionary = rv_var
		var rz := float(rv["z"])
		if rz >= cz0 and rz < cz1:
			var r_half := float(rv.get("half_w", 9.5))
			var b_half := r_half * 1.125
			var z_gap := b_half + 2.2
			var cx_b := _road_center_x(rz)
			for end_sgn in [-1.0, 1.0]:
				var z_in := rz + end_sgn * (b_half - 0.25)
				var z_out := rz + end_sgn * (z_gap + 0.4)
				var rx_out := _road_center_x(z_out)
				var rw_out := _road_half_width(z_out)
				var y_out := float(_sample_terrain(rx_out, z_out)["y"])
				for s_sgn in [-1.0, 1.0]:
					_add_guardrail_segment(
						Vector3(rx_out + s_sgn * (rw_out + 0.75), y_out, z_out),
						Vector3(cx_b + s_sgn * 5.45, 0.18, z_in),
						chunk, kerb_xforms
					)

	# 1c. Start Plaza, Connected Sky-Islands & Astral Summit Colosseum Perimeter Guardrails
	for c_var in clearings:
		var cl: Dictionary = c_var
		var cz := float(cl["z"])
		if cz < cz0 or cz >= cz1:
			continue
		var cx := float(cl["x"])
		var crx := float(cl["rx"])
		var crz := float(cl["rz"])
		var is_conn := bool(cl.get("connect", true))
		var rx_c := _road_center_x(cz)
		var rw_c := _road_half_width(cz)
		var sgn_c := 1.0 if cx > rx_c else -1.0
		var ring_y := float(_sample_terrain(cx, cz)["y"])
		var segs := 36 if crx > 18.0 else 24
		for si in segs:
			var a0 := (float(si) / float(segs)) * TAU
			var a1 := (float(si + 1) / float(segs)) * TAU
			var am := 0.5 * (a0 + a1)
			var p0 := Vector3(cx + cos(a0) * (crx + 0.15), ring_y, cz + sin(a0) * (crz + 0.15))
			var p1 := Vector3(cx + cos(a1) * (crx + 0.15), ring_y, cz + sin(a1) * (crz + 0.15))
			var pm_x := cx + cos(am) * (crx + 0.15)
			var pm_z := cz + sin(am) * (crz + 0.15)
			var on_road_band := absf(pm_x - _road_center_x(pm_z)) < (_road_half_width(pm_z) + 0.8)
			var open_seg := false
			if not is_conn:
				if cz > road_end_z + 60.0:
					open_seg = on_road_band and pm_z < cz - 1.0
				else:
					open_seg = on_road_band and pm_z > cz + 1.0
			else:
				open_seg = on_road_band or (absf(pm_z - cz) < 4.3 and (pm_x - cx) * sgn_c < 0.0)
			if not open_seg:
				_add_guardrail_segment(p0, p1, chunk, kerb_xforms)

		if is_conn:
			var x_road_edge := rx_c + sgn_c * (rw_c + 0.65)
			var x_cl_neck := cx - sgn_c * crx * sqrt(maxf(1.0 - pow(4.1 / crz, 2.0), 0.1))
			if (x_cl_neck - x_road_edge) * sgn_c > 0.3:
				for z_sgn in [-1.0, 1.0]:
					var nz := cz + z_sgn * 4.1
					_add_guardrail_segment(
						Vector3(x_road_edge, ring_y, nz),
						Vector3(x_cl_neck, ring_y, nz),
						chunk, kerb_xforms
					)

	_spawn_multimesh(kerb_xforms, _kerb_mesh, MAT_STONE, chunk)

	# 2. Luminous Billowing 3D Cloudbanks flanking and drifting below the sky-road
	var cloud_xforms: Array = []
	var cloud_count := 38
	for ci in cloud_count:
		var cl_z := rng.randf_range(cz0, cz1)
		var rx := _road_center_x(cl_z)
		var side := -1.0 if (ci % 2 == 0) else 1.0
		var lat := rng.randf_range(16.0, 78.0) if (ci % 4 != 0) else rng.randf_range(-12.0, 12.0)
		var cl_x := (rx + side * lat) if (ci % 4 != 0) else (rx + lat)
		var base_y := _road_base_y(cl_z)
		var cl_y := base_y - (rng.randf_range(10.0, 20.0) if (ci % 4 == 0) else rng.randf_range(3.5, 15.5))
		var sx := rng.randf_range(0.85, 2.15)
		var sy := rng.randf_range(0.65, 1.35)
		var sz := rng.randf_range(0.95, 2.35)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sx, sy, sz)), Vector3(cl_x, cl_y, cl_z))
		cloud_xforms.append(xf)
	_spawn_multimesh(cloud_xforms, _cloud_mesh, _cloud_mat, chunk)

	# 3. Floating Celestial Sky-Islands + Silver-Canopy Trees + Rune Monoliths beside the road
	var sky_oak_xforms: Array = []
	var island_step := 44.0
	var iz := floor(cz1 / island_step) * island_step
	var is_idx := 0
	while iz >= cz0:
		var side := -1.0 if ((is_idx + c_idx) % 2 == 0) else 1.0
		var rx := _road_center_x(iz)
		var ix := rx + side * rng.randf_range(29.0, 48.0)
		var skip_isl := false
		for c_var in clearings:
			var cl: Dictionary = c_var
			if absf(iz - float(cl["z"])) < 26.0:
				skip_isl = true
				break
		if not skip_isl:
			var iy := _road_base_y(iz) + rng.randf_range(-2.5, 6.5)
			var isl := MeshInstance3D.new()
			isl.mesh = _sky_island_mesh
			var isc := rng.randf_range(0.75, 1.35)
			isl.position = Vector3(ix, iy - 2.6 * isc, iz)
			isl.rotation.y = rng.randf_range(0.0, TAU)
			isl.scale = Vector3.ONE * isc
			isl.material_override = _terrain_stone_mat
			chunk.add_child(isl)

			sky_oak_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), Vector3(ix, iy - 0.1, iz)))
			if is_idx % 2 == 0:
				_add_rune_monolith(Vector3(ix + side * 2.2, iy, iz + 2.5), rng.randf_range(0.0, TAU), chunk)
			else:
				_add_pillar(Vector3(ix - side * 2.0, iy, iz - 2.0), 5.6, chunk)
		is_idx += 1
		iz -= island_step

	_spawn_multimesh(sky_oak_xforms, _oak_trunk_mesh, MAT_BARK, chunk)
	_spawn_multimesh(sky_oak_xforms, _oak_canopy_mesh, _pine_mat, chunk)
	_spawn_multimesh(grass_xforms, _grass_mesh, _grass_mat, chunk)

	# 4. Celestial Lanterns, Arches, Braziers, Pillars & God Rays along the sky-road
	_populate_chunk_landmarks(cz0, cz1, chunk, c_idx)


func _populate_chunk_landmarks(cz0: float, cz1: float, chunk: Node3D, c_idx: int) -> void:
	var road_start_z := float(_cfg.get("road_start_z", 16.0))
	var road_end_z := float(_cfg.get("road_end_z", -170.0))
	var rivers: Array = _cfg.get("rivers", [])
	var clearings: Array = _cfg.get("clearings", [])
	var is_highland := bool(_cfg.get("highland", false))
	var is_sanctum := bool(_cfg.get("sanctum", false))
	var is_sky_road := bool(_cfg.get("sky_road", false))
	var boss_z := float(_cfg.get("boss_arena_z", 99999.0))

	var z_top := minf(cz1, road_start_z - 4.0)
	var z_bot := maxf(cz0, road_end_z + 6.0)

	# Alternating Lantern Avenue every 22m
	var l_step := 22.0
	var z_l := floor(z_top / l_step) * l_step
	var side_i := 0
	while z_l >= z_bot:
		var near_riv := false
		for rv_var in rivers:
			if absf(z_l - float((rv_var as Dictionary)["z"])) < float((rv_var as Dictionary).get("half_w", 9.5)) + 4.0:
				near_riv = true
				break
		var near_arena := absf(z_l - boss_z) < 28.0
		if not near_riv and not near_arena:
			var rx := _road_center_x(z_l)
			var rw := _road_half_width(z_l)
			var sgn := -1.0 if ((side_i + c_idx) % 2 == 0) else 1.0
			var lx := rx + sgn * (rw + 0.55)
			var ly := float(_sample_terrain(lx, z_l)["y"])
			_add_lantern(Vector3(lx, ly, z_l), chunk, c_idx)
			side_i += 1
		z_l -= l_step

	# Monumental Archways every 220m (plus trailhead at road_start_z - 4)
	var a_step := 220.0
	var z_a := floor(z_top / a_step) * a_step
	while z_a >= z_bot:
		var near_riv := false
		for rv_var in rivers:
			if absf(z_a - float((rv_var as Dictionary)["z"])) < 22.0:
				near_riv = true
				break
		if not near_riv and absf(z_a - boss_z) > 34.0:
			_add_road_archway(z_a, 13.6, 7.8, chunk)
		z_a -= a_step

	# Scenery Props: Ruin Pillars, Monoliths, Camp Braziers, Boulders, Fallen Logs, Mushrooms, God Rays
	var p_step := 55.0
	var z_p := floor(z_top / p_step) * p_step
	var p_idx := 0
	while z_p >= z_bot:
		var near_riv := false
		for rv_var in rivers:
			if absf(z_p - float((rv_var as Dictionary)["z"])) < 18.0:
				near_riv = true
				break
		if not near_riv and absf(z_p - boss_z) > 32.0:
			var rx := _road_center_x(z_p)
			var rw := _road_half_width(z_p)
			var sgn := -1.0 if ((p_idx + c_idx) % 2 == 0) else 1.0
			var px := rx + sgn * (rw + 1.6)
			var py := float(_sample_terrain(px, z_p)["y"])
			var style_roll := (p_idx + c_idx) % 5
			if is_sky_road:
				if style_roll in [0, 2]:
					_add_pillar(Vector3(rx - (rw + 1.1), float(_sample_terrain(rx - (rw + 1.1), z_p)["y"]), z_p), 6.2, chunk)
					_add_pillar(Vector3(rx + (rw + 1.1), float(_sample_terrain(rx + (rw + 1.1), z_p)["y"]), z_p), 6.2, chunk)
				elif style_roll == 1:
					_add_camp_brazier(Vector3(rx + sgn * (rw - 0.3), float(_sample_terrain(rx + sgn * (rw - 0.3), z_p)["y"]), z_p), chunk, c_idx)
				else:
					_add_rune_monolith(Vector3(rx + sgn * (rw + 0.8), float(_sample_terrain(rx + sgn * (rw + 0.8), z_p)["y"]), z_p), sgn * 0.4, chunk, c_idx)
			elif is_sanctum:
				_add_pillar(Vector3(rx - (rw + 1.1), float(_sample_terrain(rx - (rw + 1.1), z_p)["y"]), z_p), 6.6, chunk)
				_add_pillar(Vector3(rx + (rw + 1.1), float(_sample_terrain(rx + (rw + 1.1), z_p)["y"]), z_p), 6.6, chunk)
				if style_roll == 1:
					_add_camp_brazier(Vector3(rx + sgn * (rw + 0.3), float(_sample_terrain(rx + sgn * (rw + 0.3), z_p)["y"]), z_p + 4.0), chunk, c_idx)
				elif style_roll == 3:
					_add_rune_monolith(Vector3(rx + sgn * (rw + 3.2), float(_sample_terrain(rx + sgn * (rw + 3.2), z_p)["y"]), z_p), sgn * 0.35, chunk, c_idx)
			elif is_highland:
				if style_roll == 0:
					_add_boulder(Vector3(px + sgn * 1.4, py + 0.3, z_p), Vector3(1.8, 1.35, 1.6), chunk)
				elif style_roll == 1:
					_add_camp_brazier(Vector3(px, py, z_p), chunk, c_idx)
				elif style_roll == 2:
					_add_pillar(Vector3(px, py, z_p), 5.6, chunk)
				elif style_roll == 3:
					_add_rune_monolith(Vector3(px + sgn * 0.8, py, z_p), sgn * 0.5, chunk, c_idx)
				else:
					_add_boulder(Vector3(px + sgn * 1.8, py + 0.4, z_p), Vector3(2.2, 1.6, 1.8), chunk)
			else:
				if style_roll == 0:
					_add_camp_brazier(Vector3(px, py, z_p), chunk, c_idx)
					_add_fallen_log(Vector3(px + sgn * 1.8, py, z_p + 1.8), sgn * 0.4, 0.95, chunk)
				elif style_roll == 1:
					_add_boulder(Vector3(px + sgn * 0.9, py + 0.28, z_p), Vector3(1.5, 1.0, 1.4), chunk)
					_add_mushrooms(Vector3(px - sgn * 0.6, py, z_p + 1.5), chunk)
				elif style_roll == 2:
					_add_pillar(Vector3(rx - (rw + 1.2), float(_sample_terrain(rx - (rw + 1.2), z_p)["y"]), z_p), 6.0, chunk)
					_add_pillar(Vector3(rx + (rw + 1.2), float(_sample_terrain(rx + (rw + 1.2), z_p)["y"]), z_p), 6.0, chunk)
				elif style_roll == 3:
					_add_rune_monolith(Vector3(px + sgn * 1.0, py, z_p), sgn * 0.5, chunk, c_idx)
				else:
					_add_mushrooms(Vector3(px, py, z_p), chunk)
					_add_fallen_log(Vector3(px + sgn * 1.2, py, z_p - 2.0), -sgn * 0.6, 1.0, chunk)

			if p_idx % 2 == 0:
				_add_god_rays([Vector3(rx, float(_sample_terrain(rx, z_p)["y"]), z_p)], chunk)
		p_idx += 1
		z_p -= p_step

	# Clearing turnoff signposts & side clearing focal landmarks
	for c_var in clearings:
		var cl: Dictionary = c_var
		var cz := float(cl["z"])
		var cx := float(cl["x"])
		if cz >= cz0 and cz < cz1 and bool(cl.get("connect", true)):
			var rx := _road_center_x(cz)
			var rw := _road_half_width(cz)
			var sgn := 1.0 if cx > rx else -1.0
			var sx := rx + sgn * (rw + 0.6)
			_add_signpost(Vector3(sx, float(_sample_terrain(sx, cz - 4.5)["y"]), cz - 4.5), 15.0 if sgn > 0.0 else 180.0, chunk)
			var mx := cx + sgn * 4.5
			_add_rune_monolith(Vector3(mx, float(_sample_terrain(mx, cz)["y"]), cz), -sgn * 1.55, chunk, c_idx)
			_add_mushrooms(Vector3(cx + sgn * 2.0, float(_sample_terrain(cx + sgn * 2.0, cz - 3.5)["y"]), cz - 3.5), chunk)


func _build_colosseum_props(chunk: Node3D, c_idx: int, arena_z: float, is_astral: bool) -> void:
	## Builds Grand Colosseum Stone Altar (solid collider), 8 perimeter pillars, lanterns, monoliths & mist.
	var ped_body := StaticBody3D.new()
	ped_body.collision_layer = 1
	ped_body.collision_mask = 0
	ped_body.position = Vector3(0.0, 0.14, arena_z)
	var ped_col := CollisionShape3D.new()
	var pbox := BoxShape3D.new()
	pbox.size = Vector3(4.6, 0.28, 4.6)
	ped_col.shape = pbox
	ped_body.add_child(ped_col)
	var ped_mi := MeshInstance3D.new()
	var pbm := CylinderMesh.new()
	pbm.top_radius = 2.4
	pbm.bottom_radius = 2.8
	pbm.height = 0.28
	ped_mi.mesh = pbm
	ped_mi.material_override = MAT_STONE
	ped_body.add_child(ped_mi)
	chunk.add_child(ped_body)

	for ang_deg in [20, 60, 120, 160, 200, 240, 300, 340]:
		var rad := deg_to_rad(ang_deg)
		_add_pillar(Vector3(cos(rad) * 23.0, 0.0, arena_z + sin(rad) * 22.0), 8.0, chunk)
		_add_lantern(Vector3(cos(rad) * 20.5, 0.0, arena_z + sin(rad) * 19.5), chunk, c_idx)
	for ang_deg in [40, 140, 220, 320]:
		var rad2 := deg_to_rad(ang_deg)
		_add_rune_monolith(Vector3(cos(rad2) * 23.5, 0.0, arena_z + sin(rad2) * 22.5), -rad2 + PI * 0.5, chunk, c_idx)

	_add_mushrooms(Vector3(-3.4, 0.0, arena_z - 3.4), chunk)
	_add_mushrooms(Vector3(3.4, 0.0, arena_z - 3.4), chunk)
	_add_mist_sheet(Vector3(0.0, -2.5 if is_astral else 0.3, arena_z), Vector2(64.0, 64.0), chunk)
	_add_god_rays([
		Vector3(0.0, 0.0, arena_z),
		Vector3(-11.0, 0.0, arena_z - 9.0),
		Vector3(11.0, 0.0, arena_z - 9.0),
	], chunk)


func _add_road_bridge(z_center: float, bridge_len: float = 20.0, bridge_w: float = 10.6, stone_style: bool = false, parent: Node3D = null, c_idx: int = -1) -> void:
	## Wide, sturdy, jump-free road bridge spanning smoothly across a river/gorge.
	var target_p := parent if parent else world_geo
	var cx := _road_center_x(z_center)
	var yaw := -atan2(_road_center_x(z_center - 4.0) - _road_center_x(z_center + 4.0), 8.0)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(cx, 0.0, z_center)
	body.rotation.y = yaw

	var deck_col := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	deck_box.size = Vector3(bridge_w, 0.44, bridge_len)
	deck_col.shape = deck_box
	deck_col.position = Vector3(0.0, -0.04, 0.0)
	body.add_child(deck_col)

	for end_sgn in [-1.0, 1.0]:
		var ramp_col := CollisionShape3D.new()
		var rbox := BoxShape3D.new()
		rbox.size = Vector3(bridge_w, 0.4, 3.6)
		ramp_col.shape = rbox
		ramp_col.position = Vector3(0.0, -0.14, end_sgn * (bridge_len * 0.5 + 1.4))
		ramp_col.rotation.x = end_sgn * deg_to_rad(5.5)
		body.add_child(ramp_col)

	for side_sgn in [-0.4, 0.0, 0.4]:
		var beam := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(0.38, 0.48, bridge_len + 1.8)
		beam.mesh = bmesh
		beam.position = Vector3(bridge_w * side_sgn, -0.26, 0.0)
		beam.material_override = MAT_STONE if stone_style else MAT_BARK
		body.add_child(beam)

	for end_sgn in [-1.0, 1.0]:
		var abut := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(bridge_w + 1.6, 2.8, 2.2)
		abut.mesh = am
		abut.position = Vector3(0.0, -1.25, end_sgn * (bridge_len * 0.5 - 0.6))
		abut.material_override = MAT_STONE
		body.add_child(abut)

	var plank_step := 0.72
	var plank_count := maxi(int(bridge_len / plank_step), 8)
	for i in plank_count:
		var t := (float(i) + 0.5) / float(plank_count) - 0.5
		var z_off := t * bridge_len
		var p_mi := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(bridge_w, 0.16, plank_step * 0.88)
		p_mi.mesh = pm
		p_mi.position = Vector3(0.0, 0.1 + sin(float(i) * 2.1) * 0.01, z_off)
		p_mi.material_override = MAT_STONE if stone_style else MAT_WOOD
		body.add_child(p_mi)

	for s_sgn in [-0.47, 0.47]:
		var lat := bridge_w * s_sgn
		var rail_col := CollisionShape3D.new()
		var rcb := BoxShape3D.new()
		rcb.size = Vector3(0.45, 1.4, bridge_len)
		rail_col.shape = rcb
		rail_col.position = Vector3(lat, 0.7, 0.0)
		body.add_child(rail_col)

		var rail := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.075
		rm.bottom_radius = 0.075
		rm.height = bridge_len
		rail.mesh = rm
		rail.position = Vector3(lat, 1.05, 0.0)
		rail.rotation.x = PI * 0.5
		rail.material_override = MAT_STONE if stone_style else MAT_BARK
		body.add_child(rail)

		for l_frac in [-0.44, -0.15, 0.15, 0.44]:
			var z_p := bridge_len * l_frac
			var post := MeshInstance3D.new()
			var cmesh := CylinderMesh.new()
			cmesh.top_radius = 0.14
			cmesh.bottom_radius = 0.18
			cmesh.height = 1.45
			post.mesh = cmesh
			post.position = Vector3(lat, 0.7, z_p)
			post.material_override = MAT_STONE if stone_style else MAT_BARK
			body.add_child(post)

			var cap := MeshInstance3D.new()
			cap.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.12, 0.18, 0.1, 10)
			cap.position = Vector3(lat, 1.42, z_p)
			cap.material_override = MAT_FILIGREE
			body.add_child(cap)

	target_p.add_child(body)
	_add_lantern(Vector3(cx - bridge_w * 0.48, 0.0, z_center + bridge_len * 0.42), target_p, c_idx)
	_add_lantern(Vector3(cx + bridge_w * 0.48, 0.0, z_center - bridge_len * 0.42), target_p, c_idx)


func _add_road_archway(z_pos: float, width: float = 12.6, height: float = 7.4, parent: Node3D = null) -> void:
	## Monumental carved stone archway spanning high over the road (terrain-snapped, camera-safe!).
	var target_p := parent if parent else world_geo
	var cx := _road_center_x(z_pos)
	var half_w := width * 0.5
	var yl := float(_sample_terrain(cx - half_w, z_pos)["y"])
	var yr := float(_sample_terrain(cx + half_w, z_pos)["y"])
	var yc := maxf(yl, yr)
	_add_pillar(Vector3(cx - half_w, yl - 0.3, z_pos), height + (yc - yl) + 0.3, target_p)
	_add_pillar(Vector3(cx + half_w, yr - 0.3, z_pos), height + (yc - yr) + 0.3, target_p)

	var arch := StaticBody3D.new()
	arch.collision_layer = 1
	arch.collision_mask = 0
	arch.position = Vector3(cx, yc + height + 0.55, z_pos)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(width + 2.4, 1.15, 1.65)
	lintel.mesh = lm
	lintel.material_override = MAT_STONE
	arch.add_child(lintel)

	var keystone := MeshInstance3D.new()
	keystone.mesh = MeshFactory3D.build_rune_shard_mesh(0.55, 1.35, int(absf(z_pos)) + 3)
	keystone.position = Vector3(0.0, 0.0, 0.0)
	keystone.material_override = MAT_RUNE
	arch.add_child(keystone)

	target_p.add_child(arch)


func _spawn_multimesh(xforms: Array, mesh_res: Mesh, mat: Material, parent: Node3D = null) -> void:
	if xforms.is_empty() or not mesh_res:
		return
	var target_p := parent if parent else world_geo
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_res
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	target_p.add_child(mmi)


func _add_signpost(base_pos: Vector3, yaw_deg: float = 0.0, parent: Node3D = null) -> void:
	var target_p := parent if parent else world_geo
	var root := Node3D.new()
	root.position = base_pos + Vector3(0.0, -0.15, 0.0)
	root.rotation.y = deg_to_rad(yaw_deg)

	var post := MeshInstance3D.new()
	post.mesh = MeshFactory3D.build_gnarled_trunk_mesh(2.3, 0.14, 0.09, int(absf(base_pos.z)) + 5)
	post.material_override = MAT_BARK
	root.add_child(post)

	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.15, 0.32, 0.1)
	board.mesh = bm
	board.position = Vector3(0.45, 1.95, 0.0)
	board.material_override = MAT_WOOD
	root.add_child(board)

	var tip := MeshInstance3D.new()
	tip.mesh = MeshFactory3D.build_rune_shard_mesh(0.11, 0.28, 3)
	tip.position = Vector3(1.05, 1.95, 0.0)
	tip.rotation.z = -PI * 0.5
	tip.material_override = MAT_FILIGREE
	root.add_child(tip)

	target_p.add_child(root)


func _add_camp_brazier(base_pos: Vector3, parent: Node3D = null, c_idx: int = -1) -> void:
	var target_p := parent if parent else world_geo
	var root := Node3D.new()
	root.position = base_pos

	for i in 8:
		var ang := (float(i) / 8.0) * TAU
		var rock := MeshInstance3D.new()
		rock.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.28, 0.2, 0.24), i + 30)
		rock.position = Vector3(cos(ang) * 0.72, 0.12, sin(ang) * 0.72)
		rock.material_override = MAT_STONE
		root.add_child(rock)

	var embers := MeshInstance3D.new()
	embers.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.48, 0.18, 0.46), 7)
	embers.position = Vector3(0.0, 0.1, 0.0)
	embers.material_override = _ember_mat
	root.add_child(embers)

	var lt := OmniLight3D.new()
	lt.position = Vector3(0.0, 0.7, 0.0)
	lt.light_color = Color(1.0, 0.65, 0.28, 1.0)
	lt.light_energy = 2.6
	lt.omni_range = 12.0
	lt.distance_fade_enabled = true
	lt.distance_fade_begin = 46.0
	lt.distance_fade_length = 16.0
	root.add_child(lt)
	if c_idx >= 0 and _chunk_lights.has(c_idx):
		(_chunk_lights[c_idx] as Array).append(lt)

	target_p.add_child(root)


func _add_boulder(pos: Vector3, scale_vec: Vector3 = Vector3(1.4, 1.0, 1.2), parent: Node3D = null) -> void:
	var target_p := parent if parent else world_geo
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = pos.x * 0.7 + pos.z * 0.3

	var col := CollisionShape3D.new()
	var cs := SphereShape3D.new()
	cs.radius = 0.76 * maxf(scale_vec.x, scale_vec.z)
	col.shape = cs
	body.add_child(col)

	var seed_v := int(absf(pos.x * 19.0 + pos.z * 31.0)) + 3
	var main_rock := MeshInstance3D.new()
	main_rock.mesh = MeshFactory3D.build_boulder_mesh(scale_vec * 0.88, seed_v)
	main_rock.material_override = _terrain_stone_mat
	body.add_child(main_rock)

	var side_rock := MeshInstance3D.new()
	side_rock.mesh = MeshFactory3D.build_boulder_mesh(scale_vec * 0.42, seed_v + 7)
	side_rock.position = Vector3(scale_vec.x * 0.65, -scale_vec.y * 0.28, scale_vec.z * 0.35)
	side_rock.material_override = _terrain_stone_mat
	body.add_child(side_rock)

	target_p.add_child(body)


func _add_fallen_log(base_pos: Vector3, rot_y: float = 0.4, scale_f: float = 1.0, parent: Node3D = null) -> void:
	var target_p := parent if parent else world_geo
	var root := Node3D.new()
	root.position = base_pos
	root.rotation.y = rot_y
	root.scale = Vector3.ONE * scale_f

	var log_mi := MeshInstance3D.new()
	log_mi.mesh = MeshFactory3D.build_gnarled_trunk_mesh(4.2, 0.46, 0.34, int(absf(base_pos.x * 7.0)) + 1)
	log_mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	log_mi.position = Vector3(0.0, 0.32, -2.1)
	log_mi.material_override = MAT_BARK
	root.add_child(log_mi)

	for s_i in 3:
		var m_s := MeshInstance3D.new()
		m_s.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.22, 0.05, 0.16), s_i + 2)
		m_s.position = Vector3(0.36, 0.4, -1.2 + float(s_i) * 1.1)
		m_s.material_override = _glow_mush_mat
		root.add_child(m_s)

	target_p.add_child(root)


func _add_rune_monolith(base_pos: Vector3, rot_y: float = 0.0, parent: Node3D = null, _c_idx: int = -1) -> void:
	var target_p := parent if parent else world_geo
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base_pos + Vector3(0.0, -0.22, 0.0)
	body.rotation.y = rot_y

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.35, 4.4, 0.85)
	col.shape = bs
	col.position = Vector3(0.0, 2.2, 0.0)
	body.add_child(col)

	var obelisk := MeshInstance3D.new()
	obelisk.mesh = MeshFactory3D.build_lofted_tube_mesh([
		{"center": Vector3(0, 0, 0), "rx": 0.82, "rz": 0.56, "v": 0},
		{"center": Vector3(0, 0.4, 0), "rx": 0.72, "rz": 0.46, "v": 0.15},
		{"center": Vector3(0, 3.5, 0), "rx": 0.52, "rz": 0.34, "v": 0.85},
		{"center": Vector3(0.08, 4.45, 0), "rx": 0.18, "rz": 0.14, "v": 1.0},
	], 6, true, 0, 0.0, true, true)
	obelisk.material_override = MAT_RUNE
	body.add_child(obelisk)

	for c_i in 4:
		var a := float(c_i) * (PI * 0.5) + 0.4
		var cairn := MeshInstance3D.new()
		cairn.mesh = MeshFactory3D.build_boulder_mesh(Vector3(0.38, 0.25, 0.34), c_i + 11)
		cairn.position = Vector3(cos(a) * 0.95, 0.12, sin(a) * 0.85)
		cairn.material_override = _terrain_stone_mat
		body.add_child(cairn)

	var lt := OmniLight3D.new()
	lt.position = Vector3(0.0, 2.3, 0.8)
	lt.light_color = Color(0.25, 0.92, 0.88, 1.0)
	lt.light_energy = 1.65
	lt.omni_range = 9.0
	lt.distance_fade_enabled = true
	lt.distance_fade_begin = 38.0
	lt.distance_fade_length = 14.0
	body.add_child(lt)
	target_p.add_child(body)


func _add_pillar(base_pos: Vector3, height: float = 6.0, parent: Node3D = null) -> void:
	var target_p := parent if parent else world_geo
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base_pos + Vector3(0.0, -0.2, 0.0)

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.68
	cs.height = height
	col.shape = cs
	col.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(col)

	var shaft := MeshInstance3D.new()
	shaft.mesh = MeshFactory3D.build_fluted_column_mesh(0.64, height)
	shaft.material_override = MAT_STONE
	body.add_child(shaft)

	var cap := MeshInstance3D.new()
	var cap_m := BoxMesh.new()
	cap_m.size = Vector3(1.75, 0.42, 1.75)
	cap.mesh = cap_m
	cap.position = Vector3(0.0, height + 0.2, 0.0)
	cap.material_override = MAT_STONE
	body.add_child(cap)

	target_p.add_child(body)


func _add_lantern(base_pos: Vector3, parent: Node3D = null, c_idx: int = -1) -> void:
	var target_p := parent if parent else world_geo
	var node := Node3D.new()
	node.position = base_pos + Vector3(0.0, -0.15, 0.0)

	var post := MeshInstance3D.new()
	post.mesh = MeshFactory3D.build_gnarled_trunk_mesh(2.6, 0.16, 0.09, int(absf(base_pos.x * 5.0 + base_pos.z * 3.0)) + 2)
	post.material_override = MAT_BARK
	node.add_child(post)

	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.7, 0.09, 0.09)
	arm.mesh = am
	arm.position = Vector3(0.32, 2.45, 0.0)
	arm.material_override = MAT_FILIGREE
	node.add_child(arm)

	var cage := MeshInstance3D.new()
	cage.mesh = MeshFactory3D.build_lantern_cage_mesh(0.16, 0.36)
	cage.position = Vector3(0.58, 2.18, 0.0)
	cage.material_override = MAT_FILIGREE
	node.add_child(cage)
	if c_idx >= 0 and _chunk_cages.has(c_idx):
		(_chunk_cages[c_idx] as Array).append(cage)

	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.24
	bulb.mesh = bm
	bulb.position = Vector3(0.58, 2.18, 0.0)
	bulb.material_override = _lantern_bulb_mat
	node.add_child(bulb)

	var lt := OmniLight3D.new()
	lt.position = Vector3(0.58, 2.18, 0.0)
	lt.light_color = Color(1.0, 0.8, 0.42, 1.0)
	lt.light_energy = 2.4
	lt.omni_range = 15.0
	lt.distance_fade_enabled = true
	lt.distance_fade_begin = 42.0
	lt.distance_fade_length = 16.0
	node.add_child(lt)
	if c_idx >= 0 and _chunk_lights.has(c_idx):
		(_chunk_lights[c_idx] as Array).append(lt)

	target_p.add_child(node)


func _add_mushrooms(base_pos: Vector3, parent: Node3D = null) -> void:
	var target_p := parent if parent else world_geo
	var node := Node3D.new()
	node.position = base_pos
	for cfg in [Vector3(0.0, 0.58, 0.0), Vector3(-0.36, 0.38, 0.24), Vector3(0.34, 0.44, -0.2), Vector3(0.1, 0.28, 0.32)]:
		var stem := MeshInstance3D.new()
		stem.mesh = MeshFactory3D.build_lofted_tube_mesh([
			{"center": Vector3(0, 0, 0), "rx": 0.075, "rz": 0.075, "v": 0},
			{"center": Vector3(cfg.x * 0.08, cfg.y * 0.55, 0.02), "rx": 0.052, "rz": 0.052, "v": 0.5},
			{"center": Vector3(0, cfg.y, 0), "rx": 0.04, "rz": 0.04, "v": 1.0},
		], 8, true)
		stem.position = Vector3(cfg.x, 0.0, cfg.z)
		stem.material_override = MAT_BARK
		node.add_child(stem)

		var cap := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = cfg.y * 0.44
		cm.height = cfg.y * 0.34
		cap.mesh = cm
		cap.position = Vector3(cfg.x, cfg.y, cfg.z)
		cap.material_override = _glow_mush_mat
		node.add_child(cap)
	target_p.add_child(node)


func _add_mist_sheet(pos: Vector3, size_xz: Vector2, parent: Node3D = null) -> void:
	var target_p := parent if parent else world_geo
	var mi := MeshInstance3D.new()
	var qm := PlaneMesh.new()
	qm.size = size_xz
	mi.mesh = qm
	mi.position = pos
	mi.material_override = _mist_mat
	target_p.add_child(mi)


func _add_moonlit_water(pos: Vector3, size_xz: Vector2, parent: Node3D = null) -> void:
	var target_p := parent if parent else world_geo
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size_xz
	pm.subdivide_width = 24
	pm.subdivide_depth = 24
	water.mesh = pm
	water.position = pos
	water.material_override = _water_mat
	target_p.add_child(water)


func _add_god_rays(positions: Array, parent: Node3D = null) -> void:
	var target_p := parent if parent else world_geo
	for p_var in positions:
		var p: Vector3 = p_var
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 4.6
		cm.height = 26.0
		mi.mesh = cm
		mi.position = p + Vector3(1.8, 10.5, -1.8)
		mi.rotation = Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(18.0))
		mi.material_override = _ray_mat
		target_p.add_child(mi)


func _add_reflection_probe(center: Vector3, box_size: Vector3) -> void:
	var rp := ReflectionProbe.new()
	rp.position = center
	rp.size = box_size
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	world_geo.add_child(rp)


func _add_distant_mountains(z_min: float, z_max: float, x_offset: float = 165.0) -> void:
	## Continuous flanking mountain ridges along both valley sides and far north/south horizons (never blocking the road!).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := absf(z_max - z_min) + 260.0
	var z0 := z_min - 130.0
	var segs := maxi(int(span / 45.0), 16)

	for side in [-1.0, 1.0]:
		var x_base := side * x_offset
		for i in segs:
			var zs := lerpf(z0, z0 + span, float(i) / float(segs))
			var ze := lerpf(z0, z0 + span, float(i + 1) / float(segs))
			var h0 := 36.0 + 20.0 * sin(zs * 0.025 + side) + 12.0 * cos(zs * 0.065)
			var h1 := 36.0 + 20.0 * sin(ze * 0.025 + side) + 12.0 * cos(ze * 0.065)
			var b0 := Vector3(x_base, -18.0, zs)
			var b1 := Vector3(x_base, -18.0, ze)
			var t0 := Vector3(x_base + side * 14.0, h0, zs)
			var t1 := Vector3(x_base + side * 14.0, h1, ze)
			if side > 0.0:
				st.add_vertex(b0); st.add_vertex(t0); st.add_vertex(t1)
				st.add_vertex(b0); st.add_vertex(t1); st.add_vertex(b1)
			else:
				st.add_vertex(b0); st.add_vertex(t1); st.add_vertex(t0)
				st.add_vertex(b0); st.add_vertex(b1); st.add_vertex(t1)

	for end_cfg in [[z_min - 115.0, -1.0], [z_max + 115.0, 1.0]]:
		var ez := float(end_cfg[0])
		var esgn := float(end_cfg[1])
		for i in 16:
			var xs := lerpf(-x_offset, x_offset, float(i) / 16.0)
			var xe := lerpf(-x_offset, x_offset, float(i + 1) / 16.0)
			var h0 := 34.0 + 18.0 * sin(xs * 0.03)
			var h1 := 34.0 + 18.0 * sin(xe * 0.03)
			var b0 := Vector3(xs, -18.0, ez)
			var b1 := Vector3(xe, -18.0, ez)
			var t0 := Vector3(xs, h0, ez + esgn * 14.0)
			var t1 := Vector3(xe, h1, ez + esgn * 14.0)
			if esgn < 0.0:
				st.add_vertex(b0); st.add_vertex(t0); st.add_vertex(t1)
				st.add_vertex(b0); st.add_vertex(t1); st.add_vertex(b1)
			else:
				st.add_vertex(b0); st.add_vertex(t1); st.add_vertex(t0)
				st.add_vertex(b0); st.add_vertex(b1); st.add_vertex(t1)

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mountain_mat
	world_geo.add_child(mi)


func _add_cloud_horizon_sky(z_min: float, z_max: float) -> void:
	## Infinite-feeling glowing cloud blanket beneath the celestial sky-road.
	var z_span := absf(z_max - z_min) + 420.0
	var z_mid := (z_min + z_max) * 0.5
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(560.0, z_span)
	pm.subdivide_width = 24
	pm.subdivide_depth = 96
	sea.mesh = pm
	sea.position = Vector3(0.0, -24.0, z_mid)
	sea.material_override = _cloud_mat
	world_geo.add_child(sea)


# ---------------------------------------------------------------------------
# Stage Encounter Populator (Crystals, Healing Orbs, Wayshrines, Alcoves, Traps, Enemies)
# ---------------------------------------------------------------------------

func _spawn_crystal(x: float, z: float, y_off: float = 1.1) -> void:
	var c := SCENE_CRYSTAL.instantiate() as Node3D
	var col := get_node_or_null("Collectibles")
	(col if col else self).add_child(c)
	c.global_position = Vector3(x, _ground_surface_y(x, z) + y_off, z)


func _spawn_heal(x: float, z: float, y_off: float = 1.1) -> void:
	var h := SCENE_HEAL.instantiate() as Node3D
	var col := get_node_or_null("Collectibles")
	(col if col else self).add_child(h)
	h.global_position = Vector3(x, _ground_surface_y(x, z) + y_off, z)


func _spawn_wayshrine(x: float, z: float, msg: String) -> void:
	var w := SCENE_WAYSHRINE.instantiate() as Node3D
	if "shrine_message" in w:
		w.set("shrine_message", msg)
	var ws := get_node_or_null("Wayshrines")
	(ws if ws else self).add_child(w)
	w.global_position = Vector3(x, _ground_surface_y(x, z), z)


func _spawn_hidden_path(x: float, z: float) -> void:
	var hp := SCENE_HIDDEN.instantiate() as Node3D
	var hps := get_node_or_null("HiddenPaths")
	(hps if hps else self).add_child(hp)
	hp.global_position = Vector3(x, _ground_surface_y(x, z), z)


func _spawn_spike(x: float, z: float) -> void:
	var sp := SCENE_SPIKE.instantiate() as Node3D
	var hz := get_node_or_null("Hazards")
	(hz if hz else self).add_child(sp)
	sp.global_position = Vector3(x, _ground_surface_y(x, z), z)


func _spawn_thorn(x: float, z: float) -> void:
	var th := SCENE_THORN.instantiate() as Node3D
	var hz := get_node_or_null("Hazards")
	(hz if hz else self).add_child(th)
	th.global_position = Vector3(x, _ground_surface_y(x, z), z)


func _spawn_wisp(x: float, z: float, hp_val: int = 2, chase_spd: float = 5.0) -> void:
	var w := SCENE_WISP.instantiate() as Node3D
	if "hp" in w:
		w.set("hp", hp_val)
	if "chase_speed" in w:
		w.set("chase_speed", chase_spd)
	var en := get_node_or_null("Enemies")
	(en if en else self).add_child(w)
	w.global_position = Vector3(x, _ground_surface_y(x, z) + 1.35, z)


func _populate_stage_encounters() -> void:
	if layout_id == "greybox":
		return
	var road_start_z := float(_cfg.get("road_start_z", 16.0))
	var road_end_z := float(_cfg.get("road_end_z", -4600.0))
	var rivers: Array = _cfg.get("rivers", [])
	var clearings: Array = _cfg.get("clearings", [])
	var boss_z := float(_cfg.get("boss_arena_z", 99999.0))
	var is_highland := bool(_cfg.get("highland", false))
	var is_sanctum := bool(_cfg.get("sanctum", false))
	var is_sky_road := bool(_cfg.get("sky_road", false))

	var z_top := road_start_z - 34.0
	var z_bot := road_end_z + (55.0 if boss_z < 90000.0 else 36.0)
	var span := maxf(z_top - z_bot, 100.0)

	# 0. Immediate Trailhead Archway & Opening Wayshrine visible right on spawn
	var trailhead_arch_z := road_start_z - 22.0
	_add_road_archway(trailhead_arch_z, 13.4, 7.6, world_geo)
	var first_shrine_z := road_start_z - 42.0
	_spawn_wayshrine(_road_center_x(first_shrine_z) + 4.2, first_shrine_z, "Trailhead Wayshrine Lit! Press [G] to Pulse the Golden Compass (+50)")
	for ci_open in 3:
		var oz := road_start_z - 11.0 - float(ci_open) * 6.5
		_spawn_crystal(_road_center_x(oz) + sin(float(ci_open)) * 1.4, oz, 1.1)

	# 1. Wayshrines spaced every ~540m (8 shrines per stage for steady Vitality sustain & milestones)
	var shrine_count := 8
	for si in range(1, shrine_count + 1):
		var frac := float(si) / float(shrine_count + 1)
		var sz := lerpf(z_top, z_bot, frac)
		for rv_var in rivers:
			if absf(sz - float((rv_var as Dictionary)["z"])) < 26.0:
				sz -= 32.0
		var rx := _road_center_x(sz)
		var sgn := -1.0 if (si % 2 == 0) else 1.0
		_spawn_wayshrine(rx + sgn * 3.8, sz, "Wayshrine %d Lit! Restored +1 Vitality (+50)" % si)

	# 2. Hidden Alcoves & Side Clearing Rewards
	for c_idx in clearings.size():
		var cl: Dictionary = clearings[c_idx]
		if not bool(cl.get("connect", true)):
			continue
		var cx := float(cl["x"])
		var cz := float(cl["z"])
		var rx := _road_center_x(cz)
		var sgn := 1.0 if cx > rx else -1.0
		if c_idx % 2 == 0:
			_spawn_hidden_path(lerpf(rx, cx, 0.56), cz)
		_spawn_crystal(cx - sgn * 2.0, cz - 2.4)
		_spawn_crystal(cx - sgn * 2.0, cz + 2.4)
		_spawn_crystal(cx + sgn * 2.0, cz)
		_spawn_heal(cx, cz)

	# 3. Crystal Trails along the entire road & across bridges
	var c_step := 54.0
	var z_c := z_top + 16.0
	var c_i := 0
	while z_c >= z_bot:
		var rx := _road_center_x(z_c)
		var lat := sin(float(c_i) * 0.85) * 2.8
		var on_bridge := false
		for rv_var in rivers:
			if absf(z_c - float((rv_var as Dictionary)["z"])) < 14.0:
				on_bridge = true
				lat = 0.0
				break
		if absf(z_c - boss_z) > 30.0:
			_spawn_crystal(rx + lat, z_c, 1.25 if on_bridge else 1.1)
		c_i += 1
		z_c -= c_step

	# 4. Healing Dew Orbs on long stretches & before boss arenas
	for hi in 4:
		var hz := lerpf(z_top, z_bot, float(hi + 1) / 5.0)
		for rv_var in rivers:
			if absf(hz - float((rv_var as Dictionary)["z"])) < 22.0:
				hz -= 26.0
		_spawn_heal(_road_center_x(hz), hz)
	if boss_z < 90000.0:
		_spawn_heal(-16.5, boss_z)
		_spawn_heal(16.5, boss_z)
		_spawn_crystal(-12.5, boss_z - 10.0)
		_spawn_crystal(12.5, boss_z - 10.0)

	# 5. Hazards (Spikes & Timed Thorn Gauntlets) in Stages 2, 3, and 4
	if is_highland or is_sanctum or is_sky_road:
		var t_step := 175.0 if is_highland else (210.0 if is_sky_road else 240.0)
		var z_t := z_top - 45.0
		var t_i := 0
		while z_t >= z_bot + 40.0:
			var clear_area := absf(z_t - boss_z) < 42.0
			for rv_var in rivers:
				if absf(z_t - float((rv_var as Dictionary)["z"])) < 24.0:
					clear_area = true
					break
			if not clear_area:
				var rx := _road_center_x(z_t)
				if t_i % 2 == 0:
					_spawn_spike(rx - 2.6, z_t)
					_spawn_spike(rx + 2.6, z_t - 6.0)
				else:
					_spawn_thorn(rx - 2.0, z_t)
					_spawn_thorn(rx + 2.0, z_t - 10.0)
			t_i += 1
			z_t -= t_step

	# 6. Forest Wisps & Elder Wisps spaced every ~108m across the entire road
	var w_step := 108.0
	var z_w := z_top - 22.0
	var w_i := 0
	while z_w >= z_bot:
		var skip_w := absf(z_w - boss_z) < 38.0
		for rv_var in rivers:
			if absf(z_w - float((rv_var as Dictionary)["z"])) < 18.0:
				skip_w = true
				break
		if not skip_w:
			var prog_f := clampf((z_top - z_w) / span, 0.0, 1.0)
			var rx := _road_center_x(z_w)
			var lat := sin(float(w_i) * 1.4) * 2.4
			var is_elder := (prog_f > 0.65 and w_i % 2 == 0) or (is_sky_road and w_i % 2 == 1)
			var w_hp := 3 if is_elder else 2
			var base_spd := 4.8 + float(maxi(level_index, 0)) * 0.35 + prog_f * 1.1
			_spawn_wisp(rx + lat, z_w, w_hp, base_spd)
		w_i += 1
		z_w -= w_step


# ---------------------------------------------------------------------------
# Stage Configurations (4 Distinct Aesthetic Ultra-Long Continuous Worlds!)
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	match layout_id:
		"greybox":
			_cfg = {
				"z_min": -64.0,
				"z_max": 22.0,
				"x_half": 42.0,
				"road_start_z": 12.0,
				"road_end_z": -48.0,
				"progress_start_z": 6.0,
				"progress_end_z": -44.0,
				"road_half_w": 7.5,
				"curve_amp": 0.0,
				"hill_amp": 0.0,
				"cobble_bias": 0.65,
				"clearings": [
					{"x": 0.0, "z": -16.0, "rx": 18.0, "rz": 18.0, "stone": true, "connect": false},
					{"x": 15.0, "z": -16.0, "rx": 7.0, "rz": 7.0, "stone": false, "connect": true},
				],
				"rivers": [],
			}
			_build_continuous_terrain()
			_add_reflection_probe(Vector3(0, 8, -16), Vector3(90, 40, 100))
			_add_distant_mountains(-64.0, 22.0, 140.0)

		"level_1":
			_cfg = {
				"z_min": -4640.0,
				"z_max": 38.0,
				"x_half": 64.0,
				"road_start_z": 16.0,
				"road_end_z": -4600.0,
				"progress_start_z": 8.0,
				"progress_end_z": -4590.0,
				"road_half_w": 6.6,
				"curve_amp": 9.5,
				"curve_phase": 0.35,
				"hill_amp": 2.8,
				"cobble_bias": 0.60,
				"clearings": [
					{"x": 0.0, "z": 8.0, "rx": 12.0, "rz": 10.0, "stone": true, "connect": false},
					{"x": -18.5, "z": -340.0, "rx": 8.5, "rz": 8.0, "stone": true, "connect": true},
					{"x": 18.5, "z": -960.0, "rx": 8.5, "rz": 8.5, "stone": true, "connect": true},
					{"x": -18.5, "z": -1860.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": 18.5, "z": -2780.0, "rx": 8.5, "rz": 8.0, "stone": false, "connect": true},
					{"x": -18.5, "z": -3640.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": 18.5, "z": -4320.0, "rx": 8.5, "rz": 8.0, "stone": true, "connect": true},
					{"x": 0.0, "z": -4590.0, "rx": 16.0, "rz": 15.0, "stone": true, "connect": false},
				],
				"rivers": [
					{"z": -580.0, "half_w": 10.0, "depth": 2.6},
					{"z": -1420.0, "half_w": 10.5, "depth": 2.8},
					{"z": -2340.0, "half_w": 10.0, "depth": 2.7},
					{"z": -3260.0, "half_w": 10.5, "depth": 2.8},
					{"z": -4040.0, "half_w": 10.0, "depth": 2.6},
				],
			}
			_build_continuous_terrain()
			_add_reflection_probe(Vector3(0.0, 12.0, -2300.0), Vector3(160.0, 60.0, 4800.0))
			_add_distant_mountains(-4640.0, 38.0, 175.0)

		"level_2":
			_cfg = {
				"z_min": -4840.0,
				"z_max": 38.0,
				"x_half": 64.0,
				"road_start_z": 16.0,
				"road_end_z": -4800.0,
				"progress_start_z": 8.0,
				"progress_end_z": -4790.0,
				"road_half_w": 6.8,
				"curve_amp": 11.5,
				"curve_phase": 1.1,
				"hill_amp": 9.2,
				"cobble_bias": 0.90,
				"highland": true,
				"clearings": [
					{"x": 0.0, "z": 8.0, "rx": 12.0, "rz": 10.0, "stone": true, "connect": false},
					{"x": 18.5, "z": -380.0, "rx": 8.5, "rz": 8.0, "stone": true, "connect": true},
					{"x": -18.5, "z": -1080.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": 18.5, "z": -2000.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": -18.5, "z": -2950.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": 18.5, "z": -3840.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": -18.5, "z": -4480.0, "rx": 8.5, "rz": 8.0, "stone": true, "connect": true},
					{"x": 0.0, "z": -4790.0, "rx": 16.5, "rz": 15.0, "stone": true, "connect": false},
				],
				"rivers": [
					{"z": -640.0, "half_w": 11.0, "depth": 3.4},
					{"z": -1520.0, "half_w": 11.0, "depth": 3.5},
					{"z": -2480.0, "half_w": 11.5, "depth": 3.6},
					{"z": -3420.0, "half_w": 11.0, "depth": 3.4},
					{"z": -4240.0, "half_w": 11.0, "depth": 3.4},
				],
			}
			_road_terrain_mat.set_shader_parameter("moss_tint", Color(0.76, 0.86, 0.72))
			_road_terrain_mat.set_shader_parameter("road_tint", Color(0.78, 0.75, 0.72))
			_pine_mat.set_shader_parameter("tint", Color(0.65, 0.82, 0.86, 1.0))
			_build_continuous_terrain()
			_add_reflection_probe(Vector3(0.0, 14.0, -2400.0), Vector3(160.0, 70.0, 5000.0))
			_add_distant_mountains(-4840.0, 38.0, 155.0)

		"level_3":
			_cfg = {
				"z_min": -72.0,
				"z_max": 4450.0,
				"x_half": 64.0,
				"road_start_z": 4420.0,
				"road_end_z": -36.0,
				"curve_start_z": 4400.0,
				"curve_end_z": 110.0,
				"progress_start_z": 4408.0,
				"progress_end_z": 0.0,
				"boss_arena_z": 0.0,
				"road_half_w": 7.2,
				"curve_amp": 7.0,
				"curve_phase": 0.6,
				"hill_amp": 3.6,
				"cobble_bias": 0.94,
				"sanctum": true,
				"clearings": [
					{"x": 0.0, "z": 4408.0, "rx": 12.0, "rz": 10.0, "stone": true, "connect": false},
					{"x": 18.5, "z": 3920.0, "rx": 8.5, "rz": 8.0, "stone": true, "connect": true},
					{"x": -18.5, "z": 3040.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": 18.5, "z": 2120.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": -18.5, "z": 1180.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": 18.5, "z": 360.0, "rx": 8.5, "rz": 8.0, "stone": true, "connect": true},
					{"x": 0.0, "z": 0.0, "rx": 28.0, "rz": 27.0, "stone": true, "connect": false},
				],
				"rivers": [
					{"z": 3520.0, "half_w": 10.5, "depth": 3.0},
					{"z": 2600.0, "half_w": 10.5, "depth": 3.0},
					{"z": 1680.0, "half_w": 10.5, "depth": 3.0},
					{"z": 760.0, "half_w": 10.5, "depth": 3.0},
				],
			}
			_road_terrain_mat.set_shader_parameter("moss_tint", Color(0.68, 0.90, 0.84))
			_build_continuous_terrain()
			_add_reflection_probe(Vector3(0.0, 12.0, 2200.0), Vector3(160.0, 60.0, 4650.0))
			_add_distant_mountains(-72.0, 4450.0, 175.0)

		"level_4":
			_cfg = {
				"z_min": -4960.0,
				"z_max": 38.0,
				"x_half": 64.0,
				"road_start_z": 16.0,
				"road_end_z": -4920.0,
				"curve_start_z": 2.0,
				"curve_end_z": -4815.0,
				"progress_start_z": 8.0,
				"progress_end_z": -4885.0,
				"boss_arena_z": -4885.0,
				"road_half_w": 7.4,
				"curve_amp": 9.0,
				"curve_phase": 2.0,
				"hill_amp": 6.8,
				"cobble_bias": 1.0,
				"sky_road": true,
				"clearings": [
					{"x": 0.0, "z": 8.0, "rx": 12.0, "rz": 10.0, "stone": true, "connect": false},
					{"x": 21.0, "z": -440.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": -21.0, "z": -1420.0, "rx": 9.5, "rz": 9.0, "stone": true, "connect": true},
					{"x": 21.0, "z": -2500.0, "rx": 9.5, "rz": 9.0, "stone": true, "connect": true},
					{"x": -21.0, "z": -3540.0, "rx": 9.5, "rz": 9.0, "stone": true, "connect": true},
					{"x": 21.0, "z": -4460.0, "rx": 9.0, "rz": 8.5, "stone": true, "connect": true},
					{"x": 0.0, "z": -4885.0, "rx": 28.0, "rz": 27.0, "stone": true, "connect": false},
				],
				"rivers": [
					{"z": -900.0, "half_w": 11.5, "depth": 26.0},
					{"z": -1950.0, "half_w": 11.5, "depth": 26.0},
					{"z": -3050.0, "half_w": 11.5, "depth": 26.0},
					{"z": -4050.0, "half_w": 11.5, "depth": 26.0},
				],
			}
			_road_terrain_mat.set_shader_parameter("moss_tint", Color(0.74, 0.90, 1.0))
			_road_terrain_mat.set_shader_parameter("road_tint", Color(0.86, 0.88, 0.96))
			_pine_mat.set_shader_parameter("tint", Color(0.76, 0.94, 1.0, 1.0))
			_build_continuous_terrain()
			_add_reflection_probe(Vector3(0.0, 14.0, -2450.0), Vector3(170.0, 75.0, 5150.0))
			_add_cloud_horizon_sky(-4960.0, 38.0)
