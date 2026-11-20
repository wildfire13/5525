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
func fixture(name_:String):return preload("res://tests/ui_current_fixture.gd").fixtures()[name_]
func load_fixture(name_:String):await game.update({"op":"campaign_load","data":fixture(name_)});await settle()
func node(name_:String):return game.find_child(name_,true,false)
func content(n:Node)->String:
	var lines=[]
	if n is Label or n is Button or n is RichTextLabel:lines.append(n.text)
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
	for id_ in ["ShopComparisonStats","ShopTransaction"]:
		var n=node(id_);var r=n.get_global_rect();result[id_]=[r.position.x,r.position.y,r.size.x,r.size.y]
	return result
func run():
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));DirAccess.make_dir_recursive_absolute(evidence.path_join("captures"))
	root.title="5525 acceptance fixes - isolated QA";root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await shop();await camp();await effects();await presentation()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"frames":frames,"tag":tag,"input":"Godot callbacks with explicit real Control focus","visible_render":visual,"subjective_listening":false,"os_150_percent":false,"fixtures":"Independent review fixtures plus a labeled synthetic porter->enemy-healer attack sequence"}
	var f=FileAccess.open(evidence.path_join("reports/"+tag+"-results.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("REVIEW FIXES ",checks.size()," FAILURES ",failures.size()," FRAMES ",frames.size())
	await settle();game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.2).timeout;game.queue_free()
	for i in range(5):await process_frame
	quit(0 if failures.is_empty() else 1)
func shop():
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;await load_fixture("synthetic-east");game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
		var product=node("Product_spear-wood");product.grab_focus();product.pressed.emit();await settle()
		var initial=geometry();var before=await snapshot()
		check("UI01",root.get_visible_rect().encloses(node("ShopComparisonStats").get_global_rect()) and root.get_visible_rect().encloses(node("ShopTransaction").get_global_rect()),"focused current product leaves visible comparison and transaction",initial)
		game.set_status("長い名前".repeat(10)+"\\n"+"説明".repeat(100));await settle()
		check("UI01",geometry().ShopTransaction==initial.ShopTransaction,"40-character name and 200-character explanation cannot move controls")
		game.show_status_details();await settle()
		var full=game.dialog.window
		check("UI01",full!=null and content(full).contains("説明".repeat(100)),"keyboard can open full long explanation without changing quote")
		game.dialog.close()
		await settle();node("ShopComparisonBuy").grab_focus();await settle()
		await capture("shop-focused-"+str(dims.x))
		check("UI01",not game.modal_open() and await snapshot()==before,"comparison and focus preserve campaign state")
		await game.act("trial",["character_mirei","spear-wood","rightHand"]);await settle();game.choose_command("action_defend");await game.commit();await settle();await game.act("endTrial",[]);await settle()
		var restored=await snapshot()
		check("UI01",restored==before and game.page=="shop","trial return keeps original campaign and shop")
		await capture("shop-return-"+str(dims.x))
	root.size=Vector2i(1920,1080);await settle()
func camp():
	await load_fixture("synthetic-one-hit-victory");game.choose_command("action_attack");await game.on_cell(35);await game.commit();await settle();await game.act("finishBattle",[]);await settle()
	check("UI02",game.campaign().phase=="camp","review victory fixture reaches camp")
	check("UI02",game.results_view.active,"battle reward receipt precedes camp interaction")
	if game.results_view.active:game.results_view.continue_button.pressed.emit();await settle()
	var before=button("次の区間へ").get_global_rect();var saved=await snapshot();await capture("camp-before")
	await game.forecast_action("rest","rest",[]);await settle();var warned=dialog()!=null
	await respond(true);var after=button("次の区間へ").get_global_rect()
	check("UI02",before==after,"onward button stays fixed after rest",{"before":[before.position.x,before.position.y,before.size.x,before.size.y],"after":[after.position.x,after.position.y,after.size.x,after.size.y],"warning":warned})
	check("UI02",game.campaign().journey.rested and game.campaign().hours==saved.state.hours+2,"rest keeps existing two-hour rule",{"before":saved.state.hours,"after":game.campaign().hours,"rested":game.campaign().journey.rested,"overflow":game.campaign().get("inventoryOverflow",[])})
	await capture("camp-after")
func effects():
	await load_fixture("synthetic-west");game.navigate("shop");game.pages.facility_entry.choose("buy");await game.pages.select_slot("feet");await settle()
	var row=node("Product_swift-boots")
	check("UI03",content(row).contains("俊足") and not content(row).contains("HP+0"),"unselected swift boots use a concise name/type/condition row")
	game.pages.shop_view.open_comparison("swift-boots");await settle()
	check("UI03",content(node("ShopComparisonSkills")).contains("俊足") and node("ShopComparisonPayment").text.contains("70G"),"comparison retains named movement effect and canonical 70G purchase price")
	var gear=game.campaign().shop.filter(func(item):return item.id=="swift-boots")[0]
	var badges=game.find_children("ComparisonSkill_*swift*","Button",true,false)
	var notes=node("ShopComparisonNotes")
	check("UI03",is_instance_valid(notes) and notes.is_visible_in_tree() and content(notes).contains(gear.note) and badges.any(func(badge):return badge.tooltip_text.contains("移動力+1")),"comparison shows original equipment note and movement skill tooltip",{"expected":gear.note,"notes":content(notes),"tooltips":badges.map(func(badge):return badge.tooltip_text)})
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
	await load_fixture("porter-enemy-attack");game.command="action_skill";game.render();await settle()
	var before=await snapshot();monitoring=true;process_frame.connect(observe_frame)
	game.checks_fast=not visual
	await game.choose_command("action_skill");await settle();await game.commit();await settle();monitoring=false;process_frame.disconnect(observe_frame);game.checks_fast=true
	var enemy_frames=frames.filter(func(f):return f.action.get("actor_id")=="enemy-mage-2" and f.action.get("kind")=="action_attack")
	check("UI04",enemy_frames.size()>=2,"porter boost is followed by real enemy healer attack frames",{"frames":enemy_frames.size()})
	var accurate=true;var locked=true
	for f in enemy_frames:
		accurate=accurate and not f.target_text.contains("ヒール") and not f.target_text.contains("対象を選択") and not f.command_text.contains("ヒール") and (f.target_text+f.command_text).contains("攻撃")
		locked=locked and not f.can_commit
	check("UI04",accurate and locked,"all enemy attack and impact frames explain current action with selection retired")
	check("UI04",game.data.get("presentation")==null and game.hud.state_id()=="B0" and game.pending==null and not game.presenting,"next ally opens fresh action list only after presentation completes (V2-B13)")
	check("UI04",game.state().actions>before.state.battle.actions and game.hud.unit("character_yuno").mp==before.state.battle.units.filter(func(u):return u.id=="character_yuno")[0].mp-1,"boost keeps existing MP and engine progression")
	await capture("after-enemy-sequence")
