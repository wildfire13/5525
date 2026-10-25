extends "res://tests/ui_feedback_20261016.gd"
## Fresh-profile normal journey, no fabricated campaign or layout fixtures.
var measurements=[]
func normal_deployment():
	check(game.campaign().phase=="town" and game.campaign().location=="astaris","fresh profile opens Astaris town")
	await click("HubMap");await click("Town_east");await click("DepartButton")
	var river=game.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("川沿いの道"))[0]
	river.pressed.emit();await settle()
	check(game.campaign().phase=="deployment" and game.state().get("deploying",false),"normal map east river route reaches deployment without fixture")
func geometry(label: String):
	var rows=[];var protected_=[game.hud.deployment_bar,game.hud.deployment_actions] if game.state().get("deploying",false) else [node("BattleHistory"),node("BattleOrderDetails")]
	for control in protected_:
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(control.get_global_rect()),label+" protected control in viewport "+str(control.name))
		for panel in [game.hud.left_panel,game.hud.right_panel]:
			var overlap=panel.get_global_rect().intersection(control.get_global_rect()) if panel.visible else Rect2()
			check(not overlap.has_area(),label+" panel cannot cover "+str(control.name)+" "+str(panel.name))
			rows.append({"control":str(control.name),"rect":str(control.get_global_rect()),"panel":str(panel.name),"panel_rect":str(panel.get_global_rect()),"overlap_area":overlap.get_area()})
	if game.state().get("deploying",false):
		var start=node("DeploymentBegin");var menu=node("CommonMenuButton")
		var overlap=start.get_global_rect().intersection(menu.get_global_rect()) if menu.visible else Rect2()
		check(not overlap.has_area(),label+" start button stays fully clear of common menu")
		rows.append({"control":"DeploymentBegin","rect":str(start.get_global_rect()),"panel":"CommonMenuButton","panel_rect":str(menu.get_global_rect()),"overlap_area":overlap.get_area()})
		var fixed=[game.hud.deployment_bar,game.hud.deployment_actions,menu]
		var cells=[]
		for cell in range(50):
			if cell%10>=5:continue
			var point=game.board.global_position+game.board.project_cell(cell)
			var covered=[]
			for control in fixed:
				if control.visible and control.get_global_rect().has_point(point):covered.append(str(control.name))
			var inside=Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point)
			check(inside and covered.is_empty(),label+" legal ally cell "+str(cell)+" center in viewport and clear of fixed footer")
			cells.append({"cell":cell,"x":point.x,"y":point.y,"inside_viewport":inside,"fixed_covered_by":covered})
		rows.append({"control":"all_25_ally_cell_centers","cells":cells})
	measurements.append({"label":label,"size":str(root.size),"rows":rows})
func run():
	create_timer(120).timeout.connect(func():print("FAIL deployment start watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	var width=int(OS.get_environment("DEPLOYMENT_WIDTH"));width=1180 if width==0 else width
	root.size=Vector2i(width,832 if width==1283 else 1080 if width==1920 else 812)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle();await normal_deployment()
	var original=root.size;var before=await saved();geometry("fresh "+str(width))
	for dims in [Vector2i(1180,812),Vector2i(1283,832),Vector2i(1920,1080),original]:
		root.size=dims;await settle();geometry("resized "+str(dims))
	check(await saved()==before,"parent resizing cannot alter deployment save or rules")
	await click("DeploymentBegin")
	check(game.campaign().phase=="battle" and not game.state().get("deploying",false),"ordinary start button begins canonical battle")
	geometry("battle footer "+str(width))
	for dims in [Vector2i(1180,812),Vector2i(1283,832),Vector2i(1920,1080),original]:
		root.size=dims;await settle();geometry("battle resized "+str(dims))
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"BGM voice SE remain OFF")
	for spec in [["deployment-start-checks.json",checks],["deployment-start-geometry.json",measurements]]:
		var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
