extends SceneTree
## Standalone catalog/asset check: no campaign, bridge or gameplay RNG.
const PortraitCatalog=preload("res://portraits.gd")
var failures: Array[String]=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func run():
	var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/") or OS.get_environment("NATIVE5525_AUDIO_OFF")!="1":
		push_error("UIUX_REVIEW_EVIDENCE, an isolated user-data profile beneath it, and NATIVE5525_AUDIO_OFF=1 are required");quit(2);return
	var rows=PortraitCatalog.read_character_catalog()
	var portraits=PortraitCatalog.new()
	check(not rows.is_empty() and portraits.characters.size()==rows.size(),"shared ordered catalog loads before campaign initialization")
	check(portraits.characters.keys()==rows.map(func(person):return person.id),"catalog indexing preserves authoritative roster order")
	var audio=preload("res://audio.gd").new();root.add_child(audio)
	for person in rows:
		var image=portraits.image_for({"id":person.id,"side":"ally"})
		check(image!=null and not image.is_empty(),"pre-campaign portrait resolves explicit catalog key "+person.id)
		check(audio.voice_keys.get(person.id)==person.voiceKey and audio.voice_stream(person.id,"attack")!=null,"pre-campaign voice resolves explicit catalog key "+person.id)
	if not rows.is_empty():
		var first=rows[0].duplicate(true);var second=first.duplicate(true)
		second.id="character_catalog_second_person_probe"
		var other=rows.filter(func(person):return person.portraitKey!=first.portraitKey and person.voiceKey!=first.voiceKey)
		if not other.is_empty():
			second.portraitKey=other[0].portraitKey;second.voiceKey=other[0].voiceKey
		var expanded=rows.duplicate(true);expanded.append(second)
		portraits.characters=PortraitCatalog.catalog_by_id(expanded)
		var supplied=portraits.image_for({"id":second.id,"side":"ally"})
		var expected=portraits.image_for({"id":second.id,"side":"ally","portraitKey":second.portraitKey})
		check(portraits.characters.size()==rows.size()+1 and supplied!=null and expected!=null and supplied.get_data()==expected.get_data(),"one additional catalog entry supports another individual with identical demographics")
		# The same synchronization handles fresh campaign and restored battle records.
		audio.sync({"campaign":{"roster":[second]},"state":{}})
		check(audio.voice_keys.get(second.id)==second.voiceKey and audio.voice_stream(second.id,"attack")!=null,"fresh roster maps independent voiceKey without demographic inference")
		audio.voice_keys.erase(second.id)
		audio.sync({"campaign":{},"state":{"units":[second]}})
		check(audio.voice_keys.get(second.id)==second.voiceKey and audio.voice_stream(second.id,"attack")!=null,"restored battle maps independent voiceKey without demographic inference")
	await audio.finish_audio();audio.queue_free();await process_frame
	print("Character catalog regression: "+str(failures.size())+" failures")
	quit(0 if failures.is_empty() else 1)
