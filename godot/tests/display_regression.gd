extends SceneTree
var game
var checks=[]
var failures=[]
var captures=[]
var layouts=[]
var visual=false
var directory=ProjectSettings.globalize_path("res://qa/visual/display")
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func settle():
	for i in range(5):await process_frame
	while game.locked or game.presenting or game.engine.busy or game.pages.shop_view.quote_worker:await process_frame
func button_named(text: String):
	for b in game.find_children("*","Button",true,false):
		if b.text.trim_prefix("● ")==text or text=="確定" and (b.text.ends_with("を確定") or b.text=="移動して手番終了"):return b
	return null
func click_at(at: Vector2):
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at
		root.push_input(event,true);await process_frame
	await settle()
func click(text: String):
	var b=button_named(text);check(b!=null and not b.disabled,"enabled input: "+text)
	if b!=null and not b.disabled:await click_at(b.get_global_rect().get_center())
func snapshot():
	await settle();return (await game.engine.request({"op":"campaign_save"})).data
func restore(save: Dictionary):
	game.gear_preview={};await game.update({"op":"campaign_load","data":save});await settle()
func capture(label: String):
	if not visual:return
	await create_timer(.1).timeout;await RenderingServer.frame_post_draw
	var path=directory.path_join(label+".png")
	var code=root.get_texture().get_image().save_png(path)
	captures.append({"path":path,"error":code})
	check(code==OK,"rendered capture: "+label)
func fully_visible(control: Control) -> bool:
	if not control.is_visible_in_tree():return false
	var bounds=control.get_global_rect()
	if not root.get_visible_rect().encloses(bounds):return false
	var ancestor=control.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents and not ancestor.get_global_rect().encloses(bounds):return false
		ancestor=ancestor.get_parent()
	return true
func layout(label: String):
	var names=["戦術","低","高","確定","仮置きを取消"]
	var rects={}
	for text in names:
		var b=button_named(text);check(b!=null and fully_visible(b),label+" visible "+text)
		if b!=null:rects[text]=str(b.get_global_rect())
	check(fully_visible(game.actor_face),label+" actor face fixed")
	check(fully_visible(game.battle_header.find_child("TurnOrder",true,false)),label+" queue fixed")
	check(fully_visible(game.hud.dock),label+" state-specific decision panel fits")
	check(game.battle_actions.get_global_rect().position.y>=game.board.get_global_rect().end.y if game.ui_size_mode!="standard" else game.hud.dock.get_global_rect().position.x>=game.board.get_global_rect().end.x,label+" decision below compact board or beside wide board")
	layouts.append({"name":label,"window":str(root.size),"viewport":str(root.get_visible_rect()),"controls":rects})
func facing(label: String):
	for u in game.state().units:
		var sprite=game.board.actors[u.id].sprite
		# Enemy textures are already left-facing assets. No second reflection is permitted.
		check(not sprite.flip_h and sprite.billboard==BaseMaterial3D.BILLBOARD_ENABLED,label+" source orientation: "+u.id)
		var filename=("enemy/enemy_" if u.side=="enemy" else "")+u.image
		var expected=Image.load_from_file(ProjectSettings.globalize_path("res://../native/assets/"+filename))
		expected.generate_mipmaps()
		check(sprite.texture.get_image().get_data()==expected.get_data(),label+" unmodified texture pixels: "+u.id)
	check(game.board.ghost.visible and not game.board.ghost.flip_h and game.board.ghost.modulate.a<1,label+" translucent ghost orientation")
	check(game.board.ghost.texture==game.board.actors.guard.sprite.texture,label+" ghost shares ally texture")
func run():
	visual=OS.get_cmdline_user_args().has("--visual")
	if visual:DirAccess.make_dir_recursive_absolute(directory)
	root.title="5525 display regression (isolated)";root.size=Vector2i(1280,800)
	var output=[]
	var node=OS.get_environment("NATIVE5525_NODE")
	if node.is_empty():node="node"
	var code=OS.execute(node,PackedStringArray([ProjectSettings.globalize_path("res://tests/display_fixtures.cjs")]),output,false,false)
	var fixture=JSON.parse_string("".join(output))
	if code!=0 or not fixture is Dictionary:check(false,"fixture generation");quit(1);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():check(false,"initialization");quit(1);return
	game.checks_fast=true;game.audio.fast_mode=true
	for profile in fixture.profiles:
		check(game.pages.normal_reach(profile.stats)==profile.reach,"normal reach / battle oracle: "+profile.name)
		for distance in range(1,5):
			check(game.pages.normal_atk(profile.stats,distance)==profile.powers[distance-1],"distance %d / battle oracle: %s" % [distance,profile.name])
	await restore(fixture.shop);game.shop_uid="guard";game.shop_slot="leftHand";game.navigate("shop")
	var before_quote=await snapshot()
	await game.preview_gear("javelin-wood");await settle()
	var lines=game.pages.shop_view.comparison_lines(game.gear_preview,true)
	for expected in ["通常ATK・距離1: 23 → 44","通常ATK・距離2: 23 → 44","通常ATK・距離3: 射程外 → 21","通常攻撃の届く距離: 2 → 3"]:
		check(str(lines).contains(expected),"mixed-reach comparison: "+expected)
	await capture("01-offhand-quote")
	check(await snapshot()==before_quote,"comparison never mutates campaign")
	game.pages.cancel_quote()
	await restore(fixture.deployment)
	check(fully_visible(button_named("配置リセット")) and fully_visible(button_named("戦闘開始")),"deployment controls fixed")
	await restore(fixture.battle)
	var before=await snapshot()
	await click("移動")
	await click_at(game.board.global_position+game.board.project_cell(23))
	check(game.pending==23 and game.preview.get("damagePreview",[]).size()>=3,"real cell input creates long multiweapon movement preview")
	check(await snapshot()==before,"movement preview is read-only")
	for window_size in [Vector2i(960,600),Vector2i(1024,768),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=window_size;await settle()
		for camera in range(3):
			await click(["戦術","低","高"][camera])
			var label="%dx%d-camera%d" % [window_size.x,window_size.y,camera]
			check(game.board.camera_mode==camera,label+" camera input")
			await settle();layout(label+" top")
			facing(label)
			check(game.board.cell_at(game.board.project_cell(23))==23 and game.board.cell_at(game.board.project_cell(25))==25,label+" selection/ghost cell projection")
			if window_size.x in [960,1280]:await capture(label+"-top")
			game.hud.toggle_details();await settle();game.dialog.body.get_parent().scroll_vertical=100000;game.dialog.close();await settle();layout(label+" detail-return")
			if window_size.x==960 and camera==0:await capture(label+"-scrolled")
	await click("仮置きを取消")
	check(game.pending==null and not game.board.ghost.visible and await snapshot()==before,"visible cancel keeps exact campaign")
	await click("行動一覧へ");await click("攻撃")
	await click_at(game.board.global_position+game.board.project_cell(25))
	check(not game.chosen.is_empty() and game.board.targets==game.chosen,"enemy selection follows rendered position")
	await click("対象選択を取消");await click("行動一覧へ")
	await click("移動")
	await click_at(game.board.global_position+game.board.project_cell(23))
	var old_actions=int(game.state().actions)
	await click("確定")
	check(game.state().units.filter(func(u):return u.id=="guard")[0].pos==23 and int(game.state().actions)==old_actions+1,"visible confirm commits movement exactly once")
	# A custom portrait is read from a shipped fixture into memory, never edited on disk.
	await restore(fixture.battle)
	var source=ProjectSettings.globalize_path("res://../native/assets/knight.png")
	var source_bytes=FileAccess.get_file_as_bytes(source)
	game.portraits.assign("guard",{"png":Marshalls.raw_to_base64(source_bytes)})
	game.render();await settle();await click("移動");await click_at(game.board.global_position+game.board.project_cell(23))
	check(game.pending==23,"custom portrait preview selects the real floor cell after layout")
	for camera in range(3):
		await click(["戦術","低","高"][camera]);facing("custom camera"+str(camera))
	check(FileAccess.get_file_as_bytes(source)==source_bytes,"custom source bytes unchanged")
	if visual:
		var key=InputEventKey.new();key.keycode=KEY_F11;key.pressed=true;root.push_input(key,true);await settle()
		check(root.mode==Window.MODE_FULLSCREEN,"F11 fullscreen same window");layout("fullscreen");await capture("fullscreen")
		key=InputEventKey.new();key.keycode=KEY_F11;key.pressed=true;root.push_input(key,true);await settle()
		check(root.mode==Window.MODE_WINDOWED,"F11 restores same window")
	await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(5):await process_frame
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"layouts":layouts,"captures":captures,"visual":visual,"input":"Godot viewport mouse/key events; not OS-desktop input"}
	var path="res://qa/display-"+("visual" if visual else "headless")+"-report.json"
	var directory_error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	if directory_error!=OK:
		push_error("Cannot create display report directory: "+str(directory_error));quit(1);return
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot open display report: "+str(FileAccess.get_open_error()));quit(1);return
	file.store_string(JSON.stringify(report,"  "))
	var write_error=file.get_error();file.close()
	if write_error!=OK:
		push_error("Cannot write display report: "+str(write_error));quit(1);return
	print("DISPLAY CHECKS "+str(checks.size())+" FAILURES "+str(failures.size()))
	quit(0 if failures.is_empty() else 1)
