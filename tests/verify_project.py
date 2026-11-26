"""Comprehensive static & structural verification test suite for
The Lost Golden Compass 3D (Godot 4.7.2).
Verifies project.godot settings, 3D Input Map, 6-layer 3D Physics Matrix,
.tscn load_steps and resource IDs, res:// references, @onready node paths,
Audio bus names, shader syntax basics, 3D jump-height math, and PNG/WAV integrity.
"""
import os
import re
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ERRORS = []
CHECKS = 0


def ok(cond: bool, msg: str) -> None:
    global CHECKS
    CHECKS += 1
    if not cond:
        ERRORS.append(msg)


def res_to_abs(res_path: str) -> str:
    assert res_path.startswith("res://"), res_path
    return os.path.join(ROOT, res_path[6:].replace("/", os.sep))


def test_project_godot() -> None:
    path = os.path.join(ROOT, "project.godot")
    ok(os.path.isfile(path), "Missing project.godot")
    text = open(path, encoding="utf-8").read()

    required_entries = [
        'config_version=5',
        'run/main_scene="res://scenes/ui/main_menu_3d.tscn"',
        'GameManager="*res://autoloads/game_manager.gd"',
        'buses/default_bus_layout="res://resources/default_bus_layout.tres"',
        'window/size/viewport_width=2560',
        'window/size/viewport_height=1440',
        'window/size/window_width_override=1280',
        'window/size/window_height_override=720',
        'window/stretch/mode="canvas_items"',
        'window/stretch/aspect="keep"',
        'window/stretch/scale_mode="fractional"',
        'joypad/ignore_unfocused=true',
        'common/physics_ticks_per_second=60',
        'textures/canvas_textures/default_texture_filter=1',
        'viewport/hdr_2d=true',
        '3d_physics/layer_1="World"',
        '3d_physics/layer_2="Player"',
        '3d_physics/layer_3="Enemies"',
        '3d_physics/layer_4="PlayerAttack"',
        '3d_physics/layer_5="Hazards"',
        '3d_physics/layer_6="PickupsAndZones"',
    ]
    for entry in required_entries:
        ok(entry in text, f"project.godot missing setting: {entry}")

    for action in ("move_left", "move_right", "move_forward", "move_back", "sprint", "cam_left", "cam_right", "jump", "attack", "dodge", "restart", "pause"):
        ok(f"{action}={{" in text, f"project.godot missing input action: {action}")
        ok("InputEventJoypad" in text.split(f"{action}={{")[1].split("}")[0],
           f"Input action {action} missing Joypad binding")


def test_res_references_and_tscn_tres() -> None:
    res_pattern = re.compile(r'"(res://[^"]+)"')
    ext_pattern = re.compile(r'^\[ext_resource\s+[^\]]*id="([^"]+)"', re.M)
    sub_pattern = re.compile(r'^\[sub_resource\s+[^\]]*id="([^"]+)"', re.M)
    ext_ref_pattern = re.compile(r'ExtResource\("([^"]+)"\)')
    sub_ref_pattern = re.compile(r'SubResource\("([^"]+)"\)')
    load_steps_pattern = re.compile(r'load_steps=(\d+)')

    for dirpath, _, filenames in os.walk(ROOT):
        for fn in filenames:
            if not fn.endswith((".gd", ".tscn", ".tres", ".godot", ".gdshader")):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT)
            text = open(full, encoding="utf-8").read()

            for m in res_pattern.finditer(text):
                res_p = m.group(1)
                if res_p.startswith("res://*"):
                    res_p = "res://" + res_p[7:]
                abs_p = res_to_abs(res_p)
                ok(os.path.isfile(abs_p), f"{rel}: broken res:// reference -> {m.group(1)}")

            if fn.endswith((".tscn", ".tres")):
                exts = ext_pattern.findall(text)
                subs = sub_pattern.findall(text)
                expected_steps = len(exts) + len(subs) + 1
                m_ls = load_steps_pattern.search(text.splitlines()[0])
                if m_ls:
                    actual_ls = int(m_ls.group(1))
                    ok(actual_ls == expected_steps,
                       f"{rel}: load_steps={actual_ls} != expected {expected_steps}")

                ext_set = set(exts)
                sub_set = set(subs)
                ok(len(ext_set) == len(exts), f"{rel}: duplicate ext_resource IDs")
                ok(len(sub_set) == len(subs), f"{rel}: duplicate sub_resource IDs")

                for ref in ext_ref_pattern.findall(text):
                    ok(ref in ext_set, f"{rel}: dangling ExtResource({ref})")
                for ref in sub_ref_pattern.findall(text):
                    ok(ref in sub_set, f"{rel}: dangling SubResource({ref})")

            if fn.endswith(".gdshader"):
                ok(any(st in text for st in ("shader_type canvas_item;", "shader_type sky;", "shader_type spatial;")),
                   f"{rel}: missing valid shader_type declaration")
                ok(text.count("{") == text.count("}"), f"{rel}: unbalanced shader braces")


def parse_tscn_nodes(tscn_path: str) -> dict:
    text = open(tscn_path, encoding="utf-8").read()
    nodes = {}
    cur_props = None
    cur_path = None
    node_hdr = re.compile(r'^\[node\s+name="([^"]+)"(?:\s+type="([^"]+)")?(?:\s+parent="([^"]*)")?')
    for line in text.splitlines():
        m = node_hdr.match(line)
        if m:
            name, _, parent = m.group(1), m.group(2), m.group(3)
            if parent is None:
                cur_path = "."
            elif parent == ".":
                cur_path = name
            else:
                cur_path = f"{parent}/{name}"
            cur_props = {}
            nodes[cur_path] = cur_props
        elif line.startswith("["):
            cur_props = None
        elif cur_props is not None and "=" in line:
            k, v = line.split("=", 1)
            cur_props[k.strip()] = v.strip()
    return nodes


def test_onready_paths_and_physics_layers() -> None:
    onready_re = re.compile(r'@onready\s+var\s+\w+\s*:\s*[^=]+=\s*\$([^\s]+)')
    pairs = [
        ("scenes/player/player_3d.gd", "scenes/player/player_3d.tscn"),
        ("scenes/world/crystal_3d.gd", "scenes/world/crystal_3d.tscn"),
        ("scenes/world/healing_orb_3d.gd", "scenes/world/healing_orb_3d.tscn"),
        ("scenes/world/hidden_path_3d.gd", "scenes/world/hidden_path_3d.tscn"),
        ("scenes/world/timed_thorn_trap_3d.gd", "scenes/world/timed_thorn_trap_3d.tscn"),
        ("scenes/world/golden_compass_3d.gd", "scenes/world/golden_compass_3d.tscn"),
        ("scenes/enemies/flying_wisp_3d.gd", "scenes/enemies/flying_wisp_3d.tscn"),
        ("scenes/enemies/boss_orb_3d.gd", "scenes/enemies/boss_orb_3d.tscn"),
        ("scenes/enemies/forest_guardian_3d.gd", "scenes/enemies/forest_guardian_3d.tscn"),
        ("scenes/ui/hud.gd", "scenes/ui/hud.tscn"),
        ("scenes/ui/main_menu_3d.gd", "scenes/ui/main_menu_3d.tscn"),
        ("scenes/world/wayshrine_3d.gd", "scenes/world/wayshrine_3d.tscn"),
    ]
    for gd_rel, tscn_rel in pairs:
        gd_text = open(os.path.join(ROOT, gd_rel), encoding="utf-8").read()
        nodes = parse_tscn_nodes(os.path.join(ROOT, tscn_rel))
        for m in onready_re.finditer(gd_text):
            np = m.group(1)
            ok(np in nodes, f"{gd_rel}: @onready ${np} missing in {tscn_rel}")

    bus_txt = open(os.path.join(ROOT, "resources/default_bus_layout.tres"), encoding="utf-8").read()
    valid_buses = {"Master"} | set(re.findall(r'bus/\d+/name\s*=\s*&"([^"]+)"', bus_txt))
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, "scenes")):
        for fn in filenames:
            if not fn.endswith(".tscn"):
                continue
            txt = open(os.path.join(dirpath, fn), encoding="utf-8").read()
            for b in re.findall(r'bus\s*=\s*&"([^"]+)"', txt):
                ok(b in valid_buses, f"{fn}: unknown audio bus '{b}'")

    expected_physics = [
        ("scenes/player/player_3d.tscn", ".", "2", "1"),
        ("scenes/player/player_3d.tscn", "VisualRig/AttackArea", "8", "4"),
        ("scenes/world/crystal_3d.tscn", ".", "32", "2"),
        ("scenes/world/healing_orb_3d.tscn", ".", "32", "2"),
        ("scenes/world/spike_trap_3d.tscn", ".", "16", "2"),
        ("scenes/world/timed_thorn_trap_3d.tscn", ".", "16", "2"),
        ("scenes/world/hidden_path_3d.tscn", ".", "32", "2"),
        ("scenes/world/level_exit_3d.tscn", ".", "32", "2"),
        ("scenes/world/wayshrine_3d.tscn", ".", "32", "2"),
        ("scenes/world/golden_compass_3d.tscn", ".", "32", "2"),
        ("scenes/world/kill_zone_3d.tscn", ".", "16", "2"),
        ("scenes/enemies/flying_wisp_3d.tscn", ".", "4", "1"),
        ("scenes/enemies/flying_wisp_3d.tscn", "ContactHitBox", "16", "2"),
        ("scenes/enemies/flying_wisp_3d.tscn", "DetectZone", "32", "2"),
        ("scenes/enemies/boss_orb_3d.tscn", ".", "16", "3"),
        ("scenes/enemies/forest_guardian_3d.tscn", ".", "4", "1"),
        ("scenes/enemies/forest_guardian_3d.tscn", "ContactHitBox", "16", "2"),
    ]
    for tscn_rel, node_p, exp_layer, exp_mask in expected_physics:
        nodes = parse_tscn_nodes(os.path.join(ROOT, tscn_rel))
        props = nodes.get(node_p, {})
        ok(props.get("collision_layer") == exp_layer,
           f"{tscn_rel} [{node_p}]: collision_layer={props.get('collision_layer')} != {exp_layer}")
        ok(props.get("collision_mask") == exp_mask,
           f"{tscn_rel} [{node_p}]: collision_mask={props.get('collision_mask')} != {exp_mask}")


def test_assets_integrity() -> None:
    png_count = 0
    wav_count = 0
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, "assets")):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT)
            if fn.endswith(".png"):
                png_count += 1
                data = open(full, "rb").read(24)
                ok(data[:8] == b"\x89PNG\r\n\x1a\n", f"{rel}: invalid PNG header")
                w, h = struct.unpack(">II", data[16:24])
                ok(w > 0 and h > 0, f"{rel}: invalid PNG dimensions {w}x{h}")
            elif fn.endswith(".wav"):
                wav_count += 1
                with wave.open(full, "rb") as wf:
                    ok(wf.getnframes() > 0 and wf.getframerate() > 0, f"{rel}: empty WAV")
    ok(png_count >= 30, f"Expected >=30 PNG assets (2D+3D PBR), got {png_count}")
    ok(wav_count >= 10, f"Expected >=10 WAV assets, got {wav_count}")


def test_levels_completeness() -> None:
    for lvl in ("greybox_test_room_3d.tscn", "level_1_3d.tscn", "level_2_3d.tscn", "level_3_boss_3d.tscn", "level_4_astral_3d.tscn"):
        p = os.path.join(ROOT, "scenes/levels", lvl)
        ok(os.path.isfile(p), f"Missing 3D level {lvl}")
        nodes = parse_tscn_nodes(p)
        for req in ("WorldGeometry", "SpawnFloorCollider", "FallbackRoad", "Player3D", "HUD", "KillZone3D", "MoonLight", "WorldEnvironment", "Fireflies"):
            ok(req in nodes, f"{lvl}: missing required node {req}")

    l3_nodes = parse_tscn_nodes(os.path.join(ROOT, "scenes/levels/level_3_boss_3d.tscn"))
    ok("CompassPedestal" in l3_nodes, "level_3_boss_3d.tscn: missing CompassPedestal Marker3D")
    ok("AstralPortal" in l3_nodes, "level_3_boss_3d.tscn: missing AstralPortal for advancing to Stage 4")
    ok(l3_nodes.get("AstralPortal", {}).get("starts_dormant") == "true", "level_3_boss_3d.tscn: AstralPortal should start dormant")
    fg_props = l3_nodes.get("Enemies/ForestGuardian3D", {})
    ok(fg_props.get("compass_spawn_marker") == 'NodePath("../../CompassPedestal")',
       "level_3_boss_3d.tscn: ForestGuardian3D compass_spawn_marker not linked to ../../CompassPedestal")

    l4_nodes = parse_tscn_nodes(os.path.join(ROOT, "scenes/levels/level_4_astral_3d.tscn"))
    ok("CompassPedestal" in l4_nodes, "level_4_astral_3d.tscn: missing CompassPedestal Marker3D")
    ok(l4_nodes.get("Enemies/AstralGuardian", {}).get("compass_spawn_marker") == 'NodePath("../../CompassPedestal")',
       "level_4_astral_3d.tscn: AstralGuardian compass_spawn_marker not linked to ../../CompassPedestal")

    mf_txt = open(os.path.join(ROOT, "scenes/common/mesh_factory_3d.gd"), encoding="utf-8").read()
    ok("func(" not in mf_txt, "mesh_factory_3d.gd: must not use nested lambdas inside static func")
    for h_rel in (
        "scenes/common/mesh_factory_3d.gd",
        "scenes/player/player_visuals_3d.gd",
        "scenes/enemies/guardian_visuals_3d.gd",
        "scenes/world/props_visuals_3d.gd",
    ):
        h_txt = open(os.path.join(ROOT, h_rel), encoding="utf-8").read()
        ok("class_name " not in h_txt, f"{h_rel}: use explicit preload() instead of global class_name")

    player_gd = open(os.path.join(ROOT, "scenes/player/player_3d.gd"), encoding="utf-8").read()
    ok("allow_jump: bool = false" in player_gd, "player_3d.gd: allow_jump must default to false (no jump)")
    m_jv = re.search(r'jump_velocity\s*:\s*float\s*=\s*(\d+(?:\.\d+)?)', player_gd)
    m_gv = re.search(r'gravity_value\s*:\s*float\s*=\s*(\d+(?:\.\d+)?)', player_gd)
    ok(m_jv is not None and m_gv is not None, "player_3d.gd: missing jump_velocity or gravity_value")
    if m_jv and m_gv:
        v0 = float(m_jv.group(1))
        g0 = float(m_gv.group(1))
        max_jump_m = (v0 * v0) / (2.0 * g0)
        safe_rise_m = 0.80 * max_jump_m
        ok(2.0 <= safe_rise_m,
           f"2.0m step exceeds 80% max 3D jump height ({safe_rise_m:.2f}m)")

    for hazard_gd in (
        "scenes/world/spike_trap_3d.gd",
        "scenes/world/timed_thorn_trap_3d.gd",
        "scenes/enemies/flying_wisp_3d.gd",
        "scenes/enemies/forest_guardian_3d.gd",
    ):
        t_txt = open(os.path.join(ROOT, hazard_gd), encoding="utf-8").read()
        ok("_overlapping_player" in t_txt and "_physics_process" in t_txt,
           f"{hazard_gd}: missing continuous overlap tick for i-frame step-down")

    # Verify no *_3d.tscn references a 2D script (extends Node2D / Area2D / CharacterBody2D)
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, "scenes")):
        for fn in filenames:
            if not fn.endswith("_3d.tscn"):
                continue
            tscn_txt = open(os.path.join(dirpath, fn), encoding="utf-8").read()
            for sp_m in re.finditer(r'path="(res://[^"]+\.gd)"', tscn_txt):
                gd_path = res_to_abs(sp_m.group(1))
                gd_head = open(gd_path, encoding="utf-8").read(250)
                ok(not re.search(r'^extends\s+(?:Node2D|Area2D|CharacterBody2D)\b', gd_head, re.M),
                   f"{fn}: attaches 2D script {sp_m.group(1)} to a 3D scene")

    hud_nodes = parse_tscn_nodes(os.path.join(ROOT, "scenes/ui/hud.tscn"))
    for req_hud in ("LevelBanner", "PausePanel", "CrosshairDot", "DamageVignette", "ToastPanel", "TopBar/HBoxContainer/HealthPanel/Margin/Row/VBox/DashBar", "PausePanel/Margin/VBox/SensRow/SensSlider", "PausePanel/Margin/VBox/QualityButton", "EndPanel/MarginContainer/VBoxContainer/NextAdventureButton"):
        ok(req_hud in hud_nodes, f"hud.tscn: missing {req_hud}")
    ok(os.path.isfile(os.path.join(ROOT, "scenes/ui/main_menu_3d.tscn")), "Missing main_menu_3d.tscn")
    mm_nodes = parse_tscn_nodes(os.path.join(ROOT, "scenes/ui/main_menu_3d.tscn"))
    ok("UI/ScreenFade" in mm_nodes, "main_menu_3d.tscn: missing UI/ScreenFade")
    ok("UI/CenterContainer/MenuCard/Margin/VBox/ChaptersBox/Lvl4Btn" in mm_nodes, "main_menu_3d.tscn: missing Lvl4Btn")

    for sh in (
        "resources/shaders/space_forest_sky.gdshader",
        "resources/shaders/portal_vortex_3d.gdshader",
        "resources/shaders/terrain_blend_3d.gdshader",
        "resources/shaders/road_terrain_3d.gdshader",
        "resources/shaders/grass_sway_3d.gdshader",
        "resources/shaders/foliage_sway_3d.gdshader",
        "resources/shaders/cloak_cloth_3d.gdshader",
        "resources/shaders/forest_water_3d.gdshader",
        "resources/shaders/god_ray_3d.gdshader",
        "resources/shaders/ground_mist_3d.gdshader",
        "resources/shaders/cloud_bank_3d.gdshader",
        "resources/shaders/vignette_2d.gdshader",
    ):
        ok(os.path.isfile(os.path.join(ROOT, sh)), f"Missing required shader: {sh}")

    # Verify long continuous 10-minute roads & sword reachability vs boss height
    lb_txt = open(os.path.join(ROOT, "scenes/levels/level_builder_3d.gd"), encoding="utf-8").read()
    for token in ("_update_streaming_chunks", "_build_sky_chunk_details", "_populate_stage_encounters", "get_road_progress"):
        ok(token in lb_txt, f"level_builder_3d.gd: missing {token}")
    for z_tag in ('"road_end_z": -4600.0', '"road_end_z": -4800.0', '"road_start_z": 4420.0', '"road_end_z": -4920.0'):
        ok(z_tag in lb_txt, f"level_builder_3d.gd: missing long-road stage boundary {z_tag}")

    ok("add_to_group(\"enemies\")" in open(os.path.join(ROOT, "scenes/enemies/flying_wisp_3d.gd"), encoding="utf-8").read(),
       "flying_wisp_3d.gd: must register in enemies group")
    fg_gd = open(os.path.join(ROOT, "scenes/enemies/forest_guardian_3d.gd"), encoding="utf-8").read()
    ok("add_to_group(\"enemies\")" in fg_gd and "engage_radius" in fg_gd,
       "forest_guardian_3d.gd: must register in enemies group and gate on engage_radius")
    ok("size = Vector3(3.2, 3.4, 3.4)" in open(os.path.join(ROOT, "scenes/player/player_3d.tscn"), encoding="utf-8").read(),
       "player_3d.tscn: sword AttackCollider size must cover melee vertical & forward reach")
    ok("0, 2, -8)" in fg_props.get("transform", "") or "0, 2.0, -8)" in fg_props.get("transform", ""),
       f"level_3_boss_3d.tscn: ForestGuardian3D must sit at reachable y=2.0, got {fg_props.get('transform')}")
    ag_props = l4_nodes.get("Enemies/AstralGuardian", {})
    ok("0, 2, -4893)" in ag_props.get("transform", "") or "0, 2.0, -4893)" in ag_props.get("transform", ""),
       f"level_4_astral_3d.tscn: AstralGuardian must sit at reachable y=2.0 at end of sky-road, got {ag_props.get('transform')}")

    for mat in (
        "resources/materials3d/char_cloak.tres",
        "resources/materials3d/char_leather.tres",
        "resources/materials3d/rune_stone.tres",
        "resources/materials3d/metal_filigree.tres",
        "resources/materials3d/crystal_prism.tres",
    ):
        ok(os.path.isfile(os.path.join(ROOT, mat)), f"Missing required 3D material: {mat}")

    for helper in (
        "scenes/common/mesh_factory_3d.gd",
        "scenes/player/player_visuals_3d.gd",
        "scenes/enemies/guardian_visuals_3d.gd",
        "scenes/world/props_visuals_3d.gd",
        "scenes/world/kill_zone_3d.gd",
        "scenes/world/spike_trap_3d.gd",
    ):
        ok(os.path.isfile(os.path.join(ROOT, helper)), f"Missing required 3D helper/script: {helper}")

    env_txt = open(os.path.join(ROOT, "resources/world_environment_3d.tres"), encoding="utf-8").read()
    for flag in ("ssr_enabled = true", "ssao_enabled = true", "ssil_enabled = true", "volumetric_fog_enabled = true", "glow_enabled = true"):
        ok(flag in env_txt, f"world_environment_3d.tres: missing {flag}")

    player_nodes = parse_tscn_nodes(os.path.join(ROOT, "scenes/player/player_3d.tscn"))
    ok("VisualRig/HitSparks" in player_nodes, "player_3d.tscn: missing VisualRig/HitSparks GPUParticles3D")
    ok("Audio/Footstep" in player_nodes, "player_3d.tscn: missing Audio/Footstep")
    ok("Audio/Dash" in player_nodes, "player_3d.tscn: missing Audio/Dash")
    boss_nodes = parse_tscn_nodes(os.path.join(ROOT, "scenes/enemies/forest_guardian_3d.tscn"))
    ok("HitSparks" in boss_nodes, "forest_guardian_3d.tscn: missing HitSparks GPUParticles3D")


if __name__ == "__main__":
    test_project_godot()
    test_res_references_and_tscn_tres()
    test_onready_paths_and_physics_layers()
    test_assets_integrity()
    test_levels_completeness()

    if ERRORS:
        print(f"FAILED {len(ERRORS)}/{CHECKS} checks:")
        for err in ERRORS:
            print("  -", err)
        sys.exit(1)
    print(f"ALL {CHECKS} 3D STATIC & STRUCTURAL VERIFICATION CHECKS PASSED.")
