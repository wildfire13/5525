extends "res://tests/inventory_header_261020.gd"
func contained(c: Control) -> bool:
 var w=c.get_window()
 return Rect2(Vector2.ZERO,Vector2(w.size)).encloses(c.get_global_rect()) and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(c.get_global_rect().position+Vector2(w.position),c.size))
func run():
 create_timer(150).timeout.connect(func():print("FAIL window resize watchdog");quit(2))
 root.size=Vector2i(1180,812);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var original=await saved();var town=original.duplicate(true);town.state.location="east"
 await game.update({"op":"campaign_load","data":town});game.navigate("shop");game.pages.party_view.open_detail("guard");await settle();await click("StatusTab_2");node("PartySkillDetails_guard").grab_focus();await click("PartySkillDetails_guard");var before=await saved()
 var detail=node("SkillDetailsWindow")
 for dims in [Vector2i(960,540),Vector2i(1180,812),Vector2i(1920,1080),Vector2i(960,540),Vector2i(1180,812)]:
  root.size=dims;await settle()
  check(node("SkillDetailsWindow")==detail and Rect2(Vector2.ZERO,Vector2(dims)).encloses(Rect2(Vector2(detail.position),Vector2(detail.size))),"already-open nested explanation fits resized parent "+str(dims))
  check(contained(node("SkillDetailsBack")) and contained(node("SkillDetailsSummary")),"fixed summary and back fit both child and parent "+str(dims))
  check(detail.min_size.y<=dims.y-36 and detail.min_size.y==(504 if dims.y==540 else 560),"preferred minimum adapts and restores "+str(dims))
  check(await saved()==before,"resize changes no campaign or owner "+str(dims))
 await click("SkillDetailsBack");check(node("PartySkillDetails_guard").has_focus(),"resize close restores new instance of same logical character skill button");game.dialog.close();await settle()
 # Long titles and summary still leave the fixed close action reachable.
 var copy=preload("res://skill_text.gd");var doc=copy.document("legSweep","長い足払いの名前".repeat(10),3,game.campaign())
 var extra=preload("res://skill_details.gd").new();game.add_child(extra);extra.configure(game,doc,"ガロ / 長い装備の名前".repeat(8));await settle();root.size=Vector2i(960,540);await settle()
 check(contained(node("SkillDetailsBack")) and contained(node("SkillDetailsSummary")),"long title context and sweep area leave footer inside 960x540")
 await click("SkillDetailsBack")
 # More than one managed child must update independently, including nested ones.
 var first=Window.new();game.add_child(first);game.preferences.bind_window(first,"resize-test-one",game.size,Vector2(800,650),Vector2(560,560));first.popup()
 var second=Window.new();first.add_child(second);game.preferences.bind_window(second,"resize-test-two",game.size,Vector2(620,630),Vector2(420,600));second.popup()
 for dims in [Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:
  root.size=dims;await settle()
  for w in [first,second]:check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(Rect2(Vector2(w.position),Vector2(w.size))) and w.min_size.y<=dims.y-36,"each nested managed window fits parent "+str(dims))
 second.hide();second.queue_free();first.hide();first.queue_free();await settle()
 game.preferences.store_rect("resize-reopen",Rect2(42,72,560,400))
 for i in range(3):
  var reopened=Window.new();game.add_child(reopened);game.preferences.bind_window(reopened,"resize-reopen",game.size,Vector2(560,400));reopened.popup();await settle()
  check(reopened.position==Vector2i(42,72),"reopening saved child does not add another title margin "+str(i))
  reopened.hide();reopened.queue_free();await settle()
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"resize regression keeps all audio OFF")
 var f=FileAccess.open(evidence.path_join("window-resize-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
