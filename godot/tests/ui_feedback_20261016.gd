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
	game.audio.fast_mode=true;game.checks_fast=true
	var baseline=await saved();baseline.state.characters.guard.inventory={"potion":2,"spear-wood":2,"swift-boots":1}
	await game.update({"op":"campaign_load","data":baseline});await settle()
	var p=game.pages.party_view;p.open_detail("guard");await settle()
	var status=game.dialog.window;status.position=Vector2i(65,75);status.size=Vector2i(900,720);game.dialog.close();await frames();p.open_detail("guard");await settle()
	check(game.dialog.window.position==Vector2i(65,75) and game.dialog.window.size==Vector2i(900,720) and not game.dialog.window.unresizable,"S7 status geometry survives close/reopen")
	check(not node("EquipmentHover").visible,"S8/S9 comparison not permanently displayed")
	var slot=node("OwnedEquipmentSlot");slot.select(1);slot.item_selected.emit(1);await settle()
	node("OwnedEquipmentActions_spear-wood").mouse_entered.emit();await settle()
	check(not node("OwnedEquipmentComparison").text.is_empty() and not node("OwnedEquipmentComparison").text.contains("+0"),"S5/S9 equip hover contains only changed character comparison")
	check(node("OwnedEquipment_spear-wood").alignment==HORIZONTAL_ALIGNMENT_LEFT and node("OwnedEquipment_spear-wood").icon!=null,"S4 item names left aligned with placeholder item icon")
	var before=await saved();await click("OwnedEquipmentActions_spear-wood")
	check(p.inventory_view.stage=="confirm" and node("InventoryConfirm").text=="YES" and node("InventoryCancel").text=="NO","S10 explicit YES/NO confirmation")
	await click("InventoryCancel");check((await saved())==before,"S10 NO preserves inventory and equipment")
	await click("StatusTab_0");await click("OwnedEquipmentActions_spear-wood");await click("InventoryConfirm")
	check((await saved()).state.characters.guard.inventory["spear-wood"]==1,"S10 YES equips exactly one")
	await click("StatusTab_0");check(node("UnequipSelected")!=null and node("UnequipSelected").text=="装備を外す","S11 compact unequip follows owned list")
	await click("UnequipSelected");check(p.inventory_view.quote.slot=="rightHand","S11 unequip uses selected slot")
	await click("InventoryConfirm");check((await saved()).state.characters.guard.inventory["spear-wood"]==2,"S11 unequip returns exactly one item")
	await all_inventory()
	check(node("OwnedEquipment_potion").tooltip_text.contains("HP") and node("OwnedEquipment_spear-wood").tooltip_text.contains("通常攻撃射程"),"S5 mixed consumables and unequipped gear have tooltips")
	var tip=preload("res://equipment_tooltip.gd").new();tip.configure("armor",{"type":"armor","hp":5,"effect":"archer"},{"definitions":{"archer":{"reach":3}},"descriptions":{"archer":"射程+1"}})
	check(not tip.tooltip_text.contains("通常攻撃射程") and "\n".join(tip.details).contains("#c7a5ff"),"S6 armor excludes attack reach while skill effect is purple");tip.free()
	game.dialog.close();await settle()
	var output=[];var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/inventory_battle_fixtures.cjs")]),output,true,false)
	check(code==0,"battle fixture generator")
	var fixtures=JSON.parse_string("".join(output));await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	check(game.board.get_global_rect()==Rect2(Vector2.ZERO,Vector2(1920,1080)),"S1 board spans FHD viewport beneath overlays")
	check(node("BattleHistory")!=null and game.battle_header.global_position.y>850 and node("BattleHistory").global_position.y>node("TurnOrder").global_position.y,"S1 history and bottom turn order")
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

func all_inventory():
	var chooser=game.find_child("OwnedEquipmentSlot",true,false)
	chooser.select(0);chooser.item_selected.emit(0);await settle()
