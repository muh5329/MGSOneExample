# Build Step 02 — Player Movement and Stance

## Assignment

One agent/chat owns the player motor and its outward-facing movement state. Camera, weapons, UI, and inventory remain separate consumers.

## Objective

Create responsive, predictable 3D locomotion for a top-down stealth game, with camera-relative walking, crouching, collision, rotation, and movement-noise output.

## Scope

- `CharacterBody3D` player scene and typed movement controller.
- Camera-relative input converted to world-space planar velocity.
- Acceleration/deceleration, turn behavior, gravity, slope/floor handling, and wall sliding.
- Standing/crouched stance with safe collider transition.
- Control enable/disable gates for menus, death, scripted transitions, and first-person mode.
- Animation parameters independent of the final model.
- Normalized movement-noise output for enemy hearing.
- Focused locomotion test room.

## Non-Goals

- Weapons, health, inventory, final animations, camera implementation, or enemy awareness.
- Prone, climbing, swimming, first-person free movement, or complex takedowns unless scope is later approved.

## Dependencies

- Build Step 00 input/collision contracts.
- Build Step 03 camera-facing basis and mode contract.
- Build Step 09 noise/sneak tuning expectations.

## Public Boundary

- Inputs: movement vector, crouch request, control lock, active camera basis, and aim-mode restrictions.
- Outputs: velocity, facing direction, grounded state, stance, speed ratio, and movement-noise intensity/event.
- The motor must not read UI state or enemy nodes directly.

## Activities

1. Build a capsule-based player scene with clearly separated visual, body, and interaction origins.
2. Implement dead-zone-corrected semantic movement input and camera-relative conversion.
3. Tune acceleration, braking, maximum speeds, rotation, slopes, stairs, corners, and narrow passages.
4. Implement crouch speed and collider resizing with a ceiling check before standing.
5. Define mode behavior: normal movement, crouch, first-person aim, menu lock, damage/death lock, and external scripted lock.
6. Emit animation parameters and avoid direct animation-name coupling.
7. Emit hearing-relevant noise based on stance, actual velocity, and surface multiplier.
8. Build regression cases for wall jitter, camera-zone changes during input, controller diagonal speed, and blocked uncrouch.

## Deliverables

- Reusable player actor/motor scene and script.
- Movement configuration resource or exported tuning values.
- Locomotion test room and automated checks where feasible.
- Updated interface/code-map/status/handoff docs.

## Acceptance Criteria

- Movement direction remains intuitive under every fixed camera orientation.
- Digital and analog input cannot exceed intended diagonal speed.
- Player does not tunnel through walls, jitter at ordinary corners, or stand through ceilings.
- Menu, death, and aim modes cannot leave residual velocity or stuck input.
- Camera transitions do not reverse held input unexpectedly beyond documented design.
- Noise values accurately reflect real movement and stance.
- Placeholder visuals can be replaced without modifying motor logic.

## Handoff

Document tuning values, player scene entry point, collider dimensions, mode API, emitted signals/parameters, and known edge cases.

## Critic Review

- Does movement feel controllable from all camera angles with both input families?
- Are collisions stable in the actual level metrics, not only an empty test room?
- Can crouch state desynchronize from collider or animation state?
- Is noise derived from real motion rather than button presses?
- Has the motor accidentally taken ownership of camera, combat, or UI concerns?

