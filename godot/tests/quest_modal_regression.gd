extends SceneTree
## Synthetic saves and real input dispatch. No OS dialog or real-player files.
var game
var checks := 0
var failures: Array[String] = []
func _initialize():call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)
func settle():
	for i in range(10):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func node(name_: String):return game.find_child(name_,true,false)
func key(code: int, echo := false):
	for down in [true,false]:
		var event = InputEventKey.new();event.keycode = code;event.pressed = down;event.echo = echo
		Input.parse_input_event(event);await process_frame
	await settle()
func cleanup_scene():
	var scene = node("QuestDialogue")
	if scene != null:scene._close();await settle()
func channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055,2.4)
func luminance(color: Color) -> float:
	return .2126 * channel(color.r) + .7152 * channel(color.g) + .0722 * channel(color.b)
func contrast(ink: Color, paper: Color) -> float:
	var a = luminance(ink);var b = luminance(paper)
	return (maxf(a,b) + .05) / (minf(a,b) + .05)
func verify_confirmation(d: ConfirmationDialog, context: String):
	var message = d.find_child("ConfirmationMessage",true,false)
	var panel = d.get_theme_stylebox("panel")
	check(message is Label and message.text == d.dialog_text,context + " complete confirmation text is present")
	check(panel is StyleBoxFlat,context + " panel has a measurable flat fill")
	if message is Label and panel is StyleBoxFlat:
		var ink = message.get_theme_color("font_color")
		var dark = contrast(ink,Color.BLACK.blend(panel.bg_color));var light = contrast(ink,Color.WHITE.blend(panel.bg_color))
		print("CONTRAST ",context," text=",ink," panel=",panel.bg_color," black=",dark," white=",light)
		check(ink.a == 1.0 and minf(dark,light) >= 4.5,context + " body contrast is at least 4.5:1 over dark and light backdrops")
	check(d.get_cancel_button().has_focus(),context + " starts focused on cancel")
	check(d.exclusive,context + " remains exclusive")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(d.position),Vector2(d.size))),context + " fits FHD")
func visible_confirmation():
	for dialog_ in game.find_children("*","ConfirmationDialog",true,false):
		if dialog_.visible:return dialog_
	return null
func open_load_confirmation(path: String):
	game.load_dialog();await settle()
	var chooser
	for child in game.find_children("*","FileDialog",true,false):
		if child.get_meta("file_dialog_active",false):chooser = child;break
	check(chooser is FileDialog,"actual load flow opens a file chooser")
	if chooser == null:return null
	chooser.file_selected.emit(path);await settle()
	return visible_confirmation()
func run():
	create_timer(180).timeout.connect(func():print("FAIL quest modal watchdog");quit(2))
	root.size = Vector2i(1920,1080)
	game = load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast = true;game.audio.fast_mode = true;await settle()
	var seed = await saved()
	for sample in [["turnip","north","astaris"],["kiln","astaris","east"],["wheel","east","astaris"]]:
		var id = "standalone-" + sample[0]
		for stage in ["typing","line complete","choices"]:
			var fixture = seed.duplicate(true);fixture.state.location = sample[1]
			await game.update({"op":"campaign_load","data":fixture});await settle()
			game.navigate("board");await settle();node("QuestChoice_" + id).pressed.emit();await settle()
			var before = await saved()
			node("QuestStory_" + id).pressed.emit();await process_frame
			var scene = node("QuestDialogue")
			check(scene != null,id + " " + stage + " dialogue opens")
			if scene == null:continue
			if stage == "line complete":await key(KEY_A)
			elif stage == "choices":
				for i in range(20):
					if scene.choice_row.visible:break
					await key(KEY_A)
			await key(KEY_ESCAPE)
			check(node("QuestDialogue") == null,id + " " + stage + " Escape dismisses only the dialogue")
			check(game.page == "board",id + " " + stage + " Escape does not navigate behind the dialogue")
			check(await saved() == before,id + " " + stage + " Escape does not accept cargo or mutate the save")
			await key(KEY_ESCAPE,true)
			check(game.page == "board",id + " " + stage + " held Escape does not navigate after dismissal")
			await cleanup_scene()
		# Completion dialogue must not dismiss or acknowledge the receipt behind it.
		var fixture = seed.duplicate(true);fixture.state.location = sample[1]
		await game.update({"op":"campaign_load","data":fixture});await settle()
		var porter = game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id == uid and c.job == "porter"))[0]
		await game.act("accept",[id,porter]);await settle()
		var ready = await saved();ready.state.location = sample[2];ready.state.worldTime = 10;ready.state.hours = 10
		await game.update({"op":"campaign_load","data":ready});await settle();await game.act("completeQuest",[]);await settle()
		var completed = await saved()
		check(game.results_view.active,id + " successful receipt is visible")
		node("ResultStory").pressed.emit();await process_frame;await key(KEY_ESCAPE)
		check(node("QuestDialogue") == null and game.results_view.active,id + " Escape closes result story but preserves receipt")
		check(await saved() == completed,id + " result story Escape never acknowledges or changes rewards")
		await cleanup_scene();game.results_view.reset();await settle()
	await game.update({"op":"campaign_load","data":seed});await settle();game.navigate("board");await settle()
	var before = await saved();var payload = before.duplicate(true);payload.state.gold += 7
	var path = ProjectSettings.globalize_path("user://quest-modal-synthetic.json")
	var file = FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(payload));file.close()
	var original_file = FileAccess.get_file_as_bytes(path)
	var dialog_ = await open_load_confirmation(path)
	check(dialog_ is ConfirmationDialog,"load selection reaches confirmation")
	if dialog_ is ConfirmationDialog:
		verify_confirmation(dialog_,"load")
		check(await saved() == before,"load is not applied before confirmation")
		dialog_.canceled.emit();await settle()
		check(await saved() == before and game.page == "board","cancel load preserves campaign and originating page")
	var generation = game.engine.connection_generation
	game.retry_button.pressed.emit();await settle();dialog_ = visible_confirmation()
	check(dialog_ is ConfirmationDialog,"reconnect handler uses confirmation")
	if dialog_ is ConfirmationDialog:
		verify_confirmation(dialog_,"reconnect")
		dialog_.canceled.emit();await settle()
		check(game.engine.connection_generation == generation and await saved() == before,"cancel reconnect never restarts engine or changes save")
	game.dialog.open("確認の親ウィンドウ",func(body,_actions):game.label_(body,"人工状態の確認"));await settle()
	var calls = [0];dialog_ = game.confirm("長い確認文です。".repeat(60),func():calls[0] += 1);await settle()
	verify_confirmation(dialog_,"nested long confirmation")
	var scroll = dialog_.find_child("ConfirmationTextScroll",true,false);scroll.scroll_vertical = 100000;await settle()
	var message = dialog_.find_child("ConfirmationMessage",true,false)
	check(message.get_global_rect().end.y <= scroll.get_global_rect().end.y + 2,"long confirmation remains scrollable to its end")
	dialog_.confirmed.emit();dialog_.confirmed.emit();await settle()
	check(calls[0] == 1,"confirmation callback executes exactly once")
	game.dialog.close();await settle()
	dialog_ = await open_load_confirmation(path)
	if dialog_ is ConfirmationDialog:dialog_.confirmed.emit();dialog_.confirmed.emit();await settle()
	check(game.campaign().gold == payload.state.gold,"confirmed synthetic load is applied")
	check(FileAccess.get_file_as_bytes(path) == original_file,"load flow never changes original synthetic file")
	print("quest modal regression: %d checks, %d failures" % [checks,failures.size()])
	game.closing = true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
