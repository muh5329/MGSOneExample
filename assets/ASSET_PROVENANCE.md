# Asset Provenance

Every distributed external model, animation, texture, sound, image, or font must have a machine-readable record in `assets/metadata/` before it enters a checked-in scene. Record the source URL or internal creation reference, creator, acquisition date, license name/version, redistribution and derivative permissions, attribution text, modifications, and the repository files that consume it.

The current actor visual assets are original primitive geometry authored directly in Godot for this repository. They use no external meshes, textures, animations, likenesses, or copyrighted source files. Their shared record is `assets/metadata/internal_actor_primitives.json`.

Build 11 feedback uses only runtime-generated original PCM tones, primitive VFX meshes, and code-drawn screen treatment. It ships no sampled or third-party audio. Its record is `assets/metadata/internal_feedback_primitives.json`.
