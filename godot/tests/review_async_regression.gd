extends SceneTree
## Independent-review regressions: obsolete failures, disposed dialogs and primary shop facts.
var game
var probe
var checks=[]
var failures=[]
var q=OS.get_environment("UIUX_REVIEW_EVIDENCE")
const OWNER="character_mirei"
var fresh_save={}
func _initialize():call_deferred("run")
func check(id: String,ok: bool,detail: String):
	checks.append({"id":id,"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+id+" "+detail)
	if not ok:failures.append(id+" "+detail)
func settle():
	for i in range(8):await process_frame
	var deadline=Time.get_ticks_msec()+12000
	while (game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker) and Time.get_ticks_msec()<deadline:await process_frame
func source(location: String="east"):
	var value=fresh_save.duplicate(true);value.state.location=location;return value
func fixture(location: String="east"):
	await game.update({"op":"campaign_load","data":source(location)});game.shop_uid=OWNER;game.shop_slot="rightHand" if location=="east" else "feet";game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
func snapshot():
	await settle();return (await probe.request({"op":"campaign_save"})).data
func text(node: Node)->String:
	var values=[]
	if node is Label or node is Button:values.append(node.text)
	for child in node.get_children():values.append(text(child))
	return "\n".join(values)
func button(caption: String):
	for control in game.find_children("*","Button",true,false):
		if control.text==caption and control.is_visible_in_tree():return control
	return null
func wait_held():
	var deadline=Time.get_ticks_msec()+5000
	while not probe.holding and Time.get_ticks_msec()<deadline:await process_frame
	check("PROBE",probe.holding and probe.held_reply.get("ok",false),"real Node response held before frontend delivery")
func wait_replacement_held(previous_calls: int):
	var deadline=Time.get_ticks_msec()+5000
	while not (probe.holding and probe.calls.size()>previous_calls) and Time.get_ticks_msec()<deadline:await process_frame
	check("PROBE",probe.holding and probe.calls.size()>previous_calls and probe.held_reply.get("ok",false),"latest real comparison is separately held after obsolete reply delivery")
func escape():
	var window=game.dialog.window
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=pressed
		(window if is_instance_valid(window) else root).push_input(event,true);await process_frame
func control(id: String):
	return game.find_child(id,true,false)
func press(id: String):
	var node=control(id)
	check("D01",node is Button and node.is_visible_in_tree() and not node.disabled,"enabled current control: "+id)
	if node is Button and node.is_visible_in_tree() and not node.disabled:node.pressed.emit()
func comparison_text():
	var node=control("ShopComparisonStats")
	return node.text if node!=null else ""
func quote_cases():
	root.size=Vector2i(1920,1080)
	check("D01",root.get_visible_rect().size==Vector2(1920,1080),"async test uses the real FHD viewport")
	for fail in [false,true]:
		for action in ["cancel","product","product_aba","member","member_aba"]:
			await fixture()
			var before=await snapshot()
			var shop=game.pages.shop_view
			probe.hold_reply_action="previewGear";probe.fail_held_reply=fail
			press("Product_spear-wood");await wait_held()
			check("D01",control("ShopComparisonBuy").disabled and comparison_text().contains("読み込み中"),"pending comparison cannot confirm a purchase")
			match action:
				"cancel":press("ShopExit")
				"product":press("Product_staff-wood")
				"product_aba":
					press("Product_staff-wood");press("Product_spear-wood")
				"member":press("RosterMember_character_merina")
				"member_aba":
					for uid in ["character_merina","character_yuno",OWNER]:
						press("RosterMember_"+uid)
			if action!="cancel":
				check("D01",control("ShopComparisonBuy").disabled and not game.modal_open(),"replacement cannot use the held comparison to confirm")
				var previous_calls=probe.calls.size()
				probe.hold_reply_action="previewGear";probe.release=true
				await wait_replacement_held(previous_calls)
				check("D01",control("ShopComparisonBuy").disabled and control("ShopComparisonStats").is_visible_in_tree() and comparison_text().contains("読み込み中") and not game.modal_open(),"delivered obsolete reply cannot populate or enable comparison while latest reply is held")
				check("D01",probe.calls.slice(previous_calls).all(func(call):return call.get("action","")!="purchaseQuote"),"obsolete comparison cannot advance to a purchase quote")
			probe.release=true;await settle()
			if action=="cancel":
				check("D01",control("ShopComparisonBuy")==null and not game.modal_open() and shop.selection_kind.is_empty(),"cancelled comparison cannot return after stale "+str(fail))
			else:
				var wanted="staff-wood" if action=="product" else "spear-wood"
				var owner="character_merina" if action=="member" else OWNER
				var expected=(await probe.request({"op":"campaign","action":"previewGear","args":[owner,wanted,"rightHand"]})).previewGear
				var rendered=shop.comparison_view.comparison_text(game.roster().filter(func(u):return u.id==owner)[0],{"name":expected.gear.name,"equipSlots":[]},"rightHand",expected).replace("#8ee6ab","#277242").replace("#ffb1a6","#a84432").replace("#d5dbe2","#6e786f")
				check("D01",shop.comparison_view.item_id==wanted and shop.comparison_view.owner_id==owner and comparison_text()==rendered and not control("ShopComparisonBuy").disabled and not game.modal_open(),action+" ignores stale "+("failure" if fail else "success")+" and completes only the latest canonical comparison")
				for i in range(2):
					var panel=shop.comparison_view.panels[i]
					check("D01",panel.is_visible_in_tree() and text(panel).contains(str(expected.get("current" if i==0 else "gear",{}).get("name","なし"))),"visible inline equipment matches latest canonical reply, column "+str(i))
					for stat in shop.comparison_view.stat_changes(game.roster().filter(func(u):return u.id==owner)[0],expected):
						check("D01",text(panel).contains("%s　%d" % [stat[0],stat[i+1]]),"visible latest comparison statistic: "+str(stat[0])+", column "+str(i))
				press("ShopComparisonBuy");await settle()
				check("D01",game.modal_open() and control("PurchaseDecline")!=null,"only latest comparison opens current purchase confirmation")
				var quotes=probe.calls.filter(func(call):return call.get("action","")=="purchaseQuote")
				check("D01",not quotes.is_empty() and quotes[-1].args[0]==wanted and quotes[-1].args[1]==owner and text(game.dialog.body).contains(expected.gear.name) and text(game.dialog.body).contains(game.member_name(owner)),"purchase confirmation uses latest product and recipient, not the obsolete reply")
				press("PurchaseDecline");await settle()
			check("D01",await snapshot()==before,"stale comparison sequence preserves complete campaign")
	await fixture()
	var before=await snapshot()
	probe.hold_reply_action="previewGear";probe.fail_held_reply=true
	press("Product_spear-wood");await wait_held();probe.release=true;await settle()
	check("D01",control("ShopComparisonStats").is_visible_in_tree() and comparison_text().contains("比較を取得できません") and control("ShopComparisonBuy").disabled,"current ordinary comparison failure is visible and cannot confirm")
	check("D01",await snapshot()==before,"current failed comparison preserves complete campaign")
	press("Product_staff-wood");await settle()
	check("D01",not control("ShopComparisonBuy").disabled,"fresh selection recovers after ordinary comparison failure")
	check("D01",probe.calls.all(func(call):return call.get("action","") not in ["buyInventory","buyItem","buyGear","inventoryAction","sellInventory","useItem"]),"quote failure and cancellation never submit an economic mutation")
func reference_case(which: String,exit_mode: String,fail:=false):
	await fixture();await game.act("depart",["astaris","convoy"]);await game.act("travel",["safe"]);await game.act("begin",[]);await settle()
	game.choose_command("action_move");await game.on_cell(int(game.data.choices.action_move[0]));await settle()
	var before=await snapshot();var destination=game.pending;var original=game.preview.duplicate(true);var epoch=game.pages.epoch
	game.hud.open_range_reference();await settle();var old_body=game.hud.target_box
	probe.hold_reply_action="preview";probe.fail_held_reply=fail
	button("通常攻撃の参考" if which=="attack" else "スキルの参考").pressed.emit();await wait_held()
	check("D02",game.hud.reference_pending and game.hud.reference_preview.ranges.is_empty() and game.preview==original and game.board.ghost.visible and not game.can_commit(),"pending reference retains ghost, clears obsolete ranges and cannot execute")
	match exit_mode:
		"close":game.hud.close_reference()
		"escape":await escape()
		"reopen":game.hud.close_reference();game.hud.open_range_reference()
		"new":game.new_game()
		"load":game.update({"op":"campaign_load","data":source("west")})
	for i in range(4):await process_frame
	if exit_mode in ["close","escape","reopen"]:check("D02",not is_instance_valid(old_body),"closed detail body was actually freed before reply release")
	probe.release=true;await settle()
	if exit_mode in ["new","load"]:
		check("D02",game.pages.epoch>epoch and game.pending==null and not is_instance_valid(game.dialog.window),which+" / "+exit_mode+" discards old dialog and preview continuation")
		if exit_mode=="load":check("D02",game.campaign().location=="west","load resumes with the requested canonical campaign")
	else:
		check("D02",game.pending==destination and game.preview==original and game.preview_ready,which+" / "+exit_mode+" / "+str(fail)+" preserves original movement decision")
		check("D02",game.hud.range_reference==(exit_mode=="reopen") and game.can_commit()==(exit_mode!="reopen"),"only the active reference controls confirmation availability")
		check("D02",await snapshot()==before,"abandoned reference never consumes or changes canonical state")
		if exit_mode=="reopen":
			check("D02",game.hud.reference_preview==original and not game.hud.reference_pending,"old success or failure cannot change the newly opened reference")
			game.hud.close_reference();await settle()
func shop_facts():
	root.size=Vector2i(1920,1080);await fixture();press("Product_staff-wood");await settle()
	var chosen=control("Product_staff-wood");var other=control("Product_spear-wood")
	control("ShopComparisonSlot").grab_focus()
	check("UX-SELECT",chosen.get_meta("selected",false) and chosen.has_theme_stylebox_override("normal") and chosen.get_theme_stylebox("normal").border_width_left==2 and not other.get_meta("selected",false) and control("ShopComparisonProduct").text==chosen.tooltip_text,"selection has a persistent product title, border and background independent of focus")
	press("ComparisonSkill_追加_skill_heal_1");await settle();press("SkillDetailsBack");await settle()
	check("UX-SELECT",control("Product_staff-wood").get_meta("selected",false) and control("ShopComparisonProduct").text==chosen.tooltip_text,"detail return retains the selected product marker")
	press("Product_spear-wood");await settle()
	check("UX-SELECT",not control("Product_staff-wood").get_meta("selected",false) and control("Product_spear-wood").get_meta("selected",false),"reselection moves the marker to exactly the current candidate")
	press("ShopExit");await settle()
	check("UX-SELECT",control("ShopComparisonProduct")==null and control("ShopComparisonBuy")==null,"leaving trade removes the active comparison and its confirmation")
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;await fixture("west");var before=await snapshot();press("Product_swift-boots");await settle()
		var gear=game.campaign().shop.filter(func(item):return item.id=="swift-boots")[0]
		var doc=preload("res://skill_text.gd").document("skill_swift",game.campaign().skillNames.skill_swift,1,game.campaign(),gear)
		var description=preload("res://skill_text.gd").plain(doc)
		var effects=game.find_children("ComparisonSkill_追加_skill_swift_*","Button",true,false)
		check("UX-SWIFT",effects.size()==1 and effects[0].tooltip_text.contains(description),"comparison exposes the canonical movement effect and stacking conditions")
		press("ComparisonSkill_追加_skill_swift_1");await settle()
		check("UX-SWIFT",text(control("SkillDetailsWindow")).contains("通常移動力+1"),"comparison skill opens the full movement benefit explanation")
		press("SkillDetailsBack");await settle()
		var pane=control("ShopTransactionScroll")
		check("UX-SWIFT",pane.get_v_scroll_bar().max_value<=pane.get_v_scroll_bar().page+1,"representative swift effect needs no comparison scrolling at "+str(dims))
		press("ShopComparisonBuy");await settle()
		check("UX-SWIFT",control("PurchasePayment")!=null and text(game.dialog.window).contains(game.member_name(OWNER)) and control("ShopComparisonProduct").is_visible_in_tree() and effects[0].is_visible_in_tree(),"final confirmation identifies payment and recipient while retaining the movement comparison")
		game.dialog.close();await settle();check("UX-SWIFT",await snapshot()==before,"effect explanation and cancellation change no resources")
func run():
	create_timer(180).timeout.connect(func():print("FAIL review async watchdog");quit(2))
	if q.is_empty():q="user://review-async"
	DirAccess.make_dir_recursive_absolute(q.path_join("reports"));root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	game.engine.close_engine();game.engine.queue_free();probe=load("res://tests/v2_bridge_probe.gd").new();game.add_child(probe);game.engine=probe;probe.start_engine();await game.new_game();await settle()
	fresh_save=(await probe.request({"op":"campaign_save"})).data
	fresh_save.state.gold=1000
	await quote_cases()
	for which in ["attack","skill"]:
		for exit_mode in ["close","escape","reopen","new","load"]:await reference_case(which,exit_mode)
		await reference_case(which,"close",true)
	await shop_facts()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"method":"FHD current controls; real Node replies held by test-only transport subclass","gui":DisplayServer.get_name()!="headless","viewport":str(root.size)}
	var f=FileAccess.open(q.path_join("reports/review-async.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print("REVIEW ASYNC ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();probe.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
