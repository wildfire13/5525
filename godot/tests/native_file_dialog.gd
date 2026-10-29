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
	root.size=Vector2i(1280,800)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+20000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():check(false,"engine initialization");game.queue_free();await process_frame;quit(1);return
	game.checks_fast=true;game.audio.fast_mode=true
	await settle()
	var before=await snapshot()
	for i in range(3):
		await game.save_game();await settle()
		var d=chooser()
		if i==0 and OS.get_environment("NATIVE_DIALOG_EVIDENCE")!="" and DisplayServer.get_name()!="headless":
			await create_timer(1).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("NATIVE_DIALOG_EVIDENCE").path_join("linux-save-picker.png"))
		check(d.use_native_dialog and d.access==FileDialog.ACCESS_FILESYSTEM,"save requests OS filesystem chooser")
		check(d.file_mode==FileDialog.FILE_MODE_SAVE_FILE and d.filters==PackedStringArray(["*.json ; 5525進行セーブ"]),"save retains JSON filter and mode")
		check(d.current_file.begins_with("5525-godot-") and d.current_file.ends_with(".json"),"unique JSON default name retained")
		check(d.current_dir==ProjectSettings.globalize_path("user://").trim_suffix("/"),"existing save directory hint retained")
		d.hide() # Native OS picker visibility is external to Window.visible.
		check(game.file_dialog_open() and game.modal_open(),"hidden native picker still blocks game modal operations")
		game.load_dialog()
		check(game.find_children("*","FileDialog",true,false).size()==1,"repeated request cannot stack native pickers")
		var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
		var prior_page=game.page;game._unhandled_key_input(escape)
		check(game.page==prior_page and game.file_dialog_open(),"native picker owns Escape without changing game page")
		d.canceled.emit();await settle()
		check(not game.file_dialog_open() and game.find_children("*","FileDialog",true,false).is_empty() and await snapshot()==before,"repeated save cancel cleans dialog without changing campaign")
		game.load_dialog();await settle();d=chooser()
		check(d.use_native_dialog and d.file_mode==FileDialog.FILE_MODE_OPEN_FILE and d.filters==PackedStringArray(["*.json ; 5525進行セーブ"]),"load requests OS chooser with existing JSON filter")
		d.canceled.emit();await settle()
		check(game.find_children("*","FileDialog",true,false).is_empty() and await snapshot()==before,"repeated load cancel preserves state")
	var path=OS.get_temp_dir().path_join("5525-native-picker-"+str(Time.get_ticks_usec())+".json")
	await game.save_game();await settle();chooser().file_selected.emit(path);await settle()
	check(FileAccess.file_exists(path),"selected new destination writes snapshot")
	var original_bytes=FileAccess.get_file_as_bytes(path)
	var changed=before.duplicate(true);changed.state.gold=99
	await game.update({"op":"campaign_load","data":changed});await settle()
	await game.save_game();await settle();chooser().file_selected.emit(path);await settle()
	var confirmation=game.find_child("OverwriteConfirmation",false,false)
	check(confirmation!=null and FileAccess.get_file_as_bytes(path)==original_bytes,"existing destination requires application overwrite approval")
	if confirmation!=null:confirmation.canceled.emit();await settle()
	check(FileAccess.get_file_as_bytes(path)==original_bytes,"cancel overwrite preserves exact original bytes")
	await game.save_game();await settle();chooser().file_selected.emit(path);await settle()
	confirmation=game.find_child("OverwriteConfirmation",false,false)
	if confirmation!=null:confirmation.confirmed.emit();await settle()
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).state.gold==99,"approved overwrite writes changed snapshot")
	await game.update({"op":"campaign_load","data":before});await settle()
	game.load_dialog();await settle();chooser().file_selected.emit(path);await settle()
	check(await snapshot()==before,"load destination selection still waits for replacement confirmation")
	game.find_children("*","ConfirmationDialog",true,false)[0].canceled.emit();await settle()
	check(await snapshot()==before,"load replacement cancel preserves campaign")
	game.load_dialog();await settle();chooser().file_selected.emit(path);await settle()
	game.find_children("*","ConfirmationDialog",true,false)[0].confirmed.emit();await settle()
	check(game.campaign().gold==99,"approved load roundtrips selected JSON through adapter")
	DirAccess.remove_absolute(path)
	print(JSON.stringify({"suite":"native_file_dialog","checks":checks,"failures":failures,"display_server":DisplayServer.get_name(),"native_file_feature":DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE),"os_picker_interaction":false}))
	game.closing=true;game.save_notice.dismiss();await game.audio.finish_audio();await game.engine.finish_diagnostics();game.engine.close_engine();await create_timer(.2).timeout
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
