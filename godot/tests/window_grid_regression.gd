extends "res://tests/ui_feedback_20261016.gd"
func aligned(rect: Rect2,label: String):
	var unit=Vector2(root.size)/10
	for point in [rect.position,rect.end]:
		check((point/unit).is_equal_approx((point/unit).round()),label+" "+str(point))
func region(control: Control):
	var offset=Vector2.ZERO
	if control.get_window()!=root:
		offset=Vector2(control.get_window().position)-game.preferences.window_origin(control.get_window())
	aligned(Rect2(control.global_position+offset,control.size),str(control.name))
func shot(label: String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))
func mouse_press(control: Control,button:=MOUSE_BUTTON_LEFT):
	var point=control.get_global_rect().get_center()
	# Embedded windows are routed by the root viewport, like OS input.
	if control.get_window()!=root:point+=Vector2(control.get_window().position)
	var motion=InputEventMouseMotion.new()
	motion.position=point;motion.global_position=point;root.push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and button==MOUSE_BUTTON_LEFT else 0
		root.push_input(event,true)
		await process_frame
	await settle()
func run():
	create_timer(100).timeout.connect(func():quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	check(root.size==Vector2i(1920,1080),"FHD game viewport")
	game.open_menu();await settle()
	region(game.menu);region(node("AudioSettings"));await shot("menu")
	game.menu.hide();game.save_notice.display("グリッド通知");await settle();region(game.save_notice)
	game.dialog.open("グリッド詳細",func(body,actions):
		game.label_(body,"内容と入力を保持する詳細")
		game.local_button(actions,"閉じる",game.dialog.close).name="GridClose")
	await settle()
	var window=game.dialog.window
	aligned(Rect2(Vector2(window.position),Vector2(window.size)),"detail")
	region(node("ModalDetailScroll"));region(node("ModalActions"));await shot("detail")
	var initial=Rect2(Vector2(window.position),Vector2(window.size))
	window.position+=Vector2i(215,-95);window.size+=Vector2i(-170,90);await settle()
	aligned(Rect2(Vector2(window.position),Vector2(window.size)),"moved/resized")
	var expected=Rect2(Vector2(window.position),Vector2(window.size))
	check(expected.position!=initial.position and expected.size!=initial.size,"move and resize land on different grid cells")
	await mouse_press(node("GridClose"))
	check(not is_instance_valid(game.dialog.window),"mouse closes detail")
	if is_instance_valid(window):quit(1);return
	var persisted=preload("res://ui_preferences.gd").new()
	var saved_rect=persisted.config.get_value("windows","dialog:グリッド詳細",Rect2())
	check(saved_rect.has_area() and persisted.window_rect(saved_rect,Vector2(root.size),Vector2(420,300))==expected,"moved detail rectangle is restored from disk on the grid")
	game.dialog.open("グリッド詳細",func(_body,_actions):pass);await settle()
	check(Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size))==expected,"reopen retains snapped geometry")
	var calls=[0]
	var confirm=game.confirm("確認本文",func():calls[0]+=1);await settle()
	region(node("ConfirmationTextScroll"));region(node("ConfirmationMessage"));region(confirm.get_ok_button().get_parent());await shot("confirmation")
	for pressed in [true,false]:
		var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=pressed;root.push_input(escape,true)
		await process_frame
	await settle();check(calls[0]==0 and not is_instance_valid(confirm) and is_instance_valid(game.dialog.window),"Escape cancels only the nested confirmation without executing")
	if is_instance_valid(confirm):quit(1);return
	confirm=game.confirm("確認本文",func():calls[0]+=1);await settle();await mouse_press(confirm.get_ok_button())
	check(calls[0]==1 and not is_instance_valid(confirm),"mouse confirms once and closes")
	if is_instance_valid(confirm):quit(1);return
	game.dialog.close();await settle()
	var detail=preload("res://skill_details.gd").new();game.add_child(detail)
	detail.configure(game,preload("res://skill_text.gd").document("skill_leg_sweep","足払い",3,game.campaign()),"テスト")
	await settle()
	for id in ["SkillDetailsSummary","SkillDetailsTabs","SkillDetailsActions"]:region(node(id))
	await shot("skill")
	await mouse_press(node("SkillDetailsBack"))
	var history=game.campaign().get("history",[])
	game.campaign()["history"]=range(80).map(func(i):return "行動ログ %d" % i)
	game.show_action_log();await settle()
	var scroll: ScrollContainer=node("ModalDetailScroll")
	region(node("ActionLogHistory"))
	await mouse_press(scroll,MOUSE_BUTTON_WHEEL_DOWN)
	check(scroll.scroll_vertical>0,"mouse wheel scrolls long action log")
	check(Rect2(Vector2.ZERO,Vector2(scroll.get_window().size)).encloses(node("ModalActions").get_global_rect()),"action log footer stays reachable after scrolling")
	await shot("action-log");game.dialog.close();await settle()
	game.campaign()["history"]=history
	game.navigate("board");await settle()
	await mouse_press(node("QuestAccept"))
	var choices=node("QuestCargoChoices")
	check(is_instance_valid(choices),"quest board opens the registered porter choices")
	if not is_instance_valid(choices):quit(1);return
	var picker=choices.get_window()
	picker.size.y=324;await settle()
	scroll=node("ModalDetailScroll")
	await mouse_press(scroll,MOUSE_BUTTON_WHEEL_DOWN)
	check(scroll.scroll_vertical>0,"mouse wheel scrolls porter choices in a short window")
	await mouse_press(node("QuestCargoCancel"))
	check(not is_instance_valid(picker) and game.campaign().get("activeQuest")==null,"porter picker cancel leaves the quest unaccepted")
	game.portrait_dialog();await settle();region(node("PortraitChoices"));node("PortraitChooser").close_requested.emit();await settle()
	game.navigate("character");await settle()
	var member=game.roster().filter(func(u):return u.id=="character_rio")[0]
	game.pages.party_uid=member.id
	await game.import_portrait(ProjectSettings.globalize_path("res://../native/assets/characters/scout-human-female-01.png"),member.id)
	await settle()
	game.pages.party_view.workspace.open_portrait(member);await settle()
	var framing=node("PortraitFraming")
	check(is_instance_valid(framing),"imported portrait opens the registered framing editor")
	if not is_instance_valid(framing):quit(1);return
	region(framing)
	await mouse_press(framing,MOUSE_BUTTON_WHEEL_UP)
	var zoom: float=framing.framing.zoom
	check(zoom>1.0,"mouse wheel zooms portrait preview")
	await mouse_press(node("PortraitFramingApply"))
	check(not is_instance_valid(framing) and game.portraits.metadata.characters[member.id].framing.zoom==zoom,"applying portrait framing retains the adjusted zoom")
	if DisplayServer.get_name()!="headless":
		game.debug_view.open();await settle()
		var dev=game.debug_view.window
		aligned(Rect2(Vector2(dev.position)-game.preferences.window_origin(dev),Vector2(dev.size)),"native developer")
		for id in ["DebugState","DebugPersistence","DebugHistory","DebugActions"]:region(node(id))
		await RenderingServer.frame_post_draw
		dev.get_texture().get_image().save_png(evidence.path_join("developer.png"))
		dev.hide()
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	quit(0 if checks.all(func(c):return c.passed) else 1)
