extends SceneTree
var game
var checks=[]
var mask=0
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func frames(n:=8):
	for i in range(n):await process_frame
func send(point: Vector2,button:=0,pressed:=false,delta:=Vector2.ZERO):
	var event
	if button==0:event=InputEventMouseMotion.new();event.relative=delta
	else:event=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed
	if button>0 and button<=3:
		if pressed:mask|=1<<(button-1)
		else:mask&=~(1<<(button-1))
	event.button_mask=mask
	event.position=point;event.global_position=point;root.push_input(event,true);await frames(2)
func run():
	create_timer(30).timeout.connect(func():print("FAIL watchdog");quit(2))
	var evidence=OS.get_environment("INVENTORY_QA_ROOT")
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/inventory_battle_fixtures.cjs")]),output,true,false)
	var fixtures=JSON.parse_string("".join(output));await game.update({"op":"campaign_load","data":fixtures.guard});await frames()
	var left=game.hud.left_panel;var right=game.hud.right_panel
	await send(Vector2(960,500));await send(Vector2(960,500),MOUSE_BUTTON_RIGHT,true);await send(Vector2(990,500),0,false,Vector2(30,0));await send(Vector2(990,500),MOUSE_BUTTON_RIGHT,false)
	check(left.size.x<=400 and right.size.x<=440,"FHD side panels keep central playfield open")
	var camera=game.preferences.camera().duplicate(true)
	var header=left.find_child("DragHandle",true,false);var point=header.get_global_rect().get_center();var start=left.position
	await send(point);await send(point,MOUSE_BUTTON_LEFT,true);await send(point+Vector2(35,20),0,false,Vector2(35,20));await send(point+Vector2(35,20),MOUSE_BUTTON_LEFT,false)
	check(left.position!=start,"S7 viewport-dispatched header drag moves panel")
	var extent=left.size;point=left.global_position+left.size-Vector2(3,3)
	await send(point);await send(point,MOUSE_BUTTON_LEFT,true);await send(point+Vector2(30,35),0,false,Vector2(30,35));await send(point+Vector2(30,35),MOUSE_BUTTON_LEFT,false)
	check(left.size.x>extent.x and left.size.y>extent.y,"S7 viewport-dispatched corner drag resizes panel")
	point=left.global_position+Vector2(25,80);await send(point);await send(point,MOUSE_BUTTON_WHEEL_UP,true);await send(point,MOUSE_BUTTON_WHEEL_UP,false);await send(point,MOUSE_BUTTON_RIGHT,true);await send(point+Vector2(20,20),0,false,Vector2(20,20));await send(point+Vector2(20,20),MOUSE_BUTTON_RIGHT,false)
	check(game.preferences.camera()==camera,"S3 UI move/resize/scroll/right drag do not move camera")
	var pan=game.board.camera_pan;point=Vector2(960,500)
	await send(point);await send(point,MOUSE_BUTTON_RIGHT,true);await send(point+Vector2(50,0),0,false,Vector2(50,0));await send(point+Vector2(50,0),MOUSE_BUTTON_RIGHT,false)
	check(game.board.camera_pan!=pan,"S3 viewport-dispatched board right drag pans camera")
	var pitch=game.board.camera_pitch
	await send(point,MOUSE_BUTTON_MIDDLE,true);await send(point+Vector2(0,40),0,false,Vector2(0,40));await send(point+Vector2(0,40),MOUSE_BUTTON_MIDDLE,false)
	check(game.board.camera_pitch>pitch,"S3 viewport-dispatched middle drag tilts camera")
	var zoom=game.board.world.zoom;await send(point,MOUSE_BUTTON_WHEEL_UP,true);await send(point,MOUSE_BUTTON_WHEEL_UP,false)
	check(game.board.world.zoom<zoom,"S3 viewport-dispatched wheel zooms camera")
	var edges_ok=true
	for direction in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1),Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		left.position=Vector2(100,100);left.size=Vector2(320,500);await frames(2)
		point=left.global_position+left.size/2+direction*(left.size/2-Vector2(3,3))
		var delta=direction*20
		await send(point);await send(point,MOUSE_BUTTON_LEFT,true);await send(point+delta,0,false,delta);await send(point+delta,MOUSE_BUTTON_LEFT,false)
		if direction.x!=0:edges_ok=edges_ok and left.size.x>320
		if direction.y!=0:edges_ok=edges_ok and left.size.y>500
	check(edges_ok,"S7 all four edges and four corners resize through viewport events")
	var geom={"left":str(Rect2(left.global_position,left.size)),"right":str(Rect2(right.global_position,right.size)),"board":str(game.board.get_global_rect()),"queue":str(game.battle_header.get_global_rect()),"checks":checks,"input":"Godot viewport synthetic events, not OS mouse"}
	var f=FileAccess.open(evidence.path_join("input-layout.json"),FileAccess.WRITE);f.store_string(JSON.stringify(geom,"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
