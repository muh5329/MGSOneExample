# Feedback Event Matrix

Updated: 2026-08-31

`FeedbackManager` maps semantic requests to replaceable presentation. Gameplay remains authoritative; a suppressed sound or effect never changes a hit, transaction, alert, or mission result.

| Event | Sound/bus | VFX or screen cue | Camera/vibration | Priority / cooldown |
|---|---|---|---|---|
| `FOOTSTEP` | low procedural step / Effects, spatial | none | none | 1 / 0.08 s |
| `pistol_fire` | short two-part report / Effects, spatial | muzzle flash + brief amber flash | definition impulse; medium vibration | 5 / 0.04 s |
| `pistol_dry_fire` | high click / Effects | none | none | 3 / 0.12 s |
| `pistol_reload` | mechanical tone / Effects | animation remains adapter-owned | none | 2 / 0.20 s |
| `bullet_impact` | short impact / Effects, spatial | bounded impact sphere | none | 3 / 0.03 s |
| `PICKUP` | rising UI tone / UI | green pickup spark | none | 3 / 0.08 s |
| `ITEM_USED` | recovery tone / UI | green screen wash | none | 4 / 0.20 s |
| `MENU_OPEN`, `MENU_MOVE`, `MENU_CLOSE` | distinct short UI tones / UI | none | none | 1–2 / 0.03–0.04 s |
| `REJECTED` | low error tone / UI | reason text remains HUD-owned | none | 4 / 0.10 s |
| `DETECTED` | urgent high alarm / UI | red border/pulse plus `(!)` text | medium vibration | 10 / 0.40 s |
| `ALERT_PHASE_CHANGED` | phase cue / UI | alert label shape/text changes | none | 7 / 0.12 s |
| `ATTACK_TELEGRAPH` | warning chirp / Effects, spatial | guard animation remains adapter-owned | none | 6 / 0.12 s |
| `PLAYER_DAMAGED` | low hit tone / Effects | red damage flash | capped camera impulse; strong vibration | 8 / 0.08 s |
| `PLAYER_DEATH` | descending tone / Effects | dark red fade + death panel | no repeated vibration | 10 / 1.0 s |
| `DOOR` | mechanical tone / Effects, spatial | door scene remains state owner | none | 3 / 0.10 s |
| `CHECKPOINT` | confirmation tone / UI | teal objective spark + banner | none | 6 / 0.30 s |
| `OBJECTIVE` | completion tone / UI | teal spark and flash + text | none | 9 / 0.50 s |
| `MISSION_COMPLETE` | long confirmation / Music | completion panel and flash | none | 10 / 1.0 s |

## Pooling and lifecycle policy

- The active voice cap is 12 across reusable 2D and 3D players. Higher-priority cues may preempt lower-priority voices; otherwise overflow is reported and suppressed.
- The VFX cap is 24. Oldest effects are replaced at capacity, every effect has a 0.05–1.0 second lifetime, and effect nodes join `checkpoint_disposable`.
- Spatial players use inverse-distance attenuation, a 6 m unit size, and a 34 m maximum distance. UI, alert, and mission tones are non-spatial.
- Pause suspends active voices and gameplay timers; short-lived VFX/screen overlays are allowed to finish and UI navigation remains available. Checkpoint restart stops every voice, frees all feedback effects, clears flashes/cooldowns, and then permits restored gameplay to resume.
- All current sounds are original runtime-synthesized placeholders. Replace mappings or generated streams inside the feedback owner without changing event producers.
