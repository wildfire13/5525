extends "res://tests/feedback_261019_3.gd"
## Independent bridge/log correspondence checks, using isolated real processes.
var events=[]
var observations=[]
func completed(file_operation: bool,ok: bool,duration: int):
 events.append({"file":file_operation,"ok":ok,"duration":duration,"at":Time.get_ticks_msec()})
func measured(payload: Dictionary,label: String):
 var count=events.size();var started=Time.get_ticks_msec()
 var reply=await game.engine.request(payload)
 var duration=Time.get_ticks_msec()-started
 check(events.size()==count+1,"one diagnostic per attempted request: "+label)
 if events.size()==count+1:
  var event=events[-1]
  check(event.file==(payload.get("op")=="godot_io") and event.ok==bool(reply.get("ok",false)),"real reply matches diagnostic category/result: "+label)
  check(event.duration>=0 and event.duration<=duration+2,"diagnostic duration bounded by actual call: "+label)
  var expected=("ファイル要求" if event.file else "ゲーム要求")+" / "+("成功" if event.ok else "失敗")+" / %d ms" % event.duration
  check(game.debug_view.entries[-1].ends_with(expected),"displayed log matches emitted result/time: "+label)
  observations.append({"operation":label,"event":event,"wall_ms":duration})
 return reply
func run():
 create_timer(150).timeout.connect(func():print("FAIL log accuracy watchdog");quit(2))
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var debug=game.debug_view
 check(debug.is_enabled(),"debug runtime active")
 game.engine.diagnostic_completed.connect(completed)
 debug.clear_history()
 var seed=(await measured({"op":"campaign_save"},"initial snapshot")).data
 await measured({"op":"not_a_real_operation","secret":"PRIVATE_SENTINEL"},"safe unknown-operation failure")
 var path=evidence.path_join("PRIVATE_SENTINEL-save.json")
 await measured({"op":"godot_io","action":"write","path":path,"data":seed},"save write")
 await measured({"op":"godot_io","action":"read","path":path,"allowed":[]},"save read")
 await measured({"op":"godot_io","action":"read","path":evidence.path_join("PRIVATE_SENTINEL-missing.json"),"allowed":[]},"missing-file failure")
 var state_after=(await measured({"op":"campaign_save"},"snapshot after safe failures")).data
 check(state_after==seed,"safe failures and save IO preserve campaign")
 game.engine.busy=true
 await measured({"op":"campaign_save"},"busy early rejection")
 game.engine.busy=false;game.engine.disconnected=true
 await measured({"op":"godot_io","action":"read","path":path},"disconnected early rejection")
 game.engine.disconnected=false;game.engine.closing=true
 await measured({"op":"campaign_save"},"closing early rejection")
 game.engine.closing=false
 check(not "\n".join(debug.entries).contains("PRIVATE_SENTINEL") and not "\n".join(debug.entries).contains(evidence) and not "\n".join(debug.entries).contains("ガロ"),"payload paths/person names and raw errors absent")
 for i in range(1,events.size()):check(events[i].at>=events[i-1].at,"completion timestamps monotonic")
 debug.clear_history();debug.set_process(false)
 for i in range(199):debug.request_finished(false,true,i)
 check(debug.entries.size()==199 and debug.entries[0].ends_with("0 ms"),"199 log entries retained")
 debug.request_finished(false,true,199)
 check(debug.entries.size()==200 and debug.entries[0].ends_with("0 ms"),"200th entry retains first")
 debug.request_finished(false,false,200)
 check(debug.entries.size()==200 and debug.entries[0].ends_with("1 ms") and debug.entries[-1].ends_with("失敗 / 200 ms"),"201st entry evicts exactly oldest")
 debug.open();await frames();debug.window.hide();var history=debug.history.text
 await measured({"op":"campaign_save"},"hidden window request")
 check(debug.history.text==history,"hidden window skips text widget updates")
 debug.open();await frames()
 check(debug.history.text=="\n".join(debug.entries),"reopening displays current bounded history")
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(960,540)
 debug.window.position=Vector2i(20,20);debug.window.size=Vector2i(440,480)
 for i in range(220):debug.append_entry(debug.state_text(debug.sample()))
 debug.request_finished(true,false,123456);await frames(16)
 check(debug.history.size.y>=120,"minimum native window retains readable log viewport")
 var scroll=debug.history.get_v_scroll_bar()
 check(debug.entries.size()==200 and scroll.max_value>debug.history.get_line_count(),"wrapped 200-entry history exceeds logical line count")
 check(scroll.value>=scroll.max_value-scroll.page-1,"latest wrapped log follows actual scrollbar bottom")
 debug.window.hide();debug.request_finished(false,true,654321);debug.open();await frames(16)
 check(scroll.value>=scroll.max_value-scroll.page-1 and debug.history.text.ends_with("654321 ms"),"reopening follows latest wrapped entry")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  debug.window.get_texture().get_image().save_png(evidence.path_join("wrapped-latest.png"))
 debug.window.hide();debug.clear_history()
 var previous=debug.sample();debug.previous=previous;game.locked=not game.locked;game.locked=not game.locked;debug.refresh_state()
 check(debug.entries.is_empty(),"state snapshots deliberately do not claim sub-sample transition coverage")
 debug.set_process(true)
 check(game.audio.muted.values().all(func(v):return v),"all audio OFF")
 for spec in [["checks.json",checks],["observations.json",observations]]:
  var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
