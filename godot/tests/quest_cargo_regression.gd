extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func tap(n):game.find_child(n,true,false).pressed.emit();await settle()
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func contains(text):return game.find_children("*","Label",true,false).any(func(n):return n.text.contains(text))
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	await game.act("select",[["guard","porter","porter-2"]]);await settle()
	var before=await saved();var qid=game.campaign().board[0].id
	game.pages.accept(qid);await settle()
	check(game.find_child("QuestCargoOwner_porter",true,false)!=null and game.find_child("QuestCargoOwner_porter-2",true,false)!=null,"both selected porters offered")
	check(game.find_child("QuestCargoOwner_guard",true,false)==null,"non porter not offered")
	await tap("QuestCargoCancel")
	check(await saved()==before,"owner picker cancel leaves complete state unchanged")
	game.pages.accept(qid);await settle();await tap("QuestCargoOwner_porter")
	var cargo=game.campaign().activeQuest.cargoItemId
	check(game.campaign().characters.porter.inventory.get(cargo)==1,"selected porter receives linked cargo")
	var reply=await game.engine.request({"op":"campaign","action":"inventoryQuote","args":["porter",cargo,"transfer","porter-2"]})
	var quote=reply.inventoryQuote
	await game.act("inventoryAction",["porter",cargo,"transfer","porter-2",1,null,quote.token]);await settle()
	check(game.campaign().activeQuest.cargoOwnerId=="porter-2" and not game.campaign().characters.porter.inventory.has(cargo),"existing inventory transfer updates current carrier")
	game.navigate("party");await settle();await tap("GuildMember_porter-2");await tap("GuildRemove")
	check(contains("そのポーター、荷物を持っています"),"current carrier removal warns")
	var before_remove=await saved();await tap("GuildConfirmCancel")
	check(await saved()==before_remove,"warning cancel keeps party and cargo unchanged")
	await tap("GuildRemove");await tap("GuildConfirm")
	check(not game.campaign().selected.has("porter-2") and game.campaign().characters["porter-2"].inventory.get(cargo)==1,"continue reserves carrier without relocating cargo")
	var seed=await saved()
	reply=await game.update({"op":"campaign_load","data":seed});await settle()
	check(reply.ok and game.campaign().activeQuest.cargoOwnerId=="porter-2","reserve carrier save reload")
	game.navigate("party");await settle();await tap("GuildMember_porter-2");await tap("GuildAdd");await tap("GuildConfirm")
	check(game.campaign().cargoAboard,"readding carrier restores aboard cargo")
	await tap("GuildMember_porter-2");await tap("GuildSwap");await tap("GuildMember_archer")
	check(contains("そのポーター、荷物を持っています"),"current carrier swap warns")
	await tap("GuildConfirmCancel");check(game.campaign().selected.has("porter-2"),"swap warning cancel preserves carrier")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("quest-cargo-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
