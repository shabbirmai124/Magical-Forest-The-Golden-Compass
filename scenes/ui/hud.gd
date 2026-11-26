extends CanvasLayer
## Persistent pause-proof HUD (Layer 10, Process Mode = ALWAYS).
## Features smoothly interpolated health/evade/boss bars, damage vignette shader,
## floating event toasts, slide-animated banners, pop-in Pause/End modals with fade transitions,
## and audio/sensitivity/quality controls.

@onready var screen_fade: ColorRect = $ScreenFade
@onready var damage_vignette: ColorRect = $DamageVignette
@onready var crosshair_dot: ColorRect = $CrosshairDot
@onready var toast_panel: PanelContainer = $ToastPanel
@onready var toast_label: Label = $ToastPanel/Margin/ToastLabel
@onready var health_bar: ProgressBar = $TopBar/HBoxContainer/HealthPanel/Margin/Row/VBox/HealthBar
@onready var dash_bar: ProgressBar = $TopBar/HBoxContainer/HealthPanel/Margin/Row/VBox/DashBar
@onready var health_value_label: Label = $TopBar/HBoxContainer/HealthPanel/Margin/Row/VBox/LabelRow/HealthValueLabel
@onready var crystal_label: Label = $TopBar/HBoxContainer/CrystalPanel/Margin/Row/CrystalLabel
@onready var level_label: Label = $TopBar/HBoxContainer/LevelPanel/Margin/LevelLabel
@onready var score_label: Label = $TopBar/HBoxContainer/ScorePanel/Margin/ScoreLabel
@onready var pause_button: Button = $TopBar/HBoxContainer/PauseButton
@onready var level_banner: PanelContainer = $LevelBanner
@onready var level_title_label: Label = $LevelBanner/Margin/VBox/LevelTitleLabel
@onready var hint_label: Label = $LevelBanner/Margin/VBox/HintLabel
@onready var boss_bar_box: PanelContainer = $BossBarBox
@onready var boss_name_label: Label = $BossBarBox/Margin/VBox/BossName
@onready var boss_bar: ProgressBar = $BossBarBox/Margin/VBox/BossBar
@onready var pause_panel: PanelContainer = $PausePanel
@onready var master_slider: HSlider = $PausePanel/Margin/VBox/MasterVolRow/MasterSlider
@onready var music_slider: HSlider = $PausePanel/Margin/VBox/MusicVolRow/MusicSlider
@onready var sfx_slider: HSlider = $PausePanel/Margin/VBox/SfxVolRow/SfxSlider
@onready var sens_slider: HSlider = $PausePanel/Margin/VBox/SensRow/SensSlider
@onready var quality_button: Button = $PausePanel/Margin/VBox/QualityButton
@onready var resume_button: Button = $PausePanel/Margin/VBox/ResumeButton
@onready var restart_level_button: Button = $PausePanel/Margin/VBox/RestartLevelButton
@onready var restart_run_button: Button = $PausePanel/Margin/VBox/RestartRunButton
@onready var main_menu_button: Button = $PausePanel/Margin/VBox/MainMenuButton
@onready var end_panel: PanelContainer = $EndPanel
@onready var result_label: Label = $EndPanel/MarginContainer/VBoxContainer/ResultLabel
@onready var final_score_label: Label = $EndPanel/MarginContainer/VBoxContainer/FinalScoreLabel
@onready var stats_label: Label = $EndPanel/MarginContainer/VBoxContainer/StatsLabel
@onready var retry_level_button: Button = $EndPanel/MarginContainer/VBoxContainer/RetryLevelButton
@onready var next_adventure_button: Button = $EndPanel/MarginContainer/VBoxContainer/NextAdventureButton
@onready var restart_button: Button = $EndPanel/MarginContainer/VBoxContainer/RestartButton
@onready var end_main_menu_button: Button = $EndPanel/MarginContainer/VBoxContainer/EndMainMenuButton

const QUALITY_NAMES: Array[String] = ["Balanced", "High", "Ultra"]

var _last_health: int = -1
var _last_score: int = -1
var _shake_tween: Tween
var _banner_tween: Tween
var _toast_tween: Tween
var _vig_tween: Tween
var _hp_tween: Tween
var _boss_hp_tween: Tween
var _scene_changing: bool = false
var _level_ctrl: Node = null


func _ready() -> void:
	add_to_group("hud")
	end_panel.visible = false
	pause_panel.visible = false
	boss_bar_box.visible = false
	level_banner.modulate.a = 0.0
	if toast_panel:
		toast_panel.modulate.a = 0.0
		toast_panel.visible = false

	_last_health = GameManager.health
	_last_score = GameManager.score
	_on_health_changed(GameManager.health, GameManager.max_health)
	_on_score_changed(GameManager.score)
	_on_crystals_changed(GameManager.crystals_collected)
	_on_dash_cooldown(1.0)
	_update_level_badge()

	GameManager.health_changed.connect(_on_health_changed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.crystals_changed.connect(_on_crystals_changed)
	GameManager.boss_health_changed.connect(_on_boss_health)
	GameManager.notification_posted.connect(_show_toast)
	GameManager.dash_cooldown_changed.connect(_on_dash_cooldown)
	GameManager.game_over_triggered.connect(_show_game_over)
	GameManager.victory_triggered.connect(_show_victory)

	pause_button.pressed.connect(_toggle_pause)
	resume_button.pressed.connect(_toggle_pause)
	restart_level_button.pressed.connect(func() -> void: _transition_to(GameManager.restart_current_level))
	restart_run_button.pressed.connect(func() -> void: _transition_to(GameManager.restart_game))
	main_menu_button.pressed.connect(func() -> void: _transition_to(GameManager.go_to_main_menu))
	retry_level_button.pressed.connect(func() -> void: _transition_to(GameManager.restart_current_level))
	next_adventure_button.pressed.connect(func() -> void: _transition_to(GameManager.start_next_adventure_cycle))
	restart_button.pressed.connect(func() -> void: _transition_to(GameManager.restart_game))
	end_main_menu_button.pressed.connect(func() -> void: _transition_to(GameManager.go_to_main_menu))

	for b in [pause_button, resume_button, restart_level_button, restart_run_button, main_menu_button, retry_level_button, next_adventure_button, restart_button, end_main_menu_button, quality_button]:
		_attach_hover(b)

	_sync_settings_ui()
	master_slider.value_changed.connect(func(v: float) -> void: _set_bus_linear("Master", v))
	music_slider.value_changed.connect(func(v: float) -> void: _set_bus_linear("Music", v))
	sfx_slider.value_changed.connect(func(v: float) -> void: _set_bus_linear("SFX", v))
	sens_slider.value_changed.connect(func(v: float) -> void: GameManager.mouse_sensitivity = v)
	quality_button.pressed.connect(_cycle_quality)

	screen_fade.color.a = 1.0
	create_tween().tween_property(screen_fade, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _attach_hover(btn: Button) -> void:
	if not btn:
		return
	btn.mouse_entered.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_BACK)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12)
	)


func _transition_to(action: Callable) -> void:
	if _scene_changing:
		return
	_scene_changing = true
	await fade_to_black(0.28)
	if is_inside_tree():
		action.call()


func _process(_delta: float) -> void:
	if crosshair_dot:
		crosshair_dot.visible = (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED) and not get_tree().paused and not GameManager.is_game_ended
	if not _level_ctrl or not is_instance_valid(_level_ctrl):
		_level_ctrl = get_tree().get_first_node_in_group("level_controller")
	if _level_ctrl and _level_ctrl.has_method("get_road_progress"):
		var prog: Dictionary = _level_ctrl.get_road_progress()
		var trav := int(round(float(prog.get("traveled", 0.0))))
		var tot := int(round(float(prog.get("total", 0.0))))
		if tot > 0:
			var goal_txt := "Forest Portal" if GameManager.current_level_index == 0 else ("Highland Gate" if GameManager.current_level_index == 1 else ("Sanctum Boss" if GameManager.current_level_index == 2 else "Cloud Summit"))
			var cyc_txt := " (Cycle %d)" % GameManager.adventure_cycle if GameManager.adventure_cycle > 1 else ""
			level_label.text = "Stage %d/%d — %s%s  •  %d / %d m" % [GameManager.current_level_index + 1, GameManager.LEVELS.size(), goal_txt, cyc_txt, trav, tot]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not GameManager.is_game_ended:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		_transition_to(GameManager.restart_game)


func _toggle_pause() -> void:
	if GameManager.is_game_ended or _scene_changing:
		return
	var next_paused := not get_tree().paused
	get_tree().paused = next_paused
	pause_panel.visible = next_paused
	if next_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_sync_settings_ui()
		pause_panel.pivot_offset = pause_panel.size * 0.5
		pause_panel.scale = Vector2(0.9, 0.9)
		pause_panel.modulate.a = 0.0
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		tw.tween_property(pause_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pause_panel, "modulate:a", 1.0, 0.18)
		resume_button.grab_focus()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _sync_settings_ui() -> void:
	master_slider.value = _get_bus_linear("Master")
	music_slider.value = _get_bus_linear("Music")
	sfx_slider.value = _get_bus_linear("SFX")
	sens_slider.value = GameManager.mouse_sensitivity
	quality_button.text = "Graphics Quality: %s" % QUALITY_NAMES[clampi(GameManager.graphics_quality, 0, QUALITY_NAMES.size() - 1)]


func _cycle_quality() -> void:
	GameManager.graphics_quality = (GameManager.graphics_quality + 1) % QUALITY_NAMES.size()
	quality_button.text = "Graphics Quality: %s" % QUALITY_NAMES[GameManager.graphics_quality]
	GameManager.quality_changed.emit(GameManager.graphics_quality)


func _get_bus_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func _set_bus_linear(bus_name: String, linear_val: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear_val <= 0.01)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear_val, 0.001)))


func _update_level_badge() -> void:
	var goal_txt := "Portal" if GameManager.current_level_index < 2 else ("Astral Portal" if GameManager.current_level_index == 2 else "Crown Sanctum")
	var cyc_txt := " (Cycle %d)" % GameManager.adventure_cycle if GameManager.adventure_cycle > 1 else ""
	level_label.text = "Stage %d/%d — %s%s" % [GameManager.current_level_index + 1, GameManager.LEVELS.size(), goal_txt, cyc_txt]


func show_level_banner(title_text: String, show_hint: bool) -> void:
	level_title_label.text = title_text
	hint_label.visible = show_hint
	_update_level_badge()
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	level_banner.modulate.a = 0.0
	level_banner.offset_top = 112.0
	_banner_tween = create_tween()
	var enter_tw := _banner_tween.parallel()
	enter_tw.tween_property(level_banner, "modulate:a", 1.0, 0.4)
	enter_tw.tween_property(level_banner, "offset_top", 136.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(2.8)
	var exit_tw := _banner_tween.parallel()
	exit_tw.tween_property(level_banner, "modulate:a", 0.0, 0.65)
	exit_tw.tween_property(level_banner, "offset_top", 118.0, 0.65)


func _show_toast(msg: String, accent: Color) -> void:
	if not toast_panel or not toast_label:
		return
	toast_label.text = msg
	toast_label.modulate = accent
	toast_panel.visible = true
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_panel.modulate.a = 0.0
	toast_panel.offset_top = 268.0
	_toast_tween = create_tween()
	var tin := _toast_tween.parallel()
	tin.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	tin.tween_property(toast_panel, "offset_top", 285.0, 0.28).set_trans(Tween.TRANS_BACK)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.55)
	_toast_tween.tween_callback(func() -> void: toast_panel.visible = false)


func fade_to_black(duration: float = 0.35) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(screen_fade, "color:a", 1.0, duration).set_trans(Tween.TRANS_QUAD)
	await tw.finished


func _on_dash_cooldown(ratio: float) -> void:
	if dash_bar:
		dash_bar.value = clampf(ratio, 0.0, 1.0)
		dash_bar.modulate = Color(1.15, 1.15, 1.15, 1.0) if ratio >= 0.99 else Color(0.75, 0.85, 0.92, 0.85)


func _on_health_changed(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	if _hp_tween and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(health_bar, "value", float(current), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	health_value_label.text = "%d / %d" % [current, max_hp]
	if current <= 1:
		health_bar.modulate = Color(1.0, 0.42, 0.42, 1.0)
	elif current <= 2:
		health_bar.modulate = Color(1.0, 0.8, 0.36, 1.0)
	else:
		health_bar.modulate = Color.WHITE
	if current < _last_health:
		_shake_health()
		_flash_vignette(0.82 if current > 1 else 0.95)
	elif damage_vignette and damage_vignette.material is ShaderMaterial:
		var base_vig := 0.35 if current <= 1 else 0.0
		(damage_vignette.material as ShaderMaterial).set_shader_parameter("intensity", base_vig)
	_last_health = current


func _flash_vignette(peak: float) -> void:
	if not damage_vignette or not (damage_vignette.material is ShaderMaterial):
		return
	var mat := damage_vignette.material as ShaderMaterial
	if _vig_tween and _vig_tween.is_valid():
		_vig_tween.kill()
	var end_val := 0.35 if GameManager.health <= 1 else 0.0
	_vig_tween = create_tween()
	_vig_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), peak, end_val, 0.45)


func _on_crystals_changed(collected: int) -> void:
	crystal_label.text = str(collected)
	_pop_control(crystal_label)


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score
	if new_score > _last_score:
		_pop_control(score_label)
	_last_score = new_score


func _on_boss_health(current: int, max_hp: int, is_vis: bool) -> void:
	boss_bar_box.visible = is_vis
	boss_bar.max_value = max_hp
	if _boss_hp_tween and _boss_hp_tween.is_valid():
		_boss_hp_tween.kill()
	_boss_hp_tween = create_tween()
	_boss_hp_tween.tween_property(boss_bar, "value", float(current), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if current <= max_hp / 2 and current > 0:
		boss_name_label.text = "FOREST GUARDIAN — AWAKENED"
		boss_name_label.modulate = Color(1.0, 0.55, 0.42, 1.0)
	else:
		boss_name_label.text = "FOREST GUARDIAN"
		boss_name_label.modulate = Color.WHITE


func _format_stats() -> String:
	var secs := int(GameManager.run_elapsed_seconds)
	var mins := secs / 60
	var rem := secs % 60
	return "Crystals: %d   |   Foes Vanquished: %d   |   Time: %02d:%02d" % [
		GameManager.crystals_collected,
		GameManager.enemies_defeated,
		mins,
		rem,
	]


func _pop_end_modal() -> void:
	end_panel.visible = true
	end_panel.pivot_offset = end_panel.size * 0.5
	end_panel.scale = Vector2(0.88, 0.88)
	end_panel.modulate.a = 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(end_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(end_panel, "modulate:a", 1.0, 0.24)


func _show_game_over() -> void:
	pause_panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	result_label.text = "Defeated in the Forest"
	result_label.modulate = Color(1.0, 0.55, 0.55, 1.0)
	final_score_label.text = "Final Score: %d" % GameManager.score
	stats_label.text = _format_stats()
	retry_level_button.visible = true
	next_adventure_button.visible = false
	_pop_end_modal()
	get_tree().paused = true
	retry_level_button.grab_focus()


func _show_victory() -> void:
	pause_panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	result_label.text = "Astral Crown & Compass Mastered!"
	result_label.modulate = Color(1.0, 0.88, 0.4, 1.0)
	final_score_label.text = "Final Score: %d  (Adventure Cycle %d)" % [GameManager.score, GameManager.adventure_cycle]
	stats_label.text = _format_stats()
	retry_level_button.visible = false
	next_adventure_button.visible = true
	next_adventure_button.text = "Enter Next Adventure Portal (Cycle %d)" % (GameManager.adventure_cycle + 1)
	_pop_end_modal()
	get_tree().paused = true
	next_adventure_button.grab_focus()


func _shake_health() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	health_bar.position = Vector2.ZERO
	_shake_tween = create_tween()
	_shake_tween.tween_property(health_bar, "position", Vector2(-6, 2), 0.04)
	_shake_tween.tween_property(health_bar, "position", Vector2(6, -2), 0.04)
	_shake_tween.tween_property(health_bar, "position", Vector2.ZERO, 0.04)


func _pop_control(ctrl: Control) -> void:
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := create_tween()
	tw.tween_property(ctrl, "scale", Vector2(1.18, 1.18), 0.07)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.12)
