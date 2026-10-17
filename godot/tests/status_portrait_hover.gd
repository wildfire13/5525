extends "res://tests/ui_feedback_20261016.gd"
func point(window: Window,at: Vector2):
	var motion=InputEventMouseMotion.new();motion.position=at+Vector2(window.position);motion.global_position=motion.position;root.push_input(motion,true);await frames()
func run():
	create_timer(30).timeout.connect(func():quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;game.pages.party_view.open_detail("guard");await settle()
	var before=await saved();var window=game.dialog.window;var face=node("StatusPortrait")
	await point(window,Vector2(5,5));await point(window,face.get_global_rect().get_center())
	check(window.gui_get_hovered_control()==face,"GUI pointer reaches status portrait")
	var hint=node("StatusPortraitHoverHint")
	check(hint!=null and hint.visible and hint.get_child(0).text=="クリックで画像変更","hover shows requested caption inside status window")
	check(hint!=null and hint.get_parent()==window and hint.mouse_filter==Control.MOUSE_FILTER_IGNORE and Rect2(Vector2.ZERO,Vector2(window.size)).encloses(hint.get_rect()),"hint stays within window and cannot intercept pointer")
	await point(window,Vector2(5,5));check(hint!=null and not hint.visible,"leaving portrait hides hint")
	await point(window,face.get_global_rect().get_center());check(hint!=null and hint.visible,"reentering portrait shows hint again")
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=face.get_global_rect().get_center()+Vector2(window.position);press.global_position=press.position;root.push_input(press,true);await settle()
	check(node("StatusPortraitPreview")!=null and node("StatusChangePortrait")!=null and not hint.visible,"portrait click still opens preview and image change")
	node("StatusPortraitPreview").close_requested.emit();await settle()
	game.pages.party_view.refresh_modal();await settle()
	check(not is_instance_valid(hint),"status rebuild removes previous hover hint")
	check(await saved()==before,"hover and preview cancel preserve complete save")
	var f=FileAccess.open(evidence.path_join("status-portrait-hover.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
