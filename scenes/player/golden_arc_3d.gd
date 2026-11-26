extends Node3D
## Player Golden Compass Arc — fast radiant crescent energy wave fired with Right Click / [K].

var move_dir: Vector3 = Vector3.FORWARD
var speed: float = 28.0
var damage: int = 24
var max_life: float = 1.15
var _age: float = 0.0
var _hit_enemies: Array[Node3D] = []


func _ready() -> void:
	var arc_mat := StandardMaterial3D.new()
	arc_mat.albedo_color = Color(1.0, 0.9, 0.42, 0.95)
	arc_mat.emission_enabled = true
	arc_mat.emission = Color(1.0, 0.84, 0.26, 1.0)
	arc_mat.emission_energy_multiplier = 3.8
	arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var crescent := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.65
	tm.outer_radius = 0.95
	tm.rings = 16
	tm.ring_segments = 6
	crescent.mesh = tm
	crescent.scale = Vector3(1.4, 0.28, 0.72)
	crescent.material_override = arc_mat
	add_child(crescent)


func _physics_process(delta: float) -> void:
	_age += delta
	global_position += move_dir * speed * delta
	for e_var in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node3D = e_var as Node3D
		if not enemy or not is_instance_valid(enemy) or enemy in _hit_enemies:
			continue
		if global_position.distance_to(enemy.global_position + Vector3(0.0, 1.4, 0.0)) <= 2.35:
			_hit_enemies.append(enemy)
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, global_position)
			queue_free()
			return
	if _age >= max_life:
		queue_free()
