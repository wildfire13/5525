extends SceneTree
var failures: Array[String]=[]
var count:=0
var ui_events=[]
func check(ok: bool,label: String):
	count+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():check(false,"initialization");quit(1);return
	game.checks_fast=true;game.audio.fast_mode=true
	# Sound-event assertions explicitly opt in; ordinary playtests start muted.
	for kind in ["bgm","voice","se"]:game.audio.set_mute(kind,false)
	game.audio.ui_sound_started.connect(func(id):ui_events.append(id))
	check(game.campaign().location=="astaris","single-window campaign initial state")
	game.navigate("party");await process_frame
	check(game.roster().size()==24,"24 new guild candidates")
	var portrait_donor=game.roster().filter(func(member):return member.id=="character_gareth")
	check(portrait_donor.size()==1 and portrait_donor[0].name=="ガレス" and portrait_donor[0].image=="characters/guard-human-male-01.png" and game.member_name("character_gareth")=="ガレス","proposal name follows the existing male human warrior ID and portrait")
	check(game.roster().all(func(member):return member.id.begins_with("character_") and member.job.begins_with("job_") and member.has("portraitKey") and member.has("voiceKey")),"all current people have independent individual, job, portrait and voice identities")
	var second=portrait_donor[0].duplicate(true);second.id="character_same_demographics_probe";second.name="検査用";second.image="missing-probe.png"
	var first_image=game.portraits.image_for(portrait_donor[0]);var second_image=game.portraits.image_for(second)
	check(first_image!=null and second_image!=null and first_image.get_data()==second_image.get_data(),"another person with identical demographics uses its explicit portraitKey")
	var voice_data=game.data.duplicate(true);voice_data.campaign.roster.append(second);game.audio.sync(voice_data)
	check(game.audio.voice_stream(second.id,"attack")!=null and game.audio.voice_stream(second.id,"attack")==game.audio.voice_stream(portrait_donor[0].id,"attack"),"another individual uses explicit voiceKey rather than deriving a voice from demographics")
	game.navigate("items");await process_frame
	await game.act("depart",["east"]);await game.act("travel",["safe"]);await game.act("begin",[])
	check(game.state().units.filter(func(u):return u.side=="ally").all(func(u):return u.has("attackWeapons")),"allied battle units carry their equipped weapons")
	check(game.board!=null,"battle uses same root window")
	await process_frame;await process_frame
	for turn in [0.0,0.4,-0.4]:
		game.board.camera_yaw+=turn;game.board.update_camera();await process_frame
		check(game.board.cell_at(game.board.project_cell(24))==24,"camera orbit click/world conversion")
	await game.act("retreat",[])
	await game.new_game()
	ui_events.clear()
	await game.act("depart",["north","convoy"])
	check(ui_events==["confirm"],"noncombat operation plays confirm exactly once")
	ui_events.clear();await game.act("depart",["north","convoy"])
	check(ui_events==["cancel"],"rejected noncombat operation plays cancel exactly once")
	ui_events.clear();await game.update({"op":"campaign","action":"forecast","args":["safe"]})
	check(ui_events.is_empty(),"read-only forecast does not replay confirm SE")
	var music=game.audio.frontend_save()
	check(not str(music.quest_id).is_empty(),"journey music slot chosen")
	check(game.audio.quest.playing and game.audio.quest.stream is AudioStreamMP3,"journey plays the road MP3")
	# The approved travel strip replaces the old developer-facing music label.
	# Playback and the selected track are still checked separately above/below.
	check(game.find_child("TravelRouteStrip",true,false)!=null and not game.content.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("旅のBGM:")),"first journey render uses route strip without obsolete music title label")
	await game.act("travel",["safe"])
	check(game.board!=null and game.state().deploying,"deployment in same window")
	await game.act("begin",[])
	check(game.data.get("presentation")==null and not game.presenting,"sequential opening ACK settles")
	await game.update({"op":"act","kind":"action_defend","target":null,"presentation":true})
	check(game.data.get("presentation")==null,"action/causal enemy phases settle")
	check(game.audio.frontend_save()==music,"battle does not reroll journey music")
	var save=await game.engine.request({"op":"campaign_save"})
	check(save.get("ok",false),"new mid-battle save validates")
	var battle_file=OS.get_temp_dir().path_join("5525-midbattle-"+str(Time.get_ticks_usec())+".json")
	var envelope=save.data.duplicate(true);envelope.godotFrontend=music
	await game.engine.request({"op":"godot_io","action":"write","path":battle_file,"data":envelope})
	await game.new_game();await game.load_game(battle_file)
	var reloaded=await game.engine.request({"op":"campaign_save"})
	check(reloaded.get("ok",false) and reloaded.data==save.data,"mid-battle file reload preserves exact equipment and resources: "+game.notice)
	if reloaded.get("data")!=save.data and OS.has_environment("UIUX_REVIEW_EVIDENCE"):
		var debug_file=FileAccess.open(OS.get_environment("UIUX_REVIEW_EVIDENCE").path_join("save-reload-debug.json"),FileAccess.WRITE)
		if debug_file:debug_file.store_string(JSON.stringify({"before":save.data,"after":reloaded.get("data"),"notice":game.notice},"  ",true,true));debug_file.close()
	check(game.audio.frontend_save()==music and (game.audio.quest.stream_paused or not game.audio.quest.playing),"mid-battle reload preserves song selection without road playback")
	DirAccess.remove_absolute(battle_file)
	await game.act("retreat",[])
	await game.act("acknowledge",[])
	await game.new_game();
	var copy=await game.engine.request({"op":"campaign_save"})
	copy.data.state.location="west"
	await game.update({"op":"campaign_load","data":copy.data})
	game.navigate("shop");await process_frame
	var shop_quote=await game.engine.request({"op":"campaign","action":"purchaseQuote","args":["swift-boots"]})
	check(shop_quote.get("purchaseQuote",{}).get("ok",false),"current shop purchase quote")
	var before=await game.engine.request({"op":"campaign_save"})
	var owner_id=game.campaign().selected[0]
	await game.act("trial",[owner_id,"swift-boots","feet"])
	check(game.data.get("trial")!=null,"trial uses same root window: "+game.notice)
	var before_move=JSON.stringify(game.state())
	game.choose_command("action_move")
	await game.on_cell(int(game.data.choices.action_move[0]))
	check(game.pending!=null and game.board.ghost.visible,"movement preview creates transparent ghost")
	await game.inspect_movement("action_skill")
	check(game.preview.get("previewKind")=="action_skill","movement preview supports current skill range")
	game.cancel()
	check(JSON.stringify(game.state())==before_move,"cancel preview consumes no action/resources")
	await game.act("endTrial",[])
	var after=await game.engine.request({"op":"campaign_save"})
	check(before.data==after.data,"trial does not mutate campaign")
	var east=after.data.duplicate(true);east.state.location="east"
	await game.update({"op":"campaign_load","data":east})
	var bow_user=game.roster().filter(func(member):return member.job=="job_scout" and game.campaign().selected.has(member.id))[0]
	await game.act("trial",[bow_user.id,"twin-bow","rightHand"])
	game.choose_command("action_attack")
	var single=game.data.choices.action_attack[0]
	for unit in game.state().units:
		if unit.id==single:await game.on_cell(int(unit.pos));break
	check(game.pending==single and game.chosen==[single],"single target visibly retained for confirmation")
	game.cancel()
	game.choose_command("action_skill")
	var pair: Array=game.data.choices.action_skill[0].duplicate();pair.reverse()
	for uid in pair:
		for u in game.state().units:
			if u.id==uid:await game.on_cell(int(u.pos));break
	check(game.pending!=null,"two-target skill accepts reverse click order")
	var hp={}
	for u in game.state().units:
		if pair.has(u.id):hp[u.id]=u.hp
	await game.commit()
	check(game.state().units.filter(func(u):return pair.has(u.id)).all(func(u):return u.hp<hp[u.id]),"two-target damage through Godot controls and presentation")
	await game.act("endTrial",[])
	check(game.audio.voices.size()==137 and game.audio.sounds.size()==8,"all existing voice and SE cues mapped")
	check(not game.audio.valid_metadata({"version":1,"journey_key":"x","quest_id":"untrusted"}),"invalid saved music rejected without mutation")
	var portrait_owner_id="character_mirei"
	check(game.active_member(portrait_owner_id),"explicit portrait owner is selected in fresh campaign")
	await game.import_portrait(ProjectSettings.globalize_path("res://../native/assets/"+portrait_donor[0].image),portrait_owner_id)
	check(game.portraits.metadata.characters.has(portrait_owner_id),"custom portrait uses existing normalization")
	var imported=game.portraits.metadata.duplicate(true)
	while game.engine.busy or game.pages.shop_view.quote_worker:await process_frame
	var saved=await game.engine.request({"op":"campaign_save"})
	saved.data.nativePortraits=imported.duplicate(true);saved.data.godotFrontend=game.audio.frontend_save()
	var file=OS.get_temp_dir().path_join("5525-godot-test-"+str(Time.get_ticks_usec())+".json")
	var written=await game.engine.request({"op":"godot_io","action":"write","path":file,"data":saved.data})
	check(written.get("ok",false),"isolated save file written")
	var portrait_read=await game.engine.request({"op":"godot_io","action":"read","path":file,"allowed":[]})
	check(portrait_read.get("ok",false),"embedded portrait file readable immediately after write: "+str(portrait_read.get("error","")))
	await game.new_game()
	check(game.portraits.metadata.characters.is_empty(),"fresh campaign clears custom portrait overrides")
	await game.load_game(file)
	check(game.portraits.metadata.characters.has(portrait_owner_id),"portrait restored from embedded save: "+game.notice)
	check(game.portraits.metadata==imported and game.portraits.overrides.has(portrait_owner_id),"embedded portrait bytes and active override survive reload")
	var renamed=game.roster().filter(func(person):return person.id==portrait_owner_id)[0].duplicate(true)
	renamed.name="同名検査";renamed.job="job_mage";renamed.race="elf";renamed.sex="male"
	check(game.portraits.overrides.has(portrait_owner_id) and game.portraits.image_for(renamed).get_data()==game.portraits.overrides[portrait_owner_id].get_data(),"custom portrait follows explicit character_mirei despite changed presentation attributes")
	DirAccess.remove_absolute(file)
	var legacy_id="recruit-guard-human-female"
	var old_envelope=JSON.parse_string(JSON.stringify(saved.data).replace('"'+portrait_owner_id+'"','"'+legacy_id+'"'))
	var legacy_file=OS.get_temp_dir().path_join("5525-godot-legacy-portrait-"+str(Time.get_ticks_usec())+".json")
	var old_written=await game.engine.request({"op":"godot_io","action":"write","path":legacy_file,"data":old_envelope})
	check(old_written.get("ok",false),"shipped-ID portrait fixture passes incoming-ID file validation")
	await game.new_game();await game.load_game(legacy_file)
	check(game.portraits.metadata.characters.has(portrait_owner_id) and not game.portraits.metadata.characters.has(legacy_id) and game.roster().any(func(person):return person.id==portrait_owner_id),"load activates migrated custom portraits under immutable individual IDs")
	check(game.portraits.metadata==imported and game.portraits.overrides.has(portrait_owner_id),"shipped-ID migration preserves exact embedded portrait and activates override")
	DirAccess.remove_absolute(legacy_file)
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine()
	await create_timer(.15).timeout
	game.queue_free();await process_frame
	print(JSON.stringify({"suite":"frontend_smoke","checks":count,"failures":failures,"visual_review":false,"audio_driver":"Dummy"}))
	quit(0 if failures.is_empty() else 1)
