extends SceneTree
## Phase A: existing direct swaps plus session-only reserve filtering.
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func node(name_: String):return game.find_child(name_,true,false)
func frames(n:=12):
	for i in range(n):await process_frame
func settle():
	await frames()
	while game.locked or game.engine.busy or game.presenting or game.pages.guild_view.stage=="animating":await process_frame
	await frames(4)
func tap(name_: String):
	var control=node(name_)
	if control==null:push_error("Missing control "+name_);quit(2);return
	control.pressed.emit();await settle()
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func ids(name_: String):
	return node(name_).get_child(0).get_children().filter(func(n):return n.has_meta("member_id")).map(func(n):return n.get_meta("member_id"))
func filter_job(job: String):
	var control=node("GuildReserveJobFilter")
	for index in range(control.item_count):
		if str(control.get_item_metadata(index))==job:
			control.select(index);control.item_selected.emit(index);await settle();return
	push_error("Missing existing job "+job);quit(2)
func run():
	create_timer(120).timeout.connect(func():push_error("A1 watchdog timeout");quit(2))
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.audio.fast_mode=true;game.checks_fast=true;await enter_facility("party");await settle()
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"A1 all three audio channels remain muted")
	var seed=await saved();var guild=game.pages.guild_view
	var reserve_ids=game.campaign().roster.filter(func(member):return not game.campaign().selected.has(member.id)).map(func(member):return str(member.id))
	check(game.campaign().roster.size()==35 and reserve_ids.size()==30,"A1 migrated fixture contains eleven historical people plus twenty-four new candidates")
	check(ids("GuildCurrentScroll")==game.campaign().selected and ids("GuildReserveScroll")==reserve_ids,"A1 default filter retains complete existing party and reserve order")
	check(node("GuildCapacity").text.contains("残り7枠") and node("GuildReserveJobFilter").item_count==7,"A1 capacity and only existing six job categories shown")
	await tap("GuildMember_warrior");await filter_job("archer")
	check(guild.chosen_id.is_empty() and guild.notice.contains("槌戦士") and guild.notice.contains("選択を解除"),"A1 hidden reserve selection clears with named explanation")
	check(ids("GuildReserveScroll")==["archer-2"] and ids("GuildCurrentScroll")==seed.state.selected,"A1 reserve-only filter keeps all current swap targets visible")
	check(node("GuildReserveHeading").text.contains("1/30人表示") and (await saved())==seed,"A1 filtered count and preview have no campaign or save side effects")
	guild.choose("warrior");await settle()
	check(guild.chosen_id.is_empty() and (await saved())==seed,"A1 stale hidden reserve callback cannot select or swap another target")
	await tap("GuildMember_archer-2");await filter_job("")
	check(guild.chosen_id=="archer-2" and node("GuildStatus_archer-2").text.contains("選択中"),"A1 visible reserve selection retained when filter broadens")
	guild.cancel_selection();await settle();await tap("GuildMember_guard");await filter_job("porter")
	check(guild.chosen_id=="guard" and node("GuildStatus_guard").text.contains("選択中"),"A1 changing reserve criteria retains current member context")
	var filter_area=node("GuildReserveFilter").get_global_rect().get_center();guild.outside_press(filter_area);await settle()
	check(guild.chosen_id=="guard","A1 filter click is not mistaken for outside cancellation")
	await tap("GuildDetails");check(game.pages.party_view.detail_uid=="guard","A1 existing detail opens for named selected current member")
	game.dialog.close();await settle()
	check(guild.chosen_id=="guard" and guild.reserve_job=="porter" and (await saved())==seed,"A1 closing detail keeps selection/filter and exact saved state")
	guild.cancel_selection();await settle();await filter_job("")
	var scroll=node("GuildReserveScroll");scroll.scroll_vertical=150;await frames();var offset=scroll.scroll_vertical
	await filter_job("mage");await filter_job("")
	check(node("GuildReserveScroll").scroll_vertical==offset,"A1 all-reserves scroll position survives narrower filter and return")
	await tap("GuildMember_guard");await tap("GuildMember_guard-2")
	check(game.campaign().selected==["guard-2","archer","mage","scout","porter"] and guild.chosen_id.is_empty(),"A1 unchanged two member clicks perform one direct swap")
	var swapped=await saved()
	check(swapped.state.characters==seed.state.characters and swapped.state.gold==seed.state.gold,"A1 direct swap preserves owners/equipment/stock/gold")
	await tap("GuildMember_archer");await tap("GuildRemove")
	check(node("GuildCapacity").text.contains("残り8枠"),"A1 capacity updates from confirmed composition")
	await game.update({"op":"campaign_load","data":seed});await enter_facility("party");await settle()
	check(guild.reserve_job.is_empty() and guild.chosen_id.is_empty(),"A1 load clears session-only filter and selection")
	var minimal=seed.duplicate(true);minimal.state.selected=["warrior"]
	await game.update({"op":"campaign_load","data":minimal});await enter_facility("party");await settle();await filter_job("warrior")
	check(ids("GuildReserveScroll").is_empty() and node("GuildEmptyReserves").text.contains("すべて") and ids("GuildCurrentScroll")==["warrior"],"A1 empty filtered reserves offer recovery and keep current members visible")
	check(node("GuildCapacity").text.contains("残り11枠") and (await saved())==minimal,"A1 empty view neither adds constraints nor mutates state")
	await game.update({"op":"campaign_load","data":seed});await enter_facility("party");await settle()
	for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims;await settle();await filter_job("")
		for member in game.data.campaign.roster:
			if member.id=="guard-2":member.name="長い名前の人物を見分けるための検証名・バルト"
		game.render();await settle()
		check(node("GuildMember_guard-2").tooltip_text.contains("長い名前の人物を見分けるための検証名・バルト"),"A1 long name remains available in tooltip "+str(dims.x))
		var filter=node("GuildReserveJobFilter");var reserve=node("GuildReserveScroll");var current=node("GuildCurrentScroll")
		check(filter.get_global_rect().end.x<=dims.x and reserve.size.y>100 and is_equal_approx(reserve.global_position.y,current.global_position.y),"A1 filter and aligned scroll regions fit "+str(dims.x)+" filter="+str(filter.get_global_rect())+" reserve="+str(reserve.get_global_rect())+" current="+str(current.get_global_rect()))
		check(node("GuildOperations").get_global_rect().end.y<=dims.y and node("GuildReturn").get_global_rect().end.y<=dims.y,"A1 selection/actions/return stay within supported window "+str(dims.x))
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"A1 audio stayed OFF throughout")
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("brushup-formation-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	quit(0 if checks.all(func(row):return row.passed) else 1)

func enter_facility(page: String):
	game.navigate(page);await settle()
	var service={"shop":"buy","party":"guild","inn":"inn"}.get(page,"")
	var choice=game.find_child("FacilityChoice_"+service,true,false)
	if choice!=null and choice.is_visible_in_tree():
		choice.pressed.emit();await settle()
