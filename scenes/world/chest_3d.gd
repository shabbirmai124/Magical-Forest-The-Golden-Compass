extends Node3D
## Interactive 3D Treasure Chest — hinged lid animation, golden burst VFX,
## grants +1 Healing Herb, +100 Score, and progresses Side Quest "Lost Lantern Relics".

@export var chest_name: String = "Hidden Forest Chest"
@export var bonus_score: int = 100
@export var grants_vitality_upgrade: bool = false
@export var quest_step_key: String = "open_chests_1"

var compass_label: String = "Hidden Chest"
var is_opened: bool = false
var _lid_pivot: Node3D = null
var _glow_core: MeshInstance3D = null
var _beacon: MeshInstance3D = null


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("chest")
	_build_visuals()


func _build_visuals() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.36, 0.22, 0.12, 1.0)
	wood_mat.roughness = 0.82

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.96, 0.78, 0.28, 1.0)
	gold_mat.metallic = 0.85
	gold_mat.roughness = 0.24
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.95, 0.72, 0.2, 1.0)
	gold_mat.emission_energy_multiplier = 0.55

	# Chest base box
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.24, 0.62, 0.82)
	base.mesh = bm
	base.position = Vector3(0.0, 0.31, 0.0)
	base.material_override = wood_mat
	add_child(base)

	# Gold straps
	for sx in [-0.46, 0.46]:
		var strap := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.11, 0.65, 0.86)
		strap.mesh = sm
		strap.position = Vector3(sx, 0.32, 0.0)
		strap.material_override = gold_mat
		add_child(strap)

	# Lock clasp
	var clasp := MeshInstance3D.new()
	var clm := BoxMesh.new()
	clm.size = Vector3(0.18, 0.22, 0.08)
	clasp.mesh = clm
	clasp.position = Vector3(0.0, 0.56, 0.43)
	clasp.material_override = gold_mat
	add_child(clasp)

	# Hinged lid
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0.0, 0.62, -0.41)
	add_child(_lid_pivot)

	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.28, 0.26, 0.86)
	lid.mesh = lm
	lid.position = Vector3(0.0, 0.13, 0.41)
	lid.material_override = wood_mat
	_lid_pivot.add_child(lid)

	for sx in [-0.46, 0.46]:
		var lstrap := MeshInstance3D.new()
		var lsm := BoxMesh.new()
		lsm.size = Vector3(0.12, 0.29, 0.88)
		lstrap.mesh = lsm
		lstrap.position = Vector3(sx, 0.14, 0.41)
		lstrap.material_override = gold_mat
		_lid_pivot.add_child(lstrap)

	# Inner golden treasure glow
	_glow_core = MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.28
	gm.height = 0.28
	_glow_core.mesh = gm
	_glow_core.position = Vector3(0.0, 0.52, 0.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.92, 0.42, 1.0)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.85, 0.28, 1.0)
	gmat.emission_energy_multiplier = 3.2
	_glow_core.material_override = gmat
	_glow_core.visible = false
	add_child(_glow_core)

	# Static collision
	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.3, 0.9, 0.9)
	col.shape = bs
	col.position = Vector3(0.0, 0.45, 0.0)
	col_body.add_child(col)
	add_child(col_body)

	# Compass Pulse beacon
	_beacon = MeshInstance3D.new()
	var cbm := CylinderMesh.new()
	cbm.top_radius = 0.2
	cbm.bottom_radius = 0.42
	cbm.height = 15.0
	_beacon.mesh = cbm
	_beacon.position = Vector3(0.0, 7.5, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(1.0, 0.88, 0.3, 0.35)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.82, 0.22, 1.0)
	bmat.emission_energy_multiplier = 2.4
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon.material_override = bmat
	_beacon.visible = false
	add_child(_beacon)


func is_compass_eligible() -> bool:
	return not is_opened


func highlight_compass_beacon(duration: float = 10.0) -> void:
	if is_opened or not _beacon:
		return
	_beacon.visible = true
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(_beacon):
			_beacon.visible = false
	)


func get_interact_prompt() -> String:
	if is_opened:
		return ""
	return "[E] Open %s" % chest_name


func interact(_player: Node3D) -> void:
	if is_opened:
		return
	is_opened = true
	if _beacon:
		_beacon.visible = false
	if AudioManager:
		AudioManager.play_sfx("chest_open")

	if _lid_pivot:
		create_tween().tween_property(_lid_pivot, "rotation:x", deg_to_rad(-108.0), 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _glow_core:
		_glow_core.visible = true
		_glow_core.scale = Vector3.ONE * 0.2
		var tw := create_tween()
		tw.tween_property(_glow_core, "scale", Vector3.ONE * 1.35, 0.35).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_glow_core, "position:y", 1.2, 0.5)
		tw.tween_property(_glow_core, "scale", Vector3.ZERO, 0.3)

	GameManager.register_chest_opened(bonus_score)
	if grants_vitality_upgrade:
		GameManager.upgrade_max_vitality(1)
		GameManager.post_toast("TREASURE FOUND", "+1 Max Vitality, +1 Healing Herb & +%d Score" % bonus_score, Color(1.0, 0.88, 0.36))
	else:
		GameManager.post_toast("TREASURE FOUND", "+1 Healing Herb & +%d Score" % bonus_score, Color(1.0, 0.88, 0.36))

	if not quest_step_key.is_empty() and QuestManager:
		QuestManager.record_progress(quest_step_key, 1)
