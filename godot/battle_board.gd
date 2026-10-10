extends Control
signal cell_clicked(pos: int)
signal enemy_focused(uid: String)
signal deploy_drag(uid: String, pos: int)
const CELL = 1.35
var units: Array = [] # Demo scenery consumes an empty visual roster; gameplay is below.
var camera_mode := 0
var right_panel: Control
var world
var view: SubViewport
var viewport_container: SubViewportContainer
var overlay: Control
var portraits
var data: Dictionary = {}
var preview: Dictionary = {}
var kind := "attack"
var reference_mode := false
var selected := ""
var targets: Array = []
var actors: Dictionary = {}
var ghost: Sprite3D
var press_cell := -1
var press_uid := ""
var pulse := 0.0
var hit_tween: Tween
var low_hp_font: FontVariation
var inspected_enemy := ""
var hover_uid := ""
var keyboard_cell := 24
var last_visual_phase := ""
var projected_pitch := Vector2(64,48)
var visual_height := 1.55
var visual_width := 1.55
func _ready():
	low_hp_font=FontVariation.new();low_hp_font.base_font=ThemeDB.fallback_font;low_hp_font.variation_embolden=1.0
	custom_minimum_size=Vector2(120,80)
	focus_mode=Control.FOCUS_ALL;clip_contents=true
	size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
	right_panel=self
	viewport_container=SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch=true
	viewport_container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)
	view=SubViewport.new();view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(view)
	world=load("res://demo_courtyard.gd").new();world.lab=self;view.add_child(world)
	world.selection.visible=false
	ghost=Sprite3D.new();ghost.billboard=BaseMaterial3D.BILLBOARD_ENABLED;ghost.modulate=Color(1,1,1,.4)
	ghost.no_depth_test=true;ghost.visible=false;world.add_child(ghost)
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(overlay);overlay.draw.connect(draw_overlay)
	resized.connect(func():call_deferred("update_camera"))
	call_deferred("update_camera")
	gui_input.connect(input_event)
	mouse_exited.connect(func():hover_uid="";tooltip_text="";overlay.queue_redraw())
func cell_world(c: Vector2i) -> Vector3:
	return Vector3((c.x-4.5)*CELL,.15,(c.y-2.0)*CELL)
func point(p: int) -> Vector3: return cell_world(Vector2i(p%10,p/10))
func project(v: Vector3) -> Vector2:
	return world.camera.unproject_position(v)*size/Vector2(view.size)
func project_cell(p: int) -> Vector2: return project(point(p)+Vector3(0,.03,0))
func cell_at(at: Vector2) -> int:
	var scaled=at*Vector2(view.size)/size
	var origin=world.camera.project_ray_origin(scaled)
	var direction=world.camera.project_ray_normal(scaled)
	var hit=Plane(Vector3.UP,.15).intersects_ray(origin,direction)
	if hit==null: return -1
	var x=int(floor(hit.x/CELL+5.0));var y=int(floor(hit.z/CELL+2.5))
	return y*10+x if x>=0 and x<10 and y>=0 and y<5 else -1
func unit_at(p: int) -> Dictionary:
	for u in (data.get("state",{}) as Dictionary).get("units",[]):
		if int(u.pos)==p and u.hp>0: return u
	return {}
func input_event(event):
	if reference_mode and (event is InputEventKey and event.keycode in [KEY_ENTER,KEY_KP_ENTER] or event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]):accept_event();return
	if event is InputEventKey and event.pressed and not event.echo:
		var x=keyboard_cell%10;var y=int(keyboard_cell/10)
		match event.keycode:
			KEY_LEFT:x=maxi(0,x-1)
			KEY_RIGHT:x=mini(9,x+1)
			KEY_UP:y=maxi(0,y-1)
			KEY_DOWN:y=mini(4,y+1)
			KEY_ENTER,KEY_KP_ENTER:cell_clicked.emit(keyboard_cell);accept_event();return
			_:return
		keyboard_cell=y*10+x;accept_event();overlay.queue_redraw();return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			var inspected=unit_at(cell_at(event.position))
			if inspected.get("side")=="enemy":enemy_focused.emit(str(inspected.id))
			accept_event();return
		if event.button_index==MOUSE_BUTTON_WHEEL_UP or event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			world.zoom=clampf(world.zoom+(-.6 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .6),10,24);update_camera();return
		if event.button_index==MOUSE_BUTTON_LEFT:
			var pos=cell_at(event.position)
			if event.pressed:
				grab_focus();keyboard_cell=pos if pos>=0 else keyboard_cell
				press_cell=pos;press_uid=str(unit_at(pos).get("id",""))
			elif pos>=0:
				if pos!=press_cell and not press_uid.is_empty() and data.get("state",{}).get("deploying",false): deploy_drag.emit(press_uid,pos)
				else: cell_clicked.emit(pos)
	if event is InputEventMouseMotion:
		var u=unit_at(cell_at(event.position))
		hover_uid=str(u.get("id",""))
		tooltip_text=str(u.get("name",""))
		if not u.is_empty():
			tooltip_text+="\nHP %d/%d  MP %d/%d" % [u.hp,u.max,u.mp,u.maxMp]
			for e in data.get("enemyInfo",[]):
				if e.id==u.id:tooltip_text+="\n通常射程 %d / %s %s\n%s" % [e.normalReach,e.skill,"同横列・経路条件" if e.skillReach==null else str(e.skillReach),e.reason]
func set_camera(mode: int):
	camera_mode=mode%3;update_camera();overlay.queue_redraw()
func compact_board() -> bool:return size.y<300
func framing_bounds() -> Rect2:
	var result=Rect2();var first=true
	for x in [-7.2,7.2]:
		for z in [-3.8,3.8]:
			for y in [.15,1.15]:
				var screen=project(Vector3(x,y,z))
				if first:result=Rect2(screen,Vector2.ZERO);first=false
				else:result=result.expand(screen)
	return result
func update_camera():
	if world==null or world.camera==null or view.size.x<=0 or view.size.y<=0 or size.y<=0:return
	world.update_camera()
	if compact_board():
		# The standalone comparison demo keeps its scenery framing. Battle fits the grid.
		var camera: Camera3D=world.camera;var target=Vector3(0,.55,0)
		var direction=(camera.position-target).normalized()
		if camera_mode==1:direction=Vector3(sin(world.angle+.16)*20,13.2,cos(world.angle+.16)*20).normalized()
		camera.look_at(target)
		if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:
			camera.size=16.0
			var bounds=framing_bounds()
			camera.size*=maxf(bounds.size.x/maxf(1,size.x-40),bounds.size.y/maxf(1,size.y-20))
			camera.size*=world.zoom/16.5
		else:
			var distance=24.0
			for attempt in range(6):
				camera.position=target+direction*distance;camera.look_at(target)
				var bounds=framing_bounds();var ratio=maxf(bounds.size.x/maxf(1,size.x-40),bounds.size.y/maxf(1,size.y-20))
				distance*=maxf(.7,ratio)
			camera.position=target+direction*distance*(world.zoom/16.5);camera.look_at(target)
	projected_pitch=measure_cell_pitch();visual_height=1.55
	if compact_board():
		var max_pixels=1.0
		for pos in range(50):max_pixels=maxf(max_pixels,project(point(pos)+camera_up()).distance_to(project(point(pos))))
		visual_height=minf(1.55,projected_pitch.y*.78/max_pixels);visual_width=projected_pitch.x*.72/max_pixels
	refresh_actor_scale()
	if is_instance_valid(overlay):overlay.queue_redraw()
func cell_pitch() -> Vector2:return projected_pitch
func measure_cell_pitch() -> Vector2:
	var pitch=Vector2(INF,INF)
	for pos in range(50):
		if pos%10<9:pitch.x=minf(pitch.x,project_cell(pos).distance_to(project_cell(pos+1)))
		if pos<40:pitch.y=minf(pitch.y,project_cell(pos).distance_to(project_cell(pos+10)))
	return pitch
func sprite_height() -> float:return visual_height
func camera_up() -> Vector3:return world.camera.global_basis.y
func sprite_origin(sprite: Sprite3D=null) -> Vector3:
	if not compact_board():return Vector3(0,.75,0)
	var height=visual_height if sprite==null or sprite.texture==null else sprite.pixel_size*sprite.texture.get_height()
	return camera_up()*height*.5
func texture_pixel_size(texture: Texture2D) -> float:
	var pixels=visual_height/texture.get_height()
	return minf(pixels,visual_width/texture.get_width()) if compact_board() else pixels
func refresh_actor_scale():
	for nodes in actors.values():
		if nodes.sprite.texture:nodes.sprite.pixel_size=texture_pixel_size(nodes.sprite.texture)
		if not hit_tween or not hit_tween.is_running():nodes.sprite.position=sprite_origin(nodes.sprite)
	if is_instance_valid(ghost) and ghost.visible and ghost.texture and preview.get("destination")!=null:
		ghost.pixel_size=texture_pixel_size(ghost.texture);ghost.position=point(int(preview.destination))+sprite_origin(ghost)
func update_state(d: Dictionary, pr: Dictionary, command: String, uid: String, chosen: Array):
	var phase_key=JSON.stringify(d.get("presentation"))
	if phase_key!=last_visual_phase:reset_animation()
	last_visual_phase=phase_key
	data=d;preview=pr;kind=command;selected=uid;targets=chosen
	var state: Dictionary=d.get("state") if d.get("state") is Dictionary else {}
	var phase: Dictionary=d.get("presentation") if d.get("presentation") is Dictionary else {}
	var live_ids=[]
	for u in state.get("units",[]):
		live_ids.append(u.id)
		if not actors.has(u.id):
			var root=Node3D.new();world.add_child(root)
			var sprite=Sprite3D.new();sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.position.y=.75
			sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.15
			root.add_child(sprite)
			var label=Label3D.new();label.position.y=1.65;label.pixel_size=.0045;label.font_size=34
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.outline_size=8;root.add_child(label)
			actors[u.id]={"root":root,"sprite":sprite,"label":label}
		var nodes=actors[u.id]
		nodes.root.position=point(int(u.pos))
		nodes.root.visible=u.hp>0 or (phase.get("phase")=="hurt" and phase.get("unit_id")==u.id)
		nodes.sprite.texture=portraits.texture(u)
		if nodes.sprite.texture:nodes.sprite.pixel_size=1.55/nodes.sprite.texture.get_height()
		# Enemy PNGs already face left; allies/custom portraits keep their source orientation.
		nodes.sprite.flip_h=false
		nodes.label.text="%s\n%d/%d%s" % [u.name,u.hp,u.max," 防" if u.get("guard",false) else ""]
		var low=u.max>0 and u.hp*4<u.max
		nodes.label.modulate=Color("#ff9494") if low else Color("#a9ede0") if u.side=="ally" else Color("#f3b4b4")
		nodes.label.font=low_hp_font if low else ThemeDB.fallback_font
		nodes.label.visible=false # Fixed-size 2D callouts and bars replace overlapping world labels.
	for uid_ in actors.keys():
		if not live_ids.has(uid_):actors[uid_].root.queue_free();actors.erase(uid_)
	ghost.visible=false
	if preview.get("destination")!=null:
		for u in state.get("units",[]):
			if u.id==state.get("actor"):
				ghost.texture=portraits.texture(u);ghost.pixel_size=1.55/ghost.texture.get_height()
				ghost.position=point(int(preview.destination))+Vector3(0,.75,0);ghost.visible=true
	refresh_actor_scale()
	overlay.queue_redraw()
func arrow(a: Vector2,b: Vector2,color: Color,width:=2.0):
	if a.distance_to(b)<4:return
	overlay.draw_line(a,b,color,width,true)
	var dir=(a-b).normalized()
	overlay.draw_line(b,b+dir.rotated(.5)*12,color,width,true)
	overlay.draw_line(b,b+dir.rotated(-.5)*12,color,width,true)
func dashed(a: Vector2,b: Vector2,color: Color):
	var n=maxi(1,int(a.distance_to(b)/10))
	for i in range(0,n,2):overlay.draw_line(a.lerp(b,float(i)/n),a.lerp(b,minf(float(i+1)/n,1)),color,2,true)
func cell_outline(p: int,color: Color,width:=2.0):
	var points=PackedVector2Array()
	for offset in [Vector3(-.58,.05,-.58),Vector3(.58,.05,-.58),Vector3(.58,.05,.58),Vector3(-.58,.05,.58),Vector3(-.58,.05,-.58)]:points.append(project(point(p)+offset))
	overlay.draw_polyline(points,color,width,true)
func legal_target_cells() -> Array:
	var result=[]
	if data.get("state",{}).get("deploying",false):return data.get("deployment",{}).get(selected,{}).get("ambush",[])
	for option in data.get("choices",{}).get(kind,[]):
		for target in option if option is Array else [option]:
			if target is float or target is int:result.append(int(target))
			else:
				for u in data.get("state",{}).get("units",[]):
					if u.id==target:result.append(int(u.pos))
	return result
func draw_overlay():
	if world==null or data.is_empty():return
	var state: Dictionary=data.get("state") if data.get("state") is Dictionary else {}
	var ranges=preview.get("ranges",data.get("ranges",{}).get(kind,[]))
	if preview.is_empty() and kind in ["move","return"]:ranges=data.get("choices",{}).get(kind,[])
	if state.get("deploying",false): ranges=data.get("deployment",{}).get(selected,{}).get("ranges",[])
	for p in ranges:
		var w=point(int(p));var poly=PackedVector2Array()
		for offset in [Vector3(-.58,.04,-.58),Vector3(.58,.04,-.58),Vector3(.58,.04,.58),Vector3(-.58,.04,.58)]:poly.append(project(w+offset))
		overlay.draw_colored_polygon(poly,Color(.25,.65,1,.2))
	if not reference_mode:
		for p in legal_target_cells():cell_outline(int(p),Color(.3,.9,.55,.65))
	for p in preview.get("cells",[]):cell_outline(int(p),Color("#fb923c"),3.0)
	if preview.get("target") is float or preview.get("target") is int:cell_outline(int(preview.target),Color("#fff0ac"),3.0)
	var threats={}
	for u in state.get("units",[]):
		if u.side!="enemy" or u.hp<=0 or not u.get("intent") is Dictionary:continue
		for p in u.intent.get("cells",[]):threats[int(p)]=threats.get(int(p),0)+1
		if u.intent.get("destination")!=null:
			var dest=project_cell(int(u.intent.destination))
			overlay.draw_string(ThemeDB.fallback_font,dest+Vector2(-5,18),"↓",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("#fda4af"))
	for p in threats:
		cell_outline(p,Color("#fb7185"))
		var center=project_cell(p)
		for stripe in [-8,0,8]:overlay.draw_line(center+Vector2(stripe-6,-7),center+Vector2(stripe+6,7),Color(1,.45,.55,.65),1.0,true)
		overlay.draw_string(ThemeDB.fallback_font,project_cell(p)+Vector2(14,-8),"!%d" % threats[p],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	for side in ["ally","enemy"]:
		var slots=[24,13,33] if side=="ally" else [25,16,36]
		var active=data.get("formed",{}).get(side,false)
		var color=Color("#ffe197") if active else Color(.82,.8,.62,.6)
		for i in range(3):
			var at=project_cell(slots[i]);dashed(at,project_cell(slots[(i+1)%3]),color)
			if active:overlay.draw_circle(at,13+sin(pulse*3)*2,Color(1,.82,.35,.18))
			overlay.draw_circle(at,5,color)
	for u in state.get("units",[]):
		if u.hp<=0:continue
		if u.id==(data.presentation.get("actor_id") if data.get("presentation") is Dictionary else state.get("actor")) or u.id==selected:overlay.draw_arc(project_cell(u.pos),18,0,TAU,40,Color("#fff0ac"),2,true)
		if targets.has(u.id):overlay.draw_circle(project_cell(u.pos),10,Color(.2,1,.55,.6))
		if u.side=="enemy" and u.get("intent")!=null:
			var valid=false
			for e in data.get("enemyInfo",[]):
				if e.id==u.id:valid=e.valid
			for p in u.intent.cells:
				arrow(project_cell(u.pos),project_cell(p),(Color(1,.38,.36,.95) if valid else Color(.86,.74,.47,.85)) if inspected_enemy.is_empty() or inspected_enemy==u.id else Color(.86,.6,.55,.35),3.0 if inspected_enemy==u.id else 1.5)
	if preview.get("destination")!=null:
		var actor={}
		for u in state.get("units",[]):
			if u.id==state.get("actor"):actor=u
		if not actor.is_empty():arrow(project_cell(actor.pos),project_cell(preview.destination),Color("#88ffd2"),3)
		overlay.draw_string(ThemeDB.fallback_font,project_cell(int(preview.destination))+Vector2(-8,-16),"仮",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#88ffd2"))
	var font=ThemeDB.fallback_font
	for x in range(10):overlay.draw_string(font,project(point(40+x)+Vector3(0,.02,.72)),str(x),HORIZONTAL_ALIGNMENT_CENTER,-1,18,Color("#83e9db") if x<5 else Color("#ffa4b5"))
	for y in range(5):overlay.draw_string(font,project(point(y*10)+Vector3(-.85,.02,0)),str(4-y),HORIZONTAL_ALIGNMENT_CENTER,-1,14,Color.WHITE)
	draw_unit_labels(state)
	if has_focus():
		cell_outline(keyboard_cell,Color("#78edce"),3.0)
		overlay.draw_string(ThemeDB.fallback_font,Vector2(8,size.y-10),("射程参考 / Escで同じ仮置きに戻る" if reference_mode else "フォーカス X%d,Y%d / Enterは候補選択" % [keyboard_cell%10,4-int(keyboard_cell/10)]),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
func draw_unit_labels(state: Dictionary):
	var shown: Array[Rect2]=[]
	var actor=state.get("actor","")
	if data.get("presentation") is Dictionary:actor=data.presentation.get("actor_id",actor)
	for u in state.get("units",[]):
		if u.hp<=0:continue
		var compact=compact_board();var pitch=cell_pitch() if compact else Vector2(64,48)
		var width=minf(48,pitch.x*.72);var at=project_cell(int(u.pos))+Vector2(0,3) if compact else project(point(int(u.pos))+Vector3(0,1.25,0))
		var color=Color("#a9ede0") if u.side=="ally" else Color("#f3b4b4")
		var low=u.get("max",0)>0 and u.hp*4<u.max
		if low:color=Color("#ff9494")
		at.x=clampf(at.x,width*.5+4,maxf(width*.5+4,size.x-width*.5-4));at.y=clampf(at.y,8,maxf(8,size.y-8))
		overlay.draw_rect(Rect2(at-Vector2(width*.5,0),Vector2(width,4 if compact else 5)),Color("#10202b"))
		overlay.draw_rect(Rect2(at-Vector2(width*.5,0),Vector2(width*clampf(float(u.hp)/maxf(1,u.max),0,1),4 if compact else 5)),color)
		if compact:
			var badge=at+Vector2(-width*.5-4,2)
			if u.side=="ally":overlay.draw_circle(badge,3,color)
			else:overlay.draw_colored_polygon(PackedVector2Array([badge+Vector2(0,-4),badge+Vector2(3,3),badge+Vector2(-3,3)]),color)
			if u.get("guard",false):overlay.draw_rect(Rect2(at-Vector2(width*.5+1,1),Vector2(width+2,6)),Color("#ffe197"),false,1)
		else:overlay.draw_string(ThemeDB.fallback_font,at+Vector2(-24,-5),("味" if u.side=="ally" else "敵")+(" 防" if u.get("guard",false) else ""),HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
		if u.id!=hover_uid:continue
		var per_column=maxi(1,int((size.y-20)/48))
		var rect=Rect2(Vector2(6 if shown.size()<per_column else maxf(6,size.x-158),8+(shown.size()%per_column)*48),Vector2(152,44))
		shown.append(rect)
		overlay.draw_line(project_cell(int(u.pos)),rect.position+rect.size/2,Color(color,.65),1.0,true)
		overlay.draw_rect(rect,Color(.04,.1,.14,.92));overlay.draw_rect(rect,color,false,1.0)
		var full=str(u.name);var short=full.left(7)+"…" if full.length()>8 else full
		var font=low_hp_font if low else ThemeDB.fallback_font
		overlay.draw_string(font,rect.position+Vector2(5,18),short,HORIZONTAL_ALIGNMENT_LEFT,142,16,color)
		overlay.draw_string(font,rect.position+Vector2(5,37),"HP %d/%d" % [u.hp,u.max],HORIZONTAL_ALIGNMENT_LEFT,142,16,color)
func reset_animation():
	if hit_tween and hit_tween.is_running():hit_tween.kill()
	hit_tween=null
	for nodes in actors.values():
		nodes.sprite.position=sprite_origin(nodes.sprite);nodes.sprite.modulate=Color.WHITE
func animate(p: Dictionary) -> float:
	reset_animation()
	if not actors.has(p.get("unit_id","")) or p.phase not in ["action","move","hurt","heal"]:return 0.0
	var root: Node3D=actors[p.unit_id].root
	var sprite: Sprite3D=actors[p.unit_id].sprite
	hit_tween=create_tween()
	if p.phase=="move":
		root.position=point(int(p.from));hit_tween.tween_property(root,"position",point(int(p.to)),.24)
		return .24
	if p.phase in ["action","hurt"]:
		# Legacy portrait-only shake. The caller waits before acknowledging the next phase.
		for dx in [0,-5,5,-4,4,-3,3,-2,2,0,0,0]:
			hit_tween.tween_property(sprite,"position",sprite_origin(sprite)+world.camera.global_basis.x*float(dx)*.018,.03)
		return .42
	sprite.modulate=Color(.6,1,.7)
	hit_tween.tween_property(sprite,"modulate",Color.WHITE,.3)
	return .3
func _process(delta):
	pulse+=delta
	if overlay:overlay.queue_redraw()
