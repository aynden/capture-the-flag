# Capture the Flag — Golden Hour Paintball Arena

A top-down 3D 4v4 tactical paintball **Capture the Flag** game built with **Godot 4.7** and **Blender 5.3**.

## Features
- **4v4 Paintball CTF**: Team Cobalt (Blue — you + 3 role-based AI teammates) vs. Team Ember (Coral-Orange — 4 AI opponents).
- **Custom Blender 3D Assets**: 28 sculpted models including articulated paintball competitors with thermal visor masks, electronic markers (with translucent hoppers & HPA tanks), speedball bunkers (Dorito, Temple, Cylinder, Snake), timber barricades, supply crates, sandbag walls, flag pedestals, flags, bleachers with spectators, floodlight towers, and mixed pine/oak park foliage.
- **Custom Shaders & Persistent Paint Splatters**: Sunlit mowed athletic turf shader with painted endzones, wind-rippling cloth flags, animated capture zone rings, Fresnel hit-rim flashes, and glossy paint splatters across the arena.
- **Desktop & Web Ready**: Runs on Forward+ (Metal/Vulkan) for desktop and automatically adapts to WebGL 2 (`gl_compatibility`) for browser play.

## Controls
- **`WASD` / Arrow Keys** — Move
- **`Mouse`** — Aim
- **`Left Click`** — Fire Paintball Marker
- **`Space` / `Shift` / `Right Click`** — Tactical Slide / Dash
- **`R`** — Reload Paintball Pod
- **`Q` / `E`** — Squad Orders (*Attack!* / *Defend!*)
- **`Esc`** — Pause

## Running Locally
### In Godot 4.7+
Open `project.godot` in Godot and press **Play** (`F5` / `Cmd+B`).

### In the Browser (Web Build in `web/`)
```bash
python3 -m http.server 8080 --directory web
```
Then open `http://localhost:8080`.

### Regenerating Blender Assets
Editable `.blend` files live in `blender_assets/`, and procedural generators live in `blender_scripts/` (`gen_textures.py`, `gen_audio.py`, `gen_characters.py`, `gen_arena_props.py`, `gen_environment.py`).
