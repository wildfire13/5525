extends "res://tests/ui_feedback_20261016.gd"
const Grid=preload("res://screen_grid.gd")

func exact(control: Control,x: int,y: int,w: int,h: int):
	var offset=Vector2(control.get_window().position)-game.preferences.window_origin(control.get_window())
	var actual=Rect2(control.global_position+offset,control.size)
	check(actual==Grid.cell_rect(Vector2(root.size),x,y,w,h),str(control.name)+" "+str(actual))

func battle_loadout(side: String):
	var member=game.roster()[0].duplicate(true)
	member.side=side;member.inventory={"potion":1}
	game.dialog.open("装備と所持品",func(body,_actions):game.hud.draw_loadout(body,member,"equipment"))
	await settle()
	exact(node("LoadoutTabBar"),2,2,2,1);exact(node("RegionEquipment"),2,3,2,5)
	exact(node("MemberLoadoutPanel"),2,3,2,5)
	exact(node("ModalActions"),2,8,6,1)
	check(node("BattleSlot_rightHand")!=null,side+" equipment hit target exists")
	await mouse_press(node("BattleLoadoutTab_inventory"))
	exact(node("LoadoutTabBar"),2,2,2,1);exact(node("RegionInventory"),2,3,2,5)
	var entries=node("BattleInventory")
	for i in 40:game.label_(entries,"所持品 %d" % i)
	await settle()
	var scroll=entries.get_parent()
	exact(scroll,2,3,2,5);exact(node("MemberLoadoutPanel"),2,3,2,5)
	var existing_items=entries.find_children("*","Button",true,false)
	if not existing_items.is_empty():
		await mouse_press(existing_items[0])
		exact(node("BattleItemDetail"),4,2,4,6)
		var description=node("SkillDetailsWindow")
		if is_instance_valid(description):description.finish()
		await settle()
	await mouse_press(scroll,MOUSE_BUTTON_WHEEL_DOWN)
	check(scroll.scroll_vertical>0,side+" long inventory scrolls within the stage")
	await mouse_press(node("BattleLoadoutTab_equipment"));exact(node("RegionEquipment"),2,3,2,5)
	game.dialog.close();await settle()

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
func drag_title(window: Window,delta: Vector2i):
	var start=Vector2(window.position)+window.find_child("ModalHeading",true,false).get_global_rect().get_center()
	var press=InputEventMouseButton.new()
	press.position=start;press.global_position=start
	press.button_index=MOUSE_BUTTON_LEFT;press.button_mask=MOUSE_BUTTON_MASK_LEFT;press.pressed=true
	root.push_input(press,true)
	var motion=InputEventMouseMotion.new()
	motion.position=start+Vector2(delta);motion.global_position=motion.position
	motion.relative=Vector2(delta);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	var release=InputEventMouseButton.new()
	release.position=motion.position;release.global_position=motion.position;release.button_index=MOUSE_BUTTON_LEFT
	root.push_input(release,true)
	await settle()
func mouse_press(control: Control,button:=MOUSE_BUTTON_LEFT):
	var point=control.get_global_rect().get_center()
	# Embedded windows are routed by the root viewport, like OS input.
	if control.get_window()!=root:point+=Vector2(control.get_window().position)
	await click_at(point,button)
func click_at(point: Vector2,button:=MOUSE_BUTTON_LEFT):
	var motion=InputEventMouseMotion.new()
	motion.position=point;motion.global_position=point;root.push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and button==MOUSE_BUTTON_LEFT else 0
		root.push_input(event,true)
		await process_frame
	await settle()
func facility_menu_input(facility: String):
	game.navigate(facility);await settle()
	var header=node("CampaignHeader")
	var trigger=header.find_children("*","Button",true,false).filter(func(b):return b.text=="メニュー")[0]
	await mouse_press(trigger)
	var exit_rect=node("FacilityExit").get_global_rect()
	var overlap=exit_rect.intersection(game.menu.get_global_rect())
	check(game.menu.visible and overlap.has_area(),facility+" exit overlaps the open menu")
	var motion=InputEventMouseMotion.new()
	motion.position=overlap.get_center();motion.global_position=motion.position;root.push_input(motion,true)
	await process_frame
	var hovered=root.gui_get_hovered_control()
	check(hovered!=null and (hovered==game.menu or game.menu.is_ancestor_of(hovered)),facility+" menu receives pointer above exit; hit "+str(hovered))
	var label_switch=node("UiLabelSwitch")
	var was_on=label_switch.button_pressed
	await mouse_press(label_switch)
	check(game.menu.visible and label_switch.button_pressed!=was_on and game.page==facility,facility+" menu item accepts click")
	if label_switch.button_pressed!=was_on:await mouse_press(label_switch)
	await click_at(Vector2(exit_rect.position.x+8,exit_rect.get_center().y))
	check(not game.menu.visible and game.page==facility,facility+" stays open after outside click")
	if game.menu.visible:game.menu.hide()
	if game.page==facility:await mouse_press(node("FacilityExit"))
	check(game.page=="hub",facility+" exit works after menu is closed")
func run():
	create_timer(100).timeout.connect(func():quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	check(root.size==Vector2i(1920,1080),"FHD game viewport")
	await facility_menu_input("inn")
	await facility_menu_input("party")
	var home=await saved()
	var east=home.duplicate(true);east.state.location="east"
	await game.update({"op":"campaign_load","data":east})
	await facility_menu_input("shop")
	await game.update({"op":"campaign_load","data":home})
	game.navigate("hub");await settle()
	game.open_menu();await settle()
	region(game.menu);region(node("AudioSettings"))
	var volume=node("AudioVolumeValue_bgm")
	check(volume.get_theme_color("font_color")==game.mock_shell.INK,"menu volume uses the shared dark text")
	check(game.menu.get_theme_stylebox("panel").bg_color.a==1.0,"map text cannot show through the menu")
	await shot("menu")
	game.menu.hide();game.save_notice.display("グリッド通知");await settle();region(game.save_notice)
	game.dialog.open("グリッド詳細",func(body,actions):
		game.label_(body,"内容と入力を保持する詳細")
		game.local_button(actions,"閉じる",game.dialog.close).name="GridClose")
	await settle()
	var window=game.dialog.window
	aligned(Rect2(Vector2(window.position),Vector2(window.size)),"detail")
	exact(node("ModalHeading"),2,1,6,1);exact(node("ModalDetailScroll"),2,2,6,6);exact(node("ModalActions"),2,8,6,1);await shot("detail")
	var initial=Rect2(Vector2(window.position),Vector2(window.size))
	check(window.borderless and initial==Grid.cell_rect(Vector2(root.size),2,1,6,8),"borderless detail leaves both reserved rows clear without shrinking its heading")
	var close=node("WindowHeadingClose")
	check(node("ModalHeading").get_global_rect().encloses(close.get_global_rect()),"close control is inside the shared heading")
	var heading_rect=node("ModalHeading").get_global_rect()
	var body_rect=node("ModalDetailScroll").get_global_rect()
	var actions_rect=node("ModalActions").get_global_rect()
	var delta=Vector2i(Grid.cell_rect(Vector2(root.size),1,1,1,1).size.x,-108)
	await drag_title(window,delta)
	check(Rect2(Vector2(window.position),Vector2(window.size))==Rect2(initial.position+Vector2(delta.x,0),initial.size),"title drag keeps horizontal movement but cannot enter the reserved top row")
	check(node("ModalHeading").get_global_rect()==heading_rect and node("ModalDetailScroll").get_global_rect()==body_rect and node("ModalActions").get_global_rect()==actions_rect,"drag leaves child rectangles unchanged within the window")
	await mouse_press(node("GridClose"))
	check(not is_instance_valid(game.dialog.window),"mouse closes detail")
	if is_instance_valid(window):quit(1);return
	game.preferences.config.set_value("windows","dialog:グリッド詳細",Rect2(0,0,600,400))
	game.dialog.open("グリッド詳細",func(_body,_actions):pass);await settle()
	check(Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size))==initial,"reopen resets the dragged position and ignores obsolete stored geometry")
	await mouse_press(node("WindowHeadingClose"))
	check(not is_instance_valid(game.dialog.window),"heading close emits the existing close request")
	game.dialog.open("グリッド詳細",func(_body,_actions):pass);await settle()
	var calls=[0]
	var confirm=game.confirm("確認本文",func():calls[0]+=1);await settle()
	exact(confirm.find_child("ModalHeading",true,false),3,2,4,1)
	exact(node("ConfirmationTextScroll"),3,3,4,4);exact(confirm.get_ok_button().get_parent(),3,7,4,1);await shot("confirmation")
	await mouse_press(confirm.find_child("WindowHeadingClose",true,false))
	check(calls[0]==0 and not is_instance_valid(confirm),"confirmation heading close cancels without executing")
	confirm=game.confirm("確認本文",func():calls[0]+=1);await settle()
	for pressed in [true,false]:
		var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=pressed;root.push_input(escape,true)
		await process_frame
	await settle();check(calls[0]==0 and not is_instance_valid(confirm) and is_instance_valid(game.dialog.window),"Escape cancels only the nested confirmation without executing")
	if is_instance_valid(confirm):quit(1);return
	confirm=game.confirm("確認本文",func():calls[0]+=1);await settle();await mouse_press(confirm.get_ok_button())
	check(calls[0]==1 and not is_instance_valid(confirm),"mouse confirms once and closes")
	if is_instance_valid(confirm):quit(1);return
	game.dialog.close();await settle()
	var body_clicks=[0,0]
	var receipt=game.confirm("確認本文\n".repeat(100),func():pass,func(contents,d):
		d.title="取引明細"
		for index in 2:
			game.local_button(contents,"項目 %d" % index,func():body_clicks[index]+=1).name="ReceiptOption%d" % index)
	await settle()
	var heading=receipt.find_child("ModalHeading",true,false)
	exact(heading,3,2,4,1);check(heading.text=="取引明細","custom confirmation keeps its title")
	exact(node("ConfirmationTextScroll"),3,3,4,4);exact(receipt.get_ok_button().get_parent(),3,7,4,1)
	exact(node("ConfirmationMessage"),3,3,4,4)
	node("ConfirmationTextScroll").scroll_vertical=100000;await settle()
	for index in 2:await mouse_press(node("ReceiptOption%d" % index))
	check(body_clicks==[1,1],"both confirmation body options receive pointer input after scrolling")
	exact(node("ConfirmationMessage"),3,3,4,4)
	receipt.canceled.emit();await settle()
	var detail=preload("res://skill_details.gd").new();game.add_child(detail)
	detail.configure(game,preload("res://skill_text.gd").document("skill_leg_sweep","足払い",3,game.campaign()),"テスト")
	await settle()
	exact(node("SkillDetailsTitle"),2,1,6,1)
	exact(node("SkillDetailsTabs").get_parent(),2,2,6,6);exact(node("SkillDetailsActions"),2,8,6,1)
	exact(node("SkillDetailsTabs"),2,3,6,5)
	await shot("skill")
	await mouse_press(node("SkillDetailsBack"))
	for side in ["ally","enemy"]:await battle_loadout(side)
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
	scroll=node("ModalDetailScroll")
	exact(scroll,2,2,6,6)
	await mouse_press(node("QuestCargoCancel"))
	check(not is_instance_valid(picker) and game.campaign().get("activeQuest")==null,"porter picker cancel leaves the quest unaccepted")
	game.portrait_dialog();await settle()
	exact(node("ModalHeading"),2,1,6,1);exact(node("PortraitChoices"),2,2,6,6);exact(node("ModalActions"),2,8,6,1)
	node("PortraitChooser").close_requested.emit();await settle()
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
	game.show_engine_stop();await settle()
	var stop=node("EngineStopDialog")
	exact(node("ModalHeading"),3,2,4,1);exact(node("ConfirmationTextScroll"),3,3,4,4)
	exact(stop.get_ok_button().get_parent(),3,7,4,1)
	check(not stop.get_cancel_button().visible and stop.get_ok_button().visible,"engine stop only offers quit")
	stop.hide();stop.queue_free();await settle()
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	quit(0 if checks.all(func(c):return c.passed) else 1)
