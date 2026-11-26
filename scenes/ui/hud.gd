extends CanvasLayer
## Complete Fantasy RPG HUD — Vitality, Compass Energy, Healing Herbs, Sunlit Shards,
## Live Golden Compass Bar (with rotating directional arrow & integer meters, NEVER "--m"),
## Animated Stage Banner & Toast Notifications, Boss Health & Phase Bar, Live Quest Tracker,
## Floating [E] Interact Prompt, DialogueBox, Quest Journal [Q/Tab], Pause Menu [Esc],
## Game Over Screen, and Victory & Credits Summary.

const TITLE_FONT: Font = preload("res://resources/fonts/title_font.tres")
const UI_FONT: Font = preload("res://resources/fonts/ui_font.tres")
const DIALOGUE_SCRIPT = preload("res://scenes/ui/dialogue_box.gd")

@onready var damage_vignette: ColorRect = $DamageVignette

var _root: Control = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _energy_bar: ProgressBar = null
var _energy_label: Label = null
var _dash_bar: ProgressBar = null
var _herbs_lbl: Label = null
var _shards_lbl: Label = null

var _compass_target_lbl: Label = null
var _compass_dist_lbl: Label = null
var _compass_arrow_pivot: Control = null
var _compass_cd_bar: ProgressBar = null

var _stage_lbl: Label = null
var _score_lbl: Label = null
var _quest_list_box: VBoxContainer = null

var _boss_panel: PanelContainer = null
var _boss_name_lbl: Label = null
var _boss_phase_lbl: Label = null
var _boss_bar: ProgressBar = null

var _stage_banner: PanelContainer = null
var _stage_banner_lbl: Label = null
var _toast_panel: PanelContainer = null
var _toast_title_lbl: Label = null
var _toast_sub_lbl: Label = null
var _toast_tween: Tween = null

var _interact_panel: PanelContainer = null
var _interact_lbl: Label = null

var _journal_overlay: Control = null
var _journal_content: VBoxContainer = null
var _pause_overlay: Control = null
var _gameover_overlay: Control = null
var _victory_overlay: Control = null
var _victory_stats_lbl: Label = null
var _vignette_tween: Tween = null


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud_tree()
	_connect_signals()
	_refresh_all()


func _make_box(bg: Color, border: Color, radius: int = 10, pad_h: float = 14.0, pad_v: float = 10.0) -> StyleBoxFlat:
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
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	sb.shadow_size = 8
	return sb


func _make_button(label_text: String, accent_bg: Color = Color(0.11, 0.3, 0.24, 0.96), border_col: Color = Color(0.88, 0.72, 0.34, 0.92)) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.add_theme_font_override("font", UI_FONT)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.74))
	btn.add_theme_stylebox_override("normal", _make_box(accent_bg, border_col, 8, 16.0, 9.0))
	btn.add_theme_stylebox_override("hover", _make_box(accent_bg.lightened(0.16), Color(1.0, 0.88, 0.48), 8, 16.0, 9.0))
	btn.add_theme_stylebox_override("pressed", _make_box(accent_bg.darkened(0.14), border_col, 8, 16.0, 9.0))
	return btn


func _make_progress(fill_col: Color, h: float = 14.0) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180.0, h)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	bg.corner_radius_top_left = 5
	bg.corner_radius_top_right = 5
	bg.corner_radius_bottom_right = 5
	bg.corner_radius_bottom_left = 5
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.corner_radius_top_left = 4
	fg.corner_radius_top_right = 4
	fg.corner_radius_bottom_right = 4
	fg.corner_radius_bottom_left = 4
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _build_hud_tree() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dark_bg: Color = Color(0.035, 0.06, 0.095, 0.88)
	var teal_border: Color = Color(0.32, 0.68, 0.58, 0.88)
	var gold_border: Color = Color(0.88, 0.72, 0.34, 0.92)

	# --- TOP-LEFT: VITALS, COMPASS ENERGY, HERBS & SHARDS ---
	var tl_panel: PanelContainer = PanelContainer.new()
	tl_panel.position = Vector2(18.0, 16.0)
	tl_panel.add_theme_stylebox_override("panel", _make_box(dark_bg, teal_border, 12, 14.0, 10.0))
	_root.add_child(tl_panel)

	var tl_v: VBoxContainer = VBoxContainer.new()
	tl_v.add_theme_constant_override("separation", 6)
	tl_panel.add_child(tl_v)

	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	tl_v.add_child(hp_row)
	var hp_t: Label = Label.new()
	hp_t.text = "VITALITY"
	hp_t.add_theme_font_override("font", UI_FONT)
	hp_t.add_theme_font_size_override("font_size", 12)
	hp_t.add_theme_color_override("font_color", Color(0.68, 0.94, 0.8))
	hp_row.add_child(hp_t)
	_hp_label = Label.new()
	_hp_label.text = "5 / 5"
	_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.add_theme_font_override("font", UI_FONT)
	_hp_label.add_theme_font_size_override("font_size", 13)
	hp_row.add_child(_hp_label)

	_hp_bar = _make_progress(Color(0.24, 0.84, 0.5), 14.0)
	_hp_bar.custom_minimum_size = Vector2(215.0, 14.0)
	tl_v.add_child(_hp_bar)

	var en_row: HBoxContainer = HBoxContainer.new()
	tl_v.add_child(en_row)
	var en_t: Label = Label.new()
	en_t.text = "COMPASS ENERGY"
	en_t.add_theme_font_override("font", UI_FONT)
	en_t.add_theme_font_size_override("font_size", 11)
	en_t.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	en_row.add_child(en_t)
	_energy_label = Label.new()
	_energy_label.text = "100 / 100"
	_energy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_energy_label.add_theme_font_override("font", UI_FONT)
	_energy_label.add_theme_font_size_override("font_size", 12)
	en_row.add_child(_energy_label)

	_energy_bar = _make_progress(Color(0.95, 0.78, 0.28), 10.0)
	_energy_bar.custom_minimum_size = Vector2(215.0, 10.0)
	tl_v.add_child(_energy_bar)

	_dash_bar = _make_progress(Color(0.32, 0.88, 0.96), 5.0)
	_dash_bar.custom_minimum_size = Vector2(215.0, 5.0)
	_dash_bar.max_value = 1.0
	_dash_bar.value = 1.0
	tl_v.add_child(_dash_bar)

	var items_row: HBoxContainer = HBoxContainer.new()
	items_row.add_theme_constant_override("separation", 16)
	tl_v.add_child(items_row)
	_herbs_lbl = Label.new()
	_herbs_lbl.text = "Herbs [H]: 2"
	_herbs_lbl.add_theme_font_override("font", UI_FONT)
	_herbs_lbl.add_theme_font_size_override("font_size", 13)
	_herbs_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.62))
	items_row.add_child(_herbs_lbl)

	_shards_lbl = Label.new()
	_shards_lbl.text = "Shards: 0"
	_shards_lbl.add_theme_font_override("font", UI_FONT)
	_shards_lbl.add_theme_font_size_override("font_size", 13)
	_shards_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	items_row.add_child(_shards_lbl)

	# --- TOP-CENTER: GOLDEN COMPASS BAR ---
	var comp_panel: PanelContainer = PanelContainer.new()
	comp_panel.anchor_left = 0.5
	comp_panel.anchor_right = 0.5
	comp_panel.offset_left = -190.0
	comp_panel.offset_right = 190.0
	comp_panel.offset_top = 14.0
	comp_panel.offset_bottom = 86.0
	comp_panel.add_theme_stylebox_override("panel", _make_box(dark_bg, gold_border, 14, 16.0, 8.0))
	_root.add_child(comp_panel)

	var comp_h: HBoxContainer = HBoxContainer.new()
	comp_h.add_theme_constant_override("separation", 14)
	comp_panel.add_child(comp_h)

	# Rotating Golden Compass Arrow Widget
	var dial_holder: Control = Control.new()
	dial_holder.custom_minimum_size = Vector2(44.0, 44.0)
	comp_h.add_child(dial_holder)

	var dial_ring: Panel = Panel.new()
	dial_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	dial_ring.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.12, 0.16, 0.95), gold_border, 22, 0.0, 0.0))
	dial_holder.add_child(dial_ring)

	_compass_arrow_pivot = Control.new()
	_compass_arrow_pivot.position = Vector2(22.0, 22.0)
	dial_holder.add_child(_compass_arrow_pivot)

	var arrow_poly: Polygon2D = Polygon2D.new()
	arrow_poly.polygon = PackedVector2Array([Vector2(0, -15), Vector2(7, 8), Vector2(0, 3), Vector2(-7, 8)])
	arrow_poly.color = Color(1.0, 0.88, 0.34)
	_compass_arrow_pivot.add_child(arrow_poly)

	var comp_v: VBoxContainer = VBoxContainer.new()
	comp_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comp_v.add_theme_constant_override("separation", 4)
	comp_h.add_child(comp_v)

	var comp_top: HBoxContainer = HBoxContainer.new()
	comp_v.add_child(comp_top)
	_compass_target_lbl = Label.new()
	_compass_target_lbl.text = "Elder Sylvan"
	_compass_target_lbl.add_theme_font_override("font", TITLE_FONT)
	_compass_target_lbl.add_theme_font_size_override("font_size", 16)
	_compass_target_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
	comp_top.add_child(_compass_target_lbl)

	_compass_dist_lbl = Label.new()
	_compass_dist_lbl.text = "14 m"
	_compass_dist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compass_dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_compass_dist_lbl.add_theme_font_override("font", UI_FONT)
	_compass_dist_lbl.add_theme_font_size_override("font_size", 15)
	_compass_dist_lbl.add_theme_color_override("font_color", Color(0.62, 0.98, 0.88))
	comp_top.add_child(_compass_dist_lbl)

	var comp_sub: Label = Label.new()
	comp_sub.text = "Golden Compass Pulse [G] — Trail & Secret Reveal"
	comp_sub.add_theme_font_override("font", UI_FONT)
	comp_sub.add_theme_font_size_override("font_size", 11)
	comp_sub.add_theme_color_override("font_color", Color(0.76, 0.84, 0.82))
	comp_v.add_child(comp_sub)

	_compass_cd_bar = _make_progress(Color(1.0, 0.84, 0.32), 5.0)
	_compass_cd_bar.custom_minimum_size = Vector2(220.0, 5.0)
	_compass_cd_bar.max_value = 1.0
	_compass_cd_bar.value = 1.0
	comp_v.add_child(_compass_cd_bar)

	# --- BOSS HEALTH BAR (BELOW COMPASS) ---
	_boss_panel = PanelContainer.new()
	_boss_panel.anchor_left = 0.5
	_boss_panel.anchor_right = 0.5
	_boss_panel.offset_left = -260.0
	_boss_panel.offset_right = 260.0
	_boss_panel.offset_top = 96.0
	_boss_panel.offset_bottom = 160.0
	_boss_panel.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.03, 0.05, 0.92), Color(0.95, 0.35, 0.32, 0.92), 12, 16.0, 8.0))
	_boss_panel.visible = false
	_root.add_child(_boss_panel)

	var bv: VBoxContainer = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 5)
	_boss_panel.add_child(bv)

	var bh: HBoxContainer = HBoxContainer.new()
	bv.add_child(bh)
	_boss_name_lbl = Label.new()
	_boss_name_lbl.add_theme_font_override("font", TITLE_FONT)
	_boss_name_lbl.add_theme_font_size_override("font_size", 17)
	_boss_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.72))
	bh.add_child(_boss_name_lbl)

	_boss_phase_lbl = Label.new()
	_boss_phase_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_phase_lbl.add_theme_font_override("font", UI_FONT)
	_boss_phase_lbl.add_theme_font_size_override("font_size", 13)
	_boss_phase_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	bh.add_child(_boss_phase_lbl)

	_boss_bar = _make_progress(Color(0.92, 0.24, 0.28), 14.0)
	_boss_bar.custom_minimum_size = Vector2(460.0, 14.0)
	bv.add_child(_boss_bar)

	# --- TOP-RIGHT: STAGE, SCORE, BUTTONS & LIVE QUEST TRACKER ---
	var tr_v: VBoxContainer = VBoxContainer.new()
	tr_v.anchor_left = 1.0
	tr_v.anchor_right = 1.0
	tr_v.offset_left = -335.0
	tr_v.offset_right = -18.0
	tr_v.offset_top = 16.0
	tr_v.add_theme_constant_override("separation", 8)
	_root.add_child(tr_v)

	var tr_top: PanelContainer = PanelContainer.new()
	tr_top.add_theme_stylebox_override("panel", _make_box(dark_bg, teal_border, 12, 12.0, 8.0))
	tr_v.add_child(tr_top)

	var tr_top_v: VBoxContainer = VBoxContainer.new()
	tr_top_v.add_theme_constant_override("separation", 6)
	tr_top.add_child(tr_top_v)

	_stage_lbl = Label.new()
	_stage_lbl.text = "Stage 1 — Whispering Moss Woods"
	_stage_lbl.add_theme_font_override("font", TITLE_FONT)
	_stage_lbl.add_theme_font_size_override("font_size", 14)
	_stage_lbl.add_theme_color_override("font_color", Color(0.96, 0.9, 0.6))
	tr_top_v.add_child(_stage_lbl)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	tr_top_v.add_child(btn_row)

	_score_lbl = Label.new()
	_score_lbl.text = "Score: 0"
	_score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_lbl.add_theme_font_override("font", UI_FONT)
	_score_lbl.add_theme_font_size_override("font_size", 14)
	btn_row.add_child(_score_lbl)

	var j_btn: Button = _make_button("Journal [Q]", Color(0.09, 0.2, 0.28, 0.95), teal_border)
	j_btn.add_theme_font_size_override("font_size", 12)
	j_btn.pressed.connect(toggle_journal)
	btn_row.add_child(j_btn)

	var m_btn: Button = _make_button("Menu [Esc]", Color(0.14, 0.26, 0.22, 0.95), gold_border)
	m_btn.add_theme_font_size_override("font_size", 12)
	m_btn.pressed.connect(toggle_pause)
	btn_row.add_child(m_btn)

	var quest_panel: PanelContainer = PanelContainer.new()
	quest_panel.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.055, 0.088, 0.84), Color(0.84, 0.7, 0.34, 0.72), 12, 12.0, 9.0))
	tr_v.add_child(quest_panel)

	_quest_list_box = VBoxContainer.new()
	_quest_list_box.add_theme_constant_override("separation", 4)
	quest_panel.add_child(_quest_list_box)

	# --- STAGE INTRO BANNER & TOAST NOTIFICATION ---
	_stage_banner = PanelContainer.new()
	_stage_banner.anchor_left = 0.5
	_stage_banner.anchor_right = 0.5
	_stage_banner.offset_left = -280.0
	_stage_banner.offset_right = 280.0
	_stage_banner.offset_top = 175.0
	_stage_banner.offset_bottom = 240.0
	_stage_banner.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.055, 0.09, 0.88), gold_border, 16, 20.0, 12.0))
	_stage_banner.visible = false
	_stage_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage_banner)

	_stage_banner_lbl = Label.new()
	_stage_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_banner_lbl.add_theme_font_override("font", TITLE_FONT)
	_stage_banner_lbl.add_theme_font_size_override("font_size", 24)
	_stage_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
	_stage_banner.add_child(_stage_banner_lbl)

	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.offset_left = -250.0
	_toast_panel.offset_right = 250.0
	_toast_panel.offset_top = 104.0
	_toast_panel.offset_bottom = 164.0
	_toast_panel.add_theme_stylebox_override("panel", _make_box(Color(0.04, 0.07, 0.11, 0.94), gold_border, 12, 18.0, 8.0))
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_panel)

	var tv: VBoxContainer = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	_toast_panel.add_child(tv)
	_toast_title_lbl = Label.new()
	_toast_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_title_lbl.add_theme_font_override("font", TITLE_FONT)
	_toast_title_lbl.add_theme_font_size_override("font_size", 15)
	tv.add_child(_toast_title_lbl)
	_toast_sub_lbl = Label.new()
	_toast_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_sub_lbl.add_theme_font_override("font", UI_FONT)
	_toast_sub_lbl.add_theme_font_size_override("font_size", 13)
	_toast_sub_lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 0.92))
	tv.add_child(_toast_sub_lbl)

	# --- FLOATING [E] INTERACT PROMPT ---
	_interact_panel = PanelContainer.new()
	_interact_panel.anchor_left = 0.5
	_interact_panel.anchor_right = 0.5
	_interact_panel.anchor_top = 1.0
	_interact_panel.anchor_bottom = 1.0
	_interact_panel.offset_left = -195.0
	_interact_panel.offset_right = 195.0
	_interact_panel.offset_top = -126.0
	_interact_panel.offset_bottom = -82.0
	_interact_panel.add_theme_stylebox_override("panel", _make_box(Color(0.05, 0.11, 0.14, 0.94), gold_border, 12, 16.0, 8.0))
	_interact_panel.visible = false
	_interact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_interact_panel)

	_interact_lbl = Label.new()
	_interact_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact_lbl.add_theme_font_override("font", TITLE_FONT)
	_interact_lbl.add_theme_font_size_override("font_size", 16)
	_interact_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.52))
	_interact_panel.add_child(_interact_lbl)

	# --- BOTTOM CONTROLS HINT BAR ---
	var hint_lbl: Label = Label.new()
	hint_lbl.anchor_left = 0.5
	hint_lbl.anchor_right = 0.5
	hint_lbl.anchor_top = 1.0
	hint_lbl.anchor_bottom = 1.0
	hint_lbl.offset_left = -480.0
	hint_lbl.offset_right = 480.0
	hint_lbl.offset_top = -28.0
	hint_lbl.offset_bottom = -6.0
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_override("font", UI_FONT)
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.84, 0.9, 0.88, 0.82))
	hint_lbl.text = "WASD Move • Space Jump/Double Jump • Shift Dash • LMB/J Melee • RMB/K Golden Arc • E Interact • G Compass Pulse • H Herb • Q Journal"
	_root.add_child(hint_lbl)

	# --- STORY DIALOGUE BOX ---
	var dlg: Control = Control.new()
	dlg.name = "DialogueBox"
	dlg.set_script(DIALOGUE_SCRIPT)
	_root.add_child(dlg)

	# --- MODALS: QUEST JOURNAL, PAUSE, GAME OVER, VICTORY ---
	_build_journal_overlay()
	_build_pause_overlay()
	_build_gameover_overlay()
	_build_victory_overlay()


func _build_modal_backdrop() -> ColorRect:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.02, 0.04, 0.72)
	bg.visible = false
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)
	return bg


func _build_journal_overlay() -> void:
	_journal_overlay = _build_modal_backdrop()
	var card: PanelContainer = PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -360.0
	card.offset_right = 360.0
	card.offset_top = -255.0
	card.offset_bottom = 255.0
	card.add_theme_stylebox_override("panel", _make_box(Color(0.04, 0.065, 0.1, 0.96), Color(0.9, 0.74, 0.34), 16, 24.0, 20.0))
	_journal_overlay.add_child(card)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var title: Label = Label.new()
	title.text = "EXPLORER'S QUEST JOURNAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	v.add_child(title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	_journal_content = VBoxContainer.new()
	_journal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_journal_content)

	var close_btn: Button = _make_button("Close Journal [Q / Esc]")
	close_btn.pressed.connect(toggle_journal)
	v.add_child(close_btn)


func _build_pause_overlay() -> void:
	_pause_overlay = _build_modal_backdrop()
	var card: PanelContainer = PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -220.0
	card.offset_right = 220.0
	card.offset_top = -250.0
	card.offset_bottom = 250.0
	card.add_theme_stylebox_override("panel", _make_box(Color(0.04, 0.065, 0.1, 0.96), Color(0.9, 0.74, 0.34), 16, 24.0, 20.0))
	_pause_overlay.add_child(card)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var title: Label = Label.new()
	title.text = "ADVENTURE PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.52))
	v.add_child(title)

	var b_resume: Button = _make_button("Resume Adventure")
	b_resume.pressed.connect(toggle_pause)
	v.add_child(b_resume)

	var b_journal: Button = _make_button("Quest Journal [Q]", Color(0.09, 0.2, 0.28, 0.96))
	b_journal.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		get_tree().paused = false
		toggle_journal()
	)
	v.add_child(b_journal)

	var b_cp: Button = _make_button("Respawn at Wayshrine", Color(0.12, 0.24, 0.28, 0.96))
	b_cp.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		GameManager.respawn_at_checkpoint()
	)
	v.add_child(b_cp)

	var b_restart: Button = _make_button("Restart Current Stage", Color(0.24, 0.18, 0.14, 0.96))
	b_restart.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		GameManager.restart_current_level()
	)
	v.add_child(b_restart)

	# Master & SFX Volume Sliders
	var m_lbl: Label = Label.new()
	m_lbl.text = "Master Volume"
	m_lbl.add_theme_font_override("font", UI_FONT)
	m_lbl.add_theme_font_size_override("font_size", 13)
	v.add_child(m_lbl)
	var m_slider: HSlider = HSlider.new()
	m_slider.min_value = 0.0
	m_slider.max_value = 1.0
	m_slider.step = 0.05
	m_slider.value = AudioManager.master_volume if AudioManager else 0.85
	m_slider.value_changed.connect(func(val: float) -> void:
		if AudioManager:
			AudioManager.set_master_volume(val)
	)
	v.add_child(m_slider)

	var s_lbl: Label = Label.new()
	s_lbl.text = "SFX Volume"
	s_lbl.add_theme_font_override("font", UI_FONT)
	s_lbl.add_theme_font_size_override("font_size", 13)
	v.add_child(s_lbl)
	var s_slider: HSlider = HSlider.new()
	s_slider.min_value = 0.0
	s_slider.max_value = 1.0
	s_slider.step = 0.05
	s_slider.value = AudioManager.sfx_volume if AudioManager else 0.9
	s_slider.value_changed.connect(func(val: float) -> void:
		if AudioManager:
			AudioManager.set_sfx_volume(val)
	)
	v.add_child(s_slider)

	var b_menu: Button = _make_button("Return to Main Menu", Color(0.26, 0.12, 0.14, 0.96))
	b_menu.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		GameManager.go_to_main_menu()
	)
	v.add_child(b_menu)


func _build_gameover_overlay() -> void:
	_gameover_overlay = _build_modal_backdrop()
	var card: PanelContainer = PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -230.0
	card.offset_right = 230.0
	card.offset_top = -175.0
	card.offset_bottom = 175.0
	card.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.03, 0.04, 0.96), Color(0.95, 0.34, 0.32), 16, 26.0, 22.0))
	_gameover_overlay.add_child(card)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var title: Label = Label.new()
	title.text = "THE LIGHT HAS FADED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.42))
	v.add_child(title)

	var sub: Label = Label.new()
	sub.text = "The Golden Compass still flickers. Return to your last Wayshrine and press onward."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 14)
	v.add_child(sub)

	var b_respawn: Button = _make_button("Respawn at Wayshrine")
	b_respawn.pressed.connect(func() -> void:
		_gameover_overlay.visible = false
		GameManager.respawn_at_checkpoint()
	)
	v.add_child(b_respawn)

	var b_restart: Button = _make_button("Restart Stage", Color(0.22, 0.16, 0.12, 0.96))
	b_restart.pressed.connect(func() -> void:
		_gameover_overlay.visible = false
		GameManager.restart_current_level()
	)
	v.add_child(b_restart)

	var b_menu: Button = _make_button("Main Menu", Color(0.22, 0.1, 0.12, 0.96))
	b_menu.pressed.connect(func() -> void:
		_gameover_overlay.visible = false
		GameManager.go_to_main_menu()
	)
	v.add_child(b_menu)


func _build_victory_overlay() -> void:
	_victory_overlay = _build_modal_backdrop()
	var card: PanelContainer = PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -310.0
	card.offset_right = 310.0
	card.offset_top = -245.0
	card.offset_bottom = 245.0
	card.add_theme_stylebox_override("panel", _make_box(Color(0.035, 0.065, 0.1, 0.97), Color(1.0, 0.84, 0.36), 18, 28.0, 22.0))
	_victory_overlay.add_child(card)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var title: Label = Label.new()
	title.text = "FOREST HEART RESTORED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	v.add_child(title)

	var sub: Label = Label.new()
	sub.text = "Aurelius the Astral Sovereign is purified. The Golden Compass illuminates all four realms once more."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.84, 0.96, 0.92))
	v.add_child(sub)

	_victory_stats_lbl = Label.new()
	_victory_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_stats_lbl.add_theme_font_override("font", UI_FONT)
	_victory_stats_lbl.add_theme_font_size_override("font_size", 16)
	_victory_stats_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	v.add_child(_victory_stats_lbl)

	var credits: Label = Label.new()
	credits.text = "Magical Forest: The Golden Compass — Pure Godot 4 (GDScript & WebGL2)\nThank you for playing!"
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_override("font", UI_FONT)
	credits.add_theme_font_size_override("font_size", 13)
	credits.add_theme_color_override("font_color", Color(0.62, 0.84, 0.8))
	v.add_child(credits)

	var btn_h: HBoxContainer = HBoxContainer.new()
	btn_h.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_h.add_theme_constant_override("separation", 14)
	v.add_child(btn_h)

	var b_again: Button = _make_button("Play Again (New Adventure)")
	b_again.pressed.connect(func() -> void:
		_victory_overlay.visible = false
		GameManager.reset_new_game(0)
	)
	btn_h.add_child(b_again)

	var b_menu: Button = _make_button("Main Menu", Color(0.12, 0.2, 0.28, 0.96))
	b_menu.pressed.connect(func() -> void:
		_victory_overlay.visible = false
		GameManager.go_to_main_menu()
	)
	btn_h.add_child(b_menu)


func _connect_signals() -> void:
	GameManager.vitality_changed.connect(_on_vitality_changed)
	GameManager.compass_energy_changed.connect(_on_energy_changed)
	GameManager.herbs_changed.connect(_on_herbs_changed)
	GameManager.shards_changed.connect(_on_shards_changed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.dash_cooldown_changed.connect(func(r: float) -> void: _dash_bar.value = r)
	GameManager.compass_pulse_cooldown_changed.connect(func(r: float) -> void: _compass_cd_bar.value = r)
	GameManager.compass_updated.connect(_on_compass_updated)
	GameManager.interact_prompt_changed.connect(_on_interact_prompt)
	GameManager.boss_health_changed.connect(_on_boss_health)
	GameManager.toast_posted.connect(_on_toast_posted)
	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.victory_triggered.connect(_on_victory)

	if QuestManager:
		QuestManager.quest_started.connect(func(_id: String) -> void: _refresh_quest_tracker())
		QuestManager.quest_updated.connect(func(_id: String) -> void: _refresh_quest_tracker())
		QuestManager.quest_completed.connect(func(_id: String) -> void: _refresh_quest_tracker())


func _refresh_all() -> void:
	_on_vitality_changed(GameManager.vitality, GameManager.max_vitality)
	_on_energy_changed(GameManager.compass_energy, GameManager.max_compass_energy)
	_on_herbs_changed(GameManager.healing_herbs)
	_on_shards_changed(GameManager.shards_total)
	_on_score_changed(GameManager.score)
	var idx: int = clampi(GameManager.current_stage_index, 0, GameManager.STAGE_NAMES.size() - 1)
	_stage_lbl.text = GameManager.STAGE_NAMES[idx]
	_refresh_quest_tracker()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_ended:
		return
	if event.is_action_pressed("pause"):
		if GameManager.is_journal_open:
			toggle_journal()
		elif not GameManager.is_dialogue_open:
			toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quest_journal"):
		if not get_tree().paused and not GameManager.is_dialogue_open:
			toggle_journal()
			get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if GameManager.is_game_ended:
		return
	var will_pause: bool = not get_tree().paused
	get_tree().paused = will_pause
	_pause_overlay.visible = will_pause
	if will_pause:
		GameManager.set_ui_mouse()
	else:
		GameManager.set_gameplay_mouse()


func toggle_journal() -> void:
	if GameManager.is_game_ended:
		return
	var open_now: bool = not GameManager.is_journal_open
	GameManager.is_journal_open = open_now
	_journal_overlay.visible = open_now
	if open_now:
		_populate_journal()
		GameManager.set_ui_mouse()
		if AudioManager:
			AudioManager.play_sfx("ui_click")
	else:
		GameManager.set_gameplay_mouse()


func show_level_banner(title_text: String, _show_hint: bool = true) -> void:
	_stage_lbl.text = title_text
	_stage_banner_lbl.text = title_text
	_stage_banner.visible = true
	_stage_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw: Tween = create_tween()
	tw.tween_property(_stage_banner, "modulate:a", 1.0, 0.45)
	tw.tween_interval(2.4)
	tw.tween_property(_stage_banner, "modulate:a", 0.0, 0.75)
	tw.tween_callback(func() -> void: _stage_banner.visible = false)


func flash_damage_vignette() -> void:
	if not damage_vignette or not (damage_vignette.material is ShaderMaterial):
		return
	var mat: ShaderMaterial = damage_vignette.material as ShaderMaterial
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	mat.set_shader_parameter("intensity", 0.78)
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), 0.78, 0.0, 0.55)


func _on_vitality_changed(cur: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = cur
	_hp_label.text = "%d / %d" % [cur, max_hp]


func _on_energy_changed(cur: float, max_e: float) -> void:
	_energy_bar.max_value = max_e
	_energy_bar.value = cur
	_energy_label.text = "%d / %d" % [int(round(cur)), int(round(max_e))]


func _on_herbs_changed(count: int) -> void:
	_herbs_lbl.text = "Herbs [H]: %d" % count


func _on_shards_changed(count: int) -> void:
	_shards_lbl.text = "Shards: %d" % count


func _on_score_changed(sc: int) -> void:
	_score_lbl.text = "Score: %d" % sc


func _on_compass_updated(rel_angle: float, dist_m: float, label: String) -> void:
	_compass_target_lbl.text = label
	_compass_dist_lbl.text = "%d m" % maxi(int(round(dist_m)), 1)
	if _compass_arrow_pivot:
		_compass_arrow_pivot.rotation = rel_angle


func _on_interact_prompt(vis: bool, text_str: String) -> void:
	_interact_panel.visible = vis and not GameManager.is_dialogue_open
	_interact_lbl.text = text_str


func _on_boss_health(cur: int, max_hp: int, vis: bool, bname: String, phase_lbl: String) -> void:
	_boss_panel.visible = vis
	if vis:
		_boss_name_lbl.text = bname
		_boss_phase_lbl.text = phase_lbl
		_boss_bar.max_value = maxi(max_hp, 1)
		_boss_bar.value = clampi(cur, 0, max_hp)


func _on_toast_posted(title: String, subtitle: String, accent: Color) -> void:
	_toast_title_lbl.text = title
	_toast_title_lbl.add_theme_color_override("font_color", accent)
	_toast_sub_lbl.text = subtitle
	_toast_sub_lbl.visible = not subtitle.is_empty()
	_toast_panel.visible = true
	_toast_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.22)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.45)
	_toast_tween.tween_callback(func() -> void: _toast_panel.visible = false)


func _refresh_quest_tracker() -> void:
	if not _quest_list_box or not QuestManager:
		return
	for c in _quest_list_box.get_children():
		c.queue_free()

	var mq: Dictionary = QuestManager.get_active_main_quest()
	if not mq.is_empty():
		var h: Label = Label.new()
		h.text = "MAIN: " + String(mq.get("title", ""))
		h.add_theme_font_override("font", TITLE_FONT)
		h.add_theme_font_size_override("font_size", 14)
		h.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
		_quest_list_box.add_child(h)
		var steps: Array = mq.get("steps", [])
		for s_var in steps:
			var step: Dictionary = s_var
			var cur: int = int(step.get("current", 0))
			var tgt: int = int(step.get("target", 1))
			var done: bool = cur >= tgt
			var lbl: Label = Label.new()
			lbl.text = ("%s %s (%d/%d)" % ["[x]" if done else "[ ]", String(step.get("label", "")), cur, tgt])
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_override("font", UI_FONT)
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.54, 0.92, 0.64) if done else Color(0.88, 0.93, 0.92))
			_quest_list_box.add_child(lbl)

	var sq: Dictionary = QuestManager.get_active_side_quest()
	if not sq.is_empty() and bool(sq.get("active", false)):
		var sh: Label = Label.new()
		sh.text = "SIDE: " + String(sq.get("title", ""))
		sh.add_theme_font_override("font", TITLE_FONT)
		sh.add_theme_font_size_override("font_size", 13)
		sh.add_theme_color_override("font_color", Color(0.48, 0.94, 0.88))
		_quest_list_box.add_child(sh)
		var s_steps: Array = sq.get("steps", [])
		for s_var in s_steps:
			var step: Dictionary = s_var
			var cur: int = int(step.get("current", 0))
			var tgt: int = int(step.get("target", 1))
			var done: bool = cur >= tgt
			var lbl: Label = Label.new()
			lbl.text = ("%s %s (%d/%d)" % ["[x]" if done else "[ ]", String(step.get("label", "")), cur, tgt])
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_override("font", UI_FONT)
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.54, 0.92, 0.64) if done else Color(0.84, 0.92, 0.94))
			_quest_list_box.add_child(lbl)


func _populate_journal() -> void:
	for c in _journal_content.get_children():
		c.queue_free()

	for q_dict in [QuestManager.get_active_main_quest(), QuestManager.get_active_side_quest()]:
		if q_dict.is_empty() or not bool(q_dict.get("active", false)):
			continue
		_add_journal_card(q_dict, false)

	var completed: Array[Dictionary] = QuestManager.get_all_completed_quests()
	if not completed.is_empty():
		var ch: Label = Label.new()
		ch.text = "COMPLETED QUESTS"
		ch.add_theme_font_override("font", TITLE_FONT)
		ch.add_theme_font_size_override("font_size", 16)
		ch.add_theme_color_override("font_color", Color(0.55, 0.96, 0.68))
		_journal_content.add_child(ch)
		for cq in completed:
			_add_journal_card(cq, true)


func _add_journal_card(q: Dictionary, is_done: bool) -> void:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.095, 0.14, 0.92), Color(0.52, 0.88, 0.62) if is_done else Color(0.88, 0.72, 0.34), 10, 14.0, 10.0))
	_journal_content.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)

	var kind: String = "MAIN QUEST" if String(q.get("type", "")) == "main" else "SIDE QUEST"
	var t: Label = Label.new()
	t.text = "[%s] %s%s" % [kind, String(q.get("title", "")), " (COMPLETED)" if is_done else ""]
	t.add_theme_font_override("font", TITLE_FONT)
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color(0.56, 0.96, 0.68) if is_done else Color(1.0, 0.88, 0.44))
	v.add_child(t)

	var desc: Label = Label.new()
	desc.text = String(q.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", UI_FONT)
	desc.add_theme_font_size_override("font_size", 13)
	v.add_child(desc)

	var rew: Label = Label.new()
	rew.text = "Reward: " + String(q.get("reward_text", ""))
	rew.add_theme_font_override("font", UI_FONT)
	rew.add_theme_font_size_override("font_size", 13)
	rew.add_theme_color_override("font_color", Color(0.65, 0.94, 0.86))
	v.add_child(rew)

	var steps: Array = q.get("steps", [])
	for s_var in steps:
		var st: Dictionary = s_var
		var cur: int = int(st.get("current", 0))
		var tgt: int = int(st.get("target", 1))
		var sl: Label = Label.new()
		sl.text = "  %s %s (%d/%d)" % ["[x]" if cur >= tgt else "[ ]", String(st.get("label", "")), cur, tgt]
		sl.add_theme_font_override("font", UI_FONT)
		sl.add_theme_font_size_override("font_size", 13)
		v.add_child(sl)


func _on_game_over() -> void:
	_pause_overlay.visible = false
	_journal_overlay.visible = false
	_gameover_overlay.visible = true


func _on_victory() -> void:
	_pause_overlay.visible = false
	_journal_overlay.visible = false
	var mins: int = int(GameManager.elapsed_time) / 60
	var secs: int = int(GameManager.elapsed_time) % 60
	var q_done: int = QuestManager.completed_quest_ids.size() if QuestManager else 4
	_victory_stats_lbl.text = "Final Score: %d\nQuests Completed: %d   •   Time: %02d:%02d\nSunlit Shards: %d   •   Chests Opened: %d   •   Foes Vanquished: %d" % [
		GameManager.score,
		q_done,
		mins,
		secs,
		GameManager.shards_total,
		GameManager.chests_opened,
		GameManager.enemies_defeated,
	]
	_victory_overlay.visible = true
