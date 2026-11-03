extends SceneTree
var checks=[]
func check(ok: bool,label: String):
	checks.append(ok);print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1920,1080)
	var audio=preload("res://audio.gd").new();root.add_child(audio)
	var data={"campaign":{"phase":"town","location":"astaris","journey":null},"state":{}}
	audio.sync(data)
	check(audio.current_bgm=="astaris" and audio.bgm.stream is AudioStreamMP3,"Astaris uses the explicitly provisional city MP3")
	var city=audio.bgm.stream as AudioStreamMP3
	check(city.loop and is_equal_approx(city.loop_offset,0.0) and absf(city.get_length()-99.0)<0.2,"city candidate loops the full 99-second source")
	check(is_equal_approx(audio.bgm.volume_db,-6.0) and not audio.bgm.stream_paused,"trial respects current music gain and enabled state")
	city=null
	data.campaign.phase="battle";data.state={"result":null};audio.sync(data)
	check(audio.current_bgm=="battle2" and audio.bgm.stream is AudioStreamWAV,"battle transition restores the existing battle track")
	data.campaign.phase="town";data.campaign.location="east";audio.sync(data)
	check(audio.current_bgm=="east" and audio.bgm.stream is AudioStreamWAV,"leaving Astaris restores the existing location track")
	audio.set_mute("bgm",true);data.campaign.location="astaris";audio.sync(data)
	check(audio.bgm.stream is AudioStreamMP3 and audio.bgm.stream_paused,"trial follows the saved BGM mute state")
	check(await audio.finish_audio(),"closing playback releases the experimental stream")
	audio.queue_free();await process_frame;audio=null
	quit(0 if checks.all(func(ok):return ok) else 1)
