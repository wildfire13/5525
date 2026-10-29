extends "res://tests/turn_order_i02.gd"
## Queue-only keyboard scrolling; live battle inputs retain their own focus.
func queue_key(code: int,pressed:=true,echo:=false):
 var event=InputEventKey.new();event.keycode=code;event.pressed=pressed;event.echo=echo
 root.push_input(event);await frames(3)
func queue_wheel(point: Vector2):
 var move=InputEventMouseMotion.new();move.position=point;move.global_position=point;root.push_input(move)
 var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_WHEEL_RIGHT;event.pressed=true;root.push_input(event);await frames(3)
func run():
 create_timer(120).timeout.connect(func():print("FAIL queue keyboard watchdog");quit(2))
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 root.size=Vector2i(1180,812);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.checks_fast=true;game.audio.fast_mode=true
 var fixtures=battle_fixture();await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
 var before=await saved()
 for dims in [Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:
  root.size=dims;await settle()
  var queue=node("TurnOrderViewport");var details=node("BattleOrderDetails");var reference=details.get_global_rect()
  var board=game.board;var original_cell=board.keyboard_cell
  queue.scroll_horizontal=0;queue.grab_focus();await frames()
  var limit=maxi(0,int(queue.get_h_scroll_bar().max_value-queue.get_h_scroll_bar().page))
  check(limit>0 if dims.x<1800 else limit==0,"queue test has real overflow only in narrow window "+str(dims))
  await queue_key(KEY_RIGHT);await queue_key(KEY_RIGHT,false)
  check(queue.scroll_horizontal==mini(game.hud.QUEUE_PITCH,limit),"focused right arrow scrolls one existing card pitch "+str(dims))
  check(queue.has_focus() and board.keyboard_cell==original_cell,"right arrow stays in queue without moving board focus "+str(dims))
  var after_press=queue.scroll_horizontal;await queue_key(KEY_RIGHT,false)
  check(queue.scroll_horizontal==after_press,"key release does not scroll "+str(dims))
  await queue_key(KEY_RIGHT,true,true)
  check(queue.scroll_horizontal==mini(after_press+game.hud.QUEUE_PITCH,limit) and queue.has_focus(),"held arrow repeat scrolls and stays bounded "+str(dims))
  for i in range(4):await queue_key(KEY_RIGHT)
  check(queue.scroll_horizontal==limit and queue.has_focus(),"right boundary clamps without navigation escape "+str(dims))
  await queue_key(KEY_LEFT);await queue_key(KEY_LEFT,false)
  check(queue.scroll_horizontal==maxi(0,limit-game.hud.QUEUE_PITCH) and queue.has_focus(),"left arrow scrolls back while keeping queue focus "+str(dims))
  for i in range(4):await queue_key(KEY_LEFT)
  check(queue.scroll_horizontal==0 and queue.has_focus(),"left boundary clamps without stealing another control "+str(dims))
  check(cards().size()==5 and details.get_global_rect()==reference,"five cards and fixed details geometry remain unchanged "+str(dims))
  if limit>0:
   await queue_wheel(queue.get_global_rect().get_center())
   check(queue.scroll_horizontal>0,"existing horizontal mouse wheel still scrolls "+str(dims))
   queue.get_h_scroll_bar().value=limit;await frames()
   check(queue.scroll_horizontal==limit,"existing scrollbar remains connected "+str(dims))
  var old_offset=queue.scroll_horizontal;board.grab_focus();await frames();var cell=board.keyboard_cell
  await queue_key(KEY_LEFT);await queue_key(KEY_LEFT,false)
  check(queue.scroll_horizontal==old_offset and board.keyboard_cell!=cell,"board-focused arrows still move board and never scroll queue "+str(dims))
  details.grab_focus();await frames();old_offset=queue.scroll_horizontal;await queue_key(KEY_RIGHT);await queue_key(KEY_RIGHT,false)
  check(queue.scroll_horizontal==old_offset,"another control's arrow does not scroll queue "+str(dims))
  # Traverse normal keyboard focus; queue remains reachable by Tab.
  var tab_steps=0
  while not queue.has_focus() and tab_steps<60:
   await queue_key(KEY_TAB);await queue_key(KEY_TAB,false);tab_steps+=1
  check(queue.has_focus(),"Tab traversal reaches queue viewport "+str(dims)+" steps="+str(tab_steps))
  queue.scroll_horizontal=0;await queue_key(KEY_RIGHT);await queue_key(KEY_RIGHT,false)
  check(queue.scroll_horizontal==mini(game.hud.QUEUE_PITCH,limit) and queue.has_focus(),"Tab-focused queue responds to arrow "+str(dims))
  await click("BattleOrderDetails")
  check(game.dialog.window.title=="順番詳細" and game.dialog.window.find_children("OrderDetail_*","Label",true,false).size()==game.hud.queue_entries().size(),"complete order detail remains available "+str(dims))
  game.dialog.close();await settle()
  check(await saved()==before,"keyboard wheel focus and details preserve campaign save "+str(dims))
 check(game.audio.muted.values().all(func(v):return v),"queue keyboard checks keep BGM voice SE OFF")
 var f=FileAccess.open(evidence.path_join("turn-order-keyboard-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
