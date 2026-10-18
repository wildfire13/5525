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
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true;actual=game.engine
	var seed=await saved();seed.state.characters.guard.inventory={"potion":2};seed.state.characters["guard-2"].inventory={"ether":4};seed.state.characters.warrior.inventory={"potion":1,"sword-wood":1};seed.state.characters.warrior.statPoints=2
	seed.state.characters.warrior.xp=100;seed.state.characters.warrior.level=2;seed.state.characters.warrior.skillPoints=1
	var loaded=await game.update({"op":"campaign_load","data":seed})
	check(loaded.get("ok",false),"fixture uses valid owned stock and earned growth points")
	game.navigate("hub");await settle()
	check(node("HubFacility_guild")!=null and node("HubFacility_guild").text=="ギルド","G01 Astaris hub has explicit guild entry")
	await tap("HubFacility_guild")
	var guild=game.pages.guild_view;recorder=RecordedEngine.new();recorder.actual=actual;game.add_child(recorder);game.engine=recorder
	var before=await saved()
	check(game.page=="party" and game.header.text=="ギルド / パーティー編成","G01 one click opens formation page")
	check(ids("GuildCurrentScroll")==game.campaign().selected and ids("GuildReserveScroll")==["guard-2","archer-2","mage-2","scout-2","porter-2","warrior"],"G02 lists retain selected and reserve order")
	check(node("GuildVitals_guard").text.contains("Lv.1") and not node("GuildStatus_porter").text.contains("編成固定"),"G02 rows show resources and level without job-based lock")
	await tap("GuildMember_guard")
	check((await saved())==before and guild.chosen_id=="guard","G05 first row selection is pure")
	var intent=guild.candidate("swap","guard","guard-2");var context=guild.stamp();var ticket=guild.generation+1
	recorder.hold_next=true;recorder.release=false;node("GuildMember_guard-2").pressed.emit()
	var deadline=Time.get_ticks_msec()+4000
	while not recorder.held and Time.get_ticks_msec()<deadline:await process_frame
	check(recorder.held and game.locked and guild.stage=="pending","G10 direct counterpart click starts exactly one pending select")
	guild.commit("swap","guard","guard-2",intent,context,ticket);guild.cancel_selection();game.navigate("hub")
	var denied=await game.update({"op":"campaign_load","data":seed})
	check(recorder.select_count==1 and game.page=="party" and not denied.get("ok",true),"G10 duplicate/cancel/navigation/load blocked while select pending")
	recorder.release=true;await settle()
	var after=await saved()
	check(game.campaign().selected==["guard-2","archer","mage","scout","porter"] and recorder.select_count==1,"G03 full party swap changes one slot through one select")
	check(after.state.characters==before.state.characters and after.state.gold==before.state.gold,"G06 swap preserves owner/equipment/HP/MP/growth/gold")
	check(guild.notice.contains("入替完了") and ids("GuildCurrentScroll")==game.campaign().selected,"G03 response updates lists and notice")
	await tap("GuildMember_porter")
	check(not node("GuildRemove").disabled and not guild.candidate("remove","porter","").is_empty() and not guild.candidate("swap","porter","porter-2").is_empty(),"G04 porter removal and replacement allowed")
	guild.cancel_selection();await settle();await tap("GuildMember_guard")
	check(node("GuildAdd").disabled and node("GuildSelection").text.contains("5/5人"),"G04 full-party reserve addition explains capacity")
	var event=InputEventKey.new();event.pressed=true;event.keycode=KEY_ESCAPE;game._unhandled_key_input(event);await settle()
	check(guild.stage=="idle" and guild.chosen_id.is_empty() and game.page=="party" and (await saved())==after,"G09 Escape cancels local selection without mutation")
	await tap("GuildMember_archer");await tap("GuildRemove")
	check(game.campaign().selected==["guard-2","mage","scout","porter"],"G04 noncargo member returns to reserve without reordering others")
	await tap("GuildMember_archer");await tap("GuildAdd")
	check(game.campaign().selected==["guard-2","mage","scout","porter","archer"] and (await saved()).state.characters==before.state.characters,"G04 addition appends and preserves owner data")
	var roundtrip=await saved();await game.update({"op":"campaign_load","data":roundtrip});game.navigate("party");await settle()
	check(game.campaign().selected==roundtrip.state.selected,"G10 save/load retains composition and order")
	await tap("GuildMember_warrior");await tap("GuildDetails");await tap("StatusTab_3");await tap("InventoryItem_potion")
	check(node("InventoryUse").disabled and node("InventoryTransfer").disabled and node("InventoryDiscard").disabled,"G07 reserve inventory restrictions remain")
	await tap("StatusTab_1")
	check(game.find_children("*","Button",true,false).filter(func(b):return str(b.get_meta("ui_key","")).begins_with("allocate_")).all(func(b):return b.disabled),"G07 reserve growth editing disabled")
	check(game.find_children("*","Button",true,false).all(func(b):return b.get_meta("ui_key","")!="party_membership"),"G01 no old growth-tab membership controls")
	game.dialog.close();await settle();check((await saved())==roundtrip,"G05 detail inspection changes no state")
	guild.cancel_selection();await settle()
	await tap("GuildMember_guard-2");recorder.reject_next=true;await tap("GuildMember_guard")
	check(guild.stage=="idle" and guild.notice.contains("拒否") and (await saved())==roundtrip,"G10 rejected select preserves state and explains reason")
	guild.cancel_selection();await settle()
	var footer_y=node("GuildOperations").global_position.y;var original_ids=game.data.campaign.selected.duplicate()
	game.data.campaign.selected.append("guard");game.render();await settle()
	check(ids("GuildCurrentScroll").size()==6 and node("GuildOperations").global_position.y==footer_y and node("GuildReturn").global_position.y+node("GuildReturn").size.y<=1080,"G08 six-row mock scrolls without moving operations offscreen")
	game.data.campaign.selected=original_ids;game.render();await settle()
	await game.act("accept",[game.campaign().board[0].id,"porter"]);await settle()
	var cargo=await saved();await tap("GuildMember_porter");await tap("GuildRemove")
	check(guild.stage=="confirm" and node("GuildConfirmCancel")!=null,"G09 cargo owner removal requires explicit confirmation")
	await tap("GuildConfirmCancel")
	check((await saved())==cargo and guild.stage=="idle","G09 cargo confirmation cancellation preserves full save")
	await tap("GuildRemove");game.dialog.escape();await settle()
	check((await saved())==cargo and guild.stage=="idle","G09 cargo confirmation Escape preserves full save")
	await tap("GuildRemove");intent=guild.candidate("remove","porter","");context=guild.stamp();ticket=guild.generation;var calls=recorder.select_count
	await game.update({"op":"campaign_load","data":cargo});game.navigate("party");await settle()
	await guild.commit("remove","porter","",intent,context,ticket);await settle()
	check(recorder.select_count==calls and (await saved())==cargo,"G10 stale confirmation after load cannot dispatch")
	await tap("GuildReturn")
	check(game.page=="hub" and (await saved())==cargo,"G01 return reaches town hub without mutation")
	var elsewhere=roundtrip.duplicate(true);elsewhere.state.location="east";await game.update({"op":"campaign_load","data":elsewhere});game.navigate("hub");await settle()
	check(node("HubFacility_guild")==null and not guild.available(),"G01 no guild outside Astaris")
	game.pages.party_view.open_detail("guard");await settle()
	check(not game.modal_open() and not game.can_inspect_member("guard"),"G07 noncompanion detail hidden outside Astaris")
	game.navigate("shop");await settle()
	check(node("ProductBuy_undertow-sword")!=null and node("ProductTrial_undertow-sword")!=null,"G10 shop row flow present")
	await tap("ProductBuy_undertow-sword")
	check(game.dialog.window.title=="購入の確認" and node("PurchaseAgree")!=null and node("PurchaseRecipient_guard")==null,"G10 payment precedes recipient")
	await tap("PurchaseDecline");await tap("PartyFace_archer")
	check(game.dialog.window.title=="キャラクターステータス" and game.pages.party_view.detail_uid=="archer","G10 party portrait opens character status")
	game.dialog.close(false);game.engine=actual;recorder.queue_free();game.closing=true;await game.audio.finish_audio();actual.close_engine();game.queue_free();await frames()
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("guild-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
