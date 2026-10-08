extends SceneTree
var game
var count:=0
var failures: Array[String]=[]
var voices=[]
var effects=[]
var results=[]
var folder=OS.get_temp_dir().path_join("5525-audio-regression-"+str(Time.get_ticks_usec()))
func check(ok: bool,label: String):
	count+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func snapshot():return (await game.engine.request({"op":"campaign_save"})).data
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=false
	game.audio.phase_voice_started.connect(func(id,cue):voices.append(id+"/"+cue))
	game.audio.phase_sound_started.connect(func(id):effects.append(id))
	game.audio.ui_sound_started.connect(func(id):if id in ["victory","failure"]:results.append(id))
	var output=[]
	var node=OS.get_environment("NATIVE5525_NODE")
	if node.is_empty():node="C:/Program Files/nodejs/node.exe"
	var status=OS.execute(node,PackedStringArray([ProjectSettings.globalize_path("res://tests/audio_fixtures.cjs")]),output,false,false)
	check(status==0,"synthetic start and completed saves validate through real rules")
	if status!=0:await game.close_game();return
	var fixtures=JSON.parse_string("".join(output))
	DirAccess.make_dir_recursive_absolute(folder)
	for name in ["start","finished"]:
		var reply=await game.engine.request({"op":"godot_io","action":"write","path":folder.path_join(name+".json"),"data":fixtures[name]})
		check(reply.get("ok",false),"new fixture file "+name)
	var keys=[]
	var generations=[]
	for connection in range(2):
		if connection==1:
			var old_pid=int(game.engine.handles.pid)
			OS.kill(old_pid);await create_timer(.05).timeout
			await game.update({"op":"view"})
			check(game.engine.disconnected,"real Node termination exposes reconnect")
			await game.reconnect_engine()
			check(not game.engine.disconnected and not OS.is_process_running(old_pid),"successful reconnect owns a new Node")
		generations.append(game.engine.connection_generation)
		await game.load_game(folder.path_join("start.json"))
		var reply=await game.engine.request({"op":"act","kind":"attack","target":fixtures.enemy,"presentation":true})
		check(reply.get("ok",false) and reply.presentation.phase=="action","real attack presentation begins")
		var p: Dictionary=reply.presentation
		keys.append(str(p.id)+":"+str(p.index)+":"+str(p.action_id))
		var before_voice=voices.size();var before_effect=effects.size()
		var duration=game.audio.phase(p)
		check(duration>=.22 and voices.size()==before_voice+1 and effects.size()==before_effect+1,"first phase plays voice and SE and retains ACK delay, connection "+str(connection))
		check(game.audio.phase(p)==0.0 and voices.size()==before_voice+1 and effects.size()==before_effect+1,"same phase replay is suppressed, connection "+str(connection))
		var duplicate=p.duplicate(true);duplicate.index+=100;duplicate.voiceEvents=[]
		game.audio.phase(duplicate)
		check(effects.size()==before_effect+1,"same action impact group remains deduplicated")
		await game.engine.request({"op":"presentation_finish","id":p.id})
	check(keys[0]==keys[1] and generations[1]>generations[0],"same Node serial/action IDs are scoped to different connection generations")
	check(voices==["guard/attack","guard/attack"] and effects==["attack","attack"],"two connections play exactly two real voices and attack effects")
	await game.new_game();results.clear()
	await game.load_game(folder.path_join("finished.json"))
	check(game.state().get("result")!=null and results==["victory"],"completed battle file load emits victory exactly once")
	var saved=await snapshot()
	var gold=game.campaign().gold
	for i in range(3):game.render()
	check(results==["victory"] and await snapshot()==saved and game.campaign().gold==gold,"redraw repeats neither result SE nor game settlement")
	var music=game.audio.frontend_save()
	game.audio.restore(music);game.render()
	check(results==["victory"],"music-only restore cannot replay an already synchronized result")
	await game.new_game();results.clear()
	await game.load_game(folder.path_join("finished.json"))
	check(results==["victory"],"another explicit load from town emits one result")
	var invalid=fixtures.finished.duplicate(true);invalid.godotFrontend={"version":1,"quest_id":"invalid"}
	await game.engine.request({"op":"godot_io","action":"write","path":folder.path_join("invalid.json"),"data":invalid})
	var before=await snapshot();var before_music=game.audio.frontend_save()
	await game.load_game(folder.path_join("invalid.json"))
	check(await snapshot()==before and game.audio.frontend_save()==before_music and results==["victory"],"rejected metadata changes neither state nor audio deduplication")
	check(await game.audio.finish_audio(),"audio resources drained")
	game.engine.close_engine();game.queue_free();await process_frame
	for name in ["start","finished","invalid"]:DirAccess.remove_absolute(folder.path_join(name+".json"))
	DirAccess.remove_absolute(folder)
	print(JSON.stringify({"suite":"audio_regression","checks":count,"failures":failures,"gui":false,"subjective_listening":false,"presentation_keys":keys,"generations":generations,"voices":voices,"effects":effects}))
	quit(0 if failures.is_empty() else 1)
