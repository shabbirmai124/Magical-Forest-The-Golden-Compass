extends Area3D
## 3D Ancient Dimensional Portal Arch — displays dim crimson seal while Main Quest is incomplete,
## then erupts into a swirling emerald-gold vortex ([E] Enter Portal) once unlocked.

@export var portal_name: String = "Grove Portal"
@export var next_stage_label: String = "Thornhollow Ruins"
@export var quest_step_key: String = "enter_portal_1"
@export var starts_dormant: bool = true

var compass_label: String = "Grove Portal"
var _is_active: bool = false
var _triggered: bool = false
var _t: float = 0.0
var _vortex_mesh: MeshInstance3D = null
var _ring_mesh: MeshInstance3D = null
var _vortex_mat: StandardMaterial3D = null
var _rune_mat: StandardMaterial3D = null


func _ready() -> void:
	compass_label = portal_name
	add_to_group("portal")
	add_to_group("stage_portals")
	add_to_group("interactable")
	_build_archway()
	_set_portal_active(not starts_dormant)


func _build_archway() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.24, 0.29, 0.34, 1.0)
	stone_mat.roughness = 0.86

	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.85, 0.25, 0.25, 1.0)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(0.85, 0.2, 0.2, 1.0)
	_rune_mat.emission_energy_multiplier = 1.6

	var base_step := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 4.2
	bm.bottom_radius = 4.8
	bm.height = 0.45
	bm.radial_segments = 12
	base_step.mesh = bm
	base_step.position = Vector3(0.0, 0.22, 0.0)
	base_step.material_override = stone_mat
	add_child(base_step)

	for sgn in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.56
		pm.bottom_radius = 0.68
		pm.height = 6.2
		pm.radial_segments = 10
		pillar.mesh = pm
		pillar.position = Vector3(sgn * 3.1, 3.1, 0.0)
		pillar.material_override = stone_mat
		add_child(pillar)

		var rune_col := MeshInstance3D.new()
		var rcm := BoxMesh.new()
		rcm.size = Vector3(0.24, 4.4, 1.25)
		rune_col.mesh = rcm
		rune_col.position = Vector3(sgn * 3.1, 3.1, 0.0)
		rune_col.material_override = _rune_mat
		add_child(rune_col)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(7.8, 1.1, 1.65)
	lintel.mesh = lm
	lintel.position = Vector3(0.0, 6.45, 0.0)
	lintel.material_override = stone_mat
	add_child(lintel)

	var keystone := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.58
	km.height = 1.25
	keystone.mesh = km
	keystone.position = Vector3(0.0, 7.2, 0.0)
	keystone.material_override = _rune_mat
	add_child(keystone)

	_ring_mesh = get_node_or_null("OuterAstrolabe") as MeshInstance3D
	if not _ring_mesh:
		_ring_mesh = MeshInstance3D.new()
		_ring_mesh.name = "OuterAstrolabe"
		add_child(_ring_mesh)
	var tm := TorusMesh.new()
	tm.inner_radius = 2.25
	tm.outer_radius = 2.55
	tm.rings = 24
	tm.ring_segments = 8
	_ring_mesh.mesh = tm
	_ring_mesh.position = Vector3(0.0, 3.25, 0.0)
	_ring_mesh.rotation.x = PI * 0.5
	_ring_mesh.material_override = _rune_mat

	_vortex_mat = StandardMaterial3D.new()
	_vortex_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vortex_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vortex_mat.albedo_color = Color(0.25, 0.96, 0.78, 0.72)
	_vortex_mat.emission_enabled = true
	_vortex_mat.emission = Color(0.32, 0.96, 0.72, 1.0)
	_vortex_mat.emission_energy_multiplier = 3.0
	_vortex_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_vortex_mesh = get_node_or_null("VortexDisc") as MeshInstance3D
	if not _vortex_mesh:
		_vortex_mesh = MeshInstance3D.new()
		_vortex_mesh.name = "VortexDisc"
		add_child(_vortex_mesh)
	var vm := CylinderMesh.new()
	vm.top_radius = 2.2
	vm.bottom_radius = 2.2
	vm.height = 0.08
	vm.radial_segments = 24
	_vortex_mesh.mesh = vm
	_vortex_mesh.position = Vector3(0.0, 3.25, 0.0)
	_vortex_mesh.rotation.x = PI * 0.5
	_vortex_mesh.material_override = _vortex_mat


func _set_portal_active(active: bool) -> void:
	_is_active = active
	if _vortex_mesh:
		_vortex_mesh.visible = active
	if _rune_mat:
		if active:
			_rune_mat.albedo_color = Color(0.35, 0.98, 0.78, 1.0)
			_rune_mat.emission = Color(0.3, 0.96, 0.76, 1.0)
			_rune_mat.emission_energy_multiplier = 3.2
		else:
			_rune_mat.albedo_color = Color(0.82, 0.24, 0.24, 1.0)
			_rune_mat.emission = Color(0.85, 0.18, 0.18, 1.0)
			_rune_mat.emission_energy_multiplier = 1.4


func awaken_portal() -> void:
	if _is_active:
		return
	_set_portal_active(true)
	if AudioManager:
		AudioManager.play_sfx("portal_unlock")
	GameManager.post_toast("PORTAL UNSEALED", "%s is now open — enter to reach %s!" % [portal_name, next_stage_label], Color(0.45, 1.0, 0.82))
	if _vortex_mesh:
		_vortex_mesh.scale = Vector3(0.1, 0.1, 0.1)
		create_tween().tween_property(_vortex_mesh, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _ring_mesh:
		_ring_mesh.rotate_z(delta * (1.4 if _is_active else 0.2))
	if _vortex_mesh and _is_active:
		var pulse: float = 1.0 + sin(_t * 3.8) * 0.04
		_vortex_mesh.scale = Vector3(pulse, 1.0, pulse)

	# Auto-unseal safeguard in case all stage quest steps completed
	if not _is_active and QuestManager and QuestManager.is_stage_portal_ready(QuestManager.active_stage):
		awaken_portal()

	# Allow walking directly through the open swirling vortex to travel to the next realm!
	if _is_active and not _triggered:
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		if player and is_instance_valid(player):
			var d: float = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
			if d < 2.25 and absf(player.global_position.y - global_position.y) < 3.5:
				interact(player)


func get_interact_prompt() -> String:
	if not _is_active:
		return "LOCKED — Complete Main Quest to unseal %s" % portal_name
	return "[E] or Walk Into %s -> %s" % [portal_name, next_stage_label]


func interact(_player: Node3D) -> void:
	if _triggered:
		return
	if not _is_active:
		if AudioManager:
			AudioManager.play_sfx("player_hurt", 0.7, 0.8)
		GameManager.post_toast("PORTAL SEALED", "Complete the Stage Main Quest objectives first!", Color(1.0, 0.48, 0.42))
		return
	_triggered = true
	if AudioManager:
		AudioManager.play_sfx("portal_unlock", 1.15, 1.2)
	if not quest_step_key.is_empty() and QuestManager:
		QuestManager.record_progress(quest_step_key, 1)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		await hud.fade_to_black(0.35)
	if is_inside_tree():
		GameManager.next_level()
