extends SceneTree
# Checks the shipped road MP3 using the Dummy audio driver.
var failures: Array[String]=[]
var count:=0
func check(ok: bool,label: String):
	count+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
	var audio=load("res://audio.gd").new();root.add_child(audio)
	# The test runner explicitly requests silence; product defaults are checked
	# separately by audio_options_regression.gd without the QA override.
	check(OS.get_environment("NATIVE5525_AUDIO_OFF")=="1","QA-only silence override supplied")
	for kind in ["bgm","voice","se"]:
		check(audio.muted[kind],kind+" test starts muted")
	var muted_campaign={"phase":"town","location":"astaris","journey":null}
	audio.sync({"campaign":muted_campaign})
	check(audio.bgm.stream!=null and audio.bgm.stream_paused and not audio.bgm.playing,"default town sync keeps loaded music paused")
	muted_campaign.phase="road";muted_campaign.journey={"token":1,"origin":"astaris","destination":"north"}
	audio.sync({"campaign":muted_campaign})
	var muted_selection=audio.frontend_save()
	check(not audio.quest_id.is_empty() and audio.quest.stream!=null and audio.quest.stream_paused and not audio.quest.playing,"default road sync selects music without playback")
	audio.sync({"campaign":muted_campaign})
	check(audio.frontend_save()==muted_selection and audio.quest.stream_paused,"repeated muted sync retains journey selection")
	muted_campaign.phase="battle";audio.sync({"campaign":muted_campaign,"state":{"result":null}})
	check(audio.current_bgm=="road_battle" and audio.bgm.stream_paused and not audio.bgm.playing and audio.quest.stream_paused and audio.frontend_save()==muted_selection,"default battle sync keeps both music streams silent and selection intact")
	check(not audio.voice.playing and audio.effects.all(func(p):return not p.playing) and not audio.ui_player.playing,"default sync leaves voice and effects silent")
	# Playback tests explicitly opt into BGM while preserving other mute defaults.
	audio.set_sound_level("bgm",100)
	muted_campaign.phase="camp";audio.sync({"campaign":muted_campaign})
	check(audio.quest.playing and not audio.quest.stream_paused and audio.frontend_save()==muted_selection and audio.muted.voice and audio.muted.se,"explicit BGM unmute starts retained selection only")
	var id=audio.ROAD_TRACK
	var stream=audio.quest.stream as AudioStreamMP3
	check(stream!=null and stream.resource_path.get_file()=="road_01.mp3" and stream.loop and stream.loop_offset==0,"whole road MP3 loops from the start")
	if stream==null:quit(1);return
	var campaign=muted_campaign
	var selected=audio.frontend_save()
	await create_timer(.12).timeout
	check(audio.quest.get_playback_position()>0,id+" playback position advances")
	audio.quest.seek(stream.get_length()-.04)
	await create_timer(.16).timeout
	check(audio.quest.playing and audio.quest.get_playback_position()<.6,id+" playback wraps across actual loop boundary")
	campaign.phase="battle";audio.sync({"campaign":campaign,"state":{"result":null}})
	var position=audio.quest.get_playback_position()
	check(audio.quest.stream_paused and audio.bgm.playing and audio.current_bgm=="road_battle",id+" combat pauses quest and uses existing battle track")
	await create_timer(.1).timeout
	check(absf(audio.quest.get_playback_position()-position)<.03,id+" position stays paused during combat")
	campaign.phase="camp";audio.sync({"campaign":campaign})
	check(audio.frontend_save()==selected and audio.quest.stream==stream and audio.quest.playing and not audio.quest.stream_paused and absf(audio.quest.get_playback_position()-position)<.03,id+" camp resumes same stream at same position")
	var restored=JSON.parse_string(JSON.stringify(selected))
	campaign.phase="battle";audio.restore(restored);audio.sync({"campaign":campaign,"state":{"result":null}})
	check(audio.frontend_save()==selected and (audio.quest.stream_paused or not audio.quest.playing),id+" saved battle retains selection without road playback")
	campaign.phase="camp";audio.sync({"campaign":campaign})
	check(audio.frontend_save()==selected and audio.quest.stream==stream and audio.quest.playing and not audio.quest.stream_paused,id+" loaded battle returns to same song")
	campaign.phase="arrival";audio.sync({"campaign":campaign})
	check(audio.current_bgm=="north" and audio.bgm.playing and audio.quest.stream_paused,id+" arrival switches to destination town track")
	campaign.phase="result";campaign.location="north";audio.sync({"campaign":campaign})
	check(audio.current_bgm=="north" and audio.quest.stream_paused,id+" delivery result retains town music")
	campaign.phase="town";campaign.journey=null;audio.sync({"campaign":campaign})
	check(audio.quest_id.is_empty() and audio.journey_key.is_empty() and not audio.quest.playing and audio.current_bgm=="north",id+" town clears journey selection")
	stream=null
	var sample={"phase":"road","location":"astaris","journey":{"token":100,"origin":"astaris","destination":"east"}}
	audio.sync({"campaign":sample})
	var chosen=audio.frontend_save()
	for former_id in ["quest_01_open_road","quest_02_woodland","quest_03_quiet_horizon"]:
		var metadata=chosen.duplicate()
		metadata.quest_id=former_id
		check(audio.restore(metadata) and audio.frontend_save()==chosen,"previous road track ID resolves to road_01: "+former_id)
	audio.sync({"campaign":sample})
	audio.set_mute("bgm",true);audio.sync({"campaign":sample})
	check(audio.quest.stream_paused,"mute pauses delivered quest audio")
	audio.set_mute("bgm",false);audio.sync({"campaign":sample})
	check(not audio.quest.stream_paused and audio.frontend_save()==chosen,"unmute keeps the same song")
	check(not audio.restore({"version":1,"quest_id":"untrusted"}) and audio.frontend_save()==chosen,"invalid saved selection rejected without mutation")
	sample.journey=null;sample.phase="town";audio.sync({"campaign":sample})
	sample.journey={"token":195,"origin":"astaris","destination":"east"};sample.phase="road";audio.sync({"campaign":sample})
	check(not audio.quest_id.is_empty() and audio.quest.playing,"repeat route/token after journey end starts a new selection")
	# Drain actual stream references; a fixed 150ms delay can race AudioServer cleanup.
	check(await audio.finish_audio(),"stopped audio streams released before test shutdown")
	audio.queue_free()
	for i in range(6):await process_frame
	print(JSON.stringify({"suite":"audio_state_smoke","checks":count,"failures":failures,"audio_driver":"Dummy","road_mp3_tested":true,"subjective_listening":false}))
	quit(0 if failures.is_empty() else 1)
