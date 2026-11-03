extends SceneTree
var failures: Array[String]=[]
var count:=0
var heard: Array=[]
func check(ok: bool,label: String):
	count+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1920,1080)
	var audio=load("res://audio.gd").new();root.add_child(audio)
	# Dummy output only; never alter saved user preferences or enable OS sound.
	audio.test_silence=true;audio.muted.voice=false;audio.volumes.voice=100;audio.apply_levels()
	audio.phase_voice_started.connect(func(uid,cue):heard.append([uid,cue]))
	var uid="recruit-guard-human-male"
	check(audio.event_voices.size()==120,"120 adopted event assets, candidate variants excluded")
	for key in audio.event_voices:
		var parts=key.split("/");var stream=audio.voice_stream(parts[0],parts[1])
		check(stream is AudioStreamMP3 and stream.get_length()>0.25 and stream.get_length()<20,"MP3 decode "+key)
	check(audio.voice_stream("unknown","attack")==null,"unknown identity has no borrowed voice")
	check(audio.voice_stream(uid,"skill:guard")==audio.voice_stream(uid,"attack"),"skill uses actor attack clip")
	check(audio.voice_stream(uid,"skill:returnHome")==audio.voice_stream(uid,"attack"),"return skill also uses actor attack")
	check(audio.voice_stream(uid,"hurt")==audio.voice_stream(uid,"damage"),"hurt routes to damage")
	var packet={"id":101,"index":0,"action_id":"101:0:1","phase":"hurt","voiceEvents":[{"character_id":uid,"cue":"hurt"},{"character_id":uid,"cue":"incapacitated"}]}
	var duration=audio.phase(packet)
	check(heard.size()==1 and audio.voice_queue.size()==1,"damage then incap queued without overlap")
	check(duration>audio.voice_stream(uid,"damage").get_length()+audio.voice_stream(uid,"incapacitated").get_length(),"phase waits for both clips")
	check(audio.phase(packet)==0 and heard.size()==1,"repeated packet never speaks twice")
	# Leave scheduling headroom for the dummy audio driver while still checking
	# that both clips finish and playback fully drains.
	await create_timer(duration+.5).timeout
	check(heard.size()==2 and heard[1][1]=="incapacitated" and not audio.voice.playing,"incap plays after damage and completes")
	audio.muted.voice=true;audio.apply_levels();var before=heard.size()
	audio.queue_voices([{"character_id":uid,"cue":"attack"}]);check(heard.size()==before and audio.voice_queue.is_empty(),"mute prevents start and queue")
	audio.muted.voice=false;audio.volumes.voice=0;audio.apply_levels();audio.queue_voices([{"character_id":uid,"cue":"attack"}]);check(heard.size()==before,"zero volume prevents voice")
	audio.volumes.voice=30;audio.apply_levels();check(is_equal_approx(audio.voice.volume_db,linear_to_db(.3)),"voice volume respected")
	audio.reset_character_events();heard.clear()
	var reserve="recruit-mage-elf-female"
	var c={"completed":1,"selected":[uid,reserve],"roster":[{"id":uid,"hp":10},{"id":reserve,"hp":0},{"id":"unknown","hp":10}]}
	audio.quest_completed(c);var selected=heard[0][0];audio.quest_completed(c)
	check(heard.size()==1 and selected in [uid,reserve] and audio.voice_queue.is_empty(),"quest selects one party member, repeat does not reroll")
	audio.reset_character_events();heard.clear()
	var state={"campaignToken":"test","campaignStage":1,"result":"勝利","units":[{"id":uid,"side":"ally","hp":10},{"id":"enemy","side":"enemy","hp":0}]}
	var data={"campaign":{"phase":"battle","location":"astaris"},"state":state,"presentation":{"phase":"settled"}}
	audio.sync(data);audio.sync(data)
	check(heard==[[uid,"battle_win"]],"victory chooses battle participant only, repaint silent")
	audio.phase({"id":102,"index":0,"action_id":"102:0:1","phase":"settled","voiceEvents":[]})
	check(audio.voice.playing,"settled presentation does not cut victory voice")
	audio.quest_completed(c);check(audio.voice_queue.size()==1 and heard.size()==1,"successive victory and quest voices queue without overlap")
	audio.stop_voice();heard.clear();audio.celebrate([{"id":uid,"hp":0},{"id":reserve,"hp":10}],"battle_win")
	check(heard==[[reserve,"battle_win"]],"incapacitated participant excluded from victory draw")
	audio.stop_voice();heard.clear();audio.celebrate([{"id":uid,"hp":0}],"battle_win")
	check(heard.is_empty(),"zero eligible victory participants stays silent")
	audio.reset_character_events();heard.clear();audio.suppress_result_voice_once=true;audio.sync(data);audio.sync(data)
	check(heard.is_empty(),"loaded result does not replay victory")
	audio.reset_character_events();heard.clear();state.units[1].hp=10;state.result="撤退";audio.sync(data)
	check(heard.is_empty(),"non-victory result does not celebrate")
	audio.reset_character_events();heard.clear();var choices={}
	seed(5525)
	for i in range(64):
		audio.stop_voice();audio.celebrate(c.roster.slice(0,2),"quest_clear");choices[heard.back()[0]]=true
	check(choices.size()==2,"random choice can select each eligible party member")
	audio.follow_connection(99);check(audio.voice_queue.is_empty() and not audio.voice.playing,"reconnection clears playback queue")
	await audio.finish_audio();audio.queue_free();await process_frame

	var game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var output=[]
	var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),[ProjectSettings.globalize_path("res://tests/event_voice_fixtures.cjs")],output,true,false)
	check(code==0,"new-roster quest boundary fixture validates")
	var fixture=JSON.parse_string("".join(output))
	await game.update({"op":"campaign_load","data":fixture})
	game.audio.muted.voice=false;game.audio.volumes.voice=100;game.audio.apply_levels()
	heard.clear();game.audio.phase_voice_started.connect(func(id,cue):heard.append([id,cue]))
	var reply=await game.update({"op":"campaign","action":"completeQuest","args":[]})
	check(reply.ok and heard.size()==1 and heard[0][1]=="quest_clear" and heard[0][0] in game.campaign().selected,"accepted completion command plays one current-party voice")
	game.render();game.render()
	await game.update({"op":"campaign","action":"completeQuest","args":[]})
	check(heard.size()==1,"repaint and rejected duplicate completion cannot replay")
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine()
	await create_timer(.15).timeout
	game.queue_free();await process_frame
	print("EVENT_VOICES ",count," checks failures=",failures)
	quit(0 if failures.is_empty() else 1)
