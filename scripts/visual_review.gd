extends Node
## Reproducible screenshots of the actual game, not illustrative mockups.
func _ready() -> void:
	Game.destination = "castle"
	Game.walls = []
	Game.soldiers = 6
	var location := load("res://scenes/location.tscn").instantiate() as Node3D
	add_child(location)
	for i in range(40):
		await get_tree().process_frame
	location.set_physics_process(false)
	var camera: Camera3D = location.third_camera
	camera.global_position = Vector3(2.6,2.15,21.2)
	camera.look_at(Vector3(0,2.5,-10))
	await _capture("courtyard")
	# Human-scale front view to inspect proportion, armour, faceplate and joints.
	camera.global_position = Vector3(1.8,1.65,13.8)
	camera.look_at(location.player.global_position+Vector3(0,0.15,0))
	await _capture("armour")
	location.player_visual.attack(true)
	location.player_visual.animator.seek(0.28,true)
	location.player_visual.animator.pause()
	await _capture("attack")
	print("VISUAL_REVIEW_OK: courtyard, armour, attack")
	get_tree().quit()

func _capture(title: String) -> void:
	for i in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/review")
	var image := get_viewport().get_texture().get_image()
	assert(not image.is_empty(),"Render returned an empty image")
	assert(image.save_png("res://build/review/"+title+".png")==OK)
