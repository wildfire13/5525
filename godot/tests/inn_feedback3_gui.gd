extends "res://tests/brushup_gui.gd"
func inn_consent():
 for d in game.find_children("*","ConfirmationDialog",true,false):
  if d.visible:return d
 return null
func reveal(control):
 var scroll=control.get_parent()
 while scroll!=null and not scroll is ScrollContainer:scroll=scroll.get_parent()
 if scroll!=null:scroll.ensure_control_visible(control)
 await frames(14)
func run():
 create_timer(240).timeout.connect(func():print("FAIL inn GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","actual X11 rendered inn")
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var seed=await saved();seed.state.gold=500;seed.state.characters.guard.hp=1;seed.state.characters.archer.mp=0
 await game.update({"op":"campaign_load","data":seed});game.navigate("inn");await settle();await os_click(node("FacilityChoice_inn"))
 var before=await saved();await os_click(node("InnStay"));await snapshot("inn-confirm-FHD");check(inn_consent()!=null,"OS stay confirmation")
 await os_click(inn_consent().get_cancel_button());check(await saved()==before,"OS cancel preserves exact save")
 await os_click(node("InnStay"));await os_click(inn_consent().get_ok_button());await snapshot("inn-recovery-FHD")
 check(game.campaign().gold==470 and game.campaign().characters.guard.hp==180,"OS confirm commits one charge and healing")
 await create_timer(1.3).timeout;await snapshot("inn-rested-FHD")
 before=await saved();await os_click(node("InnStay"));check(await saved()==before and game.pages.inn_view.dialogue==game.pages.inn_view.FULL_GREETING,"OS full party click uses free dedicated dialogue")
 var ids=[]
 for u in game.roster():ids.append(u.id)
 await game.act("select",[ids]);await settle()
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
  root.size=dims;game.render();await settle();await snapshot("inn-eleven-"+str(dims.x))
  var grid=node("InnParty");check(grid.columns==6 and grid.get_child_count()==11,"OS six columns eleven canonical members "+str(dims.x))
  var phantom=grid.get_child(0).duplicate();grid.add_child(phantom);await frames(12);await snapshot("inn-twelve-presentation-"+str(dims.x))
  check(grid.get_child(11).position.y==grid.get_child(6).position.y,"OS twelfth presentation card second row "+str(dims.x))
  await reveal(node("InnStay"));await snapshot("inn-stay-visible-"+str(dims.x));await os_click(node("InnStay"));check(inn_consent()==null,"OS free stay reachable "+str(dims.x))
  await os_click(node("InnReturn"));check(game.pages.facility_entry.at_top(),"OS return reaches inn entry "+str(dims.x));await os_click(node("FacilityChoice_inn"))
 check(game.audio.muted.values().all(func(v):return v),"inn GUI audio3 OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
