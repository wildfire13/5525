extends "res://tests/brushup_gui.gd"
func run():
 create_timer(240).timeout.connect(func():print("FAIL speech GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","real X11 rendering")
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var seed=await saved()
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
  root.size=dims;await settle()
  for spec in [["east","shop","weapon","buy"],["west","shop","armor","buy"],["south","shop","item","buy"],["north","shop","accessory","buy"],["astaris","party","guild","guild"],["astaris","inn","inn","inn"]]:
   var fixture=seed.duplicate(true);fixture.state.location=spec[0]
   await game.update({"op":"campaign_load","data":fixture});game.navigate(spec[1]);await settle()
   await create_timer(.9).timeout
   await snapshot(spec[2]+"-entry-"+str(dims.x))
   var before=await saved();await os_click(node("FacilityChoice_"+spec[3]))
   check(game.pages.facility_entry.view==spec[3],"OS facility choice usable with new speech "+spec[2]+str(dims.x))
   check(await saved()==before,"entry click has no canonical side effects")
   if dims.x>=1120:
    check(node("FacilityGreeting").get_global_rect().end.y<node("FacilityNpc").get_global_rect().position.y,"speech does not intersect portrait "+spec[2]+str(dims.x))
  if dims.x>=1120:
   for kind in ["normal","thought","shout"]:
    game.pages.facility_entry.render_dialogue("売る品物の持ち主を、下の人物から選んでください。",kind);await create_timer(1.2).timeout;await snapshot("speech-"+kind+"-"+str(dims.x))
 check(game.audio.muted.values().all(func(v):return v),"audio three OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
