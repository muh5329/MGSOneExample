# Code Map

Updated: 2026-08-28

## Runtime entry points

- `project.godot` — project configuration, semantic inputs, autoloads, and collision-layer names.
- `scenes/core/bootstrap.tscn` + `scripts/core/bootstrap.gd` — main entry point, camera-lab bootstrap, and explicit initial-level failure reporting.
- `scenes/actors/player.tscn` + `scripts/actors/player_controller.gd` — reusable capsule player, camera-relative motor, stance, control locks, animation outputs, and movement noise.
- `data/player/default_player_movement_config.tres` — player speed, acceleration, body, slope, gravity, and noise tuning.
- `scenes/camera/gameplay_camera_rig.tscn` + `scripts/camera/gameplay_camera_rig.gd` — sole gameplay-camera owner, deterministic zone handoff/blending, contextual aim, aim rays, obstruction response, impulses, and debug output.
- `scripts/camera/camera_zone_3d.gd` + `camera_zone_data.gd` — authored mathematical camera volumes and reusable framing/priority/blend data.
- `data/camera/default_camera_aim_settings.tres` — mouse/controller look, inversion, limits, FOV, zone hysteresis, and obstruction tuning.
- `scenes/levels/camera_aim_test_room.tscn` — current bootstrap level and camera/aim regression lab; `locomotion_test_room.tscn` remains the focused movement lab and now uses the shared rig.
- `scripts/core/game_state.gd` — mission-phase and pause-authority skeleton (`GameState` autoload).
- `scripts/core/event_bus.gd` + `noise_event.gd` — typed global noise-routing seam (`EventBus` autoload).
- `data/debug/*.tres` — debug-on development and debug-off release configurations.
- `tests/smoke_test.gd` — headless foundation contract/startup validation.
- `tests/player_movement_test.gd` — player direction, camera-basis, lock, noise, collider, and blocked-uncrouch checks.
- `tests/camera_aim_test.gd` — zone priority/hysteresis, blend/defer behavior, aim gates/locks/limits, center ray, pause, fallback, and camera ownership checks.
- `docs/VERTICAL_SLICE.md` — authoritative mission flow, placements, tuning, and acceptance scripts.

## Layout

```text
project.godot            # Godot 4.7 project and shared contracts
assets/                 # source-controlled original/licensed content
data/                   # Resource definitions and tuning data
scenes/
  actors/               # player and guards
  components/           # reusable gameplay components
  levels/               # mission and test rooms
  ui/                   # HUD, menus, settings
scripts/
  actors/
  camera/
  combat/
  core/
  interaction/
  inventory/
  stealth/
  ui/
tests/                  # headless tests and focused verification scenes
docs/                   # concise cross-agent truth
plans/                  # subsystem ownership briefs
```

## Run, test, and export

From the repository root, with the pinned Godot binary on `PATH`:

```sh
godot --path .
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --export-debug "macOS" build/ShadowCircuit.dmg
```

Use `godot --headless --path . --editor --quit-after 2` for a clean import check. Export requires matching templates. See the root `README.md` for the macOS application-bundle command.

## Recovery Note

Any deleted prototype names found only inside `.godot/` remain generated-cache artifacts and are not dependencies.
