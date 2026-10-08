extends SceneTree
var game
var captures=[]
var folder=OS.get_environment("UIUX_EVIDENCE").path_join("captures")
func _initialize():call_deferred("run")
func settle():
 for i in range(8):await process_frame
 while game.locked or game.presenting or game.engine.busy or game.pages.quote_pending:await process_frame
 await create_timer(.15).timeout
func capture(name_: String):
 await settle();await RenderingServer.frame_post_draw
 var path=folder.path_join("UIACC-"+name_+".png")
 root.get_texture().get_image().save_png(path)
 var geometry={}
 for id in ["BattleDock","BattleConfirm","TargetSummary","ShopProducts","QuoteMoney","ShopActions","PartyRoster","PartyDetail","TurnOrder"]:
  var node=game.find_child(id,true,false)
  if node is Control:
   var rect=node.get_global_rect();geometry[id]={"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y,"visible":node.is_visible_in_tree()}
 captures.append({"name":name_,"path":path,"window":[root.size.x,root.size.y],"geometry":geometry})
 print("CAPTURE ",name_," ",JSON.stringify(geometry))
func run():
 root.title="5525 UIUX candidate - isolated visual QA"
 root.size=Vector2i(1280,800)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var original=(await game.engine.request({"op":"campaign_save"})).data
 var east=original.duplicate(true);east.state.location="east"
 for dims in [Vector2i(1280,800),Vector2i(1024,720),Vector2i(800,600)]:
  root.size=dims;await settle()
  await game.update({"op":"campaign_load","data":original});game.navigate("party");await capture("P01-"+str(dims.x))
  await game.update({"op":"campaign_load","data":east});game.navigate("shop")
  await game.preview_gear("javelin-wood");await capture("S01-"+str(dims.x))
  await game.update({"op":"campaign_load","data":original})
  await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await capture("B17-"+str(dims.x))
  await game.act("begin",[]);game.choose_command("move")
  if not game.data.choices.move.is_empty():await game.on_cell(int(game.data.choices.move[0]))
  await capture("B08-"+str(dims.x))
 var file=FileAccess.open(OS.get_environment("UIUX_EVIDENCE").path_join("reports/visual-layout.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"captures":captures,"input":"Godot callbacks, rendered visible window","synthetic_shop_location":true,"subjective_listening":false},"  "));file.close()
 await settle();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.3).timeout
 game.queue_free()
 for i in range(5):await process_frame
 quit()
