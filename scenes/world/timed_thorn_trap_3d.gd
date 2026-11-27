extends Area3D
## Timed Thorn Ruin Trap — glows amber-crimson as telegraph before erupting razor thorns.
## Deals 1 damage + knockback while extended and highlights on Compass Pulse [G].

@export var damage: int = 1
@export var cycle_period: float = 3.2
@export var phase_offset: float = 0.0

var _t: float = 0.0
var _active: bool = false
var _cd: float = 0.0
var _spikes_pivot: Node3D = null
var _grate_mat: StandardMaterial3D = null
var _beacon: MeshInstance3D = null


func _ready() -> void:
	add_to_group("trap")
	collision_layer = 16
	collision_mask = 2
	_t = phase_offset
	_build_visuals()


func _build_visuals() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not col:
		col = CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.6, 1.3, 2.6)
		col.shape = bs
		col.position = Vector3(0.0, 0.65, 0.0)
		add_child(col)

	_grate_mat = StandardMaterial3D.new()
	_grate_mat.albedo_color = Color(0.16, 0.17, 0.22, 1.0)
	_grate_mat.roughness = 0.86
	_grate_mat.emission_enabled = true
	_grate_mat.emission = Color(0.68, 0.26, 0.14, 1.0)
	_grate_mat.emission_energy_multiplier = 0.18

	var pad := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(2.5, 0.95, 2.5)
	pad.mesh = pm
	pad.position = Vector3(0.0, -0.36, 0.0)
	pad.material_override = _grate_mat
	add_child(pad)

	_spikes_pivot = Node3D.new()
	add_child(_spikes_pivot)

	var thorn_mat := StandardMaterial3D.new()
	thorn_mat.albedo_color = Color(0.24, 0.19, 0.28, 1.0)
	thorn_mat.metallic = 0.45
	thorn_mat.roughness = 0.48
	thorn_mat.emission_enabled = true
	thorn_mat.emission = Color(0.62, 0.16, 0.22, 1.0)
	thorn_mat.emission_energy_multiplier = 0.55

	for ix in [-0.72, 0.0, 0.72]:
		for iz in [-0.72, 0.0, 0.72]:
			var th := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.018
			tm.bottom_radius = 0.14
			tm.height = 1.15
			tm.radial_segments = 6
			th.mesh = tm
			th.position = Vector3(ix, 0.54, iz)
			th.material_override = thorn_mat
			_spikes_pivot.add_child(th)

	_beacon = MeshInstance3D.new()
	var ring_m := TorusMesh.new()
	ring_m.inner_radius = 1.45
	ring_m.outer_radius = 1.65
	ring_m.rings = 16
	ring_m.ring_segments = 6
	_beacon.mesh = ring_m
	_beacon.position = Vector3(0.0, 0.28, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.3, 0.24, 0.9)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.24, 0.18, 1.0)
	bmat.emission_energy_multiplier = 3.0
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon.material_override = bmat
	_beacon.visible = false
	add_child(_beacon)


func _process(delta: float) -> void:
	_t += delta
	if _cd > 0.0:
		_cd = maxf(_cd - delta, 0.0)

	var cyc: float = fmod(_t, cycle_period) / cycle_period
	if cyc < 0.45:
		_active = false
		if _spikes_pivot:
			_spikes_pivot.position.y = lerpf(_spikes_pivot.position.y, -1.15, 10.0 * delta)
		if _grate_mat:
			_grate_mat.emission_energy_multiplier = 0.25
	elif cyc < 0.65:
		# Telegraph glow warning before thorns shoot up!
		_active = false
		if _spikes_pivot:
			_spikes_pivot.position.y = lerpf(_spikes_pivot.position.y, -0.82, 10.0 * delta)
		if _grate_mat:
			_grate_mat.emission_energy_multiplier = 2.6 + sin(_t * 28.0) * 0.8
	else:
		_active = true
		if _spikes_pivot:
			_spikes_pivot.position.y = lerpf(_spikes_pivot.position.y, 0.0, 18.0 * delta)
		if _grate_mat:
			_grate_mat.emission_energy_multiplier = 1.8
		if _cd <= 0.0:
			for body in get_overlapping_bodies():
				if body.is_in_group("player") and body.has_method("take_damage"):
					_cd = 1.0
					body.take_damage(damage, global_position)
					break


func highlight_compass_beacon(duration: float = 10.0) -> void:
	if not _beacon:
		return
	_beacon.visible = true
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(_beacon):
			_beacon.visible = false
	)
