extends SceneTree
var game
var checks=[]
var failures=[]
var phase_records=[]
var seen_phase := ""
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func check(id: String,value: bool,detail: String,extra: Dictionary={}):
	checks.append({"id":id,"passed":value,"detail":detail,"size":[root.size.x,root.size.y],"extra":extra})
	print(("PASS " if value else "FAIL ")+id+" "+detail+" "+JSON.stringify(extra))
	if not value:failures.append(id+" "+detail)
func settle():
	for i in range(8):await process_frame
	var deadline=Time.get_ticks_msec()+12000
	while (game.locked or game.presenting or game.engine.busy or game.pages.shop_view.quote_worker) and Time.get_ticks_msec()<deadline:await process_frame
func snapshot():
	await settle()
	return (await game.engine.request({"op":"campaign_save"})).get("data",{})
func fixture(location: String="east",gold: int=313):
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/synthetic-east.json"));source.state.location=location;source.state.gold=gold
	await game.update({"op":"campaign_load","data":source});game.shop_uid="guard";game.shop_slot="rightHand";game.navigate("shop");await settle()
func text(node: Node)->String:
	var values=[]
	if node is Label or node is Button:values.append(node.text)
	for child in node.get_children():values.append(text(child))
	return "\n".join(values)
func node(name: String):return game.find_child(name,true,false)
func button(caption: String):
	for item in game.find_children("*","Button",true,false):
		if item.text==caption and item.is_visible_in_tree():return item
	return null
func key(code: int):
	var window=game.dialog.window if is_instance_valid(game.dialog.window) else root
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;(window if is_instance_valid(window) else root).push_input(event,true);await process_frame
	await settle()
func inside(control: Control)->bool:return Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(control.get_global_rect())
func geometry(id: String):
	await settle()
	var bad=[]
	for item in game.find_children("*","Button",true,false):
		if not item.is_visible_in_tree() or item.get_window()!=root:continue
		var ancestor=item.get_parent();var scrolled=false
		while ancestor!=null:
			if ancestor is ScrollContainer:scrolled=true;break
			ancestor=ancestor.get_parent()
		if not scrolled and not inside(item):bad.append({"text":item.text,"rect":str(item.get_global_rect())})
	check(id,bad.is_empty(),"fixed actions fit the viewport",{"outside":bad})
func observe_phase():
	if not is_instance_valid(game) or game.closing:return
	var p=game.data.get("presentation")
	if p is Dictionary:
		var signature=str(p.get("id"))+":"+str(p.get("index"))
		if signature!=seen_phase:
			seen_phase=signature;phase_records.append({"phase":p.duplicate(true),"stage":game.hud.state_id(),"text":text(game.content),"can_commit":game.can_commit()})
func run():
	if evidence.is_empty():evidence="user://ui-state-v2"
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"))
	root.size=Vector2i(800,600);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;process_frame.connect(observe_phase)
	for dims in [Vector2i(800,600),Vector2i(1024,720),Vector2i(1178,814),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=dims;await fixture();var before=await snapshot()
		check("V2-S01",game.pages.shop_view.stage=="S0" and not game.pages.cached_quotes.is_empty(),"visible rows have canonical prefetched conditions")
		await geometry("V2-G01")
		await game.preview_gear("spear-wood");await settle()
		check("V2-S03",game.pages.shop_view.stage=="S2" and game.gear_preview.cost==20 and game.gear_preview.afterGold==293,"canonical representative quote 90-70=20 / 313→293")
		var lines=game.pages.shop_view.comparison_lines(game.gear_preview)
		check("V2-S03",str(lines).contains("26 → 23 (-3)") and str(lines).contains("射程外 → 23") and not str(lines).contains("HP上限"),"comparison keeps losses/range gain and omits unchanged numeric rows")
		var pane=node("ShopComparisonScroll")
		check("V2-S03",pane.get_v_scroll_bar().max_value<=pane.get_v_scroll_bar().page+1,"representative comparison needs no inner scroll",{"max":pane.get_v_scroll_bar().max_value,"page":pane.get_v_scroll_bar().page})
		check("V2-S03",(node("ShopProductsScroll")!=null)==(dims.x>=1120 and dims.y>=720),"compact comparison replaces list; wide keeps list")
		await geometry("V2-G01")
		for cycle in range(3):
			game.pages.shop_view.open_details();await settle()
			check("V2-S05",is_instance_valid(game.dialog.window) and text(game.dialog.window).contains("HP上限") and text(game.dialog.window).contains("成長補正1回"),"all-details includes unchanged fields and formula")
			if cycle==1:await key(KEY_ESCAPE)
			else:game.dialog.close();await settle()
			check("V2-S05",game.pages.shop_view.stage=="S2" and await snapshot()==before,"detail close returns identical campaign",{"stage":game.pages.shop_view.stage})
			game.pages.shop_view.confirm_purchase();await settle()
			var modal_text=text(game.dialog.window)
			check("V2-S06",modal_text.contains("木製の片手槍") and modal_text.contains("木製の護衛剣") and modal_text.contains("313 → 293G") and modal_text.contains("20Gで購入・装備"),"confirmation contains standalone transaction summary",{"text":modal_text})
			if cycle==1:await key(KEY_ESCAPE)
			elif cycle==2:await key(KEY_ENTER)
			else:game.dialog.close();await settle()
			check("V2-S07",game.pages.shop_view.stage=="S2" and await snapshot()==before,"cancel/Esc/default Enter changes no resources")
		game.pages.shop_view.confirm_purchase();await settle();button("20Gで購入・装備").pressed.emit();await settle()
		check("V2-S08",game.pages.shop_view.stage=="S6" and game.campaign().gold==293 and game.campaign().characters.guard.weapon=="spear-wood" and node("PurchaseReceipt")!=null,"successful purchase produces separate canonical receipt")
		await geometry("V2-G01")
		game.pages.shop_view.view_purchased();await settle();check("V2-S09",game.page=="party" and game.pages.party_uid=="guard" and game.pages.party_view.highlight_slot=="rightHand","receipt opens selected member and purchased slot")
		check("V2-P02",node("EquipmentSlots").get_child_count()==8,"eight read-only equipment slots")
		await geometry("V2-G01")
		for tab in range(3):game.pages.party_view.tab=tab;game.render();await settle();await geometry("V2-P03")
		button("商店へ戻る").pressed.emit();await settle();check("V2-S09",game.pages.shop_view.stage=="S0" and game.campaign().gold==293 and game.gear_preview.is_empty(),"party return reaches list without same-item quote")
		await fixture();await game.act("trial",["archer","twin-bow","rightHand"]);await settle()
		check("V2-B01",game.hud.state_id()=="B0" and game.header.text.count("HP")==1,"actor has one main status header / turn starts at action list")
		await geometry("V2-B01")
		game.choose_command("move");await settle();check("V2-B02",game.hud.state_id()=="B1" and game.preview.is_empty() and game.hud.selected_enemy.is_empty(),"movement begins with no stale target")
		var move_before=JSON.stringify(game.state(),"",true,true);await game.on_cell(int(game.data.choices.move[0]));await settle()
		check("V2-B03",game.hud.state_id()=="B2" and game.board.ghost.visible and text(game.content).contains("手番終了"),"move ghost and end-turn warning")
		await geometry("V2-B04")
		game.hud.open_range_reference();await settle();check("V2-B05",game.hud.state_id()=="B2R" and not game.can_commit(),"range reference cannot execute")
		game.dialog.close();await settle();check("V2-B05",game.hud.state_id()=="B2" and game.preview_ready,"reference returns to same valid ghost")
		game.cancel();await settle();check("V2-B03",game.hud.state_id()=="B1" and JSON.stringify(game.state(),"",true,true)==move_before,"ghost cancellation consumes nothing")
		game.cancel();await settle();check("V2-B13",game.hud.state_id()=="B0","second cancellation returns action list")
		game.choose_command("attack");var target=game.data.choices.attack[0]
		for u in game.state().units:
			if u.id==target:await game.on_cell(int(u.pos));break
		await settle();check("V2-B07",game.hud.state_id()=="B4" and game.can_commit() and node("PredictionSummary")!=null,"single target has executable canonical prediction")
		await geometry("V2-B07")
		await game.on_cell(0);await settle();check("V2-B08",game.pending==null and game.preview.is_empty() and not game.can_commit() and game.hud.selected_cell==0,"empty actual tile invalidates old target and prediction")
		game.choose_command("skill");var pair=game.data.choices.skill[0]
		for id in pair:
			for u in game.state().units:
				if u.id==id:await game.on_cell(int(u.pos));break
		await settle();check("V2-B11",game.preview.damagePreview.size()==2 and text(game.content).contains("予測 2件"),"multi-target summary retains count and detail route")
		var hp={}
		for u in game.state().units:
			if pair.has(u.id):hp[u.id]=u.hp
		await game.commit();await settle()
		check("V2-B12",game.state().units.filter(func(u):return pair.has(u.id)).all(func(u):return u.hp<hp[u.id]),"both engine results apply through sequential presentation")
		check("V2-B13",game.hud.state_id()=="B0" and game.pending==null,"completed action returns to fresh action list")
		await game.act("endTrial",[]);await settle()

	root.size=Vector2i(800,600);await fixture();await game.preview_gear("spear-wood");await settle()
	var long_name="長い装備名の可読性を確認するための表示専用試験用の木製の片手槍・最終文字"
	game.gear_preview.gear.name=long_name;game.render();await settle()
	check("V2-S16",text(game.content).contains(long_name),"display-only 40-character candidate name retains its full text")
	await geometry("V2-S16");game.pages.shop_view.confirm_purchase();await settle()
	check("V2-S16",text(game.dialog.window).contains(long_name),"confirmation contains the full long name; no transaction performed")
	for dims in [Vector2i(1280,800),Vector2i(800,600)]:
		root.size=dims;await settle();check("V2-S17",game.pages.shop_view.stage=="S4" and text(game.dialog.window).contains(long_name),"resizing keeps confirmation identity and content")
	game.dialog.close();await settle();await fixture()
	game.navigate("party");game.pages.party_uid="guard";game.pages.party_view.tab=0;game.render();await settle()
	var party_before=await snapshot();button("右手\n木製の護衛剣").pressed.emit();await settle()
	check("V2-P02",is_instance_valid(game.dialog.window) and text(game.dialog.window).contains("閲覧専用"),"P2 equipment details are read only")
	game.dialog.close();await settle();button("選択枠の装備をこの町で買い替える").pressed.emit();await settle()
	check("V2-P04",game.page=="shop" and game.shop_uid=="guard" and game.shop_slot=="rightHand" and button("仲間へ戻る")!=null,"matching town shop receives member and slot with a return route")
	button("仲間へ戻る").pressed.emit();await settle();check("V2-P04",game.page=="party" and await snapshot()==party_before,"party/shop browsing consumes no resources or travel time")
	game.pages.party_view.tab=2;game.render();await settle()
	check("V2-P03",text(game.content).contains("次の本人の番") and text(game.content).contains("左手"),"legacy skill conditions and source remain available in the skill tab")
	game.pages.party_view.tab=1;game.render();await settle()
	check("V2-P05",button("編成から外す").disabled and button("STR+1").disabled,"outside guild and without points membership/allocation remain disabled")
	await fixture("astaris");game.navigate("party");game.pages.party_uid="porter";game.pages.party_view.tab=1;game.render();await settle()
	check("V2-P05",button("編成から外す").disabled and text(game.content).contains("未実装"),"required porter cannot leave; skill points stay explicitly unimplemented")
	var dual=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/synthetic-east.json"));dual.state.characters.guard.weapon="greatsword-wood";dual.state.characters.guard.leftHand="empty-leftHand"
	await game.update({"op":"campaign_load","data":dual});game.navigate("party");game.pages.party_uid="guard";game.render();await settle()
	check("V2-P02",text(game.content).contains("右手の両手武器で使用中"),"canonical two-handed equipment explains left-hand occupancy")
	check("V2-B12",phase_records.any(func(r):return r.stage=="B5") and phase_records.any(func(r):return r.stage=="B6") and phase_records.all(func(r):return not r.can_commit),"execution and actual phases separately observed; all lock commit")
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"phase_records":phase_records,"input":"scripted Godot Control signals and viewport key events; not OS input","visible_render":DisplayServer.get_name()!="headless","os150":false,"subjective_listening":false}
	var f=FileAccess.open(evidence.path_join("reports/ui-state-v2.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ",true,true));f.close()
	print("STATE V2 ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
