# Code Map

Updated: 2026-08-28

## Runtime entry points

- `project.godot` — project configuration, semantic inputs, autoloads, and collision-layer names.
- `scenes/core/bootstrap.tscn` + `scripts/core/bootstrap.gd` — main entry point and explicit initial-level failure reporting.
- `scenes/levels/foundation_test_room.tscn` — disposable movement/controller/pause verification room; replace its content, not the bootstrap contract.
- `scripts/core/game_state.gd` — mission-phase and pause-authority skeleton (`GameState` autoload).
- `scripts/core/event_bus.gd` + `noise_event.gd` — typed global noise-routing seam (`EventBus` autoload).
- `data/debug/*.tres` — debug-on development and debug-off release configurations.
- `tests/smoke_test.gd` — headless contract/startup validation.
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
