extends SceneTree
var game
var checks=[]
var evidence=""
func _initialize():call_deferred("run")
func check(id,passed,detail):
	checks.append({"id":id,"passed":bool(passed),"detail":detail});print(("PASS " if passed else "FAIL ")+id+" "+detail)
func node(id):return game.find_child(id,true,false)
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func party():return game.pages.party_view
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker or game.pages.shop_view.plan.refreshing:await process_frame
func member_ids(parent):
	var ids=[]
	for child in parent.find_children("*","",true,false):
		if child.has_meta("member_id"):ids.append(str(child.get_meta("member_id")))
	return ids
func member(uid):return game.roster().filter(func(u):return u.id==uid)[0]
func text_in(parent):
	var texts=[]
	for child in parent.find_children("*","Label",true,false):texts.append(child.text)
	return "\n".join(texts)
func load_at(seed,place):
	var fixture=seed.duplicate(true);fixture.state.location=place
	await game.update({"op":"campaign_load","data":fixture});game.navigate("party");await settle()
func close_portraits():
	var window=node("PortraitChooser");window.hide();window.queue_free();await settle()
func inspect_locations(seed):
	for dims in [Vector2i(1920,1080),Vector2i(800,600)]:
		root.size=dims;await settle()
		for place in ["astaris","east","west","north","south"]:
			await load_at(seed,place);var before=await saved();game.pages.party_uid="warrior";game.render();await settle()
			var astaris=place=="astaris";var active=game.campaign().selected;var shown=member_ids(node("PartySplit"));var tag=str(dims.x)+"-"+place
			check("ROSTER-"+tag,game.visible_roster().size()==(11 if astaris else active.size()) and (astaris or shown.all(func(id):return active.has(id))),"only companions appear outside Astaris; full stored roster remains 11")
			var selectors=node("PartyReserveSelector")
			check("SELECTOR-"+tag,(selectors!=null)==(astaris and game.ui_size_mode!="standard"),"compact reserve selector exists only at Astaris")
			check("FOCUS-"+tag,game.pages.party_uid=="warrior" if astaris else active.has(game.pages.party_uid),"stale reserve selection is replaced by a companion outside Astaris")
			game.pages.select_party("warrior");party().open_inventory("warrior");await settle()
			check("DETAIL-"+tag,party().detail_uid=="warrior" if astaris else party().detail_uid.is_empty() and not game.modal_open(),"direct/cached status entry respects reserve visibility")
			if astaris:node("StatusClose").pressed.emit();await settle()
			else:
				party().open_equipment(member("warrior"),member("warrior").equipmentSlots[0]);await settle()
				check("GEAR-"+tag,not game.modal_open(),"cached reserve equipment callback cannot reopen hidden detail")
			game.portrait_dialog();await settle();var chooser=node("PortraitChooser");var portraits=member_ids(chooser)
			check("PORTRAITS-"+tag,portraits.size()==(11 if astaris else active.size()) and (astaris or portraits.all(func(id):return active.has(id))),"image selector lists only companions outside Astaris")
			check("PORTRAIT-BOUNDS-"+tag,Rect2i(Vector2i.ZERO,root.size).encloses(Rect2i(chooser.position,chooser.size)),"image chooser stays inside the current client area")
			if astaris:
				var reserve_rows=chooser.find_children("*","",true,false).filter(func(c):return c.has_meta("member_id") and not active.has(c.get_meta("member_id")))
				check("PORTRAIT-BLOCK-"+tag,reserve_rows.all(func(r):return r.find_children("*","Button",true,false).all(func(b):return b.disabled)),"reserve image controls are disabled until joining")
			await close_portraits();check("UNCHANGED-"+tag,await saved()==before,"inspection and rejected callbacks leave campaign exact")
func denied_and_rejoin(seed):
	await load_at(seed,"astaris");var original=game.campaign().characters.warrior.duplicate(true);var before=await saved()
	party().open_inventory("warrior");await settle();var inv=party().inventory_view;inv.pick("potion");await settle()
	check("ITEM-BUTTONS",node("InventoryUse").disabled and node("InventoryTransfer").disabled and node("InventoryDiscard").disabled,"reserve consumable actions are disabled")
	inv.pick("sword-wood");await settle()
	check("GEAR-BUTTONS",node("InventoryEquip").disabled and node("InventoryTransfer").disabled and node("InventoryDiscard").disabled,"reserve owned equipment actions are disabled")
	party().detail_tab=1;party().refresh_modal();await settle()
	var allocation=game.find_children("*","Button",true,false).filter(func(b):return str(b.get_meta("ui_key","")).begins_with("allocate_"))
	check("GROWTH-BUTTONS",allocation.size()==6 and allocation.all(func(b):return b.disabled),"reserve allocation plus/minus controls are disabled")
	party().change_draft(member("warrior"),"str",1)
	check("GROWTH-CALLBACK",party().draft_total()==0 and await saved()==before,"cached allocation callback cannot spend reserve points")
	node("StatusClose").pressed.emit();await settle()
	await game.import_portrait(evidence.path_join("does-not-exist.png"),"warrior");game.reset_portrait("warrior");await settle()
	check("PORTRAIT-CALLBACK",await saved()==before and game.portraits.metadata.characters.is_empty(),"reserve image callback returns before file access or mutation")
	await game.act("select",[["guard","warrior","porter"]]);await settle()
	check("REJOIN",game.campaign().characters.warrior==original,"joining preserves complete inventory, equipment, HP/MP and growth")
	party().open_inventory("warrior");await settle();inv.pick("potion");await settle()
	check("REJOIN-ACTIONS",not node("InventoryTransfer").disabled and not node("InventoryDiscard").disabled,"joining restores legal inventory operations")
	node("StatusClose").pressed.emit();await settle()
	await game.act("select",[["guard","porter"]]);await settle()
	var envelope=await saved();await game.update({"op":"campaign_load","data":envelope});await settle()
	await game.act("select",[["porter","warrior","guard"]]);await settle()
	check("REJOIN-ROUNDTRIP",game.campaign().characters.warrior==original,"removal, save/load, and reordered rejoin preserve every field")
func departure(seed):
	await load_at(seed,"astaris");party().open_inventory("warrior");await settle()
	await game.act("depart",["east"]);await settle()
	check("DEPARTURE",game.campaign().phase=="road" and game.campaign().location=="astaris" and not game.reserves_visible() and not game.can_inspect_member("warrior"),"origin still says Astaris on the road, but reserves are hidden")
	check("STALE-MODAL",party().detail_uid.is_empty() and not game.modal_open(),"departure closes an existing reserve detail without touching stock")
	var original=game.campaign().characters.warrior.duplicate(true)
	for phase in ["camp","deployment","battle","arrival","result"]:
		# Presentation-only phase probe: never send synthetic state to the engine or save it.
		game.data.campaign.phase=phase
		check("PHASE-"+phase,not game.can_inspect_member("warrior") and game.visible_roster().all(func(u):return game.active_member(str(u.id))),"non-town states expose companions only")
	game.data.campaign.phase="road"
	check("PHASE-STOCK",game.campaign().characters.warrior==original,"presentation filtering preserves reserve state")
func retained_plan(seed):
	await load_at(seed,"east");var plan=game.pages.shop_view.plan
	plan.plans={"east":{"warrior/rightHand":{"characterId":"warrior","gearId":"sword-wood","slot":"rightHand","name":"木の剣"}}}
	var original=plan.plans.duplicate(true);var before=await saved();game.navigate("shop");plan.show("plan");await settle()
	check("PLAN-HIDDEN",not text_in(node("PurchasePlanScroll")).contains(game.member_name("warrior")) and text_in(node("PurchasePlanScroll")).contains("同行していない仲間"),"retained plan omits the absent person's name and equipment details")
	check("PLAN-RETAINED",plan.plans==original and node("PlanCheckout").disabled and await saved()==before,"reserve intention stays intact but cannot be purchased")
	var back=game.campaign_identity.save_metadata(await saved());back.state.location="astaris"
	await game.update({"op":"campaign_load","data":back});await settle();await game.act("select",[["warrior","porter"]]);await settle()
	var town=game.campaign_identity.save_metadata(await saved());town.state.location="east"
	await game.update({"op":"campaign_load","data":town});game.navigate("shop");plan.show("plan");await settle()
	check("PLAN-REJOIN",plan.plans==original and text_in(node("PurchasePlanScroll")).contains(game.member_name("warrior")) and node("PlanCheckout").disabled,"rejoining reveals retained intention with a fresh unapproved quote; nothing is purchased automatically")
func portraits_roundtrip(seed):
	await load_at(seed,"east");var original=game.campaign().characters.warrior.duplicate(true)
	var img=Image.create(2,2,false,Image.FORMAT_RGBA8);img.fill(Color.CORNFLOWER_BLUE);var source=evidence.path_join("fixture-portrait.png");img.save_png(source)
	var imported=await game.update({"op":"godot_io","action":"portrait","path":source});await settle()
	check("PORTRAIT-FIXTURE",imported.get("ok",false),"test-owned synthetic portrait prepared in isolated evidence directory")
	var envelope=await saved();envelope.nativePortraits={"version":1,"characters":{"warrior":imported.data}};var path=evidence.path_join("reserve-portrait-save.json")
	await game.write_snapshot(path,envelope,"検証用進行");await settle();var bytes=FileAccess.get_file_as_bytes(path)
	await game.load_game(path);await settle()
	check("HIDDEN-SAVE-LOAD",game.portraits.metadata.characters.get("warrior")==imported.data and game.campaign().characters.warrior==original and not game.can_inspect_member("warrior"),"hidden reserve portrait is accepted using the full saved roster; all inventory fields stay exact")
	check("SOURCE-PRESERVED",FileAccess.get_file_as_bytes(path)==bytes,"reading the save does not rewrite its source bytes")
	game.reset_portrait("warrior");await game.import_portrait(source,"warrior");await settle()
	check("HIDDEN-PORTRAIT-RETAINED",game.portraits.metadata.characters.warrior==imported.data,"blocked reserve image changes retain existing custom metadata")
	var back=await saved();back.state.location="astaris";back.nativePortraits=envelope.nativePortraits
	var return_path=evidence.path_join("reserve-return-save.json");await game.write_snapshot(return_path,back,"検証用進行");await settle();await game.load_game(return_path);await settle()
	await game.act("select",[["warrior","porter"]]);await settle()
	check("PORTRAIT-REJOIN",game.portraits.metadata.characters.warrior==imported.data and game.campaign().characters.warrior==original,"returning to Astaris and rejoining retains hidden portrait and possessions")
func run():
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("User data must be isolated");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;var seed=await saved();var reserve=seed.state.characters.warrior
	reserve.inventory={"potion":7,"ether":2,"sword-wood":2};reserve.hp=31;reserve.mp=1;reserve.level=2;reserve.xp=100;reserve.statPoints=2;reserve.skillPoints=1
	await inspect_locations(seed);await denied_and_rejoin(seed);await departure(seed);await retained_plan(seed);await portraits_roundtrip(seed)
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(evidence.path_join("reserve-policy-regression.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
