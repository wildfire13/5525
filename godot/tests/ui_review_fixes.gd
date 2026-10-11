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
func record(id: String,scope: Node):
	var icons=[]
	for n in scope.find_children("*","Control",true,false):
		if n.has_meta("ui_icon_id") and n.is_visible_in_tree():
			var rect=n.get_global_rect()
			icons.append({"id":n.get_meta("ui_icon_id"),"node":str(n.get_path()),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"inside_viewport":root.get_visible_rect().encloses(rect)})
	records.append({"id":id,"viewport":[root.size.x,root.size.y],"phase":game.campaign().phase,"page":game.page,"location":game.campaign().location,"icons":icons,"text":text(scope),"pixels_captured":false})
func item_cases():
	for dims in [Vector2i(1920,1080),Vector2i(800,600)]:
		root.size=dims
		for context in [["camp","board",""],["camp","items",""],["town","items",""],["town","shop","south"]]:
			await restore(context[0],context[1],context[2]);var before=await snapshot()
			for stage in ["entry","list","target"]:
				game.pages.show_items(stage,"potion" if stage=="target" else "");await settle()
				var bar=node("PartyFaceBar");var party=node("CampParty") if context[0]=="camp" else node("ItemParty")
				var label="UX01 "+str(dims)+" "+str(context)+" "+stage
				check(bar!=null and bar.get_child_count()==5 and not text(bar).contains("HP") and not text(bar).contains("MP"),label+" detail bar has no duplicate resource list")
				check(party!=null and party.find_children("FullBodyPortrait","TextureRect",true,false).size()==5 and text(party).contains("HP %d/" % before.state.characters.guard.hp) and text(party).contains("MP %d/" % before.state.characters.guard.mp),label+" full-body targets retain resources")
				check(node("PartyFace_mage").text.contains("戦闘不能"),label+" detail bar retains KO")
				check(root.get_visible_rect().encloses(bar.get_global_rect()),label+" persistent entry remains in viewport")
				if dims.x==1920:record("Q01-"+context[0]+"-"+context[1]+"-"+stage,game.content)
			check(await snapshot()==before,"UX01 browsing all item stages is free")
			node("PartyFace_guard").pressed.emit();await settle()
			check(game.pages.party_view.detail_uid=="guard" and game.modal_open() and await snapshot()==before,"UX01 face opens correct detail without using an item")
			game.dialog.close();await settle()
			check(game.page==context[1] and game.pages.item_stage=="target" and node("ItemTarget_guard")!=null,"UX01 detail closes to original item target stage")
			if context[0]=="camp":
				node("ItemTarget_guard").pressed.emit();await settle();var used=await snapshot()
				check(used.state.characters.guard.hp==before.state.characters.guard.hp+55 and used.state.inventory.potion==before.state.inventory.potion-1,"UX01 full-body Use retains original heal and cost")
	root.size=Vector2i(1920,1080)
	for context in ["town","road","north_travel"]:
		await restore(context);check(text(node("PartyFaceBar")).contains("HP") and text(node("PartyFaceBar")).contains("MP"),"UX01 only resource overview remains on "+context)
	await restore("four","items");check(node("PartyFaceBar").get_child_count()==4 and node("ItemParty").get_child_count()==4,"UX01 four-person party keeps both entry and targets")
func result_cases():
	for id in ["north_delivery","north_travel","east_travel","west_travel","south_travel","astaris_travel"]:
		await restore(id);var before=await snapshot();var shortcut=node("ResultShop")
		if id=="astaris_travel":check(shortcut==null and text(game.content).contains("アスタリスの宿屋へ"),"UX02 city keeps inn shortcut");continue
		check(shortcut!=null and not shortcut.disabled,"UX02 result uses facility metadata: "+id)
		if id.begins_with("north"):
			check(shortcut.text=="ノースの装飾品店へ","UX02 North identifies accessory shop")
			record("Q02-"+id+"-result",game.content)
		var old_uid=game.shop_uid;var old_slot=game.shop_slot
		shortcut.pressed.emit();shortcut.pressed.emit();await settle()
		var after=await snapshot()
		check(game.campaign().phase=="town" and game.page=="shop" and after.state.location==before.state.location and after.state.result==null,"UX02 shortcut acknowledges and opens destination shop: "+id)
		check(after.state.gold==before.state.gold and after.state.characters==before.state.characters and after.state.completed==before.state.completed and after.state.hours==before.state.hours and after.state.boardRound==before.state.boardRound,"UX02 repeated click acknowledges once without duplicate rewards: "+id)
		await game.update({"op":"campaign_load","data":after});await settle()
		check(await snapshot()==after,"UX02 shop transition round-trips through save/load: "+id)
		if id.begins_with("north"):
			check(game.pages.shop_view.slots()==["accessory1","accessory2"] and game.pages.offered().all(func(g):return g.slot==game.shop_slot) and game.shop_uid==old_uid,"UX02 North retains person and uses accessory slot")
			record("Q02-"+id+"-shop",game.content)
func icon_case(id: String,ids: Array):
	await settle();record(id,game.content)
	var actual=records[-1].icons.map(func(item):return item.id)
	for icon in ids:check(actual.has(icon),"EV01 live UI node "+id+" has "+icon)
func icon_cases():
	await restore("town","inn");await icon_case("Q04-inn",["inn"])
	await restore("town","shop","south");await icon_case("Q04-consumable-shop",["potion","ether"])
	await restore("town","board","east");check(game.campaign().board.size()==3,"Q04 village has three destination offers");record("Q04-village-board",game.content)
	await restore("town","shop","north");await game.pages.shop_view.select_slot("accessory2");await settle();check(game.pages.offered().all(func(g):return g.slot=="accessory2"),"Q04 accessory2 excludes opposite slot products");record("Q04-accessory2",game.content)
	await restore("town","shop","east");await game.pages.shop_view.select_slot("rightHand");await settle();record("Q04-weapon-shop",game.content)
	await restore("heal_left");var before=await snapshot();await game.choose_command("skill");await game.on_cell(24);await icon_case("Q03-healing",["hp","mp","healing"]);check(await snapshot()==before,"EV01 heal prediction does not consume")
	await restore("guard");before=await snapshot();await game.choose_command("guard");await icon_case("Q03-defense",["defense_up"]);check(await snapshot()==before,"EV01 defense prediction does not consume")
	await restore("porter");before=await snapshot();await game.choose_command("skill");await icon_case("Q03-formation",["skill","attack_up","defense_up"]);check(await snapshot()==before,"EV01 boost prediction does not consume")
	await restore("town","shop","east");await game.act("trial",["archer","twin-bow","rightHand"]);await game.choose_command("skill");await settle()
	var pair=game.data.choices.skill[0]
	for uid in pair:
		for unit in game.state().units:
			if unit.id==uid:await game.on_cell(int(unit.pos));break
	await icon_case("Q03-multiple-damage",["damage"]);check(game.preview.damagePreview.size()==2 and game.can_commit(),"Q03 real two-target prediction remains available")
	await game.act("endTrial",[]);await restore("town","shop","north");await game.act("trial",["guard","return-ring-1","accessory1"]);await game.choose_command("skill");await game.select_skill("returnHome");await game.on_cell(0);await settle();record("Q03-return",game.content)
	check(game.command=="return" and game.can_commit() and text(game.content).contains("MP0"),"Q03 return stays available through skills at zero MP cost")
func run():
	if evidence.is_empty():evidence=ProjectSettings.globalize_path("user://ui-review-fixes")
	var output=[];var executable=OS.get_environment("NATIVE5525_NODE");if executable.is_empty():executable="node"
	var code=OS.execute(executable,PackedStringArray([ProjectSettings.globalize_path("res://tests/ui_review_fixes_fixtures.cjs")]),output,false,false);fixtures=JSON.parse_string("".join(output))
	if code!=0 or not fixtures is Dictionary:print(output);quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await item_cases();await result_cases();await icon_cases()
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));var f=FileAccess.open(evidence.path_join("reports/ui-review-fixes.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records,"gui":false,"input":"Godot button signals and application callbacks; no OS input","visual_acceptance":"not performed; desktop held by independent debugger","fixture_note":"result fixtures force battle victory to reach UI; not combat evidence"},"  "));f.close()
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await settle();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	print("UI REVIEW FIXES ",checks.size()," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
