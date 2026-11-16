extends "res://tests/ui_feedback2_20261016.gd"
func pointer_click(control):
	var point=control.get_global_rect().get_center()
	var motion_=InputEventMouseMotion.new();motion_.position=point;motion_.global_position=point;root.push_input(motion_,true);await frames(2)
	for pressed in [true,false]:
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;e.position=point;e.global_position=point;root.push_input(e,true);await frames(2)
	await settle()
func green(control):return control.get_theme_stylebox("normal").bg_color.is_equal_approx(Color("#236044"))
func return_layout(id):
	var back=node(id)
	var expected="取引終了" if id=="ShopExit" else "掲示板" if id=="Header_board" else "戻る"
	check(back!=null and back.is_visible_in_tree() and back.text==expected and not back.disabled and not game.town_back.visible,"one available return control "+id)
	if back==null:return
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(back.get_global_rect()),"return remains inside viewport "+id)
	check(game.find_children("*","Button",true,false).filter(func(b):return b.is_visible_in_tree() and b.text==expected).size()==1,"no duplicate service return "+id)
func run():
	create_timer(90).timeout.connect(func():print("FAIL feedback2 watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var before=await saved();await enter_facility("party");await settle()
	return_layout("GuildReturn")
	var member=str(game.campaign().selected[0]);var mage="character_merina";var porter="character_yuno"
	var reserve=str(game.roster().filter(func(u):return not game.campaign().selected.has(u.id))[0].id)
	await click("RosterMember_"+member)
	check(not game.modal_open() and game.pages.guild_view.current_id==member,"first guild click selects without opening or changing state")
	await click("RosterMember_"+member)
	check(not game.modal_open() and game.pages.guild_view.current_id==member and await saved()==before,"repeat current-member selection preserves full campaign")
	await click("GuildTab_1");check(game.pages.guild_view.detail_tab==1 and not game.modal_open(),"guild equipment detail tab opens inline")
	game.pages.guild_view.cancel_selection();await settle()
	await click("GuildMember_"+reserve);await click("GuildMember_"+reserve)
	check(not game.modal_open() and game.pages.guild_view.chosen_id==reserve and not game.active_member(reserve),"reserve repeat selection stays inline without changing composition")
	check(await saved()==before,"reserve and inline tab selection preserve the full campaign")
	await pointer_click(node("GuildReturn"))
	check(game.page=="party" and node("FacilityChoice_guild")!=null,"guild return accepts viewport pointer click and restores service entry")
	await enter_facility("inn");await settle();return_layout("InnReturn")
	check(node("InnParty").get_child_count()==game.campaign().selected.size(),"inn card count follows active party")
	check(node("InnParty").find_children("*","Button",true,false).is_empty(),"inn cards have no inventory buttons")
	check(node("InnStay").size.x<root.size.x/2 and green(node("InnStay")) and node("InnStay").disabled,"compact green stay control disables unnecessary paid rest")
	var full_before=await saved();await pointer_click(node("InnStay"))
	check(await saved()==full_before and node("InnKeeperSpeech").words.text==game.pages.inn_view.FULL_GREETING and game.pages.inn_view.recovered.is_empty(),"full-health stay uses free greeting without recovery")
	for id in game.campaign().selected:
		check(node("InnPortrait_"+id).texture!=null and node("InnHP_"+id).text.contains("HP ") and node("InnMP_"+id).text.contains("MP "),"portrait HP MP card "+id)
	await pointer_click(node("InnReturn"));check(game.page=="inn" and node("FacilityChoice_inn")!=null,"inn return accepts viewport pointer click and restores service entry")
	# Valid injured-party save; lodging rules remain the existing API's responsibility.
	var injured=before.duplicate(true);injured.state.characters[member].hp=0;injured.state.characters[mage].mp=0
	await game.update({"op":"campaign_load","data":injured});await enter_facility("inn");await settle()
	check(not node("InnStay").disabled and node("InnHP_"+member).text.begins_with("HP 0 →"),"injured/KO party enables lodging")
	var unchanged=await saved();await click("InnStay")
	var d=game.find_children("*","ConfirmationDialog",true,false).filter(func(w):return w.visible)[0];d.canceled.emit();await settle()
	check(await saved()==unchanged,"lodging cancel preserves all state")
	await click("InnStay");d=game.find_children("*","ConfirmationDialog",true,false).filter(func(w):return w.visible)[0];d.confirmed.emit();d.confirmed.emit();await settle()
	var after=await saved();check(after.state.gold==unchanged.state.gold-30 and after.state.characters[member].hp==game.roster().filter(func(u):return u.id==member)[0].max and after.state.characters[mage].mp==game.roster().filter(func(u):return u.id==mage)[0].maxMp,"lodging charges once and heals existing HP/MP")
	check(after.state.hours==unchanged.state.hours and after.state.characters[reserve]==unchanged.state.characters[reserve],"lodging leaves time and reserves unchanged")
	# Valid smaller party; long names and a larger presentation projection need scrolling, not overflow.
	var small=before.duplicate(true);small.state.selected=[member,porter]
	await game.update({"op":"campaign_load","data":small});await enter_facility("inn");await settle()
	check(node("InnParty").get_child_count()==2,"inn supports smaller party")
	game.data.campaign.selected=game.roster().map(func(u):return u.id)
	for u in game.data.campaign.roster:u.name="長いキャラクター名".repeat(10)
	game.render();await settle()
	check(node("InnParty").get_child_count()==game.roster().size() and node("InnPartyScroll").get_global_rect().end.x<=root.size.x,"larger long-name roster scrolls within viewport")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
