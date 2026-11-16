extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.guild_view.stage=="animating":await process_frame
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func tap(name_: String):
	var button=game.find_child(name_,true,false)
	check(button is Button and button.is_visible_in_tree() and not button.disabled,"action available "+name_)
	if button is Button and button.is_visible_in_tree() and not button.disabled:button.pressed.emit();await settle()
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game()
	game.audio.fast_mode=true;game.checks_fast=true
	var seed=(await game.engine.request({"op":"campaign_save"})).data;seed.state.selected=["recruit-porter-human-female"]
	var reply=await game.update({"op":"campaign_load","data":seed});await enter_facility("party");await settle()
	check(reply.get("ok",false) and game.campaign().selected==["recruit-porter-human-female"],"single porter remains valid minimum composition")
	await tap("GuildMember_recruit-guard-human-female")
	var guild=game.pages.guild_view
	check(not game.find_child("GuildAdd",true,false).disabled and not guild.candidate("swap","recruit-porter-human-female","recruit-guard-human-female").is_empty(),"single porter can exchange with reserve or append")
	check(guild.current_id=="recruit-porter-human-female" and game.campaign().characters==seed.state.characters,"minimum current member selected without changing owner fields")
	await tap("GuildSwap")
	check(game.campaign().selected==["recruit-guard-human-female"] and not game.modal_open() and game.campaign().characters==seed.state.characters,"explicit swap commits immediately without obsolete picker and preserves owner fields")
	check(game.find_child("GuildRemove",true,false).disabled,"last active member cannot be removed")
	guild.cancel_selection();await settle()
	await tap("GuildMember_recruit-porter-human-female");await tap("GuildAdd")
	check(game.campaign().selected==["recruit-guard-human-female","recruit-porter-human-female"] and game.campaign().characters==seed.state.characters,"append to minimum party keeps order and all owner fields")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("vacancy-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)

func enter_facility(page: String):
	game.navigate(page);await settle()
	var service={"shop":"buy","party":"guild","inn":"inn"}.get(page,"")
	var choice=game.find_child("FacilityChoice_"+service,true,false)
	if choice!=null and choice.is_visible_in_tree():
		choice.pressed.emit();await settle()
