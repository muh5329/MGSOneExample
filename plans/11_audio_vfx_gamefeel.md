# Build Step 11 — Audio, VFX, and Game Feel

## Assignment

One agent/chat owns audio playback policy, event-to-feedback mapping, lightweight VFX, camera/controller impulse requests, and retro presentation effects that do not reduce gameplay clarity.

## Objective

Make movement, detection, combat, items, menus, damage, and objectives feel responsive and readable with a cohesive placeholder presentation that can later accept final assets.

## Scope

- Event-driven sound hooks for footsteps, stance/surface changes, weapon actions, impacts, pickups, ration use, doors, menu navigation, detection, alert transitions, damage, death, objective, and extraction.
- Audio buses and volume categories for master, music, effects, UI, and ambience.
- Lightweight impact, muzzle, pickup, detection, damage, and objective VFX.
- Camera shake and controller vibration requests with intensity/duration limits.
- Optional retro/PS1-inspired rendering pass with toggles and readability safeguards.
- Concurrency, pooling, spatialization, and cleanup policy.

## Non-Goals

- Composing a full soundtrack, copying original game audio, elaborate particle simulation, or making feedback systems authoritative over gameplay.

## Dependencies

- Event contracts from Builds 02, 05–09.
- Build Step 12 settings/UI hooks.
- Build Step 14 performance and accessibility validation.

## Public Boundary

- Gameplay emits semantic events; feedback maps them to assets and presentation.
- Feedback never decides hits, damage, detection, inventory, or alert state.
- Camera and vibration effects are requests routed through their respective owners/settings.
- All effects can be disabled or scaled without changing simulation.

## Activities

1. Build an event matrix listing gameplay event, sound, VFX, camera impulse, vibration, priority, and cooldown.
2. Configure audio buses and expose linear/user-friendly settings conversion.
3. Implement pooled or bounded one-shot playback and spatial audio defaults.
4. Implement footstep timing/surface hooks that reflect actual motion and stance.
5. Add clear detection/alert cues distinct from suspicion cues.
6. Add weapon/pickup/damage/objective effects with strict lifetime cleanup.
7. Implement optional retro rendering settings and test UI/radar readability with every effect enabled.
8. Test high-event scenarios for clipping, voice starvation, spawned-node leaks, flashing, and excessive shake.

## Deliverables

- Feedback event matrix and routing components.
- Audio bus layout, placeholder original/licensed sounds, and bounded VFX.
- Settings hooks and stress-test scene.
- Updated shared docs, asset credits/provenance, and handoff.

## Acceptance Criteria

- Core events have immediate, distinct feedback without changing game state.
- Repeated fire/footsteps/alerts cannot create unbounded nodes or intolerable clipping.
- Pause, restart, and scene change stop or retain sounds according to a documented policy.
- Alert and suspicion are distinguishable without relying only on color.
- Camera shake, vibration, flashes, and retro processing can be reduced or disabled.
- HUD, radar, silhouettes, and aim remain readable under final effects.
- No unlicensed commercial-game assets ship with the project.

## Handoff

Document event mappings, bus names, settings keys, pooling/cleanup behavior, feedback owner APIs, asset provenance, and intentional missing assets.

## Critic Review

- Does feedback clarify state or merely add noise?
- Are crucial cues distinguishable by sound and shape/timing, not color alone?
- Can high-frequency events exhaust channels or leak nodes?
- Do retro effects obscure radar, aim, enemies, or navigation?
- Are all assets original/licensed and replaceable through data/configuration?

