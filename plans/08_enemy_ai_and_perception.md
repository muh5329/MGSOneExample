# Build Step 08 — Enemy AI and Perception

## Assignment

One agent/chat owns guard actors, navigation, perception, suspicion, decision states, combat requests, and guard debug visualization. Global alert coordination and radar rendering remain separate.

## Objective

Create guards whose cone-based vision and hearing are legible, occlusion-aware, tunable, and capable of patrolling, investigating, pursuing, searching, fighting, and recovering without state deadlocks.

## Scope

- Guard actor with navigation, facing, movement, health/damage integration, and animation parameters.
- Patrol route authoring with wait/look actions.
- Vision broad phase using range/angle, followed by line-of-sight ray tests to target sample points.
- Hearing of normalized noise events with distance/occlusion tuning.
- Suspicion accumulation/decay and confirmed detection.
- Explicit states: patrol, suspicious, investigate, alert/chase, attack, search, return, stunned/dead as required.
- Last-known-position memory and finite search pattern.
- Guard-to-alert reports and receipt of alert broadcasts.
- Debug cones, rays, targets, paths, state, suspicion, and timing.

## Non-Goals

- Global alert phase ownership, radar drawing, sophisticated squad tactics, cover shooting, stealth takedowns, or final animations.
- Reading player input, UI state, or camera nodes.

## Dependencies

- Build Step 00 collision/group/navigation contracts.
- Build Step 02 movement-noise/stance output.
- Build Step 04 level navigation and sight blockers.
- Build Step 05 weapon/damage contract.
- Build Step 07 health/reset contract.
- Build Step 09 alert coordinator contract.

## Public Boundary

- Perception consumes observable targets and noise events through defined adapters.
- Guard emits suspicion/detection/lost-target/combat/state snapshots.
- Guard submits alert observations; global alert decides shared phase.
- Radar receives a sanitized perception snapshot, never the guard state-machine object.

## Activities

1. Build a guard scene separating motor, perception, decision state, health, and visuals.
2. Implement patrol points with deterministic traversal and robust unreachable-target handling.
3. Implement cone checks using horizontal/vertical constraints and configurable target sample points.
4. Raycast only after the angular/range check; define which collision layers block sight.
5. Accumulate suspicion based on distance, exposure duration, stance/visibility, and alert context; include hysteresis to prevent flicker.
6. Implement hearing from emitted events rather than direct player distance polling.
7. Implement state transitions with enter/exit actions, timeouts, interruption rules, and a safe fallback.
8. Implement last-known-position pursuit, bounded search points, and return-to-route.
9. Integrate attack requests through the combat/damage contract with fair telegraphing.
10. Add deterministic scenarios for partial sight, occlusion, noise diversion, multiple reports, lost paths, target death, guard death, and checkpoint reset.

## Deliverables

- Reusable guard scene, patrol route component, perception component, and state logic.
- Guard configuration/tuning resource.
- AI laboratory scene and debug overlays.
- Automated deterministic tests where feasible and updated shared docs.

## Acceptance Criteria

- Solid world geometry blocks sight; radar/debug cone never claims visibility through it.
- Brief edge exposure creates suspicion rather than unavoidable instant detection, except at documented close range.
- Noise causes investigation of an event location, not omniscient tracking.
- Guards pursue last known information, search for a bounded time, then recover to valid patrol behavior.
- Missing paths/targets do not freeze or spam errors.
- Multiple guards can operate within performance targets and share alerts only through the coordinator.
- Damage, death, pause, and checkpoint restore cannot leave navigation or state logic active incorrectly.

## Handoff

Document guard scene, state diagram, perception formula and masks, noise event shape, alert messages, radar snapshot, debug controls, and tuning defaults.

## Critic Review

- Can the player understand why they were seen or heard?
- Does the visible/debug cone match actual perception, including occlusion and verticality?
- Are suspicion thresholds fair under varying frame rates?
- Can any interrupt, missing path, target death, or alert change deadlock a state?
- Do guards appear intelligent without using information they could not know?

