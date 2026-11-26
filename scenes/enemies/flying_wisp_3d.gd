extends CharacterBody3D
## 3D Forest Wisp — Patrols in a 3D figure-8 hover, chases player in DetectZone,
## takes 2 hits, disables hitboxes cleanly on death, and awards +25 score.

const PropsVisuals3D = preload("res://scenes/world/props_visuals_3d.gd")

enum State { PATROL, CHASE, DEAD }

@export var chase_speed: float = 5.4
@export var patrol_range: float = 4.5
@export var hp: int = 2

@onready var visuals: Node3D = $Visuals
@onready var orbit_ring: MeshInstance3D = $Visuals/OrbitRing
@onready var hitbox: Area3D = $ContactHitBox
@onready var detect_zone: Area3D = $DetectZone
@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $DefeatParticles
@onready var hit_sfx: AudioStreamPlayer = $HitSFX

var state: State = State.PATROL
var start_pos: Vector3
var time_passed: float = 0.0
var target: Node3D = null
var _overlapping_player: Node3D = null
var _hitstun_timer: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _core_mat: StandardMaterial3D = null
var _base_core_color: Color = Color(0.5, 0.98, 0.95, 1.0)
var _base_core_emit: Color = Color(0.28, 0.95, 0.9, 1.0)
var _inner_ring: Node3D = null
var _wing_l: Node3D = null
var _wing_r: Node3D = null
var _tendrils: Array[Node3D] = []
var _hp_pips: Array[Node3D] = []


func _ready() -> void:
	add_to_group("enemies")
	start_pos = global_position
	chase_speed += float(maxi(GameManager.adventure_cycle - 1, 0)) * 0.65
	hp += maxi(GameManager.adventure_cycle - 1, 0) / 2
	PropsVisuals3D.enhance_flying_wisp(self)
	if light:
		light.distance_fade_enabled = true
		light.distance_fade_begin = 40.0
		light.distance_fade_length = 14.0
	_inner_ring = visuals.get_node_or_null("InnerRing") as Node3D
	_wing_l = visuals.get_node_or_null("WingLeft") as Node3D
	_wing_r = visuals.get_node_or_null("WingRight") as Node3D
	for ti in 4:
		var td := visuals.get_node_or_null("Tendril_%d" % ti) as Node3D
		if td:
			_tendrils.append(td)
	var pips_node := visuals.get_node_or_null("HpPips") as Node3D
	if pips_node:
		for pi in 4:
			var p := pips_node.get_node_or_null("Pip_%d" % pi) as Node3D
			if p:
				_hp_pips.append(p)
		_refresh_hp_pips()
	var core := visuals.get_node_or_null("CoreMesh") as MeshInstance3D
	if core and core.material_override is StandardMaterial3D:
		_core_mat = (core.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		core.material_override = _core_mat
		_base_core_color = _core_mat.albedo_color
		_base_core_emit = _core_mat.emission
	if hp >= 3:
		_base_scale = Vector3.ONE * 1.28
		visuals.scale = _base_scale
		if light:
			light.light_color = Color(0.95, 0.36, 0.62, 1.0)
			light.light_energy = 2.6
		if _core_mat:
			_base_core_color = Color(0.96, 0.32, 0.58, 0.94)
			_base_core_emit = Color(0.95, 0.24, 0.52, 1.0)
			_core_mat.albedo_color = _base_core_color
			_core_mat.emission = _base_core_emit
	hitbox.body_entered.connect(_on_touch_player)
	hitbox.body_exited.connect(func(b: Node3D) -> void:
		if b == _overlapping_player:
			_overlapping_player = null
	)
	detect_zone.body_entered.connect(func(b: Node3D) -> void:
		if state != State.DEAD and b.is_in_group("player"):
			target = b
			state = State.CHASE
	)
	detect_zone.body_exited.connect(func(b: Node3D) -> void:
		if b == target:
			target = null
			if state != State.DEAD:
				state = State.PATROL
	)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	time_passed += delta
	var spin_mult := 2.6 if state == State.CHASE else 1.0
	if orbit_ring:
		orbit_ring.rotate_y(delta * 2.4 * spin_mult)
		orbit_ring.rotate_x(delta * 1.1 * spin_mult)
	if _inner_ring:
		_inner_ring.rotate_z(-delta * 2.8 * spin_mult)
		_inner_ring.rotate_y(delta * 1.5 * spin_mult)
	if _wing_l:
		_wing_l.rotation.z = 1.05 + sin(time_passed * (6.2 if state == State.CHASE else 3.2)) * 0.28
	if _wing_r:
		_wing_r.rotation.z = -1.05 - sin(time_passed * (6.2 if state == State.CHASE else 3.2)) * 0.28
	for ti in _tendrils.size():
		var td := _tendrils[ti]
		td.rotation.x = sin(time_passed * 4.5 + float(ti) * 1.5) * 0.22 + (0.28 if state == State.CHASE else 0.0)
		td.rotation.z = cos(time_passed * 3.8 + float(ti) * 1.2) * 0.16

	if _hitstun_timer > 0.0:
		_hitstun_timer = maxf(_hitstun_timer - delta, 0.0)
		velocity = velocity.move_toward(Vector3.ZERO, 16.0 * delta)
		visuals.rotation.x = lerpf(visuals.rotation.x, 0.42, 14.0 * delta)
	elif state == State.CHASE and target and is_instance_valid(target):
		if global_position.distance_to(start_pos) > 30.0:
			target = null
			state = State.PATROL
		else:
			var target_pt := target.global_position + Vector3(0.0, 1.05, 0.0)
			var dir := (target_pt - global_position).normalized()
			velocity = dir * chase_speed
			visuals.rotation.x = lerpf(visuals.rotation.x, -0.26, 8.0 * delta)
	else:
		var desired := Vector3(
			start_pos.x + sin(time_passed * 1.3) * patrol_range,
			start_pos.y + sin(time_passed * 2.4) * 0.35,
			start_pos.z + cos(time_passed * 1.3) * (patrol_range * 0.65)
		)
		velocity = (desired - global_position) * 3.0
		visuals.rotation.x = lerpf(visuals.rotation.x, sin(time_passed * 2.0) * 0.08, 6.0 * delta)

	var flat_v := Vector3(velocity.x, 0.0, velocity.z)
	if flat_v.length() > 0.2:
		var ty := atan2(-flat_v.x, -flat_v.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, ty, 8.0 * delta)

	move_and_slide()

	if _hitstun_timer <= 0.0 and _overlapping_player and is_instance_valid(_overlapping_player) and _overlapping_player.has_method("take_damage"):
		_overlapping_player.take_damage(1, global_position)


func _on_touch_player(body: Node3D) -> void:
	if state == State.DEAD:
		return
	if body.is_in_group("player"):
		_overlapping_player = body
		if _hitstun_timer <= 0.0 and body.has_method("take_damage"):
			body.take_damage(1, global_position)


func _refresh_hp_pips() -> void:
	var shown := mini(maxi(hp, 0), _hp_pips.size())
	var spacing := 0.22
	var x0 := -0.5 * float(maxi(shown - 1, 0)) * spacing
	for i in _hp_pips.size():
		var p := _hp_pips[i]
		p.visible = i < shown
		if p.visible:
			p.position = Vector3(x0 + float(i) * spacing, 0.0, 0.0)


func take_damage(amount: int, source_pos: Vector3) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_refresh_hp_pips()
	_hitstun_timer = 0.30
	var away := (global_position - source_pos)
	away.y = 0.08
	if away.length() < 0.05:
		away = Vector3.FORWARD
	velocity = away.normalized() * 10.5
	if hit_sfx and hit_sfx.stream:
		hit_sfx.pitch_scale = randf_range(1.1, 1.3)
		hit_sfx.play()

	if _core_mat:
		_core_mat.albedo_color = Color(1.0, 0.92, 0.92, 1.0)
		_core_mat.emission = Color(1.0, 0.45, 0.35, 1.0)

	if hp <= 0:
		_die()
		return

	visuals.scale = _base_scale * Vector3(1.32, 0.72, 1.32)
	await get_tree().create_timer(0.14).timeout
	if is_inside_tree() and state != State.DEAD:
		visuals.scale = _base_scale
		if _core_mat:
			_core_mat.albedo_color = _base_core_color
			_core_mat.emission = _base_core_emit


func _die() -> void:
	state = State.DEAD
	_overlapping_player = null
	set_deferred("collision_layer", 0)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	detect_zone.set_deferred("monitoring", false)
	var dtw := create_tween()
	dtw.tween_property(visuals, "scale", _base_scale * 1.45, 0.08).set_trans(Tween.TRANS_BACK)
	dtw.tween_property(visuals, "scale", Vector3.ZERO, 0.12)
	if light:
		create_tween().tween_property(light, "light_energy", 0.0, 0.18)
	GameManager.add_score(25)
	GameManager.register_enemy_defeated()
	if particles:
		particles.emitting = true
		await get_tree().create_timer(particles.lifetime).timeout
	if is_inside_tree():
		queue_free()
