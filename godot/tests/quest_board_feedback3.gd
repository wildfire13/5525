extends "res://tests/facility_gui_261022.gd"
func choose(control):
 if DisplayServer.get_name()=="headless":control.pressed.emit();await settle()
 else:await os_click(control)
func run():
 create_timer(150).timeout.connect(func():print("FAIL board watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.audio.fast_mode=true;game.checks_fast=true;await settle()
 await game.act("select",[["guard","porter","porter-2"]]);game.navigate("board");await settle()
 var seed=await saved()
 for dims in [Vector2i(1920,1080),Vector2i(960,540)]:
  root.size=dims;await settle()
  check(node("QuestBoardColumns")!=null and node("QuestList")!=null and node("QuestDetail")!=null,"list and detail present "+str(dims))
  check(node("QuestDifficultyTabs").disabled and node("QuestFutureFilters").disabled,"unimplemented filters remain placeholders")
  check(node("QuestList").get_global_rect().end.x<=node("QuestDetail").get_global_rect().position.x,"list left of details "+str(dims))
  var q=game.campaign().board[1];await choose(node("QuestChoice_"+str(q.id)))
  check(game.pages.quest_board.selected_id==q.id and await saved()==seed,"selection changes presentation only")
  check(game.find_children("*","Label",true,false).any(func(n):return n.text=="報酬 %dG" % q.reward),"actual reward shown")
  check(game.find_children("*","Label",true,false).any(func(n):return n.text=="総重量: "+str(q.weight)),"actual weight shown without invented units")
  if DisplayServer.get_name()!="headless":await snapshot("board-"+str(dims.x))
  # Scroll the enclosing page to its bottom for compact screens.
  var scroll=node("QuestBoardColumns").get_parent().get_parent()
  if scroll is ScrollContainer:scroll.ensure_control_visible(node("QuestAccept"));await frames(12)
  await choose(node("QuestAccept"))
  check(node("QuestCargoConfirm").disabled,"confirmation disabled until owner selected")
  await choose(node("QuestCargoOwner_porter-2"))
  check(not node("QuestCargoConfirm").disabled and await saved()==seed,"portrait selection does not accept or issue cargo")
  if DisplayServer.get_name()!="headless":await snapshot("porter-picker-"+str(dims.x))
  await choose(node("QuestCargoCancel"));check(await saved()==seed,"selected owner cancel preserves complete state")
 root.size=Vector2i(1920,1080);await settle();await choose(node("QuestAccept"));await choose(node("QuestCargoOwner_porter-2"))
 var board=game.pages.quest_board;var token=game.campaign().inventoryToken;var epoch=game.pages.epoch;var connection=game.engine.connection_generation;var generation=board.picker_generation;var id=board.selected_id
 await choose(node("QuestCargoConfirm"))
 var after=await saved();var quest=game.campaign().activeQuest
 check(quest is Dictionary and quest.cargoOwnerId=="porter-2" and game.campaign().characters["porter-2"].inventory.get(quest.cargoItemId)==1,"final confirmation issues once to selected porter")
 check(game.page=="board" and game.campaign().phase=="town","accept remains at board; departure via plaza")
 await board.commit(id,token,epoch,connection,generation);check(await saved()==after,"duplicate stale confirm preserves complete accepted state")
 await choose(node("TownReturn"));check(game.page=="hub","bottom right return to plaza retained")
 var reply=await game.update({"op":"campaign_load","data":after});await settle();game.navigate("board");await settle()
 check(reply.ok and game.campaign().activeQuest.cargoOwnerId=="porter-2","save reload retains confirmed cargo owner")
 await game.update({"op":"campaign_load","data":seed});await settle();game.navigate("board");await settle();await choose(node("QuestAccept"));await choose(node("QuestCargoOwner_porter"))
 token=game.campaign().inventoryToken;epoch=game.pages.epoch;connection=game.engine.connection_generation;generation=board.picker_generation;id=board.selected_id
 await choose(node("QuestCargoCancel"));await board.commit(id,token,epoch,connection,generation);check(await saved()==seed,"callback from canceled picker cannot accept")
 await game.act("select",[["guard"]]);game.navigate("board");await settle();check(node("QuestAccept").disabled,"zero porter still cannot accept")
 check(game.audio.muted.values().all(func(v):return v),"BGM voice SE all OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames(24);quit(0 if checks.all(func(c):return c.passed) else 1)
