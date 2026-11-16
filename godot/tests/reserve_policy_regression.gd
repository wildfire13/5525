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
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker:await process_frame
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
	await game.update({"op":"campaign_load","data":fixture});game.navigate("character");await settle()
func close_portraits():
	var window=node("PortraitChooser");window.hide();window.queue_free();await settle()
func inspect_locations(seed):
	for dims in [Vector2i(1920,1080),Vector2i(800,600)]:
		root.size=dims;await settle()
		for place in ["astaris","east","west","north","south"]:
			await load_at(seed,place);var before=await saved();game.pages.party_uid="warrior";game.render();await settle()
			var astaris=place=="astaris";var active=game.campaign().selected;var tag=str(dims.x)+"-"+place
			var roster=node("PartyRoster").find_children("RosterMember_*","Button",true,false)
			check("ROSTER-"+tag,roster.size()==active.size() and roster.all(func(row):return active.has(str(row.name).trim_prefix("RosterMember_"))),"character page lists current companions")
			check("FOCUS-"+tag,active.has(game.pages.party_uid),"stale reserve selection resolves to a companion")
			var previous=game.pages.party_uid
			party().open_inventory("warrior");await settle()
			check("DETAIL-"+tag,game.pages.party_uid==previous and party().workspace.owner==previous,"reserve cannot replace active inventory owner")
			game.portrait_dialog();await settle();var chooser=node("PortraitChooser");var portraits=member_ids(chooser)
			check("PORTRAITS-"+tag,portraits.size()==(game.roster().size() if astaris else active.size()) and (astaris or portraits.all(func(id):return active.has(id))),"image selector lists only companions outside Astaris")
			check("PORTRAIT-BOUNDS-"+tag,Rect2i(Vector2i.ZERO,root.size).encloses(Rect2i(chooser.position,chooser.size)),"image chooser stays inside the current client area")
			if astaris:
				var reserve_rows=chooser.find_children("*","",true,false).filter(func(c):return c.has_meta("member_id") and not active.has(c.get_meta("member_id")))
				check("PORTRAIT-BLOCK-"+tag,reserve_rows.all(func(r):return r.find_children("*","Button",true,false).all(func(b):return b.disabled)),"reserve image controls are disabled until joining")
			await close_portraits();check("UNCHANGED-"+tag,await saved()==before,"inspection and rejected callbacks leave campaign exact")
func denied_and_rejoin(seed):
	await load_at(seed,"astaris");var original=game.campaign().characters.warrior.duplicate(true);var before=await saved()
	party().open_inventory("warrior");await settle()
	check("RESERVE-ACTIONS",party().workspace.owner!="warrior","reserve inventory actions are inaccessible")
	party().change_draft(member("warrior"),"str",1)
	check("GROWTH-CALLBACK",party().draft_total()==0 and await saved()==before,"reserve allocation callback cannot spend points")
	await game.import_portrait(evidence.path_join("does-not-exist.png"),"warrior");game.reset_portrait("warrior");await settle()
	check("PORTRAIT-CALLBACK",await saved()==before and game.portraits.metadata.characters.is_empty(),"reserve image callback returns before file access or mutation")
	await game.act("select",[["guard","warrior","porter"]]);await settle()
	check("REJOIN",game.campaign().characters.warrior==original,"joining preserves complete inventory, equipment, HP/MP and growth")
	node("RosterMember_warrior").pressed.emit();await settle()
	if party().workspace.tab!="inventory":party().workspace.set_tab("inventory");await settle()
	var potion=game.campaign().inventoryByCharacter.warrior.entries.filter(func(e):return e.id=="potion")[0]
	party().workspace.picked=potion;game.render();await settle()
	check("REJOIN-ACTIONS",party().workspace.owner=="warrior" and not node("CharacterDiscard").disabled and party().workspace.payload(potion,"transfer",null).allowed.has("porter"),"joining restores discard and transfer")
	await game.act("select",[["guard","porter"]]);await settle()
	var envelope=await saved();await game.update({"op":"campaign_load","data":envelope});await settle()
	await game.act("select",[["porter","warrior","guard"]]);await settle()
	check("REJOIN-ROUNDTRIP",game.campaign().characters.warrior==original,"removal, save/load, and reordered rejoin preserve every field")
func departure(seed):
	await load_at(seed,"astaris")
	await game.act("depart",["east"]);await settle()
	check("DEPARTURE",game.campaign().phase=="road" and game.campaign().location=="astaris" and not game.reserves_visible() and not game.can_inspect_member("warrior"),"origin still says Astaris on the road, but reserves are hidden")
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
	game.checks_fast=true;game.audio.fast_mode=true;await preload("res://tests/current_historical_fixture.gd").install(game);await settle();var seed=await saved();var reserve=seed.state.characters.warrior
	reserve.inventory={"potion":7,"ether":2,"sword-wood":2};reserve.hp=31;reserve.mp=1;reserve.level=2;reserve.xp=100;reserve.statPoints=2;reserve.skillPoints=1
	await inspect_locations(seed);await denied_and_rejoin(seed);await departure(seed);await portraits_roundtrip(seed);await retained_plan(seed)
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(evidence.path_join("reserve-policy-regression.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
