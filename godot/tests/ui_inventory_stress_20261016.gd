extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func frames(n:=12):
	for i in range(n):await process_frame
func run():
	var evidence=OS.get_environment("INVENTORY_QA_ROOT")
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	var before=(await game.engine.request({"op":"campaign_save"})).data
	# View-only synthetic stress data, never sent to the rules engine or saved.
	var entry=game.campaign().inventoryByCharacter.guard.entries[0].duplicate(true)
	var items=[]
	for i in range(80):
		var item=entry.duplicate(true);item.id="stress-"+str(i);item.name="長い表示名・性能の確認用".repeat(8)+str(i);items.append(item)
	game.data.campaign.inventoryByCharacter.guard.entries=items
	var p=game.pages.party_view;p.open_detail("guard");p.detail_tab=3;p.refresh_modal();await frames()
	check(game.find_children("InventoryItem_stress-*","Button",true,false).size()==80,"S4/S5 eighty mixed entries render without hardcoded item count")
	check(game.dialog.body.get_parent().get_v_scroll_bar().max_value>game.dialog.body.get_parent().size.y,"S7 many items scroll instead of shrinking text")
	var button=game.find_child("InventoryItem_stress-79",true,false)
	check(button.alignment==HORIZONTAL_ALIGNMENT_LEFT and button.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"S4 long item names wrap left-aligned")
	var hover=preload("res://hover_comparison.gd").new();hover.ui=game;game.dialog.window.add_child(hover);hover.show_for(button,true);hover.content.text="長いスキル名・性能説明".repeat(200);await frames()
	var bounds=Rect2(Vector2.ZERO,Vector2(root.size))
	check(bounds.encloses(Rect2(Vector2(hover.position),Vector2(hover.size))),"S5/S9 long hover content stays inside root viewport")
	check(hover.content.get_parent().get_v_scroll_bar().max_value>hover.size.y,"S5 long hover content is scrollable")
	game.dialog.window.size=Vector2i(700,600);await frames();hover.place();await frames()
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(hover.position),Vector2(hover.size))),"S5 hover remains bounded after window resize")
	var roster=game.data.campaign.roster;var selected=game.data.campaign.selected
	for i in range(7):
		var member=roster[0].duplicate(true);member.id="extra-"+str(i);member.name="追加表示"+str(i);roster.append(member);selected.append(member.id)
	check(game.visible_roster().size()>5,"S7 view identity supports roster larger than five without changing rules")
	check((await game.engine.request({"op":"campaign_save"})).data==before,"stress presentation changes never mutate engine state")
	var f=FileAccess.open(evidence.path_join("inventory-stress.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
