extends "res://tests/ui_feedback_20261016.gd"
## Presentation receipt tests use only successful native replies, isolated profiles.
func fixture() -> Dictionary:
 var output=[];var exit=OS.execute(OS.get_environment("NATIVE5525_NODE"),[ProjectSettings.globalize_path("res://tests/results_fixtures.cjs")],output,true,false)
 check(exit==0,"result fixtures pass canonical native validation")
 return JSON.parse_string("".join(output))
func load_case(value: Dictionary):
 var reply=await game.update({"op":"campaign_load","data":value});await settle();check(reply.get("ok",false),"canonical saved result boundary loads")
func run():
 create_timer(150).timeout.connect(func():print("FAIL results watchdog");quit(2))
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var cases=fixture();var view=game.results_view
 for asset in ["battle-crest","quest-crest"]:
  var texture=load("res://assets/results/"+asset+".png");check(texture!=null and texture.get_size()==Vector2(640,768),"dedicated original result graphic imports without placeholder "+asset)
 await load_case(cases.victory);check(not view.active,"battle reward is not fabricated before finishBattle commits")
 var before=await saved();var reply=await game.update({"op":"campaign","action":"finishBattle","args":[]});await settle()
 check(reply.get("ok",false) and view.active and view.current.kind=="battle","successful finishBattle opens a distinct battle receipt")
 var after=await saved();check(after.state==cases.finished.state,"result display preserves exact canonical final save")
 check(view.current.gold_gain==cases.battle_after.gold-cases.battle_before.gold and view.current.gold_after==cases.battle_after.gold,"battle gold uses actual successful reply delta")
 check(view.current.members.size()==cases.battle_before.selected.size(),"battle receipt identifies only canonical growth participants")
 for row in view.current.members:
  var a=cases.battle_before.roster.filter(func(m):return m.id==row.id)[0];var b=cases.battle_after.roster.filter(func(m):return m.id==row.id)[0]
  check(row.xp_gain==b.xp-a.xp and row.level_before==a.level and row.level_after==b.level,"exact growth before/after "+row.id)
 var sequence=view.sequence;await game.update({"op":"campaign","action":"finishBattle","args":[]});await settle()
 check(await saved()==after and view.sequence==sequence,"repeat finish cannot grant again or duplicate the receipt")
 view.advance();await settle();check(not view.active and await saved()==after,"closing battle receipt is UI-only")
 for i in range(3):
  view.reopen();await frames();check(view.active and view.current.kind=="battle","read-only receipt reopens")
  view.advance();await settle();check(await saved()==after,"read-only reopen and close cannot grant rewards")
 await load_case(after);check(not view.active and view.recent.is_empty(),"reload does not invent a transient battle receipt")
 for key in ["normal","late"]:
  await load_case(cases[key].ready);var ready=await saved();check(not view.active,"arrival alone has no quest completion receipt")
  await game.update({"op":"campaign","action":"completeQuest","args":[]});await settle()
  check(view.active and view.current.kind=="quest","completeQuest opens quest-specific receipt "+key)
  var completed=await saved();check(completed.state==cases[key].result.state,"quest receipt leaves canonical reward result unchanged "+key)
  check(view.current.gold_gain==cases[key].after.gold-cases[key].before.gold and view.current.outcome==cases[key].after.result.outcome,"normal/late use exact committed gold and outcome "+key)
  check(not view.current.restored and view.current.members.all(func(m):return m.xp_before!=null),"live quest receipt retains observed growth before values")
  view.advance();await settle();check(not view.active and game.campaign().phase=="town" and game.campaign().gold==completed.state.gold,"quest continue acknowledges once without additional reward")
  var town=await saved();view.reopen();await frames();view.advance();await settle();check(await saved()==town,"replaying a quest receipt cannot acknowledge or reward again")
  await load_case(cases[key].result);check(view.active and view.current.restored and view.current.members.all(func(m):return m.level_before==null),"saved quest result shows exact receipt and no invented prior level")
  check(view.current.gold_gain==cases[key].result.state.result.gold,"saved quest result uses persisted reward amount")
  view.advance();await settle()
 await load_case(cases.defeat);await game.update({"op":"campaign","action":"finishBattle","args":[]});await settle()
 check(not view.active and game.campaign().result.outcome=="failed","defeat never opens victory receipt")
 await load_case(cases.victory);await game.update({"op":"campaign","action":"retreat","args":[]});await settle();check(not view.active,"invalid retreat from finished battle does not create a receipt")
 await load_case(cases.normal.result)
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;await frames(12)
  print("RESULT_LAYOUT ",dims," panel ",view.panel.get_global_rect()," min ",view.panel.get_combined_minimum_size()," body ",view.body.size," controls ",view.continue_button.get_global_rect()," save ",view.save_button.get_global_rect()," children ",view.body.get_children().map(func(c):return [str(c.name),str(c.size),str(c.get_combined_minimum_size())]))
  var bounds=Rect2(Vector2.ZERO,Vector2(dims));check(bounds.encloses(view.panel.get_global_rect()),str(dims)+" result panel remains inside game viewport")
  check(bounds.encloses(view.continue_button.get_global_rect()) and bounds.encloses(view.save_button.get_global_rect()),str(dims)+" fixed primary/save actions remain visible")
  for gain in view.shade.find_children("ResultGain_*","Label",true,false):check(gain.size.x>=128 and gain.autowrap_mode==TextServer.AUTOWRAP_OFF,str(dims)+" growth amount remains one readable line "+str(gain.name))
  check(view.panel.get_global_rect().encloses(view.continue_button.get_global_rect()),str(dims)+" primary action stays within result frame")
 check(game.audio.muted.values().all(func(v):return v),"result QA BGM voice SE OFF")
 var f=FileAccess.open(evidence.path_join("results-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;view.reset();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
