extends CharacterBody3D
class_name EnemyBase3D
## Base 3D Enemy with stylized procedural visuals, floating world-space billboard HP bar,
## patrol/chase/telegraph/attack/hurt/death states, hit flash, knockback, and shard drops.

const SHARD_SCRIPT = preload("res://scenes/world/sunlit_shard_3d.gd")

@export var enemy_name: String = "Forest Enemy"
@export var max_hp: int = 45
@export var move_speed: float = 4.8
@export var aggro_radius: float = 22.0
@export var attack_range: float = 2.6
@export var attack_damage: int = 1
@export var score_reward: int = 75
@export var quest_step_key: String = "defeat_stalkers"
@export var drops_shard: bool = true

var compass_label: String = "Corrupted Foe"
var hp: int = 45
var is_defeated: bool = false
var _home_pos: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _attack_cd: float = 0.0
var _hitstun_t: float = 0.0
var _state: String = "idle" # idle, chase, telegraph, attack, dead
var _visual_root: Node3D = null
var _hp_bar_root: Node3D = null
var _hp_fill_mesh: MeshInstance3D = null
var _hp_fill_mat: StandardMaterial3D = null
var _body_mats: Array[StandardMaterial3D] = []
var _orig_emissions: Array[Color] = []
var _player_ref: Node3D = null
var _telegraph_ring: MeshInstance3D = null


func _ready() -> void:
	hp = max_hp
	compass_label = enemy_name
	_home_pos = global_position
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	add_to_group("enemy")
	add_to_group("enemy_quest")

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.65
	cap.height = 1.65
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_build_enemy_rig()
	_build_world_hp_bar()


func _build_enemy_rig() -> void:
	## Override in subclasses
	pass


func _register_flash_mat(mat: StandardMaterial3D) -> void:
	_body_mats.append(mat)
	_orig_emissions.append(mat.emission if mat.emission_enabled else Color.BLACK)


func _build_world_hp_bar() -> void:
	_hp_bar_root = Node3D.new()
	_hp_bar_root.position = Vector3(0.0, 2.45, 0.0)
	add_child(_hp_bar_root)

	var bg := MeshInstance3D.new()
	var bgm := QuadMesh.new()
	bgm.size = Vector2(1.45, 0.19)
	bg.mesh = bgm
	var bgmat := StandardMaterial3D.new()
	bgmat.albedo_color = Color(0.06, 0.08, 0.1, 0.85)
	bgmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bgmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bgmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg.material_override = bgmat
	_hp_bar_root.add_child(bg)

	_hp_fill_mesh = MeshInstance3D.new()
	var fm := QuadMesh.new()
	fm.size = Vector2(1.36, 0.12)
	_hp_fill_mesh.mesh = fm
	_hp_fill_mesh.position = Vector3(0.0, 0.0, 0.02)
	_hp_fill_mat = StandardMaterial3D.new()
	_hp_fill_mat.albedo_color = Color(0.95, 0.3, 0.28, 1.0)
	_hp_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_fill_mesh.material_override = _hp_fill_mat
	_hp_bar_root.add_child(_hp_fill_mesh)


func _update_hp_bar() -> void:
	if not _hp_fill_mesh:
		return
	var ratio: float = clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	_hp_fill_mesh.scale.x = maxf(ratio, 0.001)
	if _hp_fill_mat:
		_hp_fill_mat.albedo_color = Color(0.95, 0.25, 0.22, 1.0) if ratio < 0.35 else Color(0.98, 0.52, 0.25, 1.0)


func is_compass_eligible() -> bool:
	return not is_defeated


func _physics_process(delta: float) -> void:
	if is_defeated or GameManager.is_dialogue_open or GameManager.is_journal_open or GameManager.is_game_ended:
		return
	_t += delta
	if _attack_cd > 0.0:
		_attack_cd = maxf(_attack_cd - delta, 0.0)

	if not is_on_floor():
		velocity.y = maxf(velocity.y - 24.0 * delta, -28.0)
	else:
		velocity.y = 0.0

	if _hitstun_t > 0.0:
		_hitstun_t = maxf(_hitstun_t - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		move_and_slide()
		return

	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D

	if _player_ref:
		_ai_tick(delta, _player_ref)

	move_and_slide()


func _ai_tick(delta: float, player: Node3D) -> void:
	var to_p: Vector3 = player.global_position - global_position
	var flat: Vector3 = Vector3(to_p.x, 0.0, to_p.z)
	var dist: float = flat.length()

	if _state == "telegraph" or _state == "attack":
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
		return

	if dist <= aggro_radius and global_position.distance_to(_home_pos) < 34.0:
		var dir: Vector3 = flat.normalized() if dist > 0.1 else Vector3.FORWARD
		_face_dir(dir, delta)
		if dist <= attack_range and _attack_cd <= 0.0:
			_begin_attack(player, dir)
		elif dist > attack_range * 0.85:
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			_animate_walk(delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	else:
		var back: Vector3 = _home_pos - global_position
		back.y = 0.0
		if back.length() > 1.8:
			var bdir: Vector3 = back.normalized()
			_face_dir(bdir, delta)
			velocity.x = bdir.x * (move_speed * 0.6)
			velocity.z = bdir.z * (move_speed * 0.6)
			_animate_walk(delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
			if _visual_root:
				_visual_root.position.y = sin(_t * 2.5) * 0.05


func _face_dir(dir: Vector3, delta: float) -> void:
	if _visual_root and dir.length() > 0.05:
		var yaw: float = atan2(dir.x, dir.z)
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, yaw, 9.0 * delta)


func _animate_walk(_delta: float) -> void:
	if _visual_root:
		_visual_root.position.y = absf(sin(_t * 8.5)) * 0.14


func _begin_attack(player: Node3D, dir: Vector3) -> void:
	_state = "telegraph"
	_attack_cd = 1.65
	_flash_color(Color(1.0, 0.18, 0.14), 0.35)
	if _visual_root:
		create_tween().tween_property(_visual_root, "scale", Vector3(1.15, 0.82, 1.15), 0.35)
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or is_defeated:
		return
	_state = "attack"
	if _visual_root:
		create_tween().tween_property(_visual_root, "scale", Vector3.ONE, 0.18)
	velocity.x = dir.x * (move_speed * 2.4)
	velocity.z = dir.z * (move_speed * 2.4)
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range + 1.1:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage, global_position)
	await get_tree().create_timer(0.28).timeout
	if is_inside_tree() and not is_defeated:
		_state = "idle"


func take_damage(amount: int, source_pos: Vector3) -> void:
	if is_defeated:
		return
	hp = maxi(hp - amount, 0)
	_update_hp_bar()
	if AudioManager:
		AudioManager.play_sfx("hit_enemy", 0.9, 1.12)
	_flash_color(Color(1.0, 0.95, 0.85), 0.16)

	var kb: Vector3 = global_position - source_pos
	kb.y = 0.0
	kb = kb.normalized() if kb.length() > 0.05 else Vector3.BACK
	velocity.x = kb.x * 8.5
	velocity.z = kb.z * 8.5
	velocity.y = 2.6
	_hitstun_t = 0.22

	if hp <= 0:
		_die()


func _flash_color(col: Color, duration: float) -> void:
	for m in _body_mats:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.6
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		for i in _body_mats.size():
			var m: StandardMaterial3D = _body_mats[i]
			var orig: Color = _orig_emissions[i]
			if orig == Color.BLACK:
				m.emission_enabled = false
			else:
				m.emission = orig
				m.emission_energy_multiplier = 1.2
	)


func _die() -> void:
	if is_defeated:
		return
	is_defeated = true
	_state = "dead"
	GameManager.register_enemy_defeated(score_reward)
	if not quest_step_key.is_empty() and QuestManager:
		QuestManager.record_progress(quest_step_key, 1)

	if drops_shard and get_parent():
		var drop := Node3D.new()
		drop.set_script(SHARD_SCRIPT)
		drop.set("counts_for_quest", true)
		drop.set("score_value", 40)
		get_parent().add_child(drop)
		drop.global_position = global_position + Vector3(0.0, 1.0, 0.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
