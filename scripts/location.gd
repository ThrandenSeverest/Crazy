extends Node3D
## Playable primitive 3D location: player mode, tactical mode, combat, walls.

const DARK_STONE := Color("#636b69")
const PALE_STONE := Color("#929a91")
const WOOD := Color("#76553c")
const GRASS := Color("#536b51")
const ENEMY_COLOR := Color("#923e36")
const ALLY_COLOR := Color("#3d617c")

var player: CharacterBody3D
var third_camera: Camera3D
var tactical_camera: Camera3D
var tactics := false
var building := false
var building_yaw := 0.0
var zoom := 26.0
var focus_point := Vector3.ZERO
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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#a9bac0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8e3db")
	env.ambient_light_energy = 0.65
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	_solid_box(Vector3(0, -0.7, 0), Vector3(90, 1.4, 90), GRASS)

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 3, 17)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43
	shape.height = 1.85
	var collision := CollisionShape3D.new()
	collision.shape = shape
	player.add_child(collision)
	_character_mesh(player, Color("#303840"), Color("#d1bb9e"))
	add_child(player)

func _setup_cameras() -> void:
	third_camera = Camera3D.new()
	third_camera.name = "ThirdPersonCamera"
	third_camera.fov = 70
	add_child(third_camera)
	third_camera.make_current()
	tactical_camera = Camera3D.new()
	tactical_camera.name = "StrategyCamera"
	tactical_camera.fov = 60
	add_child(tactical_camera)
	_update_cameras(1.0)

func _setup_ui() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)

	hud = Label.new()
	hud.position = Vector2(20, 18)
	hud.size = Vector2(760, 110)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_color", Color("#f4ebd6"))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	info = Label.new()
	info.position = Vector2(20, 585)
	info.size = Vector2(980, 113)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 19)
	info.add_theme_color_override("font_color", Color("#fff2d1"))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)

	actions = VBoxContainer.new()
	actions.position = Vector2(986, 25)
	actions.size = Vector2(272, 430)
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)
	_add_action("ВОЗВРАТ НА КАРТУ [Esc]", _return_to_map)
	_add_action("СОХРАНИТЬ", _save)
	if Game.destination == "castle":
		_add_action("СТРОИТЬ СТЕНУ [Tab]", _toggle_build)
		_add_action("НАНЯТЬ 2 СОЛДАТ", _recruit)
		_add_action("ОТРАЗИТЬ НАПАДЕНИЕ", _begin_defense)
	elif Game.destination == "camp":
		_add_action("ОТДОХНУТЬ (3 ЕДЫ)", _rest)

func _add_action(txt: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = txt
	button.custom_minimum_size = Vector2(267, 46)
	button.add_theme_font_size_override("font_size", 16)
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
	visible.material_override = _material(tint)
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
	material.roughness = 0.92
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
	var torso := CapsuleMesh.new()
	torso.radius = 0.40
	torso.height = 1.42
	var torso_mesh := MeshInstance3D.new()
	torso_mesh.mesh = torso
	torso_mesh.material_override = _material(tunic)
	torso_mesh.position.y = 0.18
	parent.add_child(torso_mesh)
	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.56
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = head
	head_mesh.material_override = _material(face)
	head_mesh.position.y = 1.18
	parent.add_child(head_mesh)
	_visual_box(parent, Vector3(0.43, 0.18, 0), Vector3(0.12, 0.9, 0.12), Color("#c3c6c4"))

func _create_castle() -> void:
	_solid_box(Vector3(-15, 5, -18), Vector3(12, 10, 12), DARK_STONE)
	_solid_box(Vector3(-15, 11, -18), Vector3(13, 2, 13), PALE_STONE)
	for xx in [-29.0, 29.0]:
		for zz in [-29.0, 29.0]:
			_solid_box(Vector3(xx, 5, zz), Vector3(5, 10, 5), DARK_STONE)
	for xx in [-19.0, 19.0]:
		_solid_box(Vector3(xx, 2.0, -29), Vector3(16, 4, 1.3), PALE_STONE)
	_solid_box(Vector3(0, 2.0, -29), Vector3(8, 4, 1.2), WOOD)
	_solid_box(Vector3(24, 2, 0), Vector3(1.6, 4, 35), PALE_STONE)
	_solid_box(Vector3(-29, 2, 0), Vector3(1.6, 4, 35), PALE_STONE)
	_solid_box(Vector3(0, 0.3, 8), Vector3(8, 0.6, 5), Color("#867c6c"))
	_solid_box(Vector3(12, 2.2, -13), Vector3(8, 4.4, 8), WOOD)

func _create_village() -> void:
	for pos in [Vector3(-18, 2.5, -12), Vector3(15, 2.5, -18), Vector3(-23, 2.5, 9), Vector3(21, 2.5, 6)]:
		_solid_box(pos, Vector3(8, 5, 7), WOOD)
		_solid_box(pos + Vector3(0, 2.9, 0), Vector3(9.0, 1.1, 8.0), Color("#6c4e45"))
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
	_solid_box(Vector3(0, 0.3, -2), Vector3(2, 0.6, 2), Color("#b56d3d"))
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

func _spawn_wall(x: float, z: float, yaw: float) -> void:
	_solid_box(Vector3(x, 1.65, z), Vector3(5.5, 3.3, 1.1), PALE_STONE, yaw)

func _spawn_allies() -> void:
	for n in range(mini(Game.soldiers, 12)):
		var figure := Node3D.new()
		figure.name = "Soldier_%d" % n
		figure.position = Vector3((n % 4 - 1.5) * 1.5, 0.98, 21 + (n / 4) * 1.8)
		_character_mesh(figure, ALLY_COLOR, Color("#d1b28c"))
		add_child(figure)
		allies.append(figure)

func _spawn_enemies(count: int, center: Vector3) -> void:
	for n in range(count):
		var unit := Node3D.new()
		unit.name = "Enemy_%d" % n
		unit.position = center + Vector3((n % 4 - 1.5) * 3.0, 0.98, -float(n / 4) * 3.0)
		_character_mesh(unit, ENEMY_COLOR, Color("#d9bc9c"))
		add_child(unit)
		enemies.append({"unit": unit, "hp": 4})

func _physics_process(delta: float) -> void:
	if not tactics and not encounter_done:
		_move_player(delta)
	elif tactics:
		_move_tactical(delta)
	_update_cameras(delta)
	_move_allies(delta)
	if encounter_active and not encounter_done:
		_fight_enemies(delta)

func _move_player(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	move = move.normalized()
	player.velocity.x = move.x * 7.0
	player.velocity.z = move.z * 7.0
	if player.is_on_floor():
		player.velocity.y = 0.0
	else:
		player.velocity.y -= 20.0 * delta
	player.move_and_slide()
	if move.length() > 0.1:
		player.rotation.y = atan2(-move.x, -move.z)

func _move_tactical(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.z += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	focus_point += dir.normalized() * 22.0 * delta
	focus_point.x = clampf(focus_point.x, -36, 36)
	focus_point.z = clampf(focus_point.z, -36, 36)

func _update_cameras(delta: float) -> void:
	var target := player.global_position + Vector3(0, 4.8, 9.0)
	third_camera.global_position = third_camera.global_position.lerp(target, minf(delta * 7.0, 1.0))
	third_camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	tactical_camera.global_position = focus_point + Vector3(0, zoom, zoom * 0.95)
	tactical_camera.look_at(focus_point, Vector3.UP)

func _move_allies(delta: float) -> void:
	for n in range(allies.size()):
		var unit := allies[n]
		var col := float(n % 4) - 1.5
		var row := float(int(n / 4))
		var pos := player.global_position + Vector3(col * 1.5, 0, 3.5 + row * 1.7)
		pos.y = 0.98
		unit.global_position = unit.global_position.lerp(pos, minf(delta * 3.0, 1.0))

func _fight_enemies(delta: float) -> void:
	enemy_hit_timer = maxf(0, enemy_hit_timer - delta)
	ally_hit_timer = maxf(0, ally_hit_timer - delta)
	for enemy in enemies:
		var unit: Node3D = enemy["unit"]
		var difference := player.global_position - unit.global_position
		difference.y = 0
		if difference.length() > 2.0:
			unit.position += difference.normalized() * delta * 1.7
		elif enemy_hit_timer <= 0.0:
			Game.take_damage(5)
			enemy_hit_timer = 1.3
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
					break
	_remove_dead_enemies()

func _remove_dead_enemies() -> void:
	for n in range(enemies.size() - 1, -1, -1):
		if int(enemies[n]["hp"]) <= 0:
			var unit: Node3D = enemies[n]["unit"]
			unit.queue_free()
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
	if tactics or not encounter_active or encounter_done:
		return
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
	_remove_dead_enemies()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_return_to_map()
			KEY_TAB:
				tactics = not tactics
				building = false
				if tactics:
					tactical_camera.make_current()
				else:
					third_camera.make_current()
				_refresh()
			KEY_SPACE:
				_strike()
			KEY_R:
				if building:
					building_yaw += PI / 2.0
					_message("Стена повернута на 90°. ЛКМ — разместить.")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if tactics and building:
				_try_place_wall(event.position)
			else:
				_strike()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			building = false
			_refresh()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and tactics:
			zoom = maxf(12.0, zoom - 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and tactics:
			zoom = minf(48.0, zoom + 3.0)

func _try_place_wall(screen: Vector2) -> void:
	if Game.destination != "castle" or not Game.can_place_wall():
		_message("Недостаточно ресурсов: нужно 8 дерева и 6 камня (не более 24 стен).")
		return
	var ray_start := tactical_camera.project_ray_origin(screen)
	var ray_end := ray_start + tactical_camera.project_ray_normal(screen) * 240.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var at: Vector3 = hit["position"]
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
		tactics = true
		tactical_camera.make_current()
	building = not building
	_message("Режим стройки. ЛКМ на земле — стена (8 дерева, 6 камня). R — поворот. ПКМ — выход." if building else "Строительство завершено.")
	_refresh()

func _begin_defense() -> void:
	if Game.destination != "castle" or encounter_active:
		return
	building = false
	tactics = false
	third_camera.make_current()
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
	hud.text = ("%s  |  %s  |  Здоровье %d/100\n"
		+ "Золото %d  Дерево %d  Камень %d  Еда %d  Солдаты %d\n"
		+ "TAB: камера  •  WASD: движение  •  ЛКМ/Space: удар  •  Esc: карта"
	) % [where, mode, Game.player_health, Game.gold, Game.wood, Game.stone, Game.food, Game.soldiers]
