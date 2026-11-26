extends CharacterBody3D
## Stage 3 Boss — Vaelthorn, Corrupted Forest Guardian (480 HP, 3 Epic Phases).
## Phase 1 (100%-65%): Sweeping Root Cleave + 3-Lane Thorn Wave (red ground telegraphs).
## Phase 2 (65%-30%): Enrages (amber-crimson glow), adds Jumpable Shockwave Ring + summons 2 Moss Stalkers.
## Phase 3 (<30%): Meteor Spore Rain across arena + 3.0s exhausted vulnerability window.

const MOSS_STALKER_SCRIPT = preload("res://scenes/enemies/moss_stalker_3d.gd")

@export var max_hp: int = 480
@export var engage_radius: float = 36.0

var compass_label: String = "Vaelthorn (Boss)"
var hp: int = 480
var is_defeated: bool = false
var _engaged: bool = false
var _phase: int = 1
var _summoned_p2: bool = false
var _staggered: bool = false
var _busy: bool = false
var _t: float = 0.0
var _attack_cycle: int = 0
var _visual_root: Node3D = null
var _core_mat: StandardMaterial3D = null
var _bark_mat: StandardMaterial3D = null
var _player_ref: Node3D = null


func _ready() -> void:
	hp = max_hp
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	add_to_group("boss")

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.65
	cap.height = 4.8
	col.shape = cap
	col.position = Vector3(0.0, 2.4, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	add_child(_visual_root)
	_build_boss_rig()


func _build_boss_rig() -> void:
	_bark_mat = StandardMaterial3D.new()
	_bark_mat.albedo_color = Color(0.18, 0.24, 0.16, 1.0)
	_bark_mat.roughness = 0.9

	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.28, 0.96, 0.65, 1.0)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(0.24, 0.95, 0.62, 1.0)
	_core_mat.emission_energy_multiplier = 3.0

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 1.25
	tm.bottom_radius = 1.85
	tm.height = 4.6
	tm.radial_segments = 10
	trunk.mesh = tm
	trunk.position = Vector3(0.0, 2.3, 0.0)
	trunk.material_override = _bark_mat
	_visual_root.add_child(trunk)

	var heart := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.72
	hm.height = 1.44
	heart.mesh = hm
	heart.position = Vector3(0.0, 2.9, 1.02)
	heart.material_override = _core_mat
	_visual_root.add_child(heart)

	# Giant antlers & shoulders
	for sgn in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.92
		sm.height = 1.45
		shoulder.mesh = sm
		shoulder.position = Vector3(sgn * 1.65, 3.65, 0.0)
		shoulder.material_override = _bark_mat
		_visual_root.add_child(shoulder)

		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.78, 2.85, 0.78)
		arm.mesh = am
		arm.position = Vector3(sgn * 2.1, 2.15, 0.35)
		arm.material_override = _bark_mat
		_visual_root.add_child(arm)

		var horn := MeshInstance3D.new()
		var hnm := CylinderMesh.new()
		hnm.top_radius = 0.08
		hnm.bottom_radius = 0.28
		hnm.height = 2.4
		hnm.radial_segments = 6
		horn.mesh = hnm
		horn.position = Vector3(sgn * 1.15, 5.2, 0.0)
		horn.rotation.z = -sgn * 0.42
		horn.material_override = _core_mat
		_visual_root.add_child(horn)


func is_compass_eligible() -> bool:
	return not is_defeated


func _phase_text() -> String:
	if _staggered:
		return "PHASE %d — STAGGERED!" % _phase
	return "PHASE I" if _phase == 1 else ("PHASE II — ENRAGED" if _phase == 2 else "PHASE III — CORRUPTED FURY")


func _emit_hp_bar() -> void:
	GameManager.boss_health_changed.emit(hp, max_hp, _engaged and not is_defeated, "VAELTHORN, CORRUPTED FOREST GUARDIAN", _phase_text())


func _physics_process(delta: float) -> void:
	if is_defeated or GameManager.is_dialogue_open or GameManager.is_journal_open or GameManager.is_game_ended:
		return
	_t += delta
	if _visual_root:
		_visual_root.position.y = sin(_t * 2.2) * 0.14

	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D
	if not _player_ref:
		return

	var flat: Vector3 = _player_ref.global_position - global_position
	flat.y = 0.0
	var dist: float = flat.length()

	if not _engaged:
		if dist <= engage_radius:
			_engaged = true
			if AudioManager:
				AudioManager.play_sfx("boss_roar")
			GameManager.post_toast("BOSS ENCOUNTER", "Vaelthorn, Corrupted Forest Guardian Awakens!", Color(1.0, 0.46, 0.36))
			_emit_hp_bar()
		return

	if dist > 0.2 and not _staggered:
		var dir: Vector3 = flat.normalized()
		if _visual_root:
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(dir.x, dir.z), 4.5 * delta)
		if not _busy and dist > 7.5:
			velocity.x = dir.x * (3.6 if _phase == 1 else 4.8)
			velocity.z = dir.z * (3.6 if _phase == 1 else 4.8)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	else:
		velocity = Vector3.ZERO
	move_and_slide()

	if not _busy and not _staggered:
		_run_next_attack()


func _run_next_attack() -> void:
	_busy = true
	_attack_cycle += 1

	if _phase == 3 and (_attack_cycle % 3 == 0):
		await _attack_meteor_spore_rain()
		await _enter_stagger(3.0)
	elif _phase >= 2 and (_attack_cycle % 2 == 0):
		await _attack_shockwave_ring()
	else:
		await _attack_thorn_wave()

	var cd: float = 1.6 if _phase == 1 else (1.2 if _phase == 2 else 0.95)
	await get_tree().create_timer(cd).timeout
	_busy = false


func _attack_thorn_wave() -> void:
	if not is_instance_valid(_player_ref):
		return
	var dir: Vector3 = _player_ref.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD

	for ang_deg in [-22.0, 0.0, 22.0]:
		var lane_dir: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(ang_deg))
		_spawn_thorn_line(lane_dir)
	await get_tree().create_timer(1.1).timeout


func _spawn_thorn_line(lane_dir: Vector3) -> void:
	var root: Node = get_tree().current_scene
	if not root:
		return
	for step_i in range(1, 6):
		var pt: Vector3 = global_position + lane_dir * (float(step_i) * 4.2)
		var ring := _spawn_telegraph_circle(pt, 1.5, 0.65)
		get_tree().create_timer(0.65).timeout.connect(func() -> void:
			if is_instance_valid(ring):
				ring.queue_free()
			if not is_inside_tree() or is_defeated:
				return
			var spike := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.08
			sm.bottom_radius = 0.72
			sm.height = 2.8
			spike.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.24, 0.22, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.28, 0.2, 1.0)
			mat.emission_energy_multiplier = 2.4
			spike.material_override = mat
			root.add_child(spike)
			spike.global_position = pt + Vector3(0.0, 1.4, 0.0)
			if is_instance_valid(_player_ref) and Vector2(_player_ref.global_position.x - pt.x, _player_ref.global_position.z - pt.z).length() < 1.85:
				if _player_ref.has_method("take_damage"):
					_player_ref.take_damage(1, pt)
			get_tree().create_timer(0.45).timeout.connect(func() -> void:
				if is_instance_valid(spike):
					spike.queue_free()
			)
		)


func _attack_shockwave_ring() -> void:
	var root: Node = get_tree().current_scene
	if not root:
		return
	if AudioManager:
		AudioManager.play_sfx("boss_roar", 0.9, 1.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.15
	tm.rings = 32
	tm.ring_segments = 8
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.42, 0.2, 0.95)
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.35, 0.14, 1.0)
	rmat.emission_energy_multiplier = 3.5
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	root.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.42, 0.0)

	var hit_done: bool = false
	var tw := ring.create_tween()
	tw.tween_method(func(r: float) -> void:
		if not is_instance_valid(ring):
			return
		ring.scale = Vector3(r, 1.0, r)
		if not hit_done and is_instance_valid(_player_ref):
			var d: float = Vector2(_player_ref.global_position.x - global_position.x, _player_ref.global_position.z - global_position.z).length()
			var dy: float = _player_ref.global_position.y - global_position.y
			if absf(d - r) < 1.1 and dy < 1.25:
				hit_done = true
				if _player_ref.has_method("take_damage"):
					_player_ref.take_damage(1, global_position)
	, 2.0, 26.0, 1.65)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free()
	)
	await get_tree().create_timer(1.7).timeout


func _attack_meteor_spore_rain() -> void:
	var root: Node = get_tree().current_scene
	if not root:
		return
	for i in 7:
		var ang: float = randf() * TAU
		var rad: float = randf_range(4.0, 20.0)
		var pt: Vector3 = global_position + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		if i == 0 and is_instance_valid(_player_ref):
			pt = Vector3(_player_ref.global_position.x, global_position.y, _player_ref.global_position.z)
		var ring := _spawn_telegraph_circle(pt, 2.3, 0.9)
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			if is_instance_valid(ring):
				ring.queue_free()
			if not is_inside_tree() or is_defeated:
				return
			if is_instance_valid(_player_ref) and Vector2(_player_ref.global_position.x - pt.x, _player_ref.global_position.z - pt.z).length() < 2.4:
				if _player_ref.has_method("take_damage"):
					_player_ref.take_damage(1, pt)
		)
	await get_tree().create_timer(1.2).timeout


func _enter_stagger(dur: float) -> void:
	_staggered = true
	_emit_hp_bar()
	GameManager.post_toast("BOSS STAGGERED", "Strike Vaelthorn now for heavy damage!", Color(1.0, 0.9, 0.42))
	if _visual_root:
		create_tween().tween_property(_visual_root, "rotation:x", deg_to_rad(22.0), 0.3)
	await get_tree().create_timer(dur).timeout
	if is_inside_tree() and not is_defeated:
		_staggered = false
		if _visual_root:
			create_tween().tween_property(_visual_root, "rotation:x", 0.0, 0.25)
		_emit_hp_bar()


func _spawn_telegraph_circle(pos: Vector3, radius: float, _dur: float) -> MeshInstance3D:
	var root: Node = get_tree().current_scene
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius * 0.85
	tm.outer_radius = radius
	tm.rings = 20
	tm.ring_segments = 6
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.22, 0.16, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.18, 0.12, 1.0)
	mat.emission_energy_multiplier = 3.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	if root:
		root.add_child(ring)
		ring.global_position = pos + Vector3(0.0, 0.16, 0.0)
	return ring


func take_damage(amount: int, _source_pos: Vector3) -> void:
	if is_defeated:
		return
	var mult: float = 1.5 if _staggered else 1.0
	hp = maxi(hp - int(round(float(amount) * mult)), 0)
	if AudioManager:
		AudioManager.play_sfx("hit_enemy", 0.78, 0.92)
	if _core_mat:
		_core_mat.emission_energy_multiplier = 5.5
		get_tree().create_timer(0.12).timeout.connect(func() -> void:
			if is_instance_valid(self) and _core_mat:
				_core_mat.emission_energy_multiplier = 3.2
		)

	var ratio: float = float(hp) / float(maxi(max_hp, 1))
	if _phase == 1 and ratio <= 0.65:
		_phase = 2
		if _core_mat:
			_core_mat.albedo_color = Color(1.0, 0.45, 0.2, 1.0)
			_core_mat.emission = Color(1.0, 0.35, 0.14, 1.0)
		if AudioManager:
			AudioManager.play_sfx("boss_roar")
		GameManager.post_toast("VAELTHORN ENRAGES — PHASE II", "Jump over the Shockwave Ring & watch for Moss Stalkers!", Color(1.0, 0.52, 0.28))
		if not _summoned_p2:
			_summoned_p2 = true
			_summon_stalkers()
	elif _phase == 2 and ratio <= 0.30:
		_phase = 3
		if _core_mat:
			_core_mat.albedo_color = Color(1.0, 0.18, 0.24, 1.0)
			_core_mat.emission = Color(1.0, 0.14, 0.2, 1.0)
		if AudioManager:
			AudioManager.play_sfx("boss_roar", 0.85, 0.95)
		GameManager.post_toast("VAELTHORN — PHASE III", "Dodge Meteor Spores and strike during stagger!", Color(1.0, 0.34, 0.34))

	_emit_hp_bar()
	if hp <= 0:
		_defeat_boss()


func _summon_stalkers() -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return
	for sgn in [-1.0, 1.0]:
		var st := CharacterBody3D.new()
		st.set_script(MOSS_STALKER_SCRIPT)
		st.set("quest_step_key", "")
		parent_node.add_child(st)
		st.global_position = global_position + Vector3(sgn * 9.5, 0.2, 6.0)


func _defeat_boss() -> void:
	is_defeated = true
	GameManager.boss_health_changed.emit(0, max_hp, false, "", "")
	GameManager.register_enemy_defeated(600)
	if AudioManager:
		AudioManager.play_sfx("victory_fanfare")
	GameManager.post_toast("VAELTHORN VANQUISHED", "The Heart of the Grove is cleansed — Astral Rift unsealed!", Color(1.0, 0.92, 0.45))
	if QuestManager:
		QuestManager.record_progress("defeat_vaelthorn", 1)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
