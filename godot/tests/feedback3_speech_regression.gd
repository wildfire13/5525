extends "res://tests/inventory_header_261020.gd"
## Isolated fixtures: art and typewriter never change canonical campaign state.
func run():
 create_timer(180).timeout.connect(func():print("FAIL speech watchdog");quit(2))
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var seed=await saved()
 var entry=game.pages.facility_entry
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;await settle()
  for spec in [["east","shop"],["west","shop"],["south","shop"],["north","shop"],["astaris","party"],["astaris","inn"]]:
   var fixture=seed.duplicate(true);fixture.state.location=spec[0]
   await game.update({"op":"campaign_load","data":fixture});game.navigate(spec[1]);await settle()
   var npc=node("FacilityNpc");var bubble=node("FacilityGreeting")
   check(npc!=null and bubble!=null,"portrait and speech present "+str(spec)+str(dims))
   check(bubble.get_global_rect().end.y<npc.get_global_rect().position.y,"entire NPC texture starts below speech including tail "+str(spec)+str(dims))
   check(bubble.mouse_filter==Control.MOUSE_FILTER_IGNORE and bubble.get_node("SpeechArtwork").mouse_filter==Control.MOUSE_FILTER_IGNORE,"speech never intercepts facility controls")
   var before=await saved();var rng=game.pages.facility_art.npc.rng.state
   for kind in ["normal","thought","shout"]:
    var text="これは文字送りと読みやすさを確認するための台詞です。"
    entry.render_dialogue(text,kind);var time=entry.speech_started;var current=node("FacilityGreeting")
    check(current.speech_kind==kind and current.get_node("SpeechArtwork").texture is AtlasTexture,"distinct graphic region "+kind)
    check(current.words.visible_characters<text.length(),"fresh speech begins partially revealed "+kind)
    await create_timer(.12).timeout
    entry.render_dialogue(text,kind);current=node("FacilityGreeting")
    check(entry.speech_started==time and current.words.visible_characters>0,"same speech rerender preserves reveal clock "+kind)
    current.started_usec=Time.get_ticks_usec()-10000000;current._process(0)
    check(current.words.visible_characters==text.length() and not current.is_processing(),"completed speech stops processing "+kind)
    check(current.get_global_rect().encloses(current.words.get_global_rect()),"text inside graphic bounds "+kind)
   check(await saved()==before and game.pages.facility_art.npc.rng.state==rng,"speech and redraw preserve exact save and NPC random stream")
 root.size=Vector2i(1920,1080);await settle();game.navigate("hub");game.navigate("inn");await settle()
 var prior=entry.speech_started;game.navigate("hub");await create_timer(.02).timeout;game.navigate("inn");await settle()
 check(entry.speech_started>prior,"new visit restarts dialogue")
 check(game.audio.muted.values().all(func(v):return v),"all audio OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
