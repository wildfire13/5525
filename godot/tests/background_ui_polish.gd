extends SceneTree
var game
var failures=[]
var output=OS.get_environment("POLISH_CAPTURE")
func _initialize():call_deferred("run")
func check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func settle():
 for i in range(20):await process_frame
 while game.locked or game.engine.busy:await process_frame
func shot(name):
 if output.is_empty():return
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func background():
 return game.backdrop_layer.get_child(0) if game.backdrop_layer.get_child_count()>0 else null
func run():
 root.size=Vector2i(1920,1080)
 if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 game.navigate("hub");await settle();var town=background().texture;var instance=background().get_instance_id()
 game.navigate("character");await settle()
 check(background().texture==town,"character retains current town background")
 check(background().get_instance_id()==instance,"background node reused between screens")
 check(is_equal_approx(game.find_child("PartyRoster",true,false).get_theme_stylebox("panel").bg_color.a,.9),"roster surface alpha90")
 check(game.theme.get_color("font_color","Label").a==1,"text stays opaque")
 await shot("01-town-character")
 game.navigate("party");await settle();var guild=background().texture
 game.navigate("character");await settle();check(background().texture==guild,"character retains guild background")
 await shot("02-guild-character")
 game.navigate("hub");await settle();check(background().texture==town,"leaving facility restores town background")
 var save=(await game.engine.request({"op":"campaign_save"})).data;save.state.location="east"
 await game.update({"op":"campaign_load","data":save});game.navigate("shop");await settle();var shop=background().texture
 game.navigate("character");await settle();check(background().texture==shop,"character retains shop background")
 game.pages.party_view.workspace.set_tab("ability");await settle();check(background().texture==shop,"ability tab keeps same background")
 game.navigate("board");await settle();check(background().texture==shop,"quest information retains place background")
 game.navigate("character");await settle();await shot("03-shop-character")
 var instance2=background().get_instance_id()
 for i in range(10):game.render();await settle()
 check(game.backdrop_layer.get_child_count()==2 and background().get_instance_id()==instance2,"redraw does not allocate or accumulate backdrops")
 save.state.location="west";await game.update({"op":"campaign_load","data":save});game.navigate("character");await settle()
 check(background().texture!=shop and background().name=="TownStill","changed location discards previous facility")
 await game.act("depart",["astaris","convoy"]);await settle()
 check(game.backdrop_layer.get_child_count()==0,"journey does not retain stale facility image")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
