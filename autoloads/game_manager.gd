extends Node
## Global singleton managing persisted Explorer stats, progression, stage loading,
## Wayshrine checkpoints, upgrades, and safe mouse-capture state across all 4 stages.

signal vitality_changed(current: int, max_hp: int)
signal health_changed(current: int, max_hp: int)
signal compass_energy_changed(current: float, max_energy: float)
signal herbs_changed(count: int)
signal shards_changed(collected: int)
signal crystals_changed(collected: int)
signal chests_changed(opened: int)
signal score_changed(new_score: int)
signal boss_health_changed(current: int, max_hp: int, visible_bar: bool, boss_name: String, phase_label: String)
signal notification_posted(message: String, accent: Color)
signal toast_posted(title: String, subtitle: String, accent: Color)
signal dash_cooldown_changed(ready_ratio: float)
signal compass_pulse_cooldown_changed(ready_ratio: float)
signal compass_updated(relative_angle_rad: float, distance_m: float, target_label: String)
signal interact_prompt_changed(visible_prompt: bool, prompt_text: String)
signal dialogue_requested(speaker: String, role: String, lines: Array, on_finish: Callable)
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
const STAGE_NAMES: Array[String] = [
	"Stage 1 — Whispering Moss Woods",
	"Stage 2 — Thornhollow Ancient Ruins",
	"Stage 3 — Heart of the Grove",
	"Stage 4 — Astral Canopy Sanctuary",
]

# Persisted Explorer RPG stats
var max_vitality: int = 5
var vitality: int = 5
var attack_damage: int = 18
var compass_energy: float = 100.0
var max_compass_energy: float = 100.0
var healing_herbs: int = 2
var shards_total: int = 0
var chests_opened: int = 0
var enemies_defeated: int = 0
var score: int = 0
var elapsed_time: float = 0.0
var current_stage_index: int = 0 # 0..3 corresponding to Stages 1..4
var adventure_cycle: int = 1

# Checkpoint state (reset on new stage)
var checkpoint_position: Vector3 = Vector3(0.0, 0.5, 0.0)
var has_checkpoint: bool = false

# Runtime flags
var is_game_ended: bool = false
var is_transitioning: bool = false
var is_run_active: bool = false
var is_dialogue_open: bool = false
var is_journal_open: bool = false
var mouse_sensitivity: float = 0.0028
var graphics_quality: int = 2

# Backwards-compatible property bridges
var max_health: int:
	get:
		return max_vitality
	set(v):
		max_vitality = clampi(v, 1, 9)

var health: int:
	get:
		return vitality
	set(v):
		vitality = clampi(v, 0, max_vitality)

var crystals_collected: int:
	get:
		return shards_total
	set(v):
		shards_total = maxi(v, 0)

var current_level_index: int:
	get:
		return current_stage_index
	set(v):
		current_stage_index = clampi(v, 0, LEVELS.size() - 1)

var run_elapsed_seconds: float:
	get:
		return elapsed_time
	set(v):
		elapsed_time = maxf(v, 0.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if is_run_active and not is_game_ended and not is_transitioning and not get_tree().paused and not is_dialogue_open and not is_journal_open:
		elapsed_time += delta


func set_gameplay_mouse() -> void:
	if not get_tree().paused and not is_dialogue_open and not is_journal_open and not is_game_ended:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func set_ui_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func emit_all_stats() -> void:
	vitality_changed.emit(vitality, max_vitality)
	health_changed.emit(vitality, max_vitality)
	compass_energy_changed.emit(compass_energy, max_compass_energy)
	herbs_changed.emit(healing_herbs)
	shards_changed.emit(shards_total)
	crystals_changed.emit(shards_total)
	chests_changed.emit(chests_opened)
	score_changed.emit(score)


func post_toast(title: String, subtitle: String = "", accent: Color = Color(1.0, 0.88, 0.42)) -> void:
	toast_posted.emit(title, subtitle, accent)
	var combined: String = title if subtitle.is_empty() else "%s — %s" % [title, subtitle]
	notification_posted.emit(combined, accent)


func add_score(points: int) -> void:
	if is_game_ended:
		return
	score += points
	score_changed.emit(score)


func add_shard(points: int = 50) -> void:
	if is_game_ended:
		return
	shards_total += 1
	shards_changed.emit(shards_total)
	crystals_changed.emit(shards_total)
	add_score(points)


func add_crystal(points: int = 50) -> void:
	add_shard(points)


func register_chest_opened(bonus_score: int = 100) -> void:
	chests_opened += 1
	chests_changed.emit(chests_opened)
	add_herbs(1)
	add_score(bonus_score)


func add_herbs(amount: int) -> void:
	healing_herbs = clampi(healing_herbs + amount, 0, 9)
	herbs_changed.emit(healing_herbs)


func use_healing_herb() -> bool:
	if is_game_ended or healing_herbs <= 0 or vitality >= max_vitality:
		return false
	healing_herbs -= 1
	herbs_changed.emit(healing_herbs)
	heal_player(2)
	return true


func upgrade_max_vitality(amount: int = 1) -> void:
	max_vitality = clampi(max_vitality + amount, 5, 9)
	vitality = clampi(vitality + amount, 0, max_vitality)
	vitality_changed.emit(vitality, max_vitality)
	health_changed.emit(vitality, max_vitality)


func upgrade_attack_damage(amount: int = 6) -> void:
	attack_damage += amount


func modify_compass_energy(delta_e: float) -> void:
	var prev: float = compass_energy
	compass_energy = clampf(compass_energy + delta_e, 0.0, max_compass_energy)
	if absf(compass_energy - prev) > 0.05:
		compass_energy_changed.emit(compass_energy, max_compass_energy)


func consume_compass_energy(cost: float) -> bool:
	if compass_energy < cost:
		return false
	compass_energy = clampf(compass_energy - cost, 0.0, max_compass_energy)
	compass_energy_changed.emit(compass_energy, max_compass_energy)
	return true


func register_enemy_defeated(bonus_score: int = 75) -> void:
	enemies_defeated += 1
	add_score(bonus_score)


func heal_player(amount: int) -> void:
	if is_game_ended or is_transitioning:
		return
	vitality = clampi(vitality + amount, 0, max_vitality)
	vitality_changed.emit(vitality, max_vitality)
	health_changed.emit(vitality, max_vitality)


func full_restore() -> void:
	vitality = max_vitality
	compass_energy = max_compass_energy
	vitality_changed.emit(vitality, max_vitality)
	health_changed.emit(vitality, max_vitality)
	compass_energy_changed.emit(compass_energy, max_compass_energy)


func damage_player(amount: int) -> void:
	if is_game_ended or is_transitioning:
		return
	vitality = clampi(vitality - amount, 0, max_vitality)
	vitality_changed.emit(vitality, max_vitality)
	health_changed.emit(vitality, max_vitality)
	if vitality <= 0:
		is_game_ended = true
		set_ui_mouse()
		game_over_triggered.emit()


func kill_player() -> void:
	damage_player(max_vitality + 10)


func set_checkpoint(pos: Vector3) -> void:
	checkpoint_position = pos
	has_checkpoint = true


func respawn_at_checkpoint() -> void:
	is_game_ended = false
	is_dialogue_open = false
	is_journal_open = false
	get_tree().paused = false
	full_restore()
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player and is_instance_valid(player):
		player.global_position = checkpoint_position + Vector3(0.0, 0.5, 0.0)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		set_gameplay_mouse()
		post_toast("REVIVED AT WAYSHRINE", "Vitality and Compass Energy restored", Color(0.55, 0.96, 0.85))
	else:
		restart_current_level()


func on_level_ready(stage_idx: int = 0, default_spawn: Vector3 = Vector3(0.0, 0.5, 0.0)) -> void:
	is_transitioning = false
	is_game_ended = false
	is_dialogue_open = false
	is_journal_open = false
	is_run_active = true
	current_stage_index = clampi(stage_idx, 0, LEVELS.size() - 1)
	checkpoint_position = default_spawn
	has_checkpoint = false
	boss_health_changed.emit(0, 1, false, "", "")
	interact_prompt_changed.emit(false, "")
	emit_all_stats()
	if QuestManager:
		QuestManager.setup_stage_quests(current_stage_index + 1)


func load_stage(stage_index_zero_based: int) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	is_game_ended = false
	is_dialogue_open = false
	is_journal_open = false
	current_stage_index = clampi(stage_index_zero_based, 0, LEVELS.size() - 1)
	boss_health_changed.emit(0, 1, false, "", "")
	interact_prompt_changed.emit(false, "")
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", LEVELS[current_stage_index])


func next_level() -> void:
	if is_game_ended or is_transitioning:
		return
	if current_stage_index + 1 < LEVELS.size():
		load_stage(current_stage_index + 1)
	else:
		trigger_victory()


func trigger_victory() -> void:
	if is_game_ended:
		return
	is_game_ended = true
	is_run_active = false
	set_ui_mouse()
	if AudioManager:
		AudioManager.play_sfx("victory_fanfare")
	victory_triggered.emit()


func reset_new_game(start_stage_idx: int = 0) -> void:
	adventure_cycle = 1
	max_vitality = 5
	vitality = 5
	attack_damage = 18
	compass_energy = 100.0
	healing_herbs = 2
	shards_total = 0
	chests_opened = 0
	enemies_defeated = 0
	score = 0
	elapsed_time = 0.0
	has_checkpoint = false
	is_game_ended = false
	is_transitioning = false
	is_dialogue_open = false
	is_journal_open = false
	is_run_active = true
	if QuestManager:
		QuestManager.reset_all_quests()
	emit_all_stats()
	load_stage(start_stage_idx)


func start_level_by_index(idx: int) -> void:
	reset_new_game(idx)


func restart_current_level() -> void:
	vitality = max_vitality
	compass_energy = max_compass_energy
	is_game_ended = false
	is_transitioning = false
	is_dialogue_open = false
	is_journal_open = false
	if QuestManager:
		QuestManager.reset_stage_quests(current_stage_index + 1)
	emit_all_stats()
	load_stage(current_stage_index)


func start_next_adventure_cycle() -> void:
	adventure_cycle += 1
	vitality = max_vitality
	compass_energy = max_compass_energy
	is_game_ended = false
	is_transitioning = false
	if QuestManager:
		QuestManager.reset_all_quests()
	emit_all_stats()
	load_stage(0)


func restart_game() -> void:
	reset_new_game(0)


func go_to_main_menu() -> void:
	is_game_ended = false
	is_transitioning = false
	is_dialogue_open = false
	is_journal_open = false
	is_run_active = false
	boss_health_changed.emit(0, 1, false, "", "")
	interact_prompt_changed.emit(false, "")
	set_ui_mouse()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)
