# Development instructions for AI coding agents

Project: Crazy — a medieval third-person RPG combined with a world-map strategy layer. Engine: Godot 4 (GDScript). UI and docs may be in Russian.

## Must preserve
- The game must stay launchable after every patch. Avoid half-integrated new subsystems.
- Separate world state (`Game` autoload) from view scenes.
- The global map and 3D location scenes must share persistent world state.
- Switching cameras must never reset character or army state.
- No paid API, required cloud backend, or online LLM runtime.
- Keep files reasonably small, classes independently editable, and functions testable.
- No external asset dependencies for the first vertical slice.
- Design supports hero and villain paths without two separate games.
- The first playable loop is village raid -> loot -> build fortress -> defend fortress.
- Clearly distinguish implemented MVP functionality from future design ideas.

## Before marking work complete
1. Run `godot --headless --path . --import --quit` on Godot 4.3+.
2. Run `godot --headless --path . --quit-after 30`.
3. Manually test map -> village -> combat -> loot -> map -> castle -> wall -> defense -> save/reload when interactive Godot is available.
4. If testing isn't available, explicitly say it wasn't tested.
5. Do not commit .godot/, user saves, or binary exports.

## Next priorities
- Resolve Godot engine parsing/runtime errors detected by CI.
- Add real melee hitboxes/animations and troop command UI.
- Implement build placement with proper navigation and pathfinding.
- Improve art and UX without losing functional gameplay.

## CRITICAL: Blender asset and release fidelity gate
- Do not treat the rejected PR #2 (`art/hero-modular-armor-v1`) or Windows build #14 as a valid art baseline. It regressed from `codex/dark-fortress-visual-pass` and never used Blender. The current feature branch was created from the visual-pass branch to preserve its improvements.
- Before changing graphics, read `docs/AI_ART_PIPELINE.md` and issue #3. The character must be built on a properly rigged human model with separate armor meshes inside an actual editable Blender `.blend` project. A direct GLB triangulation script and more primitive geometry do not satisfy this requirement.
- Godot import success is insufficient. Require real character visibility in exported gameplay, multi-angle preview and user reference comparison before advertising another Windows EXE as a visual upgrade.
- Do not merge a new model into the core gameplay until the isolated model showcase has passed visual inspection. Source asset licenses and provenance are mandatory.
