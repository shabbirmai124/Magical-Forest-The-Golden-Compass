extends Node3D
## Live 3D Sanctuary Title Screen with sculpted trees, fluted ruins,
## water reflections, swaying grass/ferns, flickering lanterns, orbiting Golden Compass,
## smooth entrance animations, UI hover springs, and cinematic dolly transitions.

const MeshFactory3D = preload("res://scenes/common/mesh_factory_3d.gd")
const SHADER_TERRAIN: Shader = preload("res://resources/shaders/terrain_blend_3d.gdshader")
const SHADER_FOLIAGE: Shader = preload("res://resources/shaders/foliage_sway_3d.gdshader")
const SHADER_WATER: Shader = preload("res://resources/shaders/forest_water_3d.gdshader")
const SHADER_RAY: Shader = preload("res://resources/shaders/god_ray_3d.gdshader")
const MAT_STONE: StandardMaterial3D = preload("res://resources/materials3d/ancient_stone.tres")
const TEX_MOSS_ALB: Texture2D = preload("res://assets/textures3d/moss_ground_albedo.png")
const TEX_MOSS_N: Texture2D = preload("res://assets/textures3d/moss_ground_n.png")
const TEX_MOSS_R: Texture2D = preload("res://assets/textures3d/moss_ground_r.png")
const TEX_STONE_ALB: Texture2D = preload("res://assets/textures3d/ancient_stone_albedo.png")
const TEX_STONE_N: Texture2D = preload("res://assets/textures3d/ancient_stone_n.png")
const TEX_STONE_R: Texture2D = preload("res://assets/textures3d/ancient_stone_r.png")
const TEX_BRANCH_CARD: Texture2D = preload("res://assets/textures3d/foliage_branch_card.png")
const TEX_GRASS_CARD: Texture2D = preload("res://assets/textures3d/grass_tuft_card.png")
const TEX_WATER_N: Texture2D = preload("res://assets/textures3d/water_normal.png")

@onready var diorama: Node3D = $Diorama
@onready var camera_pivot: Node3D = $CameraPivot
@onready var cam: Camera3D = $CameraPivot/Camera3D
@onready var menu_card: PanelContainer = $UI/CenterContainer/MenuCard
@onready var screen_fade: ColorRect = $UI/ScreenFade
@onready var compass_icon: TextureRect = $UI/CenterContainer/MenuCard/Margin/VBox/CompassIcon
@onready var play_button: Button = $UI/CenterContainer/MenuCard/Margin/VBox/PlayButton
@onready var chapters_button: Button = $UI/CenterContainer/MenuCard/Margin/VBox/ChaptersButton
@onready var chapters_box: HBoxContainer = $UI/CenterContainer/MenuCard/Margin/VBox/ChaptersBox
@onready var lvl1_btn: Button = $UI/CenterContainer/MenuCard/Margin/VBox/ChaptersBox/Lvl1Btn
@onready var lvl2_btn: Button = $UI/CenterContainer/MenuCard/Margin/VBox/ChaptersBox/Lvl2Btn
@onready var lvl3_btn: Button = $UI/CenterContainer/MenuCard/Margin/VBox/ChaptersBox/Lvl3Btn
@onready var lvl4_btn: Button = $UI/CenterContainer/MenuCard/Margin/VBox/ChaptersBox/Lvl4Btn
@onready var controls_button: Button = $UI/CenterContainer/MenuCard/Margin/VBox/ControlsButton
@onready var controls_info: Label = $UI/CenterContainer/MenuCard/Margin/VBox/ControlsInfo
@onready var quit_button: Button = $UI/CenterContainer/MenuCard/Margin/VBox/QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = $AmbiencePlayer

var _launching: bool = false
var _t: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_upgrade_diorama()

	# Smooth fade-in and card reveal
	if screen_fade:
		screen_fade.color = Color(0.0, 0.0, 0.0, 1.0)
		create_tween().tween_property(screen_fade, "color:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if menu_card:
		menu_card.modulate.a = 0.0
		menu_card.scale = Vector2(0.92, 0.92)
		menu_card.pivot_offset = Vector2(460.0, 320.0)
		var ctw := create_tween().set_parallel(true)
		ctw.tween_property(menu_card, "modulate:a", 1.0, 0.55)
		ctw.tween_property(menu_card, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for btn in [play_button, chapters_button, lvl1_btn, lvl2_btn, lvl3_btn, lvl4_btn, controls_button, quit_button]:
		_attach_hover_spring(btn)

	play_button.grab_focus()
	play_button.pressed.connect(func() -> void: _launch_level(0))
	chapters_button.pressed.connect(_toggle_chapters)
	lvl1_btn.pressed.connect(func() -> void: _launch_level(0))
	lvl2_btn.pressed.connect(func() -> void: _launch_level(1))
	lvl3_btn.pressed.connect(func() -> void: _launch_level(2))
	lvl4_btn.pressed.connect(func() -> void: _launch_level(3))
	controls_button.pressed.connect(_toggle_controls)
	quit_button.pressed.connect(func() -> void: get_tree().quit())

	if OS.has_feature("web"):
		quit_button.visible = false

	_loop_audio(music_player)
	_loop_audio(ambience_player)


func _attach_hover_spring(btn: Button) -> void:
	if not btn:
		return
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
		create_tween().tween_property(btn, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_BACK)
	)
	btn.mouse_exited.connect(func() -> void:
		create_tween().tween_property(btn, "scale", Vector2.ONE, 0.14)
	)


func _toggle_chapters() -> void:
	chapters_box.visible = not chapters_box.visible
	if chapters_box.visible:
		chapters_box.modulate.a = 0.0
		create_tween().tween_property(chapters_box, "modulate:a", 1.0, 0.22)


func _toggle_controls() -> void:
	controls_info.visible = not controls_info.visible
	if controls_info.visible:
		controls_info.modulate.a = 0.0
		create_tween().tween_property(controls_info, "modulate:a", 1.0, 0.22)


func _launch_level(idx: int) -> void:
	if _launching:
		return
	_launching = true
	var tw := create_tween().set_parallel(true)
	if cam:
		tw.tween_property(cam, "fov", 44.0, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if menu_card:
		tw.tween_property(menu_card, "modulate:a", 0.0, 0.3)
	if screen_fade:
		tw.tween_property(screen_fade, "color:a", 1.0, 0.44)
	await tw.finished
	if is_inside_tree():
		GameManager.start_level_by_index(idx)


func _upgrade_diorama() -> void:
	if not diorama:
		return
	var floor_mi := diorama.get_node_or_null("ClearingFloor") as MeshInstance3D
	if floor_mi:
		floor_mi.mesh = MeshFactory3D.build_sculpted_island_mesh(Vector3(36.0, 3.5, 36.0))
		floor_mi.position.y = -1.75
		var tmat := ShaderMaterial.new()
		tmat.shader = SHADER_TERRAIN
		tmat.set_shader_parameter("top_albedo", TEX_MOSS_ALB)
		tmat.set_shader_parameter("top_normal", TEX_MOSS_N)
		tmat.set_shader_parameter("side_albedo", TEX_STONE_ALB)
		tmat.set_shader_parameter("side_normal", TEX_STONE_N)
		floor_mi.material_override = tmat

	var fmat := ShaderMaterial.new()
	fmat.shader = SHADER_FOLIAGE
	fmat.set_shader_parameter("foliage_tex", TEX_BRANCH_CARD)
	for t_name in ["Tree1", "Tree2", "Tree3"]:
		var tr := diorama.get_node_or_null(t_name) as Node3D
		if tr:
			var tk := tr.get_node_or_null("Trunk") as MeshInstance3D
			if tk:
				tk.mesh = MeshFactory3D.build_gnarled_trunk_mesh(7.8, 0.85, 0.32, t_name.hash())
				tk.position.y = 0.0
			var cp := tr.get_node_or_null("Canopy") as MeshInstance3D
			if cp:
				cp.mesh = MeshFactory3D.build_foliage_canopy_cluster_mesh(3.3, 24, t_name.hash())
				cp.material_override = fmat

	for idx in 4:
		var ang := deg_to_rad(45.0 + float(idx) * 90.0)
		var pil := MeshInstance3D.new()
		pil.mesh = MeshFactory3D.build_fluted_column_mesh(0.55, 5.2)
		pil.position = Vector3(cos(ang) * 7.2, 0.0, sin(ang) * 7.2)
		pil.material_override = MAT_STONE
		diorama.add_child(pil)

	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = SHADER_FOLIAGE
	grass_mat.set_shader_parameter("foliage_tex", TEX_GRASS_CARD)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshFactory3D.build_crossed_frond_mesh(0.55, 0.85)
	mm.instance_count = 110
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in 110:
		var r := rng.randf_range(2.2, 14.5)
		var a := rng.randf_range(0.0, TAU)
		var sc := rng.randf_range(0.75, 1.35)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * sc), Vector3(cos(a) * r, -0.02, sin(a) * r)))
	var gm := MultiMeshInstance3D.new()
	gm.multimesh = mm
	gm.material_override = grass_mat
	diorama.add_child(gm)

	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	pm.subdivide_width = 16
	pm.subdivide_depth = 16
	water.mesh = pm
	water.position.y = -3.6
	var wmat := ShaderMaterial.new()
	wmat.shader = SHADER_WATER
	wmat.set_shader_parameter("water_normal_tex", TEX_WATER_N)
	water.material_override = wmat
	diorama.add_child(water)

	var ray := MeshInstance3D.new()
	var rcm := CylinderMesh.new()
	rcm.top_radius = 1.1; rcm.bottom_radius = 3.8; rcm.height = 18.0
	ray.mesh = rcm
	ray.position = Vector3(1.2, 8.5, -1.2)
	ray.rotation = Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(15.0))
	var rmat := ShaderMaterial.new()
	rmat.shader = SHADER_RAY
	ray.material_override = rmat
	diorama.add_child(ray)

	var rp := ReflectionProbe.new()
	rp.size = Vector3(60, 30, 60)
	rp.position.y = 5.0
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	diorama.add_child(rp)


func _process(delta: float) -> void:
	_t += delta
	if camera_pivot:
		camera_pivot.rotate_y(delta * (0.55 if _launching else 0.14))
	if compass_icon:
		compass_icon.rotation = sin(_t * 1.4) * 0.045


func _loop_audio(ap: AudioStreamPlayer) -> void:
	if ap and ap.stream:
		ap.finished.connect(ap.play)
		if not ap.playing:
			ap.play()
