extends EnemyBase3D
## Stage 4 Astral Wraith — hovering starlit sentinel firing a 3-bolt celestial fan volley.


func _ready() -> void:
	enemy_name = "Astral Wraith"
	max_hp = 75
	move_speed = 4.2
	aggro_radius = 28.0
	attack_range = 16.0
	attack_damage = 1
	score_reward = 130
	quest_step_key = ""
	super._ready()


func _build_enemy_rig() -> void:
	var robe_mat := StandardMaterial3D.new()
	robe_mat.albedo_color = Color(0.2, 0.34, 0.68, 0.92)
	robe_mat.emission_enabled = true
	robe_mat.emission = Color(0.24, 0.56, 0.98, 1.0)
	robe_mat.emission_energy_multiplier = 1.4
	_register_flash_mat(robe_mat)

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.9, 0.45, 1.0)
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.85, 0.32, 1.0)
	gold_mat.emission_energy_multiplier = 2.6

	var cloak := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.36
	cm.bottom_radius = 0.08
	cm.height = 1.65
	cm.radial_segments = 8
	cloak.mesh = cm
	cloak.position = Vector3(0.0, 1.45, 0.0)
	cloak.material_override = robe_mat
	_visual_root.add_child(cloak)

	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.58
	rm.outer_radius = 0.68
	rm.rings = 18
	rm.ring_segments = 6
	ring.mesh = rm
	ring.position = Vector3(0.0, 1.9, 0.0)
	ring.rotation.x = deg_to_rad(60.0)
	ring.material_override = gold_mat
	_visual_root.add_child(ring)

	var core := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.28
	sp.height = 0.56
	core.mesh = sp
	core.position = Vector3(0.0, 1.95, 0.0)
	core.material_override = gold_mat
	_visual_root.add_child(core)


func _begin_attack(player: Node3D, dir: Vector3) -> void:
	_state = "telegraph"
	_attack_cd = 2.5
	_flash_color(Color(0.65, 0.92, 1.0), 0.38)
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or is_defeated:
		return
	var base_dir: Vector3 = dir
	if is_instance_valid(player):
		var d: Vector3 = player.global_position - global_position
		d.y = 0.0
		if d.length() > 0.1:
			base_dir = d.normalized()
	for ang_deg in [-18.0, 0.0, 18.0]:
		var bdir: Vector3 = base_dir.rotated(Vector3.UP, deg_to_rad(ang_deg))
		_fire_star_bolt(player, bdir)
	_state = "idle"


func _fire_star_bolt(player: Node3D, dir: Vector3) -> void:
	var root: Node = get_tree().current_scene
	if not root:
		return
	var bolt := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	bolt.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.92, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.88, 1.0, 1.0)
	mat.emission_energy_multiplier = 3.5
	bolt.material_override = mat
	root.add_child(bolt)
	var start_p: Vector3 = global_position + Vector3(0.0, 1.55, 0.0)
	var end_p: Vector3 = start_p + dir * 24.0
	bolt.global_position = start_p

	var tw := bolt.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(bolt):
			return
		bolt.global_position = start_p.lerp(end_p, t)
		if is_instance_valid(player) and bolt.global_position.distance_to(player.global_position + Vector3(0.0, 1.0, 0.0)) < 1.15:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage, bolt.global_position)
			bolt.queue_free()
	, 0.0, 1.0, 1.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(bolt):
			bolt.queue_free()
	)
