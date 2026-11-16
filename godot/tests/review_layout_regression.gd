extends SceneTree
## Review UI2-03..07: real camera projection and Control geometry, no GUI or save writes.
var game
var checks=[]
var failures=[]
var measurements=[]
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
const OWNER="recruit-guard-human-female"
const SCOUT="recruit-scout-human-female"
var fresh_save={}
func _initialize():call_deferred("run")
func check(id: String,ok: bool,detail: String):
	checks.append({"id":id,"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+id+" "+detail)
	if not ok:failures.append(id+" "+detail)
func settle():
	for i in range(10):await process_frame
	var deadline=Time.get_ticks_msec()+12000
	while (game.locked or game.presenting or game.engine.busy or game.pages.shop_view.quote_worker) and Time.get_ticks_msec()<deadline:await process_frame
func fixture(location: String="east"):
	var source=fresh_save.duplicate(true);source.state.location=location
	await game.update({"op":"campaign_load","data":source});game.shop_uid=OWNER;game.shop_slot="rightHand" if location=="east" else "feet";game.navigate("shop");await settle()
func snapshot():
	await settle();return (await game.engine.request({"op":"campaign_save"})).data
func node(name: String):return game.find_child(name,true,false)
func text(value: Node)->String:
	var out=[]
	if value is Label or value is Button:out.append(value.text)
	for child in value.get_children():out.append(text(child))
	return "\n".join(out)
func contained(control: Control)->bool:
	return Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(control.get_global_rect())
func portrait_check(parent: Node,expected: Dictionary,id: String,name: String):
	var face=parent.find_child(name,true,false)
	check(id,face!=null and face.is_visible_in_tree() and face.texture==game.portraits.texture(expected,true) and contained(face),"selected member face stays visible and matches canonical portrait: "+str(root.size))
func shop_party():
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;await fixture();var before=await snapshot()
		game.pages.facility_entry.choose("buy");await settle()
		var shop=game.pages.shop_view
		var product_id=str(shop.offered()[0].id)
		shop.open_comparison(product_id);await settle()
		for name in ["ShopInventory","ShopTransaction","ShopCatalog","ShopCustomerArt"]:
			var control=node(name)
			check("UI2-05",control!=null and control.is_visible_in_tree() and contained(control),"current shop control fits FHD: "+name)
		var panels=shop.comparison_view.panels
		check("UI2-05",panels.size()==2 and panels.all(func(panel):return panel.is_visible_in_tree() and panel.get_child_count()>2),"current and candidate comparison columns display equipment and stat rows")
		var row=node("Product_"+product_id)
		check("UI2-06",row!=null and row.is_visible_in_tree() and contained(row),"current equipment product row stays visible")
		shop.set_inventory_tab("equipment");await settle()
		var rects={}
		for part in ["head","rightHand","upperBody","leftHand","lowerBody","feet","accessory1","accessory2"]:
			var slot=node("ShopEquipped_"+part)
			check("UI2-07",slot!=null and contained(slot),"current equipment slot fits: "+part)
			if slot!=null:rects[part]=slot.get_global_rect()
		game.mock_shell.toggle_character();await settle()
		for part in rects:
			var slot=node("CharacterSlot_"+part)
			check("UI2-04",slot!=null and slot.get_global_rect()==rects[part],"party and shop share slot geometry: "+part)
		check("UI2-04",await snapshot()==before,"current shop and character inspection preserve the entire campaign")
func board_case(label: String):
	for mode in range(3):
		game.board.camera_yaw=float(mode)*0.3;game.board.update_camera();await settle()
		var board=game.board;var pitch=board.cell_pitch();var all_hit=true;var all_inside=true
		for pos in range(50):
			var screen=board.project_cell(pos);all_hit=all_hit and board.cell_at(screen)==pos;all_inside=all_inside and Rect2(Vector2(8,8),board.size-Vector2(16,16)).has_point(screen)
		measurements.append({"state":label,"mode":mode,"viewport":str(root.size),"board":str(board.size),"pitch":str(pitch),"sprite_height_world":board.sprite_height()})
		print("BOARD "+JSON.stringify(measurements[-1]))
		check("UI2-03",board.size.y>=200 and pitch.x>=32 and pitch.y>=20,label+" camera "+str(mode)+" has usable board height and larger projected cell pitch")
		check("UI2-03",all_hit and all_inside,label+" camera "+str(mode)+" preserves all 50 floor hits and visible cell centers")
		check("UI2-03",contained(game.hud.dock) and (not game.hud.decision_footer.is_visible_in_tree() or contained(game.hud.decision_footer)) and (not is_instance_valid(game.battle_actions) or contained(game.battle_actions)),label+" camera "+str(mode)+" keeps the current command palette and confirm actions in viewport")
		var no_overlap=true
		for u in game.state().get("units",[]):
			var height_pixels=board.project(board.point(int(u.pos))+board.world.camera.global_basis.y*board.sprite_height()).distance_to(board.project(board.point(int(u.pos))))
			if board.compact_board():no_overlap=no_overlap and height_pixels<=pitch.y*.95
		check("UI2-03",no_overlap,label+" camera "+str(mode)+" bounds compact sprite heights below adjacent-row pitch")
func battle():
	root.size=Vector2i(1920,1080);await fixture();await game.act("depart",["astaris","convoy"]);await game.act("travel",["safe"]);await game.act("begin",[]);await settle()
	var before=await snapshot();await board_case("B0")
	game.choose_command("move");await game.on_cell(int(game.data.choices.move[0]));await settle();await board_case("B2")
	check("UI2-03",game.board.ghost.visible and game.can_commit(),"movement ghost and confirmation stay available")
	game.cancel();game.cancel();await settle();game.choose_command("guard");await settle();await board_case("B4")
	check("UI2-03",game.can_commit() and await snapshot()==before,"camera, layout, and cancelled previews preserve game state and legal confirmation")
	await fixture();await game.act("trial",[SCOUT,"twin-bow","rightHand"]);await settle()
	game.choose_command("attack");var target=game.data.choices.attack[0]
	for u in game.state().units:
		if u.id==target:await game.on_cell(int(u.pos));break
	await settle();await board_case("B4-attack")
	game.choose_command("skill");await settle();await board_case("B3-skill")
	var pair=game.data.choices.skill[0]
	for id in pair:
		for u in game.state().units:
			if u.id==id:await game.on_cell(int(u.pos));break
	await settle();await board_case("B4-multi")
	check("UI2-03",game.preview.damagePreview.size()==2 and game.can_commit(),"multi-target predictions remain complete and executable")
	await game.act("endTrial",[]);await settle()

func run():
	if evidence.is_empty():evidence="user://review-layout"
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	fresh_save=(await game.engine.request({"op":"campaign_save"})).data
	fresh_save.state.gold=1000
	var scout=fresh_save.state.characters[SCOUT]
	scout.xp=100;scout.level=2;scout.statPoints=1;scout.skillPoints=1;scout.allocations.str=1
	await shop_party();await battle()
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"gui":false,"visual_acceptance":"pending independent actual-window review"}
	var file=FileAccess.open(evidence.path_join("reports/review-layout.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ",true,true));file.close();print("REVIEW LAYOUT ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
