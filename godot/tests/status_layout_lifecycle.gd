extends "res://tests/ui_feedback2_20261016.gd"
func run():
	create_timer(75).timeout.connect(func():print("FAIL status lifecycle watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var before=await saved()
	var owner="character_mirei"
	game.navigate("map");await settle();await click("RosterMember_"+owner)
	game.pages.party_view.workspace.set_tab("ability");await settle()
	var badge=node("ElementIcon_earth")
	check(badge!=null and badge.texture!=null and badge.tooltip_text.contains("地属性"),"character ability presents the guard's elemental identity and explanation")
	var stats=game.roster().filter(func(member):return member.id==owner)[0].stats
	for defense in [false,true]:
		var row=node("CharacterDefense" if defense else "CharacterElementalAttack")
		var prefix="def" if defense else "atk"
		var expected=["DEF 物%d" % stats.def] if defense else ["属性ATK"]
		for element in ["fire","water","earth"]:
			var icon=row.get_node_or_null("ElementIcon_"+element)
			check(icon is TextureRect and icon.texture!=null,"%s has %s icon" % [prefix,element])
			expected.append("%s%d" % [preload("res://element_badges.gd").spec(element).label,stats[prefix+element.capitalize()]])
		var labels=row.find_children("*","Label",true,false).map(func(label):return label.text)
		check(labels==expected,"%s displays the character's values in element order" % prefix)
	check(await saved()==before,"reading abilities preserves the campaign")
	var cases=battle_fixture()
	await game.update({"op":"campaign_load","data":cases.archer});await settle()
	game.board.camera_pan=Vector2(1.5,-2);game.board.camera_yaw=.35
	game.board.camera_pitch=.6;game.board.world.zoom=14.0;game.board.persist_camera()
	var camera=game.preferences.camera().duplicate(true)
	game.hud.left_panel.position+=Vector2(25,20);game.hud.left_panel.persist()
	var panel=game.preferences.config.get_value("windows","battle_actor_b")
	check(panel is Rect2,"battle actor panel persists its layout")
	await game.update({"op":"campaign_load","data":before});await settle()
	check(game.preferences.config.get_value("windows","battle_actor_b")==panel and game.preferences.camera()==camera,"returning to town preserves the saved battle panel and camera")
	check(await saved()==before,"battle to town reload restores the complete campaign")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
