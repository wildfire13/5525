extends "res://tests/facility_gui_261022.gd"
func choose(control):
 if DisplayServer.get_name()=="headless":control.pressed.emit();await settle()
 else:await os_click(control)
func reward_row(caption: String):
 for label in node("QuestDetail").find_children("*","Label",true,false):
  if label.text==caption:return label.get_parent()
 return null
func verify_reward(caption: String,kind: String,amount: int,rp: int):
 var row=reward_row(caption)
 check(row!=null,caption+" row exists")
 if row==null:return
 var labels=[]
 for child in row.get_children():
  if child is Label:labels.append(child.text)
 var expected=[caption,"×%d" % amount]
 if rp>0:expected.append("RP ×%d" % rp)
 check(labels==expected,caption+" exact amount and distinct RP "+str(expected))
 var icons=row.find_children("*","TextureRect",true,false)
 check(icons.size()==1 and icons[0].get_meta("ui_icon_id","")==kind,caption+" correct money/EXP unit")
func run():
 create_timer(150).timeout.connect(func():print("FAIL board watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.audio.fast_mode=true;game.checks_fast=true;await settle()
 await game.act("select",[["guard","porter","porter-2"]]);game.navigate("board");await settle()
 var seed=await saved()
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;await settle()
  check(node("QuestBoardColumns")!=null and node("QuestList")!=null and node("QuestDetail")!=null,"list and detail present "+str(dims))
  # The new board omits unimplemented filters instead of presenting dummy tabs.
  var filters=game.find_children("Quest*Filter*","BaseButton",true,false)
  var old_tabs=node("QuestDifficultyTabs")
  if old_tabs!=null:filters.append(old_tabs)
  check(filters.all(func(control):return control.disabled),"unimplemented quest filters absent or disabled, never actionable")
  check(node("Header_hub")!=null and not node("Header_hub").disabled,"common header provides enabled return to local map")
  check(node("QuestList").get_global_rect().end.x<=node("QuestDetail").get_global_rect().position.x,"list left of details "+str(dims))
  var q=game.campaign().board[1];await choose(node("QuestChoice_"+str(q.id)))
  check(game.pages.quest_board.selected_id==q.id and await saved()==seed,"selection changes presentation only")
  var rewards=q.get("rewards",{})
  check(not rewards.is_empty(),"current quest supplies explicit reward breakdown")
  var kind="experience" if q.get("rewardType","money")=="experience" else "money"
  verify_reward("基本報酬",kind,int(rewards.get("base",0)),int(rewards.get("baseRP",0)))
  verify_reward("希望条件達成報酬",kind,int(rewards.get("bonus",0)),int(rewards.get("bonusRP",0)))
  check(reward_row("キャラクター報酬")==null,"current RP is not presented as character EXP")
  var weight=0.0
  for cargo in q.get("cargoItems",[{"weight":q.weight,"quantity":1}]):weight+=float(cargo.weight)*int(cargo.get("quantity",1))
  var weight_text=str(int(weight)) if is_equal_approx(weight,round(weight)) else str(weight)
  check(node("QuestCargoWeight").text=="合計Wt "+weight_text,"actual quantity-weight total shown in Wt")
  check(await saved()==seed,"reward and cargo presentation preserve complete state")
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
 await choose(node("Header_hub"));check(game.page=="hub","common header return to local map retained")
 var reply=await game.update({"op":"campaign_load","data":after});await settle();game.navigate("board");await settle()
 check(reply.ok and game.campaign().activeQuest.cargoOwnerId=="porter-2","save reload retains confirmed cargo owner")
 await game.update({"op":"campaign_load","data":seed});await settle();game.navigate("board");await settle();await choose(node("QuestAccept"));await choose(node("QuestCargoOwner_porter"))
 token=game.campaign().inventoryToken;epoch=game.pages.epoch;connection=game.engine.connection_generation;generation=board.picker_generation;id=board.selected_id
 await choose(node("QuestCargoCancel"));await board.commit(id,token,epoch,connection,generation);check(await saved()==seed,"callback from canceled picker cannot accept")
 await game.act("select",[["guard"]]);game.navigate("board");await settle();check(node("QuestAccept").disabled,"zero porter still cannot accept")
 check(game.audio.muted.values().all(func(v):return v),"BGM voice SE all OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames(24);quit(0 if checks.all(func(c):return c.passed) else 1)
