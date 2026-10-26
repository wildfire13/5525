extends "res://tests/brushup_gui.gd"
class ReleaseProbe:
 extends "res://debug_window.gd"
 func is_enabled() -> bool:return false
func run():
 create_timer(180).timeout.connect(func():print("FAIL debug window watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();game.navigate("board");await settle()
 var debug=game.debug_view;var seed=await saved()
 check(debug.window==null,"normal startup does not create developer window")
 check(debug.is_enabled()==OS.is_debug_build(),"official build predicate")
 var release=ReleaseProbe.new();release.configure(game);root.add_child(release)
 release.open();release.build();release.refresh_state();release.request_finished(true,false,5)
 check(release.window==null and release.entries.is_empty() and not release.is_processing(),"release branch cannot create window or collect diagnostics")
 release.queue_free()
 if not debug.is_enabled():
  check(node("OpenDeveloperWindow")==null,"release has no opening action")
  game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1);return
 for dims in [Vector2i(1920,1080),Vector2i(960,540)]:
  root.size=dims;await settle();var baseline=node("PartyFacesScroll").get_parent().global_position.y
  if DisplayServer.get_name()!="headless":
   await os_click(node("CommonMenuButton"))
   if dims.y<700:
    for i in range(5):await os_mouse(game.menu.get_global_rect().get_center(),"wheel_down")
   await os_click(node("OpenDeveloperWindow"))
  else:debug.open()
  await settle()
  var window=debug.window
  check(window.visible and not game.menu.visible,"menu action actually opens developer window")
  if not window.visible:break
  check(window.force_native and not window.exclusive and not window.transient,"independent nonmodal window requested")
  if DisplayServer.get_name()!="headless":check(not window.is_embedded() and window.get_window_id()!=root.get_window_id(),"separate real OS window ID")
  check(not game.modal_open(),"debug window does not lock game as modal")
  check(node("PartyFacesScroll").get_parent().global_position.y==baseline,"opening debug does not move party")
  game.locked=true;game.presenting=true;game.render();debug.refresh_state();await frames()
  check(not game.footer.text.contains("処理中") and not game.footer.text.contains("演出中"),"internal states absent from player footer")
  check(debug.status.text.contains("処理待ち: ON") and debug.status.text.contains("演出: ON"),"internal state visible in developer window")
  game.locked=false;game.presenting=false;game.notice="対処が必要なエラー";game.render();debug.refresh_state();await settle()
  check(game.footer.text=="対処が必要なエラー","actionable error remains player-facing")
  game.notice="";game.render();await settle()
  if DisplayServer.get_name()!="headless":
   window.position=Vector2i(180,80);await frames();await RenderingServer.frame_post_draw
   window.get_texture().get_image().save_png(evidence.path_join("debug-"+str(dims.x)+".png"))
   await os_click(debug.history);await os_key("Return");await os_key("space")
   check(game.page=="board" and await saved()==seed,"native window keys do not activate game controls")
   await os_key("Escape");check(not window.visible and not game.closing,"native Escape closes only debug window")
  else:window.close_requested.emit()
  debug.open();await settle();window.close_requested.emit();await settle()
  check(not window.visible and not game.closing and not game.engine.closing,"OS close request keeps game alive")
  check(node("PartyFacesScroll").get_parent().global_position.y==baseline,"closing debug keeps party position")
  if DisplayServer.get_name()!="headless":await snapshot("game-"+str(dims.x))
 debug.clear_history()
 for i in range(250):debug.request_finished(false,i%2==0,i)
 check(debug.entries.size()==200,"log bounded to newest 200 entries")
 check(not "\n".join(debug.entries).contains(OS.get_user_data_dir()),"diagnostics do not include profile path")
 debug.open();await settle()
 if DisplayServer.get_name()!="headless":await os_click(debug.window.find_child("DebugClear",true,false))
 else:debug.clear_history()
 check(debug.entries.is_empty(),"clear log works")
 debug.window.hide()
 await game.update({"op":"campaign_save"});await settle()
 check(debug.entries.any(func(line):return line.contains("ゲーム要求 / 成功")),"real bridge completion is recorded")
 check(await saved()==seed,"diagnostics do not mutate game/save")
 check(game.audio.muted.values().all(func(v):return v),"audio three OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
