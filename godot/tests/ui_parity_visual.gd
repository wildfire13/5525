extends SceneTree
var game
var captures=[]
var directory=ProjectSettings.globalize_path("res://qa/visual")
func _initialize():call_deferred("run")
func settle():
	await process_frame;await process_frame
	while game.locked or game.presenting:await process_frame
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
func capture(name: String):
	await settle()
	var filename=directory.path_join("parity-"+name+".png")
	var result=root.get_texture().get_image().save_png(filename)
	var bounds=[]
	for control in game.find_children("*","Control",true,false):
		if control.is_visible_in_tree() and control.get_global_rect().end.x>root.get_visible_rect().size.x+2:bounds.append({"type":control.get_class(),"right":control.get_global_rect().end.x})
	captures.append({"name":name,"path":filename,"error":result,"horizontal_overflow":bounds})
func click(button: Button):
	var at=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at
		root.push_input(event,true);await process_frame
	await settle()
func run():
	DirAccess.make_dir_recursive_absolute(directory)
	root.title="5525 Godot Prototype - UI parity QA";root.size=Vector2i(1280,800)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var original=(await game.engine.request({"op":"campaign_save"})).data
	await capture("01-board")
	game.navigate("map");await settle()
	var map=game.content.find_child("TownMap",true,false)
	await click(map.buttons.north)
	await capture("02-map-selected")
	var map_selected=game.destination=="north"
	game.navigate("party");await capture("03-party")
	game.navigate("inn");await capture("04-inn")
	var east=original.duplicate(true);east.state.location="east"
	await game.update({"op":"campaign_load","data":east});game.navigate("shop")
	await capture("05-shop")
	await game.preview_gear("sword-iron-1");await settle()
	await capture("06-comparison")
	var west=original.duplicate(true);west.state.location="west"
	await game.update({"op":"campaign_load","data":west});game.shop_slot="feet";game.navigate("shop")
	await game.preview_gear("swift-boots");await settle()
	await capture("07-swift")
	await game.update({"op":"campaign_load","data":original});game.navigate("board")
	await game.pages.accept(game.campaign().board[0].id)
	await game.act("depart",[game.campaign().activeQuest.to,"convoy"]);await capture("08-road")
	await game.act("travel",["safe"]);await capture("09-deployment")
	await game.act("begin",[]);game.choose_command("guard");await capture("10-battle-commands")
	game.side.get_parent().scroll_vertical=1000;await capture("11-battle-details")
	await game.act("retreat",[]);game.navigate("board");await capture("12-failure-result")
	var file=FileAccess.open("res://qa/ui-parity-visual-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"captures":captures,"map_mouse_selection":map_selected,"visible_driver":DisplayServer.get_name(),"window_size":[root.size.x,root.size.y],"audio_driver":"Dummy","subjective_listening":false},"  "));file.close()
	game.audio.close_audio();game.engine.close_engine();await create_timer(.2).timeout
	game.queue_free();await process_frame;quit()
