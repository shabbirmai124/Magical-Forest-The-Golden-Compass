extends Node2D
## Level controller & procedural greybox/forest layout populator (64x64 HD tile grid).
## All required platform rises are capped at <= 128 px (<= 65% of max jump height ~196 px)
## so every jump across all levels is mathematically fair and softlock-free.

@export_enum("greybox", "level_1", "level_2", "level_3") var layout_id: String = "level_1"
@export var level_title: String = "Whispering Canopy"
@export var level_index: int = 0
@export var show_controls_hint: bool = false
@export var camera_bounds: Rect2i = Rect2i(0, 0, 5120, 1440)
@export var camera_zoom: float = 1.06

const LANTERN_LIGHT_SCENE := preload("res://scenes/world/forest_lantern.tscn")

@onready var ground: TileMapLayer = $GroundLayer
@onready var back_decor: TileMapLayer = $BackDecorLayer
@onready var front_decor: TileMapLayer = $FrontDecorLayer
@onready var player: CharacterBody2D = $Player
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = $AmbiencePlayer

var _lantern: PointLight2D
var _base_energy: float = 0.95
var _flicker_t: float = 0.0
var _world_lanterns: Array[PointLight2D] = []


func _ready() -> void:
	GameManager.on_level_ready(level_index)

	if player:
		if player.has_method("set_camera_limits"):
			player.set_camera_limits(
				camera_bounds.position.x,
				camera_bounds.position.y,
				camera_bounds.position.x + camera_bounds.size.x,
				camera_bounds.position.y + camera_bounds.size.y,
				camera_zoom
			)
		_lantern = player.get_node_or_null("LanternLight") as PointLight2D
		if _lantern:
			_base_energy = _lantern.energy

	_setup_audio_loop(music_player)
	_setup_audio_loop(ambience_player)

	if ground and ground.get_used_cells().is_empty():
		_build_default_layout()

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_level_banner"):
		hud.show_level_banner(level_title, show_controls_hint)


func _process(delta: float) -> void:
	_flicker_t += delta * 6.0
	if _lantern:
		_lantern.energy = _base_energy + sin(_flicker_t) * 0.05 + sin(_flicker_t * 2.3) * 0.03
	for i in _world_lanterns.size():
		var wl := _world_lanterns[i]
		if is_instance_valid(wl):
			wl.energy = 0.84 + sin(_flicker_t * 0.8 + i * 1.7) * 0.06


func _setup_audio_loop(ap: AudioStreamPlayer) -> void:
	if ap and ap.stream:
		ap.finished.connect(ap.play)
		if not ap.playing:
			ap.play()


func _fill_rect(layer: TileMapLayer, x0: int, y0: int, w: int, h: int, atlas: Vector2i) -> void:
	for x in range(x0, x0 + w):
		for y in range(y0, y0 + h):
			layer.set_cell(Vector2i(x, y), 0, atlas)


func _paint_ground_strip(x0: int, w: int, top_y: int, bottom_y: int = 23, stone: bool = false) -> void:
	for x in range(x0, x0 + w):
		if stone:
			var top_atlas := Vector2i(6, 0) if (x % 9 == 4) else Vector2i(2, 0)
			ground.set_cell(Vector2i(x, top_y), 0, top_atlas)
			for y in range(top_y + 1, bottom_y):
				ground.set_cell(Vector2i(x, y), 0, Vector2i(2, 0))
		else:
			var turf_atlas := Vector2i(4, 0) if ((x * 5) % 7 == 0) else Vector2i(0, 0)
			ground.set_cell(Vector2i(x, top_y), 0, turf_atlas)
			for y in range(top_y + 1, bottom_y):
				var dirt_atlas := Vector2i(5, 0) if (((x * 7 + y * 13) % 5) == 0) else Vector2i(1, 0)
				ground.set_cell(Vector2i(x, y), 0, dirt_atlas)


func _paint_one_way_ledge(x0: int, w: int, y: int) -> void:
	for x in range(x0, x0 + w):
		var plank := Vector2i(7, 0) if (x % 3 == 1) else Vector2i(3, 0)
		ground.set_cell(Vector2i(x, y), 0, plank)


func _place_lantern(tx: int, ty: int) -> void:
	back_decor.set_cell(Vector2i(tx, ty), 0, Vector2i(7, 1))
	var light := LANTERN_LIGHT_SCENE.instantiate() as PointLight2D
	if light:
		light.position = Vector2(tx * 64 + 44, ty * 64 + 34)
		add_child(light)
		_world_lanterns.append(light)


func _paint_foliage_row(xs: Array, y_func: Callable) -> void:
	for idx in xs.size():
		var tx: int = xs[idx]
		var ty: int = y_func.call(tx)
		var deco := Vector2i(1, 1) if (idx % 3 == 0) else (Vector2i(4, 1) if (idx % 3 == 1) else Vector2i(5, 1))
		front_decor.set_cell(Vector2i(tx, ty), 0, deco)


func _paint_hidden_covers() -> void:
	var hidden_root := get_node_or_null("HiddenPaths")
	if not hidden_root:
		return
	for hp in hidden_root.get_children():
		var cover := hp.get_node_or_null("TileMapLayer") as TileMapLayer
		if cover and cover.get_used_cells().is_empty():
			_fill_rect(cover, -2, -2, 5, 4, Vector2i(0, 1))


func _build_default_layout() -> void:
	match layout_id:
		"greybox":
			_paint_ground_strip(0, 48, 18)
			_paint_ground_strip(32, 3, 12, 18, true)
			_paint_one_way_ledge(12, 6, 16)
			_paint_one_way_ledge(21, 5, 14)
			_place_lantern(6, 17)
			_place_lantern(24, 17)
			_paint_hidden_covers()
		"level_1":
			# Max rise anywhere: 128 px (2 tiles)
			_paint_ground_strip(-1, 2, 0, 23, true)
			_paint_ground_strip(0, 20, 18)
			_paint_ground_strip(23, 16, 17)
			_paint_one_way_ledge(27, 6, 15)
			_paint_ground_strip(42, 18, 16)
			_paint_ground_strip(46, 8, 11, 13, true)
			_paint_ground_strip(60, 20, 14)
			_paint_ground_strip(79, 2, 0, 23, true)

			# Background stone ruin walls behind alcove & checkpoints
			_fill_rect(back_decor, 46, 13, 8, 3, Vector2i(6, 2))
			for px in [10, 34, 54, 70]:
				var py_bot := 18 if px < 22 else (17 if px < 40 else (16 if px < 60 else 14))
				_fill_rect(back_decor, px, py_bot - 7, 1, 7, Vector2i(3, 1))
				back_decor.set_cell(Vector2i(px, py_bot - 8), 0, Vector2i(6, 1))
			for vx in [8, 15, 25, 36, 44, 57, 64, 73]:
				back_decor.set_cell(Vector2i(vx, 3), 0, Vector2i(2, 1))
				back_decor.set_cell(Vector2i(vx, 4), 0, Vector2i(2, 1))

			# Warm atmospheric lanterns along trail
			_place_lantern(4, 17)
			_place_lantern(24, 16)
			_place_lantern(43, 15)
			_place_lantern(63, 13)
			_place_lantern(73, 13)

			# Rich foreground undergrowth, ferns, and glowing mushrooms
			_paint_foliage_row([2, 5, 7, 12, 14, 17, 24, 28, 31, 36, 44, 48, 56, 62, 66, 69, 72],
				func(mx: int) -> int:
					if mx < 22:
						return 17
					elif mx < 40:
						return 16
					elif mx < 60:
						return 15
					return 13
			)
			_paint_hidden_covers()
		"level_2":
			_paint_ground_strip(-1, 2, 0, 23, true)
			_paint_ground_strip(0, 14, 18, 23, true)
			_paint_one_way_ledge(15, 5, 16)
			_paint_ground_strip(21, 15, 18, 23, true)
			_paint_one_way_ledge(38, 6, 16)
			_paint_ground_strip(45, 12, 14, 16, true)
			_paint_ground_strip(39, 23, 19, 23, true)
			_paint_one_way_ledge(58, 4, 17)
			_paint_ground_strip(62, 18, 15, 23, true)
			_paint_ground_strip(79, 2, 0, 23, true)

			_fill_rect(back_decor, 45, 16, 12, 3, Vector2i(7, 2))
			for px in [6, 24, 48, 68]:
				_fill_rect(back_decor, px, 9, 1, 9, Vector2i(3, 1))
				back_decor.set_cell(Vector2i(px, 8), 0, Vector2i(6, 1))
			for vx in [10, 20, 32, 42, 52, 66, 74]:
				back_decor.set_cell(Vector2i(vx, 3), 0, Vector2i(2, 1))
			_place_lantern(3, 17)
			_place_lantern(22, 17)
			_place_lantern(46, 13)
			_place_lantern(64, 14)

			_paint_foliage_row([4, 11, 25, 29, 33, 46, 65, 71],
				func(mx: int) -> int:
					if mx < 38:
						return 17
					elif mx < 58:
						return 13
					return 14
			)
			_paint_hidden_covers()
		"level_3":
			_paint_ground_strip(0, 40, 19, 23, true)
			_paint_ground_strip(-1, 2, 0, 23, true)
			_paint_ground_strip(39, 2, 0, 23, true)
			_paint_one_way_ledge(8, 6, 17)
			_paint_one_way_ledge(3, 6, 15)
			_paint_one_way_ledge(26, 6, 17)
			_paint_one_way_ledge(31, 6, 15)
			_fill_rect(back_decor, 7, 9, 1, 10, Vector2i(3, 1))
			_fill_rect(back_decor, 32, 9, 1, 10, Vector2i(3, 1))
			back_decor.set_cell(Vector2i(7, 8), 0, Vector2i(6, 1))
			back_decor.set_cell(Vector2i(32, 8), 0, Vector2i(6, 1))
			back_decor.set_cell(Vector2i(19, 18), 0, Vector2i(6, 1))
			back_decor.set_cell(Vector2i(20, 18), 0, Vector2i(6, 1))
			_place_lantern(2, 18)
			_place_lantern(37, 18)
			front_decor.set_cell(Vector2i(18, 18), 0, Vector2i(1, 1))
			front_decor.set_cell(Vector2i(21, 18), 0, Vector2i(1, 1))
			front_decor.set_cell(Vector2i(12, 18), 0, Vector2i(4, 1))
			front_decor.set_cell(Vector2i(27, 18), 0, Vector2i(4, 1))
