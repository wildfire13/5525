extends SceneTree
const GUARD="character_mirei"
const PORTER="character_yuno"
const OTHER_PORTER="character_teo"
const SCOUT="character_shion"
var game
var checks=[]
func _initialize():call_deferred("run")
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.guild_view.stage in ["pending","animating"]:await process_frame
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func tap(n):game.find_child(n,true,false).pressed.emit();await settle()
func enter_guild():
	game.navigate("party");await settle()
	if game.find_child("FacilityChoice_guild",true,false)!=null:await tap("FacilityChoice_guild")
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func arrive_fixture(to):
	await game.act("depart",[to]);await settle()
	var fixture=await saved()
	fixture.state.phase="arrival";fixture.state.journey.phase="delivery";fixture.state.journey.stage=2;fixture.state.journey.hours=4
	var roster=game.campaign().roster
	fixture.state.journey.party=fixture.state.selected.map(func(id):return roster.filter(func(member):return member.id==id)[0].duplicate(true))
	var reply=await game.update({"op":"campaign_load","data":fixture});await settle()
	check(reply.ok,"controlled arrival fixture accepted")
	game.navigate("hub");await settle()
func contains(text):return game.find_children("*","Label",true,false).any(func(n):return n.text.contains(text))
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	await game.act("select",[[GUARD,PORTER,OTHER_PORTER]]);await settle()
	var before=await saved();var qid=game.campaign().board[0].id
	game.pages.accept(qid);await settle()
	check(game.find_child("QuestCargoOwner_"+PORTER,true,false)!=null and game.find_child("QuestCargoOwner_"+OTHER_PORTER,true,false)!=null,"both selected porters offered")
	check(game.find_child("QuestCargoOwner_"+GUARD,true,false)==null,"non porter not offered")
	await tap("QuestCargoCancel")
	check(await saved()==before,"owner picker cancel leaves complete state unchanged")
	game.pages.accept(qid);await settle();await tap("QuestCargoOwner_"+PORTER);await tap("QuestCargoConfirm")
	var cargo=game.campaign().activeQuest.cargoItemId
	check(game.campaign().characters[PORTER].inventory.get(cargo)==1,"selected porter receives linked cargo")
	var reply=await game.engine.request({"op":"campaign","action":"inventoryQuote","args":[PORTER,cargo,"transfer",OTHER_PORTER]})
	var quote=reply.inventoryQuote
	await game.act("inventoryAction",[PORTER,cargo,"transfer",OTHER_PORTER,1,null,quote.token]);await settle()
	check(game.campaign().activeQuest.cargoOwnerId==OTHER_PORTER and not game.campaign().characters[PORTER].inventory.has(cargo),"existing inventory transfer updates current carrier")
	# Active members are selected from the current-party pane, not reserve cards.
	await enter_guild();game.pages.guild_view.current_id=OTHER_PORTER;game.render();await settle();await tap("GuildRemove")
	check(contains("そのポーター、荷物を持っています"),"current carrier removal warns")
	var before_remove=await saved();await tap("GuildConfirmCancel")
	check(await saved()==before_remove,"warning cancel keeps party and cargo unchanged")
	await tap("GuildRemove");await tap("GuildConfirm")
	check(not game.campaign().selected.has(OTHER_PORTER) and game.campaign().characters[OTHER_PORTER].inventory.get(cargo)==1,"continue reserves carrier without relocating cargo")
	var seed=await saved()
	reply=await game.update({"op":"campaign_load","data":seed});await settle()
	check(reply.ok and game.campaign().activeQuest.cargoOwnerId==OTHER_PORTER,"reserve carrier save reload")
	await enter_guild();await tap("GuildMember_"+OTHER_PORTER);await tap("GuildAdd")
	check(game.campaign().cargoAboard,"readding carrier restores aboard cargo")
	# Select an actual reserve, then invoke the current explicit swap action.
	game.pages.guild_view.current_id=OTHER_PORTER;game.render();await settle();await tap("GuildMember_"+SCOUT);await tap("GuildSwap")
	check(contains("そのポーター、荷物を持っています"),"current carrier swap warns")
	await tap("GuildConfirmCancel");check(game.campaign().selected.has(OTHER_PORTER),"swap warning cancel preserves carrier")
	reply=await game.update({"op":"campaign_load","data":seed});await settle()
	var cash=game.campaign().gold
	await arrive_fixture("east")
	check(game.campaign().phase=="town" and game.campaign().activeQuest is Dictionary and game.campaign().gold==cash,"arrival with reserve cargo enters town without reward")
	check(game.find_child("HubDeliverCargo",true,false).disabled and contains("依頼は未完了"),"missing cargo completion disabled with reason")
	game.navigate("map");await settle()
	check(not game.find_child("TownMap",true,false).buttons.astaris.disabled,"ordinary road back to city available")
	await arrive_fixture("astaris");await enter_guild()
	await tap("GuildMember_"+OTHER_PORTER);await tap("GuildAdd")
	cash=game.campaign().gold
	await arrive_fixture("east")
	check(game.campaign().gold==cash and game.campaign().characters[OTHER_PORTER].inventory.get(cargo)==1,"arrival with cargo does not deliver automatically")
	check(not game.find_child("HubDeliverCargo",true,false).disabled,"delivery button enabled with actual cargo")
	await tap("HubDeliverCargo")
	check(game.campaign().activeQuest==null and not game.campaign().characters[OTHER_PORTER].inventory.has(cargo) and game.campaign().history.any(func(line):return line.contains("「荷物」を渡しました")),"completion button hands over cargo exactly once")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("quest-cargo-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
