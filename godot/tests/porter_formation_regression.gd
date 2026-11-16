extends "res://tests/skill_grant_hud.gd"
func run():
	create_timer(45).timeout.connect(func():print("FAIL Porter formation watchdog");quit(2))
	if OS.get_environment("NATIVE5525_AUDIO_OFF")!="1":quit(2);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var startup_deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<startup_deadline:await process_frame
	if game.data.is_empty():print("BLOCKED game bridge did not become ready");quit(2);return
	game.checks_fast=true;game.audio.fast_mode=true
	var ids=["character_teo","character_yuno","character_mirei","character_rio","character_merina"]
	for step in [["select",[ids]],["accept",["sluice-bell",ids[0]]],["depart",["east"]],["travel",["short"]]]:
		var result=await game.update({"op":"campaign","action":step[0],"args":step[1]})
		check(result.get("ok",false),"fresh campaign: "+step[0])
		await settle()
	check(game.data.formed.ally==false,"second Porter leaves the formation incomplete")
	game.hud.toggle_details();await settle()
	var labels=game.dialog.window.find_children("*","Label",true,false).map(func(n):return n.text)
	check(labels.has("味方の条件マス 2/3"),"formation details exclude the second Porter from occupied guard slots")
	check(labels.has("味方陣形 未発動 / 攻撃×1・被ダメージ×1"),"formation detail factor matches engine result")
	check(labels.any(func(t):return t.contains("ポーター以外")),"formation criteria text explains Porter exclusion")
	game.dialog.close();await settle()
	check((await game.update({"op":"campaign","action":"deploy","args":[ids[1],14]})).get("ok",false),"move second Porter out of the guard slots")
	check((await game.update({"op":"campaign","action":"deploy","args":[ids[4],24]})).get("ok",false),"fill the last slot with a non-Porter")
	check(game.data.formed.ally==true,"three living non-Porters establish the formation")
	game.hud.toggle_details();await settle()
	labels=game.dialog.window.find_children("*","Label",true,false).map(func(n):return n.text)
	check(labels.has("味方の条件マス 3/3"),"display count reaches 3/3 with three non-Porters")
	check(labels.has("味方陣形 発動 / 攻撃×1.5・被ダメージ×0.75"),"displayed battle factor matches engine result")
	game.dialog.close(false);game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	quit(0 if checks.all(func(ok):return ok) else 1)
