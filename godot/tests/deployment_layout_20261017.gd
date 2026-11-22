extends "res://tests/ui_feedback_20261016.gd"
func positions():return game.state().units.map(func(u):return [u.id,u.pos])
func layout_check(label):
	var panels=[game.deployment_party_strip,game.hud.right_panel,game.hud.deployment_bar,game.hud.deployment_actions]
	var valid=true
	for i in range(panels.size()):
		valid=valid and root.get_visible_rect().encloses(panels[i].get_global_rect())
	check(valid,label)
func run():
	create_timer(85).timeout.connect(func():print("FAIL deployment watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var baseline=await saved()
	var prefs=game.preferences
	prefs.store_camera({"pan":Vector2(1.5,-2),"yaw":.35,"pitch":.6,"zoom":14.0})
	prefs.store_rect("battle_actor_b",Rect2(50,90,350,600));prefs.store_rect("battle_target_b",Rect2(1450,90,360,600))
	prefs.store_rect("deployment_ally",Rect2(800,800,900,900));prefs.store_rect("deployment_enemy",Rect2(0,0,1200,900))
	var battle_left=prefs.config.get_value("windows","battle_actor_b");var battle_right=prefs.config.get_value("windows","battle_target_b")
	game.navigate("map");await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await settle()
	var deployment=await saved();var initial=positions();var camera=prefs.camera().duplicate(true)
	check(game.deployment_party_strip.is_visible_in_tree() and node("PartyFace_"+str(game.selected))!=null,"deployment shows the current ally in the shared roster")
	check(not game.hud.right_panel.body.find_children("DeploymentEnemy_*","Button",true,false).is_empty(),"right initially lists the opposing party")
	layout_check("FHD deployment windows remain reachable with oversized misplaced saved layouts")
	check(node("DeploymentFormation_convoy").size.x>=140 and node("DeploymentFormation_flank").size.x>=140,"formation choices retain readable widths")
	var allies=game.state().units.filter(func(u):return u.side=="ally")
	await game.on_cell(int(allies[1].pos));await settle()
	check(game.selected==allies[1].id and positions()==initial and node("PartyFace_"+str(allies[1].id)).get_meta("selected",false),"ally click selects without moving or swapping")
	var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0]
	await game.on_cell(int(enemy.pos));await settle()
	check(game.modal_open() and game.hud.selected_enemy==enemy.id and game.selected==allies[1].id and positions()==initial,"enemy click inspects right without deploying ally")
	game.hud.inspect_hover(allies[0].id);await frames()
	check(game.modal_open() and game.hud.selected_enemy==enemy.id,"hover does not replace clicked enemy with ally")
	game.dialog.close();await settle()
	var empty=-1
	for pos in range(50):
		if pos%10<5 and not game.state().units.any(func(u):return int(u.pos)==pos):empty=pos;break
	await game.on_cell(empty);await settle()
	check(game.hud.unit(game.selected).pos==empty and game.hud.deployment_changed(),"empty cell moves selected ally")
	var moved=positions()
	await click("DeploymentFormation_flank")
	check(game.find_children("*","ConfirmationDialog",true,false).is_empty() and positions()==moved and game.state().formationKind=="flank","formation changes without consent or moving units")
	await click("DeploymentReset");var confirmation=game.find_children("*","ConfirmationDialog",true,false)[0];confirmation.canceled.emit();await settle()
	check(positions()==moved,"reset cancellation preserves manual positions")
	await click("DeploymentReset");confirmation=game.find_children("*","ConfirmationDialog",true,false)[0];confirmation.confirmed.emit();confirmation.confirmed.emit();await settle()
	check(not game.hud.deployment_changed(),"reset restores selected preset; repeated confirmation safe")
	check(game.state().formationKind=="flank" and game.data.formationSlots.ally.map(func(x):return int(x))==[24,13,33],"formation button applies flank rules")
	var first=game.state().units.filter(func(u):return u.side=="ally")[0];var second=game.state().units.filter(func(u):return u.side=="ally")[1]
	var oldpos=first.pos;var otherpos=second.pos
	await game.deploy_dragged(first.id,int(otherpos));await settle()
	check(game.hud.unit(first.id).pos==otherpos and game.hud.unit(second.id).pos==oldpos and game.selected==first.id,"drag preserves swap and selects dragged ally")
	await click("DeploymentReset");confirmation=game.find_children("*","ConfirmationDialog",true,false)[0];confirmation.confirmed.emit();await settle()
	check(not game.hud.deployment_changed() and game.state().formationKind=="flank","reset uses current formation")
	var before_begin=await saved()
	check(before_begin.state.gold==deployment.state.gold and game.state().actions==0,"deployment consumes no gold or battle actions")
	for u in game.state().units:
		u.name="長い人物名".repeat(15)
	game.render();await settle();layout_check("long names remain inside viewport despite user-allowed overlap")
	var left_deploy=game.deployment_party_strip.get_global_rect()
	check(prefs.config.get_value("windows","battle_actor_b")==battle_left and prefs.config.get_value("windows","battle_target_b")==battle_right,"deployment persistence leaves battle layouts intact")
	await game.update({"op":"campaign_load","data":before_begin});await settle()
	var start=node("DeploymentBegin");start.pressed.emit();start.pressed.emit();await settle()
	check(game.campaign().phase=="battle" and not game.state().get("deploying",false),"battle begins once under repeated button signal")
	check(not game.hud.deployment_bar.visible and not game.hud.deployment_actions.visible and game.battle_header.visible,"battle hides placement controls and restores turn order")
	for pair in [[game.hud.left_panel,battle_left],[game.hud.right_panel,battle_right]]:
		var restored=pair[0].get_global_rect()
		var requested=Rect2(pair[1].position+game.hud.middle.global_position,pair[1].size)
		requested.size.x=root.size.x*0.2
		var bounds=Rect2(Vector2.ZERO,Vector2(root.size.x,game.battle_header.global_position.y))
		check(restored==preload("res://screen_grid.gd").snap_rect(requested,Vector2(root.size),pair[0].minimum,bounds),"saved battle panel restored on game grid "+str(pair[0].name))
	check(game.hud.left_panel.size.x==game.hud.right_panel.size.x,"battle operation and target share width")
	await game.update({"op":"campaign_load","data":deployment});await settle()
	check(game.hud.deployment_bar.visible and game.hud.deployment_actions.visible and not game.battle_header.visible,"reentry restores deployment-only controls")
	check(game.deployment_party_strip.get_global_rect()==left_deploy,"reentry restores deployment window geometry")
	layout_check("reentry regions remain disjoint")
	await game.update({"op":"campaign_load","data":baseline});await settle()
	await game.update({"op":"campaign_load","data":deployment});await settle()
	check(game.hud.left_panel.layout_key=="deployment_ally" and game.hud.right_panel.layout_key=="deployment_enemy","town exit and remount use deployment persistence keys")
	layout_check("remounted deployment regions remain disjoint")
	check(prefs.camera()==camera and game.board.camera_pan==camera.pan and game.board.camera_yaw==camera.yaw and game.board.camera_pitch==camera.pitch and game.board.world.zoom==camera.zoom,"saved nondefault camera persists across battle and town reentry")
	var record={"checks":checks,"formation_button":str(node("DeploymentFormation_convoy").get_global_rect()),"left":str(game.hud.left_panel.get_global_rect()),"right":str(game.hud.right_panel.get_global_rect()),"formation_window":str(game.hud.deployment_bar.get_global_rect()),"actions":str(game.hud.deployment_actions.get_global_rect()),"gui_review":"pending"}
	var f=FileAccess.open(evidence.path_join("deployment-layout.json"),FileAccess.WRITE);f.store_string(JSON.stringify(record,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	quit(0 if checks.all(func(c):return c.passed) else 1)
