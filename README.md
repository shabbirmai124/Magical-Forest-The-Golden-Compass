# The Lost Golden Compass 3D

A richly detailed **Godot 4.7.2** 3D dark-fantasy action-adventure built 100% natively with Godot's Forward+ renderer, custom GLSL sky/water/cloud/foliage/cloth shaders, full PBR triplanar terrain mapping, procedurally sculpted articulated 3D characters & monsters (`MeshFactory3D`), streaming multi-kilometer continuous roads, atmospheric SSR/SSAO/SSIL/Volumetric Fog lighting, smooth aesthetic UI & scene transitions, and pure GDScript.

Journey through **four distinct multi-kilometer (~4.4 km – 4.9 km each, ~10+ minutes per stage)** continuous 3D adventures beneath an expansive cosmic night sky:
1. **Stage 1 — Whispering Canopy Forest (`4.6 km`)**: Winding emerald forest trail, 5 arched timber river bridges, glowing mushroom hollows, hidden fern-veil alcoves, wayshrines, and Forest Wisps.
2. **Stage 2 — Misty Highland Ridge Road (`4.8 km`)**: Sweeping rolling highland hills & mountain pass ridges, 5 carved stone viaduct bridges over misty gorges, rocky cliff crags, timed thorn ruin gauntlets, and Elder Wisps.
3. **Stage 3 — Guardian's Sanctum Causeway (`4.4 km`)**: Sacred fluted-pillar temple avenue, glowing rune monoliths, 4 ceremonial moat bridges, and the **Grand Colosseum** battle against the **Forest Guardian** to claim the **Golden Compass** and awaken the **Northern Astral Portal**.
4. **Stage 4 — Celestial Cloudway Sanctuary (`4.9 km`)**: Elevated starlit stone sky-road **high above luminous billowing 3D cloudbanks (`cloud_bank_3d.gdshader`)**, flanked by floating crystal sky-islands, silver-leaf trees, stone balustrades, celestial sky-bridges, and the **Astral Crown Summit** final boss battle unlocking **Adventure Cycles (NG+)**.

---

## Features & Highlights

- **Ultra-Detailed 4-Biome Streaming Continuous Worlds (`scenes/levels/level_builder_3d.gd` + `MeshFactory3D`):**
  - Seamless 200 m streaming terrain chunks with indexed finite-difference normal continuity across chunk boundaries, PBR triplanar terrain blending (`road_terrain_3d.gdshader`), distance-faded flickering trail lanterns, and per-stage atmosphere tuning.
  - **Celestial Cloud Sea (`resources/shaders/cloud_bank_3d.gdshader`)**: Custom volumetric-look billowing 3D cloudbanks with Fresnel rim scattering drifting beside and below the Stage 4 Sky-Road.
- **Articulated 3D Hero Explorer & Responsive Sword Combat (`scenes/player/`):**
  - Articulated **knee & elbow joints**, knee guards, layered mantle & compass brooch, flowing pleated cloth cape (`cloak_cloth_3d.gdshader`), pendulum-swinging wrought-iron lantern, and fullered diamond Rune Broadsword (`player_visuals_3d.gd`).
  - **3-Hit Sword Combo** with input buffering, smart camera/enemy aim-facing, wide vertical + horizontal melee hit detection, boss-orb sword deflection, and **Optional Continuous Auto-Run (`F`)** alongside full `WASD` movement.
- **Articulated Enemies & Two-Phase Bosses (`scenes/enemies/`):**
  - **Forest Wisps & Elder Wisps**: Carved stone cowl & antlers, dual counter-rotating gyro-rings, flapping mantle wings, waving spectral tendrils, floating diegetic HP pips, hitstun knockback, and emissive hit flashes.
  - **Forest Guardian & Astral Guardian**: Articulated upper arms & stone gauntlets, rib plates around the glowing heart core, 8 orbital rune spires, arena engagement range (`38 m`), reachable melee hitbox, Phase 2 expanding **Shockwave Nova** waves, and Golden Compass drop.

---

## Controls

| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| **Move (3D)** | `W` / `A` / `S` / `D` or Arrow Keys | Left Stick / D-Pad |
| **Toggle Auto-Run** | `F` (`S` stops) | — |
| **Sprint** | `Shift` | Left Stick Click (`L3`) |
| **Evade Dash** | `Right Click` or `C` | `B` / `Circle` |
| **Camera Look / Turn** | Mouse Move or `Q` / `E` | Right Stick |
| **Camera Zoom** | `Mouse Scroll Wheel` | — |
| **Sword Combo (3-Hit)** | `Left Click`, `J`, or `Z` | `X` / `Square` |
| **Pause / Settings** | `Esc` or `P` | `Start` |
| **Restart Adventure** | `R` | `Select` |

---

## Automated Verification

Run the comprehensive static & structural verification suite anytime with Python 3:

```bash
python tests/verify_project.py
```
