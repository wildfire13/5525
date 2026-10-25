extends SceneTree
## Playback is never started: product defaults, persisted controls and QA silence
## are checked independently using a fresh external profile and Dummy driver.
var failures: Array[String]=[]
var count:=0
func check(ok: bool,label: String):
	count+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
	var previous_override=OS.get_environment("NATIVE5525_AUDIO_OFF")
	OS.set_environment("NATIVE5525_AUDIO_OFF","")
	var path="user://audio-settings-v1.cfg"
	if FileAccess.file_exists(path):print("FAIL audio options requires fresh isolated profile");quit(2);return
	var script=load("res://audio.gd");var audio=script.new();root.add_child(audio)
	check(audio.muted.values().all(func(value):return not value),"new product profile starts with three sound categories ON")
	check(audio.volumes.values().all(func(value):return value==100),"initial 100% retains delivered standard mix")
	check(is_equal_approx(audio.bgm.volume_db,-6) and is_equal_approx(audio.quest.volume_db,-6) and is_equal_approx(audio.voice.volume_db,0) and is_equal_approx(audio.effects[0].volume_db,-4) and is_equal_approx(audio.ui_player.volume_db,-6),"default mix preserves music voice UI and effect gain")
	check(not FileAccess.file_exists(path),"merely opening game does not reset or write preferences")
	for kind in ["bgm","voice","se"]:audio.set_mute(kind,true)
	var before=audio.frontend_save().duplicate(true)
	for kind in ["bgm","voice","se"]:
		var player=audio.bgm if kind=="bgm" else audio.voice if kind=="voice" else audio.effects[0]
		var last=-1000.0
		for percent in range(0,101,10):
			audio.set_volume(kind,percent)
			check(audio.volumes[kind]==percent and player.volume_db>last,kind+" positive amplitude direction "+str(percent)+"%")
			last=player.volume_db
		check(audio.muted[kind],kind+" slider preserves explicit OFF toggle")
		audio.set_volume(kind,0);audio.set_mute(kind,false)
		check(not audio.audible(kind),kind+" zero percent is silent even with ON switch")
		audio.set_mute(kind,true);audio.set_volume(kind,37)
		check(audio.volumes[kind]==40,kind+" snaps to ten-percent increments")
		audio.set_volume(kind,999);check(audio.volumes[kind]==100,kind+" upper boundary clamps")
		audio.set_volume(kind,-999);check(audio.volumes[kind]==0,kind+" lower boundary clamps")
		audio.set_volume(kind,30)
	check(audio.frontend_save()==before,"audio settings never change campaign music metadata or save schema")
	var config=ConfigFile.new();check(config.load(path)==OK,"local preferences saved independently from campaign")
	config.set_value("extension","keep","unchanged");config.save(path);audio.set_volume("bgm",40)
	config.load(path);check(config.get_value("extension","keep")=="unchanged","saving audio preserves unrelated existing preference sections")
	var copy=script.new();root.add_child(copy)
	check(copy.muted==audio.muted and copy.volumes==audio.volumes,"saved OFF and volume values survive reopening without reset")
	for kind in ["bgm","voice","se"]:
		check(copy.effective_volume(kind)==0,"saved mute projects to zero without resetting stored volume "+kind)
		copy.set_sound_level(kind,70)
		check(copy.effective_volume(kind)==70 and not copy.muted[kind],"single positive slider update unmutes and sets level atomically "+kind)
		copy.set_sound_level(kind,0)
		check(copy.effective_volume(kind)==0 and copy.muted[kind] and not copy.audible(kind),"single zero slider update is OFF and silent "+kind)
	var hash_before=FileAccess.get_sha256(path)
	OS.set_environment("NATIVE5525_AUDIO_OFF","1")
	var qa=script.new();root.add_child(qa)
	check(qa.muted.values().all(func(value):return value),"test-only process override starts every channel OFF")
	qa.set_mute("bgm",false);qa.set_volume("bgm",90)
	check(FileAccess.get_sha256(path)==hash_before,"QA overrides and QA control changes do not overwrite product preferences")
	for current in [audio,copy,qa]:
		check(not current.bgm.playing and not current.quest.playing and not current.voice.playing and current.effects.all(func(p):return not p.playing),"state-only test never starts audio playback")
		await current.finish_audio();current.queue_free()
	await process_frame
	OS.set_environment("NATIVE5525_AUDIO_OFF",previous_override)
	print("Audio options checks: %d/%d" % [count-failures.size(),count]);quit(0 if failures.is_empty() else 1)
