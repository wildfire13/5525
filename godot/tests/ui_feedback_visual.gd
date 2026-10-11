extends SceneTree
# Isolated, visible viewport captures. This script never injects OS-wide input.
var game
var captures=[]
var directory=ProjectSettings.globalize_path("res://qa/feedback-visual")
func _initialize():call_deferred("run")
func settle():
	for i in range(10):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.preview_pending or game.pages.shop_view.quote_worker:await process_frame
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
func node(id: String):return game.find_child(id,true,false)
func capture(id: String):
	await settle()
	var img=root.get_texture().get_image();var path=directory.path_join(id+".png");img.save_png(path)
	var record={"id":id,"path":path,"size":[img.get_width(),img.get_height()],"window_mode":root.mode,"page":game.page,"phase":game.campaign().get("phase"),"camera":game.board.camera_mode if is_instance_valid(game.board) else null,"hover":game.board.hover_caption if is_instance_valid(game.board) else "","fixed_controls":[]}
	for name_ in ["PartyFaceBar","BottomCommands","BattlePersonArea","ShopActions"]:
		var n=node(name_)
		if n!=null:
			var r=n.get_global_rect();record.fixed_controls.append({"name":name_,"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"inside":root.get_visible_rect().encloses(r)})
	captures.append(record);print("CAPTURE "+id+" "+str(img.get_size()))
func click(control):
	var at=control.get_global_rect().get_center()
	if control.get_window()!=root:at+=Vector2(control.get_window().position)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at;root.push_input(event,true);await process_frame
	await settle()
func hover(pos: int):
	var at=game.board.global_position+game.board.project_cell(pos)
	var event=InputEventMouseMotion.new();event.position=at;event.global_position=at;root.push_input(event,true);await settle()
func key(code):
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=code;event.pressed=pressed;root.push_input(event,true);await process_frame
	await settle()
func run():
	if DisplayServer.get_name()=="headless":push_error("This visual script requires a visible display");quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.title="5525 October 11 feedback - isolated visual QA";root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await capture("01-town")
	game.navigate("map");await capture("02-map")
	game.navigate("party");await capture("03-party")
	var saved=(await game.engine.request({"op":"campaign_save"})).data
	saved.state.characters.guard.xp=300;saved.state.characters.guard.level=4;saved.state.characters.guard.statPoints=6;saved.state.characters.guard.skillPoints=3
	await game.update({"op":"campaign_load","data":saved});game.navigate("board");await settle();await click(node("PartyFace_guard"))
	game.pages.party_view.detail_tab=1;game.pages.party_view.refresh_modal();await settle()
	var member=game.roster().filter(func(u):return u.id=="guard")[0]
	game.pages.party_view.change_draft(member,"str",1);game.pages.party_view.change_draft(member,"int",1);await capture("04-growth")
	await click(node("AllocationConfirm"));await capture("05-growth-confirm")
	node("AllocationConfirmation").canceled.emit();await settle();game.pages.party_view.clear_draft();game.dialog.close();await settle()
	saved.state.location="north";await game.update({"op":"campaign_load","data":saved});game.navigate("shop");await settle()
	await game.preview_gear(game.pages.offered().filter(func(g):return g.price>0)[0].id);await capture("06-accessory-shop")
	game.navigate("map");await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await capture("07-deployment-basic")
	await game.act("chooseFormation",["flank"]);await capture("08-deployment-flank")
	await game.act("begin",[]);await settle()
	for camera in range(3):game.board.set_camera(camera);await capture("09-battle-camera-"+str(camera))
	game.board.set_camera(0);await game.choose_command("skill");await settle()
	if node("SkillContentToggle")!=null:await click(node("SkillContentToggle"))
	await capture("10-skill-content")
	await game.choose_command("move");await settle()
	var positions=game.data.get("choices",{}).get("move",[])
	if not positions.is_empty():await game.on_cell(int(positions[0]));await settle()
	await capture("11-move-ghost")
	await key(KEY_F11);await capture("12-fullscreen");await key(KEY_F11)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/synthetic-one-hit-victory.json"))
	await game.update({"op":"campaign_load","data":fixture});await game.choose_command("attack");await hover(35);await capture("13-legal-attack-hover")
	game.hide();var panel=PanelContainer.new();root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin=MarginContainer.new();panel.add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	var grid=GridContainer.new();grid.columns=8;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",20);margin.add_child(grid)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui_icons/manifest.json"))
	for item in manifest.icons:
		var cell=VBoxContainer.new();cell.custom_minimum_size=Vector2(215,112);grid.add_child(cell);game.icons.add(cell,str(item.id),64)
		var label=Label.new();label.text=str(item.id);label.add_theme_font_size_override("font_size",18);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cell.add_child(label)
	await capture("14-canonical-52-catalog")
	var report={"visible":true,"input":"Godot viewport mouse/key events and explicit app callbacks; no OS-wide injection","display_server":DisplayServer.get_name(),"screen_size":[DisplayServer.screen_get_size().x,DisplayServer.screen_get_size().y],"screen_dpi":DisplayServer.screen_get_dpi(),"screen_scale":DisplayServer.screen_get_scale(),"captures":captures,"subjective_audio":false}
	var f=FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();panel.queue_free()
	for i in range(8):await process_frame
	quit()
