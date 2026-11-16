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
	await preload("res://tests/ui_current_fixture.gd").install(game)
	var before=(await game.engine.request({"op":"campaign_save"})).data
	game.pages.party_view.open_inventory("character_mirei");await frames()
	# Use view-only copies of a real entry so the normal inventory renderer supplies the rows.
	var inventory=game.campaign().inventoryByCharacter["character_mirei"]
	var original=inventory.entries[0]
	var items=[]
	for i in range(80):
		var item=original.duplicate(true)
		if i%2==0:
			item.kind="quest"
			item.id="stress-"+str(i)
		else:
			item.kind="equipment"
			item.type="sword"
			item.id="stress-sword-"+str(i)
		item.name="長い表示名・性能の確認用".repeat(8)+str(i)
		items.append(item)
	inventory.entries=items
	game.render();await frames()
	var rows=game.find_children("*","Button",true,false).filter(func(b):return b.tooltip_text.begins_with("長い表示名"))
	check(rows.size()==80,"S4/S5 character inventory renders all eighty entries")
	if rows.size()==80:
		var last=rows.back()
		var scroll=last.get_parent()
		while scroll!=null and not scroll is ScrollContainer:scroll=scroll.get_parent()
		check(scroll!=null and scroll.get_v_scroll_bar().max_value>scroll.size.y,"S7 long inventory scrolls")
		if scroll!=null:
			scroll.ensure_control_visible(last);await frames()
			check(scroll.get_global_rect().intersects(last.get_global_rect()),"S7 last inventory entry reachable")
		check(last.alignment==HORIZONTAL_ALIGNMENT_LEFT and last.clip_text and last.tooltip_text==items.back().name,"S4 clipped long names retain the full tooltip")
	var roster=game.data.campaign.roster;var selected=game.data.campaign.selected
	for i in range(7):
		var member=roster[0].duplicate(true);member.id="extra-"+str(i);member.name="追加表示"+str(i);roster.append(member);selected.append(member.id)
	check(game.visible_roster().size()>5,"S7 view identity supports roster larger than five without changing rules")
	check((await game.engine.request({"op":"campaign_save"})).data==before,"stress presentation changes never mutate engine state")
	var f=FileAccess.open(evidence.path_join("inventory-stress.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
