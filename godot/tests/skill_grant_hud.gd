extends SceneTree
# Programmatic real controls + bridge, not OS-input or visual certification.
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks.append(ok);print(("PASS " if ok else "FAIL ")+label)
func settle():
 for i in range(12):await process_frame
 while game.locked or game.engine.busy or game.presenting or game.preview_pending:await process_frame
func skill_buttons():
 return game.find_children("BattleSkill_mage*","Button",true,false)
func run():
 create_timer(90).timeout.connect(func():print("FAIL watchdog");quit(2))
 if OS.get_environment("NATIVE5525_AUDIO_OFF")!="1":push_error("Audio OFF required");quit(2);return
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.checks_fast=true;game.audio.fast_mode=true
 await preload("res://tests/current_historical_fixture.gd").install(game);await settle()
 var save=(await game.engine.request({"op":"campaign_save"})).data
 save.state.location="east";save.state.gold=9999
 await game.update({"op":"campaign_load","data":save})
 await game.update({"op":"campaign","action":"buyGear","args":["mage","staff-silver-1","leftHand"]})
 await game.update({"op":"campaign","action":"trial","args":["mage","staff-wood","rightHand"]});await settle()
 for size in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
  root.size=size;game.render();await settle();game.hud.open_skills();await settle()
  var buttons=skill_buttons()
  check(buttons.size()==2,"two heal controls at "+str(size))
  if buttons.size()==2:
   check(buttons[0].icon!=null and buttons[1].icon!=null,"effect ID icons exist at "+str(size))
   check(buttons.any(func(b):return b.text.contains("右手")) and buttons.any(func(b):return b.text.contains("左手")),"source labels at "+str(size))
   check(buttons.all(func(b):return b.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART),"long source labels wrap at "+str(size))
 var choices=game.data.skillset.filter(func(o):return o.id=="mage")
 await game.select_skill(choices[1].key);await settle()
 check(game.hud.acting().selectedSkillKey==choices[1].key,"second source selected through UI")
 await game.update({"op":"act","kind":"skill","target":"guard"});await settle()
 game.hud.open_skills();await settle()
 var buttons=skill_buttons()
 check(buttons.size()==2 and buttons.filter(func(b):return b.disabled).size()==1,"only used source disabled")
 check(buttons.any(func(b):return b.text.contains("クールタイム中")),"cooldown readable as text")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all audio OFF")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
 for i in range(8):await process_frame
 quit(0 if checks.all(func(ok):return ok) else 1)
