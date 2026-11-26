extends Area3D
## Iron Spike Trap — glowing crimson danger grate, deals 1 damage + knockback,
## highlighted by Golden Compass Pulse [G].

@export var damage: int = 1
@export var cooldown_time: float = 1.1

var _cd: float = 0.0
var _beacon: MeshInstance3D = null


func _ready() -> void:
	add_to_group("trap")
	collision_layer = 16
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_build_visuals()


func _build_visuals() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not col:
		col = CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.2, 0.9, 2.2)
		col.shape = bs
		col.position = Vector3(0.0, 0.45, 0.0)
		add_child(col)

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.22, 0.18, 0.2, 1.0)
	base_mat.roughness = 0.72
	base_mat.emission_enabled = true
	base_mat.emission = Color(0.65, 0.14, 0.14, 1.0)
	base_mat.emission_energy_multiplier = 0.65

	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.66, 0.7, 0.75, 1.0)
	spike_mat.metallic = 0.8
	spike_mat.roughness = 0.3

	var grate := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(2.2, 0.14, 2.2)
	grate.mesh = gm
	grate.position = Vector3(0.0, 0.07, 0.0)
	grate.material_override = base_mat
	add_child(grate)

	for ix in [-0.65, 0.0, 0.65]:
		for iz in [-0.65, 0.0, 0.65]:
			var sp := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.015
			sm.bottom_radius = 0.13
			sm.height = 0.72
			sm.radial_segments = 6
			sp.mesh = sm
			sp.position = Vector3(ix, 0.42, iz)
			sp.material_override = spike_mat
			add_child(sp)

	_beacon = MeshInstance3D.new()
	var ring_m := TorusMesh.new()
	ring_m.inner_radius = 1.25
	ring_m.outer_radius = 1.45
	ring_m.rings = 16
	ring_m.ring_segments = 6
	_beacon.mesh = ring_m
	_beacon.position = Vector3(0.0, 0.25, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.28, 0.22, 0.9)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.22, 0.18, 1.0)
	bmat.emission_energy_multiplier = 3.0
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon.material_override = bmat
	_beacon.visible = false
	add_child(_beacon)


func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd = maxf(_cd - delta, 0.0)


func highlight_compass_beacon(duration: float = 10.0) -> void:
	if not _beacon:
		return
	_beacon.visible = true
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(_beacon):
			_beacon.visible = false
	)


func _on_body_entered(body: Node3D) -> void:
	if _cd > 0.0 or not body.is_in_group("player"):
		return
	_cd = cooldown_time
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
