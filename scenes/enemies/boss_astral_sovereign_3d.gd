extends CharacterBody3D
## Stage 4 Final Boss — Aurelius, the Astral Sovereign (620 HP).
## Sweeping Starlight Arcs, Teleporting Ring Bursts, and an Astral Aegis Shield
## that is shattered by Golden Compass Pulse [G] for a 4.0s stun at 2x damage!

@export var max_hp: int = 620
@export var engage_radius: float = 34.0

var compass_label: String = "Aurelius, Astral Sovereign"
var hp: int = 620
var is_defeated: bool = false
var _engaged: bool = false
var _phase: int = 1
var _shield_active: bool = false
var _stunned: bool = false
var _busy: bool = false
var _t: float = 0.0
var _attack_count: int = 0
var _home_pos: Vector3 = Vector3.ZERO
var _visual_root: Node3D = null
var _shield_mesh: MeshInstance3D = null
var _halo_ring: MeshInstance3D = null
var _player_ref: Node3D = null


func _ready() -> void:
	hp = max_hp
	_home_pos = global_position
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	add_to_group("boss")
	add_to_group("astral_boss")

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.45
	cap.height = 4.4
	col.shape = cap
	col.position = Vector3(0.0, 2.2, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	add_child(_visual_root)
	_build_sovereign_rig()


func _build_sovereign_rig() -> void:
	var armor_mat := StandardMaterial3D.new()
	armor_mat.albedo_color = Color(0.92, 0.94, 1.0, 1.0)
	armor_mat.metallic = 0.72
	armor_mat.roughness = 0.2

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.88, 0.36, 1.0)
	gold_mat.metallic = 0.85
	gold_mat.roughness = 0.18
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.84, 0.28, 1.0)
	gold_mat.emission_energy_multiplier = 2.4

	var cloak := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.62
	cm.bottom_radius = 1.35
	cm.height = 3.2
	cm.radial_segments = 10
	cloak.mesh = cm
	cloak.position = Vector3(0.0, 1.9, 0.0)
	cloak.material_override = armor_mat
	_visual_root.add_child(cloak)

	var chest := MeshInstance3D.new()
	var chm := BoxMesh.new()
	chm.size = Vector3(1.5, 1.25, 0.85)
	chest.mesh = chm
	chest.position = Vector3(0.0, 3.15, 0.0)
	chest.material_override = gold_mat
	_visual_root.add_child(chest)

	var crown := MeshInstance3D.new()
	var crm := SphereMesh.new()
	crm.radius = 0.45
	crm.height = 0.9
	crown.mesh = crm
	crown.position = Vector3(0.0, 4.15, 0.0)
	crown.material_override = gold_mat
	_visual_root.add_child(crown)

	_halo_ring = MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = 1.55
	hm.outer_radius = 1.82
	hm.rings = 28
	hm.ring_segments = 8
	_halo_ring.mesh = hm
	_halo_ring.position = Vector3(0.0, 3.55, -0.45)
	_halo_ring.rotation.x = PI * 0.5
	_halo_ring.material_override = gold_mat
	_visual_root.add_child(_halo_ring)

	_shield_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.65
	sm.height = 5.3
	_shield_mesh.mesh = sm
	_shield_mesh.position = Vector3(0.0, 2.5, 0.0)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(1.0, 0.9, 0.42, 0.34)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.86, 0.32, 1.0)
	smat.emission_energy_multiplier = 2.6
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_mesh.material_override = smat
	_shield_mesh.visible = false
	add_child(_shield_mesh)


func is_compass_eligible() -> bool:
	return not is_defeated


func _phase_text() -> String:
	if _stunned:
		return "SHIELD SHATTERED — 2X DAMAGE!"
	if _shield_active:
		return "ASTRAL AEGIS — PRESS [G] COMPASS PULSE!"
	return "PHASE I — STARLIGHT" if _phase == 1 else "PHASE II — CELESTIAL CROWN"


func _emit_hp_bar() -> void:
	GameManager.boss_health_changed.emit(hp, max_hp, _engaged and not is_defeated, "AURELIUS, THE ASTRAL SOVEREIGN", _phase_text())


func _physics_process(delta: float) -> void:
	if is_defeated or GameManager.is_dialogue_open or GameManager.is_journal_open or GameManager.is_game_ended:
		return
	_t += delta
	if _visual_root:
		_visual_root.position.y = 0.4 + sin(_t * 2.4) * 0.25
	if _halo_ring:
		_halo_ring.rotate_z(delta * 1.6)

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
				AudioManager.play_sfx("boss_roar", 1.1, 1.2)
			GameManager.post_toast("FINAL BOSS", "Aurelius, the Astral Sovereign — Use [G] to shatter his Shield!", Color(1.0, 0.9, 0.45))
			_emit_hp_bar()
		return

	if dist > 0.2 and _visual_root and not _stunned:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(flat.x, flat.z), 5.0 * delta)

	if not _busy and not _stunned:
		_run_next_attack()


func _run_next_attack() -> void:
	_busy = true
	_attack_count += 1
	if _attack_count % 3 == 0 and not _shield_active:
		_activate_astral_shield()
	elif _attack_count % 2 == 0:
		await _attack_teleport_ring()
	else:
		await _attack_starlight_arcs()
	await get_tree().create_timer(1.25 if _phase == 1 else 0.9).timeout
	_busy = false


func _activate_astral_shield() -> void:
	_shield_active = true
	if _shield_mesh:
		_shield_mesh.visible = true
	GameManager.post_toast("ASTRAL AEGIS ACTIVE", "Press [G] Golden Compass Pulse to shatter Aurelius's shield!", Color(1.0, 0.9, 0.42))
	_emit_hp_bar()


func shatter_shield_by_compass() -> void:
	if is_defeated or not _shield_active:
		return
	_shield_active = false
	_stunned = true
	if _shield_mesh:
		_shield_mesh.visible = false
	if AudioManager:
		AudioManager.play_sfx("portal_unlock", 1.2, 1.3)
	GameManager.post_toast("SHIELD SHATTERED!", "Aurelius is stunned for 4s — Deal 2X DAMAGE!", Color(1.0, 0.94, 0.46))
	_emit_hp_bar()
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_defeated:
			_stunned = false
			_emit_hp_bar()
	)


func _attack_starlight_arcs() -> void:
	if not is_instance_valid(_player_ref):
		return
	var root: Node = get_tree().current_scene
	if not root:
		return
	var dir: Vector3 = _player_ref.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var angles: Array = [-24.0, -12.0, 0.0, 12.0, 24.0] if _phase >= 2 else [-18.0, 0.0, 18.0]
	for ang_var in angles:
		var bdir: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(float(ang_var)))
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.34
		sm.height = 0.68
		orb.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.92, 0.46, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.86, 0.34, 1.0)
		mat.emission_energy_multiplier = 3.8
		orb.material_override = mat
		root.add_child(orb)
		var sp: Vector3 = global_position + Vector3(0.0, 1.6, 0.0)
		var ep: Vector3 = sp + bdir * 28.0
		orb.global_position = sp
		var tw := orb.create_tween()
		tw.tween_method(func(t: float) -> void:
			if not is_instance_valid(orb):
				return
			orb.global_position = sp.lerp(ep, t)
			if is_instance_valid(_player_ref) and orb.global_position.distance_to(_player_ref.global_position + Vector3(0.0, 1.0, 0.0)) < 1.25:
				if _player_ref.has_method("take_damage"):
					_player_ref.take_damage(1, orb.global_position)
				orb.queue_free()
		, 0.0, 1.0, 1.4)
		tw.tween_callback(func() -> void:
			if is_instance_valid(orb):
				orb.queue_free()
		)
	await get_tree().create_timer(1.0).timeout


func _attack_teleport_ring() -> void:
	var ang: float = randf() * TAU
	var next_pos: Vector3 = _home_pos + Vector3(cos(ang) * 9.5, 0.0, sin(ang) * 9.5)
	global_position = next_pos
	var root: Node = get_tree().current_scene
	if not root:
		return
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.25
	tm.rings = 28
	tm.ring_segments = 8
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.92, 1.0, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.88, 1.0, 1.0)
	mat.emission_energy_multiplier = 3.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
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
			if absf(d - r) < 1.15 and dy < 1.25:
				hit_done = true
				if _player_ref.has_method("take_damage"):
					_player_ref.take_damage(1, global_position)
	, 2.0, 22.0, 1.45)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free()
	)
	await get_tree().create_timer(1.5).timeout


func take_damage(amount: int, _source_pos: Vector3) -> void:
	if is_defeated:
		return
	if _shield_active:
		if AudioManager:
			AudioManager.play_sfx("rune_activate", 0.7, 0.8)
		GameManager.post_toast("SHIELDED!", "Press [G] Golden Compass Pulse to shatter the Astral Aegis!", Color(1.0, 0.88, 0.4))
		return
	var dmg: int = amount * 2 if _stunned else amount
	hp = maxi(hp - dmg, 0)
	if AudioManager:
		AudioManager.play_sfx("hit_enemy", 0.95, 1.12)
	if _phase == 1 and float(hp) / float(maxi(max_hp, 1)) <= 0.5:
		_phase = 2
		_activate_astral_shield()
	_emit_hp_bar()
	if hp <= 0:
		_defeat_sovereign()


func _defeat_sovereign() -> void:
	is_defeated = true
	GameManager.boss_health_changed.emit(0, max_hp, false, "", "")
	GameManager.register_enemy_defeated(1000)
	if QuestManager:
		QuestManager.record_progress("defeat_aurelius", 1)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.5, 0.35)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.65)
	tw.tween_callback(func() -> void:
		GameManager.trigger_victory()
		queue_free()
	)
