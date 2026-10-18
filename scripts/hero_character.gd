extends Node3D
## Procedurally exported separate GLB meshes; pivots support coarse rigid animation.
## NOT a SkinnedMesh3D yet. This is a model/armor geometry prototype.

const ASSET_ROOT := "res://assets/hero/"

const ITEMS := {
	"body_torso": ["body", "torso", Vector3.ZERO],
	"body_head": ["body", "head", Vector3(0, 1.62, 0)],
	"body_left_arm": ["body", "arm_L", Vector3(-0.31, 1.53, 0)],
	"body_right_arm": ["body", "arm_R", Vector3(0.31, 1.53, 0)],
	"body_left_leg": ["body", "leg_L", Vector3(-0.135, 0.96, 0)],
	"body_right_leg": ["body", "leg_R", Vector3(0.135, 0.96, 0)],
	"armor_cuirass": ["chest", "torso", Vector3.ZERO],
	"armor_faulds": ["waist", "torso", Vector3.ZERO],
	"armor_helmet": ["head", "head", Vector3(0, 1.62, 0)],
	"armor_pauldron_L": ["shoulders", "arm_L", Vector3(-0.31, 1.53, 0)],
	"armor_pauldron_R": ["shoulders", "arm_R", Vector3(0.31, 1.53, 0)],
	"armor_vambrace_L": ["arms", "arm_L", Vector3(-0.31, 1.53, 0)],
	"armor_vambrace_R": ["arms", "arm_R", Vector3(0.31, 1.53, 0)],
	"armor_gauntlet_L": ["gloves", "arm_L", Vector3(-0.31, 1.53, 0)],
	"armor_gauntlet_R": ["gloves", "arm_R", Vector3(0.31, 1.53, 0)],
	"armor_greave_L": ["legs", "leg_L", Vector3(-0.135, 0.96, 0)],
	"armor_greave_R": ["legs", "leg_R", Vector3(0.135, 0.96, 0)],
	"armor_sabaton_L": ["boots", "leg_L", Vector3(-0.135, 0.96, 0)],
	"armor_sabaton_R": ["boots", "leg_R", Vector3(0.135, 0.96, 0)],
	"armor_cloak": ["cloak", "torso", Vector3.ZERO],
	"weapon_longsword": ["weapon", "arm_R", Vector3(0.31, 1.53, 0)]
}

var is_ready_for_game := false
var skeleton_pivots: Dictionary = {}
var equipped_meshes: Dictionary = {}
var movement_phase := 0.0

func _ready() -> void:
	for part in ITEMS.keys():
		var path := ASSET_ROOT + part + ".glb"
		if not ResourceLoader.exists(path):
			push_warning("Hero model missing: %s (run python3 tools/build_hero.py)" % path)
			return
	for part in ITEMS.keys():
		var config: Array = ITEMS[part]
		var pivot_name: String = config[1]
		if not skeleton_pivots.has(pivot_name):
			var pivot := Node3D.new()
			pivot.name = pivot_name
			pivot.position = config[2]
			add_child(pivot)
			skeleton_pivots[pivot_name] = pivot
		var packed := load(ASSET_ROOT + part + ".glb") as PackedScene
		if packed == null:
			push_error("Hero GLB import failed: %s" % part)
			return
		var geometry := packed.instantiate() as Node3D
		geometry.name = part
		geometry.position = -(config[2] as Vector3)
		skeleton_pivots[pivot_name].add_child(geometry)
		equipped_meshes[part] = geometry
	is_ready_for_game = true

func set_equipment_visible(slot: String, enabled: bool) -> void:
	for part in equipped_meshes.keys():
		if ITEMS[part][0] == slot and slot != "body":
			equipped_meshes[part].visible = enabled

func set_piece_visible(piece: String, enabled: bool) -> void:
	if equipped_meshes.has(piece) and ITEMS[piece][0] != "body":
		equipped_meshes[piece].visible = enabled

func animate_character(delta: float, speed_ratio: float) -> void:
	if not is_ready_for_game:
		return
	var run_weight := clampf(speed_ratio, 0.0, 1.0)
	movement_phase += delta * (3.0 + run_weight * 7.5)
	var walk_swing := sin(movement_phase) * run_weight
	(skeleton_pivots["leg_L"] as Node3D).rotation.x = walk_swing * 0.45
	(skeleton_pivots["leg_R"] as Node3D).rotation.x = -walk_swing * 0.45
	(skeleton_pivots["arm_L"] as Node3D).rotation.x = -walk_swing * 0.24
	(skeleton_pivots["arm_R"] as Node3D).rotation.x = walk_swing * 0.24
	(skeleton_pivots["head"] as Node3D).rotation.y = sin(movement_phase * 0.24) * 0.018