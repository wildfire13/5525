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
  var keeper=node("FacilityNpc")
  var viewport=Rect2(Vector2.ZERO,Vector2(root.size))
  var region_rect=keeper.get_parent().get_global_rect() if keeper!=null else Rect2()
  var keeper_rect=keeper.get_global_rect() if keeper!=null else Rect2()
  var speech_rect=node("FacilityEntrySpeech").get_global_rect()
  var choices_rect=node("FacilityChoices").get_global_rect()
  check(keeper is TextureRect and keeper.is_visible_in_tree() and keeper.texture!=null and viewport.encloses(region_rect) and region_rect.encloses(keeper_rect) and keeper_rect.size.y>=root.size.y*0.45 and keeper_rect.size.x>=root.size.x*0.35 and not region_rect.intersects(speech_rect) and not region_rect.intersects(choices_rect),label+" visible keeper fills right-side region without overlap")
  check(viewport.encloses(choices_rect) and viewport.encloses(speech_rect) and not choices_rect.intersects(speech_rect) and node("FacilityExit").get_global_rect().end.y<=972,label+" choices and speech fit FHD without overlap")
  await capture(label)
  node("FacilityExit").pressed.emit();await settle()
  check(game.page=="hub",label+" exit remains functional")
 game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.15).timeout;game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
