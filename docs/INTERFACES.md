# Subsystem Interfaces

Updated: 2026-08-28

This is the shared contract ledger. Foundation names below are accepted. Agents may refine signatures, but must update all consumers and this file in the same change.

## Accepted Foundation Contracts

### Input

- Movement: `move_left`, `move_right`, `move_forward`, `move_back`.
- First-person look: `look_left`, `look_right`, `look_up`, `look_down`; mouse motion is analog camera input handled by the camera owner.
- Gameplay: `aim`, `fire`, `reload`, `crouch`, `interact`, `weapon_menu`, `item_menu`, `quick_use`, `pause`.
- UI: `ui_accept`, `ui_cancel`, `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_focus_next`, `ui_focus_prev`.
- Development only: `debug_toggle`; runtime debug presentation must additionally require `OS.is_debug_build()` and an enabled debug resource.
- Gameplay code reads actions, not raw keys/buttons. Defaults in `project.godot` cover keyboard/mouse and a standard controller. The authoritative mode behavior is in `VERTICAL_SLICE.md`.

### Pause and global services

- `GameState` is the sole pause/mission-phase authority. `set_paused(bool)` updates `SceneTree.paused`, emits `pause_changed(bool)`, and transitions the public `MissionPhase` enum.
- Always-interactive menu roots use `PROCESS_MODE_ALWAYS`; gameplay remains pausable/inheritable.
- `EventBus.emit_noise(NoiseEvent3D)` emits `noise_emitted(event)`. `NoiseEvent3D` contains source, world position, nonnegative loudness, and category. Perception consumes the signal; producers do not locate guards.
- No settings autoload exists yet. Build Step 12 may add one when persistence has a real consumer.

### Collision layers and query masks

| Layer | Name | Ownership/use |
|---:|---|---|
| 1 | `world` | Solid authored environment; character bodies query it. |
| 2 | `player_body` | Player physical body. |
| 3 | `enemy_body` | Guard physical bodies. |
| 4 | `damageable_hitbox` | Query-only hurtboxes for player/guards/targets. |
| 5 | `interaction_query` | Query-only interactable targets. |
| 6 | `perception_blocker` | Opaque sight blockers; solid walls normally occupy layers 1 and 6. |
| 7 | `pickup` | Query-only pickup targets. |

Canonical masks: player body `1|3`, enemy body `1|2`, hitscan `1|4`, interaction focus `5|7`, and perception ray `4|6`. Query-only targets use mask 0 unless their subsystem documents a deliberate overlap requirement.

### Groups and resource identity

- `player` is the only global group with a current consumer. Add `guards`, `damageable`, `interactable`, `camera_zones`, or `checkpoint_targets` with the first real consumer rather than speculatively.
- Commit Godot-generated `.uid` sidecars for source scripts/resources. Do not hand-author, copy, or renumber UIDs; resolve moves through the editor or update all path consumers in the same change.

## Accepted Subsystem Boundaries

- Player movement exposes velocity, stance, movement-noise level, control-enabled state, and aim-mode requests.
- Camera owns the active view mode and exposes aim origin/direction; weapons do not inspect camera node paths.
- Interaction targets expose prompt text, availability, and an `interact(actor)` operation.
- Damage receivers accept a value plus hit context and emit health/death changes.
- Inventory owns quantities and equipment state and emits change signals; UI never mutates its dictionaries directly.
- Weapons consume inventory ammunition through a narrow inventory API and submit hits through the damage contract.
- Perception consumes observable target position, stance/visibility modifiers, and emitted noise events.
- Guards report local suspicion/detection to the alert coordinator; they do not directly control the radar or global UI.
- Alert coordinator exposes a single authoritative phase and phase changes.
- Radar reads public guard/perception snapshots and alert restrictions; it never reaches into guard state-machine internals.
- Game-state/checkpoint service owns mission phase, pause/death transitions, and checkpoint snapshots.

## Contract Change Rule

Before breaking a shared contract, record the reason in `DECISIONS.md`, identify every consumer in `CODE_MAP.md`, and coordinate the change in `STATUS.md`/`HANDOFF.md`.
