extends SceneTree
var game
var checks=[]
var failures=[]
var q=OS.get_environment("UIUX_REVIEW_EVIDENCE")
var tag=OS.get_environment("UIUX_REVIEW_TAG")
var visual=DisplayServer.get_name()!="headless"
func _initialize():call_deferred("run")
func check(id_:String,ok:bool,detail:String,extra:Dictionary={}):
	checks.append({"id":id_,"passed":ok,"detail":detail,"size":[root.size.x,root.size.y],"extra":extra})
	if not ok:failures.append(detail)
	print(("PASS " if ok else "FAIL ")+id_+" "+detail+" "+JSON.stringify(extra))
func settle():
	for i in range(8):await process_frame
	while game.locked or game.presenting or game.engine.busy or game.pages.quote_pending:await process_frame
func node(id_:String):return game.find_child(id_,true,false)
func snapshot():return (await game.engine.request({"op":"campaign_save"})).data
func fixture():
	await game.update({"op":"campaign_load","data":JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/synthetic-east.json"))});game.navigate("shop");await settle()
func button(label_:String):
	for n in game.find_children("*","Button",true,false):
		if n.text.trim_prefix("● ")==label_:return n
	return null
func dialog():
	for n in game.get_children():
		if n is ConfirmationDialog and n.visible:return n
	return null
func text(n:Node)->String:
	var lines=[]
	if n is Button or n is Label:lines.append(n.text)
	for child in n.get_children():lines.append(text(child))
	return "\n".join(lines)
func key(code:int):
	var window=root
	for child in game.get_children():
		if child is Window and child.visible:window=child
	for pressed in [true,false]:
		var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed
		window.push_input(e,true);await process_frame
	await settle()
func click(control):
	# Includes real Control focus acquisition, unlike directly calling purchase().
	control.grab_focus();control.pressed.emit();await settle()
func wheel(pane,steps:int):
	var point=pane.get_global_rect().get_center()
	for i in range(absi(steps)):
		var e=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_WHEEL_DOWN if steps>0 else MOUSE_BUTTON_WHEEL_UP;e.pressed=true;e.factor=1
		root.push_input(e,true);await process_frame
	await settle()
func view()->Dictionary:
	var pane=node("ShopComparisonScroll");var rect=pane.get_global_rect();var rows=[]
	for label_ in pane.find_children("*","Label",true,false):
		var r=label_.get_global_rect()
		if r.end.y>rect.position.y and r.position.y<rect.end.y:rows.append({"y":r.position.y,"x":r.position.x,"text":label_.text})
	rows.sort_custom(func(a,b):return a.y<b.y if a.y!=b.y else a.x<b.x)
	return {"compare":pane.scroll_vertical,"products":node("ShopProducts").scroll_vertical,"top":rows[0].text if not rows.is_empty() else "","member":game.shop_uid,"slot":game.shop_slot,"gear":game.pages.gear_id}
func capture(name_:String):
	if not visual:return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(q.path_join("captures/"+tag+"-"+name_+".png"))
func cancel_purchase(_cycle:int):
	var d=dialog()
	if d!=null:d.canceled.emit()
	await settle()
	check("N01",dialog()==null,"confirmation actually closes")
func read_repeated(expected:String,prefix:String):
	for cycle in range(3):
		game.footer.grab_focus();game.show_status_details();await settle()
		var popup=node("StatusDetails")
		check("N02",popup!=null and not expected.is_empty() and text(popup).contains(expected),prefix+" full text open "+str(cycle+1))
		if visual and cycle==2:await capture(prefix+"-reopened")
		if popup!=null:
			if cycle%2==0:popup.hide()
			else:popup.find_children("*","Button",true,false)[0].pressed.emit()
		await settle()
		check("N02",node("StatusDetails")==null and str(game.footer.get_meta("full_message",""))==expected,prefix+" closing preserves full source "+str(cycle+1))
func extra_transitions():
	var before=await snapshot()
	await click(node("Product_javelin-wood"));var expected=str(game.footer.get_meta("full_message",""))
	game.show_status_details();await settle();root.size=Vector2i(800,600);await settle();root.size=Vector2i(1024,720);await settle()
	var popup=node("StatusDetails")
	check("N02",popup!=null and text(popup).contains(expected),"resize during explanation preserves displayed text")
	popup.hide();await settle()
	check("N02",str(game.footer.get_meta("full_message",""))==expected,"resize then close restores original explanation")
	await read_repeated(expected,"resize-return")
	await wheel(node("ShopComparisonScroll"),6);var position=view()
	await click(button("差額%dGで買い替える" % game.gear_preview.cost))
	check("N01",dialog()!=null,"confirmation opens before resize round trip")
	root.size=Vector2i(800,600);await settle();root.size=Vector2i(1024,720);await settle()
	await cancel_purchase(0)
	check("N01",view()==position,"resize round trip while confirming preserves comparison",{"before":position,"after":view()})
	game.navigate("town");await settle();game.navigate("shop");await settle()
	await game.pages.select_slot("leftHand");await game.preview_gear("javelin-wood");await settle()
	await click(node("Product_javelin-wood"));expected=str(game.footer.get_meta("full_message",""))
	await read_repeated(expected,"shop-return")
	check("TRANSITION",await snapshot()==before,"town and shop return never changes campaign")
	# Context replacement must discard the old popup's restoration checkpoint.
	game.show_status_details();await settle()
	await fixture();var new_message=str(game.footer.get_meta("full_message",""))
	popup=node("StatusDetails");popup.hide();await settle()
	check("N02",str(game.footer.get_meta("full_message",""))==new_message,"campaign replacement prevents stale explanation restoration")
func run():
	if q.is_empty():q="user://uiux-state-regression"
	if tag.is_empty():tag="regression"
	DirAccess.make_dir_recursive_absolute(q.path_join("reports"));DirAccess.make_dir_recursive_absolute(q.path_join("captures"))
	root.title="5525 repeated UI state regression";root.size=Vector2i(1280,800)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	for dims in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1024,720)]:
		root.size=dims;await settle();await fixture()
		for pair in [["rightHand","spear-wood"],["leftHand","javelin-wood"]]:
			await game.pages.select_slot(pair[0]);await game.preview_gear(pair[1]);await settle()
			var before=await snapshot()
			for cycle in range(3):
				await wheel(node("ShopComparisonScroll"),-80);await wheel(node("ShopComparisonScroll"),6 if cycle%2==0 else 80)
				await wheel(node("ShopProducts"),2 if cycle%2==0 else -2)
				var position=view()
				check("N01",position.compare>0,"wheel reaches middle/end without memory.capture",position)
				if visual and cycle==0:await capture("before-"+str(dims.x)+"-"+pair[0])
				await click(button("差額%dGで買い替える" % game.gear_preview.cost))
				await create_timer(.12 if not visual else 1.0).timeout
				check("N01",dialog()!=null,"purchase confirmation appears "+str(cycle+1))
				await cancel_purchase(cycle)
				check("N01",view()==position and await snapshot()==before,"repeat cancellation keeps both panes and top row "+str(cycle+1),{"before":position,"after":view()})
				if visual and cycle==0:await capture("after-"+str(dims.x)+"-"+pair[0])
			# A newly selected product must supply its own message; modal focus must not clear it.
			await click(node("Product_"+pair[1]));var expected=str(game.footer.get_meta("full_message",""));var position=view()
			await read_repeated(expected,str(dims.x)+"-"+pair[0])
			check("N02",view()==position and await snapshot()==before,"reopening explanation never changes quote, scroll or campaign")
			await wheel(node("ShopComparisonScroll"),6);var trial_position=view()
			await game.pages.start_trial();await settle();game.choose_command("guard");await game.commit();await settle();await game.act("endTrial",[]);await settle()
			check("TRANSITION",view()==trial_position and await snapshot()==before,"trial return preserves both scrolls after repeated modals",{"before":trial_position,"after":view()})
			await click(node("Product_"+pair[1]));expected=str(game.footer.get_meta("full_message",""))
			await read_repeated(expected,str(dims.x)+"-returned-"+pair[0])
			var list_position=node("ShopProducts").scroll_vertical
			await click(button("比較を閉じる"));check("TRANSITION",game.gear_preview.is_empty() and node("ShopProducts").scroll_vertical==list_position,"closing comparison preserves product list")
			await game.preview_gear(pair[1]);await settle();await click(node("Product_"+pair[1]));expected=str(game.footer.get_meta("full_message",""))
			await read_repeated(expected,str(dims.x)+"-comparison-reopened-"+pair[0])
			check("TRANSITION",await snapshot()==before,"all read/cancel/trial/reopen transitions leave campaign unchanged")
	await extra_transitions()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"tag":tag,"input":"Injected wheel events, Control activation, confirmation canceled signal and popup hide/close; no manual memory.capture; OS keys tested separately","visible_render":visual,"subjective_listening":false,"os150":false}
	var f=FileAccess.open(q.path_join("reports/"+tag+"-results.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("REPEATED STATE ",checks.size()," FAILURES ",failures.size())
	await game.audio.finish_audio();game.engine.close_engine();await create_timer(.2).timeout;game.queue_free()
	for i in range(5):await process_frame
	quit(0 if failures.is_empty() else 1)
