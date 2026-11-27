extends Node3D
## Live 3D Twilight Forest Clearing Main Menu — Pure Godot 4 (WebGL2 gl_compatibility).
## Renders an orbiting moonlit forest grove with campfire, MultiMesh trees, glowing mushrooms,
## and a floating spinning Golden Compass relic on an ancient pedestal, paired with clean
## New Adventure, Stage Select (1-4), Controls & Guide, Audio Settings, and Credits panels.

const Props3D = preload("res://scenes/world/props_visuals_3d.gd")
const TITLE_FONT: Font = preload("res://resources/fonts/title_font.tres")
const UI_FONT: Font = preload("res://resources/fonts/ui_font.tres")

@onready var cam_pivot: Node3D = $CameraPivot
@onready var we_node: WorldEnvironment = $WorldEnvironment

var _relic_root: Node3D = null
var _relic_ring_a: Node3D = null
var _relic_ring_b: Node3D = null
var _fireflies: Array[Node3D] = []
var _time: float = 0.0

var _sub_panel_title: Label = null
var _sub_panel_box: VBoxContainer = null
var _sub_panel: PanelContainer = null


func _ready() -> void:
	GameManager.set_ui_mouse()
	get_tree().paused = false
	_configure_env()
	_build_menu_ui()
	_build_3d_clearing()


func _configure_env() -> void:
	if we_node and we_node.environment:
		var env: Environment = we_node.environment.duplicate() as Environment
		we_node.environment = env
		env.ssr_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.volumetric_fog_enabled = false
		env.fog_enabled = true
		env.fog_light_color = Color(0.07, 0.18, 0.22, 1.0)
		env.fog_density = 0.012
		env.glow_enabled = true


func _build_3d_clearing() -> void:
	var world: Node3D = Node3D.new()
	world.name = "MenuClearing"
	add_child(world)

	# Mossy sculpted clearing disc
	var ground: MeshInstance3D = MeshInstance3D.new()
	var gm: CylinderMesh = CylinderMesh.new()
	gm.top_radius = 48.0
	gm.bottom_radius = 52.0
	gm.height = 2.0
	gm.radial_segments = 40
	ground.mesh = gm
	ground.position = Vector3(0.0, -1.0, 0.0)
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.14, 0.26, 0.18)
	gmat.roughness = 0.94
	ground.material_override = gmat
	world.add_child(ground)

	# Cobblestone sanctuary ring
	var plaza: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 6.2
	pm.bottom_radius = 6.6
	pm.height = 0.22
	plaza.mesh = pm
	plaza.position = Vector3(0.0, 0.08, 0.0)
	var pmat: StandardMaterial3D = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.32, 0.36, 0.34)
	pmat.roughness = 0.88
	plaza.material_override = pmat
	world.add_child(plaza)

	# Ancient Stone Pedestal & Floating Golden Compass Relic
	var ped: MeshInstance3D = MeshInstance3D.new()
	var ped_m: CylinderMesh = CylinderMesh.new()
	ped_m.top_radius = 0.95
	ped_m.bottom_radius = 1.25
	ped_m.height = 1.45
	ped_m.radial_segments = 8
	ped.mesh = ped_m
	ped.position = Vector3(0.0, 0.85, 0.0)
	ped.material_override = pmat
	world.add_child(ped)

	_relic_root = Node3D.new()
	_relic_root.position = Vector3(0.0, 2.7, 0.0)
	world.add_child(_relic_root)

	var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.84, 0.32)
	gold_mat.metallic = 0.92
	gold_mat.roughness = 0.18
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.78, 0.22)
	gold_mat.emission_energy_multiplier = 2.4

	_relic_ring_a = Node3D.new()
	_relic_root.add_child(_relic_ring_a)
	var ra_mi: MeshInstance3D = MeshInstance3D.new()
	var ra_m: TorusMesh = TorusMesh.new()
	ra_m.inner_radius = 0.85
	ra_m.outer_radius = 1.02
	ra_mi.mesh = ra_m
	ra_mi.material_override = gold_mat
	_relic_ring_a.add_child(ra_mi)

	_relic_ring_b = Node3D.new()
	_relic_root.add_child(_relic_ring_b)
	var rb_mi: MeshInstance3D = MeshInstance3D.new()
	var rb_m: TorusMesh = TorusMesh.new()
	rb_m.inner_radius = 0.54
	rb_m.outer_radius = 0.68
	rb_mi.mesh = rb_m
	rb_mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	rb_mi.material_override = gold_mat
	_relic_ring_b.add_child(rb_mi)

	var core_mi: MeshInstance3D = MeshInstance3D.new()
	var cm: SphereMesh = SphereMesh.new()
	cm.radius = 0.32
	cm.height = 0.64
	core_mi.mesh = cm
	var cmat: StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.55, 0.98, 1.0)
	cmat.emission_enabled = true
	cmat.emission = Color(0.42, 0.95, 1.0)
	cmat.emission_energy_multiplier = 3.2
	core_mi.material_override = cmat
	_relic_root.add_child(core_mi)

	var relic_light: OmniLight3D = OmniLight3D.new()
	relic_light.light_color = Color(1.0, 0.86, 0.42)
	relic_light.light_energy = 3.0
	relic_light.omni_range = 16.0
	_relic_root.add_child(relic_light)

	# Campfire, Stone Archway, Lanterns, Mushrooms & MultiMesh Forest Ring
	Props3D.spawn_campfire(world, Vector3(3.6, 0.0, 3.2), true)
	Props3D.spawn_stone_archway(world, Vector3(0.0, 0.0, -7.8), 9.0, 6.2, 0.0)
	Props3D.spawn_lantern_post(world, Vector3(-4.5, 0.0, 3.8), 0.35, true)
	Props3D.spawn_lantern_post(world, Vector3(4.5, 0.0, -4.2), PI - 0.35, false)

	var mush_xfs: Array = []
	for m_pos in [Vector3(-3.2, 0.0, 1.5), Vector3(3.0, 0.0, -2.5), Vector3(-5.8, 0.0, -3.0), Vector3(5.6, 0.0, 1.2)]:
		mush_xfs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.15, 1.15, 1.15)), m_pos))

	var pine_xfs: Array = []
	var oak_xfs: Array = []
	var rock_xfs: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	for i in 52:
		var ang: float = (float(i) / 52.0) * TAU + rng.randf_range(-0.08, 0.08)
		var dist: float = rng.randf_range(11.5, 34.0)
		var pos: Vector3 = Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		var sc: float = rng.randf_range(0.85, 1.45)
		var xf: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc, sc)), pos)
		if i % 3 == 0:
			oak_xfs.append(xf)
		else:
			pine_xfs.append(xf)
	for j in 24:
		var a2: float = rng.randf_range(0.0, TAU)
		var d2: float = rng.randf_range(7.5, 22.0)
		var sc2: float = rng.randf_range(0.6, 1.5)
		rock_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sc2, sc2 * 0.75, sc2)), Vector3(cos(a2) * d2, 0.0, sin(a2) * d2)))

	var bark_mat: StandardMaterial3D = Props3D.make_mat(Color(0.24, 0.16, 0.11, 1.0), 0.92)
	var pine_mat: StandardMaterial3D = Props3D.make_mat(Color(0.14, 0.36, 0.24, 1.0), 0.85)
	var oak_mat: StandardMaterial3D = Props3D.make_mat(Color(0.2, 0.44, 0.28, 1.0), 0.85)
	var rock_mat: StandardMaterial3D = Props3D.make_mat(Color(0.32, 0.38, 0.42, 1.0), 0.9)
	var mush_mat: StandardMaterial3D = Props3D.make_mat(Color(0.28, 0.95, 0.84, 1.0), 0.28, 0.0, Color(0.24, 0.92, 0.82, 1.0), 2.4)

	Props3D.spawn_multimesh(world, pine_xfs, Props3D.build_pine_trunk_mesh(), bark_mat)
	Props3D.spawn_multimesh(world, pine_xfs, Props3D.build_pine_canopy_mesh(), pine_mat)
	Props3D.spawn_multimesh(world, oak_xfs, Props3D.build_oak_trunk_mesh(), bark_mat)
	Props3D.spawn_multimesh(world, oak_xfs, Props3D.build_oak_canopy_mesh(), oak_mat)
	Props3D.spawn_multimesh(world, rock_xfs, Props3D.build_rock_mesh(), rock_mat)
	Props3D.spawn_multimesh(world, mush_xfs, Props3D.build_mushroom_cluster_mesh(), mush_mat)

	# Floating golden firefly motes
	var fmat: StandardMaterial3D = StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.94, 0.5)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.88, 0.34)
	fmat.emission_energy_multiplier = 3.6
	var fmesh: SphereMesh = SphereMesh.new()
	fmesh.radius = 0.07
	fmesh.height = 0.14
	for k in 18:
		var m: MeshInstance3D = MeshInstance3D.new()
		m.mesh = fmesh
		m.material_override = fmat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a3: float = float(k) * 0.7
		m.position = Vector3(cos(a3) * rng.randf_range(2.2, 8.5), rng.randf_range(1.0, 4.5), sin(a3) * rng.randf_range(2.2, 8.5))
		world.add_child(m)
		_fireflies.append(m)


func _process(delta: float) -> void:
	_time += delta
	if cam_pivot:
		cam_pivot.rotation.y = sin(_time * 0.16) * 0.42 + _time * 0.06
	if _relic_root:
		_relic_root.position.y = 2.65 + sin(_time * 1.8) * 0.22
	if _relic_ring_a:
		_relic_ring_a.rotation.y += delta * 0.85
		_relic_ring_a.rotation.x = sin(_time * 0.9) * 0.25
	if _relic_ring_b:
		_relic_ring_b.rotation.z -= delta * 1.15
	for i in _fireflies.size():
		var f: Node3D = _fireflies[i]
		f.position.y += sin(_time * 1.9 + float(i)) * delta * 0.35


func _make_box(bg: Color, border: Color, radius: int = 12, ph: float = 20.0, pv: float = 16.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = ph
	sb.content_margin_right = ph
	sb.content_margin_top = pv
	sb.content_margin_bottom = pv
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.shadow_size = 18
	return sb


func _make_btn(text_str: String, bg: Color = Color(0.11, 0.32, 0.25, 0.96), border: Color = Color(0.9, 0.74, 0.34)) -> Button:
	var b: Button = Button.new()
	b.text = text_str
	b.add_theme_font_override("font", UI_FONT)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.66))
	b.add_theme_stylebox_override("normal", _make_box(bg, border, 10, 20.0, 11.0))
	b.add_theme_stylebox_override("hover", _make_box(bg.lightened(0.16), Color(1.0, 0.88, 0.48), 10, 20.0, 11.0))
	b.add_theme_stylebox_override("pressed", _make_box(bg.darkened(0.14), border, 10, 20.0, 11.0))
	return b


func _build_menu_ui() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)

	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	# Left Main Title & Actions Card
	var card: PanelContainer = PanelContainer.new()
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = 48.0
	card.offset_right = 468.0
	card.offset_top = -250.0
	card.offset_bottom = 250.0
	card.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.055, 0.09, 0.86), Color(0.9, 0.74, 0.34, 0.94), 18, 28.0, 24.0))
	root.add_child(card)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var kicker: Label = Label.new()
	kicker.text = "PURE GODOT 4 • 3D FANTASY ADVENTURE"
	kicker.add_theme_font_override("font", UI_FONT)
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", Color(0.54, 0.92, 0.84))
	v.add_child(kicker)

	var title: Label = Label.new()
	title.text = "Magical Forest:\nThe Golden Compass"
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.48))
	v.add_child(title)

	var desc: Label = Label.new()
	desc.text = "Wield the Golden Compass across four enchanted realms, awaken Ancient Wayshrines, complete quests, and vanquish the corrupted guardians."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", UI_FONT)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.86, 0.92, 0.9))
	v.add_child(desc)

	var b_new: Button = _make_btn("New Adventure")
	b_new.pressed.connect(func() -> void:
		if AudioManager:
			AudioManager.play_sfx("ui_click")
		GameManager.reset_new_game(0)
	)
	v.add_child(b_new)

	var b_stages: Button = _make_btn("Stage Select (1–4)", Color(0.09, 0.2, 0.28, 0.96), Color(0.38, 0.74, 0.66))
	b_stages.pressed.connect(_show_stage_select)
	v.add_child(b_stages)

	var b_ctrl: Button = _make_btn("Controls & Guide", Color(0.09, 0.2, 0.28, 0.96), Color(0.38, 0.74, 0.66))
	b_ctrl.pressed.connect(_show_controls_guide)
	v.add_child(b_ctrl)

	var b_audio: Button = _make_btn("Audio Settings", Color(0.09, 0.2, 0.28, 0.96), Color(0.38, 0.74, 0.66))
	b_audio.pressed.connect(_show_audio_settings)
	v.add_child(b_audio)

	var b_cred: Button = _make_btn("Credits", Color(0.11, 0.14, 0.2, 0.96), Color(0.62, 0.72, 0.78))
	b_cred.pressed.connect(_show_credits)
	v.add_child(b_cred)

	# Right Side Sub-Panel (Stage Select / Controls / Audio / Credits)
	_sub_panel = PanelContainer.new()
	_sub_panel.anchor_left = 1.0
	_sub_panel.anchor_right = 1.0
	_sub_panel.anchor_top = 0.5
	_sub_panel.anchor_bottom = 0.5
	_sub_panel.offset_left = -470.0
	_sub_panel.offset_right = -48.0
	_sub_panel.offset_top = -230.0
	_sub_panel.offset_bottom = 230.0
	_sub_panel.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.055, 0.09, 0.9), Color(0.4, 0.76, 0.68, 0.92), 16, 24.0, 20.0))
	_sub_panel.visible = false
	root.add_child(_sub_panel)

	var sv: VBoxContainer = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	_sub_panel.add_child(sv)

	_sub_panel_title = Label.new()
	_sub_panel_title.add_theme_font_override("font", TITLE_FONT)
	_sub_panel_title.add_theme_font_size_override("font_size", 22)
	_sub_panel_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.48))
	sv.add_child(_sub_panel_title)

	_sub_panel_box = VBoxContainer.new()
	_sub_panel_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sub_panel_box.add_theme_constant_override("separation", 10)
	sv.add_child(_sub_panel_box)

	var close_b: Button = _make_btn("Close", Color(0.22, 0.12, 0.14, 0.95), Color(0.86, 0.52, 0.48))
	close_b.pressed.connect(func() -> void: _sub_panel.visible = false)
	sv.add_child(close_b)


func _open_sub_panel(title_str: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_click")
	_sub_panel_title.text = title_str
	for c in _sub_panel_box.get_children():
		c.queue_free()
	_sub_panel.visible = true


func _show_stage_select() -> void:
	_open_sub_panel("SELECT REALM")
	var stage_infos: Array = [
		["Stage 1 — Whispering Moss Woods", "Moonlit forest trails, Elder Sylvan, Sunlit Shards & hidden chests."],
		["Stage 2 — Thornhollow Ancient Ruins", "Misty mossy courtyards, 3 Ancient Rune Pillars, Lore Runestones & Golems."],
		["Stage 3 — Heart of the Grove", "Sacred Boss Sanctum — Face Vaelthorn, the Corrupted Forest Guardian."],
		["Stage 4 — Astral Canopy Sanctuary", "Starlit sky islands, Astral Light Bridges & Final Boss Aurelius."],
	]
	for i in stage_infos.size():
		var info: Array = stage_infos[i]
		var btn: Button = _make_btn(String(info[0]), Color(0.1, 0.24, 0.22, 0.95))
		var idx: int = i
		btn.pressed.connect(func() -> void:
			if AudioManager:
				AudioManager.play_sfx("ui_click")
			GameManager.reset_new_game(idx)
		)
		_sub_panel_box.add_child(btn)
		var dl: Label = Label.new()
		dl.text = String(info[1])
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_override("font", UI_FONT)
		dl.add_theme_font_size_override("font_size", 12)
		dl.add_theme_color_override("font_color", Color(0.76, 0.88, 0.86))
		_sub_panel_box.add_child(dl)


func _show_controls_guide() -> void:
	_open_sub_panel("CONTROLS & GUIDE")
	var lines: Array[String] = [
		"WASD / Arrows — Move Explorer",
		"Mouse Move / Wheel — Orbit Camera & Zoom",
		"Space — Jump & Double Jump",
		"Shift — Evade Dash (with Invulnerability Frames)",
		"Left Click / J — 3-Hit Rune Blade Melee Combo",
		"Right Click / K — Golden Compass Arc (Ranged Wave, 25 Energy)",
		"G — Golden Compass Pulse (Firefly Trail, Secret Beacons, Astral Bridges & Boss Shield Shatter)",
		"E — Interact (NPCs, Wayshrines, Chests, Rune Pillars, Portals)",
		"H — Use Healing Herb (+2 Vitality)",
		"Q / Tab — Quest Journal   •   Esc — Pause Menu",
	]
	for l in lines:
		var lbl: Label = Label.new()
		lbl.text = "• " + l
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", UI_FONT)
		lbl.add_theme_font_size_override("font_size", 13)
		_sub_panel_box.add_child(lbl)


func _show_audio_settings() -> void:
	_open_sub_panel("AUDIO SETTINGS")
	var m_lbl: Label = Label.new()
	m_lbl.text = "Master Volume"
	m_lbl.add_theme_font_override("font", UI_FONT)
	_sub_panel_box.add_child(m_lbl)
	var ms: HSlider = HSlider.new()
	ms.min_value = 0.0
	ms.max_value = 1.0
	ms.step = 0.05
	ms.value = AudioManager.master_volume if AudioManager else 0.85
	ms.value_changed.connect(func(v: float) -> void:
		if AudioManager:
			AudioManager.set_master_volume(v)
	)
	_sub_panel_box.add_child(ms)

	var s_lbl: Label = Label.new()
	s_lbl.text = "Sound Effects (SFX) Volume"
	s_lbl.add_theme_font_override("font", UI_FONT)
	_sub_panel_box.add_child(s_lbl)
	var ss: HSlider = HSlider.new()
	ss.min_value = 0.0
	ss.max_value = 1.0
	ss.step = 0.05
	ss.value = AudioManager.sfx_volume if AudioManager else 0.9
	ss.value_changed.connect(func(v: float) -> void:
		if AudioManager:
			AudioManager.set_sfx_volume(v)
	)
	_sub_panel_box.add_child(ss)

	var test_btn: Button = _make_btn("Test Compass Chime", Color(0.14, 0.28, 0.24, 0.95))
	test_btn.pressed.connect(func() -> void:
		if AudioManager:
			AudioManager.play_sfx("compass_pulse")
	)
	_sub_panel_box.add_child(test_btn)


func _show_credits() -> void:
	_open_sub_panel("CREDITS")
	var c_lbl: Label = Label.new()
	c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_lbl.add_theme_font_override("font", UI_FONT)
	c_lbl.add_theme_font_size_override("font_size", 14)
	c_lbl.text = "Magical Forest: The Golden Compass\n\nEngine: Pure Godot 4 (GDScript-only, WebGL2 gl_compatibility)\n\nFeatures:\n• 4 Complete 3D Stages with Deterministic Sculpted Terrain & MultiMesh Forests\n• Full Main & Side Quest RPG Campaign with Story NPCs & Dialogue\n• Live Golden Compass Pulse, Firefly Trail, Secret Reveal & Astral Bridges\n• 4 Enemy Archetypes & 2 Multi-Phase Boss Encounters\n• 100% Procedural WebGL2-Safe Audio Synthesis"
	_sub_panel_box.add_child(c_lbl)
