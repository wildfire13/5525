extends "res://tests/research2_gui.gd"
var baseline=OS.get_environment("UI_P3_BASELINE")=="1"
var measurements=[]
func run():
 create_timer(240).timeout.connect(func():print("FAIL queue keyboard GUI watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1180,812)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;var cases=cases2()
 for dims in [Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:
  root.size=dims;await game.update({"op":"campaign_load","data":cases.sweep100});await settle();await os_click(game.hud.buttons.attack)
  var queue=node("TurnOrderViewport");var before=await saved();var cell=game.board.keyboard_cell
  for i in range(30):
   if queue.has_focus():break
   await os_key("Tab")
  check(queue.has_focus(),"actual OS Tab reaches turn-order viewport "+str(dims.x));queue.scroll_horizontal=0;await frames()
  var overflow=queue.get_h_scroll_bar().max_value>queue.size.x+1
  await snapshot("queue-focus-"+str(dims.x));await os_key("Right")
  measurements.append({"size":str(dims),"overflow":overflow,"scroll_after_right":queue.scroll_horizontal,"focus_after_right":queue.has_focus(),"board_cell_unchanged":game.board.keyboard_cell==cell})
  if baseline:
   if overflow:check(queue.scroll_horizontal==0,"baseline actual OS Right cannot scroll focused queue")
  else:
   check(queue.has_focus() and (queue.scroll_horizontal>0 if overflow else queue.scroll_horizontal==0),"actual OS Right scrolls only focused queue "+str(dims.x))
   await os_key("Left");check(queue.scroll_horizontal==0 and queue.has_focus(),"actual OS Left returns queue without losing focus")
  check(game.board.keyboard_cell==cell and await saved()==before,"queue keys do not move board or change save")
  await snapshot("queue-right-"+str(dims.x))
  for i in range(40):
   if game.board.has_focus():break
   await os_key("Tab")
  var board_cell=game.board.keyboard_cell
  check(game.board.has_focus(),"actual OS Tab returns focus to board")
  await os_key("Right" if board_cell%10<9 else "Left")
  check(game.board.has_focus() and game.board.keyboard_cell!=board_cell,"board retains its own arrow key when focused")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"queue OS checks keep audio OFF")
 for spec in [["queue-keyboard-measurements.json",measurements],["checks.json",checks]]:
  var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
