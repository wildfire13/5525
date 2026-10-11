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
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	check(node("PartyFaceBar").get_child_count()==5,"R06 active party has five persistent portraits")
	var base=await snap();base.state.characters.guard.xp=300;base.state.characters.guard.level=4;base.state.characters.guard.statPoints=6;base.state.characters.guard.skillPoints=3
	await game.update({"op":"campaign_load","data":base});await settle()
	game.pages.party_view.open_detail("guard");await settle();game.pages.party_view.detail_tab=1;game.pages.party_view.refresh_modal();await settle()
	var pv=game.pages.party_view;var u=game.roster().filter(func(x):return x.id=="guard")[0];var before=await snap()
	pv.change_draft(u,"str",1);pv.change_draft(u,"str",1);pv.change_draft(u,"int",1);await settle()
	check(pv.draft_total()==3 and await snap()==before,"R07 plus changes only local pending values")
	check(node("AllocationRemaining").text.contains("3"),"R07 remaining point count is explicit")
	pv.confirm_allocation(u);await settle();var d=node("AllocationConfirmation")
	check(d!=null and d.get_cancel_button().has_focus() and d.cancel_button_text=="NO","R07 confirmation defaults to NO")
	d.canceled.emit();await settle();check(pv.draft_total()==3 and await snap()==before,"R07 NO retains pending without consuming")
	game.dialog.close();await settle();d=node("DiscardAllocation");check(d!=null,"R07 close asks to discard pending")
	d.canceled.emit();await settle();check(is_instance_valid(game.dialog.window) and pv.draft_total()==3,"R07 continue editing keeps detail and pending")
	pv.confirm_allocation(u);await settle();d=node("AllocationConfirmation");d.confirmed.emit();d.confirmed.emit();await settle()
	var after=await snap();var allocations=after.state.characters.guard.allocations;check(after.state.characters.guard.statPoints==3 and allocations.str==2 and allocations.int==1 and allocations.agi==0,"R07 double confirm spends exactly the three allocated points")
	check(after.state.characters.guard.hp==before.state.characters.guard.hp+6,"R07 existing HP growth formula retained")
	game.dialog.close();await settle();check(not game.modal_open() and node("PartyFaceBar")!=null,"R06 close restores original page and face bar")
	game.navigate("map");await settle();check(node("TownMap").routes.east==["north","astaris","south"],"R08 map and engine use same ring routes")
	before=await snap();before.state.location="north";await game.update({"op":"campaign_load","data":before});game.navigate("shop");await settle()
	check(game.pages.shop_view.slots()==["accessory1","accessory2"],"R09 North offers both accessory slots")
	for slot in ["accessory1","accessory2"]:
		await game.pages.shop_view.select_slot(slot);await settle();check(game.pages.offered().size()>0 and game.pages.offered().all(func(g):return g.slot==slot),"R10 product rows match "+slot)
	game.navigate("board");await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await settle()
	check(node("PartyFaceBar")==null and game.data.formationSlots.ally.map(func(x):return int(x))==[23,12,32],"R04 deployment uses new basic cells and battle shell")
	await game.act("chooseFormation",["flank"]);check(game.data.formationSlots.ally.map(func(x):return int(x))==[24,13,33],"R04 deployment can select old flank cells")
	await game.act("begin",[]);await settle()
	check(game.hud.buttons.keys()==["attack","move","skill","items","guard"],"R01 exactly five bottom commands")
	var row=node("BottomCommands");check(row.get_global_rect().end.y<=1080 and game.hud.buttons.attack.global_position.y==game.hud.buttons.guard.global_position.y,"R01 bottom commands fit and share a row")
	await game.choose_command("attack");await settle();var pending=game.pending;var action=game.command
	game.board.set_hover("mage");await settle();check(game.hud.person_box.get_meta("inspected_unit")=="mage" and game.pending==pending and game.command==action,"R02 hover changes only person inspection")
	game.board.set_hover("");await settle();check(game.hud.person_box.get_meta("inspected_unit")==game.state().actor,"R02 hover leave falls back to actor")
	var frame=game.board.get_global_rect();await game.choose_command("skill");await settle();check(node("SkillContentToggle")!=null,"R03 explicit skill content button")
	node("SkillContentToggle").pressed.emit();await settle();check(node("SkillEffect")!=null,"R03 content button opens explanation")
	node("SkillContentToggle").pressed.emit();await settle();check(node("SkillEffect")==null and game.board.get_global_rect()==frame,"R03 close keeps same action and board geometry")
	check(game.hud.decision_footer.get_global_rect().end.y<=1080,"R02 confirm footer stays visible at FHD")
	for camera in range(3):game.board.set_camera(camera);await settle();check(game.board.cell_at(game.board.project_cell(24))==24,"R02 camera projection "+str(camera))
	root.size=Vector2i(800,600);await settle();check(game.hud.decision_footer.get_global_rect().end.y<=600,"R02 compact confirm remains reachable")
	var return_only=base.duplicate(true);return_only.state.location="north";return_only.state.characters.guard.weapon="empty-rightHand";return_only.state.characters.guard.leftHand="empty-leftHand"
	await game.update({"op":"campaign_load","data":return_only});await game.act("trial",["guard","return-ring-1","accessory1"]);await settle()
	check(game.data.skillset.is_empty() and game.hud.has_return() and not game.hud.buttons.skill.disabled,"R01 character with only return can open skills")
	await game.choose_command("skill");await settle();check(game.command=="return" and node("SkillSelection").get_item_metadata(0)=="returnHome" and not game.hud.buttons.has("return"),"R01 return remains discoverable inside skill selection")
	var before_return=game.state().duplicate(true);await game.on_cell(0);await settle();check(game.can_commit(),"R01 return accepts home cell zero")
	game.cancel();await settle();check(game.state()==before_return,"R01 return cancellation leaves gameplay untouched")
	await game.choose_command("skill");await game.on_cell(0);await game.commit();await settle();check(game.hud.unit("guard").returnUsed and game.hud.unit("guard").pos==0 and game.hud.unit("guard").mp==before_return.units[0].mp,"R01 return executes once with unchanged MP")
	await game.choose_command("skill");await settle();check(game.command=="return" and not game.can_commit() and game.hud.skill_unavailable_reason().contains("使用済み"),"R01 used return remains explained and cannot repeat")
	await game.act("endTrial",[]);await settle()
	var icons=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui_icons/manifest.json"));var skill_map=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui_icons/skill_mapping.json"))
	check(icons.icons.size()==52,"R11 adopted manifest has exactly52 icons")
	for icon in icons.icons:check(game.icons.texture(icon.id)!=null,"R11 imported icon "+str(icon.id))
	for skill in skill_map.skills:check(game.icons.skill(skill.skill_id)==skill.icon_ids[0],"R11 canonical skill "+str(skill.skill_id))
	check(game.icons.command("guard")=="defend" and game.icons.skill("guard")=="sheet_shield","R11 defense and cover namespaces stay separate")
	for slot in ["rightHand","leftHand","head","upperBody","lowerBody","feet","accessory1","accessory2"]:
		check(game.icons.gear({"type":"empty","slot":slot})==("unarmed" if slot in ["rightHand","leftHand"] else game.icons.slot(slot)),"R11 empty equipment uses correct slot icon: "+slot)
	check(game.icons.gear({"type":"empty","slot":"weapon"})=="unarmed" and game.icons.gear({"type":"empty","slot":"armor"})=="body","R11 empty legacy storage aliases preserve hand and body semantics")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	var report=FileAccess.open("res://qa/ui-feedback-regression.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"gui":false},"  "));report.close()
	game.closing=true;game.dialog.close(false);game.hud.invalidate_hover();await settle();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	print("UI FEEDBACK checks ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
