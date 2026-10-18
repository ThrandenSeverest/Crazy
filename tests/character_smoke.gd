extends SceneTree
const Visual = preload("res://scripts/character_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for role in ["lord","ally","enemy","brute"]:
		var visual := Visual.new()
		root.add_child(visual)
		assert(visual.setup(role))
		for clip in ["Idle","Walking_A","Running_A","Attack","Hit_A","Death_A"]:
			assert(visual.animator.has_animation(clip))
		visual.set_motion(true)
		visual.animator.advance(0.20)
		visual.animator.advance(0.0)
		var leg: Node3D = visual.get_node("Rig/Pelvis/LegL")
		var before := leg.rotation.x
		visual.animator.advance(0.45)
		visual.animator.advance(0.0)
		assert(absf(before-leg.rotation.x)>0.1,"Walking must actually move the leg")
		visual.attack(true)
		visual.animator.advance(0.30)
		visual.animator.advance(0.0)
		var arm: Node3D = visual.get_node("Rig/Pelvis/Torso/ArmR")
		print(role," attack angle: ",arm.rotation.x)
		assert(absf(arm.rotation.x)>0.6,"Attack must move the weapon arm")
		visual.die()
		visual.animator.advance(1.0)
		visual.animator.advance(0.0)
		assert(visual.dead)
		assert(absf(visual.rig.rotation.z)>1.0,"Death must not remain upright")
		visual.queue_free()
	await process_frame
	print("CHARACTER_SMOKE_OK: 4 roles, 6 clips, verified joint motion")
	quit()
