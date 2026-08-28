# Build Step 14 — Integration, Balance, and Release

## Assignment

One integration agent/chat owns the playable mission assembly, dependency reconciliation, cross-system tuning, release checklist, export configuration, and final handoff. It does not silently rewrite subsystem contracts; boundary fixes are coordinated with owners and documented.

## Objective

Turn completed subsystems into one coherent, stable, performant vertical slice, validate stealth and detected playthroughs, and produce a clean exported build with honest known limitations.

## Scope

- Assemble bootstrap, level, player, cameras, interactions, inventory, weapons, health, guards, alerts, radar, feedback, UI, and mission outcomes.
- Resolve ordering, ownership, pause, scene lifecycle, and checkpoint-reset defects.
- Tune movement, cameras, sight/hearing, suspicion, alert/search, damage, ammo, rations, patrols, and encounter pacing together.
- Run accessibility, control, resolution, performance, clean-import, and exported-build validation.
- Verify asset licensing/provenance and remove debug/test-only presentation from release.
- Freeze release candidate and record defects/deferred work.

## Non-Goals

- Adding major features, final commercial content, a second mission, or redesigning stable subsystems without evidence.

## Dependencies

- All prior build steps meet their acceptance criteria or have an explicitly accepted limitation.
- Build Step 01 canonical playthrough scripts and Build Step 13 verification tools are current.

## Integration Order

1. Bootstrap, game state, level, player movement, and camera traversal.
2. Interaction, pickups, inventory, menus, objective, and checkpoint flow.
3. Aim, weapons, damage, health, death, and restart.
4. One guard perception/state loop, then alert/radar, then remaining guards.
5. Animation, audio/VFX, HUD/settings, and accessibility presentation.
6. Balance, performance, regression, export, and critic review.

## Activities

1. Verify every dependency against its documented interface rather than inferred node hierarchy.
2. Create a release configuration and stable mission entry point.
3. Run the stealth, detected-recovery, and death/restart scripts after each integration tier.
4. Fix source-of-truth conflicts first; avoid UI-side or scene-order workarounds.
5. Tune with recorded values and reasons, then update data resources rather than scattered literals.
6. Test controller/keyboard handoff, every modal transition, every camera zone, all door/item states, multiple alert cycles, and repeated checkpoint resets.
7. Profile worst-case guard/physics/render/audio scenarios on named target hardware.
8. Perform a clean checkout/import/test/export and run the exported build without editor cache.
9. Remove or gate cheats, debug overlays, verbose logs, and test spawns.
10. Ask a separate critic to execute the global and subsystem critic questions and record findings in `docs/CRITIC_REPORT.md`.

## Deliverables

- Integrated mission scene and release configuration.
- Tuning baseline and verified test results.
- Exported vertical-slice build or reproducible export instructions.
- Completed `docs/CRITIC_REPORT.md`, known-issues list, and final shared-doc handoff.

## Acceptance Criteria

- All global acceptance criteria in `BUILD_PLAN.md` pass in the exported build.
- Canonical stealth, detected-recovery, and death/restart playthroughs complete without reload-only workarounds.
- No subsystem uses stale `.godot` cache content or editor-only state.
- Keyboard/mouse and controller support gameplay and every menu path.
- Frame rate and frame pacing meet the recorded target in the worst vertical-slice encounter.
- No blocker or major critic finding remains open; accepted minors have owners/rationale.
- Clean import, automated checks, export, and launch are reproducible from documentation.

## Handoff

Record build identifier, Godot version, export target, exact commands, canonical-test results, performance hardware/results, known issues, licenses, critic disposition, and next recommended milestone.

## Critic Review

- Does the exported build demonstrate the promised experience from start to finish?
- Are stealth, combat, alert recovery, inventory, first-person aim, and checkpoint restart all naturally exercised?
- Are any apparent fixes actually ordering hacks, duplicated truth, or undocumented coupling?
- Is the difficulty fair when perception, camera, controls, and feedback interact?
- Does the build work from clean source without cache or local editor assumptions?
- Are performance, accessibility, licensing, and known limitations reported honestly?
- What are the three highest-risk defects, and does each have evidence, severity, and an owner?

