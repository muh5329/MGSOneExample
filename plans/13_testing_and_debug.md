# Build Step 13 — Testing and Debug Tooling

## Assignment

One agent/chat owns the test harness, automated smoke/contract/regression tests, gameplay verification scenes, debug overlay framework, test commands, and result reporting. Subsystem owners remain responsible for fixing their defects.

## Objective

Make integration failures quick to reproduce and diagnose, especially at subsystem boundaries involving input modes, collision, perception, alert state, inventory, and checkpoint resets.

## Scope

- Headless startup/smoke test and reusable assertion/test runner conventions.
- Contract tests for input actions, groups/layers, damage, inventory, alert transitions, snapshots, and settings.
- Deterministic scenes for movement/camera, doors/interactions, combat, AI perception, alert/radar, UI, and checkpoint restart.
- Debug overlay toggles for FPS, room/camera zone, player mode/noise, aim ray, collisions, guard state/cones/rays/path, alert phase/timers, and checkpoint IDs.
- End-to-end playthrough checklist and captured result template.
- Performance budgets and repeatable stress scenario.

## Non-Goals

- Rewriting subsystem logic to make tests pass, visual polish, or pretending frame-dependent behaviors are deterministic without controlling time/randomness.

## Dependencies

- Build Step 00 test convention and command.
- All subsystem public contracts and debug snapshots.
- Build Step 01 three canonical playthrough scripts.

## Public Boundary

- Debug tools consume read-only snapshots or explicitly marked test hooks.
- Test-only controls are disabled in release builds and cannot silently alter production behavior.
- Every regression test names the bug/contract it protects and its owning subsystem.

## Activities

1. Create a one-command local/headless test entry point with reliable exit codes.
2. Turn shared interface requirements into contract assertions.
3. Add minimal isolated scenes using fakes for dependencies rather than importing the entire mission.
4. Add fixed-seed/fixed-step support for perception, search, and timing-sensitive scenarios where feasible.
5. Build composable debug overlay panels and world gizmos with centralized enable/disable settings.
6. Implement stress scenarios for multiple guards, repeated shots/effects, rapid menus, and checkpoint loops.
7. Automate startup and mission-scene load checks; record where end-to-end play still requires manual verification.
8. Define triage severity: blocker, major, minor, observation, with reproduction/evidence requirements.

## Deliverables

- Test runner/commands and isolated verification scenes.
- Contract/regression tests and debug overlay framework.
- Performance/stress scenario and manual release checklist.
- Updated shared docs and handoff.

## Acceptance Criteria

- Tests run from a clean checkout/import and return nonzero on failure.
- Each shared contract has at least a validation assertion or explicit manual check.
- AI/perception failures show state, target, rays, cone, path, and timing evidence.
- Debug mode can be disabled globally and is off in release export.
- The three canonical playthrough scripts are reproducible and record outcomes.
- Repeated checkpoint, menu, alert, and combat cycles expose no growing node/resource count beyond documented caching.
- Test failures identify the owning subsystem and a useful reproduction.

## Handoff

Document exact commands, test categories, debug keys/settings, deterministic limitations, performance hardware/budgets, current failures, and how agents add new regressions.

## Critic Review

- Do tests verify behavior/contracts or implementation details?
- Are timing and randomness actually controlled where claimed?
- Can the debug layer itself change performance or state enough to hide defects?
- Are the highest-risk integration boundaries covered?
- Does a clean failure provide enough evidence for another agent to act without reopening the entire project?

