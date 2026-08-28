# Decision Log

Keep only decisions that affect more than one subsystem. Newest entries first.

## 2026-08-28 — Vertical Slice Locked

- The authoritative mission is the seven-room `Substation 6` route in `VERTICAL_SLICE.md`, with four guards, one pistol, one ration, one access level, ten camera zones, and two checkpoints.
- First-person aim roots translation; it allows bounded look, defers camera-zone transitions, and exits for modal UI.
- Detection is recoverable: the global sequence is ALERT → EVASION → SEARCH → NORMAL, and alerts never lock progression.
- Access card, unlocked security door, completed objective, and inventory are checkpoint state; transient alert/guard suspicion resets.

## 2026-08-28 — Foundation Contracts Pinned

- Pin engine version `4.7.stable.official.5b4e0cb0f`, Compatibility renderer, 60 Hz physics, 1280×720 reference viewport, and a 60 fps desktop target.
- Use only two initial autoloads: `GameState` for global mission/pause authority and `EventBus` for typed noise routing. Settings waits for a persistence consumer.
- Canonical input names and seven 3D collision layers live in `project.godot` and are published in `INTERFACES.md`.
- Debug presentation requires both a debug build and an enabled `DebugConfig`; release configuration defaults off.
- Commit engine-generated `.uid` sidecars, never `.godot/`; do not manually invent or transplant resource UIDs.

## 2026-08-28 — Greenfield Recovery

- Treat the current workspace as greenfield because only generated `.godot` cache files remain.
- Target Godot 4.x; the foundation owner pins the exact engine version.
- Use primitive graybox art first and keep visual replacement independent of game logic.
- Use typed GDScript and signal/interface boundaries by default.
- Require keyboard/mouse and controller support for the vertical slice.
- Maintain original/licensed content for any distributed build; references guide mechanics and mood only.
