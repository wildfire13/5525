extends SceneTree

var failures: Array[String]=[]
var game

func check(ok: bool,label: String):
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)

func expect_song(file: String):
	var player=game.audio.bgm
	var stream=player.stream as AudioStreamMP3
	check(stream!=null and stream.resource_path.get_file()==file and stream.loop and player.playing and not game.audio.quest.playing,file+" plays alone and loops")

func _initialize():call_deferred("run")

func run():
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():quit(1);return
	game.audio.test_silence=true
	game.audio.set_sound_level("bgm",100)
	game.navigate("hub");expect_song("city_01.mp3")
	game.navigate("character");expect_song("city_01.mp3")
	game.navigate("board");expect_song("city_01.mp3")
	game.navigate("map");expect_song("city_01.mp3")
	check(game.find_child("TownStill",true,false)!=null and game.find_child("FacilityStill",true,false)==null,"astaris world map keeps town still")
	game.navigate("party");expect_song("guild_01.mp3")
	game.navigate("character");expect_song("guild_01.mp3")
	game.navigate("inn");expect_song("inn_01.mp3")
	game.navigate("character");expect_song("inn_01.mp3")
	for pair in [["east","lively"],["west","brush"],["south","cheerful"],["north","fishy"]]:
		game.campaign().location=pair[0]
		game.navigate("hub");expect_song(pair[0]+".mp3")
		game.navigate("character");expect_song(pair[0]+".mp3")
		game.navigate("board");expect_song(pair[0]+".mp3")
		game.navigate("map");expect_song(pair[0]+".mp3")
		check(game.find_child("TownStill",true,false)!=null and game.find_child("FacilityStill",true,false)==null,pair[0]+" world map keeps town still")
		game.navigate("shop");expect_song(pair[1]+".mp3")
		game.navigate("character");expect_song(pair[1]+".mp3")
		game.navigate("shop");expect_song(pair[1]+".mp3")
		game.pages.facility_entry.choose("buy");expect_song(pair[1]+".mp3")
		game.navigate("character");expect_song(pair[1]+".mp3")
		game.navigate("hub");expect_song(pair[0]+".mp3")
	game.navigate("map");expect_song("north.mp3")
	check(game.pages.facility_art.visit_key.is_empty() and game.find_child("TownStill",true,false)!=null and game.find_child("FacilityStill",true,false)==null,"world map keeps current location music and town background")
	game.checks_fast=true;game.audio.fast_mode=true
	await game.new_game()
	await game.act("depart",["north","convoy"])
	var selected=game.audio.quest_id
	check(game.audio.quest.playing and game.audio.quest.stream.resource_path.get_file()=="road_01.mp3" and game.audio.quest.stream.loop and not game.audio.bgm.playing,"road_01.mp3 plays alone and loops")
	for tab in ["character","board","map"]:
		game.navigate(tab)
		check(game.audio.quest.playing and game.audio.quest_id==selected and game.find_child("RoadStill",true,false)!=null,"road "+tab+" keeps journey music and road background")
	game.navigate("road")
	await game.act("travel",["safe"]);expect_song("decision.mp3")
	game.navigate("character");expect_song("decision.mp3")
	game.mock_shell.toggle_character();expect_song("decision.mp3")
	await game.act("begin",[]);expect_song("battle_01.mp3")
	var data=game.data.duplicate(true)
	data.campaign.phase="camp";game.audio.sync(data)
	check(game.audio.quest.playing and game.audio.quest_id==selected,"camp resumes the same journey music")
	for tab in ["character","board","map"]:
		game.pages.facility_art.sync("camp",str(data.campaign.get("location","astaris")),tab)
		game.audio.sync(data,"")
		check(game.audio.quest.playing and game.audio.quest_id==selected and game.pages.facility_art.visit_key.is_empty(),"camp "+tab+" keeps journey music and road visit state")
	data.trial={};data.campaign.phase="town";game.audio.sync(data)
	check(game.audio.bgm.stream is AudioStreamWAV and game.audio.current_bgm=="battle2","shop equipment trial keeps original battle music")
	game.closing=true;game.invalidate_preview();game.engine.close_engine()
	check(await game.audio.finish_audio(),"closing releases music streams")
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
