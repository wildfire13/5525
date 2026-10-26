extends "res://tests/skill_effects_gui.gd"
var observed_presentation=false
func capture_frame():
 if capturing and game.presenting:
  observed_presentation=true
  var texts=game.find_children("*","Label",true,false).filter(func(control):return control.is_visible_in_tree()).map(func(control):return control.text)
  texts.append_array(game.find_children("*","Button",true,false).filter(func(control):return control.is_visible_in_tree()).map(func(control):return control.text))
  check(not texts.has("演出中…") and not texts.has("処理中…"),"real presentation has no generic developer labels")
 super.capture_frame()
func run():
 create_timer(180).timeout.connect(func():print("FAIL debug battle watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=false;game.audio.fast_mode=true;await settle();var cases=cases_fx()
 RenderingServer.frame_post_draw.connect(capture_frame)
 for name_ in ["attackMelee","heal"]:await record_action(name_,cases[name_])
 check(observed_presentation,"actual presentation frames inspected")
 check(game.debug_view.entries.any(func(line):return line.contains("演出: ON")),"presentation state moved to diagnostics")
 check(game.audio.muted.values().all(func(v):return v),"audio three OFF")
 await snapshot("battle-after")
 for spec in [["clips.json",clips],["checks.json",checks]]:
  var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
