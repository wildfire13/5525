extends "res://tests/ui_feedback_20261016.gd"
func point(at: Vector2):
	var motion=InputEventMouseMotion.new()
	motion.position=at;motion.global_position=at
	root.push_input(motion,true);await frames()
func run():
	create_timer(30).timeout.connect(func():quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	game.navigate("character");await settle()
	game.pages.party_view.workspace.set_tab("ability");await settle()
	var before=await saved();var face=node("CharacterPortraitHelp")
	var center=face.get_global_rect().get_center()
	await point(center)
	check(root.gui_get_hovered_control()==face and face.tooltip_text=="クリックで画像変更","ability help icon receives the pointer and explains image change")
	await point(Vector2(5,5))
	check(root.gui_get_hovered_control()!=face,"leaving the portrait clears its hover target")
	await point(center)
	check(root.gui_get_hovered_control()==face,"reentering the portrait restores its hover target")
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=center;event.global_position=center
		root.push_input(event,true);await process_frame
	await settle()
	check(game.modal_open() and node("StatusChangePortrait")!=null,"help icon click opens image preview and customization")
	if game.modal_open():game.dialog.window.close_requested.emit();await settle()
	check(not game.modal_open() and await saved()==before,"preview dismissal preserves the complete campaign")
	var f=FileAccess.open(evidence.path_join("status-portrait-hover.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
