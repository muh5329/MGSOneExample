# Build Step 12 — HUD, Accessibility, and Settings

## Assignment

One agent/chat owns player-facing HUD composition, prompts, alert presentation, pause/settings screens, input remapping UX, controller focus, and accessibility/readability options. It renders public state but does not own gameplay data.

## Objective

Present health, equipment, ammunition, radar, interactions, alerts, objectives, death/restart, and settings clearly at target resolutions with full keyboard/mouse and controller operation.

## Scope

- HUD for health, equipped weapon/item, magazine/reserve, radar frame, suspicion/alert, and contextual prompt.
- Objective/start/completion/extraction and death/restart messaging.
- Pause/settings screen with volume, sensitivity, inversion, aim assist if present, screen effects, shake, vibration, and remapping.
- Controller focus, glyph strategy, safe-area/scaling anchors, and input-family switching.
- Readability without color alone; scalable text/UI and reduced-flash/motion options where feasible.
- UI state snapshot adapters and presentation tests.

## Non-Goals

- Owning inventory quantities, health, alert timers, camera aim logic, checkpoint behavior, or final branded art.
- A full localization pipeline unless explicitly added.

## Dependencies

- Builds 00, 03, 05–09 public state/events.
- Build Step 11 audio/visual settings.
- Build Step 14 target resolution/platform decisions.

## Public Boundary

- HUD observes immutable snapshots/signals and submits semantic requests.
- Only the settings service persists settings; controls/widgets do not write arbitrary project state.
- UI layer owns focus and modal stacking while game state owns whether gameplay is paused.
- Prompts use the interaction system's current focus and reason text.

## Activities

1. Inventory every HUD element and specify source, display states, priority, and hide/show behavior.
2. Build anchored layouts for target aspect ratios and safe areas using placeholder style assets.
3. Bind health, ammo, equipment, radar, alert, prompts, and mission state through adapters.
4. Implement modal order for gameplay, inventory panels, pause, settings, death, and completion.
5. Implement controller focus/navigation and automatic but stable input-glyph switching.
6. Implement settings persistence/default/reset and remapping conflict handling.
7. Add text/scale, contrast, reduced shake/flash/post-processing, vibration, and audio controls within scope.
8. Test at minimum supported resolution, ultrawide, controller-only, mouse-only, rapid modal switching, pause/restart, and missing data.

## Deliverables

- HUD, prompt, pause/settings, death, and completion UI scenes.
- Settings/remapping integration and UI test scene/tests.
- Updated shared docs and handoff.

## Acceptance Criteria

- HUD always agrees with authoritative health, inventory, weapon, alert, radar, interaction, and mission state.
- No text/control clips or overlaps at supported resolutions and scale settings.
- Every menu path is completable controller-only and keyboard/mouse-only.
- Opening/closing nested menus cannot leave gameplay input active or focus lost.
- Alert/suspicion/death states remain comprehensible without color alone.
- Remapping detects conflicts and always preserves a way to navigate/back out.
- Settings apply consistently and persist according to the documented policy.

## Handoff

Document UI entry scenes, data adapters, modal/focus order, settings keys, persistence location, supported resolutions, and known accessibility gaps.

## Critic Review

- Can UI ever display stale data or mutate gameplay state directly?
- Are modal, pause, and focus ownership unambiguous?
- Is every essential action reachable after remapping with a controller?
- Does UI remain legible with retro effects and at minimum resolution?
- Are critical states conveyed by more than color and subtle audio?

