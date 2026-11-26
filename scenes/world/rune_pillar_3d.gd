extends Node3D
## Stage 2 Ancient Rune Pillar — interactive courtyard monolith.
## Pressing [E] illuminates its runes, shoots an energy beam skyward, and progresses "Seals of Thornhollow".

@export var pillar_index: int = 1

var compass_label: String = "Ancient Rune Pillar"
var _activated: bool = false
var _t: float = 0.0
var _crystal: MeshInstance3D = null
var _rune_mat: StandardMaterial3D = null
var _beam: MeshInstance3D = null


func _ready() -> void:
	compass_label = "Rune Pillar #%d" % pillar_index
	add_to_group("interactable")
	add_to_group("rune_pillar")
	_build_visuals()


func _build_visuals() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.24, 0.29, 0.35, 1.0)
	stone_mat.roughness = 0.85

	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.32, 0.72, 0.95, 1.0)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(0.22, 0.65, 0.95, 1.0)
	_rune_mat.emission_energy_multiplier = 1.1

	var plinth := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 1.25
	pm.bottom_radius = 1.55
	pm.height = 0.55
	pm.radial_segments = 8
	plinth.mesh = pm
	plinth.position = Vector3(0.0, 0.275, 0.0)
	plinth.material_override = stone_mat
	add_child(plinth)

	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.55
	sm.bottom_radius = 0.72
	sm.height = 3.6
	sm.radial_segments = 6
	shaft.mesh = sm
	shaft.position = Vector3(0.0, 2.2, 0.0)
	shaft.material_override = stone_mat
	add_child(shaft)

	var band := MeshInstance3D.new()
	var bdm := CylinderMesh.new()
	bdm.top_radius = 0.64
	bdm.bottom_radius = 0.64
	bdm.height = 0.45
	bdm.radial_segments = 6
	band.mesh = bdm
	band.position = Vector3(0.0, 2.8, 0.0)
	band.material_override = _rune_mat
	add_child(band)

	_crystal = MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.42
	cm.height = 0.96
	cm.radial_segments = 8
	cm.rings = 4
	_crystal.mesh = cm
	_crystal.position = Vector3(0.0, 4.75, 0.0)
	_crystal.material_override = _rune_mat
	add_child(_crystal)

	_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.16
	bm.bottom_radius = 0.42
	bm.height = 28.0
	_beam.mesh = bm
	_beam.position = Vector3(0.0, 18.0, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(0.45, 0.96, 1.0, 0.42)
	bmat.emission_enabled = true
	bmat.emission = Color(0.35, 0.95, 1.0, 1.0)
	bmat.emission_energy_multiplier = 3.2
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam.material_override = bmat
	_beam.visible = false
	add_child(_beam)

	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.95
	cs.height = 4.2
	col.shape = cs
	col.position = Vector3(0.0, 2.1, 0.0)
	col_body.add_child(col)
	add_child(col_body)


func _process(delta: float) -> void:
	_t += delta
	if _crystal:
		_crystal.rotate_y(delta * (3.2 if _activated else 0.9))
		_crystal.position.y = 4.75 + sin(_t * 2.6) * 0.18


func is_activated() -> bool:
	return _activated


func is_compass_eligible() -> bool:
	return not _activated


func get_interact_prompt() -> String:
	if _activated:
		return ""
	return "[E] Activate Ancient Rune Pillar #%d" % pillar_index


func interact(_player: Node3D) -> void:
	if _activated:
		return
	_activated = true
	if AudioManager:
		AudioManager.play_sfx("rune_activate")
	if _rune_mat:
		_rune_mat.albedo_color = Color(1.0, 0.92, 0.44, 1.0)
		_rune_mat.emission = Color(1.0, 0.85, 0.28, 1.0)
		_rune_mat.emission_energy_multiplier = 3.8
	if _beam:
		_beam.visible = true
	GameManager.add_score(120)
	GameManager.post_toast("RUNE PILLAR AWAKENED", "Ancient Seal %d/3 resonates toward the Sanctum!" % pillar_index, Color(0.55, 0.96, 1.0))
	if QuestManager:
		QuestManager.record_progress("activate_pillars", 1)
