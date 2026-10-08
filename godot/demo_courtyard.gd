extends Node3D
var lab
var camera: Camera3D
var sun: DirectionalLight3D
var scenery: Node3D
var grid_root: Node3D
var unit_nodes: Array = []
var unit_sprites: Array = []
var unit_labels: Array = []
var selection: MeshInstance3D
var angle = 0.0
var zoom = 16.5
var stone: StandardMaterial3D
var wood: StandardMaterial3D
var roof: StandardMaterial3D
var moss: StandardMaterial3D
var flat_shadows: Array = []

func material(c: Color, rough: float = 0.9, unshaded: bool = false) -> StandardMaterial3D:
	var m=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=rough
	if unshaded: m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func texture_mat(base: Color, kind: String) -> StandardMaterial3D:
	var img=Image.create(128,128,false,Image.FORMAT_RGB8)
	var rng=RandomNumberGenerator.new()
	rng.seed=5525
	for y in range(128):
		for x in range(128):
			var noise_=rng.randf_range(-.055,.055)
			var c=Color(base.r+noise_,base.g+noise_,base.b+noise_)
			var seam=false
			if kind=="stone": seam=y%32<2 or (x+(int(y/32)%2)*32)%64<2
			elif kind=="wood": seam=x%24<2 or (x%7==0 and y%17<13)
			else: seam=y%16<2 or (x+(int(y/16)%2)*12)%24<1
			if seam:c=c.darkened(.23)
			img.set_pixel(x,y,c)
	var m=material(Color.WHITE)
	img.generate_mipmaps()
	m.albedo_texture=ImageTexture.create_from_image(img)
	m.albedo_color=Color(.72,.72,.72)
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

func box(p: Vector3, dims: Vector3, mat: Material, parent_: Node3D = null) -> MeshInstance3D:
	var n=MeshInstance3D.new()
	var mesh=BoxMesh.new()
	mesh.size=dims
	n.mesh=mesh
	n.material_override=mat
	n.position=p
	(parent_ if parent_!=null else self).add_child(n)
	return n

func cylinder(p: Vector3, radius: float, height_: float, mat: Material, parent_: Node3D = null, top: float = -1.0) -> MeshInstance3D:
	var n=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.bottom_radius=radius
	mesh.top_radius=radius if top<0 else top
	mesh.height=height_
	mesh.radial_segments=10
	n.mesh=mesh
	n.material_override=mat
	n.position=p
	(parent_ if parent_!=null else self).add_child(n)
	return n

func _ready():
	stone=texture_mat(Color("9a9982"),"stone")
	wood=texture_mat(Color("654b36"),"wood")
	roof=texture_mat(Color("3c626c"),"roof")
	moss=material(Color("415941"))
	var env=WorldEnvironment.new()
	var e=Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("1b3945")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("bbd6cf")
	e.ambient_light_energy=0.45
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	e.fog_enabled=true
	e.fog_light_color=Color("31545e")
	e.fog_density=0.0025
	e.fog_sky_affect=0.0
	env.environment=e
	add_child(env)
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-47,-32,0)
	sun.light_color=Color("ffe4b6")
	sun.light_energy=0.90
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=60
	sun.shadow_bias=0.07
	add_child(sun)
	camera=Camera3D.new()
	camera.current=true
	camera.near=.1
	camera.far=160
	add_child(camera)
	# Low-poly water and raised land keep the layout visibly three dimensional.
	box(Vector3(0,-.9,0),Vector3(80,.15,75),material(Color("244953"),.25))
	box(Vector3(0,-.35,0),Vector3(16,1,10),texture_mat(Color("59624e"),"stone"))
	box(Vector3(0,.03,0),Vector3(15.6,.22,9.6),moss)
	box(Vector3(0,.055,0),Vector3(14,.1,7.2),stone)
	for y in range(5):
		for x in range(10):
			var base=Color("8a896a") if (x+y)%2==0 else Color("a29b79")
			base=base.lerp(Color("538174") if x<5 else Color("936962"),.16)
			box(lab.cell_world(Vector2i(x,y))-Vector3(0,.09,0),Vector3(lab.CELL-.024,.12,lab.CELL-.024),texture_mat(base,"stone"))
	grid_root=Node3D.new()
	add_child(grid_root)
	var gridmat=material(Color("b6b59b"))
	for x in range(11):box(Vector3((x-5)*lab.CELL,.16,0),Vector3(.018,.008,5*lab.CELL),gridmat,grid_root)
	for z in range(6):box(Vector3(0,.16,(z-2.5)*lab.CELL),Vector3(10*lab.CELL,.008,.018),gridmat,grid_root)
	box(Vector3(0,.173,0),Vector3(.04,.012,5*lab.CELL),material(Color("e9ce98")),grid_root)
	scenery=Node3D.new()
	add_child(scenery)
	build_scenery()
	for i in range(lab.units.size()):build_unit(i)
	selection=MeshInstance3D.new()
	var torus=TorusMesh.new()
	torus.inner_radius=.55
	torus.outer_radius=.61
	torus.rings=32
	torus.ring_segments=8
	selection.mesh=torus
	selection.material_override=material(Color("ffe5a1"),.6,true)
	add_child(selection)
	update_camera()

func build_scenery():
	# Back gate: only textured rectangular prisms, banners and small light sources.
	for sx in [-1,1]:
		var x=sx*2.55
		box(Vector3(x,1.55,-4.15),Vector3(.82,3.0,.82),stone,scenery)
		box(Vector3(x,3.10,-4.15),Vector3(1.06,.28,1.06),stone,scenery)
		box(Vector3(x,.28,-4.15),Vector3(1.12,.32,1.12),stone,scenery)
		box(Vector3(x+sx*.5,2.16,-3.67),Vector3(.58,.98,.035),material(Color("226c6a") if sx<0 else Color("843c4d")),scenery)
		box(Vector3(x+sx*.5,2.14,-3.63),Vector3(.075,.52,.023),material(Color("dec78b")),scenery)
		box(Vector3(x+sx*.5,2.15,-3.615),Vector3(.3,.075,.026),material(Color("dec78b")),scenery)
		lantern(Vector3(x,1.1,-3.55))
		box(Vector3(sx*5.75,.51,-4.18),Vector3(4.25,.85,.44),stone,scenery)
		box(Vector3(sx*5.75,1.0,-4.18),Vector3(4.5,.15,.68),stone,scenery)
		for z in [-1.0,2.8]:
			box(Vector3(sx*7.35,.52,z),Vector3(.48,.82,.62),stone,scenery)
			lantern(Vector3(sx*7.35,1.15,z))
		# Back buildings are deliberately made of textured cuboids, with a roof prism.
		house(Vector3(sx*5.2,0,-6.05),sx)
		for k in range(4): tree(Vector3(sx*(8.0+k*.8),-.3,-4.3+k*2.1),1.1+float(k%2)*.25)
		for k in range(7):
			var x2=sx*(8.8+(k%3)*2.1)
			var z2=-9.0-k*1.2
			tree(Vector3(x2,-.7,z2),1.4+float(k%3)*.4)
		# Terrace lip and simple stairs.
		box(Vector3(sx*7.75,-.12,0),Vector3(.34,.42,8.5),stone,scenery)
	for step in range(4):
		box(Vector3(0,-.18-step*.19,4.7+step*.35),Vector3(3.1,.23,.7),stone,scenery)
	# Crates, pots and patches establish practical model complexity.
	for p in [Vector3(-6.6,.52,-3.4),Vector3(-5.8,.4,-3.65),Vector3(6.65,.43,3.55)]:
		box(p,Vector3(.7,.7,.7),wood,scenery)
		box(p+Vector3(0,.02,.365),Vector3(.74,.10,.055),material(Color("ad9867")),scenery)
		box(p+Vector3(0,.02,.368),Vector3(.085,.73,.055),material(Color("ad9867")),scenery)
	var rng=RandomNumberGenerator.new()
	rng.seed=2525
	for i in range(40):
		var side=-1 if i%2==0 else 1
		var p=Vector3(rng.randf_range(-7.5,7.5),.18,side*rng.randf_range(3.55,4.2))
		cylinder(p,.08,.25,material(Color("597345")),scenery,.01)
		if i%4==0:cylinder(p+Vector3(0,.12,0),.055,.05,material(Color("d4b573")),scenery)

func house(p: Vector3, side: int):
	box(p+Vector3(0,.95,0),Vector3(2.45,1.85,1.8),texture_mat(Color("b2a184"),"stone"),scenery)
	box(p+Vector3(0,1.99,0),Vector3(2.75,.22,2.08),wood,scenery)
	var roofmesh=PrismMesh.new()
	roofmesh.size=Vector3(2.9,1.1,2.25)
	var r=MeshInstance3D.new()
	r.mesh=roofmesh
	r.material_override=roof
	r.position=p+Vector3(0,2.53,0)
	scenery.add_child(r)
	for x in [-.78,.78]:
		box(p+Vector3(x,1.22,.915),Vector3(.43,.58,.035),wood,scenery)
		var glow=material(Color("ffc97b"),.5,true)
		box(p+Vector3(x,1.22,.94),Vector3(.30,.43,.016),glow,scenery)
		box(p+Vector3(x,1.22,.96),Vector3(.035,.46,.02),wood,scenery)
	box(p+Vector3(0,.61,.92),Vector3(.47,1.16,.055),wood,scenery)
	box(p+Vector3(.8,2.94,-.2),Vector3(.40,.8,.43),stone,scenery)
	if side<0:box(p+Vector3(0,1.23,1.35),Vector3(2.6,.08,1.0),material(Color("386c6a")),scenery)

func lantern(p: Vector3):
	cylinder(p-Vector3(0,.27,0),.07,.55,wood,scenery)
	var m=material(Color("ffcb75"),.6,true)
	m.emission_enabled=true
	m.emission=Color("ffb75c")
	m.emission_energy_multiplier=1.2
	box(p,Vector3(.21,.29,.21),m,scenery)
	box(p+Vector3(0,.18,0),Vector3(.32,.07,.32),wood,scenery)
	var l=OmniLight3D.new()
	l.position=p
	l.light_color=Color("ffbd73")
	l.light_energy=1.5
	l.omni_range=2.1
	scenery.add_child(l)

func tree(p: Vector3, s: float):
	cylinder(p+Vector3(0,.65*s,0),.15*s,1.3*s,wood,scenery)
	for j in range(3):
		cylinder(p+Vector3(0,(1.18+j*.49)*s,0),(.93-j*.17)*s,1.27*s,material(Color("254e43").lightened(j*.05)),scenery,.02)

func build_unit(i: int):
	var u=lab.units[i]
	var root=Node3D.new()
	root.position=lab.cell_world(u.cell)
	add_child(root)
	unit_nodes.append(root)
	# Shadows use a small flat contact disc, never a full opaque character quad.
	var shadowmat=material(Color(0.015,.05,.055,.28),1.0,true)
	shadowmat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc=cylinder(Vector3(0,.015,0),.42,.006,shadowmat,root)
	disc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flat_shadows.append(disc)
	var sprite=Sprite3D.new()
	sprite.texture=lab.textures[u.art]
	sprite.pixel_size=1.4/1254.0
	sprite.position.y=.60
	sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold=.4
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded=false
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.flip_h=u.side==1
	root.add_child(sprite)
	unit_sprites.append(sprite)
	var label_=Label3D.new()
	label_.text=u.name
	label_.font_size=40
	label_.pixel_size=.0065
	label_.position=Vector3(0,1.42,0)
	label_.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label_.modulate=Color("7be5d2") if u.side==0 else Color("f4a3a2")
	label_.outline_size=9
	label_.outline_modulate=Color("10252e")
	label_.no_depth_test=true
	root.add_child(label_)
	unit_labels.append(label_)
	var teammat=material(Color("71dec9") if u.side==0 else Color("de8c87"),.8,true)
	box(Vector3(0,.035,.47),Vector3(.69,.025,.075),teammat,root)

func sync_positions():
	for i in unit_nodes.size():unit_nodes[i].position=lab.cell_world(lab.units[i].cell)

func refresh():
	grid_root.visible=lab.grid_on
	scenery.visible=lab.props_on
	selection.position=lab.cell_world(lab.units[lab.selected].cell)+Vector3(0,.07,0)
	for i in unit_nodes.size():
		unit_sprites[i].shaded=lab.sprite_light
		unit_sprites[i].scale=Vector3.ONE*lab.scale_factor
		unit_sprites[i].position.y=.60*lab.scale_factor
		unit_labels[i].visible=lab.labels_on
		unit_labels[i].position.y=1.42*lab.scale_factor
		flat_shadows[i].visible=lab.shadows_on

func update_camera():
	if camera==null:return
	var target=Vector3(0,.6,-1.1)
	camera.keep_aspect=Camera3D.KEEP_WIDTH
	if lab.camera_mode==0:
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=zoom * maxf(1.0,lab.right_panel.size.x / maxf(1.0,lab.right_panel.size.y) / 1.62)
		camera.position=Vector3(sin(angle)*17,13,cos(angle)*17)
	elif lab.camera_mode==1:
		camera.projection=Camera3D.PROJECTION_PERSPECTIVE
		camera.fov=48
		camera.position=Vector3(sin(angle+.16)*20,8.8,cos(angle+.16)*20) * (zoom/16.5)
	else:
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=zoom * maxf(1.0,lab.right_panel.size.x / maxf(1.0,lab.right_panel.size.y) / 1.62)
		camera.position=Vector3(sin(angle)*10,23,cos(angle)*10)
	camera.look_at(target)
