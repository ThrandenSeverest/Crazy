# CRAZY Hero v0.1: modular character and armor

This is the **first mechanically separate 3D geometry prototype**, not final art and not a commercial-quality character. The visual references are the three images in the October 18 conversation. They show a crowned black-iron knight with layered pauldrons, a ragged crimson cloak, steel weapons, and a giant gothic fortress. No claim of a faithful final match is made yet.

## Build and preview

`python3 tools/build_hero.py` uses **only Python standard library**, generates 21 discrete GLB files in `assets/hero/`, and a structured `manifest.json`. For inspection, open `scenes/hero_showcase.tscn` in Godot 4 and run current scene (F6). You can rotate, zoom and toggle armor groups. CI invokes this script before Godot imports scenes and exports the Windows game so files are included in EXE. The GLBs are intentionally untracked: **source lives in Git**; generated models live in CI artifacts/game exports. No Blender is required to regenerate. Each generated GLB can be imported into Blender, edited, and later replaced by higher-quality mesh art.

**Art direction:** dark riveted articulated metal armor; seven crown spikes; full helm with thin visor gaps and grill; overlapping faulds and tassets; layered pauldrons; greaves and articulated sabatons; hanging torn crimson cape; worn longsword. Hard-surface shapes use custom tapered elliptical lofts, cross-section profiles, blade-like bevels, cloth grids and individually placed details. No sphere/cylinder box mannequin is used as the complete finished character.

## Armor slots and movement

`body_torso`, `body_head`, `body_left_arm`, `body_right_arm`, `body_left_leg`, and `body_right_leg` are distinct organic under-body pieces. Armor items are physically separate mesh files: cuirass, faulds, crowned helmet, left/right pauldrons, left/right vambraces, left/right gauntlets, left/right greaves, left/right sabatons, cloak, and sword. `scripts/hero_character.gd` loads, attaches and toggles parts in Godot. All parts share a common origin at ground, +Y up, +Z forward. Its simple shoulder/hip-pivot walk demonstration does NOT replace production skeleton-weighted animation and may intersect armor.

## Technical limits and next checkpoints

- **Geometry only, first pass:** silhouettes and cutouts need iterative visual critique. Needs sculpt-level organic modeling, hand-authored helmet face details, improved metal/cloth texturing with UV/PBR maps, and optimization.
- **Rig:** next major step should create a real humanoid skeleton and skin weights (or retarget a licensed compatible rig) before adding combat animations. Pivot movement is a rudimentary inspection aid, NOT correct animation.
- **Cloak:** currently static mesh; cloth simulation/secondary animation and correct tearing need future work.
- **Gameplay integration:** the player model is loaded in `scripts/location.gd` when GLBs are available; the old primitive preview is a fallback for local builds lacking generated assets. NPC/army units remain placeholders pending separate work.
- **QA:** test `python3 tools/build_hero.py`, glTF validity, Godot headless import/start, standalone showcase interactive rotation and equipment toggles, gameplay movement/camera/save. Never claim visual fidelity or animation quality without human review of actual Godot frames. Links to original reference must be preserved outside source repo until added with appropriate permission.
- **Licensing:** all generated geometry is first-party procedural project source, and contains no third-party art meshes.