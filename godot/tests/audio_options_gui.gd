extends "res://tests/equipment_hover_gui.gd"
func run():
	create_timer(180).timeout.connect(func():print("FAIL audio options OS watchdog");quit(2))
	root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1180,812)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true;await settle()
	check(game.audio.muted.values().all(func(v):return v),"OS options checks start all sound OFF")
	var original=await saved()
	for size in [Vector2i(1180,812),Vector2i(960,540),Vector2i(1180,812)]:
		await os_resize(size)
		for repeat in range(3):
			await os_click(node("CommonMenuButton"));check(game.menu.visible,"actual right menu click opens "+str(size)+str(repeat))
			await snapshot("options-open-"+str(size.x)+"-"+str(repeat))
			await os_click(node("CommonMenuButton"));check(not game.menu.visible,"same right menu click closes without reopening "+str(size)+str(repeat))
		await os_click(node("CommonMenuButton"))
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(game.menu.get_global_rect()),"options panel stays inside resized game")
		for repeat in range(game.menu_focus_controls().size()+2):
			await os_key("Tab")
			check(game.menu.is_ancestor_of(game.get_viewport().gui_get_focus_owner()),"Tab focus remains inside options")
		var scroll=node("CommonMenuScroll")
		for kind in ["bgm","voice","se"]:
			var slider=node("AudioVolume_"+kind);scroll.ensure_control_visible(slider);await settle()
			var left=slider.get_global_rect().position+Vector2(5,slider.size.y/2)+Vector2(slider.get_window().position)
			await os_mouse(left,"click");check(game.audio.volumes[kind]==0,kind+" real slider left is zero percent")
			check(node("AudioVolumeValue_"+kind).text=="0% 無音" and not game.audio.audible(kind),kind+" zero percent explicitly reads silent")
			await snapshot("options-zero-"+kind+"-"+str(size.x))
			var right=slider.get_global_rect().end-Vector2(5,slider.size.y/2)+Vector2(slider.get_window().position)
			await os_mouse(right,"click");check(game.audio.volumes[kind]==100,kind+" real slider right is 100 percent")
			check(not game.audio.muted[kind] and game.audio.effective_volume(kind)==100,kind+" positive slider simultaneously sets ON and level")
			# This deliberate slider-direction check uses Dummy output. Immediately
			# restore silence before other UI operations or screenshots.
			game.audio.set_mute(kind,true);game.audio.sync(game.data)
		await os_key("Escape");check(not game.menu.visible,"Escape closes options")
		await os_click(node("CommonMenuButton"));await os_mouse(Vector2(12,root.size.y/2),"click")
		check(not game.menu.visible,"outside click closes options without activating scene behind it")
	check(await saved()==original,"options control and repeated menu toggles do not mutate game save")
	check(game.audio.muted.values().all(func(v):return v),"OS options checks finish all sound OFF")
	var file=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
