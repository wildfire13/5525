extends SceneTree
## Independent-review regressions: obsolete failures, disposed dialogs and primary shop facts.
var game
var probe
var checks=[]
var failures=[]
var q=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func check(id: String,ok: bool,detail: String):
	checks.append({"id":id,"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+id+" "+detail)
	if not ok:failures.append(id+" "+detail)
func settle():
	for i in range(8):await process_frame
	var deadline=Time.get_ticks_msec()+12000
	while (game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker) and Time.get_ticks_msec()<deadline:await process_frame
func source(location: String="east"):
	var value=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/synthetic-east.json"));value.state.location=location;return value
func fixture(location: String="east"):
	await game.update({"op":"campaign_load","data":source(location)});game.shop_uid="guard";game.shop_slot="rightHand" if location=="east" else "feet";game.navigate("shop");await settle()
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
func escape():
	var window=game.dialog.window
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=pressed
		(window if is_instance_valid(window) else root).push_input(event,true);await process_frame
func quote_cases():
	for fail in [false,true]:
		for action in ["cancel","product","member_aba"]:
			await fixture();var before=await snapshot();game.pages.cached_quotes.clear();probe.hold_reply_action="previewGear";probe.fail_held_reply=fail
			game.pages.shop_view.select_product("spear-wood");await wait_held()
			check("D01",game.pages.shop_view.stage=="S1" and game.pages.quote_pending,"waiting quote has no completed comparison")
			match action:
				"cancel":game.pages.shop_view.back_list()
				"product":game.pages.shop_view.select_product("staff-wood")
				"member_aba":
					for member in ["archer","porter","guard"]:game.pages.shop_view.select_member(member)
			probe.release=true;await settle()
			var correct=game.pages.shop_view.stage=="S0" and game.gear_preview.is_empty() if action=="cancel" else game.pages.shop_view.stage=="S2" and game.pages.quote_valid() and game.gear_preview.gearId==("staff-wood" if action=="product" else "spear-wood") and game.gear_preview.characterId=="guard"
			check("D01",correct and not game.pages.quote_pending and game.pages.shop_view.selected_request.is_empty(),action+" / obsolete "+("failure" if fail else "success")+" cannot replace latest state or stop its request")
			check("D01",await snapshot()==before,"stale quote handling leaves the canonical campaign unchanged")
	await fixture();game.pages.cached_quotes.clear();probe.hold_reply_action="previewGear";probe.fail_held_reply=true
	game.pages.shop_view.select_product("spear-wood");await wait_held();probe.release=true;await settle()
	check("D01",game.pages.shop_view.stage=="S7" and game.pages.shop_view.error_text.contains("delayed_quote_failure"),"current known failure is still displayed")
	await fixture();game.pages.cached_quotes.clear();probe.hold_reply_action="previewGear";probe.disconnect_held_reply=true
	game.pages.shop_view.select_product("spear-wood");await wait_held();game.pages.shop_view.back_list();probe.release=true;await settle()
	check("D01",probe.disconnected and game.pages.shop_view.stage=="S7" and game.retry_button.visible and not game.pages.quote_pending,"connection-wide failure stays visible after quote cancellation")
	await game.reconnect_engine();await settle()
func reference_case(which: String,exit_mode: String,fail:=false):
	await fixture();await game.act("depart",["astaris","convoy"]);await game.act("travel",["safe"]);await game.act("begin",[]);await settle()
	game.choose_command("move");await game.on_cell(int(game.data.choices.move[0]));await settle()
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
	root.size=Vector2i(1280,800);await fixture();await game.preview_gear("spear-wood");await settle()
	var chosen=game.find_child("Product_spear-wood",true,false);var other=game.find_child("Product_staff-wood",true,false)
	check("UX-SELECT",chosen.get_meta("product_selected",false) and text(chosen).contains("選択中") and chosen.has_theme_stylebox_override("normal") and not other.get_meta("product_selected",false),"selection has a persistent label, border and background independent of focus")
	button("全性能・説明").grab_focus();game.pages.shop_view.open_details();await settle();game.dialog.close();await settle()
	check("UX-SELECT",text(game.find_child("Product_spear-wood",true,false)).contains("選択中"),"detail return retains the selected product marker")
	await game.preview_gear("staff-wood");await settle()
	check("UX-SELECT",not game.find_child("Product_spear-wood",true,false).get_meta("product_selected",false) and game.find_child("Product_staff-wood",true,false).get_meta("product_selected",false),"reselection moves the marker to exactly the current candidate")
	game.pages.shop_view.back_list();await settle();check("UX-SELECT",not game.find_child("Product_staff-wood",true,false).get_meta("product_selected",false),"list-only state does not pretend a comparison is still active")
	for dims in [Vector2i(800,600),Vector2i(1280,800)]:
		root.size=dims;await fixture("west");var before=await snapshot();await game.preview_gear("swift-boots");await settle()
		var description=str(game.campaign().skillDefinitions.swift.description)
		check("UX-SWIFT",text(game.content).contains("通常移動力+1") and text(game.content).contains(description),"comparison directly shows the canonical movement effect and stacking conditions")
		var pane=game.find_child("ShopComparisonScroll",true,false)
		check("UX-SWIFT",pane.get_v_scroll_bar().max_value<=pane.get_v_scroll_bar().page+1,"representative swift effect needs no comparison scrolling at "+str(dims))
		game.pages.shop_view.confirm_purchase();await settle()
		check("UX-SWIFT",text(game.dialog.window).contains("通常移動力+1") and text(game.dialog.window).contains(description),"final confirmation shows the movement benefit without opening details")
		game.dialog.close();await settle();check("UX-SWIFT",await snapshot()==before,"effect explanation and cancellation change no resources")
func run():
	if q.is_empty():q="user://review-async"
	DirAccess.make_dir_recursive_absolute(q.path_join("reports"));root.size=Vector2i(1280,800)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	game.engine.close_engine();game.engine.queue_free();probe=load("res://tests/v2_bridge_probe.gd").new();game.add_child(probe);game.engine=probe;probe.start_engine();await game.new_game();await settle()
	await quote_cases()
	for which in ["attack","skill"]:
		for exit_mode in ["close","escape","reopen","new","load"]:await reference_case(which,exit_mode)
		await reference_case(which,"close",true)
	await shop_facts()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"method":"headless real Node replies held by test-only transport subclass; script error markers checked by check.py","gui":false}
	var f=FileAccess.open(q.path_join("reports/review-async.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print("REVIEW ASYNC ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();probe.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
