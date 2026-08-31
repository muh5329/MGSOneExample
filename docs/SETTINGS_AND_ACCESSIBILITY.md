# Settings and Accessibility

Updated: 2026-08-31

`SettingsService` is the only persistence owner. It writes `user://shadow_circuit_settings.cfg`, loads before the mission, emits typed key/value changes, applies audio buses, and projects aim settings into the camera's existing resource boundary. Widgets submit requests; they never mutate gameplay state.

## Keys

| Key | Default | Range / behavior |
|---|---:|---|
| `master_volume` | 1.0 | Linear 0–1, converted to decibels on `Master` |
| `music_volume` | 0.75 | `Music` bus |
| `effects_volume` | 0.9 | `Effects` bus |
| `ui_volume` | 0.85 | `UI` bus |
| `ambience_volume` | 0.7 | `Ambience` bus |
| `mouse_sensitivity` | 0.12 | 0.01–1.0 degrees/pixel |
| `controller_sensitivity` | 150 | 30–360 degrees/second |
| `invert_horizontal`, `invert_vertical` | false | Applied through `CameraAimSettings` |
| `screen_effect_intensity` | 0.75 | 0 disables screen treatment |
| `retro_enabled` | true | Toggles scanlines/edge treatment; never covers HUD or radar |
| `camera_shake_scale`, `vibration_scale` | 1.0 | 0 disables the request, 1 uses capped authored values |
| `reduced_flash` | false | Caps flash alpha and duration |
| `text_scale` | 1.0 | HUD scale 0.8–1.5 |
| `high_contrast` | false | Raises HUD contrast without changing semantic colors |

The pause menu is always-processing while `GameState` remains the sole pause owner. Its main/settings paths use standard UI actions and automatic controller focus. `ui_cancel` backs out one level, then resumes. Input-family switching changes prompt glyphs between keyboard/mouse and controller.

Alternate bindings can be added for all essential gameplay actions. Conflicts return the already-bound semantic action before mutation. Defaults—including `ui_cancel`—are only supplemented, never removed, so remapping cannot strand menu navigation. Custom alternates persist in the same settings file and Reset Settings removes only those alternates.

Critical states use text and shape/timing as well as color: suspicion uses `(?)` plus a meter, detection/alert uses `(!)` and explicit instruction, evasion/search use bracketed labels, and death/completion use full-screen titled panels. Current known gaps are localization, narrated menus, subtitle timing for future voiced content, and per-action removal/replacement of default bindings.
