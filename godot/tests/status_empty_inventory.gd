extends "res://tests/ui_feedback2_20261016.gd"
func run():
	create_timer(70).timeout.connect(func():print("FAIL empty inventory watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1364,1024);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle();var before=await saved()
	game.pages.party_view.open_detail("guard");await settle();game.dialog.window.size=Vector2i(1364,662);await settle()
	await click("PartyFace_archer")
	check(game.pages.party_view.detail_uid=="archer" and game.member_name("archer")=="リノ","Garo to Rino portrait switch reproduces empty inventory")
	var empty=node("StatusOwnedInventory").find_children("*","Label",true,false).filter(func(l):return l.text=="所持品はありません。")[0]
	print("EMPTY label=",empty.get_global_rect()," column=",node("StatusOwnedInventory").get_global_rect())
	check(empty.size.x>=node("StatusOwnedInventory").size.x*.9 and empty.size.y<=60,"empty inventory message uses full column width without vertical character wrapping")
	check(game.dialog.window.size==Vector2i(1364,662),"portrait switching preserves full status size")
	for resolution in [Vector2i(1364,1024),Vector2i(1920,1080)]:
		root.size=resolution;await settle()
		game.pages.party_view.owned_equipment_view.slot="rightHand";game.pages.party_view.refresh_modal();await settle()
		empty=node("StatusOwnedInventory").find_children("*","Label",true,false).filter(func(l):return l.text.contains("この枠に装備できる"))[0]
		check(empty.size.x>=node("StatusOwnedInventory").size.x*.9 and empty.size.y<=100,"filtered empty message spans full column "+str(resolution))
		await click("PartyFace_guard");check(node("OwnedEquipment_potion")!=null,"nonempty owner still renders item grid "+str(resolution))
		await click("PartyFace_archer")
		check(node("OwnedEquipment_potion")==null and game.pages.party_view.detail_uid=="archer","empty owner never inherits previous items "+str(resolution))
	check(await saved()==before,"empty inventory and portrait switching preserve entire save")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
