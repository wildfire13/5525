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
func key(name_: String):return game.find_children("*","BaseButton",true,false).filter(func(b):return b.get_meta("ui_key","")==name_)[0]
func frames(n:=12):
	for i in range(n):await process_frame
func settle():
	await frames()
	while game.locked or game.engine.busy or game.presenting:await process_frame
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
	game.navigate("board");await settle()
	check(key("nav_party").text.contains("ギルド"),"G01 Astaris has explicit guild entry")
	key("nav_party").pressed.emit();await settle()
	var guild=game.pages.guild_view;recorder=RecordedEngine.new();recorder.actual=actual;game.add_child(recorder);game.engine=recorder
	var before=await saved()
	check(game.page=="party" and game.header.text=="ギルド / パーティー編成","G01 one click opens formation page")
	check(ids("GuildCurrentScroll")==game.campaign().selected and ids("GuildReserveScroll")==["guard-2","archer-2","mage-2","scout-2","porter-2","warrior"],"G02 simultaneous lists retain selected order and roster reserve order")
	check(node("GuildVitals_guard").text.contains("Lv.1") and node("GuildStatus_porter").text.contains("編成固定：ポーター"),"G02 rows show resources, level and explicit porter lock")
	await tap("GuildMember_guard")
	check((await saved())==before and guild.chosen_id=="guard","G05 row selection is pure")
	await tap("GuildSwap");await tap("GuildMember_guard-2")
	check(game.dialog.body.get_child(0).text.contains("ガロ") and game.dialog.body.get_child(0).text.contains("バルト"),"G09 confirmation names outgoing and incoming characters")
	await tap("GuildConfirmCancel")
	check(guild.stage=="pick" and (await saved())==before and recorder.select_count==0,"G05 confirmation cancel returns to counterpart selection without request")
	await tap("GuildCancel");await tap("GuildSwap");await tap("GuildMember_guard-2")
	var intent=guild.candidate("swap","guard","guard-2");var context=guild.stamp();var ticket=guild.generation
	recorder.hold_next=true;recorder.release=false;node("GuildConfirm").pressed.emit()
	var deadline=Time.get_ticks_msec()+4000
	while not recorder.held and Time.get_ticks_msec()<deadline:await process_frame
	check(recorder.held and game.locked and guild.stage=="pending","G10 delayed select locks formation")
	guild.commit("swap","guard","guard-2",intent,context,ticket);guild.cancel_selection();game.navigate("board")
	var denied=await game.update({"op":"campaign_load","data":seed})
	check(recorder.select_count==1 and game.page=="party" and not denied.get("ok",true),"G10 duplicate/cancel/navigation/load blocked while one select is pending")
	recorder.release=true;await settle()
	var after=await saved()
	check(game.campaign().selected==["guard-2","archer","mage","scout","porter"] and recorder.select_count==1,"G03 full party swap changes one slot through one select call")
	check(after.state.characters==before.state.characters and after.state.gold==before.state.gold,"G06 swap preserves all owner/equipment/HP/MP/growth/gold fields")
	check(guild.notice.contains("入替完了") and ids("GuildCurrentScroll")==game.campaign().selected,"G03 successful response updates both lists and notice")
	await tap("GuildMember_porter")
	check(node("GuildSwap").disabled and node("GuildRemove").disabled and guild.candidate("remove","porter","").is_empty() and guild.candidate("swap","porter","porter-2").is_empty(),"G04 current porter removal and replacement are forbidden")
	await tap("GuildMember_guard")
	check(node("GuildAdd").disabled and node("GuildSelection").text.contains("5/5人"),"G04 full-party reserve addition explains capacity")
	await tap("GuildSwap");await tap("GuildMember_archer");game.dialog.escape();await settle()
	check(guild.stage=="pick" and (await saved())==after,"G09 confirmation Escape returns to counterpart selection")
	var event=InputEventKey.new();event.pressed=true;event.keycode=KEY_ESCAPE;game._unhandled_key_input(event);await settle()
	check(guild.stage=="idle" and game.page=="party" and (await saved())==after,"G09 counterpart Escape cancels selection only")
	await tap("GuildMember_archer");await tap("GuildRemove");await tap("GuildConfirm")
	check(game.campaign().selected==["guard-2","mage","scout","porter"],"G04 nonporter returns to reserve without reordering others")
	await tap("GuildAdd");await tap("GuildConfirm")
	check(game.campaign().selected==["guard-2","mage","scout","porter","archer"] and (await saved()).state.characters==before.state.characters,"G04 adding to vacant slot appends and preserves all character data")
	var roundtrip=await saved();await game.update({"op":"campaign_load","data":roundtrip});game.navigate("party");await settle()
	check(game.campaign().selected==roundtrip.state.selected,"G10 save/load retains successful composition and order")
	await tap("GuildMember_warrior");await tap("GuildDetails");await tap("StatusTab_3");await tap("InventoryItem_potion")
	check(node("InventoryUse").disabled and node("InventoryTransfer").disabled and node("InventoryDiscard").disabled,"G07 existing reserve inventory restrictions remain")
	await tap("StatusTab_1")
	check(game.find_children("*","Button",true,false).filter(func(b):return str(b.get_meta("ui_key","")).begins_with("allocate_")).all(func(b):return b.disabled),"G07 reserve growth editing remains disabled")
	check(game.find_children("*","Button",true,false).all(func(b):return b.get_meta("ui_key","")!="party_membership"),"G01 membership controls moved out of growth tab")
	await tap("StatusClose");check((await saved())==roundtrip,"G05 reserve detail inspection changes no state")
	await tap("GuildMember_guard-2");await tap("GuildSwap");await tap("GuildMember_guard")
	intent=guild.candidate("swap","guard-2","guard");context=guild.stamp();ticket=guild.generation;var calls=recorder.select_count
	await game.update({"op":"campaign_load","data":roundtrip});game.navigate("party");await settle()
	await guild.commit("swap","guard-2","guard",intent,context,ticket);await settle()
	check(recorder.select_count==calls and (await saved())==roundtrip,"G10 stale confirmation after load cannot dispatch old composition")
	await tap("GuildMember_guard-2");await tap("GuildSwap");await tap("GuildMember_guard");recorder.reject_next=true;await tap("GuildConfirm")
	check(guild.stage=="idle" and guild.notice.contains("拒否") and not guild.notice.contains("入替完了") and (await saved())==roundtrip,"G10 rejected select leaves current list and resources unchanged with reason")
	var footer_y=node("GuildOperations").global_position.y;var original_ids=game.data.campaign.selected.duplicate()
	game.data.campaign.selected.append("guard");game.render();await settle()
	check(ids("GuildCurrentScroll").size()==6 and node("GuildOperations").global_position.y==footer_y and node("GuildReturn").global_position.y+node("GuildReturn").size.y<=1080,"G08 six-row presentation mock scrolls without pushing fixed operations")
	game.data.campaign.selected=original_ids;game.render();await settle();await tap("GuildReturn")
	check(game.page=="board" and (await saved())==roundtrip,"G01 return to town cancels only local selection")
	var elsewhere=roundtrip.duplicate(true);elsewhere.state.location="east";await game.update({"op":"campaign_load","data":elsewhere});game.navigate("board");await settle()
	check(game.find_children("*","Button",true,false).all(func(b):return b.get_meta("ui_key","")!="nav_party") and not guild.available(),"G01 no guild entry or valid guild operation outside Astaris")
	game.pages.party_view.open_detail("guard");await settle()
	check(not game.modal_open() and not game.can_inspect_member("guard"),"G07 noncompanion detail stays hidden outside Astaris")
	game.navigate("shop");await settle()
	check(node("ProductBuy_undertow-sword")!=null and node("ProductTrial_undertow-sword")!=null,"G10 shop row flow remains present")
	await tap("ProductBuy_undertow-sword")
	check(game.dialog.window.title=="購入の確認" and node("PurchaseAgree")!=null and node("PurchaseRecipient_guard")==null,"G10 shop payment still precedes recipient")
	await tap("PurchaseDecline");await tap("PartyFace_archer")
	check(game.dialog.window.title=="ステータス" and game.pages.party_view.detail_uid=="archer","G10 lower face still opens existing status")
	game.dialog.close(false);game.engine=actual;recorder.queue_free();game.closing=true;await game.audio.finish_audio();actual.close_engine();game.queue_free();await frames()
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("guild-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
