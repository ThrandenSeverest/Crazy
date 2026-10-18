class_name FortressVisual
extends Node3D
## Modular gothic skyline and a traversable courtyard. Distant geometry has no collision.
const MASONRY = preload("res://shaders/masonry.gdshader")
const CLOTH = preload("res://shaders/tattered_cloth.gdshader")
var stone: ShaderMaterial
var pale: ShaderMaterial
var black: StandardMaterial3D
var ember: StandardMaterial3D

func build() -> void:
	stone = _stone(Color("#292b30"))
	pale = _stone(Color("#434247"))
	black = StandardMaterial3D.new()
	black.albedo_color = Color("#0a0c12")
	ember = StandardMaterial3D.new()
	ember.albedo_color = Color("#aa431b")
	ember.emission_enabled = true
	ember.emission = Color("#e96724")
	ember.emission_energy_multiplier = 2.0
	_terrace()
	# Near curtain walls frame the courtyard, rather than hiding the skyline.
	for side in [-1.0,1.0]:
		_wall(Vector3(side*27,0,-2),Vector3(2.5,9,54),true)
		for z in [-24.0,-8.0,8.0,24.0]:
			_tower(Vector3(side*27,0,z),3.2,14.0,true)
		for z in range(-22,25,6):
			_box(Vector3(side*25.1,4,float(z)),Vector3(1.4,8,1.4),pale)
	# Gatehouse opening remains passable.
	for side in [-1.0,1.0]:
		_wall(Vector3(side*16,0,-29),Vector3(21,11,3.5),true)
		_tower(Vector3(side*6.0,0,-29),3.4,18,true)
	_box(Vector3(0,13,-29),Vector3(7,4,3.5),stone,true)
	for x in [-20.0,-13.0,13.0,20.0]:
		_banner(Vector3(x,10,-26.9),Vector2(1.7,6.0))
	# Layered inner citadel with flanking towers, buttresses and lancet windows.
	_wall(Vector3(0,0,-60),Vector3(40,18,12))
	for x in [-21.0,-10.0,10.0,21.0]:
		_tower(Vector3(x,0,-56),4.1,31+absf(x)*0.30)
	_box(Vector3(0,22,-70),Vector3(20,44,19),stone)
	for x in [-11.0,11.0]:
		_belfry(Vector3(x,0,-68),5.2,48)
	_belfry(Vector3(0,0,-79),8.0,61)
	for x in [-8.0,-4.0,0.0,4.0,8.0]:
		_box(Vector3(x,17,-59.6),Vector3(0.85,34,1.8),pale)
		for y in [9.0,18.0,29.0,38.0]:
			_window(Vector3(x+1.6,y,-59.5),0.6,2.7)
	_banner(Vector3(0,37,-59.3),Vector2(3.0,14.0))
	for side in [-1.0,1.0]:
		for i in range(4):
			_tower(Vector3(side*(35+i*13),-4,-83-i*9),3.8,22+i*5)
	# Narrow foreground ramparts provide repeated masonry/torch scale cues.
	for x in [-17.0,17.0]:
		for z in [-20.0,-9.0,2.0,13.0]:
			_box(Vector3(x,0.38,z),Vector3(1.0,0.76,1.0),pale,true)
			_torch(Vector3(x,0.9,z))
	_mountains()

func _belfry(at: Vector3, width: float, height: float) -> void:
	_box(at+Vector3(0,height*0.5,0),Vector3(width,height,width),stone)
	for side in [-1.0,1.0]:
		for depth in [-1.0,1.0]:
			var corner := at+Vector3(side*width*0.5,0,depth*width*0.5)
			_box(corner+Vector3(0,height*0.5,0),Vector3(0.65,height+2.5,0.65),pale)
			var spire := CylinderMesh.new()
			spire.top_radius = 0
			spire.bottom_radius = 0.55
			spire.height = 4.5
			spire.radial_segments = 4
			var finial := MeshInstance3D.new()
			finial.mesh = spire
			finial.position = corner+Vector3(0,height+3.5,0)
			finial.material_override = pale
			add_child(finial)
	for y in range(8,int(height-3),7):
		_box(at+Vector3(0,y,0),Vector3(width+0.4,0.35,width+0.4),pale)
		for x in [-0.27,0.27]:
			_window(at+Vector3(x*width,float(y)+2.3,width*0.5+0.06),0.65,3.6)
	_box(at+Vector3(0,height,0),Vector3(width+0.8,0.7,width+0.8),pale)

func _terrace() -> void:
	_box(Vector3(0,3.5,21),Vector3(17,1,14),stone,true)
	for side in [-1.0,1.0]:
		_wall(Vector3(side*8.0,4.0,21),Vector3(0.65,1.1,14),true)
		_wall(Vector3(side*5.4,4.0,14.3),Vector3(6.0,1.1,0.65),true)
		_torch(Vector3(side*7.2,5.2,15))
		_banner(Vector3(side*7.9,3.3,13.9),Vector2(1.3,2.8))
	for i in range(16):
		var height := (16-i)*0.25
		_box(Vector3(0,height*0.5,13.8-i*0.42),Vector3(4.4,height,0.46),pale,true)

func _stone(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = MASONRY
	mat.set_shader_parameter("base_color",color)
	return mat

func _box(pos: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visible := MeshInstance3D.new()
	visible.mesh = mesh
	visible.position = pos
	visible.material_override = material
	add_child(visible)
	if solid:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		visible.add_child(body)
	return visible

func _wall(at: Vector3, size: Vector3, solid: bool = false) -> void:
	_box(at+Vector3(0,size.y*0.5,0),size,stone,solid)
	_box(at+Vector3(0,size.y-0.35,0),Vector3(size.x+0.5,0.6,size.z+0.5),pale)
	var along_x := size.x>size.z
	var count := int(maxf(size.x,size.z)/1.5)
	for i in range(count):
		var d := (i-float(count-1)*0.5)*1.5
		_box(at+Vector3(d if along_x else 0,size.y+0.5,0 if along_x else d),Vector3(0.78 if along_x else size.x,1.1,size.z if along_x else 0.78),pale)

func _tower(at: Vector3, radius: float, height: float, solid: bool = false) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius*0.86
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var tower := MeshInstance3D.new()
	tower.mesh = mesh
	tower.position = at+Vector3(0,height*0.5,0)
	tower.material_override = stone
	add_child(tower)
	if solid:
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		tower.add_child(body)
	for y in [height*0.33,height*0.66,height-0.5]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius*0.86
		ring.outer_radius = radius*1.02
		ring.rings = 12
		ring.ring_segments = 4
		var band := MeshInstance3D.new()
		band.mesh = ring
		band.position = at+Vector3(0,y,0)
		band.material_override = pale
		add_child(band)
	for i in range(8):
		var a := i*TAU/8.0
		var offset := Vector3(sin(a)*radius*0.87,0,cos(a)*radius*0.87)
		_box(at+offset+Vector3(0,height+0.45,0),Vector3(0.9,1.9,0.9),pale)
		var cone := CylinderMesh.new()
		cone.top_radius = 0
		cone.bottom_radius = 0.42
		cone.height = 2.4
		cone.radial_segments = 4
		var spire := MeshInstance3D.new()
		spire.mesh = cone
		spire.position = at+offset+Vector3(0,height+2.5,0)
		spire.material_override = stone
		add_child(spire)
	for y in range(5,int(height-3),6):
		_window(at+Vector3(0,float(y),radius*0.96),0.55,2.5)

func _window(at: Vector3, width: float, height: float) -> void:
	_box(at,Vector3(width,height,0.08),black)
	for x in [-1.0,1.0]:
		_box(at+Vector3(x*(width*0.5+0.1),0,0.04),Vector3(0.16,height+0.25,0.22),pale)
		var cap := _box(at+Vector3(x*width*0.27,height*0.5+width*0.23,0.04),Vector3(0.14,width*0.85,0.22),pale)
		cap.rotation.z = -x*0.63
	_box(at+Vector3(0,-height*0.2,0.06),Vector3(width*0.45,height*0.34,0.02),ember)
	_box(at+Vector3(0,0,0.09),Vector3(0.065,height,0.04),black)

func _banner(at: Vector3, size: Vector2) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 10
	mesh.subdivide_depth = 16
	var mat := ShaderMaterial.new()
	mat.shader = CLOTH
	mat.set_shader_parameter("cloth_color",Color("#441923"))
	mat.set_shader_parameter("wind_strength",0.16)
	var flag := MeshInstance3D.new()
	flag.mesh = mesh
	flag.material_override = mat
	flag.rotation.x = PI*0.5
	flag.position = at
	add_child(flag)
	_box(at+Vector3(0,size.y*0.5,0),Vector3(size.x+0.4,0.12,0.15),black)

func _torch(at: Vector3) -> void:
	_box(at,Vector3(0.18,1.2,0.18),black)
	_box(at+Vector3(0,0.65,0),Vector3(0.42,0.2,0.42),black)
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.55
	var flame := MeshInstance3D.new()
	flame.mesh = mesh
	flame.position = at+Vector3(0,0.91,0)
	flame.material_override = ember
	add_child(flame)
	var light := OmniLight3D.new()
	light.position = at+Vector3(0,1.1,0)
	light.light_color = Color("#ff924d")
	light.light_energy = 2.6
	light.omni_range = 6
	add_child(light)

func _mountains() -> void:
	# Continuous eroded ridges, not isolated cone/pyramid placeholders.
	var noise := FastNoiseLite.new()
	noise.seed = 1709
	noise.frequency = 0.014
	noise.fractal_octaves = 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-50,50):
		for x in range(-50,50):
			if Vector2(x,z).length()<16.0:
				continue
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var px: float = (x+corner.x)*8.0
				var pz: float = (z+corner.y)*8.0
				var distance_from_center := Vector2(px,pz).length()
				var rise := smoothstep(125.0,210.0,distance_from_center)
				var ridge := 1.0-absf(noise.get_noise_2d(px,pz))
				var elevation := (ridge*ridge*ridge*65.0+noise.get_noise_2d(px*2.1,pz*2.1)*14.0)*rise-12.0
				st.add_vertex(Vector3(px,elevation,pz))
	st.generate_normals()
	var mountain := MeshInstance3D.new()
	mountain.mesh = st.commit()
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color("#20212a")
	rock.roughness = 0.98
	mountain.material_override = rock
	add_child(mountain)
