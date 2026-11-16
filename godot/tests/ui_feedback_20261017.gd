extends "res://tests/ui_feedback_20261016.gd"
var visual=false
func settle():
	await super.settle()
	while game.pages.guild_view.stage=="animating":await process_frame
	await frames()
func contains(fragment):return game.find_children("*","Label",true,false).any(func(n):return n.text.contains(fragment))
func at(point):
	for down in [true,false]:
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=point;e.global_position=point;root.push_input(e,true);await process_frame
	await settle()
func tap(id):
	var control=node(id);var ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await frames(3)
	var point=control.get_global_rect().get_center()
	if control.get_window()!=root:point+=Vector2(control.get_window().position)
	await at(point)
func capture(id):
	if not visual:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(id+".png"))
func run():
	create_timer(150).timeout.connect(func():print("FAIL feedback watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):quit(2);return
	visual=DisplayServer.get_name()!="headless"
	root.size=Vector2i(1920,1080);root.title="5525 feedback 20261017 - isolated PC QA"
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.characters.guard.xp=300;seed.state.characters.guard.level=4;seed.state.characters.guard.statPoints=6;seed.state.characters.guard.skillPoints=3
	seed.state.characters.guard.inventory={"potion":3,"spear-wood":2}
	await game.update({"op":"campaign_load","data":seed});await settle()
	var p=game.pages.party_view;var guild=game.pages.guild_view
	game.navigate("map");await settle();await tap("RosterMember_guard")
	p.workspace.set_tab("ability");await settle()
	check(contains("EXP 300") and contains("Lv.4"),"ability shows level and experience")
	check(node("RosterMember_guard").get_meta("selected"),"current member is highlighted in the roster")
	var before=await saved()
	await tap("RosterMember_archer")
	check(game.pages.party_uid=="archer" and p.workspace.tab=="ability" and await saved()==before,"roster switch preserves ability tab and save")
	await tap("RosterMember_guard")
	var allocate=game.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("能力を割り振る"))[0]
	allocate.pressed.emit();await settle()
	check(contains("ギルドで変更") and node("AllocationConfirm").size.x<300,"allocation has guild guidance and compact confirmation")
	var u=game.roster().filter(func(x):return x.id=="guard")[0]
	p.change_draft(u,"str",1);await settle()
	check(node("AllocationConfirm").get_theme_stylebox("normal").bg_color==Color("#236044") and contains("（＋1）") and not contains("仮＋"),"pending allocation green with explicit delta")
	await capture("growth-pending")
	await tap("RosterMember_archer");check(node("DiscardAllocation")!=null and game.pages.party_uid=="guard","switching guards pending allocation")
	node("DiscardAllocation").canceled.emit();await settle();check(p.draft_total()==1 and await saved()==before,"switch cancellation preserves allocation and complete save")
	await tap("AllocationConfirm");var d=node("AllocationConfirmation");d.canceled.emit();await settle()
	check(p.draft_total()==1 and await saved()==before,"allocation cancel consumes nothing")
	await tap("AllocationConfirm");d=node("AllocationConfirmation");d.confirmed.emit();d.confirmed.emit();await settle()
	check((await saved()).state.characters.guard.statPoints==5 and p.draft_total()==0,"allocation double confirm spends once")
	seed.state.location="west";await game.update({"op":"campaign_load","data":seed});await enter_facility("shop")
	await tap("RosterMember_guard")
	var sale=game.pages.shop_view.sale
	await tap("SaleItem_potion")
	check(node("FacilitySalePrepare").disabled and node("FacilitySaleTotals").text.contains("売却不可"),"ineligible item explains why it cannot be sold")
	await tap("SaleItem_spear-wood")
	check(not node("FacilitySalePrepare").disabled and node("FacilitySaleTotals").text.contains(str(int(sale.quote.proceeds))+"G"),"eligible sale shows quoted proceeds")
	await capture("sale-rows")
	before=await saved();await tap("FacilitySalePrepare");sale.confirmation.canceled.emit();await settle()
	check(await saved()==before,"sale cancel preserves inventory and gold")
	await tap("FacilitySalePrepare");d=sale.confirmation;d.confirmed.emit();d.confirmed.emit();await settle()
	check((await saved()).state.characters.guard.inventory["spear-wood"]==1,"sale double confirm sells exactly one")
	seed.state.location="astaris";await game.update({"op":"campaign_load","data":seed});await enter_facility("party")
	check(node("GuildSwap").disabled,"guild swap needs a selected reserve")
	before=await saved();await tap("RosterMember_guard");await tap("GuildMember_guard-2")
	check(guild.current_id=="guard" and node("GuildMember_guard-2").get_meta("selected"),"guild marks the selected reserve for the current member")
	await capture("guild-selected")
	guild.outside_press(Vector2.ZERO);await settle();check(guild.chosen_id.is_empty() and await saved()==before,"outside guild lists clears selection without mutation")
	var drag=guild.drag_payload("guard");guild.drop_member(drag,"archer");await settle()
	check(game.campaign().selected[0]=="archer" and game.campaign().selected[1]=="guard" and not game.modal_open(),"active roster reorder needs no confirmation")
	await tap("RosterMember_guard");await tap("GuildMember_guard-2")
	var swap=node("GuildSwap");swap.pressed.emit();swap.pressed.emit()
	while guild.stage=="pending":await process_frame
	await frames(3)
	check(guild.stage=="animating" and node("GuildAnimationClip")!=null,"reserve exchange starts the guild slide animation")
	await capture("guild-sliding");await settle()
	check(guild.stage=="idle" and node("GuildMember_guard").modulate.a==1,"finished slide restores reserve row")
	check(game.campaign().selected[1]=="guard-2" and not game.campaign().selected.has("guard"),"repeated swap commits once")
	check((await saved()).state.characters==before.state.characters,"exchanges preserve character equipment HP MP growth and inventory")
	await capture("guild-swapped")
	await tap("GuildMember_guard");await tap("RosterMember_guard-2");await tap("GuildSwap")
	check(game.campaign().selected[1]=="guard" and not game.modal_open(),"reserve-first selection also swaps without confirmation")
	await tap("RosterMember_guard");await tap("RosterMember_guard")
	check(guild.current_id=="guard" and game.campaign().selected[1]=="guard","selecting the same active member preserves order")
	await tap("GuildRemove");check(not game.campaign().selected.has("guard") and not game.modal_open(),"ordinary removal needs no confirmation")
	await tap("GuildMember_guard");await tap("GuildAdd");check(game.campaign().selected[-1]=="guard" and not game.modal_open(),"addition fills the vacant slot without confirmation")
	# Keep cargo warning for the actual carrier; no warning for a party reorder.
	await game.update({"op":"campaign_load","data":seed});game.navigate("board");await settle()
	game.pages.accept(game.campaign().board[0].id);await settle();await tap("QuestCargoOwner_porter");await tap("QuestCargoConfirm")
	await enter_facility("party");before=await saved();await tap("RosterMember_porter");await tap("GuildMember_porter-2");await tap("GuildSwap")
	check(contains("荷物を持っています") and node("GuildConfirm")!=null,"carrier to reserve retains warning")
	await capture("cargo-warning")
	await tap("GuildConfirmCancel");check(await saved()==before,"cargo warning cancel preserves entire save")
	await tap("GuildSwap");await tap("GuildConfirm");await settle()
	check(not game.campaign().selected.has("porter") and game.campaign().activeQuest.cargoOwnerId=="porter","cargo confirmation reserves carrier without moving cargo")
	await game.update({"op":"campaign_load","data":seed});game.navigate("map");await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await settle()
	check(node("DeploymentAllySelection")==null and not contains("位置を調整する味方") and not contains("味方クリックで選択"),"deployment selection instructions removed")
	check(node("DeploymentFormation_convoy").tooltip_text.contains("×1.5") and node("DeploymentFormation_flank").tooltip_text.contains("×0.75"),"both formation presets expose actual effects")
	game.hud.inspect_hover(game.selected);await settle();check(game.board.hover_caption.is_empty(),"deployment does not show action prediction prompt")
	await capture("deployment")
	if visual:
		var motion=InputEventMouseMotion.new();motion.position=node("DeploymentFormation_convoy").get_global_rect().get_center();motion.global_position=motion.position;root.push_input(motion,true)
		await create_timer(1.0).timeout;await capture("formation-hover")
	var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/inventory_battle_fixtures.cjs")]),output,true,false)
	var fixture=JSON.parse_string("".join(output));await game.update({"op":"campaign_load","data":fixture.guard});await settle()
	before=await saved();game.hud.open_skills();await settle();game.hud.open_items();await settle()
	check(node("BattleSkillList")==null and node("BattleItemList")!=null,"items replaces old skill list")
	game.hud.open_skills();await settle();check(node("BattleItemList")==null and node("BattleSkillList")!=null,"skills replaces old item list")
	check(not game.hud.buttons.attack.disabled,"attack remains selectable to dismiss lists even without legal target")
	var attack_point=game.hud.buttons.attack.get_global_rect().get_center();await at(attack_point)
	check(node("BattleItemList")==null and node("BattleSkillList")==null,"attack click collapses expanded lists")
	check(not game.can_commit(),"selecting attack without target cannot consume an action")
	check(await saved()==before,"command switching consumes no MP inventory or actions")
	await capture("battle-command")
	var f=FileAccess.open(evidence.path_join("feedback-20261017"+("-visible" if visual else "")+".json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	quit(0 if checks.all(func(c):return c.passed) else 1)
