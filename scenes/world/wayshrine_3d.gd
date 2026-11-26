extends Area3D
## 3D Ancient Wayshrine Obelisk — illuminates when visited, restores +1 Vitality,
## grants +50 score, and guides the Explorer along the multi-kilometer road.

const MeshFactory3D = preload("res://scenes/common/mesh_factory_3d.gd")
const MAT_STONE: StandardMaterial3D = preload("res://resources/materials3d/ancient_stone.tres")
const MAT_RUNE: StandardMaterial3D = preload("res://resources/materials3d/rune_stone.tres")
const MAT_FILIGREE: StandardMaterial3D = preload("res://resources/materials3d/metal_filigree.tres")

@export var shrine_message: String = "Wayshrine Lit! Restored +1 Vitality (+50)"

@onready var crystal_node: MeshInstance3D = $BeaconCrystal
@onready var astrolabe_ring: MeshInstance3D = $AstrolabeRing
@onready var beacon_light: OmniLight3D = $BeaconLight
@onready var sfx: AudioStreamPlayer = $ChimeSFX

var _activated: bool = false
var _t: float = 0.0
var _crystal_mat: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("wayshrines")
	body_entered.connect(_on_body_entered)
	_build_obelisk()
	if beacon_light:
		beacon_light.distance_fade_enabled = true
		beacon_light.distance_fade_begin = 55.0
		beacon_light.distance_fade_length = 18.0


func _build_obelisk() -> void:
	var base := MeshInstance3D.new()
	base.name = "ShrineBase"
	var bm := CylinderMesh.new()
	bm.top_radius = 1.25
	bm.bottom_radius = 1.65
	bm.height = 0.45
	bm.radial_segments = 8
	base.mesh = bm
	base.position = Vector3(0.0, 0.22, 0.0)
	base.material_override = MAT_STONE
	add_child(base)

	var shaft := MeshInstance3D.new()
	shaft.name = "ShrineShaft"
	shaft.mesh = MeshFactory3D.build_fluted_column_mesh(0.46, 3.2)
	shaft.position = Vector3(0.0, 1.95, 0.0)
	shaft.material_override = MAT_RUNE
	add_child(shaft)

	if crystal_node:
		crystal_node.mesh = MeshFactory3D.build_rune_shard_mesh(0.32, 1.05, 17)
		_crystal_mat = StandardMaterial3D.new()
		_crystal_mat.albedo_color = Color(0.42, 0.86, 0.96, 1.0)
		_crystal_mat.roughness = 0.16
		_crystal_mat.metallic = 0.25
		_crystal_mat.emission_enabled = true
		_crystal_mat.emission = Color(0.28, 0.78, 0.95, 1.0)
		_crystal_mat.emission_energy_multiplier = 1.6
		crystal_node.material_override = _crystal_mat

	if astrolabe_ring:
		astrolabe_ring.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.68, 0.78, 0.045, 24)
		astrolabe_ring.material_override = MAT_FILIGREE


func _process(delta: float) -> void:
	_t += delta
	if crystal_node:
		crystal_node.rotate_y(delta * (2.6 if _activated else 0.9))
		crystal_node.position.y = 4.25 + sin(_t * 2.4) * 0.14
	if astrolabe_ring:
		astrolabe_ring.rotate_y(delta * (-1.8 if _activated else -0.6))
		astrolabe_ring.rotate_x(delta * 0.75)


func is_activated() -> bool:
	return _activated


func _on_body_entered(body: Node3D) -> void:
	if _activated or not body.is_in_group("player"):
		return
	_activated = true
	GameManager.heal_player(1)
	GameManager.add_score(50)
	GameManager.notification_posted.emit(shrine_message, Color(1.0, 0.88, 0.42))
	if sfx and sfx.stream:
		sfx.pitch_scale = 1.04
		sfx.play()
	if _crystal_mat:
		_crystal_mat.albedo_color = Color(1.0, 0.92, 0.48, 1.0)
		_crystal_mat.emission = Color(1.0, 0.84, 0.34, 1.0)
		_crystal_mat.emission_energy_multiplier = 3.8
	if beacon_light:
		beacon_light.light_color = Color(1.0, 0.88, 0.42, 1.0)
		create_tween().tween_property(beacon_light, "light_energy", 4.4, 0.45)
