extends Node3D
## The walkable crest sits directly beneath the existing tactical grid.
const FAR_BANK = "res://assets/sluice-farbank.webp"
var ferry: Node3D
var ridge: Node3D

func build(world) -> void:
	var water := ShaderMaterial.new()
	water.shader = preload("res://sluice_river.gdshader")
	world.box(Vector3(0,-0.66,0), Vector3(120,0.08,100), water, self)
	var soil = world.material(Color("776747"))
	var turf = world.material(Color("74825b"))
	var gravel = world.texture_mat(Color("a59b76"), "earth")
	gravel.uv1_scale = Vector3(14, 3, 1)
	world.box(Vector3(0,-0.34,0), Vector3(40,0.70,7.3), soil, self)
	world.box(Vector3(0,0.04,0), Vector3(40,0.16,6.98), turf, self)
	world.box(Vector3(0,0.105,0), Vector3(40,0.08,6.76), gravel, self)
	for side in [-1,1]:
		var slope = world.box(Vector3(0,-0.31,float(side)*3.70),Vector3(40,0.15,1.30),turf,self)
		slope.rotation.x = side * 0.55
	world.box(Vector3(0,-0.5,-14), Vector3(75,0.9,5), turf, self)
	var reeds = world.material(Color("a79c59"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5525
	for i in range(35):
		var x := rng.randf_range(-16,16)
		var z := rng.randf_range(3.76,4.32) * (-1 if i%2 else 1)
		for j in range(3):
			var blade = world.cylinder(Vector3(x+0.075*j,-0.29,z),0.035,rng.randf_range(0.45,0.8),reeds,self,0.006)
			blade.rotation.z = rng.randf_range(-0.25,0.25)
	ferry = Node3D.new();add_child(ferry)
	ferry.position = Vector3(-1.5,-0.48,-5.1)
	var hull = world.cylinder(Vector3.ZERO,1,0.35,world.wood,ferry,1.15)
	hull.scale = Vector3(1.40,1,0.45)
	world.box(Vector3(0,0.19,0),Vector3(2.30,0.08,0.68),soil,ferry)
	for x in [-0.68,0.58]:
		world.box(Vector3(x,0.28,0),Vector3(0.20,0.11,0.81),world.wood,ferry)
	var oar = world.box(Vector3(0,0.35,0.12),Vector3(0.07,0.08,1.65),world.wood,ferry)
	oar.rotation.y = 0.6
	for x in [-3.0,-1.0,1.0]:world.cylinder(Vector3(x,-0.32,-4.16),0.085,1.05,world.wood,self)
	ridge = Node3D.new();add_child(ridge)
	for i in range(8):
		var rock = world.cylinder(Vector3(i*2.5-9,0,-12.5),1.5,1.4,world.stone,ridge,0.55)
		rock.rotation.z = rng.randf_range(-0.35,0.35)
	if ResourceLoader.exists(FAR_BANK,"Texture2D"):
		var painting: Texture2D = load(FAR_BANK)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://sluice_farbank.gdshader")
		mat.set_shader_parameter("painting", painting)
		var quad := QuadMesh.new()
		quad.size = Vector2(120, 50)
		var skyline := MeshInstance3D.new();skyline.mesh=quad;skyline.material_override=mat
		skyline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skyline.position=Vector3(0,quad.size.y*0.5-2.5,-7.8);add_child(skyline)

func set_route(route: String) -> void:
	ridge.visible = route == "short"
	ferry.position.x = -3.8 if ridge.visible else -1.5
