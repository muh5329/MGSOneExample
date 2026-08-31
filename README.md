# Shadow Circuit

An original Godot 4 stealth-action vertical slice. The current release candidate boots into the playable seven-room Substation 6 mission with coordinated patrol/search/combat guards, recoverable alerts, tactical radar, contextual aim and combat, inventory/health/checkpoint outcomes, replaceable actor visuals, bounded original procedural audio/VFX, an authoritative-snapshot HUD, persistent accessibility/settings/remapping, keyboard/controller menu focus, and debug-off release presentation. The mission contract is in [`docs/VERTICAL_SLICE.md`](docs/VERTICAL_SLICE.md); exact test and remaining manual release gates are in [`docs/TESTING_AND_RELEASE.md`](docs/TESTING_AND_RELEASE.md).

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
godot --headless --path . --editor --quit-after 3
tests/run_all.sh
godot --headless --path . --quit-after 3
```

The runner executes all 12 contract suites and exits nonzero on the first failure. Set `GODOT_BIN` when Godot is not on `PATH`.

## Export

Install matching Godot export templates, then use the checked-in macOS preset:

```sh
godot --headless --path . --export-debug "macOS" build/ShadowCircuit.dmg
godot --headless --path . --export-pack "macOS" build/ShadowCircuit.pck
```

`build/`, `exports/`, and `.godot/` are intentionally ignored.

# MGSOneExample
