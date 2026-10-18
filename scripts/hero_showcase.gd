extends Node3D
## Standalone inspection of real separate armor parts. Load via scenes/hero_showcase.tscn.
const HeroCharacter = preload("res://scripts/hero_character.gd")

var hero: Node3D
var camera: Camera3D
var yaw := 0.25
var pitch := 0.12
var distance := 3.5
var preview_walking := false
var slots := ["head", "chest", "shoulders", "arms", "gloves", "waist", "legs", "boots", "cloak", "weapon"]
var shown: Dictionary = {}
var status: Label

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#24242b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7e7980")
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	for index in range(2):
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-50, -45 if index == 0 else 130, 0)
		light.light_energy = 1.8 if index == 0 else 0.65
		light.shadow_enabled = index == 0
		add_child(light)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.22
	floor_mesh.bottom_radius = 1.34
	floor_mesh.height = 0.13
	var stand := MeshInstance3D.new()
	stand.mesh = floor_mesh
	stand.position.y = -0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#49464b")
	stand.material_override = mat
	add_child(stand)
	hero = HeroCharacter.new()
	hero.name = "HeroPreview"
	add_child(hero)
	camera = Camera3D.new()
	camera.fov = 43
	add_child(camera)
	camera.make_current()
	update_camera()
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(22, 20)
	status.add_theme_font_size_override("font_size", 16)
	layer.add_child(status)
	for slot in slots:
		shown[slot] = true
	refresh_status()

func refresh_status() -> void:
	status.text = "CRAZY • HERO MODEL / SEPARATE ARMOR\n"
	status.text += "Drag LMB: rotate | mousewheel: zoom | A: walk\n"
	status.text += "1: helmet  2: chest  3: pauldrons  4: arms  5: gauntlets\n"
	status.text += "6: waist  7: greaves  8: boots  9: cloak  0: sword\n"
	status.text += "Geometry prototype only • no skinned rig yet"
	if not (hero as Node).get("is_ready_for_game"):
		status.text += "\nGLB assets missing: python3 tools/build_hero.py"

func update_camera() -> void:
	var eye := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.position = Vector3(0,1.04,0) + eye * distance
	camera.look_at(Vector3(0,1.05,0))

func _process(delta: float) -> void:
	(hero as Node).call("animate_character",delta,0.75 if preview_walking else 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw += event.relative.x * 0.008
		pitch = clampf(pitch - event.relative.y * 0.008, -0.52, 0.6)
		update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.0, distance - 0.3)
			update_camera()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(7.0, distance + 0.3)
			update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A:
			preview_walking = not preview_walking
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var slot: String = str(slots[event.keycode - KEY_1])
			shown[slot] = not shown[slot]
			(hero as Node).call("set_equipment_visible",slot,shown[slot])
		elif event.keycode == KEY_0:
			shown["weapon"] = not shown["weapon"]
			(hero as Node).call("set_equipment_visible","weapon",shown["weapon"])