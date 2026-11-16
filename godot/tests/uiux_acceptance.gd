extends SceneTree
var game
var checks=[]
var failures=[]
var evidence=OS.get_environment("UIUX_EVIDENCE") if not OS.get_environment("UIUX_EVIDENCE").is_empty() else OS.get_environment("UIUX_REVIEW_EVIDENCE")
var original: Dictionary
var fixtures: Dictionary
func _initialize():call_deferred("run")
func check(ids: String,ok: bool,detail: String):
	checks.append({"ids":ids.split(","),"passed":ok,"detail":detail,"size":[root.size.x,root.size.y],"input":"Godot callback or GUI event injection"})
	if not ok:failures.append(detail)
	print(("PASS " if ok else "FAIL ")+ids+" "+detail)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.presenting or game.engine.busy or game.pages.quote_pending:await process_frame
func snapshot():return (await game.engine.request({"op":"campaign_save"})).data
func load_fixture(value: Dictionary):
	await game.update({"op":"campaign_load","data":value});await settle()
func node(name_: String):return game.find_child(name_,true,false)
func visible(control) -> bool:
	return control is Control and control.is_visible_in_tree() and root.get_visible_rect().grow(1).encloses(control.get_global_rect())
func text(node_: Node) -> String:
	var parts=[]
	if node_ is Label or node_ is Button or node_ is RichTextLabel:parts.append(node_.text)
	for child in node_.get_children():parts.append(text(child))
	return "\n".join(parts)
func named_button(value: String):
	for control in game.find_children("*","Button",true,false):
		if control.text.trim_prefix("● ")==value:return control
	return null
func key(code: int,echo:=false):
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;event.echo=echo and pressed
		root.push_input(event,true);await process_frame
	await settle()
func confirm_dialog():
	for child in game.get_children():
		if child is ConfirmationDialog and child.visible:return child
	return null
func respond(yes: bool):
	var d=confirm_dialog()
	if d!=null:
		if yes:d.confirmed.emit()
		else:d.canceled.emit()
	await settle()
func member(id: String) -> Dictionary:
	for u in game.roster():
		if u.id==id:return u
	return {}
func run():
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"))
	DirAccess.make_dir_recursive_absolute(evidence.path_join("temp"))
	root.size=Vector2i(1920,1080)
	fixtures=preload("res://tests/ui_current_fixture.gd").fixtures()
	if fixtures.is_empty():quit(1);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	await settle();game.engine.close_engine();game.engine.node_script=ProjectSettings.globalize_path("res://tests/seeded_rules.cjs");game.engine.start_engine();await game.new_game();await settle()
	original=await snapshot()
	var subset=OS.get_environment("UIUX_TEST_PART")
	if subset.is_empty():await layouts()
	if subset.is_empty() or subset=="party":await party_checks()
	if subset.is_empty() or subset=="shop":await shop_checks()
	if subset.is_empty() or subset=="battle":await battle_checks()
	if subset.is_empty() or subset=="input":await input_and_load_checks()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"manual_pending":["AC-G06: actual OS 150 percent display setting (not changed by implementer)","AC-G12: subjective listening of real audio; event ordering has automated regression"],"source":"formal UIUX v1.0 34 requirements / 65 acceptance cases","synthetic_data":"fixture battle branches, shop locations and display-only 25-member roster are synthetic; not claimed as ordinary play"}
	var f=FileAccess.open(evidence.path_join("reports/uiux-acceptance.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("UIUX ACCEPTANCE ",checks.size()," FAILURES ",failures.size())
	await settle();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.2).timeout;game.queue_free()
	for i in range(5):await process_frame
	quit(0 if failures.is_empty() else 1)
func layouts():
	var east=original.duplicate(true);east.state.location="east"
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;await settle()
		await load_fixture(original);game.navigate("character");await settle()
		check("AC-G02,AC-G03,AC-G04,AC-P01",visible(node("PartyRoster")),"live roster stays within client area "+str(dims))
		check("AC-P01",game.campaign().selected.size()==5 and game.roster().size()==24,"live roster and initial party remain available "+str(dims))
		await load_fixture(east);game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
		game.pages.shop_view.open_comparison("spear-wood");await settle()
		check("AC-S01",node("ShopComparisonStats")!=null and node("ShopComparisonBuy")!=null,"current inline comparison and purchase are available "+str(dims))
		await load_fixture(fixtures.attack);game.choose_command("action_move");await game.on_cell(int(game.data.choices.action_move[0]));await settle()
		var pending=game.pending;var preview=JSON.stringify(game.preview);var rect=node("BattleConfirm").get_global_rect()
		var regions=[game.hud.left_panel,game.hud.right_panel,node("BattleConfirm"),node("DecisionTitle")]
		check("AC-G02,AC-G03,AC-G04,AC-B01",regions.all(visible),"actor/commands/target/confirm all visible "+str(dims)+" "+str(regions.map(func(region):return {"name":region.name,"visible":region.is_visible_in_tree(),"rect":region.get_global_rect()})))
		for mode in range(3):
			game.board.camera_mode=mode;game.board.update_camera();await settle()
			check("AC-B14",game.board.cell_at(game.board.project_cell(23))==23 and game.board.cell_at(game.board.project_cell(25))==25,"camera "+str(mode)+" retains cell projection "+str(dims))
		check("AC-B14,AC-G05",game.pending==pending and JSON.stringify(game.preview)==preview and node("BattleConfirm").get_global_rect()==rect,"camera changes preserve selection, preview and fixed HUD")
		for control in game.find_children("*","Button",true,false):
			if control.is_visible_in_tree() and game.hud.decision_footer.is_ancestor_of(control):check("AC-G07",control.size.y>=40,"button target height")
	root.size=Vector2i(1920,1080);await settle()
func party_checks():
	await load_fixture(original);game.navigate("party");await settle();var before=await snapshot()
	game.pages.select_party("character_gareth");await settle()
	check("AC-P01,AC-P02",await snapshot()==before and game.pages.party_uid=="character_gareth","reserve inspection never changes party")
	game.pages.select_party("character_mirei");await game.pages.change_membership("character_mirei");await settle()
	check("AC-P03,AC-P05",game.campaign().selected.size()==4 and game.pages.party_uid=="character_mirei","removal keeps same member detail")
	await game.pages.change_membership("character_mirei");await settle()
	check("AC-P03,AC-P06",game.campaign().selected.size()==5 and member("character_mirei").hp==member("character_mirei").max,"rejoin preserves current recruit health")
	var with_porter=await snapshot();var ids=game.campaign().selected.duplicate();ids.erase("character_yuno")
	var rejected=oracle(with_porter,[{"action":"select","args":[ids]}])
	await game.pages.change_membership("character_yuno");await settle()
	check("AC-G01,AC-P04",await snapshot()==rejected and not game.campaign().hasPorter,"removing the last porter matches live composition rules")
	var without_porter=await snapshot()
	var departed=oracle(without_porter,[{"action":"depart","args":["east"]}])
	await game.act("depart",["east"]);await settle()
	var actual_departure=await snapshot()
	check("AC-P04",actual_departure==departed,"questless departure follows current composition rules")
	await load_fixture(original)
	var long_name="長い名前".repeat(10)
	var long_uid="character_mirei"
	for recruit in game.data.campaign.roster:
		if recruit.id==long_uid:recruit.name=long_name
	game.pages.party_uid=long_uid;game.navigate("character")
	game.pages.party_view.workspace.tab="ability";game.render();await settle()
	var roster_button=node("RosterMember_"+long_uid)
	check("AC-G07,AC-P07",game.pages.party_uid==long_uid and text(node("CampaignBody")).contains(long_name),"real recruit keeps full long name in selected detail")
	var name_tooltips=[roster_button]+roster_button.find_children("*","Control",true,false)
	check("AC-G07",name_tooltips.any(func(control):return control.tooltip_text.contains(long_name)),"real recruit long roster name remains available on hover/focus")
	await load_fixture(original);game.pages.party_uid="absent-test-member";game.navigate("character");game.render();await settle()
	check("AC-P07",game.pages.party_uid==game.campaign().selected[0],"absent selected ID safely falls back to first current member after load")
func shop_checks():
	await load_fixture(fixtures["synthetic-east"]);game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
	var before=await snapshot();var uid="character_mirei"
	game.pages.shop_view.open_comparison("spear-wood");await settle()
	check("AC-S03,AC-S04",node("ShopComparisonStats").text.contains("→"),"live recruit comparison shows canonical numeric changes")
	await game.pages.shop_view.confirm_purchase("spear-wood",uid);await settle()
	var quote=game.pages.shop_view.consent.duplicate(true)
	node("PurchaseDecline").pressed.emit();await settle()
	check("AC-S07",await snapshot()==before,"inventory purchase cancellation preserves exact save")
	await game.act("trial",[uid,"spear-wood","rightHand"]);await settle()
	check("AC-B20",game.data.get("trial")!=null,"eligible current recruit enters isolated trial")
	game.choose_command("action_defend");await game.commit();await settle();await game.act("endTrial",[]);await settle()
	check("AC-S09,AC-S10",await snapshot()==before and game.page=="shop","trial restores original current campaign")
	await game.pages.shop_view.confirm_purchase("spear-wood",uid);await settle();node("PurchaseAgree").pressed.emit();await settle()
	var after=await snapshot()
	check("AC-S08",after.state.gold==quote.afterGold and after.state.characters[uid].inventory.get("spear-wood",0)==before.state.characters[uid].inventory.get("spear-wood",0)+1 and after.state.characters[uid].weapon==before.state.characters[uid].weapon,"confirmed purchase adds inventory without legacy automatic replacement")
func battle_checks():
	await load_fixture(fixtures.attack)
	game.choose_command("action_attack");var target=game.data.choices.action_attack[0];var u=game.hud.unit(target);await game.on_cell(int(u.pos));await settle()
	var executable=game.can_commit();var expected=game.preview.duplicate(true)
	game.hud.open_action_details();await settle()
	check("AC-B01,AC-B04",executable and text(game.dialog.window).contains("予測受領者:") and text(game.dialog.window).contains("消費MP: 0"),"attack details retain recipient, preview and current cost")
	check("AC-B04,AC-B16",JSON.stringify(game.preview)==JSON.stringify(expected),"rendering contribution detail never changes prediction")
	game.dialog.close();await settle()
	var old_kind=game.command;await game.commit();await settle()
	check("AC-B02",game.command==old_kind and game.pending==null and game.preview.is_empty(),"next hand inherits mode but removes previous target and preview")
	await load_fixture(fixtures.attack);game.choose_command("action_move");var before=await snapshot();var dest=int(game.data.choices.action_move[0]);await game.on_cell(dest);await settle()
	check("AC-B08",text(game).contains("この移動で手番終了") and text(game).contains("移動後の陣形:"),"movement summary explains turn end and formation")
	await game.inspect_movement("action_skill");await settle()
	check("AC-B10",await snapshot()==before,"hypothetical range consumes nothing")
	game.cancel();await settle();check("AC-B08",game.pending==null and await snapshot()==before,"movement cancellation preserves position, MP and action count")
	var moved=oracle(before,[{"action":"act","args":["move",dest]}])
	await game.on_cell(dest);await game.commit();await settle()
	print("MOVE_DONE ",JSON.stringify({"before":before.state.battle.actions,"after":game.state().actions,"old_actor":before.state.battle.actor,"actor":game.state().actor,"dest":dest,"guard_pos":game.hud.unit("character_mirei").pos}))
	check("AC-G01,AC-B09",await snapshot()==moved and game.state().actions>before.state.battle.actions and game.hud.unit(before.state.battle.actor).pos==dest and game.pending==null,"moving advances engine hand count and position, then clears pending input; same actor may recur")
	await load_fixture(fixtures.low);game.hud.detail_tab=1;game.render();await settle()
	check("AC-B15",game.board.actors["character_mirei"].label.font==game.board.low_hp_font and game.board.actors["character_shion"].label.font!=game.board.low_hp_font,"below-quarter and above-quarter fonts retain HP boundary")
	var queue_=game.data.queue.duplicate(true);var repeated=queue_.map(func(q):return q.id)
	check("AC-B13",game.hud.queue_at_start==queue_ and node("TurnOrder").get_children().filter(func(c):return c is PanelContainer).size()==mini(5,queue_.size()),"queue retains full engine order while displaying only its first five cards")
	game.hud.detail_tab=0;game.hud.details_open=true;game.render();await settle()
	for enemy in game.state().units:
		if enemy.side=="enemy":game.hud.inspect_enemy(enemy.id);break
	await settle();check("AC-B11,AC-B12",text(game).contains("陣形条件") and not text(game).contains("固定マス") and game.hud.selected_enemy!="","enemy details use the current board without fixed-cell intent text")
	await load_fixture(fixtures.heal);await game.select_skill("skill_heal")
	if not game.data.choices.action_skill.is_empty():await game.on_cell(int(game.hud.unit(game.data.choices.action_skill[0]).pos))
	await settle();executable=game.can_commit();game.hud.open_action_details();await settle()
	check("AC-B05,AC-B06",executable and text(game.dialog.window).contains("由来:") and text(game.dialog.window).contains("消費MP: 1"),"skill details display current actor source, MP and legal preview")
	game.dialog.close();await settle()
	await load_fixture(fixtures.attack);game.choose_command("action_defend");await settle();check("AC-B21",game.can_commit() and text(game).contains("対象不要"),"guard remains explicitly executable without target preview")
	await game.commit();await settle()
func input_and_load_checks():
	await load_fixture(fixtures.attack);game.choose_command("action_move");await settle();var before=await snapshot()
	game.board.keyboard_cell=int(game.data.choices.action_move[0]);game.board.grab_focus();await key(KEY_ENTER)
	check("AC-G08",game.pending!=null and await snapshot()==before,"board Enter selects candidate without committing")
	var held=game.pending;await key(KEY_ENTER,true)
	check("AC-G10",game.pending==held and await snapshot()==before,"held Enter does not repeat candidate activation or execute action")
	game.hud.open_range_reference();await settle();await key(KEY_ESCAPE)
	check("AC-G09",not game.hud.range_reference and game.pending!=null,"first Escape closes current range reference only")
	await key(KEY_ESCAPE);check("AC-G09",game.pending==null and await snapshot()==before,"next Escape clears provisional target without retreat")
	game.choose_command("action_attack")
	game.on_cell(int(game.hud.unit(game.data.choices.action_attack[0]).pos));game.cancel();await settle()
	check("AC-G11",game.pending==null and game.preview.is_empty() and not game.can_commit() and await snapshot()==before,"late real preview cannot resurrect cancelled target")
	await game.on_cell(int(game.hud.unit(game.data.choices.action_attack[0]).pos));await settle()
	var pending=game.pending;var preview=JSON.stringify(game.preview);game.fullscreen();await settle();game.fullscreen();await settle()
	check("AC-G05",game.pending==pending and JSON.stringify(game.preview)==preview and await snapshot()==before,"F11 round trip retains selection and preview without action")
	game.confirm("読み込み確認",func():pass);await settle();await respond(false)
	check("AC-G17",game.pending==pending and await snapshot()==before,"load confirmation cancellation preserves pending and game state")
	var invalid=evidence.path_join("temp/uiux-invalid.json");var f=FileAccess.open(invalid,FileAccess.WRITE);f.store_string("broken");f.close()
	await game.load_game(invalid);await settle()
	check("AC-G17,AC-G19",game.pending==null and game.preview.is_empty() and await snapshot()==before and not game.notice.is_empty(),"failed actual file load preserves progression, discards pending and displays reason")
	game.open_menu();await settle()
	check("AC-G20",game.menu.visible and game.menu.find_children("*","Button",true,false).size()>0,"current common menu remains reachable")
	game.menu.hide();game.portrait_dialog();await settle()
	check("AC-G20",game.notice.contains("画像変更は戦闘"),"battle portrait restriction remains enforced")


func oracle(save: Dictionary,operations: Array) -> Dictionary:
	var path=evidence.path_join("temp/uiux-oracle-input.json")
	var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify({"save":save,"operations":operations}));f.close()
	var output_path=evidence.path_join("temp/uiux-oracle-output.json")
	var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/uiux_oracle.cjs"),path,output_path]),[],false,false)
	if code!=0:return {}
	return JSON.parse_string(FileAccess.get_file_as_string(output_path))
