extends SceneTree
var game
var fixtures={}
var checks=[]
var failures=[]
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
var visible_run=OS.get_cmdline_user_args().has("--visible-captures")
var reproduce_only=OS.get_cmdline_user_args().has("--reproduce-only")
var records=[]
var cursor_marker: ColorRect
var last_pointer=Vector2.ZERO
func _initialize():call_deferred("run")
func check(ok: bool,detail: String):
	checks.append({"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+detail)
	if not ok:failures.append(detail)
func settle():
	for i in range(10):await process_frame
	var deadline=Time.get_ticks_msec()+10000
	while (game.locked or game.engine.busy or game.presenting or game.preview_pending) and Time.get_ticks_msec()<deadline:await process_frame
func load_fixture(id: String):
	await game.update({"op":"campaign_load","data":fixtures[id]});await settle()
func snap():return (await game.engine.request({"op":"campaign_save"})).data
func move_mouse(local: Vector2):
	var event=InputEventMouseMotion.new();event.position=game.board.global_position+local;event.global_position=event.position;last_pointer=event.position
	if is_instance_valid(cursor_marker):cursor_marker.position=event.position-Vector2(3,3)
	root.push_input(event,true);await settle()
func point_on_sprite(uid: String,part: float)->Vector2:
	var sprite=game.board.actors[uid].sprite;var img=sprite.texture.get_image()
	if img.is_compressed():img.decompress()
	var best=Vector2(-1,-1);var score=INF;var desired=Vector2(img.get_width()*.5,img.get_height()*part)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x,y).a<.5:continue
			var candidate=Vector2(x+.5,y+.5);var distance=candidate.distance_squared_to(desired)
			if distance<score:score=distance;best=candidate
	var centered=best-Vector2(img.get_width(),img.get_height())*.5
	return game.board.project(sprite.global_position+game.board.world.camera.global_basis.x*centered.x*sprite.pixel_size-game.board.camera_up()*centered.y*sprite.pixel_size)
func capture(id: String):
	if not visible_run:return
	await RenderingServer.frame_post_draw
	var path=evidence.path_join(id+".png");root.get_texture().get_image().save_png(path)
	records.append({"id":id,"path":path,"camera":game.board.camera_mode,"hover":game.board.hover_uid,"inspected":game.hud.person_box.get_meta("inspected_unit",""),"pending":game.pending,"size":[root.size.x,root.size.y],"pointer":[last_pointer.x,last_pointer.y]})
func pointer_cases():
	await load_fixture("battle");await game.choose_command("move");await game.on_cell(2);await settle()
	var before=await snap();var pending=game.pending
	for camera in range(3):
		game.board.set_camera(camera);await settle()
		for part in [["head",.15],["body",.5],["feet",.85]]:
			await move_mouse(point_on_sprite("guard",part[1]))
			check(game.board.hover_uid=="guard" and game.hud.person_box.get_meta("inspected_unit","")=="guard","Q05 camera%d %s inspects visible guard" % [camera,part[0]])
			check(game.pending==pending and game.command=="move","Q05 hover leaves provisional move unchanged")
			await capture("Q05-camera%d-%s" % [camera,part[0]])
		game.board.grab_focus();game.board.keyboard_cell=24
		var key=InputEventKey.new();key.keycode=KEY_RIGHT;key.pressed=true;root.push_input(key,true);await settle()
		check(game.board.hover_uid==str(game.board.unit_at(25).get("id","")) and game.pending==pending,"Q05 keyboard still inspects foot cell without retargeting")
	check(await snap()==before,"Q05 all inspection preserves exact campaign save")
func scale_and_selection_cases():
	for dims in [Vector2i(1920,1080),Vector2i(800,600)]:
		root.size=dims;await load_fixture("battle");var before=await snap()
		for camera in range(3):
			game.board.set_camera(camera)
			for zoom in [10.0,16.5,24.0]:
				game.board.world.zoom=zoom;game.board.update_camera();await settle();await move_mouse(point_on_sprite("guard",.5))
				check(game.board.hover_uid=="guard","Q05 resize/zoom "+str(dims)+" camera"+str(camera)+" zoom"+str(zoom))
		check(await snap()==before,"Q05 zoom/resize inspection preserves save")
	root.size=Vector2i(1920,1080);await load_fixture("battle");game.board.world.zoom=16.5;game.board.set_camera(0);await game.choose_command("attack");await settle()
	var uid=game.data.choices.attack[0]
	for u in game.state().units:
		if u.id==uid:await game.on_cell(int(u.pos));break
	await settle();var pending=game.pending;var chosen=game.chosen.duplicate();var before=await snap()
	await move_mouse(point_on_sprite("guard",.5))
	check(game.pending==pending and game.chosen==chosen and game.command=="attack" and await snap()==before,"Q05 inspecting another character preserves selected attack and resources")
	await load_fixture("deployment");await move_mouse(point_on_sprite("guard",.5));check(game.board.hover_uid=="guard","Q05 deployment body hover uses portrait too")
	var board=game.board;var cell=board.cell_at(point_on_sprite("guard",.5));var clicked=[];board.cell_clicked.connect(func(pos):clicked.append(pos))
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point_on_sprite("guard",.5);board.input_event(event)
	await settle();check(clicked==[cell],"Q05 click continues to select the floor cell")
func alpha_and_overlap_cases():
	await load_fixture("battle");var board=game.board;board.set_camera(0);await settle()
	var before=await snap();var camera=board.world.camera
	for nodes in board.actors.values():nodes.sprite.visible=false
	var back=board.actors.guard.sprite;var front=board.actors.archer.sprite
	back.visible=true;front.visible=true
	var full=Image.create(32,64,false,Image.FORMAT_RGBA8);full.fill(Color.WHITE)
	var hole=full.duplicate();hole.fill_rect(Rect2i(8,16,16,32),Color.TRANSPARENT)
	back.texture=ImageTexture.create_from_image(full);front.texture=ImageTexture.create_from_image(hole)
	back.pixel_size=.04;front.pixel_size=.04;back.global_position=Vector3(0,2.4,0);front.global_position=back.global_position+camera.global_basis.z*.3
	var center=board.project(front.global_position)
	check(board.sprite_unit_at(center).get("id")=="guard","Q05 transparent hole reveals the rear portrait")
	var edge=board.project(front.global_position+camera.global_basis.x*.52)
	check(board.sprite_unit_at(edge).get("id")=="archer","Q05 opaque overlap selects nearest drawn portrait")
	front.visible=false;check(board.sprite_unit_at(edge).get("id")=="guard","Q05 hidden portrait never intercepts hover");front.visible=true
	var half=full.duplicate();half.fill_rect(Rect2i(0,0,16,64),Color.TRANSPARENT);front.texture=ImageTexture.create_from_image(half)
	var left=board.project(front.global_position-camera.global_basis.x*.4)
	check(board.sprite_unit_at(left).get("id")=="guard","Q05 transparent side does not steal hover")
	front.flip_h=true;check(board.sprite_unit_at(left).get("id")=="archer","Q05 texture flip is respected");front.flip_h=false
	front.visible=false;back.visible=false;board.ghost.texture=ImageTexture.create_from_image(full);board.ghost.pixel_size=.04;board.ghost.global_position=front.global_position;board.ghost.visible=true
	check(board.sprite_unit_at(center).is_empty(),"Q05 provisional ghost is not a real character target")
	check(await snap()==before,"Q05 synthetic visual overlap leaves canonical state untouched")
	for nodes in board.actors.values():nodes.sprite.visible=true
	await load_fixture("battle");board=game.board;board.set_camera(0);await settle();await move_mouse(point_on_sprite("guard",.5))
	var old=board.actors.guard.sprite.texture
	game.portraits.assign("guard",{"png":Marshalls.raw_to_base64(full.save_png_to_buffer())});game.render();await settle();await move_mouse(point_on_sprite("guard",.5))
	check(board.actors.guard.sprite.texture!=old and board.hover_uid=="guard" and not board.portrait_images.has(old),"Q05 changed custom portrait replaces cached alpha image")
	game.portraits.clear_member("guard");game.render();await settle()
func lifecycle_cases():
	await load_fixture("battle");var previous=game.board
	game.hud.selected_cell=24;previous.set_hover("guard");game.board=null
	previous.set_hover("") # Matches mouse/focus exit during main.render clear(content).
	game.board=previous;await settle();check(true,"Q06 deterministic null-board hover exit returned; error log must also be clean")
	if not reproduce_only:
		var stale=Node.new();root.add_child(stale);var inspected=game.hud.inspected_uid
		game.hud.inspect_hover("mage",stale)
		check(game.hud.inspected_uid==inspected,"Q06 foreign board callback cannot overwrite current inspection");stale.queue_free()
	for i in range(3):
		var east=fixtures.town.duplicate(true);east.state.location="east";await game.update({"op":"campaign_load","data":east});await game.act("trial",["guard","sword-wood","rightHand"]);await settle()
		game.hud.selected_cell=24;await move_mouse(point_on_sprite("guard",.5));await game.act("endTrial",[]);await settle()
		check(game.board==null and game.campaign().phase=="town","Q06 hovered trial ends safely "+str(i))
		await load_fixture("battle");await move_mouse(point_on_sprite("guard",.5));await game.new_game();await settle()
		check(game.board==null and game.campaign().phase=="town","Q06 hovered battle can start new game "+str(i))
func run():
	if evidence.is_empty():evidence=ProjectSettings.globalize_path("user://hover-regression")
	DirAccess.make_dir_recursive_absolute(evidence)
	var output=[];var executable=OS.get_environment("NATIVE5525_NODE");if executable.is_empty():executable="node"
	var code=OS.execute(executable,PackedStringArray([ProjectSettings.globalize_path("res://tests/hover_fixtures.cjs")]),output,false,false);fixtures=JSON.parse_string("".join(output))
	if code!=0 or not fixtures is Dictionary:print(output);quit(2);return
	root.size=Vector2i(1920,1080);root.title="5525 isolated hover verification";game=load("res://main.tscn").instantiate();root.add_child(game)
	if visible_run:
		cursor_marker=ColorRect.new();cursor_marker.color=Color("#ff67df");cursor_marker.size=Vector2(6,6);cursor_marker.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(cursor_marker)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await pointer_cases()
	if not reproduce_only:await scale_and_selection_cases();await alpha_and_overlap_cases()
	await lifecycle_cases()
	var f=FileAccess.open(evidence.path_join("hover-regression.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"visible":visible_run,"display_server":DisplayServer.get_name(),"screen_dpi":DisplayServer.screen_get_dpi(),"screen_scale":DisplayServer.screen_get_scale(),"input":"Godot viewport events and explicit app callbacks; no OS-wide injection. Magenta square marks injected hover position.","captures":records},"  "));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	print("HOVER REGRESSION ",checks.size()," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
