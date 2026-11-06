extends SceneTree
var game
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func node(id):return game.find_child(id,true,false)
func settle():
 for i in range(12):await process_frame
 while game.locked or game.engine.busy or game.presenting:await process_frame
func capture(name_):
 if OS.get_environment("FACILITY_ART_CAPTURE").is_empty():return
 await create_timer(1.8).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("FACILITY_ART_CAPTURE").path_join(name_+".png"))
func run():
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var initial=(await game.engine.request({"op":"campaign_save"})).data
 for pair in [["astaris","party"],["astaris","inn"],["east","shop"],["west","shop"],["south","shop"],["north","shop"]]:
  var save=initial.duplicate(true);save.state.location=pair[0]
  await game.update({"op":"campaign_load","data":save});game.navigate(pair[1]);await settle()
  var label=pair[0]+"-"+pair[1]
  check(node("FacilityStill")!=null and node("FacilityStill").texture!=null,label+" adopted facility backdrop")
  check(node("FacilityNpc").size.y>=900,label+" prominent keeper")
  check(node("FacilityExit").get_global_rect().end.y<1080 and node("FacilityEntrySpeech").get_global_rect().end.x<=1920,label+" choices and speech fit FHD")
  await capture(label)
  node("FacilityExit").pressed.emit();await settle()
  check(game.page=="hub",label+" exit remains functional")
 game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.15).timeout;game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
