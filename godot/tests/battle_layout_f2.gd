extends "res://tests/inventory_header_261020.gd"
## Pure UI checks; real OS input and screenshots are recorded separately.
var pointer_mask := 0
func fixtures_f2() -> Dictionary:
	var output=[]
	var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/feedback_261019_fixtures.cjs")]),output,true,false)
	check(code==0,"F2 current sweep fixtures generated")
	return JSON.parse_string("".join(output))
func protected_controls(label: String):
	var view=Rect2(Vector2.ZERO,Vector2(root.size))
	for id in ["BattleHistory","BattleOrderDetails"]:
		var control=node(id)
		check(control!=null and control.is_visible_in_tree() and not control.disabled and view.encloses(control.get_global_rect()),"F2 "+id+" enabled within viewport "+label)
		for panel in [game.hud.left_panel,game.hud.right_panel]:
			check(not panel.visible or not panel.get_global_rect().intersects(control.get_global_rect()),"F2 floating "+str(panel.name)+" cannot cover "+id+" "+label)
	check(node("TurnOrderViewport").get_global_rect().end.x<node("BattleOrderDetails").global_position.x,"F2 order details stays outside clipping viewport "+label)
func pointer(point: Vector2,button:=0,pressed:=false,delta:=Vector2.ZERO):
	var event
	if button==0:event=InputEventMouseMotion.new();event.relative=delta
	else:event=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed
	if button>0:
		if pressed:pointer_mask|=1<<(button-1)
		else:pointer_mask&=~(1<<(button-1))
	event.button_mask=pointer_mask;event.position=point;event.global_position=point
	root.push_input(event,true);await frames(2)
func drag_to_bottom(panel,label: String):
	var header=panel.find_child("DragHandle",true,false);var point=header.get_global_rect().get_center()
	await pointer(point);await pointer(point,MOUSE_BUTTON_LEFT,true)
	check(panel.dragging and panel.moving,"F2 actual viewport header starts drag "+label)
	await pointer(point+Vector2(0,5000),0,false,Vector2(0,5000));await pointer(point+Vector2(0,5000),MOUSE_BUTTON_LEFT,false);await settle()
	protected_controls("after bottom drag "+label)
func run():
	create_timer(180).timeout.connect(func():print("FAIL F2 battle layout watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):push_error("Isolated F2 profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var cases=fixtures_f2()
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;await settle()
		for kind in ["sweep50","sweep100"]:
			for key in ["battle_actor","battle_target"]:
				if game.preferences.config.has_section_key("windows",key):game.preferences.config.erase_section_key("windows",key)
			await game.update({"op":"campaign_load","data":cases[kind]});await settle()
			game.hud.left_panel.restore_rect(Rect2(0,76,320,650))
			game.hud.right_panel.restore_rect(Rect2(maxf(0,game.size.x-380),76,330,620));await settle()
			var before=await saved();var label=kind+" "+str(dims.x)
			protected_controls("default "+label)
			var cards=node("TurnOrder").get_children().filter(func(c):return c is PanelContainer)
			check(cards.size()==5,"F2 retains all five predicted cards "+label)
			var scroll=node("TurnOrderViewport");scroll.scroll_horizontal=100000;await frames()
			check(scroll.get_global_rect().encloses(cards[-1].get_global_rect()),"F2 horizontal scroll exposes fifth predicted card "+label)
			scroll.scroll_horizontal=0
			game.hud.open_skills();await settle();await click("BattleSkillDetails_legSweep");await click("SkillDetailsBack")
			protected_controls("skill explanation closed "+label)
			await game.select_skill("legSweep");await settle()
			# Selection now persists an exact grant key. Reading windows must stay
			# pure after that deliberate selection; no resources may change here.
			var selected_save=await saved();var expected=before.duplicate(true)
			var actor_id=str(selected_save.state.battle.actor)
			var selected_units=selected_save.state.battle.units.filter(func(unit):return str(unit.id)==actor_id)
			check(selected_units.size()==1 and not str(selected_units[0].get("selectedSkillKey","")).is_empty(),"F2 selection identifies exact grant "+label)
			if selected_units.size()==1:
				for unit in expected.state.battle.units:
					if str(unit.id)==actor_id:unit.selectedSkillKey=selected_units[0].get("selectedSkillKey","")
			check(selected_save==expected,"F2 selection changes only grant identity, never resources "+label)
			before=selected_save
			for id in ["battle_commit","battle_cancel"]:
				var controls=game.find_children("*","Button",true,false).filter(func(button):return button.get_meta("ui_key","")==id)
				check(controls.size()==1 and controls[0].is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(controls[0].get_global_rect()),"F2 existing action "+id+" still visible "+label)
			var pending=game.pending;var preview=game.preview.duplicate(true)
			await click("BattleHistory")
			check(game.dialog.window.title=="戦闘履歴","F2 history opens from selected sweep "+label)
			game.dialog.close();await settle();await click("BattleOrderDetails")
			check(game.dialog.window.title=="順番詳細" and game.dialog.window.find_children("OrderDetail_*","Label",true,false).size()==game.hud.queue_entries().size(),"F2 order details retains complete queue "+label)
			game.dialog.close();await settle()
			check(game.pending==pending and game.preview==preview and (await saved())==before,"F2 reading controls preserve pending action prediction and save "+label)
			await drag_to_bottom(game.hud.left_panel,"left "+label);await drag_to_bottom(game.hud.right_panel,"right "+label)
			for panel in [game.hud.left_panel,game.hud.right_panel]:
				panel.position=Vector2(-500,-500);panel.constrain();await settle()
				check(panel.global_position==Vector2.ZERO,"F2 panel can still reach viewport top "+label+str(panel.name))
				panel.position=Vector2(5000,5000);panel.size=Vector2(900,1500);panel.constrain();await settle()
				protected_controls("oversized stored rect "+label+str(panel.name))
			check((await saved())==before,"F2 panel movement resizing and scroll never change campaign "+label)
	check(game.audio.muted.values().all(func(value):return value),"F2 BGM voice and SE remain OFF")
	var f=FileAccess.open(evidence.path_join("battle-layout-f2-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
