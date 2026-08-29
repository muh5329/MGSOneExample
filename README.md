# Shadow Circuit

An original Godot 4 stealth-action vertical slice. The current build boots into the playable seven-room Substation 6 graybox with a functional optional pistol, transactional pickups, and keyboard/controller equipment panels; the authoritative mission target is in [`docs/VERTICAL_SLICE.md`](docs/VERTICAL_SLICE.md).

## Requirements

- Godot `4.7.stable.official.5b4e0cb0f` (standard editor build)
- Compatibility renderer; no generated `.godot/` state is required

## Run

Open `project.godot` in Godot and press F6/F5, or run:

```sh
godot --path .
```

On macOS, when Godot is not on `PATH`:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Validate a clean checkout

```sh
godot --headless --path . --editor --quit-after 2
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/player_movement_test.gd
godot --headless --path . --script res://tests/camera_aim_test.gd
godot --headless --path . --script res://tests/level_interaction_test.gd
godot --headless --path . --script res://tests/weapon_combat_test.gd
godot --headless --path . --script res://tests/inventory_items_menu_test.gd
godot --headless --path . --quit-after 3
```

The smoke test exits nonzero when a required input, collision name, autoload, scene, or shared resource is missing.

## Export

Install matching Godot export templates, then use the checked-in macOS preset:

```sh
godot --headless --path . --export-debug "macOS" build/ShadowCircuit.dmg
```

`build/`, `exports/`, and `.godot/` are intentionally ignored.

# MGSOneExample
