extends SceneTree
var game
var checks=[]
var frames=[]
var seen={}
var active_action={}
var failures=[]
var monitoring=false
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE") if not OS.get_environment("UIUX_REVIEW_EVIDENCE").is_empty() else OS.get_user_data_dir().path_join("uiux-review-evidence")
var tag=OS.get_environment("UIUX_REVIEW_TAG")
var visual=DisplayServer.get_name()!="headless"
func _initialize():call_deferred("run")
func check(id_:String,ok:bool,detail:String,metrics:Dictionary={}):
	checks.append({"id":id_,"passed":ok,"detail":detail,"size":[root.size.x,root.size.y],"metrics":metrics})
	if not ok:failures.append(detail)
	print(("PASS " if ok else "FAIL ")+id_+" "+detail+" "+JSON.stringify(metrics))
func settle():
	for i in range(8):await process_frame
	while game.locked or game.presenting or game.engine.busy or game.pages.quote_pending or game.pages.shop_view.quote_worker:await process_frame
func fixture(name_:String):return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/"+name_+".json"))
func load_fixture(name_:String):await game.update({"op":"campaign_load","data":fixture(name_)});await settle()
func node(name_:String):return game.find_child(name_,true,false)
func content(n:Node)->String:
	var lines=[]
	if n is Label or n is Button:lines.append(n.text)
	for child in n.get_children():lines.append(content(child))
	return "\n".join(lines)
func button(caption:String):
	for b in game.find_children("*","Button",true,false):
		if b.text.trim_prefix("● ")==caption:return b
	return null
func dialog():
	if is_instance_valid(game.dialog.window):return game.dialog.window
	for n in game.get_children():
		if n is ConfirmationDialog and n.visible:return n
	return null
func respond(yes:bool):
	var d=dialog()
	if d!=null:
		if d is ConfirmationDialog:
			if yes:d.confirmed.emit()
			else:d.canceled.emit()
		else:game.dialog.close()
	await settle()
func capture(name_:String):
	if not visual:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join("captures/"+tag+"-"+name_+".png"))
func snapshot():
	await settle();return (await game.engine.request({"op":"campaign_save"})).data
func geometry():
	var result={"footer_height":game.footer.size.y}
	for id_ in ["ShopComparisonScroll","ShopActions","PaymentSummary"]:
		var n=node(id_);var r=n.get_global_rect();result[id_]=[r.position.x,r.position.y,r.size.x,r.size.y]
	return result
func run():
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));DirAccess.make_dir_recursive_absolute(evidence.path_join("captures"))
	root.title="5525 acceptance fixes - isolated QA";root.size=Vector2i(1280,800)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await shop();await camp();await effects();await presentation()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"frames":frames,"tag":tag,"input":"Godot callbacks with explicit real Control focus","visible_render":visual,"subjective_listening":false,"os_150_percent":false,"fixtures":"Independent review fixtures plus a labeled synthetic porter->enemy-healer attack sequence"}
	var f=FileAccess.open(evidence.path_join("reports/"+tag+"-results.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("REVIEW FIXES ",checks.size()," FAILURES ",failures.size()," FRAMES ",frames.size())
	await settle();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.2).timeout;game.queue_free()
	for i in range(5):await process_frame
	quit(0 if failures.is_empty() else 1)
func shop():
	for dims in [Vector2i(1280,800),Vector2i(1024,720),Vector2i(800,600)]:
		root.size=dims;await load_fixture("synthetic-east");game.navigate("shop");await settle()
		var product=node("Product_spear-wood");product.grab_focus();product.pressed.emit();await settle()
		var initial=geometry();var before=await snapshot()
		check("UI01",game.footer.size.y<=26 and node("ShopComparisonScroll").size.y>=64,"long focused product leaves usable comparison",initial)
		game.set_status("長い名前".repeat(10)+"\\n"+"説明".repeat(100));await settle()
		check("UI01",game.footer.size.y<=26 and geometry().ShopActions==initial.ShopActions,"40-character name and 200-character explanation cannot move controls")
		game.show_status_details();await settle()
		var full=node("StatusDetails")
		check("UI01",full!=null and content(full).contains("説明".repeat(100)),"keyboard can open full long explanation without changing quote")
		if full!=null:full.hide()
		await settle();node("ShopComparisonScroll").grab_focus();await settle()
		await capture("shop-focused-"+str(dims.x))
		var lines=game.pages.shop_view.comparison_lines(game.gear_preview,true)
		game.pages.shop_view.open_details();await settle()
		check("UI01",lines.all(func(line):return content(game.dialog.window).contains(line)),"full-details route contains all canonical comparison rows")
		game.dialog.close();await settle()
		game.pages.purchase(game.gear_preview);await settle();check("UI01",dialog()!=null,"readable quote can open confirmation")
		await respond(false);var after=geometry()
		check("UI01",after.ShopActions==initial.ShopActions and await snapshot()==before,"purchase cancel keeps operation position and campaign",after)
		node("ShopComparisonScroll").grab_focus();await settle();check("UI01",geometry().ShopActions==initial.ShopActions,"restoring long focus does not move purchase")
		await game.pages.start_trial();await settle();game.choose_command("guard");await game.commit();await settle();await game.act("endTrial",[]);await settle()
		check("UI01",geometry().ShopActions==initial.ShopActions and node("ShopComparisonScroll").size.y>=64 and await snapshot()==before,"trial return keeps readable comparison, position and original campaign")
		await capture("shop-return-"+str(dims.x))
	var hidden_quote=game.gear_preview.duplicate(true);var untouched=await snapshot()
	node("ShopComparisonScroll").hide();await settle()
	check("UI01",button("購入内容を確認").disabled,"purchase is disabled if comparison is hidden")
	game.pages.purchase(hidden_quote);await settle()
	check("UI01",dialog()==null and await snapshot()==untouched,"direct callback cannot purchase without visible comparison")
	root.size=Vector2i(1280,800);await settle()
func camp():
	await load_fixture("synthetic-one-hit-victory");game.choose_command("attack");await game.on_cell(35);await game.commit();await settle();await game.act("finishBattle",[]);await settle()
	check("UI02",game.campaign().phase=="camp","review victory fixture reaches camp")
	var before=button("次の区間へ").get_global_rect();var saved=await snapshot();await capture("camp-before")
	await game.forecast_action("rest","rest",[]);await settle();var warned=dialog()!=null
	await respond(true);var after=button("次の区間へ").get_global_rect()
	check("UI02",before==after,"onward button stays fixed after rest",{"before":[before.position.x,before.position.y,before.size.x,before.size.y],"after":[after.position.x,after.position.y,after.size.x,after.size.y],"warning":warned})
	check("UI02",game.campaign().journey.rested and game.campaign().journey.hours==saved.state.journey.hours+2,"rest keeps existing two-hour rule")
	await capture("camp-after")
func effects():
	await load_fixture("synthetic-west");game.navigate("shop");await game.pages.select_slot("feet");await settle()
	var row=node("Product_swift-boots")
	check("UI03",content(row).contains("俊足") and not content(row).contains("HP+0"),"unselected swift boots use a concise name/type/condition row")
	await game.preview_gear("swift-boots");await settle()
	check("UI03",content(node("GearQuote")).contains("俊足") and game.gear_preview.price==70,"comparison retains named movement effect and 70G price")
	game.pages.shop_view.open_details();await settle()
	check("UI03",content(game.dialog.window).contains("移動力+1"),"full effect description retains movement +1")
	game.dialog.close();await settle()
func observe_frame():
	if not monitoring or not game.data.get("presentation") is Dictionary:return
	var p=game.data.presentation;var key=str(p.id)+":"+str(p.index)
	if seen.has(key):return
	seen[key]=true
	if p.phase=="action":active_action=p.duplicate(true)
	var item={"key":key,"phase":p.duplicate(true),"action":active_action.duplicate(true),"actor_text":game.header.text,"command_text":content(game.hud.command_box),"target_text":content(game.hud.target_box),"can_commit":game.can_commit()}
	frames.append(item)
	if visual:frame_capture.call_deferred(key)
func frame_capture(key:String):
	await RenderingServer.frame_post_draw
	var p=game.data.get("presentation")
	if p is Dictionary and str(p.id)+":"+str(p.index)==key:root.get_texture().get_image().save_png(evidence.path_join("captures/"+tag+"-frame-"+key.replace(":","-")+".png"))
func presentation():
	await load_fixture("porter-enemy-attack");game.command="skill";game.render();await settle()
	var before=await snapshot();monitoring=true;process_frame.connect(observe_frame)
	game.checks_fast=not visual
	await game.choose_command("skill");await settle();await game.commit();await settle();monitoring=false;process_frame.disconnect(observe_frame);game.checks_fast=true
	var enemy_frames=frames.filter(func(f):return f.action.get("actor_id")=="enemy-mage-2" and f.action.get("kind")=="attack")
	check("UI04",enemy_frames.size()>=2,"porter boost is followed by real enemy healer attack frames",{"frames":enemy_frames.size()})
	var accurate=true;var locked=true
	for f in enemy_frames:
		accurate=accurate and not f.target_text.contains("ヒール") and not f.target_text.contains("対象を選択") and not f.command_text.contains("ヒール") and (f.target_text+f.command_text).contains("攻撃")
		locked=locked and not f.can_commit
	check("UI04",accurate and locked,"all enemy attack and impact frames explain current action with selection retired")
	check("UI04",game.data.get("presentation")==null and game.hud.state_id()=="B0" and game.pending==null and not game.presenting,"next ally opens fresh action list only after presentation completes (V2-B13)")
	check("UI04",game.state().actions>before.state.battle.actions and game.hud.unit("porter").mp==before.state.battle.units.filter(func(u):return u.id=="porter")[0].mp-1,"boost keeps existing MP and engine progression")
	await capture("after-enemy-sequence")
