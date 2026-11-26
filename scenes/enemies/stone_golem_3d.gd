extends EnemyBase3D
## Stage 2 & 3 Corrupted Stone Golem — towering armored monolith with a telegraphed ground slam ring.

var _slam_ring: MeshInstance3D = null


func _ready() -> void:
	enemy_name = "Corrupted Stone Golem"
	max_hp = 115
	move_speed = 2.8
	aggro_radius = 24.0
	attack_range = 3.8
	attack_damage = 2
	score_reward = 150
	quest_step_key = "defeat_ruin_foes"
	super._ready()
	if _hp_bar_root:
		_hp_bar_root.position.y = 3.65


func _build_enemy_rig() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.28, 0.34, 0.36, 1.0)
	stone_mat.roughness = 0.9
	_register_flash_mat(stone_mat)

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.95, 0.36, 0.22, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.3, 0.16, 1.0)
	core_mat.emission_energy_multiplier = 2.8
	_register_flash_mat(core_mat)

	var torso := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.55, 1.65, 1.05)
	torso.mesh = tm
	torso.position = Vector3(0.0, 1.85, 0.0)
	torso.material_override = stone_mat
	_visual_root.add_child(torso)

	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.32
	cm.height = 0.64
	core.mesh = cm
	core.position = Vector3(0.0, 1.9, 0.5)
	core.material_override = core_mat
	_visual_root.add_child(core)

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.75, 0.55, 0.72)
	head.mesh = hm
	head.position = Vector3(0.0, 2.95, 0.12)
	head.material_override = stone_mat
	_visual_root.add_child(head)

	for sgn in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.55, 1.75, 0.55)
		arm.mesh = am
		arm.position = Vector3(sgn * 1.15, 1.55, 0.15)
		arm.material_override = stone_mat
		_visual_root.add_child(arm)

		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.52, 1.05, 0.56)
		leg.mesh = lm
		leg.position = Vector3(sgn * 0.45, 0.52, 0.0)
		leg.material_override = stone_mat
		_visual_root.add_child(leg)

	# Ground slam telegraph ring
	_slam_ring = MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 4.0
	rm.outer_radius = 4.45
	rm.rings = 24
	rm.ring_segments = 6
	_slam_ring.mesh = rm
	_slam_ring.position = Vector3(0.0, 0.18, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.22, 0.18, 0.9)
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.18, 0.12, 1.0)
	rmat.emission_energy_multiplier = 3.2
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slam_ring.material_override = rmat
	_slam_ring.visible = false
	add_child(_slam_ring)


func _begin_attack(player: Node3D, _dir: Vector3) -> void:
	_state = "telegraph"
	_attack_cd = 2.8
	if _slam_ring:
		_slam_ring.visible = true
		_slam_ring.scale = Vector3(0.25, 1.0, 0.25)
		create_tween().tween_property(_slam_ring, "scale", Vector3.ONE, 0.85).set_trans(Tween.TRANS_QUAD)
	if _visual_root:
		create_tween().tween_property(_visual_root, "position:y", 0.45, 0.75)

	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree() or is_defeated:
		return
	_state = "attack"
	if _slam_ring:
		_slam_ring.visible = false
	if _visual_root:
		create_tween().tween_property(_visual_root, "position:y", 0.0, 0.12)
	if AudioManager:
		AudioManager.play_sfx("boss_roar", 1.2, 1.35, -6.0)
	if is_instance_valid(player):
		var flat_d: float = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		var dy: float = player.global_position.y - global_position.y
		if flat_d <= 4.55 and dy < 1.5:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage, global_position)
	await get_tree().create_timer(0.45).timeout
	if is_inside_tree() and not is_defeated:
		_state = "idle"
