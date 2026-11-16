extends "res://tests/quest_board_feedback3.gd"
func run():
 create_timer(180).timeout.connect(func():push_error("UI guidelines watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await game.new_game();
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var seed=await saved()
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;game.navigate("character");await settle()
  for tab in ["inventory","equipment"]:
   await choose(node("CharacterTab_"+tab))
   check(node("CharacterTab_"+tab).get_meta("selected",false),"selected loadout tab explicit "+str(dims)+tab)
  check(await saved()==seed,"loadout tab changes preserve full save")
  game.navigate("board");await settle()
  var y=node("QuestAccept").global_position.y
  var quantities=node("QuestCargoItems").find_children("*","Label",true,false)
  check(not quantities.is_empty() and quantities.all(func(label):return label.autowrap_mode==TextServer.AUTOWRAP_OFF and label.size.x>=label.get_minimum_size().x),"cargo quantities stay readable on the current board")
  for quest in game.campaign().board:
   await choose(node("QuestChoice_"+str(quest.id)))
   check(node("QuestChoice_"+str(quest.id)).get_meta("selected",false),"chosen quest has selection style")
   check(absf(node("QuestAccept").global_position.y-y)<2,"quest action stable across selection")
  check(node("QuestAccept").get_parent().name=="QuestDetailActions","action separate from scrolling detail")
  if DisplayServer.get_name()!="headless":await snapshot("board-"+str(dims.x))
  await choose(node("QuestAccept"));check(node("QuestCargoConfirm").disabled,"no automatic porter selection")
  var options=game.find_children("QuestCargoOwner_*","Button",true,false)
  check(options.size()>0 and options.all(func(b):return b.size.x<300 and b.icon_alignment==HORIZONTAL_ALIGNMENT_CENTER),"bounded centered porter cards")
  await choose(options[0]);check(options[0].get_meta("selected",false) and not node("QuestCargoConfirm").disabled,"selected porter and enabled confirmation")
  if DisplayServer.get_name()!="headless":await snapshot("porter-picker-"+str(dims.x))
  await choose(node("QuestCargoCancel"));check(await saved()==seed,"picker cancel leaves quest cargo money unchanged")
 check(game.audio.muted.values().all(func(v):return v),"audio three OFF")
 var f=FileAccess.open(evidence.path_join("guidelines-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
 print("UI_GUIDELINES "+str(checks.filter(func(c):return c.passed).size())+"/"+str(checks.size()));quit(0 if checks.all(func(c):return c.passed) else 1)
