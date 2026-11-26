extends Area3D
## 3D Timed Thorn Ruin Trap — cycles Dormant -> Amber Telegraph Warning -> Raised Active Thorns.

const MAT_STONE: StandardMaterial3D = preload("res://resources/materials3d/ancient_stone.tres")

@export var damage: int = 1
@export var dormant_duration: float = 2.0
@export var warn_duration: float = 0.75
@export var active_duration: float = 1.35

enum Phase { DORMANT, WARN, ACTIVE }

var _phase: Phase = Phase.DORMANT
var _timer: float = 0.0
var _overlapping_player: Node3D = null
var _thorns_pivot: Node3D = null
var _rune_mat: StandardMaterial3D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_timer = randf_range(0.0, dormant_duration * 0.75)
	_build_trap_meshes()


func _build_trap_meshes() -> void:
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(2.6, 0.2, 2.6)
	frame.mesh = fm
	frame.position = Vector3(0.0, 0.1, 0.0)
	frame.material_override = MAT_STONE
	add_child(frame)

	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.24, 0.42, 0.36, 1.0)
	_rune_mat.roughness = 0.4
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(0.18, 0.45, 0.36, 1.0)
	_rune_mat.emission_energy_multiplier = 0.45

	var rune_ring := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(2.15, 0.24, 2.15)
	rune_ring.mesh = rm
	rune_ring.position = Vector3(0.0, 0.11, 0.0)
	rune_ring.material_override = _rune_mat
	add_child(rune_ring)

	_thorns_pivot = Node3D.new()
	_thorns_pivot.name = "ThornsPivot"
	_thorns_pivot.position = Vector3(0.0, -0.82, 0.0)
	add_child(_thorns_pivot)

	var thorn_mat := StandardMaterial3D.new()
	thorn_mat.albedo_color = Color(0.32, 0.18, 0.24, 1.0)
	thorn_mat.roughness = 0.48
	thorn_mat.emission_enabled = true
	thorn_mat.emission = Color(0.85, 0.22, 0.28, 1.0)
	thorn_mat.emission_energy_multiplier = 0.8

	var thorn_mesh := CylinderMesh.new()
	thorn_mesh.top_radius = 0.015
	thorn_mesh.bottom_radius = 0.14
	thorn_mesh.height = 1.05
	thorn_mesh.radial_segments = 6

	for gx in [-0.75, 0.0, 0.75]:
		for gz in [-0.75, 0.0, 0.75]:
			var th := MeshInstance3D.new()
			th.mesh = thorn_mesh
			th.position = Vector3(gx, 0.52, gz)
			th.rotation = Vector3(deg_to_rad(gz * 8.0), 0.0, deg_to_rad(-gx * 8.0))
			th.material_override = thorn_mat
			_thorns_pivot.add_child(th)


func _physics_process(delta: float) -> void:
	_timer += delta
	match _phase:
		Phase.DORMANT:
			if _thorns_pivot:
				_thorns_pivot.position.y = lerpf(_thorns_pivot.position.y, -0.85, 9.0 * delta)
			if _timer >= dormant_duration:
				_timer = 0.0
				_phase = Phase.WARN
				if _rune_mat:
					_rune_mat.albedo_color = Color(1.0, 0.76, 0.22, 1.0)
					_rune_mat.emission = Color(1.0, 0.68, 0.14, 1.0)
					_rune_mat.emission_energy_multiplier = 2.4
		Phase.WARN:
			if _thorns_pivot:
				_thorns_pivot.position.y = lerpf(_thorns_pivot.position.y, -0.52, 10.0 * delta)
			if _timer >= warn_duration:
				_timer = 0.0
				_phase = Phase.ACTIVE
				if _rune_mat:
					_rune_mat.albedo_color = Color(1.0, 0.28, 0.24, 1.0)
					_rune_mat.emission = Color(1.0, 0.22, 0.18, 1.0)
					_rune_mat.emission_energy_multiplier = 3.2
		Phase.ACTIVE:
			if _thorns_pivot:
				_thorns_pivot.position.y = lerpf(_thorns_pivot.position.y, 0.12, 18.0 * delta)
			if _overlapping_player and is_instance_valid(_overlapping_player) and _overlapping_player.has_method("take_damage"):
				_overlapping_player.take_damage(damage, global_position)
			if _timer >= active_duration:
				_timer = 0.0
				_phase = Phase.DORMANT
				if _rune_mat:
					_rune_mat.albedo_color = Color(0.24, 0.42, 0.36, 1.0)
					_rune_mat.emission = Color(0.18, 0.45, 0.36, 1.0)
					_rune_mat.emission_energy_multiplier = 0.45


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_overlapping_player = body
		if _phase == Phase.ACTIVE and body.has_method("take_damage"):
			body.take_damage(damage, global_position)


func _on_body_exited(body: Node3D) -> void:
	if body == _overlapping_player:
		_overlapping_player = null
