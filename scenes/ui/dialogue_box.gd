extends Control
## RPG Story Dialogue Box with typewriter reveal, speaker name & role badge,
## and [E / Space / Left Click] advance control.

const TITLE_FONT: Font = preload("res://resources/fonts/title_font.tres")
const UI_FONT: Font = preload("res://resources/fonts/ui_font.tres")

var _panel: PanelContainer = null
var _speaker_lbl: Label = null
var _role_lbl: Label = null
var _body_lbl: Label = null
var _prompt_lbl: Label = null

var _lines: Array[String] = []
var _line_index: int = 0
var _full_text: String = ""
var _shown_chars: float = 0.0
var _is_typing: bool = false
var _is_active: bool = false
var _on_finish: Callable = Callable()
var _tick_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	visible = false
	GameManager.dialogue_requested.connect(_on_dialogue_requested)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -390.0
	_panel.offset_right = 390.0
	_panel.offset_top = -225.0
	_panel.offset_bottom = -42.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.06, 0.095, 0.94)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.9, 0.74, 0.34, 0.95)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 14.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	_speaker_lbl = Label.new()
	_speaker_lbl.add_theme_font_override("font", TITLE_FONT)
	_speaker_lbl.add_theme_font_size_override("font_size", 22)
	_speaker_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	header.add_child(_speaker_lbl)

	_role_lbl = Label.new()
	_role_lbl.add_theme_font_override("font", UI_FONT)
	_role_lbl.add_theme_font_size_override("font_size", 14)
	_role_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 0.82))
	_role_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header.add_child(_role_lbl)

	var sep: HSeparator = HSeparator.new()
	sep.modulate = Color(0.88, 0.72, 0.34, 0.45)
	vbox.add_child(sep)

	_body_lbl = Label.new()
	_body_lbl.add_theme_font_override("font", UI_FONT)
	_body_lbl.add_theme_font_size_override("font_size", 17)
	_body_lbl.add_theme_color_override("font_color", Color(0.93, 0.96, 0.95))
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_body_lbl)

	_prompt_lbl = Label.new()
	_prompt_lbl.add_theme_font_override("font", UI_FONT)
	_prompt_lbl.add_theme_font_size_override("font_size", 13)
	_prompt_lbl.add_theme_color_override("font_color", Color(0.94, 0.82, 0.45))
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_lbl.text = "[E / Space / Click] Continue"
	vbox.add_child(_prompt_lbl)


func _on_dialogue_requested(speaker: String, role: String, lines: Array, on_finish: Callable) -> void:
	_lines.clear()
	for l_var in lines:
		_lines.append(String(l_var))
	if _lines.is_empty():
		if on_finish.is_valid():
			on_finish.call()
		return

	_speaker_lbl.text = speaker
	_role_lbl.text = ("— " + role) if not role.is_empty() else ""
	_on_finish = on_finish
	_line_index = 0
	_is_active = true
	visible = true
	GameManager.is_dialogue_open = true
	GameManager.set_ui_mouse()
	_show_current_line()


func _show_current_line() -> void:
	_full_text = _lines[_line_index]
	_shown_chars = 0.0
	_is_typing = true
	_body_lbl.text = ""
	var is_last: bool = (_line_index >= _lines.size() - 1)
	_prompt_lbl.text = "[E / Space / Click] Finish" if is_last else "[E / Space / Click] Next (%d/%d)" % [_line_index + 1, _lines.size()]


func _process(delta: float) -> void:
	if not _is_active or not _is_typing:
		return
	_shown_chars += delta * 46.0
	var count: int = mini(int(_shown_chars), _full_text.length())
	_body_lbl.text = _full_text.substr(0, count)
	_tick_accum += delta
	if _tick_accum >= 0.075:
		_tick_accum = 0.0
		if AudioManager:
			AudioManager.play_sfx("dialogue_blip", 0.94, 1.08, -12.0)
	if count >= _full_text.length():
		_is_typing = false


func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	var advance: bool = false
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		advance = true
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			advance = true

	if advance:
		get_viewport().set_input_as_handled()
		if _is_typing:
			_is_typing = false
			_body_lbl.text = _full_text
		else:
			if AudioManager:
				AudioManager.play_sfx("ui_click")
			_line_index += 1
			if _line_index < _lines.size():
				_show_current_line()
			else:
				_close_dialogue()


func _close_dialogue() -> void:
	_is_active = false
	visible = false
	GameManager.is_dialogue_open = false
	GameManager.set_gameplay_mouse()
	var cb: Callable = _on_finish
	_on_finish = Callable()
	if cb.is_valid():
		cb.call()
