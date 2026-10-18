class_name CharacterVisual
extends Node3D
## Rigged KayKit character wrapper with resilient animation-name lookup.

const MODELS := {
	"lord": "res://assets/characters/kaykit/Knight.glb",
	"ally": "res://assets/characters/kaykit/Knight.glb",
	"enemy": "res://assets/characters/kaykit/Rogue_Hooded.glb",
	"brute": "res://assets/characters/kaykit/Barbarian.glb",
}

var animator: AnimationPlayer
var current_loop := ""
var attacking := false
var role := "ally"

func setup(character_role: String) -> bool:
	role = character_role
	var packed := load(MODELS.get(role, MODELS["ally"])) as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate()
	model.name = "RiggedModel"
	model.scale = Vector3.ONE * (1.08 if role == "lord" else 0.96)
	model.rotation.y = PI
	add_child(model)
	animator = _find_animation_player(model)
	_style_model(model)
	_configure_equipment(model)
	if animator != null:
		animator.animation_finished.connect(_on_animation_finished)
		play_loop("Idle")
	return true

func set_motion(moving: bool, running: bool = false) -> void:
	if attacking:
		return
	play_loop("Running_A" if moving and running else ("Walking_A" if moving else "Idle"))

func attack(two_handed: bool = false) -> void:
	if animator == null:
		return
	var requested := "2H_Melee_Attack_Slice" if two_handed else "1H_Melee_Attack_Slice_Diagonal"
	var resolved := _resolve_animation(requested)
	if resolved == "":
		resolved = _resolve_animation("1H_Melee_Attack_Chop")
	if resolved == "":
		return
	attacking = true
	animator.speed_scale = 1.18
	animator.play(resolved, 0.08)

func hit() -> void:
	_play_once("Hit_A", 0.06)

func die() -> void:
	attacking = true
	var resolved := _resolve_animation("Death_A")
	if resolved != "":
		animator.play(resolved, 0.12)

func play_loop(requested: String) -> void:
	if animator == null or current_loop == requested:
		return
	var resolved := _resolve_animation(requested)
	if resolved == "":
		return
	current_loop = requested
	animator.speed_scale = 1.0
	animator.play(resolved, 0.16)

func _play_once(requested: String, blend: float) -> void:
	if animator == null:
		return
	var resolved := _resolve_animation(requested)
	if resolved == "":
		return
	attacking = true
	animator.play(resolved, blend)

func _on_animation_finished(_name: StringName) -> void:
	if attacking:
		attacking = false
		current_loop = ""
		play_loop("Idle")

func _resolve_animation(requested: String) -> StringName:
	if animator == null:
		return &""
	for animation_name in animator.get_animation_list():
		var plain := String(animation_name)
		if plain == requested or plain.ends_with("/" + requested):
			return animation_name
	return &""

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _style_model(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var original := mesh_instance.mesh.surface_get_material(surface)
				if original is StandardMaterial3D:
					var material := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
					material.albedo_color *= _role_tint()
					material.roughness = 0.66
					material.metallic = 0.34 if role != "enemy" else 0.16
					mesh_instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_style_model(child)

func _role_tint() -> Color:
	match role:
		"lord": return Color("#9a8580")
		"enemy": return Color("#8a4d55")
		"brute": return Color("#6e5550")
		_: return Color("#727985")

func _configure_equipment(node: Node) -> void:
	var node_name := node.name.to_lower()
	if node is Node3D:
		var spatial := node as Node3D
		if "shield" in node_name:
			spatial.visible = role == "ally" and ("round" in node_name or "badge" in node_name)
		elif "2h_sword" in node_name:
			spatial.visible = role == "lord" or role == "brute"
		elif "1h_sword_offhand" in node_name:
			spatial.visible = false
		elif "1h_sword" in node_name:
			spatial.visible = role == "ally" or role == "enemy"
	for child in node.get_children():
		_configure_equipment(child)
