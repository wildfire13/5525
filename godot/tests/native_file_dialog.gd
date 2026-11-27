extends SceneTree
## Native request and save/load callback contract; not proof of OS picker UI.
var game
var failures=[]
var checks=0
func _initialize():call_deferred("run")
func check(value: bool,label: String):
	checks+=1
	if not value:failures.append(label)
	print(("PASS " if value else "FAIL ")+label)
func settle():
	for i in range(5):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func chooser():return game.find_children("*","FileDialog",true,false)[0]
func snapshot():return (await game.engine.request({"op":"campaign_save"})).data
func run():
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+20000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():check(false,"engine initialization");game.queue_free();await process_frame;quit(1);return
	game.checks_fast=true;game.audio.fast_mode=true
	await settle()
	var before=await snapshot()
	game.file_dialog(FileDialog.FILE_MODE_OPEN_FILE,PackedStringArray([preload("res://portraits.gd").FILE_FILTER]),func(_path):pass)
	await settle()
	var d=chooser()
	check(d.use_native_dialog,"portrait picker requests native dialog")
	d.canceled.emit();await settle()
	check(not game.file_dialog_open() and await snapshot()==before,"cancel preserves campaign")
	print(JSON.stringify({"suite":"native_file_dialog","checks":checks,"failures":failures,"display_server":DisplayServer.get_name(),"native_file_feature":DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE),"os_picker_interaction":false}))
	game.closing=true;game.save_notice.dismiss();await game.audio.finish_audio();await game.engine.finish_diagnostics();game.engine.close_engine();await create_timer(.2).timeout
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
