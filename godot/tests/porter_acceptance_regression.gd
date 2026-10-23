extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func tap(n):
	var control=game.find_child(n,true,false)
	if control==null:push_error("Missing test control: "+n);quit(2);return
	control.pressed.emit();await settle()
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	game.navigate("party");await settle()
	await tap("GuildMember_porter")
	check(not game.find_child("GuildRemove",true,false).disabled,"last porter removal available")
	await tap("GuildRemove")
	check(not game.campaign().hasPorter and game.campaign().selected.size()==4,"UI removes last porter without a fixed-member constraint")
	check(game.find_child("GuildConfirm",true,false)==null,"unladen porter removal needs no cargo warning; carrier warning is tested separately")
	var saved=(await game.engine.request({"op":"campaign_save"})).data
	var path=OS.get_environment("INVENTORY_QA_ROOT").path_join("zero-porter-save.json")
	var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(saved));f.close()
	var reply=await game.update({"op":"campaign_load","data":JSON.parse_string(FileAccess.get_file_as_string(path))});await settle()
	check(reply.get("ok",false) and not game.campaign().hasPorter,"zero porter isolated file save reload")
	var qid=game.campaign().board[0].id
	reply=await game.engine.request({"op":"campaign","action":"accept","args":[qid]})
	check(not reply.get("ok",true) and str(reply.get("error","")).contains("最低1人"),"zero porter acceptance explains required count")
	await game.act("select",[["guard","porter-2"]]);await settle()
	reply=await game.update({"op":"campaign","action":"accept","args":[qid,"porter-2"]});await settle()
	check(reply.get("ok",false) and game.campaign().activeQuest is Dictionary,"one porter acceptance succeeds")
	check(game.campaign().phase=="town","accept does not depart")
	await game.act("select",[["guard"]]);await settle()
	check(not game.campaign().hasPorter,"accepted quest can retain zero porter composition")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("porter-acceptance-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
