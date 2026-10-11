extends SceneTree
## Review UI2-03..07: real camera projection and Control geometry, no GUI or save writes.
var game
var checks=[]
var failures=[]
var measurements=[]
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func check(id: String,ok: bool,detail: String):
	checks.append({"id":id,"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+id+" "+detail)
	if not ok:failures.append(id+" "+detail)
func settle():
	for i in range(10):await process_frame
	var deadline=Time.get_ticks_msec()+12000
	while (game.locked or game.presenting or game.engine.busy or game.pages.shop_view.quote_worker) and Time.get_ticks_msec()<deadline:await process_frame
func fixture(location: String="east"):
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/synthetic-east.json"));source.state.location=location
	await game.update({"op":"campaign_load","data":source});game.shop_uid="guard";game.shop_slot="rightHand" if location=="east" else "feet";game.navigate("shop");await settle()
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
	for dims in [Vector2i(800,600),Vector2i(1024,720),Vector2i(1178,814),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=dims;await fixture();var before=await snapshot()
		var member=game.pages.shop_view.member();await game.preview_gear("spear-wood");await settle()
		portrait_check(game,member,"UI2-05","ShopMemberPortrait")
		game.pages.shop_view.confirm_purchase();await settle();portrait_check(game.dialog.window,member,"UI2-05","ConfirmationMemberPortrait")
		game.dialog.close();await settle();game.pages.shop_view.back_list();await settle()
		var row=node("Product_spear-wood");check("UI2-06",row.size.y<=(88 if dims.x>=1800 else 72),"R11 short product row fits its canonical icon and readable type: "+str(row.size))
		var label=game.pages.shop_view.row_labels["spear-wood"];check("UI2-06",label.text.contains("装備可") and label.size.y<=row.size.y-8,"canonical condition remains visible on compact product row")
		if game.ui_size_mode=="standard":check("UI2-06",node("ShopProductsScroll").size.x<=380 and node("ShopProductsScroll").size.x<node("GearQuote").get_parent().size.x,"wide comparison receives more width than product list")
		game.navigate("party");game.pages.party_uid="guard";game.pages.party_view.tab=0;game.render();await settle()
		var active=game.campaign().selected
		if game.ui_size_mode=="standard":
			var roster=node("PartyRoster");var observed=[];var seen_reserve=false;var grouped=true;var visible_active=true
			for child in roster.get_child(0).get_children():
				if not child.has_meta("member_id"):continue
				if child.get_meta("active_member"):
					observed.append(child.get_meta("member_id"));grouped=grouped and not seen_reserve;visible_active=visible_active and roster.get_global_rect().encloses(child.get_global_rect())
				else:seen_reserve=true
			check("UI2-04",observed==active and grouped and seen_reserve and visible_active,"all five active members precede reserves and fit the initial roster viewport")
			check("UI2-04",node("PartyDetail").size.x>roster.size.x,"equipment and member detail receives the wider column")
		else:
			var lineup=node("PartyActiveLineup");var observed=[];var faces=0;var fits=true
			for child in lineup.get_children():
				observed.append(child.get_meta("member_id"));faces+=child.find_children("*","TextureRect",true,false).size();fits=fits and contained(child)
				for caption in child.find_children("*","Label",true,false):
					fits=fits and child.get_global_rect().encloses(caption.get_global_rect())
			check("UI2-04",observed==active and faces==active.size() and fits,"compact view shows every active face/name/role/HP/MP before reserves")
			var reserves=node("PartyReserveSelector");check("UI2-04",reserves.item_count==game.roster().size()-active.size()+1 and contained(reserves),"separate reserve selector contains every reserve")
			reserves.item_selected.emit(1);await settle();check("UI2-04",not active.has(game.pages.party_uid) and node("PartyActiveLineup").get_child_count()==active.size(),"reserve inspection preserves the visible active lineup")
		var slots=node("EquipmentSlots");var clean=true
		for button in slots.get_children():
			var parts=button.text.split("\n");clean=clean and parts.size()==2 and not parts[1].begins_with(parts[0].trim_prefix("● ")+":") and not parts[1].begins_with(parts[0].trim_prefix("● ")+"：")
		check("UI2-07",slots.get_child_count()==8 and clean,"all eight slot labels occur once; empty values omit repeated slot prefix")
		check("UI2-04",await snapshot()==before,"shop comparison, confirmation cancel and roster inspection preserve the entire campaign")
func board_case(label: String):
	for mode in range(3):
		game.board.set_camera(mode);await settle()
		var board=game.board;var pitch=board.cell_pitch();var all_hit=true;var all_inside=true
		for pos in range(50):
			var screen=board.project_cell(pos);all_hit=all_hit and board.cell_at(screen)==pos;all_inside=all_inside and Rect2(Vector2(8,8),board.size-Vector2(16,16)).has_point(screen)
		measurements.append({"state":label,"mode":mode,"viewport":str(root.size),"board":str(board.size),"pitch":str(pitch),"sprite_height_world":board.sprite_height()})
		print("BOARD "+JSON.stringify(measurements[-1]))
		check("UI2-03",board.size.y>=200 and pitch.x>=32 and pitch.y>=20,label+" camera "+str(mode)+" has usable board height and larger projected cell pitch")
		check("UI2-03",all_hit and all_inside,label+" camera "+str(mode)+" preserves all 50 floor hits and visible cell centers")
		check("UI2-03",contained(game.hud.intent_strip) and contained(game.hud.dock) and (not is_instance_valid(game.battle_actions) or contained(game.battle_actions)),label+" camera "+str(mode)+" keeps fixed intent, decision and confirm actions in viewport")
		var no_overlap=true
		for u in game.state().get("units",[]):
			var height_pixels=board.project(board.point(int(u.pos))+board.world.camera.global_basis.y*board.sprite_height()).distance_to(board.project(board.point(int(u.pos))))
			if board.compact_board():no_overlap=no_overlap and height_pixels<=pitch.y*.95
		check("UI2-03",no_overlap,label+" camera "+str(mode)+" bounds compact sprite heights below adjacent-row pitch")
func battle():
	root.size=Vector2i(800,600);await fixture();await game.act("depart",["astaris","convoy"]);await game.act("travel",["safe"]);await game.act("begin",[]);await settle()
	var before=await snapshot();await board_case("B0")
	game.choose_command("move");await game.on_cell(int(game.data.choices.move[0]));await settle();await board_case("B2")
	check("UI2-03",game.board.ghost.visible and game.can_commit(),"movement ghost and confirmation stay available")
	game.cancel();game.cancel();await settle();game.choose_command("guard");await settle();await board_case("B4")
	check("UI2-03",game.can_commit() and await snapshot()==before,"camera, layout, and cancelled previews preserve game state and legal confirmation")
	await fixture();await game.act("trial",["archer","twin-bow","rightHand"]);await settle()
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
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));root.size=Vector2i(800,600)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await shop_party();await battle()
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"gui":false,"visual_acceptance":"pending independent actual-window review"}
	var file=FileAccess.open(evidence.path_join("reports/review-layout.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ",true,true));file.close();print("REVIEW LAYOUT ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
