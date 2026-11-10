extends Node3D
## The walkable crest sits directly beneath the existing tactical grid.
const FAR_BANK = "res://assets/sluice-farbank.webp"
var ferry: Node3D
var ridge: Node3D

func build(world) -> void:
	var water := ShaderMaterial.new()
	water.shader = preload("res://sluice_river.gdshader")
	world.box(Vector3(0,-0.66,-30), Vector3(144,0.08,54), water, self)
	var soil = world.material(Color("776747"))
	var turf = world.material(Color("74825b"))
	var meadow := PlaneMesh.new()
	meadow.size = Vector2(144, 92)
	meadow.subdivide_width = 200
	meadow.subdivide_depth = 160
	var ground_material := ShaderMaterial.new()
	ground_material.shader = preload("res://sluice_bank_ground.gdshader")
	var ground := MeshInstance3D.new()
	ground.mesh = meadow
	ground.material_override = ground_material
	ground.position.z = 37
	ground.extra_cull_margin = 1.5
	add_child(ground)
	world.box(Vector3(0,-0.5,-14), Vector3(75,0.9,5), turf, self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5525
	var reeds = world.material(Color("a79c59"))
	for i in range(22):
		var x := rng.randf_range(-14,14)
		var shore := -4.55 + .35*sin(x*.68) + .18*sin(x*1.31)
		for j in range(3):
			var blade = world.cylinder(Vector3(x+0.075*j,-0.28,shore),0.035,rng.randf_range(0.45,0.8),reeds,self,0.006)
			blade.rotation.z = rng.randf_range(-0.25,0.25)
	plant_meadow(world, rng)
	ferry = Node3D.new();add_child(ferry)
	ferry.position = Vector3(4.55,-0.48,-5.74)
	var hull = world.cylinder(Vector3.ZERO,1,0.35,world.wood,ferry,1.15)
	hull.scale = Vector3(1.40,1,0.45)
	world.box(Vector3(0,0.19,0),Vector3(2.30,0.08,0.68),soil,ferry)
	for x in [-0.68,0.58]:
		world.box(Vector3(x,0.28,0),Vector3(0.20,0.11,0.81),world.wood,ferry)
	var oar = world.box(Vector3(0,0.35,0.12),Vector3(0.07,0.08,1.65),world.wood,ferry)
	oar.rotation.y = 0.6
	# The landing only spans the short distance from the bank to the ferry.
	for i in range(6):
		world.box(Vector3(4.6,-.04,-4.05-.22*i),Vector3(.87,.09,.20),world.wood,self)
	for x in [4.19,5.01]:
		world.cylinder(Vector3(x,-.34,-5.2),.075,1.05,world.wood,self)
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
		skyline.extra_cull_margin = 24.0
		skyline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skyline.position=Vector3(0,quad.size.y*0.5-2.5,-7.8);add_child(skyline)

func set_route(route: String) -> void:
	ridge.visible = route == "short"


func plant_meadow(world, rng: RandomNumberGenerator) -> void:
	var leaf = world.material(Color("597343"))
	var light_leaf = world.material(Color("799150"))
	var stone_mat = world.material(Color("9c9986"))
	for spot in [Vector2(-7.2,4.3), Vector2(7.2,4.7), Vector2(9,6), Vector2(-12,5.3)]:
		world.cylinder(Vector3(spot.x,.49,spot.y),.1,.85,world.wood,self,.075)
		for j in range(3):
			var crown = world.cylinder(Vector3(spot.x+.34*cos(j*2.1),.92+.18*j,spot.y+.26*sin(j*2.1)),.55,.62,leaf if j<2 else light_leaf,self,.29)
			crown.rotation.z = .16*j
	for i in range(38):
		var x := rng.randf_range(-13,13)
		var z := rng.randf_range(3.65,7.7)
		if abs(x - (-.7-1.35*(z-3)+.63*sin(z*.85))) < 1.8:continue
		for j in range(3):
			var blade = world.cylinder(Vector3(x+.08*j,.19,z),.038,.34,light_leaf,self,.003)
			blade.rotation.z = (j-1)*.42
	for i in range(28):
		var rock = world.cylinder(Vector3(rng.randf_range(-9,9),.14,rng.randf_range(3.46,5.3)),rng.randf_range(.05,.15),.10,stone_mat,self,.05)
		rock.scale.z = .66
