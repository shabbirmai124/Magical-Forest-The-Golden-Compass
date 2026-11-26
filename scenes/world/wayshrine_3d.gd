extends Area3D
## 3D Ancient Wayshrine Spire — visible landmark with soft sky beam, [E] interactable checkpoint.
## Igniting restores full Vitality & Compass Energy, saves respawn checkpoint, and updates QuestManager.

@export var shrine_name: String = "Ancient Wayshrine"
@export var shrine_message: String = "Wayshrine Ignited! Full Vitality Restored & Checkpoint Saved"
@export var quest_step_key: String = "ignite_wayshrine_1"

var compass_label: String = "Ancient Wayshrine"
var _activated: bool = false
var _t: float = 0.0
var _crystal_node: MeshInstance3D = null
var _ring_node: MeshInstance3D = null
var _beam_node: MeshInstance3D = null
var _crystal_mat: StandardMaterial3D = null
var _beam_mat: StandardMaterial3D = null


func _ready() -> void:
	compass_label = shrine_name
	add_to_group("wayshrine")
	add_to_group("wayshrines")
	add_to_group("interactable")
	_build_obelisk()


func _build_obelisk() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.28, 0.34, 0.36, 1.0)
	stone_mat.roughness = 0.85

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.78, 0.32, 1.0)
	gold_mat.metallic = 0.8
	gold_mat.roughness = 0.25

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 1.4
	bm.bottom_radius = 1.9
	bm.height = 0.5
	bm.radial_segments = 8
	base.mesh = bm
	base.position = Vector3(0.0, 0.25, 0.0)
	base.material_override = stone_mat
	add_child(base)

	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.42
	sm.bottom_radius = 0.65
	sm.height = 3.6
	sm.radial_segments = 8
	shaft.mesh = sm
	shaft.position = Vector3(0.0, 2.25, 0.0)
	shaft.material_override = stone_mat
	add_child(shaft)

	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.45, 0.9, 1.0, 1.0)
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.28, 0.82, 1.0, 1.0)
	_crystal_mat.emission_energy_multiplier = 2.2
	_crystal_mat.roughness = 0.16

	_crystal_node = get_node_or_null("BeaconCrystal") as MeshInstance3D
	if not _crystal_node:
		_crystal_node = MeshInstance3D.new()
		_crystal_node.name = "BeaconCrystal"
		add_child(_crystal_node)
	var cm := SphereMesh.new()
	cm.radius = 0.42
	cm.height = 1.05
	cm.radial_segments = 8
	cm.rings = 4
	_crystal_node.mesh = cm
	_crystal_node.position = Vector3(0.0, 4.75, 0.0)
	_crystal_node.material_override = _crystal_mat

	_ring_node = get_node_or_null("AstrolabeRing") as MeshInstance3D
	if not _ring_node:
		_ring_node = MeshInstance3D.new()
		_ring_node.name = "AstrolabeRing"
		add_child(_ring_node)
	var rm := TorusMesh.new()
	rm.inner_radius = 0.72
	rm.outer_radius = 0.86
	rm.rings = 18
	rm.ring_segments = 8
	_ring_node.mesh = rm
	_ring_node.position = Vector3(0.0, 4.75, 0.0)
	_ring_node.material_override = gold_mat

	# Vertical sky light beam visible above treetops from spawn!
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.albedo_color = Color(0.45, 0.92, 1.0, 0.22)
	_beam_mat.emission_enabled = true
	_beam_mat.emission = Color(0.38, 0.88, 1.0, 1.0)
	_beam_mat.emission_energy_multiplier = 2.0
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_beam_node = MeshInstance3D.new()
	var beam_m := CylinderMesh.new()
	beam_m.top_radius = 0.22
	beam_m.bottom_radius = 0.55
	beam_m.height = 38.0
	_beam_node.mesh = beam_m
	_beam_node.position = Vector3(0.0, 23.0, 0.0)
	_beam_node.material_override = _beam_mat
	add_child(_beam_node)

	# Solid pillar collider
	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.9
	cs.height = 4.0
	col.shape = cs
	col.position = Vector3(0.0, 2.0, 0.0)
	col_body.add_child(col)
	add_child(col_body)


func _process(delta: float) -> void:
	_t += delta
	if _crystal_node:
		_crystal_node.rotate_y(delta * (2.8 if _activated else 1.0))
		_crystal_node.position.y = 4.75 + sin(_t * 2.5) * 0.16
	if _ring_node:
		_ring_node.rotate_y(delta * (-1.9 if _activated else -0.7))
		_ring_node.rotate_x(delta * 0.8)


func is_activated() -> bool:
	return _activated


func is_compass_eligible() -> bool:
	return not _activated


func get_interact_prompt() -> String:
	if _activated:
		return "[E] Rest at %s (Restore Vitality)" % shrine_name
	return "[E] Ignite %s" % shrine_name


func interact(_player: Node3D) -> void:
	var first_time: bool = not _activated
	_activated = true
	GameManager.full_restore()
	GameManager.set_checkpoint(global_position + Vector3(0.0, 0.4, 2.6))
	if AudioManager:
		AudioManager.play_sfx("wayshrine_ignite")

	if _crystal_mat:
		_crystal_mat.albedo_color = Color(1.0, 0.92, 0.44, 1.0)
		_crystal_mat.emission = Color(1.0, 0.84, 0.28, 1.0)
		_crystal_mat.emission_energy_multiplier = 3.8
	if _beam_mat:
		_beam_mat.albedo_color = Color(1.0, 0.9, 0.42, 0.34)
		_beam_mat.emission = Color(1.0, 0.85, 0.28, 1.0)
		_beam_mat.emission_energy_multiplier = 3.2

	if first_time:
		GameManager.add_score(100)
		GameManager.post_toast("WAYSHRINE IGNITED", shrine_message, Color(1.0, 0.9, 0.42))
		if not quest_step_key.is_empty() and QuestManager:
			QuestManager.record_progress(quest_step_key, 1)
	else:
		GameManager.post_toast("WAYSHRINE BLESSING", "Vitality & Compass Energy Restored", Color(0.55, 0.96, 0.85))
