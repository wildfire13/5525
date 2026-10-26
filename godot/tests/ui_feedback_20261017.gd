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
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.characters.guard.xp=300;seed.state.characters.guard.level=4;seed.state.characters.guard.statPoints=6;seed.state.characters.guard.skillPoints=3
	seed.state.characters.guard.inventory={"potion":3,"spear-wood":2}
	await game.update({"op":"campaign_load","data":seed});await settle()
	var p=game.pages.party_view;var guild=game.pages.guild_view
	p.open_detail("guard");await settle();await tap("StatusTab_1")
	check(node("StatusClose")==null and not contains("スキルポイント") and not contains("未確定分だけ") and not contains("成長は保持"),"growth removes redundant copy and footer close")
	check(contains("経験値 300") and contains("Lv.4") and contains("ギルドで変更"),"growth level XP and guild guidance retained")
	check(node("AllocationConfirm").size.x<300,"allocation confirmation is compact")
	check(node("PartyFace_guard").get_theme_stylebox("normal").bg_color==Color("#243c58"),"current detail portrait blue")
	var status=game.dialog.window;var before=await saved()
	await tap("PartyFace_archer")
	check(p.detail_uid=="archer" and game.dialog.window==status and p.detail_tab==1 and await saved()==before,"outside bottom portrait switches same window and tab without mutation")
	var key_event=InputEventKey.new();key_event.keycode=KEY_ENTER;key_event.pressed=true;root.push_input(key_event,true);await settle()
	check(game.page=="board" and p.detail_uid=="archer" and await saved()==before,"root Enter cannot activate background controls while status open")
	await tap("PartyFace_guard")
	var u=game.roster().filter(func(x):return x.id=="guard")[0]
	p.change_draft(u,"str",1);await settle()
	check(node("AllocationConfirm").get_theme_stylebox("normal").bg_color==Color("#236044") and contains("（＋1）") and not contains("仮＋"),"pending allocation green; delta retained without provisional label")
	await capture("growth-pending")
	await tap("PartyFace_archer");check(node("DiscardAllocation")!=null and p.detail_uid=="guard","character switching preserves pending allocation until discard consent")
	node("DiscardAllocation").canceled.emit();await settle();check(p.draft_total()==1 and await saved()==before,"switch cancellation preserves allocation and complete save")
	await tap("AllocationConfirm");var d=node("AllocationConfirmation");d.canceled.emit();await settle()
	check(p.draft_total()==1 and await saved()==before,"allocation NO consumes nothing")
	await tap("AllocationConfirm");d=node("AllocationConfirmation");d.confirmed.emit();d.confirmed.emit();await settle()
	check((await saved()).state.characters.guard.statPoints==5 and p.draft_total()==0,"allocation double YES spends once")
	await at(Vector2(30,110));check(not is_instance_valid(game.dialog.window) and game.page=="board","outside click closes detail without activating underlying page")
	p.open_detail("guard");await settle();game.dialog.window.close_requested.emit();await settle();check(p.detail_uid.is_empty(),"window X closes detail")
	seed.state.location="west";await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();p.open_inventory("guard");await settle()
	check(node("InventoryOwner")==null and node("InventoryItem_spear-wood").text.contains("単価") and node("InventoryItem_potion").text.contains("売却不可"),"shop rows show unit price or unavailable without duplicate owner heading")
	check(node("InventorySell_potion").disabled and not node("InventorySell_spear-wood").disabled,"all shop entries retain sale button with correct enabled state")
	await capture("sale-rows")
	before=await saved();await tap("InventorySell_spear-wood");await tap("InventoryPrepareSale");p.inventory_view.confirmation.canceled.emit();await settle()
	check(await saved()==before,"sale cancel preserves inventory and gold")
	p.inventory_view.choose_sale("spear-wood");await settle();await tap("InventoryPrepareSale");d=p.inventory_view.confirmation;d.confirmed.emit();d.confirmed.emit();await settle()
	check((await saved()).state.characters.guard.inventory["spear-wood"]==1,"sale double YES sells exactly one")
	game.dialog.close();seed.state.location="astaris";await game.update({"op":"campaign_load","data":seed});game.navigate("party");await settle()
	check(node("GuildSwap")==null and node("GuildCancel")==null,"guild redundant actions removed")
	before=await saved();await tap("GuildMember_guard")
	check(guild.chosen_id=="guard" and node("PartyFace_guard").get_theme_stylebox("normal").bg_color==Color("#236044"),"guild selected member also green in lower bar")
	await capture("guild-selected")
	await at(Vector2(30,115));check(guild.chosen_id.is_empty() and await saved()==before,"outside guild lists clears selection without mutation")
	await tap("GuildMember_guard");node("GuildMember_archer").pressed.emit()
	while guild.stage!="animating":await process_frame
	await frames(4);await create_timer(.08).timeout
	var slides=game.find_children("GuildSlide_*","Button",true,false)
	check(slides.size()>=2,"exchange displays sliding buttons between old and new positions")
	await capture("guild-sliding");await settle()
	check(game.campaign().selected[0]=="archer" and game.campaign().selected[1]=="guard" and not game.modal_open(),"two party clicks reorder without confirmation")
	check(guild.stage=="idle" and node("GuildMember_guard").modulate.a==1,"slide animation finishes and restores input and visibility")
	await tap("GuildMember_guard");var second=node("GuildMember_guard-2");second.pressed.emit();second.pressed.emit();await settle()
	check(game.campaign().selected[1]=="guard-2" and not game.campaign().selected.has("guard"),"reserve exchange repeated signal commits once without confirmation")
	check((await saved()).state.characters==before.state.characters,"guild exchanges preserve all characters equipment HP MP growth and inventory")
	await capture("guild-swapped")
	await tap("GuildMember_guard");await tap("GuildMember_guard-2")
	check(game.campaign().selected[1]=="guard" and not game.modal_open(),"reserve first then active member swaps without confirmation")
	await tap("GuildMember_guard");await tap("GuildMember_guard")
	check(guild.chosen_id=="guard" and game.campaign().selected[1]=="guard","clicking selected member again does not reorder")
	await tap("GuildRemove");check(not game.campaign().selected.has("guard") and not game.modal_open(),"ordinary reserve removal needs no confirmation")
	await tap("GuildMember_guard");await tap("GuildAdd");check(game.campaign().selected[-1]=="guard" and not game.modal_open(),"ordinary addition uses vacant slot without confirmation")
	# Keep cargo warning for the actual carrier; no warning for a party reorder.
	await game.update({"op":"campaign_load","data":seed});game.navigate("board");await settle()
	game.pages.accept(game.campaign().board[0].id);await settle();await tap("QuestCargoOwner_porter");await tap("QuestCargoConfirm")
	game.navigate("party");await settle();before=await saved();await tap("GuildMember_porter");await tap("GuildMember_porter-2")
	check(contains("荷物を持っています") and node("GuildConfirm")!=null,"carrier to reserve retains warning")
	await capture("cargo-warning")
	await tap("GuildConfirmCancel");check(await saved()==before,"cargo warning cancel preserves entire save")
	await tap("GuildMember_porter-2");await tap("GuildConfirm");await settle()
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
