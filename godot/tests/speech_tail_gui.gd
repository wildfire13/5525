extends "res://tests/brushup_gui.gd"
## Every shipped keeper is selected explicitly in this presentation-only fixture.
func run():
 create_timer(420).timeout.connect(func():print("FAIL speech tail GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","real X11 rendering")
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var seed=await saved()
 var geometry=[]
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
  if OS.get_environment("TAIL_SMOKE")=="1" and dims.x!=1920:continue
  root.size=dims;await settle()
  for spec in [["east","shop","weapon1","buy"],["east","shop","weapon2","buy"],["west","shop","armor","buy"],["south","shop","item","buy"],["north","shop","accessory","buy"],["astaris","party","guild","guild"],["astaris","inn","inn","inn"]]:
   if OS.get_environment("TAIL_SMOKE")=="1" and spec[2]!="weapon1":continue
   var fixture=seed.duplicate(true);fixture.state.location=spec[0]
   await game.update({"op":"campaign_load","data":fixture});game.navigate(spec[1]);await settle()
   var npc=game.pages.facility_art.npc;npc.selected_path=npc.ROOT+spec[2]+".png";npc.texture=load(npc.selected_path);game.render();await settle()
   var before=await saved();var rng=npc.rng.state;var entry=game.pages.facility_entry
   for kind in ["normal","thought","shout"]:
    if dims.x>=1120:
     entry.render_dialogue("いらっしゃい。今日はどうしますか？",kind)
    else:
     var old=node("FacilityGreeting");var parent=old.get_parent();var index=old.get_index();parent.remove_child(old);old.queue_free()
     var bubble=entry.make_speech("いらっしゃい。今日はどうしますか？",kind);entry.fit_inline_speech(bubble);parent.add_child(bubble);parent.move_child(bubble,index)
    await settle();await create_timer(.8).timeout
    var bubble=node("FacilityGreeting");var art=bubble.get_node("SpeechArtwork");var portrait=node("FacilityNpc")
    check(not art.flip_h,"body and text stay unmirrored "+spec[2]+kind+str(dims.x))
    check(bubble.words.text=="いらっしゃい。今日はどうしますか？" and bubble.words.scale==Vector2.ONE,"text unchanged and unmirrored")
    check(bubble.mouse_filter==Control.MOUSE_FILTER_IGNORE and art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"decoration does not capture input")
    if portrait!=null:
     check(portrait.texture==npc.texture and bubble.get_global_rect().end.y<portrait.get_global_rect().position.y,"original keeper and no speech overlap "+spec[2]+kind)
     if kind!="shout":
      var direction=(bubble.pointer_tip-bubble.pointer_base).normalized();var target=(bubble.speaker_target-bubble.pointer_base).normalized()
      check(direction.dot(target)>.9999,"pointer extends exactly toward mouth "+spec[2]+kind)
      check(bubble.pointer.visible,"visible speaker gets directional pointer")
    else:
     check(not bubble.speaker_visible and (bubble.get_node_or_null("SpeechBodyLower")!=null)==(kind!="shout"),"compact no-speaker body has no tail or thought trail")
    geometry.append({"npc":spec[2],"kind":kind,"size":[dims.x,dims.y],"bubble":[bubble.position.x,bubble.position.y,bubble.size.x,bubble.size.y],"text":[bubble.words.position.x,bubble.words.position.y,bubble.words.size.x,bubble.words.size.y],"mouth":[bubble.speaker_target.x,bubble.speaker_target.y],"base":[bubble.pointer_base.x,bubble.pointer_base.y],"tip":[bubble.pointer_tip.x,bubble.pointer_tip.y]})
    await snapshot(spec[2]+"-"+kind+"-"+str(dims.x))
   await os_click(node("FacilityChoice_"+spec[3]));check(entry.view==spec[3],"OS facility choice works after graphics "+spec[2]+str(dims.x))
   check(await saved()==before and npc.rng.state==rng,"graphics and click preserve save and visit RNG")
 check(game.audio.muted.values().all(func(v):return v),"all audio OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 f=FileAccess.open(evidence.path_join("geometry.json"),FileAccess.WRITE);f.store_string(JSON.stringify(geometry,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
