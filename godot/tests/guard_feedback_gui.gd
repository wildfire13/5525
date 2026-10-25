extends "res://tests/skill_effects_gui.gd"
## Real OS confirmation and timed frames for the guard outline only.
var view_yaw := 0.0
var view_zoom := 16.5
func prepare(c: Dictionary):
 await super.prepare(c)
 game.board.camera_yaw=view_yaw;game.board.world.zoom=view_zoom;game.board.update_camera();await frames(3)
func run():
 create_timer(400).timeout.connect(func():print("FAIL guard feedback GUI watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=false;game.audio.fast_mode=true;await settle();var cases=cases_fx()
 RenderingServer.frame_post_draw.connect(capture_frame)
 for spec in [["guard",Vector2i(1920,1080),0.0,16.5],["guard",Vector2i(1180,812),-.45,14.0],["guard",Vector2i(1283,832),.45,20.0],["attackGuarded",Vector2i(1180,812),0.0,16.5],["attackCoverGuarded",Vector2i(1180,812),0.0,16.5]]:
  root.size=spec[1];view_yaw=spec[2];view_zoom=spec[3];await settle()
  await record_action(str(spec[0])+"-"+str(spec[1].x),cases[spec[0]])
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"guard feedback audio OFF")
 for spec in [["clips.json",clips],["checks.json",checks]]:
  var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
