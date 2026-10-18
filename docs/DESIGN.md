# CRAZY — vertical slice design lock (2026-10-18)

## Genre
Single-player medieval dark fantasy RPG + strategy. Global map for travel, distinct 3D locations for castle, villages, battlefields, and camps. Two game cameras: third-person direct control and tactical top-down.

## Player fantasy
Be the hero or become a feared Dark Lord. Create your own villain fortress, recruit HUMAN armies (soldiers, mercenaries, exiled knights), raid villages, capture prisoners, expand, and personally defend against heroes. Villain mechanics have political/economic consequences (rebellions, liberators, royal expeditions); they are not just dialog choices.

## Long-term systems (not all implemented in prototype)
- Modular fortress architecture, workshops, barracks, dungeons, siege defenses.
- Recruitment, officers, loyalty, payroll, morale, persistent wounds, equipment.
- Settlements with civilians, prisoners, recruitment, rebellion, ransom and slavery mechanics.
- Hero/villain systemic reputation: fear, loyalty, legitimacy, kingdom threat.
- World simulation, caravans, factions and dynamic hero adventuring parties.
- Craft/upgrade personal equipment, survival, wilderness travel and small camps.
- Character progression, social interactions, saves.

## Prototype scope
- One strategic region, one castle, two villages, and a camp.
- One persistent protagonist, allied soldiers, simple opponents.
- Player / tactical camera switch (Tab).
- Simple fight in 3D (LMB/Space); not final melee model.
- Loot for clearing a village.
- Placeable fortress walls, two types of resource expense, persisted geometry.
- Defensive encounter at castle and ability to recruit more soldiers.
- JSON save / load.

## Acceptance checks
1. F5 opens global map, with readable resources and accessible locations.
2. Enter castle: move in third person, switch camera, place stone walls; resources decrease.
3. Enter village: defeat enemies in 3D; get resources and increased kingdom threat.
4. Defend castle from attacking forces in 3D.
5. Reopen game: gold, food, stone, wood, troops, raids, wall placements persist.
6. All of the above are playable without network access or an AI API.

## Technical choices
- Godot 4.x (GDScript), GL Compatibility rendering to prioritize broad hardware support.
- One Game autoload owns state; scene scripts are presentation and interaction.
- Procedural placeholder primitive meshes, no binary art assets in v0.1.
- Prefer resource-driven units and buildings after vertical-slice tests.
- Automate import/runtime checks in GitHub Actions.

## Control update
Mouse-orbit third-person camera with wall avoidance; tactical orbit, pan and zoom; camera-relative RPG movement, jump and sprint; basic squad follow/hold/move-to orders. Troops still use direct steering, not obstacle-aware navigation.
