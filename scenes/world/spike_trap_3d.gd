extends Area3D
## 3D Ancient Iron Spike Trap — static road hazard with continuous overlap check for clean i-frame cadence.

const MAT_STONE: StandardMaterial3D = preload("res://resources/materials3d/ancient_stone.tres")
const MAT_FILIGREE: StandardMaterial3D = preload("res://resources/materials3d/metal_filigree.tres")

@export var damage: int = 1

var _overlapping_player: Node3D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_spikes()


func _build_spikes() -> void:
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(2.2, 0.16, 2.2)
	plate.mesh = pm
	plate.position = Vector3(0.0, 0.08, 0.0)
	plate.material_override = MAT_STONE
	add_child(plate)

	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.55, 0.58, 0.64, 1.0)
	spike_mat.metallic = 0.82
	spike_mat.roughness = 0.28
	spike_mat.emission_enabled = true
	spike_mat.emission = Color(0.75, 0.18, 0.14, 1.0)
	spike_mat.emission_energy_multiplier = 0.35

	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.015
	spike_mesh.bottom_radius = 0.13
	spike_mesh.height = 0.78
	spike_mesh.radial_segments = 6

	for gx in [-0.65, 0.0, 0.65]:
		for gz in [-0.65, 0.0, 0.65]:
			var sp := MeshInstance3D.new()
			sp.mesh = spike_mesh
			sp.position = Vector3(gx, 0.48, gz)
			sp.material_override = spike_mat
			add_child(sp)


func _physics_process(_delta: float) -> void:
	if _overlapping_player and is_instance_valid(_overlapping_player) and _overlapping_player.has_method("take_damage"):
		_overlapping_player.take_damage(damage, global_position)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_overlapping_player = body
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)


func _on_body_exited(body: Node3D) -> void:
	if body == _overlapping_player:
		_overlapping_player = null
