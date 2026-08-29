# Decision Log

Keep only decisions that affect more than one subsystem. Newest entries first.

## 2026-08-28 — Camera and Aim Integration Contract

- One `GameplayCameraRig` owns the current gameplay camera. Authored mathematical volumes select by priority, preserve the current equal-priority overlap, and use lexical zone ID only as a final deterministic tie-break.
- First-person aim is contextual and rooted: equipment/modal/interaction owners provide narrow gates, the camera sets only the player's AIM lock, and zone changes wait until aim exits.
- Weapons consume camera-owned origin/direction APIs rather than camera node paths. Settings are resource-backed now and may gain persistence later without changing this boundary.
- Level-authored angles and occluded handoffs are the first obstruction solution; runtime pull-in and near-wall rejection are safety nets, not replacements for valid mission framing.

## 2026-08-28 — Player Movement Integration Contract

- Camera-relative direction latches the supplied camera basis while movement input remains held; camera transitions affect the next input gesture after neutral, avoiding an involuntary reversal.
- Movement locks are a composable bitmask owned by the player motor. Aim, menus, death, and scripted consumers set and clear only their own reason.
- Hearing receives normalized, periodic `NoiseEvent3D` events derived from actual grounded speed, stance, and a surface multiplier; input presses alone never produce noise.
- Player body origin stays at the feet with a 0.4 m capsule radius, 1.8 m standing height, and 1.2 m crouched height so level and camera owners can author consistent clearances.

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
