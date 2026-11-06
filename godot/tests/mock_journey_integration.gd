extends SceneTree
# UI journey integration. Battles are entered normally; only victory boundaries
# are synthetic, so this does not claim a tactical playthrough.
var game
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func settle():
 for i in range(12):await process_frame
 while game.locked or game.engine.busy or game.presenting:await process_frame
 for i in range(8):await process_frame
func capture(label):
 if OS.get_environment("MOCK_FLOW_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("MOCK_FLOW_CAPTURE").path_join(label+".png"))
func synthetic_victory():
 var save=(await game.engine.request({"op":"campaign_save"})).data
 for unit in save.state.battle.units:
  if unit.side=="enemy":unit.hp=0
 save.state.battle.actor=null;save.state.battle.result="勝利！ 街道を切り抜けた。"
 await game.update({"op":"campaign_load","data":save});await settle()
 await game.act("finishBattle",[]);await settle()
 if game.results_view.active:game.results_view.continue_button.pressed.emit()
 await settle()
func run():
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 var deadline=Time.get_ticks_msec()+20000
 while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 if game.data.is_empty():quit(2);return
 game.checks_fast=true;game.audio.fast_mode=true
 check(game.campaign().phase=="town" and game.campaign().activeQuest==null,"new campaign begins without accepted quest")
 game.navigate("board");await settle()
 game.find_child("QuestAccept",true,false).pressed.emit();await settle()
 var choices=game.find_child("QuestCargoChoices",true,false)
 check(choices!=null,"quest accept opens porter selection")
 var porter=choices.find_children("QuestCargoOwner_*","Button",true,false)[0]
 porter.pressed.emit();game.find_child("QuestCargoConfirm",true,false).pressed.emit();await settle()
 check(game.campaign().activeQuest is Dictionary,"UI accept persists quest and selected cargo owner")
 game.navigate("map");await settle()
 game.find_child("DepartButton",true,false).pressed.emit();await settle()
 check(game.campaign().phase=="road","departure enters road")
 game.find_child("TravelQuestDetails",true,false).pressed.emit();await settle()
 check(game.find_child("QuestDetailActions",true,false)!=null,"active quest detail reachable during journey")
 game.navigate("map");await settle()
 check(game.find_child("RouteChoices",true,false)!=null,"map navigation returns to route choices")
 await game.act("travel",["short"]);await settle()
 check(game.campaign().phase=="deployment","outbound route enters deployment")
 check(game.theme.get_color("font_color","Label").r>.7,"battle restores light text on dark theme")
 print("BATTLE_FONT ",game.theme.default_font_size)
 await capture("flow-deployment")
 await game.act("begin",[]);await settle()
 check(game.campaign().phase=="battle","deployment begins battle")
 await synthetic_victory()
 check(game.campaign().phase=="camp","synthetic victory boundary returns to camp")
 game.navigate("map");await settle()
 check(game.theme.get_color("font_color","Label").r<.4,"camp restores ivory shell dark text")
 var previous_hours=int(game.campaign().hours)
 var buttons=game.find_children("*","Button",true,false).filter(func(b):return b.text=="引き返す")
 check(not buttons.is_empty(),"camp offers turn back")
 if not buttons.is_empty():buttons[0].pressed.emit()
 await settle()
 check(game.campaign().phase=="deployment" and game.campaign().journey.returning,"turn back starts actual return encounter")
 await game.act("begin",[]);await settle();await synthetic_victory()
 check(game.campaign().phase=="town" and game.campaign().location=="astaris","return completes at original town")
 var returned=(await game.engine.request({"op":"campaign_save"})).data.state
 check(game.campaign().activeQuest is Dictionary and int(returned.activeQuest.elapsedHours)>previous_hours,"return keeps quest and elapsed time")
 await capture("flow-returned")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
