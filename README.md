# The Lost Golden Compass 3D

A richly detailed **pure Godot 4 (GDScript only)** 3D dark-fantasy action-adventure built for the **Godot 4 Web Editor (`gl_compatibility` / WebGL2)** and desktop Godot 4.

## Opening & Running in Godot 4 Web Editor
1. Open [https://editor.godotengine.org/releases/latest/](https://editor.godotengine.org/releases/latest/).
2. Import this project folder (or zip it and import the archive).
3. Press **Play (F5)** — launches directly into **Stage 1 — Whispering Canopy Forest** (`res://scenes/levels/level_1_3d.tscn`), with full access to all 4 stages and the 3D Main Menu via **Esc -> Return to Main Menu**.

## Four Multi-Kilometer 3D Adventures
- **Stage 1 — Whispering Canopy Forest (4.6 km)**: Winding cobblestone & forest earth road, trailhead archways, 5 arched timber river bridges, glowing mushroom hollows, hidden fern-veil alcoves, wayshrines, and Forest Wisps.
- **Stage 2 — Misty Highland Ridge Road (4.8 km)**: Rolling highland ridges, 5 carved stone viaduct bridges over misty gorges, rocky cliff crags, iron spike traps, timed thorn gauntlets, and Elder Wisps.
- **Stage 3 — Guardian's Sanctum Causeway (4.4 km)**: Sacred fluted-pillar temple avenue, rune monoliths, 4 ceremonial moat bridges, and the Grand Colosseum battle against the **Forest Guardian** to claim the Golden Compass and awaken the Northern Astral Portal.
- **Stage 4 — Celestial Cloudway Sanctuary (4.9 km)**: Starlit stone sky-road high above billowing 3D cloudbanks (`cloud_bank_3d.gdshader`), floating crystal sky-islands, celestial bridges, and the **Astral Guardian** final battle unlocking **Adventure Cycles (NG+)**.

## Project Structure
- `project.godot` — Godot 4 `gl_compatibility` configuration, 3D physics layers, audio bus layout, and input map.
- `autoloads/` — `game_manager.gd` global singleton (vitality, score, crystals, Golden Compass signals, 4-stage progression, Adventure Cycles).
- `scenes/` — Pure 3D scenes & GDScript (`levels/`, `player/`, `enemies/`, `world/`, `ui/`, `common/`).
- `resources/` — WebGL2-safe GLSL `.gdshader` files, PBR `.tres` materials, particle materials, fonts, audio bus layout, and `world_environment_3d.tres`.
- `assets/` — 3D PBR textures (`textures3d/`), UI icons (`sprites/`), and original music/ambience/SFX (`audio/`).

## Controls
| Action | Keyboard / Mouse | Gamepad |
| :--- | :--- | :--- |
| **Move (3D)** | `W` `A` `S` `D` or Arrow Keys | Left Stick / D-Pad |
| **Toggle Auto-Run** | `F` (`S` stops) | — |
| **Sprint** | `Shift` | Left Stick Click (`L3`) |
| **Evade Dash** | `Right Click` or `C` | `B` / Circle |
| **Golden Compass Pulse** | `G` | `Y` / Triangle |
| **Camera Look / Turn** | Mouse Move or `Q` / `E` | Right Stick |
| **Camera Zoom** | Mouse Scroll Wheel | — |
| **Sword Combo (3-Hit)** | `Left Click`, `J`, or `Z` | `X` / Square |
| **Pause / Settings** | `Esc` or `P` | Start |
| **Restart Adventure** | `R` | Select |
