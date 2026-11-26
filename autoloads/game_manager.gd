extends Node
## Global singleton managing health, score, crystals, Adventure Cycle NG+,
## 3D level progression (4 stages), audio settings, and game state.

signal health_changed(current: int, max_hp: int)
signal score_changed(new_score: int)
signal crystals_changed(collected: int)
signal boss_health_changed(current: int, max_hp: int, visible_bar: bool)
signal notification_posted(message: String, accent: Color)
signal dash_cooldown_changed(ready_ratio: float)
signal quality_changed(level: int)
signal game_over_triggered
signal victory_triggered

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu_3d.tscn"
const LEVELS: Array[String] = [
	"res://scenes/levels/level_1_3d.tscn",
	"res://scenes/levels/level_2_3d.tscn",
	"res://scenes/levels/level_3_boss_3d.tscn",
	"res://scenes/levels/level_4_astral_3d.tscn",
]

var max_health: int = 5
var health: int = 5
var score: int = 0
var crystals_collected: int = 0
var enemies_defeated: int = 0
var run_elapsed_seconds: float = 0.0
var current_level_index: int = 0
var adventure_cycle: int = 1
var is_game_ended: bool = false
var is_transitioning: bool = false
var is_run_active: bool = false
var mouse_sensitivity: float = 0.0028
var graphics_quality: int = 2 # 0=Balanced, 1=High, 2=Ultra


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if is_run_active and not is_game_ended and not is_transitioning and not get_tree().paused:
		run_elapsed_seconds += delta


func add_score(points: int) -> void:
	if is_game_ended:
		return
	score += points
	score_changed.emit(score)


func add_crystal(points: int = 10) -> void:
	if is_game_ended:
		return
	crystals_collected += 1
	crystals_changed.emit(crystals_collected)
	add_score(points)


func register_enemy_defeated() -> void:
	enemies_defeated += 1


func heal_player(amount: int) -> void:
	if is_game_ended or is_transitioning:
		return
	health = clampi(health + amount, 0, max_health)
	health_changed.emit(health, max_health)


func damage_player(amount: int) -> void:
	if is_game_ended or is_transitioning:
		return
	health = clampi(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0:
		is_game_ended = true
		game_over_triggered.emit()


func kill_player() -> void:
	if is_game_ended:
		return
	health = 0
	health_changed.emit(health, max_health)
	is_game_ended = true
	game_over_triggered.emit()


func next_level() -> void:
	if is_game_ended or is_transitioning:
		return
	if current_level_index + 1 < LEVELS.size():
		is_transitioning = true
		current_level_index += 1
		boss_health_changed.emit(0, 1, false)
		get_tree().call_deferred("change_scene_to_file", LEVELS[current_level_index])


func on_level_ready(level_idx: int = -1) -> void:
	is_transitioning = false
	is_run_active = true
	if level_idx >= 0:
		current_level_index = clampi(level_idx, 0, LEVELS.size() - 1)


func trigger_victory() -> void:
	if is_game_ended:
		return
	is_game_ended = true
	is_run_active = false
	victory_triggered.emit()


func start_next_adventure_cycle() -> void:
	## Opens New Adventure+ cycle carrying crystals & score forward into higher challenge.
	adventure_cycle += 1
	health = max_health
	current_level_index = 0
	is_game_ended = false
	is_transitioning = false
	is_run_active = true
	health_changed.emit(health, max_health)
	boss_health_changed.emit(0, 1, false)
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", LEVELS[0])
	call_deferred("_announce_cycle")


func _announce_cycle() -> void:
	notification_posted.emit("Adventure Cycle %d — The Forest Awaits!" % adventure_cycle, Color(1.0, 0.88, 0.4))


func start_level_by_index(idx: int) -> void:
	adventure_cycle = 1
	health = max_health
	score = 0
	crystals_collected = 0
	enemies_defeated = 0
	run_elapsed_seconds = 0.0
	current_level_index = clampi(idx, 0, LEVELS.size() - 1)
	is_game_ended = false
	is_transitioning = false
	is_run_active = true
	health_changed.emit(health, max_health)
	score_changed.emit(score)
	crystals_changed.emit(crystals_collected)
	boss_health_changed.emit(0, 1, false)
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", LEVELS[current_level_index])


func restart_current_level() -> void:
	health = max_health
	is_game_ended = false
	is_transitioning = false
	is_run_active = true
	health_changed.emit(health, max_health)
	boss_health_changed.emit(0, 1, false)
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", LEVELS[current_level_index])


func restart_game() -> void:
	start_level_by_index(0)


func go_to_main_menu() -> void:
	adventure_cycle = 1
	is_game_ended = false
	is_transitioning = false
	is_run_active = false
	boss_health_changed.emit(0, 1, false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)
