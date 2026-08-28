# Build Step 09 — Alert, Radar, and Stealth Feedback

## Assignment

One agent/chat owns the authoritative global alert phase, guard report/broadcast coordination, evasion/search timing, tactical radar transformation/rendering, and high-level stealth feedback.

## Objective

Turn individual guard perception into a coherent facility response and give the player honest, readable information about nearby threats and alert recovery.

## Scope

- Alert phases such as normal, alert, evasion/search, and recovery/normal, with explicit transition rules.
- Reports containing observer, target/last-known position, confidence, and time.
- Broadcast/update rules for guards without granting permanent omniscience.
- Timers and conditions for losing contact, searching, and returning to normal.
- Player-centered radar showing local walls/space as appropriate, guards, facing/cones, and alert state.
- Radar rotation/orientation policy and out-of-range/clamped contacts.
- Jammed/disabled radar behavior if the mission design uses it.
- Alert/radar debug overlay and telemetry.

## Non-Goals

- Individual guard state logic, raw perception tests, level navigation, weapon combat, or final HUD styling.
- A complete facility simulation or reinforcements system unless added to scope.

## Dependencies

- Build Step 01 alert design targets.
- Build Step 03 camera/player orientation data if radar orientation depends on it.
- Build Step 04 room/radar bounds.
- Build Step 08 guard reports and sanitized snapshots.
- Build Step 12 HUD presentation.

## Public Boundary

- Coordinator accepts guard reports and exposes one read-only alert snapshot/phase.
- Broadcasts convey bounded shared knowledge and expiry, not direct player references.
- Radar consumes player transform, approved map data, guard snapshots, and alert phase.
- Other systems react to alert signals but cannot set internal timers directly.

## Activities

1. Define a transition table with entry conditions, minimum durations, exit conditions, and knowledge retained in each phase.
2. Implement report validation/deduplication and monotonic alert escalation rules.
3. Implement contact-loss and evasion/search countdown based on whether any guard currently has confirmed sight.
4. Expire shared last-known information and signal guards to resume local search/return behavior.
5. Choose a radar convention—north-up, camera-up, or player-up—and document it.
6. Transform world positions and facing vectors into radar space using one tested conversion path.
7. Render only authorized contacts and cone/range information; apply distance/clamp/culling rules.
8. Add state-change feedback hooks for HUD, music, sound, lighting, and vibration.
9. Test simultaneous reports, reporter death, repeated sightings, pause, checkpoint reset, scene reload, and boundary positions.

## Deliverables

- Alert coordinator with documented state/transition table.
- Tactical radar component and world-to-radar tests.
- Debug display/telemetry and feedback events.
- Updated shared docs and handoff.

## Acceptance Criteria

- One source of truth drives alert UI, guard coordination, audio hooks, and radar restrictions.
- Alert cannot drop while any valid guard has confirmed sight unless design explicitly says so.
- Search eventually terminates and guards recover; pause does not consume timers.
- Guards receive only plausible last-known data and it expires.
- Radar contacts and facing/cones align with the world under every camera/player orientation.
- Disabled/jammed/hidden radar states do not leak information through another layer.
- Checkpoint restart begins in the documented alert phase with no stale reports.

## Handoff

Document transition table, report/broadcast shapes, timers, radar orientation/conversion, culling rules, events, and reset behavior.

## Critic Review

- Is there exactly one authoritative alert phase?
- Does alert escalation/recovery feel fair and explainable?
- Does shared knowledge become implausible omniscience?
- Does radar truthfully match guard perception and world orientation?
- Can simultaneous reports, death, pause, or reset leave timers stuck?

