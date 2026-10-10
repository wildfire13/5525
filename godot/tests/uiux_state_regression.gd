extends SceneTree
var game
var checks=[]
var failures=[]
var q=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func check(id: String,ok: bool,detail: String,extra: Dictionary={}):
	checks.append({"id":id,"passed":ok,"detail":detail,"size":[root.size.x,root.size.y],"extra":extra})
	if not ok:failures.append(id+" "+detail)
	print(("PASS " if ok else "FAIL ")+id+" "+detail)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker:await process_frame
func snapshot():
	await settle();return (await game.engine.request({"op":"campaign_save"})).data
func pane():return game.find_child("ShopComparisonScroll",true,false)
func text(node: Node)->String:
	var out=[]
	if node is Label or node is Button:out.append(node.text)
	for child in node.get_children():out.append(text(child))
	return "\n".join(out)
func fixture():
	await game.update({"op":"campaign_load","data":JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/synthetic-east.json"))})
	game.shop_uid="guard";game.shop_slot="rightHand";game.navigate("shop");await settle()
func run():
	if q.is_empty():q="user://uiux-state-regression"
	DirAccess.make_dir_recursive_absolute(q.path_join("reports"))
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	for dims in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1024,720)]:
		root.size=dims;await fixture();var before=await snapshot()
		for pair in [["rightHand","spear-wood"],["leftHand","javelin-wood"]]:
			await game.pages.select_slot(pair[0]);await game.preview_gear(pair[1]);await settle()
			# Display-only synthetic many-effect quote exercises scroll anchors; never submitted.
			var canonical=game.gear_preview.duplicate(true)
			for i in range(30):game.gear_preview.after.effects.append("表示試験の長い効果説明 "+str(i))
			game.render();await settle()
			for cycle in range(3):
				pane().scroll_vertical=200+cycle*180;await settle();var y=pane().scroll_vertical
				check("N01",y>0,"synthetic long comparison reaches a scrolled position")
				game.pages.shop_view.confirm_purchase();await settle()
				check("N01",is_instance_valid(game.dialog.window),"confirmation opens without changing selected context")
				game.dialog.close();await settle()
				check("N01",pane().scroll_vertical==y and game.pages.gear_id==pair[1] and game.shop_slot==pair[0] and await snapshot()==before,"cancel restores comparison offset/member/slot and exact campaign")
				var message="操作説明 "+"長い文を繰り返して全文の保持を確認します。".repeat(20)
				game.set_status(message);game.show_status_details();await settle()
				var popup=game.find_child("StatusDetails",true,false)
				check("N02",popup!=null and text(popup).contains(message),"reopened full explanation preserves exact source text")
				popup.hide();await settle();root.size=dims+Vector2i(2,2);await settle();root.size=dims;await settle()
				check("C01",str(game.footer.get_meta("full_message",""))==message,"closing full explanation then resize retains source")
				check("N02",pane().scroll_vertical==y and await snapshot()==before,"full explanation never shifts comparison or mutates campaign",{"before_y":y,"after_y":pane().scroll_vertical,"memory":game.memory.scrolls.get("shop_compare",{})})
			game.gear_preview=canonical;game.memory.scrolls.erase("shop_compare");game.skip_capture_once=true;game.render();await settle()
			var original=game.memory.scrolls.duplicate(true)
			await game.pages.start_trial();await settle();game.choose_command("guard");await game.commit();await settle();await game.act("endTrial",[]);await settle()
			check("TRANSITION",game.pages.shop_view.stage=="S2" and game.pages.gear_id==pair[1] and game.shop_slot==pair[0] and await snapshot()==before,"trial restores member/slot/product and exact resources")
			game.pages.cancel_quote();await settle();check("TRANSITION",game.pages.shop_view.stage=="S0" and game.gear_preview.is_empty(),"close comparison returns product list")
			await game.preview_gear(pair[1]);await settle();check("TRANSITION",pane().scroll_vertical==0,"new selection starts comparison at top")
		game.show_status_details();await settle();var old=game.find_child("StatusDetails",true,false);await fixture();var message=str(game.footer.get_meta("full_message",""))
		if is_instance_valid(old):old.hide()
		await settle();check("N02",str(game.footer.get_meta("full_message",""))==message,"new campaign prevents stale modal restoration")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"input":"Godot callbacks and synthetic display-only long quote; no OS input","visible_render":false,"subjective_listening":false,"os150":false}
	var f=FileAccess.open(q.path_join("reports/repeated-state-v2.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("REPEATED STATE ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
