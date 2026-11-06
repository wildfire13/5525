extends SceneTree
var game
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func node(id):return game.find_child(id,true,false)
func settle():
 for i in range(16):await process_frame
 while game.locked or game.engine.busy or game.presenting:await process_frame
func run():
 create_timer(100).timeout.connect(func():print("FAIL watchdog");quit(2))
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var initial=(await game.engine.request({"op":"campaign_save"})).data
 var output=OS.get_environment("SHOP_ENTRY_CAPTURE")
 if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
 for entry in [["east","shop","buy"],["west","shop","buy"],["south","shop","buy"],["north","shop","buy"],["astaris","party","guild"],["astaris","inn","inn"]]:
  var town=entry[0];var page=entry[1];var service=entry[2];var label=town+"-"+page
  var save=initial.duplicate(true);save.state.location=town
  await game.update({"op":"campaign_load","data":save});game.navigate(page);await settle()
  var portrait=node("FacilityNpc");var speech=node("FacilityEntrySpeech");var choices=node("FacilityChoices")
  check(game.find_children("FacilityNpc","TextureRect",true,false).size()==1,label+" single current keeper")
  check(portrait.global_position.x>1000 and abs(portrait.size.y-1080*1.28)<2,label+" A right portrait framing")
  check(speech.get_global_rect().get_center().distance_to(Vector2(960,540))<2,label+" speech centered")
  check(not speech.get_global_rect().intersects(choices.get_global_rect()),label+" choices separate from speech")
  var mouth=game.pages.facility_art.npc.mouth_anchor(node("FacilityEntryArt"))
  check(mouth.x>speech.get_global_rect().end.x,label+" face clear of speech")
  if not output.is_empty():
   await create_timer(2).timeout;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join(label+"-entry.png"))
  node("FacilityChoice_"+service).pressed.emit();await settle()
  check(game.pages.facility_entry.view==service,label+" service choice works")
  game.pages.facility_entry.back();await settle();node("FacilityExit").pressed.emit();await settle()
  check(game.page=="hub",label+" exit works")
 game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
