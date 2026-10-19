extends Node
var bgm: AudioStreamPlayer
var quest: AudioStreamPlayer
var voice: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var ui_player: AudioStreamPlayer
var bgm_catalog: Dictionary = {}
var voices: Dictionary = {}
var sounds: Dictionary = {}
var streams: Dictionary = {}
var quest_slots: Array = []
var quest_id := ""
var journey_key := ""
var current_bgm := ""
var quest_loaded := ""
var muted := {"bgm":true,"voice":true,"se":true}
var seen: Dictionary = {}
var connection_generation:=-1
var result_key := ""
var fast_mode := false
var effect_cursor := 0
signal ui_sound_started(id: String)
signal phase_voice_started(character_id: String,cue: String)
signal phase_sound_started(id: String)
func follow_connection(generation: int):
	if generation==connection_generation:return
	connection_generation=generation;seen.clear();result_key=""
	voice.stop()
	for sound in effects:sound.stop()
func player(volume: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.volume_db = volume
	add_child(p)
	return p
func _ready():
	bgm=player(-6); quest=player(-6); voice=player(0); ui_player=player(-6)
	for i in range(4): effects.append(player(-4))
	var base = ProjectSettings.globalize_path("res://../native/assets")
	var m = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("music/manifest.json")))
	for t in m.tracks: bgm_catalog[t.id]=base.path_join("music").path_join(t.filename)
	bgm_catalog["battle2"]=bgm_catalog[m.routes.battle]
	var v = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("voices/manifest.json")))
	for c in v.characters:
		for cue in c.prepared: voices[c.id+"/"+cue] = base.path_join("voices").path_join(c.prepared[cue].path)
	var s = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("se/manifest.json")))
	for e in s.se: sounds[e.id]=base.path_join("se").path_join(e.filename)
	quest_slots = JSON.parse_string(FileAccess.get_file_as_string("res://assets/quest_music.json")).tracks
	for track in quest_slots:bgm_catalog[track.id]=track.path
func load_wav(path: String, loop := false) -> AudioStreamWAV:
	if path.is_empty() or not FileAccess.file_exists(path): return null
	var key = path + str(loop)
	if streams.has(key): return streams[key]
	var stream = AudioStreamWAV.load_from_file(path)
	if stream != null and loop:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=int(round(stream.get_length()*stream.mix_rate))
	streams[key]=stream
	return stream
func quest_stream(track: Dictionary) -> AudioStreamWAV:
	var stream=load_wav(str(bgm_catalog.get(track.id,"")),true)
	if stream!=null:
		stream.loop_begin=int(track.loop_start_frame)
		stream.loop_end=int(track.loop_end_frame_exclusive)
	return stream
func choose_journey(c: Dictionary) -> void:
	var j = c.get("journey")
	if j == null:
		journey_key="";quest_id="";quest.stop();quest_loaded=""
		return
	var key = str(j.token)+":"+str(j.origin)+":"+str(j.destination)
	if key == journey_key and not quest_id.is_empty(): return
	journey_key=key
	quest_id=str(quest_slots[randi()%quest_slots.size()].id)
	quest.stop(); quest_loaded=""
func quest_title() -> String:
	for t in quest_slots:
		if t.id == quest_id: return t.title
	return "旅曲未選択"
func frontend_save() -> Dictionary:
	return {"version":1,"journey_key":journey_key,"quest_id":quest_id}
func valid_metadata(data) -> bool:
	if not data is Dictionary:return false
	if data.is_empty():return true
	if data.get("version") != 1 or not data.get("journey_key","") is String or data.get("journey_key","").length()>200:return false
	var valid=data.get("quest_id","")==""
	for t in quest_slots:
		if t.id==data.get("quest_id"):valid=true
	return valid
func restore(data: Dictionary) -> bool:
	if not valid_metadata(data):return false
	# Music metadata does not reset presentation/result deduplication.
	if data.is_empty(): journey_key="";quest_id="";quest.stop();quest_loaded="";return true
	journey_key=data.get("journey_key","");quest_id=data.get("quest_id","");quest.stop();quest_loaded=""
	return true
func sync(d: Dictionary) -> void:
	var c: Dictionary = d.get("campaign",{})
	choose_journey(c)
	var state: Dictionary = d.get("state") if d.get("state") is Dictionary else {}
	var phase = c.get("phase","town")
	var battle = (phase=="battle" or d.get("trial") != null) and state.get("result")==null
	var on_road = phase in ["road","deployment","battle","camp"] and not battle and d.get("trial")==null
	var key = "battle2" if battle else str(c.get("location","astaris")) if not on_road else ""
	if phase=="arrival": key=str(c.get("journey",{}).get("destination",key))
	if key != current_bgm:
		bgm.stop();current_bgm=key
		bgm.stream=load_wav(str(bgm_catalog.get(key,"")),true)
		if bgm.stream: bgm.play()
	bgm.stream_paused=muted.bgm
	if on_road:
		if quest_loaded != quest_id:
			quest.stop();quest_loaded=quest_id
			for t in quest_slots:
				if t.id==quest_id:
					quest.stream=quest_stream(t)
					if quest.stream: quest.play()
		quest.stream_paused=muted.bgm
	else: quest.stream_paused=true
	if state.get("result")==null:result_key=""
	if state.get("result") != null and (d.get("presentation")==null or d.presentation.phase=="settled"):
		var rk=str(connection_generation)+":"+str(state.get("campaignToken","trial"))+":"+str(state.get("campaignStage",0))+":"+str(state.result)
		if rk!=result_key:
			result_key=rk; ui("failure" if state.get("failure") else "victory")
func close_audio() -> void:
	for p in [bgm,quest,voice,ui_player]+effects:
		if is_instance_valid(p):p.stop();p.stream=null
	streams.clear()
func finish_audio() -> bool:
	# AudioServer releases stopped playback on its mix/main-thread cleanup.
	# Wait for weak references, never hold WAVs alive during the drain.
	var watched=streams.values().map(func(stream):return weakref(stream))
	close_audio()
	var deadline=Time.get_ticks_msec()+1000
	while watched.any(func(ref):return ref.get_ref()!=null) and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	return watched.all(func(ref):return ref.get_ref()==null)
func _exit_tree():
	close_audio()
func set_mute(kind: String, value: bool) -> void:
	muted[kind]=value
	if kind=="voice" and value: voice.stop()
	if kind=="se" and value:
		for p in effects: p.stop()
		ui_player.stop()
func ui(id: String) -> void:
	if muted.se: return
	ui_player.stream=load_wav(str(sounds.get(id,"")))
	if ui_player.stream:
		ui_player.play();ui_sound_started.emit(id)
func phase(p: Dictionary) -> float:
	var key=str(connection_generation)+":phase:"+str(p.id)+":"+str(p.index)
	if seen.has(key): return 0.0
	seen[key]=true
	if seen.size()>800: seen.erase(seen.keys()[0])
	var duration := 0.22
	if not muted.voice:
		for e in p.get("voiceEvents",[]):
			voice.stream=load_wav(str(voices.get(str(e.character_id)+"/"+str(e.cue),"")))
			if voice.stream:
				voice.play();phase_voice_started.emit(str(e.character_id),str(e.cue));duration=maxf(duration,voice.stream.get_length()+0.04)
	var se_id=""
	if p.phase=="action":
		if p.get("kind")=="attack":se_id="attack"
		elif p.get("kind") in ["skill","return"]:
			se_id="attack" if p.get("skill_id") in ["archer","scout","stamp","retreatSlash","knockback","splitShot","pincer"] else "skill"
		elif p.get("kind")=="ether":se_id="heal"
	elif p.phase=="hurt":se_id="hit"
	elif p.phase=="heal":se_id="heal"
	var group=str(connection_generation)+":group:"+str(p.action_id)+":"+p.phase+":"+str(p.get("impact_group_id",0))
	if not se_id.is_empty() and not muted.se and not seen.has(group):
		seen[group]=true
		var sound=effects[effect_cursor%effects.size()];effect_cursor+=1
		sound.stream=load_wav(str(sounds.get(se_id,"")))
		if sound.stream: sound.play();phase_sound_started.emit(se_id);duration=maxf(duration,sound.stream.get_length())
	return 0.0 if fast_mode else duration
