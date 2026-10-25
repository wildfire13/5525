extends "res://tests/research2_gui.gd"
## Real X11 input and timed rendered frames. All campaign boundaries are synthetic.
var baseline := OS.get_environment("SKILL_FX_BASELINE")=="1"
var capturing := false
var clip_name := ""
var clip_started := 0
var last_capture := 0
var clip_frames=[]
var clips=[]
var benchmarks=[]
var saw_phase := false
var clip_draws=[]
func effect_snapshot() -> Dictionary:
 return {"active":false,"event":{},"progress":0.0} if baseline else game.board.skill_effects.snapshot()
func capture_effect_draw():
 if capturing:clip_draws.append({"time_ms":Time.get_ticks_msec()-clip_started,"size":str(game.board.skill_effects.size),"position":str(game.board.skill_effects.global_position),"modulate":str(game.board.skill_effects.modulate),"effect":effect_snapshot()})
func capture_frame():
 if not capturing or Time.get_ticks_msec()-last_capture<50:return
 var phase=game.data.get("presentation",{})
 phase=phase if phase is Dictionary else {}
 if phase.is_empty() and not saw_phase and not clip_frames.is_empty():return
 if not phase.is_empty():saw_phase=true
 last_capture=Time.get_ticks_msec()
 var image=root.get_texture().get_image()
 var file="clips/"+clip_name+"/frame%04d.jpg" % clip_frames.size()
 image.save_jpg(evidence.path_join(file),.97)
 clip_frames.append({"file":file,"time_ms":last_capture-clip_started,"presentation":phase.duplicate(true) if phase is Dictionary else {},"effect":effect_snapshot(),"hp":game.state().get("units",[]).map(func(u):return {"id":u.id,"hp":u.hp,"pos":u.pos})})
 if phase.is_empty() and saw_phase:capturing=false
func cases_fx() -> Dictionary:
 var output=[];var path=OS.get_environment("SKILL_EFFECT_FIXTURES")
 if path.is_empty():path=ProjectSettings.globalize_path("res://tests/skill_effect_fixtures.cjs")
 var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([path]),output,true,false)
 check(code==0,"canonical effect fixtures generated")
 return JSON.parse_string("".join(output)).cases
func keyed(value: String):
 var found=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")==value and b.is_visible_in_tree())
 return found[0] if not found.is_empty() else null
func prepare(c: Dictionary):
 check((await game.update({"op":"campaign_load","data":c.save})).get("ok",false),"validated effect boundary loaded")
 await settle()
 if c.request.kind=="skill":
  await os_click(game.hud.buttons.skill);await os_click(node("BattleSkill_"+str(c.expected.skill_id)))
 else:await os_click(game.hud.buttons[str(c.request.kind)])
 if c.request.kind!="guard" and game.pending==null:
  var cell=int(c.request.target) if c.request.target is float or c.request.target is int else -1
  if cell<0:
   for unit in game.state().units:
    if unit.id==c.request.target:cell=int(unit.pos);break
  await os_mouse(game.board.global_position+game.board.project_cell(cell),"click")
 await settle();check(game.can_commit(),"real UI reaches canonical confirmation")
 check(not effect_snapshot().active,"preview has no activation or hit effect")
func record_action(name_: String,c: Dictionary):
 await prepare(c);var before=await saved()
 if not baseline and not game.board.skill_effects.draw.is_connected(capture_effect_draw):game.board.skill_effects.draw.connect(capture_effect_draw)
 clip_name=name_;clip_frames=[];clip_draws=[];DirAccess.make_dir_recursive_absolute(evidence.path_join("clips/"+clip_name))
 clip_started=Time.get_ticks_msec();last_capture=0;saw_phase=false;capturing=true
 await create_timer(.08).timeout;await os_click(keyed("battle_commit"));await settle();await create_timer(.14).timeout
 capturing=false
 check(not game.presenting and game.data.get("presentation")==null,"accepted action presentation drains once "+name_)
 check(not effect_snapshot().active,"accepted action leaves no visual residue "+name_)
 var after=await saved()
 check(int(after.state.battle.actions)>int(before.state.battle.actions),"real confirmation executes action "+name_)
 check(after.state.battle==c.frames[-1].state,"visual playback keeps exact canonical battle result "+name_)
 var seen=clip_frames.filter(func(f):return f.effect.active)
 if not baseline:check(not seen.is_empty(),"actual rendered effect frames captured "+name_)
 check(clip_frames.any(func(f):return not f.presentation.is_empty()),"actual native presentation recorded "+name_)
 var clip={"name":name_,"frames":clip_frames.duplicate(true),"draws":clip_draws.duplicate(true),"save_before":before,"save_after":after}
 clips.append(clip)
 var f=FileAccess.open(evidence.path_join("clips/"+clip_name+"/clip.json"),FileAccess.WRITE);f.store_string(JSON.stringify(clip,"\t"));f.close()
func percentile(values: Array,ratio: float) -> float:
 var copy=values.duplicate();copy.sort();return copy[mini(copy.size()-1,int(copy.size()*ratio))]
func benchmark(c: Dictionary,dims: Vector2i):
 root.size=dims;await game.update({"op":"campaign_load","data":c.save});await settle()
 await os_mouse(Vector2(root.size.x-2,2))
 game.board.camera_yaw=0;game.board.world.zoom=16.5;game.board.update_camera();await frames(30)
 var before=await saved();var samples=[];var process_ms=[];var calls=[];var nodes=[];var memories=[];var last=Time.get_ticks_usec()
 for index in range(180):
  if not baseline and index%2==0:game.board.skill_effects.play({"skill_id":"legSweep","phase":"action","origin":24,"cells":c.geometry.sweepCells},.42)
  await process_frame;var now=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
  process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0);calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));memories.append(Performance.get_monitor(Performance.MEMORY_STATIC))
 if not baseline:game.board.skill_effects.clear()
 await frames(30);check(await saved()==before,"isolated effect benchmark consumes no gameplay resources")
 benchmarks.append({"size":str(dims),"samples":samples.size(),"frame_median_ms":percentile(samples,.5),"frame_p95_ms":percentile(samples,.95),"process_median_ms":percentile(process_ms,.5),"process_p95_ms":percentile(process_ms,.95),"draw_calls_median":percentile(calls,.5),"nodes_median":percentile(nodes,.5),"memory_static_median":percentile(memories,.5),"effect_active_after":effect_snapshot().active})
func run():
 create_timer(600).timeout.connect(func():print("FAIL effect GUI watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=false;game.audio.fast_mode=true;await settle();var cases=cases_fx()
 RenderingServer.frame_post_draw.connect(capture_frame)
 var core_only=OS.get_environment("SKILL_FX_CORE_ONLY")=="1"
 var names=["sweep100","heal","stamp","attackMelee","guard"]
 if not baseline and not core_only:names.append_array(["stampCover","stampMiss","healCapped","attackRanged","attackGuarded","attackCoverGuarded","attackFixedMiss","attackSequence"])
 var benchmark_only=OS.get_environment("SKILL_FX_BENCHMARK_ONLY")=="1"
 if benchmark_only:names=[]
 for name_ in names:await record_action(name_+"-1920",cases[name_])
 if not baseline and not benchmark_only and not core_only:
  root.size=Vector2i(1180,812);await settle();game.board.camera_yaw=-.45;game.board.world.zoom=14;game.board.update_camera()
  for name_ in ["sweep100","heal","stamp"]:await record_action(name_+"-1180-left",cases[name_])
  root.size=Vector2i(1280,800);await settle();game.board.camera_yaw=.45;game.board.world.zoom=20;game.board.update_camera()
  for name_ in ["heal","stamp","attackMelee"]:await record_action(name_+"-1280-right",cases[name_])
  await prepare(cases.stamp);var before=await saved();await os_click(keyed("battle_cancel"))
  check(not effect_snapshot().active and await saved()==before,"actual OS cancel never triggers an effect or changes save")
  check(game.board.skill_effects.mouse_filter==Control.MOUSE_FILTER_IGNORE and game.board.skill_effects.get_index()<game.board.overlay.get_index(),"effect input ignored and HP labels stay above effects")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all effect GUI audio OFF")
 if OS.get_environment("SKILL_FX_BENCHMARK")!="0":
  for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:await benchmark(cases.sweep100,dims)
 for spec in [["clips.json",clips],["benchmarks.json",benchmarks],["checks.json",checks]]:
  var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
