extends "res://tests/research2_gui.gd"
var baseline := OS.get_environment("LAYOUT_BASELINE")=="1"
var observations=[]
func os_resize(dims: Vector2i):
 request_id+=1
 var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"id":request_id,"action":"resize_window","window":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),"width":dims.x,"height":dims.y}));f.close()
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if FileAccess.file_exists(evidence.path_join("response.json")):
   var reply=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
   if reply is Dictionary and reply.get("id")==request_id:break
  await process_frame
 await create_timer(.4).timeout;await settle()
 check(root.size==dims,"X11 native resize delivered "+str(dims))
func screen_rect(c: Control) -> Rect2:return Rect2(c.get_global_rect().position+Vector2(c.get_window().position),c.size)
func inside(c: Control) -> bool:return Rect2(Vector2.ZERO,Vector2(root.size)).encloses(screen_rect(c))
func observe(label: String,controls: Array):
 var data={"case":label,"screen":str(root.size),"controls":{}}
 for c in controls:
  data.controls[str(c.name)]={"rect":str(screen_rect(c)),"inside_screen":inside(c)}
  if not baseline:check(inside(c),label+" "+str(c.name)+" completely inside screen")
  if label.begins_with("F3"):
   var viewport=screen_rect(node("ModalDetailScroll"))
   data.controls[str(c.name)].inside_viewport=viewport.encloses(screen_rect(c));data.viewport=str(viewport)
   if not baseline:check(viewport.encloses(screen_rect(c)),label+" "+str(c.name)+" inside scroll viewport without clipping")
 observations.append(data);print("GEOMETRY "+JSON.stringify(data))
func run():
 create_timer(500).timeout.connect(func():print("FAIL layout GUI watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1180,812)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var original=await saved()
 var town=original.duplicate(true);town.state.location="east"
 await game.update({"op":"campaign_load","data":town});await enter_facility("shop");await settle();await os_click(node("PartyFace_guard"));await os_click(node("StatusTab_2"));await os_click(node("PartySkillDetails_guard"))
 var before=await saved();await snapshot("F1-open-1180")
 await os_resize(Vector2i(960,540));observe("F1-shrink",[node("SkillDetailsBack"),node("SkillDetailsSummary")]);await snapshot("F1-shrink-960")
 if not baseline:
  check(node("SkillDetailsWindow")!=null and await saved()==before,"resize keeps same explanation and save")
  await os_click(node("SkillDetailsBack"));check(node("SkillDetailsWindow")==null and game.dialog.window!=null and node("PartySkillDetails_guard").has_focus(),"mouse closes resized explanation to same logical skill button")
  await os_resize(Vector2i(1180,812));await os_click(node("PartySkillDetails_guard"));await os_resize(Vector2i(960,540));await os_resize(Vector2i(1920,1080));observe("F1-restore",[node("SkillDetailsBack")]);await os_key("Escape")
 else:await os_key("Escape")
 game.dialog.close();await settle();var cases=cases2()
 for which in ["sweep50","sweep100"]:
  await os_resize(Vector2i(1180,812));await game.update({"op":"campaign_load","data":cases[which]});await settle()
  await os_click(game.hud.buttons.skill);await os_click(node("BattleSkill_legSweep"));await os_click(node("BattleSkillDetails_legSweep"));await os_key("Escape")
  observe("F2-"+which,[node("BattleHistory"),node("BattleOrderDetails")]);await snapshot("F2-"+which+"-1180")
  if not baseline:
   for panel in [game.hud.left_panel,game.hud.right_panel]:
    for control in [node("BattleHistory"),node("BattleOrderDetails")]:check(not panel.get_global_rect().intersects(control.get_global_rect()),"floating panel does not cover "+str(control.name))
   await os_click(node("BattleHistory"));check(game.dialog.window!=null and game.dialog.window.title=="戦闘履歴","mouse opens history without moving panel");await os_key("Escape")
   await os_click(node("BattleOrderDetails"));check(node("OrderDetail_0")!=null,"mouse opens turn order details inside screen");await os_key("Escape")
   var queue=node("TurnOrderViewport");var bar=queue.get_h_scroll_bar();var bar_rect=bar.get_global_rect()
   await os_mouse(Vector2(bar_rect.position.x+10,bar_rect.get_center().y),"drag",Vector2(bar_rect.end.x-10,bar_rect.get_center().y))
   check(queue.scroll_horizontal>0 and queue.get_global_rect().encloses(node("TurnCard_4").get_global_rect()),"OS horizontal scrollbar exposes fifth turn card")
   if which=="sweep100":
    var pending=game.pending;var saved_preview=game.preview.duplicate(true);var saved_state=await saved()
    for panel in [game.hud.left_panel,game.hud.right_panel]:
     var handle=panel.find_child("DragHandle",true,false);var start=panel.position
     await os_mouse(handle.get_global_rect().get_center(),"drag",Vector2(handle.get_global_rect().get_center().x-40,root.size.y-40))
     check(panel.position!=start,"OS floating header still drags")
     for control in [node("BattleHistory"),node("BattleOrderDetails")]:check(not panel.get_global_rect().intersects(control.get_global_rect()),"OS drag respects protected bottom controls")
    check(game.pending==pending and game.preview==saved_preview and await saved()==saved_state,"OS scrolling and panel drag preserve prediction and save")
    await snapshot("F2-drag-1180")
    await os_resize(Vector2i(960,540));observe("F2-narrow",[node("BattleHistory"),node("BattleOrderDetails")])
    for panel in [game.hud.left_panel,game.hud.right_panel]:
     for control in [node("BattleHistory"),node("BattleOrderDetails")]:check(not panel.get_global_rect().intersects(control.get_global_rect()),"narrow parent keeps bottom controls clear")
    await snapshot("F2-narrow-960");await os_resize(Vector2i(1180,812))
 var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e","const C=require(process.argv[1]);process.stdout.write(JSON.stringify(C.gear.filter(g=>!g.virtualDefault&&g.type!=='empty'&&!g.id.startsWith('fist-')).map(g=>g.id)));",ProjectSettings.globalize_path("res://../native/campaign.js")]),output,true,false)
 town=original.duplicate(true);town.state.location="east";town.state.gold=500;town.state.characters.guard.inventory={"potion":3,"ether":2}
 for id in JSON.parse_string("".join(output)):town.state.characters.guard.inventory[id]=3
 await game.update({"op":"campaign_load","data":town});await enter_facility("shop");await settle();await os_click(node("PartyFace_guard"));game.dialog.window.size=Vector2i(1180,619);game.dialog.window.position=Vector2i(0,36);await settle()
 var list=node("OwnedEquipmentScroll");list.ensure_control_visible(node("OwnedEquipment_kungfu-pants"));await settle();await os_click(node("OwnedEquipment_kungfu-pants"));await os_click(node("InventoryDetails"));await os_click(node("SkillDetailsBack"))
 observe("F3-pants",[node("InventoryEquip"),node("InventoryList")]);await snapshot("F3-pants-1180x619")
 if not baseline:
  check(node("ModalDetailScroll").scroll_vertical==0,"pants controls need no outer scroll")
  await os_click(node("InventoryList"))
 else:game.pages.party_view.inventory_view.show_list();await settle()
 list=node("OwnedEquipmentScroll");list.ensure_control_visible(node("OwnedInventorySell_spear-wood"));await settle();await os_click(node("OwnedInventorySell_spear-wood"))
 var quantity=node("InventoryQuantity");await os_click(quantity.get_line_edit());await os_key("Home");await os_key("Delete");await os_key("2");await os_key("Return")
 before=await saved();await os_click(node("InventoryPrepareSale"));await os_click(node("InventoryCancel"))
 observe("F3-sale-NO",[node("InventoryQuantity"),node("InventorySaleTotals"),node("InventoryPrepareSale"),node("InventoryList")]);await snapshot("F3-sale-NO-1180x619")
 if not baseline:
  check(node("ModalDetailScroll").scroll_vertical==0 and game.pages.party_view.inventory_view.amount==2 and await saved()==before,"NO keeps quantity and save without outer scroll")
  await os_click(node("InventoryList"))
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all layout GUI audio OFF")
 var f=FileAccess.open(evidence.path_join("geometry.json"),FileAccess.WRITE);f.store_string(JSON.stringify(observations,"\t"));f.close()
 f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
