extends EnemyBase3D
## Stage 1 & 2 Moss Stalker — agile clawed corrupted woodland beast with glowing amber eyes.


func _ready() -> void:
	enemy_name = "Moss Stalker"
	max_hp = 45
	move_speed = 5.2
	aggro_radius = 22.0
	attack_range = 2.7
	attack_damage = 1
	score_reward = 75
	super._ready()


func _build_enemy_rig() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.16, 0.34, 0.2, 1.0)
	body_mat.roughness = 0.85
	_register_flash_mat(body_mat)

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.11, 0.18, 0.14, 1.0)
	dark_mat.roughness = 0.8
	_register_flash_mat(dark_mat)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.36, 0.18, 1.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.3, 0.14, 1.0)
	eye_mat.emission_energy_multiplier = 3.0

	var torso := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.52
	tm.height = 0.92
	torso.mesh = tm
	torso.position = Vector3(0.0, 0.82, 0.0)
	torso.scale = Vector3(1.0, 0.85, 1.35)
	torso.material_override = body_mat
	_visual_root.add_child(torso)

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.56, 0.44, 0.62)
	head.mesh = hm
	head.position = Vector3(0.0, 1.05, 0.56)
	head.material_override = dark_mat
	_visual_root.add_child(head)

	for sgn in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.075
		em.height = 0.14
		eye.mesh = em
		eye.position = Vector3(sgn * 0.17, 1.12, 0.86)
		eye.material_override = eye_mat
		_visual_root.add_child(eye)

		var claw := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.11
		cm.height = 0.62
		cm.radial_segments = 6
		claw.mesh = cm
		claw.position = Vector3(sgn * 0.52, 0.62, 0.45)
		claw.rotation.x = deg_to_rad(52.0)
		claw.material_override = dark_mat
		_visual_root.add_child(claw)

		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.11
		lm.bottom_radius = 0.08
		lm.height = 0.65
		lm.radial_segments = 6
		leg.mesh = lm
		leg.position = Vector3(sgn * 0.36, 0.32, -0.3)
		leg.material_override = dark_mat
		_visual_root.add_child(leg)
