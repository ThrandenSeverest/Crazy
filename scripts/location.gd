extends Node3D

const CameraRig = preload("res://scripts/camera_rig.gd")
const CharacterVisualScript = preload("res://scripts/character_visual.gd")
const FortressVisualScript = preload("res://scripts/fortress_visual.gd")
const MasonryShader = preload("res://shaders/masonry.gdshader")
const EclipseShader = preload("res://shaders/eclipse_sky.gdshader")
## Playable primitive 3D location: player mode, tactical mode, combat, walls.

const DARK_STONE := Color("#242126")
const PALE_STONE := Color("#4a4647")
const WOOD := Color("#251b19")
const GRASS := Color("#202923")
const ENEMY_COLOR := Color("#6f151d")
const ALLY_COLOR := Color("#3d414a")
const EMBER := Color("#ff6a24")
const BLOOD_RED := Color("#61131a")

var player: CharacterBody3D
var player_visual: CharacterVisual
var third_camera: Camera3D
var tactical_camera: Camera3D
var tactics := false
var building := false
var building_yaw := 0.0
var camera_rig = CameraRig.new()
var squad_order := "follow"
var squad_target := Vector3.ZERO
var attack_cooldown := 0.0
var encounter_done := false
var encounter_active := false
var defending := false

var allies: Array[Node3D] = []
var enemies: Array[Dictionary] = []
var enemy_hit_timer := 0.0
var ally_hit_timer := 0.0

var hud: Label
var info: Label
var actions: VBoxContainer
var title_plate: Panel
var health_bar: ProgressBar

func _ready() -> void:
	_setup_world()
	_setup_player()
	_setup_cameras()
	_setup_ui()
	Game.changed.connect(_refresh)
	match Game.destination:
		"castle":
			_create_castle()
			for wall in Game.walls:
				if wall is Dictionary:
					_spawn_wall(float(wall.get("x", 0)), float(wall.get("z", 0)), float(wall.get("yaw", 0)))
			_spawn_allies()
			_message("Замок. TAB — стратегия, построй стену или собери гарнизон.")
		"village":
			_create_village()
			_spawn_allies()
			_spawn_enemies(4 + Game.village_id, Vector3(0, 0, -13))
			encounter_active = true
			_message("Набег. Победи защитников деревни, чтобы получить добычу.")
		"camp":
			_create_camp()
			_spawn_allies()
			_message("Лесной лагерь. Можно восстановить здоровье за 3 провизии.")
	_refresh()

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = EclipseShader
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8994a6")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 0.72
	env.glow_bloom = 0.18
	env.ssao_enabled = true
	env.ssao_radius = 1.8
	env.ssao_intensity = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color("#2a262c")
	env.fog_light_energy = 0.65
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.65
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color("#f3b49d")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	_solid_box(Vector3(0, -0.7, -20), Vector3(140, 1.4, 180), Color("#33343a"))
	# A broad, low red sky light keeps silhouettes legible without making the world cheerful.
	var dusk := DirectionalLight3D.new()
	dusk.rotation_degrees = Vector3(-26, 152, 0)
	dusk.light_color = Color("#8593b7")
	dusk.light_energy = 0.28
	add_child(dusk)

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0,7,20) if Game.destination=="castle" else Vector3(0,3,17)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43
	shape.height = 1.85
	var collision := CollisionShape3D.new()
	collision.shape = shape
	player.add_child(collision)
	player_visual = _spawn_character_visual(player, "lord")
	add_child(player)

func _setup_cameras() -> void:
	third_camera = Camera3D.new()
	third_camera.name = "ThirdPersonCamera"
	third_camera.fov = 58
	add_child(third_camera)
	third_camera.make_current()
	tactical_camera = Camera3D.new()
	tactical_camera.name = "StrategyCamera"
	tactical_camera.fov = 60
	add_child(tactical_camera)
	camera_rig.setup(player, third_camera, tactical_camera)

func _setup_ui() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	var theme := Theme.new()
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia","Liberation Serif","Times New Roman"])
	theme.default_font = serif
	root.theme = theme
	var plate := Panel.new()
	plate.position = Vector2(18,18)
	plate.size = Vector2(430,119)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.025,0.025,0.035,0.87)
	frame.border_color = Color("#74624a")
	frame.set_border_width_all(1)
	frame.set_content_margin_all(10)
	plate.add_theme_stylebox_override("panel",frame)
	root.add_child(plate)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(34,56)
	health_bar.size = Vector2(390,11)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color("#84302e")
	health_fill.border_color = Color("#ba8861")
	health_fill.set_border_width_all(1)
	health_bar.add_theme_stylebox_override("fill",health_fill)
	root.add_child(health_bar)

	hud = Label.new()
	hud.position = Vector2(34, 28)
	hud.size = Vector2(400, 104)
	hud.add_theme_font_size_override("font_size", 17)
	hud.add_theme_color_override("font_color", Color("#f4ebd6"))
	hud.add_theme_color_override("font_shadow_color", Color("#080607"))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	info = Label.new()
	info.position = Vector2(28, 656)
	info.size = Vector2(1030, 56)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color("#fff2d1"))
	info.add_theme_color_override("font_shadow_color", Color("#080607"))
	info.add_theme_constant_override("shadow_offset_x", 2)
	info.add_theme_constant_override("shadow_offset_y", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)

	actions = VBoxContainer.new()
	actions.position = Vector2(1030, 25)
	actions.size = Vector2(224, 330)
	actions.add_theme_constant_override("separation", 5)
	root.add_child(actions)
	_add_action("ВОЗВРАТ НА КАРТУ [Esc]", _return_to_map)
	_add_action("ОТРЯД: СЛЕДОВАТЬ [1]", _order_follow)
	_add_action("ОТРЯД: СТОЯТЬ [2]", _order_hold)
	_add_action("СОХРАНИТЬ", _save)
	if Game.destination == "castle":
		_add_action("СТРОИТЬ СТЕНУ [ЛКМ]", _toggle_build)
		_add_action("НАНЯТЬ 2 СОЛДАТ", _recruit)
		_add_action("ОТРАЗИТЬ НАПАДЕНИЕ", _begin_defense)
	elif Game.destination == "camp":
		_add_action("ОТДОХНУТЬ (3 ЕДЫ)", _rest)

func _add_action(txt: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = txt
	button.custom_minimum_size = Vector2(224, 34)
	button.add_theme_font_size_override("font_size", 14)
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.025,0.025,0.035,0.88)
	border.border_color = Color("#6d5d48")
	border.set_border_width_all(1)
	button.add_theme_stylebox_override("normal",border)
	var hover := border.duplicate() as StyleBoxFlat
	hover.border_color = Color("#cbab73")
	hover.bg_color = Color("#30242a")
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.add_theme_color_override("font_color", Color("#eadcc5"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffbb75"))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	actions.add_child(button)

func _solid_box(at: Vector3, dims: Vector3, tint: Color, yaw: float = 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	pivot.rotation.y = yaw
	add_child(pivot)
	var body := StaticBody3D.new()
	pivot.add_child(body)
	var block_mesh := BoxMesh.new()
	block_mesh.size = dims
	var visible := MeshInstance3D.new()
	visible.mesh = block_mesh
	var stone_material := ShaderMaterial.new()
	stone_material.shader = MasonryShader
	stone_material.set_shader_parameter("base_color",tint)
	stone_material.set_shader_parameter("paving",dims.y<2.0 and dims.x>20.0)
	visible.material_override = _material(tint) if tint==WOOD else stone_material
	body.add_child(visible)
	var shape := BoxShape3D.new()
	shape.size = dims
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	return pivot

func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.84
	material.metallic = 0.08 if tint.get_luminance() < 0.20 else 0.0
	material.metallic_specular = 0.45
	return material

func _metal_material(tint: Color = Color("#24252a")) -> StandardMaterial3D:
	var material := _material(tint)
	material.metallic = 0.85
	material.roughness = 0.48
	return material

func _ember_material() -> StandardMaterial3D:
	var material := _material(EMBER)
	material.emission_enabled = true
	material.emission = EMBER
	material.emission_energy_multiplier = 4.0
	return material

func _visual_box(parent: Node3D, pos: Vector3, dims: Vector3, tint: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dims
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(tint)
	parent.add_child(instance)

func _character_mesh(parent: Node3D, tunic: Color, face: Color) -> void:
	# Emergency fallback used only if an imported rig cannot be loaded.
	var torso := CapsuleMesh.new()
	torso.radius = 0.43
	torso.height = 1.42
	var torso_mesh := MeshInstance3D.new()
	torso_mesh.mesh = torso
	torso_mesh.material_override = _metal_material(tunic)
	torso_mesh.position.y = 0.18
	parent.add_child(torso_mesh)
	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.56
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = head
	head_mesh.material_override = _metal_material(Color("#17171b"))
	head_mesh.position.y = 1.18
	parent.add_child(head_mesh)
	_visual_box(parent, Vector3(0.43, 0.18, 0), Vector3(0.12, 0.9, 0.12), Color("#b9b5b0"))
	_visual_box(parent, Vector3(-0.43, 0.18, 0), Vector3(0.12, 0.9, 0.12), Color("#b9b5b0"))
	_visual_box(parent, Vector3(0, 0.76, 0.03), Vector3(0.66, 0.48, 0.08), tunic)
	# Narrow black helmet and a ragged red mantle make a readable silhouette at game distance.
	var helm := CylinderMesh.new()
	helm.top_radius = 0.25
	helm.bottom_radius = 0.31
	helm.height = 0.34
	var helm_mesh := MeshInstance3D.new()
	helm_mesh.mesh = helm
	helm_mesh.position.y = 1.36
	helm_mesh.material_override = _metal_material()
	parent.add_child(helm_mesh)
	_banner(parent, Vector3(0, 0.45, 0.31), Vector2(0.55, 1.15), tunic, PI)

func _spawn_character_visual(parent: Node3D, role: String) -> CharacterVisual:
	var visual := CharacterVisualScript.new() as CharacterVisual
	visual.name = "CharacterVisual"
	parent.add_child(visual)
	if not visual.setup(role):
		visual.queue_free()
		_character_mesh(parent, ENEMY_COLOR if role == "enemy" else ALLY_COLOR, Color("#d1b28c"))
		return null
	return visual

func _create_castle() -> void:
	var fortress := FortressVisualScript.new()
	add_child(fortress)
	fortress.build()

func _create_village() -> void:
	for pos in [Vector3(-18, 2.5, -12), Vector3(15, 2.5, -18), Vector3(-23, 2.5, 9), Vector3(21, 2.5, 6)]:
		_solid_box(pos, Vector3(8, 5, 7), WOOD)
		_solid_box(pos + Vector3(0, 2.9, 0), Vector3(9.0, 1.1, 8.0), Color("#3d2928"))
		_brazier(pos + Vector3(3.8, 0, 2.8))
	for n in range(14):
		var x := -37.0 + float((n * 19) % 76)
		var z := -36.0 + float((n * 23) % 73)
		if absf(x) > 27.0 or absf(z) > 25.0:
			_tree(Vector3(x, 0, z))

func _create_camp() -> void:
	for n in range(22):
		var x := -38.0 + float((n * 19) % 77)
		var z := -38.0 + float((n * 29) % 76)
		if absf(x) > 6.0 or absf(z) > 6.0:
			_tree(Vector3(x, 0, z))
	_solid_box(Vector3(0, 0.3, -2), Vector3(2, 0.6, 2), Color("#4c2920"))
	_brazier(Vector3(0, 0.35, -2))
	_solid_box(Vector3(5, 1, 5), Vector3(5, 2, 3), WOOD)

func _tree(at: Vector3) -> void:
	_solid_box(at + Vector3(0, 2, 0), Vector3(0.9, 4, 0.9), Color("#58442e"))
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.1
	sphere.height = 4.2
	crown.mesh = sphere
	crown.material_override = _material(Color("#2f5441"))
	crown.position = at + Vector3(0, 5, 0)
	add_child(crown)

func _tower(at: Vector3, width: float, height: float) -> void:
	_solid_box(at + Vector3(0, height * 0.5, 0), Vector3(width, height, width), DARK_STONE)
	_solid_box(at + Vector3(0, height + 0.45, 0), Vector3(width + 0.5, 0.9, width + 0.5), PALE_STONE)
	for dx in [-1.7, 0.0, 1.7]:
		for dz in [-1.7, 1.7]:
			_solid_box(at + Vector3(dx, height + 1.3, dz), Vector3(0.75, 1.2, 0.75), PALE_STONE)
	_brazier(at + Vector3(0, height + 2.0, 0))

func _banner(parent: Node3D, pos: Vector3, size: Vector2, tint: Color, yaw: float = 0.0) -> void:
	var banner := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	banner.mesh = plane
	banner.position = pos
	banner.rotation = Vector3(PI * 0.5, yaw, 0)
	banner.material_override = _material(tint)
	parent.add_child(banner)

func _brazier(at: Vector3) -> void:
	var bowl := MeshInstance3D.new()
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.42
	bowl_mesh.bottom_radius = 0.25
	bowl_mesh.height = 0.3
	bowl.mesh = bowl_mesh
	bowl.position = at + Vector3(0, 0.48, 0)
	bowl.material_override = _metal_material()
	add_child(bowl)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.25
	flame_mesh.height = 0.75
	flame.mesh = flame_mesh
	flame.position = at + Vector3(0, 0.86, 0)
	flame.material_override = _ember_material()
	add_child(flame)
	var fire_light := OmniLight3D.new()
	fire_light.position = at + Vector3(0, 1.15, 0)
	fire_light.light_color = Color("#ff7b32")
	fire_light.light_energy = 3.2
	fire_light.omni_range = 8.0
	fire_light.shadow_enabled = true
	add_child(fire_light)

func _spawn_wall(x: float, z: float, yaw: float) -> void:
	_solid_box(Vector3(x, 1.65, z), Vector3(5.5, 3.3, 1.1), PALE_STONE, yaw)

func _spawn_allies() -> void:
	for n in range(mini(Game.soldiers, 12)):
		var figure := Node3D.new()
		figure.name = "Soldier_%d" % n
		figure.position = Vector3((n % 4 - 1.5) * 2.4, 0.98, 10 - (n / 4) * 1.8)
		var visual := _spawn_character_visual(figure, "ally")
		figure.set_meta("character_visual", visual)
		add_child(figure)
		allies.append(figure)

func _spawn_enemies(count: int, center: Vector3) -> void:
	for n in range(count):
		var unit := Node3D.new()
		unit.name = "Enemy_%d" % n
		unit.position = center + Vector3((n % 4 - 1.5) * 3.0, 0.98, -float(n / 4) * 3.0)
		var visual := _spawn_character_visual(unit, "brute" if n % 4 == 3 else "enemy")
		add_child(unit)
		enemies.append({"unit": unit, "visual": visual, "hp": 4})

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if not tactics:
		_move_player(delta)
	else:
		_move_tactical(delta)
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		if not player.is_on_floor():
			player.velocity.y -= 20.0 * delta
		player.move_and_slide()
	camera_rig.update(delta)
	_move_allies(delta)
	if encounter_active and not encounter_done:
		_fight_enemies(delta)

func _move_player(delta: float) -> void:
	var h := float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)))
	var v := float(int(Input.is_key_pressed(KEY_W)) - int(Input.is_key_pressed(KEY_S)))
	var direction: Vector3 = camera_rig.world_movement(h, v)
	var speed := 10.0 if Input.is_key_pressed(KEY_SHIFT) else 6.5
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if player.is_on_floor():
		if player.velocity.y < 0.0:
			player.velocity.y = 0.0
	else:
		player.velocity.y -= 20.0 * delta
	player.move_and_slide()
	if player_visual != null:
		player_visual.set_motion(direction.length() > 0.1, Input.is_key_pressed(KEY_SHIFT))
	if direction.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), clampf(delta * 14.0, 0, 1))

func _move_tactical(delta: float) -> void:
	var h := float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)))
	var v := float(int(Input.is_key_pressed(KEY_W)) - int(Input.is_key_pressed(KEY_S)))
	var rot := float(int(Input.is_key_pressed(KEY_E)) - int(Input.is_key_pressed(KEY_Q)))
	camera_rig.pan(h, v, rot, delta)

func _set_tactics(enabled: bool) -> void:
	tactics = enabled
	if not enabled:
		building = false
	camera_rig.set_mode(enabled)
	_refresh()

func _order_follow() -> void:
	squad_order = "follow"
	_message("Солдаты следуют за героем.")

func _order_hold() -> void:
	squad_order = "hold"
	squad_target = player.global_position
	_message("Солдаты удерживают текущую позицию.")

func _order_at(screen: Vector2) -> void:
	var point := _ground_at(screen)
	if point == Vector3.INF:
		_message("Точка за пределами игровой локации.")
		return
	squad_order = "move"
	squad_target = Vector3(point.x, 0.98, point.z)
	_message("Отряд направлен в указанную точку. 1 — следовать, 2 — стоять.")

func _ground_at(screen: Vector2) -> Vector3:
	var origin := tactical_camera.project_ray_origin(screen)
	var ray_dir := tactical_camera.project_ray_normal(screen)
	if ray_dir.y >= -0.001:
		return Vector3.INF
	var ray_length := -origin.y / ray_dir.y
	if ray_length < 0.0 or ray_length > 500.0:
		return Vector3.INF
	var pos := origin + ray_dir * ray_length
	if absf(pos.x) > 43.0 or absf(pos.z) > 43.0:
		return Vector3.INF
	return pos

func _move_allies(delta: float) -> void:
	var anchor := player.global_position if squad_order == "follow" else squad_target
	anchor.y = 0.98
	for n in range(allies.size()):
		var soldier := allies[n]
		var col := float(n % 4) - 1.5
		var row := float(int(n / 4))
		var pos := anchor + camera_rig.right() * (col * 2.4) + camera_rig.forward() * (8.0 + row * 1.7)
		pos.y = 0.98
		var displacement := pos - soldier.global_position
		var visual := soldier.get_meta("character_visual") as CharacterVisual
		if displacement.length() > 0.2:
			var step := displacement.normalized() * minf(displacement.length(), delta * 6.0)
			soldier.global_position += step
			soldier.rotation.y = lerp_angle(soldier.rotation.y, atan2(-step.x, -step.z), minf(1.0, delta * 12.0))
			if visual != null:
				visual.set_motion(true)
		elif visual != null:
			visual.set_motion(false)

func _fight_enemies(delta: float) -> void:
	enemy_hit_timer = maxf(0, enemy_hit_timer - delta)
	ally_hit_timer = maxf(0, ally_hit_timer - delta)
	for enemy in enemies:
		var unit: Node3D = enemy["unit"]
		var enemy_visual: CharacterVisual = enemy.get("visual") as CharacterVisual
		var difference := player.global_position - unit.global_position
		difference.y = 0
		if difference.length() > 2.0:
			unit.position += difference.normalized() * delta * 1.7
			unit.rotation.y = lerp_angle(unit.rotation.y, atan2(-difference.x, -difference.z), minf(1.0, delta * 8.0))
			if enemy_visual != null:
				enemy_visual.set_motion(true)
		elif enemy_hit_timer <= 0.0:
			Game.take_damage(5)
			enemy_hit_timer = 1.3
			if enemy_visual != null:
				enemy_visual.attack()
		elif enemy_visual != null:
			enemy_visual.set_motion(false)
	if Game.player_health <= 0:
		encounter_done = true
		Game.fail_encounter()
		_return_to_map()
		return

	if ally_hit_timer <= 0.0:
		ally_hit_timer = 1.0
		for ally in allies:
			for enemy in enemies:
				var unit: Node3D = enemy["unit"]
				if ally.global_position.distance_to(unit.global_position) < 2.8:
					enemy["hp"] = int(enemy["hp"]) - 1
					var ally_visual := ally.get_meta("character_visual") as CharacterVisual
					if ally_visual != null:
						ally_visual.attack()
					break
	_remove_dead_enemies()

func _remove_dead_enemies() -> void:
	for n in range(enemies.size() - 1, -1, -1):
		if int(enemies[n]["hp"]) <= 0:
			var unit: Node3D = enemies[n]["unit"]
			var corpse_visual: CharacterVisual = enemies[n].get("visual") as CharacterVisual
			if corpse_visual != null:
				corpse_visual.die()
			get_tree().create_timer(6.0).timeout.connect(unit.queue_free)
			enemies.remove_at(n)
	if enemies.is_empty() and encounter_active and not encounter_done:
		encounter_done = true
		encounter_active = false
		if defending:
			Game.finish_defense()
		elif Game.destination == "village":
			Game.finish_raid()
		_message(Game.last_report + " Нажми Esc для возвращения на карту.")

func _strike() -> void:
	if tactics or not encounter_active or encounter_done or attack_cooldown > 0.0:
		return
	attack_cooldown = 0.45
	if player_visual != null:
		player_visual.attack(true)
	var nearest: Dictionary = {}
	var best := 3.7
	for enemy in enemies:
		var unit: Node3D = enemy["unit"]
		var d := player.global_position.distance_to(unit.global_position)
		if d < best:
			best = d
			nearest = enemy
	if nearest.is_empty():
		_message("Противник слишком далеко. Подойди ближе.")
		return
	nearest["hp"] = int(nearest["hp"]) - 2
	var struck_visual: CharacterVisual = nearest.get("visual") as CharacterVisual
	if struck_visual != null:
		struck_visual.hit()
	_remove_dead_enemies()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		camera_rig.mouse_move(event.relative, Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE), Input.is_key_pressed(KEY_SHIFT))
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if building:
					building = false
				else:
					_return_to_map()
			KEY_TAB:
				_set_tactics(not tactics)
			KEY_SPACE:
				if not tactics and player.is_on_floor():
					player.velocity.y = 7.0
			KEY_F:
				_strike()
			KEY_1:
				_order_follow()
			KEY_2:
				_order_hold()
			KEY_R:
				if building:
					building_yaw += PI / 2.0
					_message("Стена повернута на 90 градусов.")
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if tactics and building:
					_try_place_wall(event.position)
				elif not tactics:
					_strike()
			MOUSE_BUTTON_RIGHT:
				if tactics:
					if building:
						building = false
					else:
						_order_at(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				camera_rig.wheel(true)
			MOUSE_BUTTON_WHEEL_DOWN:
				camera_rig.wheel(false)

func _try_place_wall(screen: Vector2) -> void:
	if Game.destination != "castle" or not Game.can_place_wall():
		_message("Недостаточно ресурсов: нужно 8 дерева и 6 камня (не более 24 стен).")
		return
	var at := _ground_at(screen)
	if at == Vector3.INF:
		_message("Нельзя строить за пределами локации.")
		return
	if Game.place_wall(at, building_yaw):
		_spawn_wall(snappedf(at.x, 1), snappedf(at.z, 1), building_yaw)
		_message("Стена построена. ЛКМ — следующая, R — повернуть, ПКМ — отмена.")
	else:
		_message("Здесь строить нельзя или не хватает ресурсов.")
	_refresh()

func _toggle_build() -> void:
	if Game.destination != "castle" or encounter_active:
		return
	if not tactics:
		_set_tactics(true)
	building = not building
	_message("Режим стройки. ЛКМ на земле — стена (8 дерева, 6 камня). R — поворот. ПКМ — выход." if building else "Строительство завершено.")
	_refresh()

func _begin_defense() -> void:
	if Game.destination != "castle" or encounter_active:
		return
	building = false
	_set_tactics(false)
	defending = true
	encounter_done = false
	encounter_active = true
	_spawn_enemies(5 + int(Game.threat / 15), Vector3(0, 0, -27))
	_message("Карательная экспедиция атакует! Сражайся лично или руководи обзором.")

func _recruit() -> void:
	if Game.recruit():
		for ally in allies:
			ally.queue_free()
		allies.clear()
		_spawn_allies()
		_message(Game.last_report)
	else:
		_message("Нужно 25 золота и 3 провизии; максимум 16 солдат.")

func _rest() -> void:
	if Game.food >= 3:
		Game.heal_at_camp()
		_message(Game.last_report)
	else:
		_message("Не хватает провизии для отдыха.")

func _save() -> void:
	_message("Игра сохранена." if Game.save_game() else "Не удалось сохранить игру.")

func _return_to_map() -> void:
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func _message(text: String) -> void:
	if info != null:
		info.text = text

func _refresh() -> void:
	if hud == null:
		return
	var mode := "ТАКТИКА" if tactics else "ГЕРОЙ"
	var where := "ЗАМОК" if Game.destination == "castle" else ("ДЕРЕВНЯ" if Game.destination == "village" else "ЛАГЕРЬ")
	health_bar.value = Game.player_health
	hud.text = ("%s  /  %s\n\nЗолото %d   Дерево %d   Камень %d\nПровизия %d   Гарнизон %d") % [where,mode,Game.gold,Game.wood,Game.stone,Game.food,Game.soldiers]
