extends CharacterBody3D
## 3D Final Boss — The Forest Guardian.
## Sculpted Ancient Treant-Golem with articulated gauntlet/shoulder breathing,
## 8 orbital rune spires, telegraph ring, Phase 1 aimed orb volleys, Phase 2 Shockwave Nova,
## and dramatic ascending dissolution reveal when spawning the Lost Golden Compass.

const GuardianVisuals3D = preload("res://scenes/enemies/guardian_visuals_3d.gd")

@export var max_hp: int = 12
@export var engage_radius: float = 38.0
@export var orb_scene: PackedScene = preload("res://scenes/enemies/boss_orb_3d.tscn")
@export var compass_scene: PackedScene = preload("res://scenes/world/golden_compass_3d.tscn")
@export var compass_spawn_marker: NodePath
@export var fallback_compass_position: Vector3 = Vector3(0.0, 1.2, 0.0)

@onready var visuals: Node3D = $Visuals
@onready var orbit_shards: Node3D = $Visuals/OrbitShards
@onready var chest_core: MeshInstance3D = $Visuals/ChestCore
@onready var eye_left: MeshInstance3D = $Visuals/EyeLeft
@onready var eye_right: MeshInstance3D = $Visuals/EyeRight
@onready var hitbox: Area3D = $ContactHitBox
@onready var aura_light: OmniLight3D = $AuraLight
@onready var attack_timer: Timer = $AttackTimer
@onready var hit_sparks: GPUParticles3D = $HitSparks
@onready var cast_sfx: AudioStreamPlayer = $Audio/Cast
@onready var roar_sfx: AudioStreamPlayer = $Audio/Roar
@onready var hit_sfx: AudioStreamPlayer = $Audio/Hit

var hp: int
var phase_two: bool = false
var is_engaged: bool = false
var is_telegraphing: bool = false
var is_defeated: bool = false
var hover_origin: Vector3
var t: float = 0.0
var _overlapping_player: Node3D = null
var _telegraph_ring: MeshInstance3D = null
var _shock_mat: StandardMaterial3D = null
var _cast_counter: int = 0
var _shock_active: bool = false
var _shock_radius: float = 1.0
var _shock_center: Vector3 = Vector3.ZERO
var _fist_l: Node3D = null
var _fist_r: Node3D = null
var _uarm_l: Node3D = null
var _uarm_r: Node3D = null
var _fist_l_base_y: float = -0.35
var _fist_r_base_y: float = -0.35
var _core_mat: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("enemies")
	max_hp += maxi(GameManager.adventure_cycle - 1, 0) * 3
	hp = max_hp
	hover_origin = global_position
	var vis_refs := GuardianVisuals3D.enhance_guardian(self)
	_telegraph_ring = vis_refs.get("telegraph_ring", null)
	_shock_mat = vis_refs.get("shock_mat", null)
	_fist_l = visuals.get_node_or_null("FistLeft") as Node3D
	_fist_r = visuals.get_node_or_null("FistRight") as Node3D
	_uarm_l = visuals.get_node_or_null("UpperArmLeft") as Node3D
	_uarm_r = visuals.get_node_or_null("UpperArmRight") as Node3D
	if _fist_l:
		_fist_l_base_y = _fist_l.position.y
	if _fist_r:
		_fist_r_base_y = _fist_r.position.y
	if chest_core and chest_core.material_override is StandardMaterial3D:
		_core_mat = (chest_core.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		chest_core.material_override = _core_mat

	attack_timer.stop()
	attack_timer.timeout.connect(_start_attack_telegraph)
	hitbox.body_entered.connect(func(b: Node3D) -> void:
		if not is_defeated and b.is_in_group("player"):
			_overlapping_player = b
			if b.has_method("take_damage"):
				b.take_damage(1, global_position)
	)
	hitbox.body_exited.connect(func(b: Node3D) -> void:
		if b == _overlapping_player:
			_overlapping_player = null
	)


func _engage_boss() -> void:
	if is_engaged or is_defeated:
		return
	is_engaged = true
	attack_timer.start()
	GameManager.boss_health_changed.emit(hp, max_hp, true)
	GameManager.notification_posted.emit("Forest Guardian Challenges You! Strike with Sword [LMB / J]!", Color(0.55, 1.0, 0.72))
	if roar_sfx and roar_sfx.stream:
		roar_sfx.pitch_scale = 1.0
		roar_sfx.play()


func _physics_process(delta: float) -> void:
	if is_defeated:
		velocity = Vector3.ZERO
		return

	if _overlapping_player and is_instance_valid(_overlapping_player) and _overlapping_player.has_method("take_damage"):
		_overlapping_player.take_damage(1, global_position)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and is_instance_valid(player):
		var to_p := player.global_position - global_position
		to_p.y = 0.0
		if not is_engaged and to_p.length() <= engage_radius:
			_engage_boss()
		if to_p.length() > 0.2:
			var target_yaw := atan2(-to_p.x, -to_p.z)
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_yaw, 4.5 * delta)

	if not is_engaged:
		t += delta
		if orbit_shards:
			orbit_shards.rotate_y(delta * 1.1)
		global_position.y = hover_origin.y + sin(t * 1.5) * 0.25
		return

	if _shock_active and _telegraph_ring:
		_shock_radius += 17.5 * delta
		var sc := _shock_radius / 2.1
		_telegraph_ring.scale = Vector3(sc, 1.0, sc)
		if player and is_instance_valid(player):
			var flat_d := Vector2(player.global_position.x - _shock_center.x, player.global_position.z - _shock_center.z).length()
			if absf(flat_d - _shock_radius) < 1.15 and player.global_position.y < _shock_center.y + 1.05:
				if player.has_method("take_damage"):
					player.take_damage(1, _shock_center)
		if _shock_radius >= 21.0:
			_shock_active = false
			_telegraph_ring.visible = false

	t += delta
	var speed_mult := 1.65 if phase_two else 1.0
	if orbit_shards:
		orbit_shards.rotate_y(delta * (1.8 * speed_mult))
		orbit_shards.position.y = sin(t * 2.5) * 0.25

	if not is_telegraphing:
		if _fist_l:
			_fist_l.position.y = lerpf(_fist_l.position.y, _fist_l_base_y + sin(t * 2.8) * 0.24, 6.0 * delta)
		if _fist_r:
			_fist_r.position.y = lerpf(_fist_r.position.y, _fist_r_base_y + cos(t * 2.8) * 0.24, 6.0 * delta)
		if _uarm_l and _fist_l:
			_uarm_l.rotation.x = lerpf(_uarm_l.rotation.x, 0.14 + (_fist_l.position.y - _fist_l_base_y) * 0.45, 7.0 * delta)
		if _uarm_r and _fist_r:
			_uarm_r.rotation.x = lerpf(_uarm_r.rotation.x, 0.14 + (_fist_r.position.y - _fist_r_base_y) * 0.45, 7.0 * delta)

	if is_telegraphing:
		velocity = Vector3.ZERO
		return

	var target_pos := Vector3(
		hover_origin.x + sin(t * 0.9 * speed_mult) * 10.5,
		hover_origin.y + sin(t * 2.0 * speed_mult) * 0.45,
		hover_origin.z + sin(t * 1.8 * speed_mult) * 7.0
	)
	velocity = (target_pos - global_position) * 3.0
	visuals.rotation.x = lerpf(visuals.rotation.x, -0.06 - clampf(velocity.length() * 0.008, 0.0, 0.12), 5.0 * delta)
	move_and_slide()


func _start_attack_telegraph() -> void:
	if is_defeated or is_telegraphing or GameManager.is_game_ended:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player or not orb_scene:
		return

	is_telegraphing = true
	_cast_counter += 1
	if aura_light:
		create_tween().tween_property(aura_light, "light_energy", 6.2, 0.3)
	create_tween().tween_property(visuals, "scale", Vector3(1.09, 1.09, 1.09), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _fist_l:
		create_tween().tween_property(_fist_l, "position:y", _fist_l_base_y + 0.95, 0.35).set_trans(Tween.TRANS_BACK)
	if _fist_r:
		create_tween().tween_property(_fist_r, "position:y", _fist_r_base_y + 0.95, 0.35).set_trans(Tween.TRANS_BACK)

	if _telegraph_ring and not _shock_active:
		_telegraph_ring.global_position = Vector3(global_position.x, 0.14, global_position.z)
		_telegraph_ring.scale = Vector3(0.4, 1.0, 0.4)
		_telegraph_ring.visible = true
		create_tween().tween_property(_telegraph_ring, "scale", Vector3(1.15, 1.0, 1.15), 0.45).set_trans(Tween.TRANS_BACK)

	await get_tree().create_timer(0.55).timeout

	if is_defeated or GameManager.is_game_ended:
		return

	create_tween().tween_property(visuals, "scale", Vector3.ONE, 0.15)
	if _fist_l:
		create_tween().tween_property(_fist_l, "position:y", _fist_l_base_y, 0.15)
	if _fist_r:
		create_tween().tween_property(_fist_r, "position:y", _fist_r_base_y, 0.15)
	if aura_light:
		aura_light.light_energy = 4.2 if phase_two else 3.2

	if phase_two and (_cast_counter % 3 == 0):
		_trigger_shockwave_nova()
	else:
		if _telegraph_ring and not _shock_active:
			_telegraph_ring.visible = false
		_fire_orb_volley(player)
	is_telegraphing = false


func _trigger_shockwave_nova() -> void:
	if roar_sfx and roar_sfx.stream:
		roar_sfx.pitch_scale = 1.15
		roar_sfx.play()
	_shock_center = Vector3(global_position.x, 0.14, global_position.z)
	_shock_radius = 2.0
	_shock_active = true
	if _telegraph_ring:
		_telegraph_ring.global_position = _shock_center
		_telegraph_ring.scale = Vector3(1.0, 1.0, 1.0)
		_telegraph_ring.visible = true


func _fire_orb_volley(player: Node3D) -> void:
	if not is_instance_valid(player):
		return
	if cast_sfx and cast_sfx.stream:
		cast_sfx.pitch_scale = randf_range(0.95, 1.05)
		cast_sfx.play()

	var origin := global_position + Vector3(0.0, 0.2, 0.0)
	var target_pt := player.global_position + Vector3(0.0, 1.0, 0.0)
	var base_dir := (target_pt - origin).normalized()
	var spread_deg: Array[float] = [-15.0, 0.0, 15.0] if phase_two else [0.0]
	for deg in spread_deg:
		var orb := orb_scene.instantiate()
		orb.global_position = origin
		orb.direction = base_dir.rotated(Vector3.UP, deg_to_rad(deg))
		get_tree().current_scene.add_child(orb)


func take_damage(amount: int, _source_pos: Vector3) -> void:
	if is_defeated:
		return
	if not is_engaged:
		_engage_boss()
	hp = maxi(hp - amount, 0)
	GameManager.boss_health_changed.emit(hp, max_hp, true)

	if hit_sfx and hit_sfx.stream:
		hit_sfx.pitch_scale = randf_range(0.9, 1.1)
		hit_sfx.play()
	if hit_sparks:
		hit_sparks.restart()
		hit_sparks.emitting = true

	var tw := create_tween()
	tw.tween_property(visuals, "scale", Vector3(0.9, 1.12, 0.9), 0.06)
	tw.tween_property(visuals, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	if _core_mat:
		var base_e := _core_mat.emission_energy_multiplier
		_core_mat.emission_energy_multiplier = 8.0
		create_tween().tween_property(_core_mat, "emission_energy_multiplier", base_e, 0.16)

	if not phase_two and hp <= max_hp / 2 and hp > 0:
		_enter_phase_two()

	if hp <= 0:
		_defeat()


func _enter_phase_two() -> void:
	phase_two = true
	attack_timer.wait_time = 1.45
	GameManager.notification_posted.emit("THE FOREST GUARDIAN AWAKENS! Evade Dash [RMB / C] Through Waves!", Color(1.0, 0.45, 0.28))
	if aura_light:
		create_tween().tween_property(aura_light, "light_color", Color(1.0, 0.35, 0.22, 1.0), 0.4)
		create_tween().tween_property(aura_light, "light_energy", 4.6, 0.4)
	if _shock_mat:
		_shock_mat.albedo_color = Color(1.0, 0.38, 0.22, 0.9)
		_shock_mat.emission = Color(1.0, 0.28, 0.14, 1.0)
	if _core_mat:
		_core_mat.albedo_color = Color(1.0, 0.36, 0.22, 1.0)
		_core_mat.emission = Color(1.0, 0.28, 0.14, 1.0)
	if eye_left and eye_left.material_override is StandardMaterial3D:
		var em := eye_left.material_override.duplicate() as StandardMaterial3D
		em.albedo_color = Color(1.0, 0.52, 0.28, 1.0)
		em.emission = Color(1.0, 0.3, 0.15, 1.0)
		eye_left.material_override = em
		eye_right.material_override = em
	if roar_sfx and roar_sfx.stream:
		roar_sfx.play()


func _defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	_shock_active = false
	_overlapping_player = null
	set_deferred("collision_layer", 0)
	attack_timer.stop()
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	if _telegraph_ring:
		_telegraph_ring.visible = false
	GameManager.add_score(200)
	GameManager.register_enemy_defeated()
	GameManager.boss_health_changed.emit(0, max_hp, false)
	GameManager.notification_posted.emit("Forest Guardian Vanquished! Reclaim the Golden Compass!", Color(1.0, 0.88, 0.36))

	if roar_sfx and roar_sfx.stream:
		roar_sfx.pitch_scale = 0.78
		roar_sfx.play()
	if hit_sparks:
		hit_sparks.restart()
		hit_sparks.emitting = true

	var dtw := create_tween().set_parallel(true)
	dtw.tween_property(visuals, "scale", Vector3(0.02, 2.2, 0.02), 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dtw.tween_property(visuals, "position:y", visuals.position.y + 3.2, 0.72)
	dtw.tween_property(visuals, "rotation:y", visuals.rotation.y + TAU * 1.5, 0.72)
	if aura_light:
		dtw.tween_property(aura_light, "light_energy", 9.0, 0.35)
		dtw.tween_property(aura_light, "light_energy", 0.0, 0.4).set_delay(0.35)
	await dtw.finished
	if not is_inside_tree():
		return

	var spawn_pos := fallback_compass_position
	if not compass_spawn_marker.is_empty():
		var marker := get_node_or_null(compass_spawn_marker) as Node3D
		if marker:
			spawn_pos = marker.global_position

	if compass_scene:
		var compass := compass_scene.instantiate()
		if not get_tree().get_nodes_in_group("awakened_portal").is_empty() and "unlocks_next_portal" in compass:
			compass.unlocks_next_portal = true
		compass.global_position = spawn_pos + Vector3(0.0, 2.4, 0.0)
		get_tree().current_scene.add_child(compass)
		create_tween().tween_property(compass, "global_position", spawn_pos, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	queue_free()
