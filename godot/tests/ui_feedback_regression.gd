extends SceneTree
var game
var checks=[]
var failures=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"passed":ok,"detail":label});print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func settle():
	for i in range(8):await process_frame
	var deadline=Time.get_ticks_msec()+15000
	while (game.locked or game.engine.busy or game.presenting or game.preview_pending) and Time.get_ticks_msec()<deadline:await process_frame
func node(id: String):return game.find_child(id,true,false)
func snap():return (await game.engine.request({"op":"campaign_save"})).data
func run():
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():quit(2);return
	await game.new_game();
	game.checks_fast=true;game.audio.fast_mode=true;game.navigate("map");await settle()
	check(node("PartyRoster").find_children("RosterMember_*","Button",true,false).size()==5,"R06 active party has five persistent portraits")
	var base=await snap();base.state.characters["character_mirei"].xp=300;base.state.characters["character_mirei"].level=4;base.state.characters["character_mirei"].statPoints=6;base.state.characters["character_mirei"].skillPoints=3
	await game.update({"op":"campaign_load","data":base});await settle()
	node("RosterMember_character_mirei").pressed.emit();await settle()
	var workspace=game.pages.party_view.workspace
	workspace.set_tab("ability");await settle()
	var allocate=game.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("能力を割り振る"))[0]
	allocate.pressed.emit();await settle()
	var pv=game.pages.party_view;var u=game.roster().filter(func(x):return x.id=="character_mirei")[0];var before=await snap()
	pv.change_draft(u,"str",1);pv.change_draft(u,"str",1);pv.change_draft(u,"int",1);await settle()
	check(pv.draft_total()==3 and await snap()==before,"R07 plus changes only local pending values")
	check(node("AllocationRemaining").text.contains("3"),"R07 remaining point count is explicit")
	pv.confirm_allocation(u);await settle();var d=node("AllocationConfirmation")
	check(d!=null and d.get_cancel_button().has_focus() and d.cancel_button_text=="キャンセル","R07 confirmation defaults to cancel")
	d.canceled.emit();await settle();check(pv.draft_total()==3 and await snap()==before,"R07 NO retains pending without consuming")
	workspace.end_allocation();await settle();d=node("DiscardAllocation");check(d!=null,"R07 leaving allocation asks to discard pending changes")
	d.canceled.emit();await settle();check(workspace.allocating and pv.draft_total()==3,"R07 continue editing keeps pending changes")
	pv.confirm_allocation(u);await settle();d=node("AllocationConfirmation");d.confirmed.emit();d.confirmed.emit();await settle()
	var after=await snap();var allocations=after.state.characters["character_mirei"].allocations;check(after.state.characters["character_mirei"].statPoints==3 and allocations.str==2 and allocations.int==1 and allocations.agi==0,"R07 double confirm spends exactly the three allocated points")
	check(after.state.characters["character_mirei"].hp==before.state.characters["character_mirei"].hp+6,"R07 existing HP growth formula retained")
	game.mock_shell.toggle_character();await settle();check(game.page=="map" and node("PartyRoster")!=null,"R06 closing character restores map and roster")
	game.navigate("map");await settle();check(node("TownMap").routes.east==["north","astaris","south"],"R08 map and engine use same ring routes")
	before=await snap();before.state.location="north";await game.update({"op":"campaign_load","data":before});game.navigate("shop");await settle()
	game.pages.facility_entry.choose("buy");await settle()
	check(game.pages.shop_view.slots()==["accessory1","accessory2"],"R09 North offers both accessory slots")
	for slot in ["accessory1","accessory2"]:
		await game.pages.shop_view.select_slot(slot);await settle();check(node("ShopProductsScroll").find_children("Product_*","Button",true,false).filter(func(row):return row.is_visible_in_tree()).size()==game.pages.offered().size() and game.pages.offered().all(func(g):return g.get("allowedSlots",[g.slot]).has(slot)),"R10 product rows match current catalog for "+slot)
	game.navigate("board");await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await settle()
	var slots=game.data.formationSlots.ally.duplicate()
	check(node("PartyRoster")!=null and not slots.is_empty(),"R04 deployment shows current porter-anchored formation cells")
	await game.act("chooseFormation",["flank"]);check(game.state().formationKind=="flank" and game.data.formationSlots.ally==slots,"R04 flank selection retains porter-anchored cells")
	await game.act("begin",[]);await settle()
	check(game.hud.buttons.keys()==["action_attack","action_move","action_skill","items","action_defend"],"R01 exactly five bottom commands")
	var row=node("ActorCommands");check(row.get_global_rect().end.y<=1080 and game.hud.buttons.action_attack.global_position.x==game.hud.buttons.action_defend.global_position.x,"R01 commands fit the actor column")
	await game.choose_command("action_attack");await settle();var pending=game.pending;var action=game.command
	game.board.set_hover("character_merina");await settle();check(game.hud.person_box.get_meta("inspected_unit")=="character_merina" and game.pending==pending and game.command==action,"R02 hover changes only person inspection")
	game.board.set_hover("");await settle();check(not game.hud.person_box.has_meta("inspected_unit"),"R02 hover leave clears inspection")
	var frame=game.board.get_global_rect();game.hud.open_skills();await settle()
	var details=game.find_children("BattleSkillDetails_*","Button",true,false)
	check(not details.is_empty(),"R03 explicit skill details button")
	if not details.is_empty():
		details[0].pressed.emit();await settle();check(node("SkillDetailsBody")!=null,"R03 details open explanation")
		node("SkillDetailsBack").pressed.emit();await settle();check(node("SkillDetailsBody")==null and game.board.get_global_rect()==frame,"R03 closing explanation preserves board geometry")
	check(game.hud.decision_footer.get_global_rect().end.y<=1080,"R02 confirm footer stays visible at FHD")
	for turn in [0.0,0.4,-0.4]:
		game.board.camera_yaw+=turn;game.board.update_camera();await settle();check(game.board.cell_at(game.board.project_cell(24))==24,"R02 camera projection "+str(turn))
	await settle();check(root.get_visible_rect().encloses(game.hud.decision_footer.get_global_rect()),"R02 FHD confirm remains reachable")
	var return_only=base.duplicate(true);return_only.state.location="north";return_only.state.characters["character_mirei"].weapon="empty-rightHand";return_only.state.characters["character_mirei"].leftHand="empty-leftHand"
	await game.update({"op":"campaign_load","data":return_only});await game.act("trial",["character_mirei","return-ring-1","accessory1"]);await settle()
	check(game.data.skillset.is_empty() and game.hud.has_return() and not game.hud.buttons.action_skill.disabled,"R01 character with only return can open skills")
	game.hud.open_skills();await settle()
	var return_button=node("BattleSkill_skill_return_home")
	check(return_button!=null and not game.hud.buttons.has("return"),"R01 return remains discoverable inside skill selection")
	return_button.pressed.emit();await settle()
	var before_return=game.state().duplicate(true);await game.on_cell(0);await settle();check(game.can_commit(),"R01 return accepts home cell zero")
	game.cancel();await settle();check(game.state()==before_return,"R01 return cancellation leaves gameplay untouched")
	await game.select_skill("skill_return_home");await game.on_cell(0);await game.commit();await settle()
	var guard=game.hud.unit("character_mirei")
	check(guard.get("returnUsedGrants",{}).values().has(true) and guard.pos==0 and guard.mp==before_return.units.filter(func(u):return u.id=="character_mirei")[0].mp,"R01 return executes once with unchanged MP")
	game.hud.open_skills();await settle();check(node("BattleSkill_skill_return_home").disabled and node("BattleSkill_skill_return_home").tooltip_text.contains("1戦闘に1回"),"R01 used return remains explained and cannot repeat")
	await game.act("endTrial",[]);await settle()
	var icons=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui_icons/manifest.json"))
	check(icons.icons.size()==52,"R11 adopted manifest has exactly52 icons")
	for icon in icons.icons:check(game.icons.texture(icon.id)!=null,"R11 imported icon "+str(icon.id))
	for skill in game.icons.approved.skills:
		var icon=game.icons.skill(skill);check(icon=="approved:skill:"+skill+":1" and game.icons.texture(icon)!=null,"R11 canonical skill "+skill)
	check(game.icons.command("action_defend")=="defend" and game.icons.skill("skill_cover")=="approved:skill:skill_cover:1","R11 defense and cover namespaces stay separate")
	for slot in ["rightHand","leftHand","head","upperBody","lowerBody","feet","accessory1","accessory2"]:
		check(game.icons.gear({"type":"empty","slot":slot})==("unarmed" if slot in ["rightHand","leftHand"] else game.icons.slot(slot)),"R11 empty equipment uses correct slot icon: "+slot)
	check(game.icons.gear({"type":"empty","slot":"weapon"})=="unarmed" and game.icons.gear({"type":"empty","slot":"armor"})=="body","R11 empty legacy storage aliases preserve hand and body semantics")
	var report=FileAccess.open("user://ui-feedback-regression.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"gui":false},"  "));report.close()
	game.closing=true;game.dialog.close(false);game.hud.invalidate_hover();await settle();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	print("UI FEEDBACK checks ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
