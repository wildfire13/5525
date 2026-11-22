extends "res://tests/ui_feedback_20261016.gd"

const ROLES=["Button","ActionButton","SelectedButton","DestinationButton"]
var samples=[]
var references={}

func pointer(point: Vector2, held:=false):
	var event=InputEventMouseMotion.new()
	event.position=point;event.global_position=point
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event,true)
	await frames(3)

func button_event(point: Vector2,down: bool):
	var event=InputEventMouseButton.new()
	event.position=point;event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event,true)
	await frames(3)

func capture_button(scene: String,b: Button):
	var role=str(b.theme_type_variation)
	if role.is_empty():role="Button"
	var originally_disabled=b.disabled
	var rect=b.get_global_rect()
	if b.get_window()!=root:rect.position+=Vector2(b.get_window().position)
	var point=rect.position+Vector2(8,8)
	for state_name in ["normal","hover","pressed","disabled"]:
		b.disabled=state_name=="disabled"
		await pointer(Vector2(1919,1079))
		if state_name in ["hover","pressed"]:await pointer(point)
		if state_name=="pressed":await button_event(point,true)
		await RenderingServer.frame_post_draw
		var mode=b.get_draw_mode()
		var expected={"normal":BaseButton.DRAW_NORMAL,"hover":BaseButton.DRAW_HOVER,"pressed":BaseButton.DRAW_PRESSED,"disabled":BaseButton.DRAW_DISABLED}[state_name]
		check(mode==expected,scene+" "+role+" "+state_name+" actual draw mode")
		var style_name={BaseButton.DRAW_NORMAL:"normal",BaseButton.DRAW_HOVER:"hover",BaseButton.DRAW_PRESSED:"pressed",BaseButton.DRAW_DISABLED:"disabled",BaseButton.DRAW_HOVER_PRESSED:"hover_pressed"}.get(mode,"normal")
		var box=b.get_theme_stylebox(style_name)
		var ink=b.get_theme_color({"normal":"font_color","hover":"font_hover_color","pressed":"font_pressed_color","disabled":"font_disabled_color","hover_pressed":"font_hover_pressed_color"}[style_name])
		for caption in b.find_children("*","Label",true,false):
			if not caption.has_theme_color_override("font_color"):
				check(caption.get_theme_color("font_color")==ink,scene+" "+state_name+" caption "+str(caption.name))
		var fill=box.bg_color if box is StyleBoxFlat else Color.TRANSPARENT
		var key=role+"/"+state_name
		var colors=[fill.to_html(),ink.to_html()]
		if references.has(key):check(references[key]==colors,scene+" "+key+" matches other scenes")
		else:references[key]=colors
		var filename=scene+"-"+role+"-"+state_name+".png"
		var image=root.get_texture().get_image()
		check(image.get_size()==Vector2i(1920,1080),"FHD "+filename)
		image.save_png(evidence.path_join(filename))
		var pixel=image.get_pixelv(Vector2i(point))
		check(pixel.is_equal_approx(fill),scene+" "+key+" rendered pixel matches fill")
		samples.append({"scene":scene,"node":str(b.name),"role":role,"state":state_name,"draw_mode":mode,"background":colors[0],"pixel":pixel.to_html(),"text":colors[1],"image":filename,"originally_disabled":originally_disabled,"forced_enabled":originally_disabled and state_name!="disabled","forced_disabled":not originally_disabled and state_name=="disabled","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		if state_name=="pressed":
			await pointer(Vector2(1919,1079),true)
			await button_event(Vector2(1919,1079),false)
	b.disabled=originally_disabled

func scene_buttons(scene: String):
	var targets={"town":["RosterMember_character_mirei"],"map":["Town_east","DepartButton"],"inn":["InnReturn","InnStay"],"road":["Header_character","RosterMember_character_mirei"],"window":["ActionLogSave"],"battle":["BattleOrderDetails"]}
	for node_name in targets.get(scene,[]):
		var b=root.find_child(node_name,true,false) as Button
		check(b!=null and b.is_visible_in_tree(),scene+" explicit "+node_name)
		if b!=null and b.is_visible_in_tree():await capture_button(scene,b)

func run():
	create_timer(180).timeout.connect(func():quit(2))
	var profile=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(profile+"/"):quit(2);return
	evidence=OS.get_environment("BUTTON_PALETTE_EVIDENCE")
	if evidence.is_empty():quit(2);return
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	await settle()
	await scene_buttons("town")
	var quest=game.campaign().get("board",[]).filter(func(q):return q.get("to")=="east")[0]
	await game.act("accept",[quest.id,"character_yuno"])
	game.destination="west"
	game.navigate("map");await settle();await scene_buttons("map")
	await enter_facility("inn");await scene_buttons("inn")
	game.show_action_log()
	await settle();await scene_buttons("window")
	game.dialog.close();game.navigate("hub");await settle()
	await game.act("depart",["east"]);await settle();await scene_buttons("road")
	await game.act("travel",["short"])
	await game.act("begin");await settle()
	await scene_buttons("battle")
	for role in ROLES:
		var scenes={}
		for row in samples:
			if row.role==role:scenes[row.scene]=true
		check(scenes.size()>=(1 if role=="DestinationButton" else 2),role+" scene coverage")
	var file=FileAccess.open(evidence.path_join("palette.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":samples,"checks":checks},"\t"));file.close()
	game.audio.close_audio();game.engine.close_engine()
	quit(1 if checks.any(func(c):return not c.passed) else 0)
