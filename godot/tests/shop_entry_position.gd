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
  var cell=Vector2(root.size)/10
  var viewport=Rect2(Vector2.ZERO,Vector2(root.size))
  var region_rect=portrait.get_parent().get_global_rect()
  var speech_rect=speech.get_global_rect()
  var choices_rect=choices.get_global_rect()
  check(region_rect==Rect2(cell*Vector2(6,4),cell*Vector2(4,5)) and portrait.get_global_rect()==region_rect and viewport.encloses(region_rect),label+" portrait fills reserved lower-right grid region")
  check(speech_rect==Rect2(cell*Vector2(6,2),cell*Vector2(4,2)) and viewport.encloses(speech_rect) and not speech.words.text.is_empty(),label+" speech occupies upper-right region above keeper")
  check(not speech_rect.intersects(choices_rect) and not region_rect.intersects(choices_rect),label+" choices separate from speech and keeper")
  check(speech_rect.end.y<=region_rect.position.y and not speech_rect.intersects(region_rect),label+" speech stays clear above keeper face")
  if not output.is_empty():
   await create_timer(2).timeout;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join(label+"-entry.png"))
  node("FacilityChoice_"+service).pressed.emit();await settle()
  check(game.pages.facility_entry.view==service,label+" service choice works")
  game.pages.facility_entry.back();await settle();node("FacilityExit").pressed.emit();await settle()
  check(game.page=="hub",label+" exit works")
 game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
