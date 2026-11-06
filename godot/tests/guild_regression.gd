extends SceneTree
class RecordedEngine extends Node:
	var actual
	var select_count=0
	var last_ids=[]
	var hold_next=false
	var reject_next=false
	var held=false
	var release=false
	var busy:
		get:return actual.busy or held
	var disconnected:
		get:return actual.disconnected
	var connection_generation:
		get:return actual.connection_generation
	var handles:
		get:return actual.handles
	var last_error:
		get:return actual.last_error
	func request(payload: Dictionary) -> Dictionary:
		if payload.get("action")=="select":
			select_count+=1;last_ids=payload.args[0].duplicate()
			if reject_next:
				reject_next=false;var response=await actual.request({"op":"view"});response.ok=false;response.error="検査用の編成拒否";return response
		var reply=await actual.request(payload)
		if payload.get("action")=="select" and hold_next:
			hold_next=false;held=true
			while not release:await get_tree().process_frame
			held=false
		return reply
var game
var actual
var recorder
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
	if control==null:push_error("Missing control "+name_+" / detail="+game.pages.party_view.detail_uid+" / chosen="+game.pages.guild_view.chosen_id);quit(2);return
	control.pressed.emit();await settle()
func saved():return (await actual.request({"op":"campaign_save"})).data
func ids(name_: String):
	return node(name_).get_child(0).get_children().filter(func(n):return n.has_meta("member_id")).map(func(n):return n.get_meta("member_id"))
func current_ids() -> Array:
	return node("PartyRoster").find_children("RosterMember_*","Button",true,false).map(func(n):return str(n.member_id))
func current_scroll():return node("PartyRoster").find_children("*","ScrollContainer",true,false)[0]
func labels(control) -> String:
	return "\n".join(control.find_children("*","Label",true,false).map(func(n):return n.text))
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.audio.fast_mode=true;game.checks_fast=true;actual=game.engine
	var seed=await saved();seed.state.characters.guard.inventory={"potion":2};seed.state.characters["guard-2"].inventory={"ether":4};seed.state.characters.warrior.inventory={"potion":1,"sword-wood":1};seed.state.characters.warrior.statPoints=2
	seed.state.characters.warrior.xp=100;seed.state.characters.warrior.level=2;seed.state.characters.warrior.skillPoints=1
	var loaded=await game.update({"op":"campaign_load","data":seed})
	check(loaded.get("ok",false),"fixture uses valid owned stock and earned growth points")
	var entry_before=await saved();game.navigate("hub");await settle()
	check(node("HubFacility_guild")!=null and node("HubFacility_guild").text=="ギルド","G01 Astaris hub has explicit guild entry")
	await tap("HubFacility_guild")
	check(node("FacilityChoice_guild")!=null and (await saved())==entry_before,"G01 guild opens pure service entry")
	await tap("FacilityChoice_guild")
	var guild=game.pages.guild_view;recorder=RecordedEngine.new();recorder.actual=actual;game.add_child(recorder);game.engine=recorder
	var before=await saved()
	check(game.page=="party" and game.header.text=="アスタリス" and node("GuildComparison")!=null and node("PartyRoster")!=null,"G01 formation service opens named formation page")
	var reserve_ids=game.campaign().roster.filter(func(member):return not game.campaign().selected.has(member.id)).map(func(member):return str(member.id))
	check(game.campaign().roster.size()==35 and reserve_ids.size()==30,"G02 migrated fixture retains eleven historical and twenty-four new people")
	check(current_ids()==game.campaign().selected and ids("GuildReserveScroll")==reserve_ids,"G02 lists retain selected and complete reserve order")
	check(labels(node("GuildComparison")).contains("Lv.1") and labels(node("RosterMember_guard")).contains("HP") and not labels(node("RosterMember_porter")).contains("編成固定"),"G02 rows show resources and level without job-based lock")
	await tap("RosterMember_guard")
	check((await saved())==before and guild.current_id=="guard","G05 first row selection is pure")
	var intent=guild.candidate("swap","guard","guard-2");var context=guild.stamp();var ticket=guild.generation+1
	await tap("GuildMember_guard-2")
	check((await saved())==before and recorder.select_count==0 and not node("GuildSwap").disabled,"G05 counterpart selection is pure until explicit swap")
	recorder.hold_next=true;recorder.release=false;node("GuildSwap").pressed.emit()
	var deadline=Time.get_ticks_msec()+4000
	while not recorder.held and Time.get_ticks_msec()<deadline:await process_frame
	check(recorder.held and game.locked and guild.stage=="pending","G10 explicit swap starts exactly one pending select")
	guild.commit("swap","guard","guard-2",intent,context,ticket);guild.cancel_selection();game.navigate("hub")
	var denied=await game.update({"op":"campaign_load","data":seed})
	check(recorder.select_count==1 and game.page=="party" and not denied.get("ok",true),"G10 duplicate/cancel/navigation/load blocked while select pending")
	recorder.release=true;await settle()
	var after=await saved()
	check(game.campaign().selected==["guard-2","archer","mage","scout","porter"] and recorder.select_count==1,"G03 party swap changes one slot through one select")
	check(after.state.characters==before.state.characters and after.state.gold==before.state.gold,"G06 swap preserves owner/equipment/HP/MP/growth/gold")
	check(guild.notice.contains("入替完了") and current_ids()==game.campaign().selected,"G03 response updates lists and notice")
	await tap("RosterMember_porter")
	check(not node("GuildRemove").disabled and not guild.candidate("remove","porter","").is_empty() and not guild.candidate("swap","porter","porter-2").is_empty(),"G04 porter removal and replacement allowed")
	guild.cancel_selection();await settle();await tap("GuildMember_guard")
	check(not node("GuildAdd").disabled and labels(node("PartyRoster")).contains("5 / 12") and guild.party_limit()-current_ids().size()==7,"G04 initial five companions can add within canonical twelve capacity")
	var event=InputEventKey.new();event.pressed=true;event.keycode=KEY_ESCAPE;game._unhandled_key_input(event);await settle()
	check(guild.stage=="idle" and guild.chosen_id.is_empty() and game.page=="party" and (await saved())==after,"G09 Escape cancels local selection without mutation")
	await tap("RosterMember_archer");await tap("GuildRemove")
	check(game.campaign().selected==["guard-2","mage","scout","porter"],"G04 noncargo member returns to reserve without reordering others")
	await tap("GuildMember_archer");await tap("GuildAdd")
	check(game.campaign().selected==["guard-2","mage","scout","porter","archer"] and (await saved()).state.characters==before.state.characters,"G04 addition appends and preserves owner data")
	var roundtrip=await saved();await game.update({"op":"campaign_load","data":roundtrip});await enter_facility("party");await settle()
	check(game.campaign().selected==roundtrip.state.selected,"G10 save/load retains composition and order")
	await tap("GuildMember_warrior");game.pages.party_view.open_detail("warrior");await settle();await all_inventory();await tap("OwnedEquipment_potion")
	check(node("InventoryUse").disabled and node("InventoryTransfer").disabled and node("InventoryDiscard").disabled,"G07 reserve inventory restrictions remain")
	await tap("StatusTab_1")
	check(game.find_children("*","Button",true,false).filter(func(b):return str(b.get_meta("ui_key","")).begins_with("allocate_")).all(func(b):return b.disabled),"G07 reserve growth editing disabled")
	check(game.find_children("*","Button",true,false).all(func(b):return b.get_meta("ui_key","")!="party_membership"),"G01 no old growth-tab membership controls")
	game.dialog.close();await settle();check((await saved())==roundtrip,"G05 detail inspection changes no state")
	guild.cancel_selection();await settle()
	await tap("RosterMember_guard-2");await tap("GuildMember_guard");recorder.reject_next=true;await tap("GuildSwap")
	check(guild.stage=="idle" and guild.notice.contains("拒否") and (await saved())==roundtrip,"G10 rejected select preserves state and explains reason")
	guild.cancel_selection();await settle()
	var footer_y=node("GuildActions").global_position.y;var original_ids=game.data.campaign.selected.duplicate()
	game.data.campaign.selected.append("guard");game.render();await settle()
	check(current_ids().size()==6 and node("GuildActions").global_position.y==footer_y and node("GuildReturn").global_position.y+node("GuildReturn").size.y<=1080,"G08 six-row mock scrolls without moving operations offscreen")
	game.data.campaign.selected=original_ids;game.render();await settle()
	await game.act("accept",[game.campaign().board[0].id,"porter"]);await settle()
	var cargo=await saved();await tap("RosterMember_porter");await tap("GuildRemove")
	check(guild.stage=="confirm" and node("GuildConfirmCancel")!=null,"G09 cargo owner removal requires explicit confirmation")
	await tap("GuildConfirmCancel")
	check((await saved())==cargo and guild.stage=="idle","G09 cargo confirmation cancellation preserves full save")
	await tap("GuildRemove");game.dialog.escape();await settle()
	check((await saved())==cargo and guild.stage=="idle","G09 cargo confirmation Escape preserves full save")
	await tap("GuildRemove");intent=guild.candidate("remove","porter","");context=guild.stamp();ticket=guild.generation;var calls=recorder.select_count
	await game.update({"op":"campaign_load","data":cargo});await enter_facility("party");await settle()
	await guild.commit("remove","porter","",intent,context,ticket);await settle()
	check(recorder.select_count==calls and (await saved())==cargo,"G10 stale confirmation after load cannot dispatch")
	await tap("GuildReturn")
	check(game.page=="party" and node("FacilityChoice_guild")!=null and (await saved())==cargo,"G01 return reaches guild entry without mutation")
	await tap("FacilityExit")
	check(game.page=="hub" and (await saved())==cargo,"G01 entry return reaches town hub without mutation")
	var elsewhere=roundtrip.duplicate(true);elsewhere.state.location="east";await game.update({"op":"campaign_load","data":elsewhere});game.navigate("hub");await settle()
	check(node("HubFacility_guild")==null and not guild.available(),"G01 no guild outside Astaris")
	game.pages.party_view.open_detail("guard");await settle()
	check(not game.modal_open() and not game.can_inspect_member("guard"),"G07 noncompanion detail hidden outside Astaris")
	await enter_facility("shop");await settle()
	game.pages.shop_view.open_comparison("undertow-sword");await settle()
	check(node("ShopComparisonBuy")!=null and node("ShopComparisonStats")!=null,"G10 shop inline comparison and purchase flow present")
	await tap("ShopComparisonBuy")
	check(game.dialog.window.title=="購入の確認" and node("PurchaseAgree")!=null and node("PurchaseRecipient_guard")==null,"G10 payment precedes recipient")
	await tap("PurchaseDecline");await tap("RosterMember_archer")
	check(game.shop_uid=="archer","G10 shop roster selects purchase owner without mutation")
	game.navigate("character");await settle();await tap("RosterMember_archer")
	check(game.page=="character" and game.pages.party_uid=="archer" and node("CharacterSlot_head")!=null and game.pages.party_view.workspace.owner=="archer","G10 shared roster opens named character workspace")
	game.engine=actual;recorder.queue_free();game.closing=true;await game.audio.finish_audio();actual.close_engine();game.queue_free();await frames()
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("guild-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)

func all_inventory():
	var chooser=game.find_child("OwnedEquipmentSlot",true,false)
	chooser.select(0);chooser.item_selected.emit(0);await settle()

func enter_facility(page: String):
	game.navigate(page);await settle()
	var service={"shop":"buy","party":"guild","inn":"inn"}.get(page,"")
	var choice=game.find_child("FacilityChoice_"+service,true,false)
	if choice!=null and choice.is_visible_in_tree():
		choice.pressed.emit();await settle()
