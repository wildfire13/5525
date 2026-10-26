extends SceneTree
## Kind-less legacy shield packets remain distinct from selection and foot-level status information.
var checks: Array = []
func _initialize():call_deferred("run")
func check(ok: bool, label: String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)
func run():
	var evidence=OS.get_environment("SKILL_EFFECT_QA_ROOT")
	if evidence.is_empty():evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):
		push_error("isolated evidence/XDG profile required");quit(2);return
	# No campaign, audio player, native process or random source is created.
	var board=load("res://battle_board.gd").new()
	board.size=Vector2(900,650);root.add_child(board)
	await process_frame
	var layer=board.skill_effects
	layer.process_mode=Node.PROCESS_MODE_DISABLED
	check(layer.get_index()<board.overlay.get_index(),"shield stays beneath HP and other numeric labels")
	check(layer.mouse_filter==Control.MOUSE_FILTER_IGNORE,"shield cannot intercept input")
	layer.play({"skill_id":"guard","phase":"action","origin":24,"cells":[]},.42)
	layer._process(.21)
	var before=layer.snapshot()
	for area in [Vector2(900,650),Vector2(1180,812),Vector2(1920,1080)]:
		board.size=area
		await process_frame
		await process_frame
		check(board.view.size==Vector2i(area),str(area)+" viewport follows actual board resize")
		for yaw in [-.7,0.0,.7]:
			for pitch in [.2,.7,1.4]:
				for zoom in [10.0,16.5,24.0]:
					board.camera_yaw=yaw;board.camera_pitch=pitch;board.world.zoom=zoom;board.update_camera()
					for cell in [0,24,49]:
						var foot=board.project_cell(cell)
						var points=layer._shield_outline(cell)
						var bounds=Rect2(points[0],Vector2.ZERO)
						for point in points:bounds=bounds.expand(point)
						var tag=str([area,yaw,pitch,zoom,cell])
						check(points.size()==6 and points[0]==points[-1],tag+" closed shield")
						check(bounds.size.y>=21.99 and bounds.size.y<=30.01 and bounds.size.x>=18.9,tag+" shield legible at all angles")
						# Include the dark 4px stroke and antialiasing in the bounds.
						var ink=bounds.grow(3)
						check(not ink.intersects(Rect2(foot-Vector2(18,18),Vector2(36,36))),tag+" clears 18px selection ring")
						check(not ink.intersects(Rect2(foot+Vector2(-28,-21),Vector2(56,30))),tag+" clears HP band and guard text")
	check(layer.snapshot()==before,"geometry checks do not change active event or timing")
	await process_frame
	layer._process(.21)
	check(not layer.snapshot().active and not layer.is_processing(),"existing .42 second duration ends with no residue")
	var file=FileAccess.open(evidence.path_join("guard-visibility-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"));file.close()
	board.queue_free();await process_frame
	print("Guard visibility "+str(checks.filter(func(c):return c.passed).size())+"/"+str(checks.size()))
	quit(0 if checks.all(func(c):return c.passed) else 1)
