extends Node3D
## Stylized 3D Interactive Story NPC (Elder Sylvan, Wandering Cartographer, Grove Spirit, Astral Weaver).
## Features procedural hooded/robed 3D rig, gentle idle breathing, floating golden "!" / "?" marker,
## Compass targeting registration, and [E] Dialogue interaction.

@export var npc_name: String = "Elder Sylvan"
@export var npc_role: String = "Keeper of the Whispering Woods"
@export var quest_step_key: String = "talk_sylvan"
@export var side_quest_id: String = ""
@export var robe_color: Color = Color(0.14, 0.34, 0.24, 1.0)
@export var accent_color: Color = Color(0.95, 0.78, 0.32, 1.0)
@export var dialogue_lines: Array[String] = []
@export var repeat_lines: Array[String] = []
@export var heals_on_talk: bool = false

var compass_label: String = "Elder Sylvan"
var _talked: bool = false
var _t: float = 0.0
var _body_pivot: Node3D = null
var _marker_pivot: Node3D = null
var _marker_mat: StandardMaterial3D = null


func _ready() -> void:
	compass_label = npc_name
	add_to_group("interactable")
	add_to_group("npc_quest")
	_build_visuals()


func _build_visuals() -> void:
	_body_pivot = Node3D.new()
	_body_pivot.name = "BodyPivot"
	add_child(_body_pivot)

	var robe_mat := StandardMaterial3D.new()
	robe_mat.albedo_color = robe_color
	robe_mat.roughness = 0.85

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = accent_color
	trim_mat.metallic = 0.65
	trim_mat.roughness = 0.28
	trim_mat.emission_enabled = true
	trim_mat.emission = accent_color
	trim_mat.emission_energy_multiplier = 0.45

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.84, 0.72, 0.62, 1.0)
	skin_mat.roughness = 0.72

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.32, 0.21, 0.13, 1.0)
	wood_mat.roughness = 0.9

	# Flowing robe skirt
	var robe := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.24
	rm.bottom_radius = 0.44
	rm.height = 1.28
	rm.radial_segments = 10
	robe.mesh = rm
	robe.position = Vector3(0.0, 0.64, 0.0)
	robe.material_override = robe_mat
	_body_pivot.add_child(robe)

	# Shoulder mantle
	var mantle := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.22
	mm.bottom_radius = 0.42
	mm.height = 0.34
	mm.radial_segments = 10
	mantle.mesh = mm
	mantle.position = Vector3(0.0, 1.26, 0.0)
	mantle.material_override = trim_mat
	_body_pivot.add_child(mantle)

	# Head + hooded cowl
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.18
	hm.height = 0.36
	head.mesh = hm
	head.position = Vector3(0.0, 1.56, -0.02)
	head.material_override = skin_mat
	_body_pivot.add_child(head)

	var hood := MeshInstance3D.new()
	var hdm := SphereMesh.new()
	hdm.radius = 0.23
	hdm.height = 0.44
	hood.mesh = hdm
	hood.position = Vector3(0.0, 1.59, 0.04)
	hood.material_override = robe_mat
	_body_pivot.add_child(hood)

	# Glowing sage staff in right hand
	var staff := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03
	sm.bottom_radius = 0.038
	sm.height = 2.05
	sm.radial_segments = 8
	staff.mesh = sm
	staff.position = Vector3(0.42, 1.02, -0.14)
	staff.rotation.z = -0.08
	staff.material_override = wood_mat
	_body_pivot.add_child(staff)

	var orb := MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.11
	om.height = 0.22
	orb.mesh = om
	orb.position = Vector3(0.49, 2.05, -0.14)
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = accent_color
	orb_mat.emission_enabled = true
	orb_mat.emission = accent_color
	orb_mat.emission_energy_multiplier = 2.8
	orb.material_override = orb_mat
	_body_pivot.add_child(orb)

	# Solid cylinder collision so player does not walk through NPC
	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.45
	cs.height = 1.85
	col.shape = cs
	col.position = Vector3(0.0, 0.92, 0.0)
	col_body.add_child(col)
	add_child(col_body)

	# Floating golden Quest Marker ("!") above head
	_marker_pivot = Node3D.new()
	_marker_pivot.position = Vector3(0.0, 2.48, 0.0)
	add_child(_marker_pivot)

	_marker_mat = StandardMaterial3D.new()
	_marker_mat.albedo_color = Color(1.0, 0.9, 0.35, 1.0)
	_marker_mat.emission_enabled = true
	_marker_mat.emission = Color(1.0, 0.82, 0.22, 1.0)
	_marker_mat.emission_energy_multiplier = 3.2

	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.42, 0.11)
	bar.mesh = bm
	bar.position = Vector3(0.0, 0.18, 0.0)
	bar.material_override = _marker_mat
	_marker_pivot.add_child(bar)

	var dot := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.08
	dm.height = 0.16
	dot.mesh = dm
	dot.position = Vector3(0.0, -0.14, 0.0)
	dot.material_override = _marker_mat
	_marker_pivot.add_child(dot)


func _process(delta: float) -> void:
	_t += delta
	if _body_pivot:
		_body_pivot.position.y = sin(_t * 2.1) * 0.035
	if _marker_pivot:
		_marker_pivot.position.y = 2.52 + sin(_t * 3.4) * 0.12
		_marker_pivot.rotate_y(delta * 1.9)
		_marker_pivot.visible = not _talked


func is_compass_eligible() -> bool:
	return not _talked


func get_interact_prompt() -> String:
	return "[E] Talk to %s" % npc_name


func interact(player: Node3D) -> void:
	if player and is_instance_valid(player):
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0.0
		if to_p.length() > 0.1:
			rotation.y = atan2(to_p.x, to_p.z)

	var lines_to_show: Array = dialogue_lines if (not _talked or repeat_lines.is_empty()) else repeat_lines
	if lines_to_show.is_empty():
		lines_to_show = ["Follow the Golden Compass light, traveler. Press [G] whenever you seek the path."]

	GameManager.dialogue_requested.emit(npc_name, npc_role, lines_to_show, Callable(self, "_on_dialogue_finished"))


func _on_dialogue_finished() -> void:
	if heals_on_talk:
		GameManager.full_restore()
		if AudioManager:
			AudioManager.play_sfx("wayshrine_ignite")
	if not _talked:
		_talked = true
		if not quest_step_key.is_empty() and QuestManager:
			QuestManager.record_progress(quest_step_key, 1)
		if not side_quest_id.is_empty() and QuestManager:
			QuestManager.activate_side_quest(side_quest_id)
