extends "res://tests/ui_feedback_20261016.gd"
func run():
	create_timer(30).timeout.connect(func():quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;game.navigate("map");await settle()
	var before=await saved();var map=node("TownMap");var record=[]
	for viewport in [Vector2i(1920,1080),Vector2i(1920,1032)]:
		root.size=viewport;await settle();map=node("TownMap")
		var groups={}
		for marker in map.event_markers:
			if not groups.has(marker.route):groups[marker.route]=[]
			groups[marker.route].append(marker)
		check(groups.size()==8,"all eight routes at "+str(viewport))
		for route in groups:
			var markers=groups[route];check(markers.size()==2,"two markers "+route)
			var a=markers[0];var b=markers[1];var spacing=a.position.distance_to(b.position);var gap=spacing-a.radius-b.radius
			check(gap>=1.9,"separate circles with visible gap "+route)
			check(is_equal_approx(a.from.distance_to(a.position),spacing) and is_equal_approx(b.position.distance_to(a.to),spacing),"equal edge/center intervals "+route)
			record.append({"viewport":str(viewport),"route":route,"radius":a.radius,"center_spacing":spacing,"circle_gap":gap})
	check(await saved()==before,"map geometry has no campaign mutation")
	var f=FileAccess.open(evidence.path_join("map-event-spacing.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"measurements":record},"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
