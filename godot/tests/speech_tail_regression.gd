extends SceneTree
var checks=[]
func check(value: bool,label: String):
 checks.append({"passed":value,"label":label});print(("PASS " if value else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
 var Bubble=load("res://speech_bubble.gd")
 for kind in ["normal","thought","shout"]:
  for dims in [Vector2(480,160),Vector2(295,160),Vector2(420,110)]:
   var bubble=Bubble.new();bubble.configure("読み順と文字送りを保持します。",kind,Time.get_ticks_usec()-100000);root.add_child(bubble);bubble.custom_minimum_size=Vector2.ZERO;bubble.size=dims
   await process_frame
   var text_rect=bubble.words.get_rect();var started=bubble.started_usec
   check(not bubble.artwork.flip_h,"body and text orientation preserved "+kind+str(dims))
   for mouth in [Vector2(40,400),Vector2(240,300),Vector2(470,600)]:
    bubble.point_to(mouth)
    if kind!="shout":
     check((bubble.pointer_tip-bubble.pointer_base).normalized().dot((mouth-bubble.pointer_base).normalized())>.9999,"pointer aims exactly at left/center/right mouth")
     if kind=="normal":
      var tail=bubble.pointer.get_child(0);var ratio=bubble.pointer_base.distance_to(bubble.pointer_tip)/Bubble.TAIL_BASE.distance_to(Bubble.TAIL_TIP)
      var actual=tail.position+((Bubble.TAIL_TIP-Bubble.TAIL_BASE)*ratio).rotated(tail.rotation)
      check(actual.distance_to(bubble.pointer_tip)<.01,"actual texture tip equals mouth-directed endpoint")
   bubble.set_speaker_visible(false);await process_frame
   check(not bubble.speaker_visible and bubble.words.get_rect()==text_rect and bubble.started_usec==started,"no speaker changes neither text region nor reveal clock")
   if kind=="shout":
    check(bubble.pointer==null and bubble.artwork.texture.region==Bubble.REGIONS[kind],"shout has no invented pointer")
   else:
    check(not bubble.pointer.visible and bubble.body_lower.visible and bubble.body_lower.flip_v,"compact has closed body without pointer")
    check(is_equal_approx(bubble.artwork.get_rect().end.y,bubble.body_lower.position.y) and is_equal_approx(bubble.body_lower.get_rect().end.y,dims.y),"closed halves meet with no gap or overlap")
   bubble.set_speaker_visible(false);bubble.set_speaker_visible(true);await process_frame
   check(kind=="shout" or bubble.pointer.visible,"repeated compact/wide switching restores pointer")
   check(bubble.words.text=="読み順と文字送りを保持します。" and bubble.words.scale==Vector2.ONE,"Japanese content and direction unchanged")
   bubble.queue_free();await process_frame
 var output=OS.get_environment("INVENTORY_QA_ROOT")
 if not output.is_empty():
  var f=FileAccess.open(output.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 quit(0 if checks.all(func(c):return c.passed) else 1)
