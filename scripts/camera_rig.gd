extends RefCounted
## Two freely controlled cameras, without mouse lock (UI remains clickable).

var actor: CharacterBody3D
var third: Camera3D
var tactical: Camera3D
var is_tactical := false
var yaw := 0.0
var pitch := 0.36
var distance := 7.0
var map_yaw := 0.0
var map_zoom := 28.0
var focus := Vector3.ZERO

func setup(character: CharacterBody3D, player_camera: Camera3D, map_camera: Camera3D) -> void:
	actor = character
	third = player_camera
	tactical = map_camera
	third.make_current()
	focus = Vector3(actor.global_position.x, 0, actor.global_position.z)
	update(1.0)

func set_mode(tactics: bool) -> void:
	is_tactical = tactics
	if tactics:
		focus = Vector3(actor.global_position.x, 0, actor.global_position.z)
		tactical.make_current()
	else:
		third.make_current()

func forward(tactics: bool = false) -> Vector3:
	var angle := map_yaw if tactics else yaw
	return Vector3(-sin(angle), 0, -cos(angle))

func right(tactics: bool = false) -> Vector3:
	var angle := map_yaw if tactics else yaw
	return Vector3(cos(angle), 0, -sin(angle))

func world_movement(h: float, v: float, tactics: bool = false) -> Vector3:
	return (right(tactics) * h + forward(tactics) * v).normalized()

func mouse_move(delta: Vector2, right_held: bool, middle_held: bool, shift: bool) -> void:
	if is_tactical and middle_held:
		if shift:
			focus -= right(true) * delta.x * map_zoom * 0.009
			focus += forward(true) * delta.y * map_zoom * 0.009
			limit_focus()
		else:
			map_yaw = wrapf(map_yaw - delta.x * 0.008, -PI, PI)
	elif not is_tactical and right_held:
		yaw = wrapf(yaw - delta.x * 0.006, -PI, PI)
		pitch = clampf(pitch + delta.y * 0.005, 0.10, 1.2)

func wheel(up: bool) -> void:
	if is_tactical:
		map_zoom = clampf(map_zoom + (-3.0 if up else 3.0), 11.0, 58.0)
	else:
		distance = clampf(distance + (-0.8 if up else 0.8), 2.2, 12.0)

func pan(h: float, v: float, rotate: float, delta: float) -> void:
	focus += world_movement(h, v, true) * delta * (9.0 + map_zoom * 0.6)
	map_yaw = wrapf(map_yaw + rotate * delta * 1.5, -PI, PI)
	limit_focus()

func limit_focus() -> void:
	focus.x = clampf(focus.x, -38.0, 38.0)
	focus.z = clampf(focus.z, -38.0, 38.0)

func update(delta: float) -> void:
	var target := actor.global_position + Vector3(0, 1.3, 0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var desired := target + offset
	var ray := PhysicsRayQueryParameters3D.create(target, desired)
	ray.exclude = [actor.get_rid()]
	var obstacle := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstacle.is_empty():
		desired = target + offset.normalized() * maxf(0.8, target.distance_to(obstacle["position"]) - 0.35)
	third.global_position = third.global_position.lerp(desired, clampf(delta * 12.0, 0.0, 1.0))
	third.look_at(target, Vector3.UP)
	tactical.global_position = focus + Vector3(sin(map_yaw) * 0.67, 1.2, cos(map_yaw) * 0.67) * map_zoom
	tactical.look_at(focus, Vector3.UP)
