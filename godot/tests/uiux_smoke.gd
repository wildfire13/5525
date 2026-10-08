extends SceneTree
var game
func _initialize():call_deferred("run")
func settle():
 for i in range(6):await process_frame
 while game.locked or game.presenting or game.engine.busy or game.pages.quote_pending:await process_frame
func run():
 root.size=Vector2i(1280,800)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var original=(await game.engine.request({"op":"campaign_save"})).data
 game.navigate("party");await settle();print("UIUX PARTY ",game.size)
 var east=original.duplicate(true);east.state.location="east"
 await game.update({"op":"campaign_load","data":east});game.navigate("shop")
 await game.preview_gear("javelin-wood");await settle();print("UIUX SHOP ",game.gear_preview.get("cost"))
 await game.update({"op":"campaign_load","data":original})
 await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await settle();print("UIUX DEPLOY ",game.board.size)
 await game.act("begin",[]);await settle();print("UIUX BATTLE ",game.board.size)
 await settle();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.3).timeout;game.queue_free()
 for i in range(5):await process_frame
 quit()
