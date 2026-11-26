extends Control
## Atmospheric Title Screen for The Lost Golden Compass.

@onready var compass_icon: TextureRect = $CenterContainer/MenuCard/Margin/VBox/CompassIcon
@onready var play_button: Button = $CenterContainer/MenuCard/Margin/VBox/PlayButton
@onready var chapters_button: Button = $CenterContainer/MenuCard/Margin/VBox/ChaptersButton
@onready var chapters_box: HBoxContainer = $CenterContainer/MenuCard/Margin/VBox/ChaptersBox
@onready var lvl1_btn: Button = $CenterContainer/MenuCard/Margin/VBox/ChaptersBox/Lvl1Btn
@onready var lvl2_btn: Button = $CenterContainer/MenuCard/Margin/VBox/ChaptersBox/Lvl2Btn
@onready var lvl3_btn: Button = $CenterContainer/MenuCard/Margin/VBox/ChaptersBox/Lvl3Btn
@onready var controls_button: Button = $CenterContainer/MenuCard/Margin/VBox/ControlsButton
@onready var controls_info: Label = $CenterContainer/MenuCard/Margin/VBox/ControlsInfo
@onready var quit_button: Button = $CenterContainer/MenuCard/Margin/VBox/QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = $AmbiencePlayer


func _ready() -> void:
	get_tree().paused = false
	play_button.grab_focus()

	play_button.pressed.connect(func() -> void: GameManager.start_level_by_index(0))
	chapters_button.pressed.connect(func() -> void: chapters_box.visible = not chapters_box.visible)
	lvl1_btn.pressed.connect(func() -> void: GameManager.start_level_by_index(0))
	lvl2_btn.pressed.connect(func() -> void: GameManager.start_level_by_index(1))
	lvl3_btn.pressed.connect(func() -> void: GameManager.start_level_by_index(2))
	controls_button.pressed.connect(func() -> void: controls_info.visible = not controls_info.visible)
	quit_button.pressed.connect(func() -> void: get_tree().quit())

	if OS.has_feature("web"):
		quit_button.visible = false

	_loop_audio(music_player)
	_loop_audio(ambience_player)

	if compass_icon:
		compass_icon.pivot_offset = compass_icon.size * 0.5
		var tw := create_tween().set_loops()
		tw.tween_property(compass_icon, "modulate", Color(1.25, 1.15, 0.9, 1.0), 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(compass_icon, "modulate", Color(0.95, 0.95, 0.95, 1.0), 1.4).set_trans(Tween.TRANS_SINE)


func _loop_audio(ap: AudioStreamPlayer) -> void:
	if ap and ap.stream:
		ap.finished.connect(ap.play)
		if not ap.playing:
			ap.play()
