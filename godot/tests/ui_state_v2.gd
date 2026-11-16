extends SceneTree
var game
var checks=[]
var phases=[]
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
const GUARD="recruit-guard-human-female"
func _initialize():call_deferred("run")
func node(id):return game.find_child(id,true,false)
func check(id,ok,detail):
	checks.append({"id":id,"passed":bool(ok),"detail":detail})
	print(("PASS " if ok else "FAIL ")+id+" "+detail)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker:await process_frame
func saved():
	await settle()
	return (await game.engine.request({"op":"campaign_save"})).data
func geometry(id):
	var outside=[]
	for control in game.find_children("*","Button",true,false):
		if not control.is_visible_in_tree() or control.get_window()!=root:continue
		var ancestor=control.get_parent();var scrolled=false
		while ancestor!=null:
			if ancestor is ScrollContainer:scrolled=true;break
			ancestor=ancestor.get_parent()
		if not scrolled and not root.get_visible_rect().grow(1).encloses(control.get_global_rect()):outside.append(control.name)
	check(id,outside.is_empty(),"fixed actions fit FHD viewport: "+str(outside))
func observe():
	if not is_instance_valid(game) or game.closing:return
	if game.data.get("presentation") is Dictionary:phases.append({"stage":game.hud.state_id(),"can_commit":game.can_commit()})
func run():
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;process_frame.connect(observe)
	var fixtures=preload("res://tests/ui_current_fixture.gd").fixtures()
	await game.update({"op":"campaign_load","data":fixtures["synthetic-east"]})
	game.shop_uid=GUARD;game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
	var before=await saved();game.pages.shop_view.open_comparison("spear-wood");await settle()
	var canonical=(await game.engine.request({"op":"campaign","action":"previewGear","args":[GUARD,"spear-wood","rightHand"]})).previewGear
	var comparison=game.pages.shop_view.comparison_view
	var owner=game.roster().filter(func(member):return member.id==GUARD)[0]
	check("V2-S03",not comparison.stat_changes(owner,canonical).is_empty() and node("ShopComparisonStats").text.contains("→"),"live recruit comparison retains canonical losses and gains")
	geometry("V2-G01")
	for cycle in range(3):
		await game.pages.shop_view.confirm_purchase("spear-wood",GUARD);await settle()
		check("V2-S06",node("PurchasePayment").text.contains("313 → 223G"),"standalone consent shows current full-price inventory transaction")
		node("PurchaseDecline").pressed.emit();await settle()
		var cancelled=await saved()
		check("V2-S07",cancelled==before,"repeated purchase cancellation preserves all resources")
	await game.act("trial",["recruit-scout-elf-male","twin-bow","rightHand"]);await settle()
	check("V2-B01",game.hud.state_id()=="B0","live scout trial starts at action list")
	geometry("V2-B01")
	game.choose_command("move");var move_before=await saved();var dest=int(game.data.choices.move[0])
	await game.on_cell(dest);await settle()
	check("V2-B03",game.hud.state_id()=="B2" and game.board.ghost.visible,"candidate move shows ghost without consuming turn")
	game.hud.open_range_reference();await settle()
	check("V2-B05",game.hud.state_id()=="B2R" and not game.can_commit(),"range reference cannot execute")
	game.hud.close_reference();await settle()
	check("V2-B05",game.hud.state_id()=="B2" and game.preview_ready,"closing range returns valid candidate")
	game.cancel();await settle()
	var cancelled_move=await saved()
	check("V2-B03",game.pending==null and cancelled_move==move_before,"move cancellation preserves exact campaign")
	await game.select_skill("archer");await settle()
	var pair=game.data.choices.skill[0]
	for uid in pair:
		for unit in game.state().units:
			if unit.id==uid:await game.on_cell(int(unit.pos));break
	await settle()
	check("V2-B11",game.can_commit() and game.preview.damagePreview.size()==2,"equipped bow grants real two-target preview to current scout")
	var hp={}
	for unit in game.state().units:
		if pair.has(unit.id):hp[unit.id]=unit.hp
	await game.commit();await settle()
	check("V2-B12",game.state().units.filter(func(unit):return pair.has(unit.id)).all(func(unit):return unit.hp<hp[unit.id]),"both predicted recipients receive damage")
	check("V2-B13",game.hud.state_id()=="B0" and game.pending==null,"completed presentation returns fresh action list")
	await game.act("endTrial",[]);await settle()
	var restored=await saved()
	check("V2-S09",restored==before,"trial restores complete original campaign")
	check("V2-B12",not phases.is_empty() and phases.all(func(phase):return not phase.can_commit),"all observed action presentation frames lock execution")
	var file=FileAccess.open(evidence.path_join("reports/ui-state-v2.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"phases":phases},"  "));file.close()
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
