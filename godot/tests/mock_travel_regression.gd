extends SceneTree
var failures=[]
func _initialize():call_deferred("run")
func check(value,label):
	print(("PASS " if value else "FAIL ")+label)
	if not value:failures.append(label)
func run():
	root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+20000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():quit(1);return
	game.checks_fast=true;game.audio.fast_mode=true
	game.navigate("map")
	for i in range(5):await process_frame
	check(game.find_child("TownMap",true,false)!=null,"world map mounted")
	check(game.find_child("TownMap",true,false).event_markers.is_empty(),"undisclosed route encounters are not drawn")
	check(game.find_child("DepartButton",true,false)!=null,"departure in map action row")
	check(game.find_child("TravelQuestDetails",true,false)==null,"no quest detail button without active quest")
	var offers=game.campaign().board;var porter=game.roster().filter(func(u):return u.job=="porter" and game.campaign().selected.has(u.id))[0]
	await game.act("accept",[offers[0].id,porter.id]);game.navigate("map")
	for i in range(5):await process_frame
	check(game.find_child("TravelQuestDetails",true,false)!=null,"active quest detail button")
	await game.act("depart",[offers[0].to,"convoy"])
	for i in range(5):await process_frame
	var strip=game.find_child("TravelRouteStrip",true,false)
	check(strip!=null,"horizontal travel strip mounted")
	check(game.find_child("RouteChoices",true,false)!=null,"route choice buttons")
	check(strip.size.y==160,"fixed compact travel strip height")
	check(game.find_child("RouteChoice_short",true,false).text.contains("2時間") and not game.find_child("RouteChoice_short",true,false).text.contains("敵") and game.find_child("RouteChoice_safe",true,false).text.contains("4時間"),"route choices expose time without disclosing enemy details")
	if not OS.get_environment("TRAVEL_FIX_CAPTURE").is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TRAVEL_FIX_CAPTURE").path_join("road-choices.png"))
	game.find_child("TravelMapToggle",true,false).pressed.emit()
	for i in range(5):await process_frame
	var full_map=game.find_child("TravelFullMap",true,false)
	check(full_map!=null and full_map.read_only,"expanded travel map is read only")
	game.find_child("TravelMapToggle",true,false).pressed.emit()
	for i in range(5):await process_frame
	check(game.find_child("TravelFullMap",true,false)==null and game.find_child("TravelRouteStrip",true,false)!=null,"collapse restores compact route only")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
