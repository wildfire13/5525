extends "res://tests/skill_grant_hud.gd"
func warrior():return game.state().units.filter(func(u):return u.id=="warrior")[0]
func run():
 create_timer(100).timeout.connect(func():print("FAIL watchdog");quit(2))
 if OS.get_environment("NATIVE5525_AUDIO_OFF")!="1":quit(2);return
 var output=[]
 var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/updateplan_fixtures.cjs")]),output,true,false)
 check(code==0,"fixture creation")
 var fixtures=JSON.parse_string("".join(output))
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 await game.update({"op":"campaign_load","data":fixtures.town});await settle()
 check(game.roster().size()==24,"new roster has all 24 candidates")
 check(game.campaign().selected.size()<=12,"party limit preserved")
 for dims in [Vector2i(1920,1080)]:
  root.size=dims
  await game.update({"op":"campaign_load","data":fixtures.stamp});await settle()
  await game.select_skill("stamp");await settle();await game.on_cell(23);await settle()
  check(game.can_commit() and warrior().mp==1 and not warrior().has("pendingStamp"),"preview is free "+str(dims))
  await game.cancel();await settle()
  check(game.pending==null and warrior().mp==1,"cancel is free "+str(dims))
  await game.on_cell(23);await settle();await game.commit();await settle()
  check(warrior().mp==0 and warrior().has("pendingStamp"),"commit prepays exactly one MP "+str(dims))
  var save=(await game.engine.request({"op":"campaign_save"})).data
  await game.update({"op":"campaign_load","data":save});await settle()
  check(warrior().mp==0 and warrior().has("pendingStamp"),"load keeps prepaid reservation "+str(dims))
  for i in range(5):
   if not warrior().has("pendingStamp"):break
   await game.choose_command("guard");await settle();await game.commit();await settle()
  check(not warrior().has("pendingStamp") and warrior().mp==0,"zero MP automatic resolution no second charge "+str(dims))
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"audio OFF")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
 for i in range(8):await process_frame
 quit(0 if checks.all(func(ok):return ok) else 1)
