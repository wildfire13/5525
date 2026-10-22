extends "res://tests/inventory_header_261020.gd"
var clicked=[]
func probe_point(at: Vector2,label: String):
	var board=game.board
	var cell=board.cell_at(at)
	var expected=str(board.unit_at(cell).get("id",""))
	var motion=InputEventMouseMotion.new();motion.position=at;board.input_event(motion)
	await settle()
	check(board.hover_uid==expected,label+" hover uses floor occupant")
	check(game.hud.person_box.get_meta("inspected_unit","")==expected,label+" right abilities use same occupant")
	if expected.is_empty():check(board.hover_caption.is_empty(),label+" empty cell clears effect prediction")
	clicked.clear()
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;board.input_event(event)
	check(clicked==([cell] if cell>=0 else []),label+" click uses same floor cell or ignores outside")
	if cell>=0:check(board.hover_uid==expected,label+" click focus preserves matching hover")
func run():
	create_timer(120).timeout.connect(func():print("FAIL floor hover watchdog");quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await game.update({"op":"campaign_load","data":battle_fixture().guard});await settle()
	await game.choose_command("attack");await settle()
	var board=game.board
	# Observe the real board input callback without selecting/executing actions.
	board.cell_clicked.disconnect(game.on_cell)
	board.cell_clicked.connect(func(pos):clicked.append(pos))
	var before=await saved();var pending=game.pending;var chosen=game.chosen.duplicate()
	var occupied=int(game.state().units[0].pos);var empty=-1
	for p in range(50):
		if board.unit_at(p).is_empty():empty=p;break
	for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims;await settle()
		for pitch in [.4,.7,1.1]:
			board.camera_pitch=pitch;board.update_camera();await settle()
			await probe_point(board.project_cell(occupied),str(dims)+" pitch"+str(pitch)+" occupied")
			await probe_point(board.project_cell(occupied)+Vector2(0,5),"foot HP bar")
			await probe_point(board.project_cell(empty),"empty after occupied")
			await probe_point(board.project(board.point(0)+Vector3(-2,0,0)),"outside grid")
	board.camera_pitch=.7;board.update_camera();await settle()
	var sprite=board.actors[game.state().units[0].id].sprite
	var full=Image.create(64,64,false,Image.FORMAT_RGBA8);full.fill(Color.WHITE)
	var hole=full.duplicate();hole.fill_rect(Rect2i(16,16,32,32),Color.TRANSPARENT)
	for p in [empty,occupied]:
		var at=board.project_cell(p)
		# Put a different unit image over this floor cell, without changing its pos.
		for u in game.state().units:
			if int(u.pos)!=p:sprite=board.actors[u.id].sprite;break
		sprite.global_position=board.point(p)+Vector3(0,.03,0)+board.world.camera.global_basis.z*.8
		sprite.pixel_size=.03
		for texture in [full,hole]:
			sprite.texture=ImageTexture.create_from_image(texture)
			await probe_point(at,"overlapping "+("opaque" if texture==full else "transparent")+" image on cell "+str(p))
	check(board.overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE and board.viewport_container.mouse_filter==Control.MOUSE_FILTER_IGNORE,"HP drawing overlay and viewport cannot intercept mouse")
	# A pending target must not be mistaken for the occupant of an empty hovered cell.
	game.pending=str(game.state().units[0].id);game.hud.selected_cell=occupied
	board.set_hover(game.pending);await probe_point(board.project_cell(empty),"empty with pending target")
	check(game.pending==str(game.state().units[0].id),"empty hover preserves pending action")
	game.pending=pending
	check(game.chosen==chosen and await saved()==before,"hover and observed clicks preserve save and chosen targets")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
