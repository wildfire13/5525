extends "res://tests/skill_grant_hud.gd"
func run():
 create_timer(90).timeout.connect(func():print("FAIL watchdog");quit(2))
 if OS.get_environment("NATIVE5525_AUDIO_OFF")!="1":quit(2);return
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 await game.update({"op":"campaign_start"});await settle()
 # Isolated fixture: explicitly seed inventory; production new recruits are empty.
 var save=(await game.engine.request({"op":"campaign_save"})).data
 save.state.characters[save.state.selected[0]].inventory={"potion":3}
 await game.update({"op":"campaign_load","data":save});await settle()
 for dims in [Vector2i(1920,1080),Vector2i(1280,720)]:
  await game.update({"op":"campaign_load","data":save});await settle()
  root.size=dims;game.navigate("party");await settle()
  game.pages.facility_entry.choose("warehouse");await settle()
  var view=game.pages.warehouse_view
  check(view.available() and not game.pages.guild_view.available(),"warehouse mode distinct from guild "+str(dims))
  var owner=str(game.campaign().selected[0]);view.select_owner(owner);await settle()
  var control=game.find_child("WarehouseItem_character_potion",true,false)
  check(control!=null,"inventory potion row "+str(dims))
  control.pressed.emit();await settle()
  var button=game.find_child("WarehouseTransfer",true,false)
  check(button!=null and not button.disabled,"deposit enabled "+str(dims))
  var outer=game.find_child("MemberWorkspaceScroll",true,false)
  outer.ensure_control_visible(button);await settle()
  check(outer.get_global_rect().encloses(button.get_global_rect()) and button.get_global_rect().end.y<=dims.y,"transfer within window "+str(dims))
  await view.transfer_selected();await settle()
  check(int(game.campaign().warehouse.get("potion",0))==1,"deposit reaches campaign "+str(dims))
  var stored=game.find_child("WarehouseItem_warehouse_potion",true,false)
  check(view.source=="warehouse" and stored.get_meta("selected"),"deposit selects the destination "+str(dims))
  outer=game.find_child("MemberWorkspaceScroll",true,false)
  check(outer.get_global_rect().encloses(stored.get_global_rect()),"deposit reveals row in window "+str(dims))
  if not OS.get_environment("WAREHOUSE_CAPTURE").is_empty():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("WAREHOUSE_CAPTURE").path_join("warehouse-deposit-%dx%d.png" % [dims.x,dims.y]))
  var payload=view.drag("warehouse","potion")
  check(view.can_drop(payload,"character") and not view.can_drop(payload,"warehouse"),"drag only opposite side "+str(dims))
  await view.drop(payload,"character");await settle()
  check(game.campaign().warehouse.is_empty(),"drag withdrawal "+str(dims))
  check(not view.can_drop(payload,"character"),"consumed drag cannot replay "+str(dims))
  view.set_filter("items","warehouse");await settle()
  view.set_filter("items","character");await settle()
  view.set_tab("equipment");await settle()
  game.find_child("WarehouseSlot_rightHand",true,false).pressed.emit();await settle()
  var obsolete=view.quote_context
  var old_ticket=view.quote_generation
  view.select_owner(str(game.campaign().selected[1]));await settle()
  await view.refresh_unequip_quote(old_ticket,obsolete)
  check(view.unequip_quote.is_empty(),"previous owner quote discarded")
  view.select_owner(owner);await settle()
  game.find_child("WarehouseSlot_upperBody",true,false).pressed.emit()
  game.find_child("WarehouseSlot_rightHand",true,false).pressed.emit();await settle()
  check(view.unequip_quote.get("slot")=="rightHand","latest selected slot owns quote")
  var sword=view.item_id
  var remove=game.find_child("WarehouseUnequip",true,false)
  check(remove!=null and not remove.disabled,"equipped weapon can be removed")
  view.unequip();view.unequip();view.select_owner(str(game.campaign().selected[1]));await settle()
  check(view.owner_id==owner and view.tab=="inventory" and view.source=="character" and view.item_id==sword,"unequip reveals item for original owner")
  check(int(game.campaign().characters[owner].inventory.get(sword,0))==1,"repeated unequip moves one sword")
  view.set_tab("equipment");await settle()
  game.find_child("WarehouseSlot_upperBody",true,false).pressed.emit();await settle()
  var quoted=view.unequip_quote
  check(quoted.has("ok") and game.find_child("WarehouseUnequip",true,false).disabled==not quoted.ok,"full inventory uses native unequip decision")
  check(game.find_child("WarehouseReason",true,false).text==quoted.reason,"native unequip reason shown unchanged")
  view.set_tab("inventory");await settle()
  view.choose("character",sword);await settle();await view.transfer_selected();await settle()
  check(view.source=="warehouse" and view.item_id==sword and view.filters.warehouse=="all","deposited sword is revealed despite old filter")
  view.set_filter("rightHand","warehouse");await settle()
  check(game.find_child("WarehouseItem_warehouse_"+sword,true,false)!=null,"storage filters equipped weapon by part")
  view.set_filter("items","warehouse");await settle()
  check(game.find_child("WarehouseItem_warehouse_"+sword,true,false)==null,"consumable filter excludes weapon")
  var full=(await game.engine.request({"op":"campaign_save"})).data
  full.state.characters[owner].inventory={"potion":2,"ether":1}
  await game.update({"op":"campaign_load","data":full})
  game.navigate("party");game.pages.facility_entry.choose("warehouse");await settle()
  view.select_owner(owner);view.choose("warehouse",sword);await settle()
  check(game.find_child("WarehouseTransfer",true,false).disabled and not game.find_child("WarehouseReason",true,false).text.is_empty(),"full bag rejects warehouse withdrawal with a reason")
  game.pages.party_view.portrait_pressed(str(game.campaign().selected[1]));await settle()
  check(view.owner_id==str(game.campaign().selected[1]) and game.pages.party_view.detail_uid.is_empty(),"bottom card changes inventory without modal "+str(dims))
  game.pages.facility_entry.back();await settle()
  check(game.pages.facility_entry.at_top(),"back to guild entrance "+str(dims))
 check(game.audio.muted.values().all(func(v):return v),"audio OFF")
 game.closing=true;await game.audio.finish_audio();await game.engine.finish_diagnostics();game.engine.close_engine();game.queue_free()
 for i in range(8):await process_frame
 quit(0 if checks.all(func(ok):return ok) else 1)
