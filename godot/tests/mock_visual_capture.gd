extends SceneTree
var game
func _initialize():call_deferred("run")
func settle():
	for i in range(15):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
	await RenderingServer.frame_post_draw
func capture(label):
	await settle()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qa/mock-"+label+".png"))
func run():
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	await capture("town")
	game.navigate("character");await capture("party")
	game.navigate("party");await capture("guild-entry")
	game.pages.facility_entry.choose("guild");await capture("guild")
	game.navigate("board");await capture("quests")
	game.navigate("map");await capture("map")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame;quit()
