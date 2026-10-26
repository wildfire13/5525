extends "res://tests/research2_gui.gd"
## Actual OS drag and NO input; root runner owns the X11 display.
var baseline=OS.get_environment("UI_P3_BASELINE")=="1"
var probes=[]
func equipment_slot(slot: String):
 return node("EquipmentSlots").get_children().filter(func(b):return b.get_meta("ui_key","")=="equipment_"+slot)[0]
func actual_drag(slot: String,label: String,known_baseline_failure:=false):
 var source=node("OwnedEquipment_spear-wood");var target=equipment_slot(slot)
 var start=source.get_global_rect().get_center()+Vector2(source.get_window().position)
 var end=target.get_global_rect().get_center()+Vector2(target.get_window().position)
 await os_mouse(start,"drag",end)
 var inv=game.pages.party_view.inventory_view
 var opened=inv.stage=="confirm" and is_instance_valid(inv.confirmation) and inv.confirmation.visible
 probes.append({"label":label,"confirmation_open":opened,"stage":inv.stage,"quote":inv.quote.duplicate(true),"start":str(start),"end":str(end)})
 if baseline and known_baseline_failure:check(not opened,"baseline reproduced real OS blocked re-drag "+label)
 else:
  check(opened,"actual OS drag opens visible consent "+label)
  check(inv.quote.get("ownerId")=="guard" and inv.quote.get("itemId")=="spear-wood" and inv.quote.get("slot")==slot and inv.quote.get("ok",false),"actual OS consent identifies canonical owner item and hand "+label)
 await snapshot("p3-"+label)
 if opened:await os_click(node("InventoryCancel"))
 return opened
func choose_right_hand():
 var chooser=node("OwnedEquipmentSlot");var wanted=-1
 for index in range(chooser.item_count):
  if chooser.get_item_metadata(index)=="rightHand":wanted=index
 check(wanted>=0,"canonical right-hand category exists")
 await os_click(chooser)
 var popup=chooser.get_popup()
 check(popup.visible,"OS opens inventory category popup")
 var steps=0
 while popup.visible and popup.get_focused_item()!=wanted and steps<chooser.item_count+1:
  await os_key("Down");steps+=1
 print("P3_CATEGORY focused=",popup.get_focused_item()," wanted=",wanted," keys=",steps)
 check(popup.visible and popup.get_focused_item()==wanted,"actual OS keys focus canonical right-hand category")
 await os_key("Return")
 check(game.pages.party_view.owned_equipment_view.slot=="rightHand","OS selector chooses right-hand comparison")
func run():
 create_timer(300).timeout.connect(func():print("FAIL P3 OS watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","P3 uses rendered display and real OS mouse input")
 var width=int(OS.get_environment("BRUSHUP_GUI_WIDTH"));width=1180 if width==0 else width
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(width,812 if width==1180 else 1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var seed=await saved();seed.state.location="east";seed.state.characters.guard.inventory={"spear-wood":2,"potion":2}
 await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");await settle()
 await os_click(node("PartyFace_guard"));var before=await saved()
 await actual_drag("rightHand","initial")
 check(await saved()==before,"actual OS first NO preserves complete save")
 await actual_drag("rightHand","repeat",width==1180)
 await actual_drag("leftHand","other-hand",width==1180)
 await os_key("Escape");await os_click(node("PartyFace_guard"))
 await actual_drag("rightHand","reopened")
 # Select the canonical hand using native keyboard input, then hover comparison.
 await choose_right_hand()
 var action=node("OwnedEquipmentActions_spear-wood")
 await os_mouse(action.get_global_rect().get_center()+Vector2(action.get_window().position));await create_timer(.4).timeout;await settle()
 var hover=game.pages.party_view.owned_equipment_view.hover_window
 check(hover.visible,"OS pointer opens comparison")
 var source=node("OwnedEquipment_spear-wood")
 var covered=Rect2(Vector2(hover.position),Vector2(hover.size)).intersects(Rect2(Vector2(source.get_window().position)+source.get_global_rect().position,source.size))
 probes.append({"label":"hover","source_covered":covered,"hover_rect":str(Rect2(Vector2(hover.position),Vector2(hover.size)))})
 if not baseline:check(not covered,"comparison keeps same item's name and drag origin unobscured")
 await snapshot("p3-hover")
 await actual_drag("rightHand","hover-drag",baseline and covered)
 check(await saved()==before,"all OS cancelled drags preserve exact save")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"P3 OS BGM voice and SE remain OFF")
 var file=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
 file=FileAccess.open(evidence.path_join("p3-probes.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"probes":probes,"baseline":baseline},"\t"));file.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
