extends "res://tests/ui_feedback2_20261016.gd"
func pointer_click(control):
	var point=control.get_global_rect().get_center()
	var motion_=InputEventMouseMotion.new();motion_.position=point;motion_.global_position=point;root.push_input(motion_,true);await frames(2)
	for pressed in [true,false]:
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;e.position=point;e.global_position=point;root.push_input(e,true);await frames(2)
	await settle()
func green(control):return control.get_theme_stylebox("normal").bg_color.is_equal_approx(Color("#236044"))
func return_layout(id):
	var back=node(id);var bar=node("PartyFaceBar")
	check(back!=null and back.text=="広場に移動" and green(back) and not game.town_back.visible,"one green square-return button "+id)
	check(back.get_global_rect().end.y<=bar.global_position.y and bar.global_position.y-back.get_global_rect().end.y<=20 and absf(back.get_global_rect().end.x-bar.get_global_rect().end.x)<2,"return sits right aligned immediately above party bar "+id)
	check(game.find_children("*","Button",true,false).filter(func(b):return b.visible and b.text=="広場に移動").size()==1,"no duplicate return "+id)
func alignment():
	check(absf(node("StatusTab_2").get_global_rect().end.x-node("StatusEquipped").get_global_rect().end.x)<2,"skills tab right edge matches equipped column")
	check(absf(node("OwnedInventoryHeader").global_position.x-node("StatusOwnedInventory").global_position.x)<2,"inventory header left edge matches owner inventory")
func run():
	create_timer(90).timeout.connect(func():print("FAIL feedback2 watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var before=await saved();game.navigate("party");await settle()
	return_layout("GuildReturn")
	await click("GuildMember_guard")
	check(not game.modal_open() and game.pages.guild_view.chosen_id=="guard","first guild click selects without opening or changing state")
	await click("GuildMember_guard")
	check(game.dialog.window.title=="キャラクターステータス" and game.pages.party_view.detail_uid=="guard","selected member repeat click opens existing character status")
	check(game.dialog.window.size.x==1920 and game.dialog.window.size.y==780,"new default doubles width capped to screen, unchanged height")
	alignment()
	check(not game.dialog.window.exclusive and game.dialog.layout_key()=="status","renamed status preserves face switching and saved layout key")
	check(await saved()==before,"repeat-click inspection leaves full campaign unchanged")
	game.dialog.close();await settle()
	check(node("GuildDetails")!=null and not node("GuildDetails").disabled,"explicit person-details button remains")
	await click("GuildDetails")
	check(game.dialog.window.title=="キャラクターステータス" and game.pages.party_view.detail_uid=="guard","details button opens identical status")
	game.dialog.close();await settle();game.pages.guild_view.cancel_selection();await settle()
	await click("GuildMember_warrior");await click("GuildMember_warrior")
	check(game.pages.party_view.detail_uid=="warrior" and not game.active_member("warrior"),"reserve repeat click opens existing read-only status")
	check(await saved()==before,"reserve inspection does not modify composition or stock")
	game.dialog.close();await settle()
	# Saved dimensions are not overwritten by the new default; resized screen remains safe.
	game.preferences.store_rect("status",Rect2(120,60,1000,700));game.pages.party_view.open_detail("guard");await settle()
	check(game.dialog.window.size==Vector2i(1000,700),"existing saved width and height retained")
	alignment();game.dialog.close();await settle()
	for resolution in [Vector2i(1364,1024),Vector2i(1920,1080)]:
		root.size=resolution;await settle();game.navigate("party");await settle();return_layout("GuildReturn")
		game.pages.party_view.open_detail("guard");await settle();alignment()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size))),"saved status remains within viewport "+str(resolution))
		game.dialog.close();await settle();await pointer_click(node("GuildReturn"))
		check(game.page=="hub","guild return accepts viewport pointer click")
		game.navigate("inn");await settle();return_layout("InnReturn")
		check(node("InnParty").get_child_count()==game.campaign().selected.size(),"inn card count follows active party")
		check(node("InnParty").find_children("*","Button",true,false).is_empty(),"inn cards have no inventory buttons")
		check(node("InnStay").size.x<root.size.x/2 and green(node("InnStay")) and node("InnStay").disabled,"compact green stay control disables when full")
		for id in game.campaign().selected:
			check(node("InnPortrait_"+id).texture!=null and node("InnHP_"+id).text.contains("HP ") and node("InnMP_"+id).text.contains("MP "),"portrait HP MP card "+id)
		await pointer_click(node("InnReturn"));check(game.page=="hub","inn return accepts viewport pointer click")
	# Valid injured-party save; lodging rules remain the existing API's responsibility.
	var injured=before.duplicate(true);injured.state.characters.guard.hp=0;injured.state.characters.mage.mp=0
	await game.update({"op":"campaign_load","data":injured});game.navigate("inn");await settle()
	check(not node("InnStay").disabled and node("InnHP_guard").text.begins_with("HP 0/"),"injured/KO party enables lodging")
	var unchanged=await saved();await click("InnStay")
	var d=game.find_children("*","ConfirmationDialog",true,false).filter(func(w):return w.visible)[0];d.canceled.emit();await settle()
	check(await saved()==unchanged,"lodging cancel preserves all state")
	await click("InnStay");d=game.find_children("*","ConfirmationDialog",true,false).filter(func(w):return w.visible)[0];d.confirmed.emit();d.confirmed.emit();await settle()
	var after=await saved();check(after.state.gold==unchanged.state.gold-30 and after.state.characters.guard.hp==game.roster().filter(func(u):return u.id=="guard")[0].max and after.state.characters.mage.mp==game.roster().filter(func(u):return u.id=="mage")[0].maxMp,"lodging charges once and heals existing HP/MP")
	check(after.state.hours==unchanged.state.hours and after.state.characters["guard-2"]==unchanged.state.characters["guard-2"],"lodging leaves time and reserves unchanged")
	# Valid smaller party; long names and a larger presentation projection need scrolling, not overflow.
	var small=before.duplicate(true);small.state.selected=["guard","porter"]
	await game.update({"op":"campaign_load","data":small});game.navigate("inn");await settle()
	check(node("InnParty").get_child_count()==2,"inn supports smaller party")
	game.data.campaign.selected=game.roster().map(func(u):return u.id)
	for u in game.data.campaign.roster:u.name="長いキャラクター名".repeat(10)
	game.render();await settle()
	check(node("InnParty").get_child_count()==game.roster().size() and node("InnPartyScroll").get_global_rect().end.x<=root.size.x,"larger long-name roster scrolls within viewport")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
