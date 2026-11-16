extends SceneTree
var game
var checks=[]
var evidence=OS.get_environment("INVENTORY_QA_ROOT")
func _initialize():call_deferred("run")
func check(ok,label):
	checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func frames(count:=8):
	for i in range(count):await process_frame
func settle():
	await frames()
	while game.locked or game.engine.busy or game.presenting or game.preview_pending:await process_frame
	await frames()
func enter_facility(page: String):
	game.navigate(page);await settle()
	var service={"shop":"buy","party":"guild","inn":"inn"}.get(page,"")
	var choice=game.find_child("FacilityChoice_"+service,true,false)
	if choice!=null and choice.is_visible_in_tree():
		choice.pressed.emit();await settle()
func node(id):return game.find_child(id,true,false)
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func click(id):node(id).pressed.emit();await settle()
func mouse(button,pressed):
	var event=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed;event.position=Vector2(800,400);game.board.input_event(event)
func motion(delta):
	var event=InputEventMouseMotion.new();event.relative=delta;event.position=Vector2(800,400);game.board.input_event(event)
func run():
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();
	game.audio.fast_mode=true;game.checks_fast=true
	var baseline=await saved()
	baseline.state.characters["recruit-guard-human-female"].inventory={"potion":2,"spear-wood":2,"swift-boots":1}
	await game.update({"op":"campaign_load","data":baseline});await settle()
	game.mock_shell.activate("recruit-guard-human-female");await settle()
	var workspace=game.pages.party_view.workspace
	workspace.set_tab("inventory");await settle()
	var spear=game.campaign().inventoryByCharacter["recruit-guard-human-female"].entries.filter(func(e):return e.id=="spear-wood")[0]
	var row=game.find_children("*","Button",true,false).filter(func(b):return b.tooltip_text==spear.name)[0]
	check(row.alignment==HORIZONTAL_ALIGNMENT_LEFT and row.icon!=null,"S4 owned equipment shows a left-aligned name and icon")
	row.pressed.emit();await settle()
	check(node("CharacterEquipmentComparison").text.contains("比較対象") and not node("CharacterEquip").disabled,"S5 selected equipment exposes its comparison and equip action")
	await click("CharacterItemDetails")
	check(node("SkillDetailsBody").text.contains("通常攻撃射程"),"S5 owned spear details include attack reach")
	await click("SkillDetailsBack");await click("CharacterEquip")
	check((await saved()).state.characters["recruit-guard-human-female"].inventory["spear-wood"]==1,"S10 equipping consumes exactly one spear")
	workspace.set_tab("equipment");await settle();await click("CharacterSlot_rightHand")
	var remove=game.find_children("*","Button",true,false).filter(func(b):return b.text=="装備を外す")[0]
	remove.pressed.emit();await settle()
	check((await saved()).state.characters["recruit-guard-human-female"].inventory["spear-wood"]==2,"S11 unequipping returns exactly one spear")
	var tip=preload("res://equipment_tooltip.gd").new();tip.configure("armor",{"type":"armor","hp":5,"effect":"archer"},{"definitions":{"archer":{"reach":3}},"descriptions":{"archer":"射程+1"}})
	check(not tip.tooltip_text.contains("通常攻撃射程") and "\n".join(tip.details).contains("#c7a5ff"),"S6 armor excludes attack reach while skill effect is purple");tip.free()
	var fixtures=preload("res://tests/ui_current_fixture.gd").generate("res://tests/inventory_battle_fixtures.cjs")
	check(not fixtures.is_empty(),"battle fixture generator")
	await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	var field=game.board.get_global_rect();var viewport=Rect2(Vector2.ZERO,Vector2(root.size))
	check(viewport.encloses(field) and not field.intersects(game.hud.left_panel.get_global_rect()) and not field.intersects(game.hud.right_panel.get_global_rect()),"S1 B board fits FHD between separate information columns")
	check(range(50).all(func(cell):return field.has_point(game.board.global_position+game.board.project_cell(cell))),"S1 all fifty board cell centers remain visible")
	check(node("BattleHistory")!=null and game.battle_header.global_position.y>root.size.y*.75 and viewport.encloses(node("BattleHistory").get_global_rect()) and node("BattleHistory").global_position.x>=node("TurnOrderViewport").get_global_rect().end.x,"S1 history remains visible beside bottom turn order")
	check(game.hud.left_panel.visible and game.hud.buttons.size()==5 and not game.actor_face.visible and not game.header.text.contains("HP"),"S2 ally and commands left; no duplicate top actor")
	check(not game.find_children("*","Button",true,false).any(func(b):return b.text in ["戦術","低","高"]),"S3 preset camera controls removed")
	var left=game.hud.left_panel;left.position=Vector2(40,90);left.size=Vector2(360,630);left.persist();var rect=Rect2(left.position,left.size)
	var previous=game.data.duplicate(true);var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0]
	game.data.state.actor=enemy.id;game.hud.render();await frames();check(not left.visible,"S2 enemy turn hides entire left panel")
	game.data=previous;game.hud.render();await frames();check(left.visible and Rect2(left.position,left.size)==rect,"S2/S7 next ally restores exact geometry")
	game.hud.inspected_uid="";game.hud.selected_cell=-1;game.hud.render_person();check(not game.hud.person_box.has_meta("inspected_unit"),"S2 right panel does not default to actor")
	game.hud.inspected_uid=str(game.hud.acting().id);game.hud.render_person();check(game.hud.person_box.get_meta("inspected_unit","")==game.hud.acting().id,"S2 explicitly targeted self appears right")
	var board=game.board;var pan=board.camera_pan
	mouse(MOUSE_BUTTON_RIGHT,true);motion(Vector2(80,30));mouse(MOUSE_BUTTON_RIGHT,false)
	check(board.camera_pan!=pan and board.camera_drag==0,"S3 right drag pans and release retains view")
	mouse(MOUSE_BUTTON_MIDDLE,true);motion(Vector2(45,-10000));mouse(MOUSE_BUTTON_MIDDLE,false)
	check(board.camera_pitch>=.2 and board.world.camera.position.y>0,"S3 middle drag tilt clamped above ground")
	var zoom=board.world.zoom;mouse(MOUSE_BUTTON_WHEEL_UP,true);check(board.world.zoom<zoom,"S3 wheel zoom retained")
	var prefs=preload("res://ui_preferences.gd").new();check(prefs.camera().pan.is_equal_approx(game.preferences.camera().pan) and is_equal_approx(prefs.camera().yaw,game.preferences.camera().yaw) and is_equal_approx(prefs.camera().zoom,game.preferences.camera().zoom),"S3 camera disk roundtrip")
	var bounded=prefs.bounded(Rect2(-2000,5000,2500,1800),Vector2(1280,720),Vector2(280,240));check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(bounded),"S7 off-screen preferences clamped")
	var camera=game.preferences.camera();await game.update({"op":"campaign_load","data":baseline});await settle();await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	check(game.board.camera_pan==camera.pan and game.board.camera_pitch==camera.pitch and game.board.world.zoom==camera.zoom,"S3 next battle restores camera")
	check(Rect2(game.hud.left_panel.position,game.hud.left_panel.size)==rect,"S7 next battle restores left panel")
	var record={"camera":str(camera),"left":str(rect),"viewport":str(root.size),"checks":checks,"gui_review":"not performed; headless state/layout assertions only"}
	var f=FileAccess.open(evidence.path_join("ui-feedback-20261016.json"),FileAccess.WRITE);f.store_string(JSON.stringify(record,"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	quit(0 if checks.all(func(c):return c.passed) else 1)
