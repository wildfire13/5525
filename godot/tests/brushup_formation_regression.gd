extends SceneTree
## Shared current roster, explicit swaps, and session-only reserve filtering.
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
func current_ids():
	return node("PartyRoster").find_children("RosterMember_*","Button",true,false).map(func(n):return str(n.member_id))
func labels(control):
	return "\n".join(control.find_children("*","Label",true,false).map(func(n):return n.text))
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
	await game.update({"op":"campaign_start"})
	game.audio.fast_mode=true;game.checks_fast=true;await enter_facility("party");await settle()
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"A1 all three audio channels remain muted")
	var seed=await saved();var guild=game.pages.guild_view
	var reserve_ids=game.campaign().roster.filter(func(member):return not game.campaign().selected.has(member.id)).map(func(member):return str(member.id))
	var selected=seed.state.selected
	var reserves=game.campaign().roster.filter(func(member):return reserve_ids.has(member.id))
	var incoming=reserves[0]
	var other=reserves.filter(func(member):return member.job!=incoming.job)[0]
	var filtered_ids=reserves.filter(func(member):return member.job==other.job).map(func(member):return member.id)
	var expected=selected.duplicate()
	expected[0]=incoming.id
	check(current_ids()==game.campaign().selected and ids("GuildReserveScroll")==reserve_ids,"A1 default filter retains complete existing party and reserve order")
	check(labels(node("PartyRoster")).contains(str(selected.size())+" / "+str(guild.party_limit())),"A1 roster shows the current party size and capacity")
	await tap("GuildMember_"+incoming.id);await filter_job(other.job)
	check(guild.chosen_id.is_empty() and guild.notice.contains(incoming.name) and guild.notice.contains("選択を解除"),"A1 hidden reserve selection clears with named explanation")
	check(ids("GuildReserveScroll")==filtered_ids and current_ids()==selected,"A1 job filter shows matching reserves and keeps the party visible")
	check(node("GuildReserveHeading").text.contains(str(reserve_ids.size())+"人") and (await saved())==seed,"A1 filtered count and preview have no campaign or save side effects")
	guild.choose(incoming.id);await settle()
	check(guild.chosen_id.is_empty() and (await saved())==seed,"A1 stale hidden reserve callback cannot select or swap another target")
	await tap("GuildMember_"+other.id);await filter_job("")
	check(guild.chosen_id==other.id and node("GuildMember_"+other.id)!=null,"A1 visible reserve selection retained when filter broadens")
	guild.cancel_selection();await settle();await tap("RosterMember_"+selected[0]);await filter_job("job_porter")
	check(guild.current_id==selected[0] and node("RosterMember_"+selected[0])!=null,"A1 changing reserve criteria retains current member context")
	var filter_area=node("GuildReserveFilter").get_global_rect().get_center();guild.outside_press(filter_area);await settle()
	check(guild.current_id==selected[0],"A1 filter click is not mistaken for outside cancellation")
	await tap("GuildTab_1")
	check(guild.detail_tab==1 and guild.current_id==selected[0] and guild.reserve_job=="job_porter" and (await saved())==seed,"A1 inline equipment comparison keeps selected member, filter and save")
	guild.cancel_selection();await settle();await filter_job("")
	var scroll=node("GuildReserveScroll");scroll.scroll_vertical=150;await frames();var offset=scroll.scroll_vertical
	await filter_job("job_mage");await filter_job("")
	check(node("GuildReserveScroll").scroll_vertical==offset,"A1 all-reserves scroll position survives narrower filter and return")
	await tap("RosterMember_"+selected[0]);await tap("GuildMember_"+incoming.id);check((await saved())==seed,"A1 selecting swap targets is pure until explicit confirmation");var swap_button=node("GuildSwap");swap_button.pressed.emit();swap_button.pressed.emit();await settle()
	check(game.campaign().selected==expected and guild.chosen_id.is_empty(),"A1 selected current and reserve perform exactly one explicit swap under double submission")
	var swapped=await saved()
	check(swapped.state.characters==seed.state.characters and swapped.state.gold==seed.state.gold,"A1 explicit swap preserves owners/equipment/stock/gold")
	await tap("RosterMember_"+selected[1]);await tap("GuildRemove")
	check(labels(node("PartyRoster")).contains(str(selected.size()-1)+" / "+str(guild.party_limit())),"A1 capacity updates from confirmed composition")
	await game.update({"op":"campaign_load","data":seed});await enter_facility("party");await settle()
	check(guild.reserve_job.is_empty() and guild.chosen_id.is_empty(),"A1 load clears session-only filter and selection")
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;await settle();await filter_job("")
		for member in game.data.campaign.roster:
			if member.id==incoming.id:member.name="長い名前の人物を見分けるための検証名"
		game.render();await settle()
		await tap("GuildMember_"+incoming.id)
		check(labels(node("GuildComparisonDetails")).contains("長い名前の人物を見分けるための検証名"),"A1 selecting clipped reserve card exposes complete long name in inline details "+str(dims.x))
		var filter=node("GuildReserveJobFilter");var reserve=node("GuildReserveScroll");var current=node("PartyRoster")
		check(filter.get_global_rect().end.x<=dims.x and reserve.size.y>100 and current.get_global_rect().end.x<reserve.global_position.x and current.size.y>100,"A1 filter and ordered roster and reserve regions fit "+str(dims.x)+" filter="+str(filter.get_global_rect())+" reserve="+str(reserve.get_global_rect())+" current="+str(current.get_global_rect()))
		check(node("GuildActions").get_global_rect().end.y<=dims.y and node("GuildReturn").get_global_rect().end.y<=dims.y,"A1 selection/actions/return stay within supported window "+str(dims.x))
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
