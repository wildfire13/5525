extends SceneTree
# Headless controls/state evidence. It is not a screenshot or an OS input test.
var game
var fixtures={}
var checks=[]
var records=[]
var failures=[]
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func check(ok: bool,detail: String):
	checks.append({"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+detail)
	if not ok:failures.append(detail)
func node(id: String):return game.find_child(id,true,false)
func text(n: Node)->String:
	var parts=[]
	if n is Label or n is Button:parts.append(n.text)
	for child in n.get_children():parts.append(text(child))
	return "\n".join(parts)
func settle():
	for i in range(10):await process_frame
	var deadline=Time.get_ticks_msec()+15000
	while (game.locked or game.engine.busy or game.presenting or game.preview_pending or game.pages.shop_view.quote_worker) and Time.get_ticks_msec()<deadline:await process_frame
func snapshot():return (await game.engine.request({"op":"campaign_save"})).data
func restore(id: String,page: String="board",location: String=""):
	var saved=fixtures[id].duplicate(true)
	if not location.is_empty():saved.state.location=location
	game.page=page;await game.update({"op":"campaign_load","data":saved});await settle()
	if page in ["shop","inn"] and game.pages.facility_entry.at_top():
		game.pages.facility_entry.choose("buy" if page=="shop" else "inn");await settle()
func record(id: String,scope: Node):
	var icons=[]
	for n in scope.find_children("*","Control",true,false):
		if n.has_meta("ui_icon_id") and n.is_visible_in_tree():
			var rect=n.get_global_rect()
			icons.append({"id":n.get_meta("ui_icon_id"),"node":str(n.get_path()),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"inside_viewport":root.get_visible_rect().encloses(rect)})
	records.append({"id":id,"viewport":[root.size.x,root.size.y],"phase":game.campaign().phase,"page":game.page,"location":game.campaign().location,"icons":icons,"text":text(scope),"pixels_captured":false})
func item_cases():
	for dims in [Vector2i(1920,1080)]:
		root.size=dims
		await restore("camp","hub")
		var camp_before=await snapshot()
		var inventory_entry=game.content.find_children("*","Button",true,false).filter(func(button):return button.text=="インベントリ")
		check(inventory_entry.size()==1,"UX01 camp offers inventory access")
		if inventory_entry.size()==1:
			inventory_entry[0].pressed.emit();await settle()
			check(game.page=="character" and game.pages.party_view.workspace.tab=="inventory" and await snapshot()==camp_before,"UX01 camp entry preserves resources")
			node("FooterPartyButton").pressed.emit();await settle()
			check(game.page=="hub" and node("CampActions")!=null and await snapshot()==camp_before,"UX01 closing inventory restores camp")
		for context in ["camp","town","four"]:
			await restore(context,"items")
			var before=await snapshot()
			var selected=before.state.selected
			var party=node("CampParty" if context=="camp" else "ItemParty")
			var roster=node("PartyRoster")
			check(roster.find_children("RosterMember_*","Button",true,false).size()==selected.size(),"UX01 shared roster contains the selected party "+context)
			check(party.find_children("FullBodyPortrait","TextureRect",true,false).size()==selected.size(),"UX01 owner portraits match the party "+context)
			var owner=node("ItemMember_character_mirei")
			check(text(owner).contains("HP %d/" % before.state.characters["character_mirei"].hp) and text(owner).contains("MP %d/" % before.state.characters["character_mirei"].mp),"UX01 guard card shows current resources "+context)
			if before.state.characters["character_merina"].hp==0:check(text(node("ItemMember_character_merina")).contains("戦闘不能"),"UX01 defeated owner remains identifiable")
			check(root.get_visible_rect().encloses(node("RosterMember_character_mirei").get_global_rect()),"UX01 roster entry visible "+context)
			node("InventoryOwner_character_mirei").pressed.emit();await settle()
			check(game.page=="character" and game.pages.party_uid=="character_mirei" and game.pages.party_view.workspace.tab=="inventory" and await snapshot()==before,"UX01 owner opens inventory without consuming")
			node("FooterPartyButton").pressed.emit();await settle()
			check(game.page=="items" and node("InventoryOwner_character_mirei")!=null and await snapshot()==before,"UX01 return to owner cards preserves save")
	root.size=Vector2i(1920,1080)
	for context in ["town","road","north_travel"]:
		await restore(context,"hub")
		var member=node("RosterMember_character_mirei")
		check(text(member).contains("HP") and text(member).contains("MP"),"UX01 resource overview remains on "+context)
func result_cases():
	for id in ["north_delivery","north_travel","east_travel","west_travel","south_travel","astaris_travel"]:
		await restore(id)
		var before=await snapshot()
		var destination=str(before.state.location)
		var service="inn" if destination=="astaris" else "shop"
		var shortcut
		if id=="north_delivery":
			shortcut=node("ResultShop")
			check(shortcut!=null and shortcut.text=="ノースの装飾品店へ","UX02 North delivery offers the accessory shop")
			record("Q02-"+id+"-result",game.results_view.shade)
		else:
			check(game.page=="hub" and game.campaign().phase=="town","UX02 travel arrives at the town hub "+id)
			var facility={"north":"accessory","east":"weapon","west":"armor","south":"items","astaris":"inn"}[destination]
			shortcut=node("HubFacility_"+facility)
		check(shortcut!=null and not shortcut.disabled,"UX02 destination facility available "+id)
		if shortcut==null:continue
		shortcut.pressed.emit()
		if id=="north_delivery":shortcut.pressed.emit()
		await settle()
		var after=await snapshot()
		check(game.campaign().phase=="town" and game.page==service and after.state.location==destination and after.state.result==null,"UX02 destination service opens "+id)
		check(after.state.gold==before.state.gold and after.state.characters==before.state.characters and after.state.completed==before.state.completed and after.state.hours==before.state.hours and after.state.boardRound==before.state.boardRound,"UX02 opening facility does not regrant rewards "+id)
		await game.update({"op":"campaign_load","data":after});await settle()
		check(await snapshot()==after,"UX02 transition round-trips through save/load "+id)
		if destination=="north":
			game.pages.facility_entry.choose("buy");await settle()
			check(game.pages.shop_view.slots()==["accessory1","accessory2"] and node("ShopSlotFilter")!=null and game.shop_uid==game.pages.party_uid,"UX02 accessory shop opens for selected member")
			record("Q02-"+id+"-shop",game.content)
func icon_case(id: String,ids: Array):
	await settle();record(id,game.content)
	var actual=records[-1].icons.map(func(item):return item.id)
	for icon in ids:check(actual.has(icon),"EV01 live UI node "+id+" has "+icon)
func icon_cases():
	await restore("town","inn");await icon_case("Q04-inn",["inn"])
	await restore("town","shop","south");await icon_case("Q04-consumable-shop",["potion","ether"])
	await restore("town","board","east");check(node("QuestList").find_children("QuestChoice_*","Button",true,false).size()==game.campaign().board.size(),"Q04 village displays its current offers");record("Q04-village-board",game.content)
	await restore("town","shop","north");await game.pages.shop_view.select_slot("accessory1");await settle();check(not game.pages.offered().is_empty() and game.pages.offered().all(func(g):return g.get("shopProductId",g.id)==g.id and g.get("allowedSlots",[g.slot]).has("accessory1")),"Q04 accessory filter lists canonical products");record("Q04-accessory",game.content)
	await restore("town","shop","east");await game.pages.shop_view.select_slot("sword");await settle();record("Q04-weapon-shop",game.content)
	await restore("heal_left");var before=await snapshot();await game.choose_command("action_skill");await game.on_cell(24);await icon_case("Q03-healing",["hp","mp","healing"]);check(await snapshot()==before,"EV01 heal prediction does not consume")
	await restore("guard");before=await snapshot();await game.choose_command("action_defend");await icon_case("Q03-defense",["defense_up"]);check(await snapshot()==before,"EV01 defense prediction does not consume")
	await restore("porter");before=await snapshot();await game.choose_command("action_skill");await icon_case("Q03-formation",["skill","attack_up","defense_up"]);check(await snapshot()==before,"EV01 boost prediction does not consume")
	await restore("town","shop","east");await game.act("trial",["character_shion","twin-bow","rightHand"]);await game.choose_command("action_skill");await settle()
	var pair=game.data.choices.action_skill[0]
	for uid in pair:
		for unit in game.state().units:
			if unit.id==uid:await game.on_cell(int(unit.pos));break
	await icon_case("Q03-multiple-damage",["damage"]);check(game.preview.damagePreview.size()==2 and game.can_commit(),"Q03 real two-target prediction remains available")
	await game.act("endTrial",[]);await restore("town","shop","north");await game.act("trial",["character_mirei","return-ring-1","accessory1"]);await game.choose_command("action_skill");await game.select_skill("skill_return_home");await game.on_cell(0);await settle();record("Q03-return",game.content)
	check(game.command=="action_return" and game.can_commit() and text(game.content).contains("MP0"),"Q03 return stays available through skills at zero MP cost")
func run():
	if evidence.is_empty():evidence=ProjectSettings.globalize_path("user://ui-review-fixes")
	fixtures=preload("res://tests/ui_current_fixture.gd").generate("res://tests/ui_review_fixes_fixtures.cjs")
	if fixtures.is_empty():quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await item_cases();await result_cases();await icon_cases()
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));var f=FileAccess.open(evidence.path_join("reports/ui-review-fixes.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records,"gui":false,"input":"Godot button signals and application callbacks; no OS input","visual_acceptance":"not performed; desktop held by independent debugger","fixture_note":"result fixtures force battle victory to reach UI; not combat evidence"},"  "));f.close()
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await settle();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	print("UI REVIEW FIXES ",checks.size()," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
