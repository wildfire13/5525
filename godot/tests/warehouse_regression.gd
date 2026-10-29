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
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
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
  check(button.get_global_rect().end.y<=dims.y,"transfer within window "+str(dims))
  await view.transfer_selected();await settle()
  check(int(game.campaign().warehouse.get("potion",0))==1,"deposit reaches campaign "+str(dims))
  var payload=view.drag("warehouse","potion")
  check(view.can_drop(payload,"character") and not view.can_drop(payload,"warehouse"),"drag only opposite side "+str(dims))
  await view.drop(payload,"character");await settle()
  check(game.campaign().warehouse.is_empty(),"drag withdrawal "+str(dims))
  check(not view.can_drop(payload,"character"),"consumed drag cannot replay "+str(dims))
  game.pages.party_view.portrait_pressed(str(game.campaign().selected[1]));await settle()
  check(view.owner_id==str(game.campaign().selected[1]) and game.pages.party_view.detail_uid.is_empty(),"bottom card changes inventory without modal "+str(dims))
  game.pages.facility_entry.back();await settle()
  check(game.pages.facility_entry.at_top(),"back to guild entrance "+str(dims))
 check(game.audio.muted.values().all(func(v):return v),"audio OFF")
 game.closing=true;await game.audio.finish_audio();await game.engine.finish_diagnostics();game.engine.close_engine();game.queue_free()
 for i in range(8):await process_frame
 quit(0 if checks.all(func(ok):return ok) else 1)
