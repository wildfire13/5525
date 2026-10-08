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
	root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():check(false,"initialization");quit(1);return
	game.checks_fast=true;game.audio.fast_mode=true
	game.audio.ui_sound_started.connect(func(id):ui_events.append(id))
	check(game.campaign().location=="astaris","single-window campaign initial state")
	game.navigate("party");await process_frame
	check(game.roster().size()==11,"eleven party portrait cards")
	game.navigate("items");await process_frame
	var source=ProjectSettings.globalize_path("res://../native/test_fixtures/campaign-a51a773-battle.json")
	await game.load_game(source)
	check(game.campaign().phase=="battle","legacy battle save via real file adapter")
	check(game.state().units.filter(func(u):return u.side=="ally").all(func(u):return u.has("attackWeapons")),"legacy equipment migration")
	check(game.board!=null,"battle uses same root window")
	await process_frame;await process_frame
	for camera in range(3):
		game.board.set_camera(camera);await process_frame
		check(game.board.cell_at(game.board.project_cell(24))==24,"camera %d click/world conversion" % camera)
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
	check(game.audio.quest.playing and game.audio.quest.stream!=null,"journey plays a delivered quest WAV")
	check(game.content.find_children("*","Label",true,false).any(func(label):return label.text=="旅のBGM: "+game.audio.quest_title()),"chosen song title displayed on the first journey render")
	await game.act("travel",["safe"])
	check(game.board!=null and game.state().deploying,"deployment in same window")
	await game.act("begin",[])
	check(game.data.get("presentation")==null and not game.presenting,"sequential opening ACK settles")
	await game.update({"op":"act","kind":"guard","target":null,"presentation":true})
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
	if reloaded.get("data")!=save.data:
		var debug_file=FileAccess.open("res://qa/save-reload-debug.json",FileAccess.WRITE);debug_file.store_string(JSON.stringify({"before":save.data,"after":reloaded.get("data"),"notice":game.notice},"  ",true,true));debug_file.close()
	check(game.audio.frontend_save()==music and (game.audio.quest.stream_paused or not game.audio.quest.playing),"mid-battle reload preserves song selection without road playback")
	DirAccess.remove_absolute(battle_file)
	await game.act("retreat",[])
	await game.act("acknowledge",[])
	var copy=await game.engine.request({"op":"campaign_save"})
	copy.data.state.location="west"
	await game.update({"op":"campaign_load","data":copy.data})
	game.navigate("shop");await process_frame
	await game.preview_gear("swift-boots") # Selected slot is upperBody; rejected preview is safe.
	game.shop_slot="feet";await game.preview_gear("swift-boots")
	check(game.gear_preview.get("eligible",false),"eight-slot shop quote")
	var before=await game.engine.request({"op":"campaign_save"})
	await game.act("trial",["guard","swift-boots","feet"])
	check(game.data.get("trial")!=null,"trial uses same root window: "+game.notice)
	var before_move=JSON.stringify(game.state())
	game.choose_command("move")
	await game.on_cell(int(game.data.choices.move[0]))
	check(game.pending!=null and game.board.ghost.visible,"movement preview creates transparent ghost")
	await game.inspect_movement("skill")
	check(game.preview.get("previewKind")=="skill","movement preview supports current skill range")
	game.cancel()
	check(JSON.stringify(game.state())==before_move,"cancel preview consumes no action/resources")
	await game.act("endTrial",[])
	var after=await game.engine.request({"op":"campaign_save"})
	check(before.data==after.data,"trial does not mutate campaign")
	var east=after.data.duplicate(true);east.state.location="east"
	await game.update({"op":"campaign_load","data":east})
	await game.act("trial",["archer","twin-bow","rightHand"])
	game.choose_command("attack")
	var single=game.data.choices.attack[0]
	for unit in game.state().units:
		if unit.id==single:await game.on_cell(int(unit.pos));break
	check(game.pending==single and game.chosen==[single],"single target visibly retained for confirmation")
	game.cancel()
	game.choose_command("skill")
	var pair: Array=game.data.choices.skill[0].duplicate();pair.reverse()
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
	await game.import_portrait(ProjectSettings.globalize_path("res://../native/assets/knight.png"),"guard")
	check(game.portraits.metadata.characters.has("guard"),"custom portrait uses existing normalization")
	var saved=await game.engine.request({"op":"campaign_save"})
	saved.data.nativePortraits=game.portraits.metadata;saved.data.godotFrontend=game.audio.frontend_save()
	var file=OS.get_temp_dir().path_join("5525-godot-test-"+str(Time.get_ticks_usec())+".json")
	var written=await game.engine.request({"op":"godot_io","action":"write","path":file,"data":saved.data})
	check(written.get("ok",false),"isolated save file written")
	await game.new_game();await game.load_game(file)
	check(game.portraits.metadata.characters.has("guard"),"portrait restored from embedded save")
	DirAccess.remove_absolute(file)
	game.audio.close_audio();game.engine.close_engine()
	await create_timer(.15).timeout
	game.queue_free();await process_frame
	print(JSON.stringify({"suite":"frontend_smoke","checks":count,"failures":failures,"visual_review":false,"audio_driver":"Dummy"}))
	quit(0 if failures.is_empty() else 1)
