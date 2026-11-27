extends SceneTree
## Synthetic saves and real input dispatch. No OS dialog or real-player files.
const Grid = preload("res://screen_grid.gd")
const WindowGrid = preload("res://window_grid.gd")
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
		root.push_input(event,true);await process_frame
	await settle()
func click(control: Control, button := MOUSE_BUTTON_LEFT):
	var point = control.get_global_rect().get_center()
	if control.get_window() != root:point += Vector2(control.get_window().position)
	var motion = InputEventMouseMotion.new();motion.position = point;motion.global_position = point;root.push_input(motion,true)
	for down in [true,false]:
		var event = InputEventMouseButton.new();event.button_index = button;event.position = point;event.global_position = point;event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and button == MOUSE_BUTTON_LEFT else 0
		root.push_input(event,true);await process_frame
	await settle()
func shot(label: String):
	if DisplayServer.get_name()=="headless" or OS.get_environment("UIUX_REVIEW_EVIDENCE").is_empty():return
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	check(image.get_size() == Vector2i(1920,1080),label + " rendered at FHD")
	image.save_png(OS.get_environment("UIUX_REVIEW_EVIDENCE").path_join(label+".png"))
func window_rect(window: Window) -> Rect2:
	return Rect2(Vector2(window.position)-game.preferences.window_origin(window),Vector2(window.size))
func grid_check(rect: Rect2, label: String):
	check(rect == Grid.snap_rect(rect,Vector2(root.size)),label + " uses four grid edges: " + str(rect))
func cargo_picker(id: String, seed: Dictionary):
	var fixture = seed.duplicate(true);fixture.state.location = "east"
	await game.update({"op":"campaign_load","data":fixture});await settle()
	game.navigate("board");await settle();await click(node("QuestChoice_"+id))
	var before = await saved()
	await click(node("QuestStory_"+id))
	var scene = node("QuestDialogue")
	check(scene != null and scene.portrait.texture != null and node("QuestDialoguePanel").get_global_rect().has_area(),"current request dialogue shows a portrait and panel")
	if scene == null:return
	for i in range(20):
		if scene.choice_row.visible:break
		await key(KEY_A)
	grid_check(scene.choice_row.get_global_rect(),"request dialogue choices")
	check(node("QuestSpeaker").visible and node("QuestSpeaker").text=="車輪職人" and not node("QuestDialogueText").text.is_empty(),"choices retain the last speaker and line")
	await shot("quest-dialogue-choices")
	await click(node("QuestStoryDecline"))
	check(node("QuestDialogue")==null and await saved()==before,"declining the conversation keeps the mission unaccepted")
	await click(node("QuestStory_"+id))
	scene = node("QuestDialogue")
	for i in range(20):
		if scene.choice_row.visible:break
		await key(KEY_A)
	await click(node("QuestStoryAccept"))
	var choices = node("QuestCargoChoices")
	check(is_instance_valid(choices) and node("QuestDialogue") == null,"accept choice opens the cargo picker")
	if not is_instance_valid(choices):return
	var picker: Window = choices.get_window()
	var rect = window_rect(picker)
	grid_check(rect,"cargo picker")
	check(picker.borderless and rect==WindowGrid.modal_frame_rect(Vector2(root.size)) and Grid.cell_rect(Vector2(root.size),0,1,10,8).encloses(rect),"borderless cargo picker leaves the first and last game rows clear")
	for region in [node("ModalDetailScroll"),choices,node("ModalActions")]:
		grid_check(Rect2(region.get_global_rect().position+rect.position,region.size),str(region.name))
	var confirm_ = node("QuestCargoConfirm")
	var porter = game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id == uid and c.job == "job_porter"))[0]
	var owner = node("QuestCargoOwner_"+porter)
	check(confirm_.disabled and owner is Button and owner.icon != null and not owner.text.is_empty(),"cargo displays portrait and name and requires a selection")
	await shot("cargo-picker")
	var scroll = node("ModalDetailScroll")
	var cell = Grid.cell_rect(Vector2(root.size),0,0,1,1).size
	var moved = Rect2(rect.position+Vector2(cell.x,0),rect.size)
	picker.position += Vector2i(int(cell.x),-int(cell.y));await settle()
	check(window_rect(picker)==moved and scroll.get_global_rect().end.y==node("ModalActions").get_global_rect().position.y and node("QuestCargoCancel").is_visible_in_tree(),"cargo picker stays below the reserved top row and keeps cancel below the scroll viewport")
	await click(node("QuestCargoCancel"))
	check(not is_instance_valid(picker) and await saved() == before,"pointer cancel keeps the mission unaccepted")
	await click(node("QuestAccept"))
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game.dialog.window) and await saved() == before,"Escape from the picker leaves the board and save unchanged")
	await click(node("QuestAccept"))
	picker = node("QuestCargoChoices").get_window()
	check(window_rect(picker)==rect,"cargo picker opens again in the shared frame")
	await click(node("QuestCargoOwner_"+porter))
	check(node("QuestCargoOwner_"+porter).button_pressed and not node("QuestCargoConfirm").disabled,"pointer selection marks the porter and enables confirmation")
	await click(node("QuestCargoConfirm"))
	var after = await saved()
	check(not is_instance_valid(picker) and after.state.activeQuest is Dictionary and after.state.activeQuest.cargoOwnerId == porter,"confirmation records the chosen cargo owner")
	await game.update({"op":"campaign_load","data":after});await settle()
	check(game.campaign().activeQuest.cargoOwnerId==porter,"chosen cargo owner survives reload")
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
	var message = d.find_child("ConfirmationText",true,false)
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
	var rect = window_rect(d)
	check(Grid.cell_rect(Vector2(root.size),0,1,10,8).encloses(rect),context + " fits between the first and last FHD rows: " + str(rect))
	grid_check(rect,context)
func visible_confirmation():
	for dialog_ in game.find_children("*","ConfirmationDialog",true,false):
		if dialog_.visible:return dialog_
	return null
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
		var porter = game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id == uid and c.job == "job_porter"))[0]
		await game.act("accept",[id,porter]);await settle()
		var ready = await saved();ready.state.location = sample[2];ready.state.worldTime = 10;ready.state.hours = 10
		await game.update({"op":"campaign_load","data":ready});await settle();await game.act("completeQuest",[]);await settle()
		var completed = await saved()
		check(game.results_view.active,id + " successful receipt is visible")
		node("ResultStory").pressed.emit();await process_frame;await key(KEY_ESCAPE)
		check(node("QuestDialogue") == null and game.results_view.active,id + " Escape closes result story but preserves receipt")
		check(await saved() == completed,id + " result story Escape never acknowledges or changes rewards")
		await cleanup_scene();game.results_view.reset();await settle()
	await cargo_picker("standalone-wheel",seed)
	await game.update({"op":"campaign_load","data":seed});await settle();game.navigate("board");await settle()
	game.dialog.open("確認の親ウィンドウ",func(body,_actions):game.label_(body,"人工状態の確認"));await settle()
	var calls = [0];var dialog_ = game.confirm("長い確認文です。".repeat(640),func():calls[0] += 1);await settle()
	verify_confirmation(dialog_,"nested long confirmation")
	await shot("nested-long-confirmation")
	var scroll = dialog_.find_child("ConfirmationTextScroll",true,false);scroll.scroll_vertical = 100000;await settle()
	var message = dialog_.find_child("ConfirmationText",true,false)
	check(scroll.scroll_vertical > 0 and message.get_global_rect().end.y <= scroll.get_global_rect().end.y + 2,"long confirmation remains scrollable to its end")
	dialog_.confirmed.emit();dialog_.confirmed.emit();await settle()
	check(calls[0] == 1,"confirmation callback executes exactly once")
	game.dialog.close();await settle()
	print("quest modal regression: %d checks, %d failures" % [checks,failures.size()])
	game.closing = true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
