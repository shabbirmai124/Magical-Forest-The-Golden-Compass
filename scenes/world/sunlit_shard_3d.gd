extends Node3D
## Collectible Sunlit Shard — spinning radiant golden crystal with gentle magnetic pull within 2.5m,
## Golden Compass Pulse beacon highlight, and automatic QuestManager + Score progression.

@export var score_value: int = 50
@export var counts_for_quest: bool = true

var compass_label: String = "Sunlit Shard"
var is_collected: bool = false
var _t: float = 0.0
var _base_y: float = 0.0
var _crystal_pivot: Node3D = null
var _beacon: MeshInstance3D = null
var _player_ref: Node3D = null


func _ready() -> void:
	add_to_group("shard")
	_base_y = position.y
	_t = randf() * TAU
	_build_visuals()


func _build_visuals() -> void:
	_crystal_pivot = Node3D.new()
	add_child(_crystal_pivot)

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.9, 0.36, 1.0)
	gold_mat.metallic = 0.4
	gold_mat.roughness = 0.14
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.82, 0.22, 1.0)
	gold_mat.emission_energy_multiplier = 2.8

	# Faceted double-pyramid crystal
	var top_cone := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.01
	tc.bottom_radius = 0.24
	tc.height = 0.54
	tc.radial_segments = 6
	top_cone.mesh = tc
	top_cone.position = Vector3(0.0, 0.27, 0.0)
	top_cone.material_override = gold_mat
	_crystal_pivot.add_child(top_cone)

	var bot_cone := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.24
	bc.bottom_radius = 0.01
	bc.height = 0.42
	bc.radial_segments = 6
	bot_cone.mesh = bc
	bot_cone.position = Vector3(0.0, -0.21, 0.0)
	bot_cone.material_override = gold_mat
	_crystal_pivot.add_child(bot_cone)

	# Orbiting halo ring
	var halo := MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = 0.34
	hm.outer_radius = 0.4
	hm.rings = 16
	hm.ring_segments = 8
	halo.mesh = hm
	halo.rotation.x = deg_to_rad(68.0)
	halo.material_override = gold_mat
	_crystal_pivot.add_child(halo)

	# Compass Pulse vertical golden beacon
	_beacon = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.14
	bm.bottom_radius = 0.28
	bm.height = 12.0
	_beacon.mesh = bm
	_beacon.position = Vector3(0.0, 6.0, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(1.0, 0.9, 0.38, 0.34)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.85, 0.24, 1.0)
	bmat.emission_energy_multiplier = 2.2
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon.material_override = bmat
	_beacon.visible = false
	add_child(_beacon)


func _process(delta: float) -> void:
	if is_collected:
		return
	_t += delta
	if _crystal_pivot:
		_crystal_pivot.rotate_y(delta * 2.2)
		_crystal_pivot.position.y = sin(_t * 3.1) * 0.18

	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D
	if _player_ref:
		var target_pt: Vector3 = _player_ref.global_position + Vector3(0.0, 1.0, 0.0)
		var dist: float = global_position.distance_to(target_pt)
		if dist < 2.8:
			global_position = global_position.lerp(target_pt, minf(delta * 10.0, 1.0))
		if dist < 1.15:
			_collect()


func is_compass_eligible() -> bool:
	return not is_collected


func highlight_compass_beacon(duration: float = 10.0) -> void:
	if is_collected or not _beacon:
		return
	_beacon.visible = true
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(_beacon):
			_beacon.visible = false
	)


func _collect() -> void:
	if is_collected:
		return
	is_collected = true
	if AudioManager:
		AudioManager.play_sfx("shard_pickup", 0.95, 1.12)
	GameManager.add_shard(score_value)
	GameManager.modify_compass_energy(15.0)
	if counts_for_quest and QuestManager:
		QuestManager.record_progress("collect_shards", 1)
	if _beacon:
		_beacon.visible = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 1.6, 0.16)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.18).set_delay(0.1)
	tw.chain().tween_callback(queue_free)
