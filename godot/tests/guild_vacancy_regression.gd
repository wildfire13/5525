extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func tap(name_: String):game.find_child(name_,true,false).pressed.emit();await settle()
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	var seed=(await game.engine.request({"op":"campaign_save"})).data;seed.state.selected=["porter"]
	var reply=await game.update({"op":"campaign_load","data":seed});game.navigate("party");await settle()
	check(reply.get("ok",false) and game.campaign().selected==["porter"],"single fixed porter remains valid minimum composition")
	await tap("GuildMember_guard")
	check(game.find_child("GuildSwap",true,false).disabled and not game.find_child("GuildAdd",true,false).disabled,"no swappable member disables exchange but permits append")
	var guild=game.pages.guild_view;guild.begin_swap();await settle()
	check(guild.stage=="idle" and not game.modal_open(),"unfulfillable counterpart picker cannot start")
	await tap("GuildAdd");await tap("GuildConfirm")
	check(game.campaign().selected==["porter","guard"] and game.campaign().characters==seed.state.characters,"append to minimum party keeps order and all owner fields")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("vacancy-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
