# Vertical Slice Specification — Substation 6

Updated: 2026-08-28  
Status: authoritative target for Build Steps 02–14

## Mission Contract

The player infiltrates an original coastal power-routing station, copies a relay manifest from its control terminal, and returns to the drainage gate. The intended first clear takes 5–10 minutes. The mission begins unseen, becomes completable without detection, remains completable after an alert, and restarts from the most recent checkpoint after death.

- Start: `CP0_INSERTION` in `R0_DRAINAGE`, 100 health, empty inventory, objective `FIND_RELAY_TERMINAL`.
- Objective: interact with `O1_RELAY_TERMINAL` in `R6_CONTROL` for 1.25 seconds.
- Extraction: after the objective, reach `X1_DRAINAGE_GATE` in `R0_DRAINAGE` and interact.
- Success: objective complete and extraction interaction accepted; player control locks and mission phase becomes `COMPLETED`.
- Failure: player health reaches zero. After a 1.5-second readable death hold, restart from the most recent checkpoint.
- Restart: restore player health, transform, inventory/equipment, persistent pickup/door/objective flags; clear alerts, projectiles, transient noise, and guard suspicion; reset living guards to authored patrol starts.
- No alarm is a failure condition. Detection changes pressure and radar feedback, not objective availability.

## Room and Connection Diagram

Distances are centerline traversal targets, not straight-line room dimensions. Bracketed labels are fixed-camera zones; arrows are traversable connections.

```text
                         12 m side trip
                    +-----------------------+
                    | R2 SUPPLY CAGE [Z2S]  |
                    | W1 pistol / A1 / I1   |
                    +-----------+-----------+
                                |
R0 DRAINAGE          R1 LOADING YARD         R3 SECURITY HALL
[Z0] 18 m ----8 m----[Z1S|Z1N] 28 m----6 m---[Z3] 20 m
CP0 / X1             G1 + crates             D1: LEVEL_1
   ^                       ^                       |
   |                       |                       | 8 m
   |                       |                       v
   |                  D2 shortcut             R5 SWITCH FLOOR
   |                       |                   [Z5W|Z5E] 32 m
   |                       |                   G3 + G4 / CP1
   |                       |                       |
   |                       +----10 m----R6 CONTROL [Z6] 16 m
   |                                    O1 terminal
   |
   +---------------- extraction return -----------------------

R3 SECURITY HALL ----5 m---- R4 MAINTENANCE [Z4A|Z4B] 26 m
                              G2 / K1 access card / locker
                              (returns to R3 by the same door)
```

Critical path before the objective is `R0 → R1 → R3 → R4 → R3 → D1 → R5 → R6`. Completing `O1` opens one-way shortcut `D2` from `R6` to `R1`; extraction is then `R1 → R0`. `R2` is optional but contains all combat supplies.

## Authoritative Placement

| Room | Purpose and authored content | Camera and aim | First-run target |
|---|---|---|---:|
| `R0_DRAINAGE` | Safe insertion, `CP0`, extraction `X1`, movement prompts, waist-high pipe cover. No guard enters. | `Z0`, high three-quarter view facing the R1 exit. First-person aim is allowed after a weapon is owned; no transition boundary crosses cover. | 0:40 |
| `R1_LOADING_YARD` | `G1` loops clockwise around three cargo stacks with a 2.0 s north-facing pause. Two wide routes around the center stack; neither requires perfect timing. | `Z1S → Z1N` at the center-stack sight break; 0.35 s blend. Both zones allow aim. | 1:05 |
| `R2_SUPPLY_CAGE` | Optional safe alcove off R1 after crossing G1's route. Fixed pickups: loaded pistol `W1`, 12-round ammo box `A1`, ration `I1`. | `Z2S`; close high view facing the only exit. Aim allowed, with a clear near-wall indicator. | 0:45 |
| `R3_SECURITY_HALL` | Locked door `D1` shows `LEVEL_1_REQUIRED`; west branch leads to R4. A solid divider breaks G2's long sightline into the hall. | `Z3`; long axial view. Aim allowed. Zone never changes while the player is directly in front of D1. | 0:40 |
| `R4_MAINTENANCE` | `G2` patrols a U-shaped pipe loop, pausing 1.5 s at the workbench. `K1_LEVEL_1_CARD` sits on the lit workbench. One locker and two pipe banks provide honest occlusion. | `Z4A → Z4B` at the opaque pipe-bank threshold; 0.3 s blend. Aim allowed in both zones. | 1:15 |
| `R5_SWITCH_FLOOR` | `G3` patrols the west perimeter; `G4` crosses north/south between transformer rows. Three transformer banks and a low service trench support break-contact routes. `CP1` triggers after D1 opens and the player crosses the entry threshold. | `Z5W → Z5E` on the fully occluded center transformer; 0.4 s blend. Aim allowed. | 1:35 |
| `R6_CONTROL` | `O1_RELAY_TERMINAL`, sealed shortcut `D2`, and a guard-proof console recess. Objective interaction opens D2 and changes the objective to extraction. Guards may enter but cannot occupy the terminal focus point. | `Z6`; high corner view showing terminal and both exits. Aim allowed except during the terminal hold. | 0:55 |
| Return/extraction | `D2` bypasses R5 and R3. R1 patrols continue; R0 remains safe. | Reverse zone transitions use the same boundaries and blends. | 0:55 |

First-run target: 7:55. Expected clean replay: 5:15–6:00. Expected detected recovery: 8:00–9:30.

## Progression and Soft-Lock Rules

- `K1_LEVEL_1_CARD` is a persistent key item: it has no capacity cost, cannot be dropped or consumed, and is restored by checkpoints. `D1` permanently records unlocked once a valid access check succeeds.
- If the player dies before `CP1`, K1 and all pickups revert to the state recorded at CP0. If the player dies after `CP1`, K1 and D1 remain acquired/unlocked.
- `D2` opens permanently when O1 completes. Objective state is included in every subsequent restart snapshot.
- Guards never carry progression items, never lock doors, and cannot enter R0. A living guard blocking a narrow doorway must yield or repath after 1.0 second.
- The pistol is optional. The mission has enough occlusion and patrol slack to finish without it.
- If an interaction is unavailable, the prompt exposes the reason (`LEVEL_1_REQUIRED`, `OBJECTIVE_INCOMPLETE`, `FULL_HEALTH`, or `INVENTORY_FULL`) rather than silently failing.

## Controls and Mode Transitions

All gameplay reads the semantic action names in `project.godot`. Mouse motion is consumed as analog camera look in first-person mode; it is not polled as a button action.

| Intent | Keyboard/mouse | Controller | Exploration | First-person aim | Inventory/pause |
|---|---|---|---|---|---|
| Move / navigate | WASD | Left stick | Camera-relative movement | Disabled; player is rooted | UI focus navigation |
| Look / aim | Mouse | Right stick | No manual camera orbit | Yaw/pitch within camera limits | No effect |
| Aim | Hold right mouse | Hold LT | Enter aim if weapon equipped and zone permits | Hold to remain; release returns to prior exploration camera/facing | No effect |
| Fire / accept | Left mouse / Enter | RT / A | Fire ignored | Fire equipped weapon | Accept focused choice |
| Reload | R | X | Request reload | Request reload; aim remains active | No effect |
| Crouch | C | Left-stick click | Toggle stand/crouch when clearance permits | No effect; existing stance is preserved | No effect |
| Interact | F | A | Use current interaction focus | Disabled | Accept focused choice |
| Weapon panel | Hold Q | Hold LB | Open left weapon panel; gameplay input stops | Exits aim, then opens panel | Release closes and equips highlighted weapon |
| Item panel | Hold E | Hold RB | Open right item panel; gameplay input stops | Exits aim, then opens panel | Release closes and equips highlighted item |
| Quick-use | G | Y | Use equipped ration if valid | Use equipped ration without leaving aim | No effect in another modal |
| Pause / back | Esc | Start | Pause world and open pause menu | Exits aim, then pauses | Resume or back one modal level |

Mode precedence is `death/completed > pause > inventory panel > terminal interaction > aim > exploration`. Entering a higher-priority mode cancels lower-priority movement/fire input and zeroes residual velocity. Pause sets `SceneTree.paused`; pause UI and the `GameState` autoload use always-processing mode. Inventory panels stop player/weapon input but do not pause world simulation. Opening pause while a panel is held closes the panel first and opens pause once.

First-person aim roots translation and allows no strafing. It preserves standing/crouched stance, uses mouse or right-stick yaw/pitch, clamps yaw to ±70° from entry facing and pitch to -45°/+35°, and recenters only when aim is released. Camera-zone changes are deferred until aim exits. Aim is rejected with visible feedback when no weapon is equipped, during interactions, or while a modal is open.

## Stealth and Alert State Contract

| State | Entry rule | Guard behavior | Player feedback | Exit rule |
|---|---|---|---|---|
| `NORMAL` | Mission/restart default | Authored patrol and waits | Green radar; contacts and honest cones visible | A guard gains suspicion or confirms sight |
| `SUSPICIOUS` | One guard has >0 suspicion without confirmed sight | That guard slows, looks, then investigates last stimulus | Yellow local meter and question cue; radar remains available | Suspicion decays to 0 or sight reaches confirmation |
| `DETECTED` | One-frame event when a guard confirms the player | Reporter broadcasts last-known position | Red flash, directional marker, distinct sound | Immediately starts ALERT |
| `ALERT` | Global response after DETECTED or gunshot identification | Guards pursue/flank last seen player; direct sight refreshes position | Red alert label; radar hides guard cones but keeps coarse contacts | No guard has sight for 3.0 s and minimum alert time elapsed |
| `EVASION` | ALERT loses confirmed sight | Guards move to last-known position and nearby exits | Orange countdown; radar shows intermittent contacts | Sight returns → ALERT; countdown expires → SEARCH |
| `SEARCH` | Evasion countdown expires | Guards search assigned nearby sectors, then return to route | Amber label; radar contacts/cones return | Sight returns → ALERT; search timer expires → NORMAL |

Suspicion is readable before confirmation. Reacquiring the player during EVASION or SEARCH returns directly to ALERT. Pausing freezes every timer. Death/restart clears the global phase to NORMAL before actors resume.

## Tuning Targets

These values are implementation targets stored in owning subsystem data/resources later; they are not constants to duplicate across scripts.

| System | Target | Unit / rationale |
|---|---:|---|
| Player standing speed | 4.5 | m/s; crosses a 20 m room in ~4.5 s unobstructed |
| Player crouch speed | 2.6 | m/s; meaningful stealth cost without becoming tedious |
| Player acceleration / deceleration | 24 / 30 | m/s²; responsive with a fast stop at cover |
| Player turn rate | 720 | degrees/s exploration |
| Player maximum health | 100 | health points |
| Ration heal | 50 | health points, clamped to maximum |
| Guard walk / pursue speed | 2.4 / 4.0 | m/s; player can break contact using route choice |
| Guard vision | 70° / 18 | full cone angle / meters while player stands in normal light |
| Crouched visibility range | 13 | meters; occlusion always overrides range |
| Sight confirmation | 0.8 | seconds at full exposure; meter drains over 1.5 s |
| Suspicion stimulus | 0.25 | minimum meter increase for a visible/noise hint |
| Walk / crouch hearing radius | 5.0 / 1.5 | meters on standard floor |
| Gunshot hearing radius | 30 | meters; identifies position and starts ALERT |
| ALERT minimum / lost-sight grace | 12 / 3 | seconds |
| EVASION / SEARCH duration | 8 / 20 | seconds; enough time to demonstrate both states |
| Player pistol | 50 damage, 8-round magazine | two body hits defeat a 100-health guard |
| Guard weapon | 20 damage, 0.75 s cadence | five hits from full health; supports recovery |
| Pistol reserve at pickup / cap | 12 / 24 | rounds; total starting supply is 20 including magazine |
| Interaction range / hold | 2.0 / 1.25 | meters / seconds for objective; normal pickups are instant |
| Camera blend | 0.30–0.40 | seconds only across occluded zone boundaries |
| Performance target | 60 | fps at 1280×720 on a conservative desktop target |

## Content Budget

| Content | Exact budget |
|---|---:|
| Rooms | 7 (`R0`–`R6`) |
| Traversal camera zones | 10 (`Z0`, `Z1S`, `Z1N`, `Z2S`, `Z3`, `Z4A`, `Z4B`, `Z5W`, `Z5E`, `Z6`) |
| Guards | 4 (`G1`–`G4`), each with one authored patrol loop |
| Weapons | 1 pistol (`W1`) |
| Consumables | 1 ration pickup (`I1`) |
| Ammo pickups | 1 box of 12 pistol rounds (`A1`) |
| Key items / access levels | 1 card (`K1`) / one access level (`LEVEL_1`) |
| Authored doors | 3: supply-cage door, `D1` access door, `D2` objective shortcut |
| Objective / extraction | 1 terminal (`O1`) / 1 gate (`X1`) |
| Checkpoints | 2 (`CP0`, `CP1`) |
| Explicit hiding/occlusion clusters | 8: 3 yard crates, 2 maintenance pipe banks, 1 locker, 2 transformer banks/trench routes |

## Acceptance Playthroughs

### A — Stealth success

1. Start at CP0, traverse R1 behind G1 using either side of the center stack, and optionally collect all R2 supplies.
2. Read D1's access requirement, enter R4, use a pipe bank to avoid G2, and collect K1.
3. Return to D1, unlock it, trigger CP1, and cross R5 by waiting behind transformer banks while G3/G4 paths separate.
4. Complete O1, take D2 to R1, pass G1, and extract at X1.
5. Pass if no state reaches DETECTED and the mission completes in under 10 minutes without hidden information or frame-perfect movement.

### B — Detected recovery

1. Collect R2 supplies, then deliberately enter G1's cone until DETECTED.
2. Break line of sight around the center cargo stack, observe ALERT → EVASION → SEARCH, and either wait for NORMAL or continue through R3.
3. Acquire K1, cross D1/CP1, then deliberately fire in R5. Use transformer cover, the service trench, a ration if damaged, and the optional pistol to survive or evade G3/G4.
4. Complete O1 during or after recovery, use D2, and extract.
5. Pass if alerts never lock D1, O1, D2, or X1 and recovery requires no reload or guard extermination.

### C — Death and checkpoint restart

1. Acquire K1, unlock D1, cross CP1, and record health, pistol magazine/reserve, ration ownership, K1, and D1 state.
2. Trigger ALERT in R5 and allow guards to reduce health to zero.
3. Confirm one death transition, a 1.5-second hold, then restart at CP1 with full health, the recorded inventory/equipment state, K1 present, D1 unlocked, objective incomplete, all guards alive at patrol starts, and alert NORMAL.
4. Complete O1, then die again before extraction if damage access permits; otherwise restart manually from CP1 for this branch.
5. Pass if objective/door/pickup persistence matches the checkpoint snapshot, transient combat/AI state is cleared, and extraction remains reachable.

## Explicit Exclusions and Cut Order

No cinematics, codec conversations, boss, multiple floors, vent crawling, disguises, body dragging, nonlethal weapon, melee combo, manual saves, crafting, item dropping, weapon attachments, destructible cover, procedural patrols, dynamic lighting stealth, or more than one access level are in this slice. Visuals and names remain original.

If schedule contracts, cut in this order: decorative supply-cage door animation, terminal hold animation, then the R4 locker hiding pose. Do not cut the R2 supply choice, alert recovery, CP1 restart, camera-zone transitions, or D2 extraction shortcut; those prove the core loop.

## Implementation Ownership Notes

- Build 02 consumes movement and stance targets; Build 03 consumes camera zones and rooted aim rules.
- Build 04 owns room geometry and the exact placements above; Builds 05–07 own combat, inventory, health, progression, and snapshot implementation.
- Builds 08–09 own the state behavior/timers but must preserve the phase names and recovery guarantees.
- Build 12 owns prompts/modal focus and may improve presentation without changing action semantics.
- Any change to room IDs, critical path, entity counts, control semantics, checkpoint persistence, or alert phase transitions updates this file, `INTERFACES.md`, and affected consumers in the same change.
