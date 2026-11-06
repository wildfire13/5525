extends SceneTree
var game
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func settle():
 for i in range(15):await process_frame
 while game.engine.busy or game.locked:await process_frame
func run():
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var uid=str(game.campaign().selected[0]);var save=(await game.engine.request({"op":"campaign_save"})).data
 save.state.characters[uid].inventory={"javelin-wood":1,"potion":2}
 await game.update({"op":"campaign_load","data":save});game.navigate("character");await settle()
 var ws=game.pages.party_view.workspace;ws.set_tab("inventory");await settle()
 for id in ["javelin-wood","potion"]:
  ws.picked=game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id==id)[0];game.render();await settle()
  game.find_child("CharacterItemDetails",true,false).pressed.emit();await settle()
  var window=game.find_child("SkillDetailsWindow",true,false)
  check(window!=null and window.visible,id+" detailed explanation opens")
  var texts=[]
  for n in window.find_children("*","",true,false):
   if n is Label or n is RichTextLabel:texts.append(n.text)
  var text="\n".join(texts)
  check(text.contains("戦闘後に回収") if id=="javelin-wood" else text.contains("55"),id+" actual mechanical detail present")
  if not OS.get_environment("CHARACTER_DETAILS_CAPTURE").is_empty():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("CHARACTER_DETAILS_CAPTURE").path_join(id+"-detail.png"))
  window.queue_free();await settle()
 ws.set_tab("ability");await settle()
 var attack=game.find_child("CharacterAttackProfile",true,false)
 check(attack.tooltip_text.contains("距離1") and attack.tooltip_text.contains("属性ATK"),"attack tooltip includes complete distance profile")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
