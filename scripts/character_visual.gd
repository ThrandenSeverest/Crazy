class_name CharacterVisual
extends Node3D
## Original human-proportioned articulated armour; no external character pack.
const METAL = preload("res://shaders/forged_metal.gdshader")
const CLOTH = preload("res://shaders/tattered_cloth.gdshader")
var animator: AnimationPlayer
var current_loop := ""
var attacking := false
var dead := false
var role := "ally"
var steel: ShaderMaterial
var trim: ShaderMaterial
var leather: ShaderMaterial
var dark: StandardMaterial3D
var rig: Node3D

func setup(character_role: String) -> bool:
	role = character_role
	steel = _metal(Color("#555b60") if role == "ally" else Color("#373b43"),0.82)
	trim = _metal(Color("#655c4a"),0.75)
	leather = _metal(Color("#282023"),0.0)
	dark = StandardMaterial3D.new()
	dark.albedo_color = Color("#08090c")
	rig = _joint(self,"Rig",Vector3.ZERO)
	var pelvis := _joint(rig,"Pelvis",Vector3(0,0.02,0))
	_shell(pelvis,[Vector3(-0.12,0.22,0.14),Vector3(0.03,0.24,0.15),Vector3(0.18,0.20,0.14)],steel)
	var torso := _joint(pelvis,"Torso",Vector3(0,0.18,0))
	_shell(torso,[Vector3(0,0.20,0.14),Vector3(0.13,0.245,0.175),Vector3(0.32,0.30,0.19),Vector3(0.44,0.27,0.14),Vector3(0.49,0.12,0.105)],steel)
	for i in range(4):
		_shell(torso,[Vector3(-0.14+i*0.07,0.235+i*0.007,0.16),Vector3(-0.09+i*0.07,0.245+i*0.007,0.17)],steel)
	for side in [-1.0,1.0]:
		for i in range(3):
			var rib := _box(torso,Vector3(side*(0.055+i*0.057),0.25,-0.18),Vector3(0.012,0.29,0.012),trim)
			rib.rotation.z = side*(0.08+i*0.06)
		for i in range(4):
			var plate := _box(pelvis,Vector3(side*0.15,-0.08-i*0.065,-0.16-i*0.012),Vector3(0.22,0.085,0.035),steel)
			plate.rotation.z = side*0.12
			for x in [-0.08,0.08]:
				_rivet(plate,Vector3(x,0.025,-0.025))
	_box(pelvis,Vector3(0,0.045,-0.167),Vector3(0.105,0.07,0.035),trim)
	var head := _joint(torso,"Head",Vector3(0,0.49,0))
	_shell(head,[Vector3(0,0.12,0.11),Vector3(0.07,0.135,0.13),Vector3(0.20,0.13,0.12),Vector3(0.29,0.07,0.07),Vector3(0.31,0.005,0.005)],steel)
	_box(head,Vector3(0,0.145,-0.125),Vector3(0.225,0.024,0.016),dark)
	_box(head,Vector3(0,0.103,-0.142),Vector3(0.018,0.13,0.028),trim)
	for side in [-1.0,1.0]:
		for i in range(3):
			_box(head,Vector3(side*(0.037+i*0.025),0.067,-0.121),Vector3(0.009,0.037,0.016),dark)
	if role == "lord":
		_shell(head,[Vector3(0.21,0.14,0.13),Vector3(0.25,0.145,0.13)],trim)
		for i in range(7):
			var a := i*TAU/7.0
			_spike(head,Vector3(sin(a)*0.137,0.25,cos(a)*0.125),0.025,0.14+0.055*sin(a*3.0),trim)
	for side in [-1.0,1.0]:
		_build_arm(torso,side)
		_build_leg(pelvis,side)
	_build_cloth(torso)
	if role == "brute":
		rig.scale = Vector3(1.16,1.08,1.10)
	_build_animations()
	play_loop("Idle")
	return true

func _build_arm(torso: Node3D, side: float) -> void:
	var arm := _joint(torso,"Arm"+("L" if side<0 else "R"),Vector3(side*0.31,0.39,0))
	_shell(arm,[Vector3(-0.12,0.15,0.13),Vector3(0,0.17,0.15),Vector3(0.11,0.10,0.11),Vector3(0.16,0.015,0.025)],steel,6)
	for i in range(3):
		_shell(arm,[Vector3(-0.13-i*0.055,0.15-i*0.014,0.14-i*0.01),Vector3(-0.10-i*0.055,0.17-i*0.014,0.15-i*0.01)],steel)
	if role in ["lord","brute"]:
		for i in range(3):
			var spike := _spike(arm,Vector3(side*(0.05+i*0.06),0.085,0),0.028,0.12+i*0.035,steel)
			spike.rotation.z = -side*0.45
	_shell(arm,[Vector3(-0.31,0.075,0.075),Vector3(-0.12,0.10,0.10)],leather)
	var elbow := _joint(arm,"Elbow",Vector3(0,-0.31,0))
	_shell(elbow,[Vector3(-0.07,0.10,0.10),Vector3(0.04,0.12,0.10)],steel)
	_shell(elbow,[Vector3(-0.29,0.065,0.075),Vector3(-0.09,0.105,0.10)],steel)
	for i in range(3):
		_shell(elbow,[Vector3(-0.29+i*0.06,0.07+i*0.01,0.082+i*0.005),Vector3(-0.275+i*0.06,0.075+i*0.01,0.087+i*0.005)],trim)
	var hand := _joint(elbow,"Hand",Vector3(0,-0.31,0))
	_box(hand,Vector3(0,-0.025,0),Vector3(0.115,0.115,0.105),steel)
	for i in range(4):
		_box(hand,Vector3(-0.04+i*0.027,-0.085,-0.01),Vector3(0.022,0.07,0.075),steel)
	if side > 0:
		_sword(hand)
	elif role == "ally":
		var shield := _joint(hand,"Shield",Vector3(-0.08,0.10,-0.07))
		_box(shield,Vector3.ZERO,Vector3(0.07,0.64,0.40),steel)
		_box(shield,Vector3(-0.045,0,0),Vector3(0.015,0.60,0.035),trim)
		_box(shield,Vector3(-0.045,0.10,0),Vector3(0.015,0.035,0.36),trim)

func _build_leg(pelvis: Node3D, side: float) -> void:
	var leg := _joint(pelvis,"Leg"+("L" if side<0 else "R"),Vector3(side*0.135,-0.08,0))
	_shell(leg,[Vector3(-0.40,0.085,0.085),Vector3(-0.08,0.12,0.115),Vector3(0.02,0.12,0.115)],steel)
	var knee := _joint(leg,"Knee",Vector3(0,-0.40,0))
	_shell(knee,[Vector3(-0.065,0.105,0.11),Vector3(0.035,0.11,0.12)],steel)
	_box(knee,Vector3(0,0,-0.12),Vector3(0.10,0.115,0.035),trim)
	_shell(knee,[Vector3(-0.36,0.065,0.065),Vector3(-0.13,0.09,0.095),Vector3(-0.06,0.085,0.085)],steel)
	_box(knee,Vector3(0,-0.405,-0.055),Vector3(0.15,0.10,0.32),steel)
	for i in range(4):
		_box(knee,Vector3(0,-0.357,-0.02-i*0.05),Vector3(0.15,0.018,0.018),trim)

func _sword(hand: Node3D) -> void:
	var weapon := _joint(hand,"Sword",Vector3(0,-0.04,-0.015))
	_box(weapon,Vector3(0,-0.025,0),Vector3(0.04,0.22,0.04),leather)
	_box(weapon,Vector3(0,-0.15,0),Vector3(0.31,0.035,0.05),trim)
	var blade := _shell(weapon,[Vector3(-0.86,0.001,0.003),Vector3(-0.71,0.055,0.012),Vector3(-0.17,0.065,0.015)],steel,4)
	blade.rotation.y = PI*0.25
	_box(weapon,Vector3(0,-0.45,-0.016),Vector3(0.013,0.51,0.005),dark)
	_rivet(weapon,Vector3(0,0.10,0))

func _build_cloth(torso: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(18):
		for x in range(14):
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var u: float = (x+corner.x)/14.0
				var v: float = (y+corner.y)/18.0
				var width := lerpf(0.28,0.47,v)
				st.set_uv(Vector2(u,v))
				st.add_vertex(Vector3((u-0.5)*width*2.0,0.45-v*1.48+sin(u*81.0)*0.06*pow(v,8.0),0.17+v*0.22+sin(u*31.4)*0.026))
	st.generate_normals()
	var cloth := ShaderMaterial.new()
	cloth.shader = CLOTH
	cloth.set_shader_parameter("cloth_color",Color("#40141d") if role=="lord" else Color("#252631"))
	_mesh(torso,st.commit(),Vector3.ZERO,cloth)
	var tabard := _box(torso,Vector3(0,-0.29,-0.19),Vector3(0.20,0.64,0.018),cloth)
	tabard.rotation.x = 0.12

func _metal(color: Color, amount: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = METAL
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("metalness",amount)
	return mat

func _joint(parent: Node3D, title: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = title
	joint.position = pos
	parent.add_child(joint)
	return joint

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent,mesh,pos,mat)

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.material_override = mat
	parent.add_child(part)
	return part

func _rivet(parent: Node3D, pos: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 6
	mesh.rings = 3
	_mesh(parent,mesh,pos,trim)

func _spike(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	return _mesh(parent,mesh,pos+Vector3(0,height*0.5,0),mat)

func _shell(parent: Node3D, profile: Array, mat: Material, segments: int = 12) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size()-1):
		for col in range(segments):
			for ij in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1)]:
				var p: Vector3 = profile[row+ij.x]
				var a: float = (col+ij.y)*TAU/segments
				st.set_uv(Vector2(float(col+ij.y)/segments,float(row+ij.x)/(profile.size()-1)))
				st.add_vertex(Vector3(sin(a)*p.y,p.x,cos(a)*p.z))
	st.generate_normals()
	return _mesh(parent,st.commit(),Vector3.ZERO,mat)

func _build_animations() -> void:
	animator = AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	add_child(animator)
	var library := AnimationLibrary.new()
	for clip in ["Idle","Walking_A","Running_A","Attack","Hit_A","Death_A"]:
		var animation := Animation.new()
		animation.length = 0.6 if clip=="Attack" else 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if clip in ["Idle","Walking_A","Running_A"] else Animation.LOOP_NONE
		var walking: bool = clip in ["Walking_A","Running_A"]
		var amplitude := 0.65 if clip=="Running_A" else 0.40
		for side in ["L","R"]:
			var s := -1.0 if side=="L" else 1.0
			var hip: String = "Rig/Pelvis/Leg"+side
			var arm: String = "Rig/Pelvis/Torso/Arm"+side
			_track(animation,hip+":rotation",[Vector3(amplitude*s,0,0),Vector3(-amplitude*s,0,0),Vector3(amplitude*s,0,0)] if walking else [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
			_track(animation,hip+"/Knee:rotation",[Vector3(-0.12,0,0),Vector3(-0.60 if walking else -0.12,0,0),Vector3(-0.12,0,0)])
			var values := [Vector3(-amplitude*s*0.7,0,-s*0.09),Vector3(amplitude*s*0.7,0,-s*0.09),Vector3(-amplitude*s*0.7,0,-s*0.09)] if walking else [Vector3(0,0,-s*0.09),Vector3(0.025,0,-s*0.09),Vector3(0,0,-s*0.09)]
			if clip=="Attack" and side=="R":
				values = [Vector3(-2.4,0,-0.4),Vector3(1.25,-0.3,0.1),Vector3(0.15,0,-0.09)]
			_track(animation,arm+":rotation",values)
			_track(animation,arm+"/Elbow:rotation",[Vector3(0.16,0,0),Vector3(0.65 if clip=="Attack" else 0.20,0,0),Vector3(0.16,0,0)])
		_track(animation,"Rig/Pelvis/Torso:rotation",[Vector3(0,0.35 if clip=="Attack" else 0,0),Vector3(-0.18 if clip=="Hit_A" else 0.015,-0.5 if clip=="Attack" else 0,0),Vector3.ZERO])
		_track(animation,"Rig:rotation",[Vector3.ZERO,Vector3(0,0,1.0 if clip=="Death_A" else 0),Vector3(0,0,1.5 if clip=="Death_A" else 0)])
		library.add_animation(clip,animation)
	animator.add_animation_library("",library)
	animator.animation_finished.connect(_on_animation_finished)

func _track(animation: Animation, path: String, values: Array) -> void:
	var index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index,NodePath(path))
	animation.track_set_interpolation_type(index,Animation.INTERPOLATION_CUBIC)
	for i in range(values.size()):
		animation.track_insert_key(index,float(i)/(values.size()-1)*animation.length,values[i])

func set_motion(moving: bool, running: bool = false) -> void:
	if not attacking and not dead:
		play_loop("Running_A" if moving and running else ("Walking_A" if moving else "Idle"))

func play_loop(requested: String) -> void:
	if current_loop==requested or dead:
		return
	current_loop = requested
	animator.speed_scale = 1.6 if requested=="Running_A" else 1.0
	animator.play(requested,0.15)

func attack(_two_handed: bool = false) -> void:
	if not dead:
		attacking = true
		animator.speed_scale = 1.3
		animator.play("Attack",0.06)

func hit() -> void:
	if not dead:
		attacking = true
		animator.play("Hit_A",0.05)

func die() -> void:
	dead = true
	attacking = true
	animator.play("Death_A",0.1)

func _on_animation_finished(_clip: StringName) -> void:
	if not dead:
		attacking = false
		current_loop = ""
		play_loop("Idle")
