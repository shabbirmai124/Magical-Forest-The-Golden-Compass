extends EnemyBase3D
## Stage 2 Thorn Spitter — rooted corrupted flora turret firing aimed violet poison bolts.

var _pod_mat: StandardMaterial3D = null


func _ready() -> void:
	enemy_name = "Thorn Spitter"
	max_hp = 40
	move_speed = 0.0
	aggro_radius = 26.0
	attack_range = 24.0
	attack_damage = 1
	score_reward = 90
	quest_step_key = "defeat_ruin_foes"
	super._ready()


func _build_enemy_rig() -> void:
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.22, 0.34, 0.18, 1.0)
	stem_mat.roughness = 0.85
	_register_flash_mat(stem_mat)

	_pod_mat = StandardMaterial3D.new()
	_pod_mat.albedo_color = Color(0.62, 0.22, 0.78, 1.0)
	_pod_mat.emission_enabled = true
	_pod_mat.emission = Color(0.66, 0.22, 0.92, 1.0)
	_pod_mat.emission_energy_multiplier = 1.6
	_register_flash_mat(_pod_mat)

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.42
	bm.bottom_radius = 0.78
	bm.height = 0.55
	bm.radial_segments = 8
	base.mesh = bm
	base.position = Vector3(0.0, 0.28, 0.0)
	base.material_override = stem_mat
	_visual_root.add_child(base)

	var stalk := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.24
	sm.bottom_radius = 0.34
	sm.height = 1.45
	sm.radial_segments = 8
	stalk.mesh = sm
	stalk.position = Vector3(0.0, 1.1, 0.0)
	stalk.material_override = stem_mat
	_visual_root.add_child(stalk)

	var bulb := MeshInstance3D.new()
	var blm := SphereMesh.new()
	blm.radius = 0.48
	blm.height = 0.86
	bulb.mesh = blm
	bulb.position = Vector3(0.0, 1.9, 0.18)
	bulb.material_override = _pod_mat
	_visual_root.add_child(bulb)


func _begin_attack(player: Node3D, dir: Vector3) -> void:
	_state = "telegraph"
	_attack_cd = 2.2
	if _pod_mat:
		_pod_mat.emission_energy_multiplier = 4.2
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or is_defeated:
		return
	if _pod_mat:
		_pod_mat.emission_energy_multiplier = 1.6
	_fire_poison_bolt(player, dir)
	_state = "idle"


func _fire_poison_bolt(player: Node3D, fallback_dir: Vector3) -> void:
	var spawn_pos: Vector3 = global_position + Vector3(0.0, 1.75, 0.0)
	var aim: Vector3 = fallback_dir
	if is_instance_valid(player):
		aim = (player.global_position + Vector3(0.0, 1.0, 0.0) - spawn_pos).normalized()
	var bolt := Area3D.new()
	bolt.collision_layer = 16
	bolt.collision_mask = 3
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.28, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.78, 0.25, 1.0, 1.0)
	mat.emission_energy_multiplier = 3.5
	mi.material_override = mat
	bolt.add_child(mi)

	var root: Node = get_tree().current_scene
	if not root:
		bolt.queue_free()
		return
	root.add_child(bolt)
	bolt.global_position = spawn_pos

	var end_pos: Vector3 = spawn_pos + aim * 26.0
	var tw := bolt.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(bolt):
			return
		bolt.global_position = spawn_pos.lerp(end_pos, t)
		if is_instance_valid(player) and bolt.global_position.distance_to(player.global_position + Vector3(0.0, 1.0, 0.0)) < 1.15:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage, bolt.global_position)
			bolt.queue_free()
	, 0.0, 1.0, 1.45)
	tw.tween_callback(func() -> void:
		if is_instance_valid(bolt):
			bolt.queue_free()
	)
