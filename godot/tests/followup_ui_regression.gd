extends SceneTree
var game
var fixtures={}
var checks=[]
var failures=[]
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
var boost_phases=[]
func _initialize():call_deferred("run")
func check(ok: bool,detail: String):
	checks.append({"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+detail)
	if not ok:failures.append(detail)
func settle():
	for i in range(10):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.preview_pending:await process_frame
func text(node: Node)->String:
	var out=[]
	if node is Label or node is Button:out.append(node.text)
	for child in node.get_children():out.append(text(child))
	return "\n".join(out)
func button(label: String):
	for b in game.find_children("*","Button",true,false):
		if b.is_visible_in_tree() and b.text==label:return b
	return null
func node(name_: String):return game.find_child(name_,true,false)
func press(label: String):
	var b=button(label);check(b!=null and not b.disabled,"enabled button: "+label)
	if b!=null and not b.disabled:b.pressed.emit();await settle()
func snapshot():return (await game.engine.request({"op":"campaign_save"})).data
func restore(which: String):
	game.page="board";await game.update({"op":"campaign_load","data":fixtures[which]});await settle()
func observe():
	if game.data.get("presentation") is Dictionary and game.data.presentation.get("skill_id")=="porter":boost_phases.append(text(game.hud.target_box))
func camp_cases():
	for dims in [Vector2i(1178,814),Vector2i(800,600)]:
		root.size=dims;await restore("camp");var before=await snapshot();var party=node("CampParty")
		check(party!=null and party.get_child_count()==5,"camp has one horizontal group of five members at "+str(dims))
		var faces=party.find_children("FullBodyPortrait","TextureRect",true,false);var rows=[]
		for face in faces:
			rows.append(face.global_position.y)
			check(face.texture!=null and face.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and face.texture==game.portraits.texture(game.roster().filter(func(u):return "ItemMember_"+str(u.id)==str(face.get_parent().name))[0],false),"camp uses uncropped whole image: "+str(face.get_parent().name))
		check(faces.size()==5 and rows.all(func(y):return absf(y-rows[0])<1),"full body portraits are side by side")
		check(not text(game.content).contains("［") and game.content.find_children("ItemMember_*","VBoxContainer",true,false).size()==5,"duplicate upper HP/MP band is removed")
		check(button("アイテム")!=null and node("CampaignItemList")==null and node("ItemTarget_guard")==null,"camp starts at one item entry")
		await press("アイテム");check(node("CampaignItemList")!=null and node("ItemTarget_guard")==null,"item list precedes target controls")
		game.pages.show_items("target","potion");await settle()
		check(node("ItemTarget_guard").get_global_rect().end.y<=game.footer.global_position.y,"selected item reveals target controls above the footer")
		check(not node("ItemTarget_guard").disabled and node("ItemTarget_archer").disabled and node("ItemTarget_mage").disabled,"camp potion excludes full HP and fallen members")
		await press("アイテム一覧へ");await press("戻る");check(await snapshot()==before,"camp browse and back preserve the exact save")
		game.pages.show_items("target","potion");await settle();node("ItemTarget_guard").pressed.emit();await settle()
		var used=await snapshot();check(used.state.characters.guard.hp==before.state.characters.guard.hp+55 and used.state.inventory.potion==before.state.inventory.potion-1 and used.state.characters.guard.mp==before.state.characters.guard.mp,"camp potion preserves +55 effect, stock and MP")
		game.pages.show_items("target","ether");await settle();node("ItemTarget_guard").pressed.emit();await settle();used=await snapshot()
		check(used.state.characters.guard.mp==mini(int(before.state.characters.guard.mp)+3,6) and used.state.inventory.ether==before.state.inventory.ether-1 and node("ItemTarget_mage").disabled,"camp ether preserves +3 cap, one stock and living-only rule")
	await restore("guard");check(game.pages.item_stage=="entry" and game.pages.item_id.is_empty(),"load clears pending campaign item context")
func battle_cases():
	for dims in [Vector2i(1178,814),Vector2i(800,600)]:
		root.size=dims;await restore("guard");var before=await snapshot();var rect=game.board.get_global_rect()
		check(game.hud.buttons.has("items") and not game.hud.buttons.has("item") and not game.hud.buttons.has("ether"),"battle has a single items entry at "+str(dims))
		await press("アイテム");check(game.hud.item_list and node("BattleItem_ether").disabled and text(game.hud.target_box).contains("ポーター専用"),"non-porter sees explicit ether restriction")
		await game.on_cell(24);check(game.pending==null and not game.can_commit(),"item list cannot commit or select board targets")
		node("BattleItem_potion").pressed.emit();await settle();await game.on_cell(24);await settle()
		check(game.command=="item" and game.pending=="guard" and game.can_commit(),"potion item list reaches ordinary engine preview")
		await press("アイテム一覧へ");await press("戻る");check(await snapshot()==before and game.board.get_global_rect()==rect,"battle item back clears target and preserves save and board geometry")
		await game.choose_command("skill");await settle();check(text(game.hud.target_box).contains("内容確認") and node("SkillEffect")!=null and node("SkillSelection").size.x>=160 and button("実行").disabled and not game.modal_open(),"skill details are inline with disabled execute before target")
		await game.on_cell(23);await settle();check(game.can_commit() and not button("実行").disabled,"cover can preview a reachable ally")
		var footer=game.hud.decision_footer.get_global_rect();check(root.get_visible_rect().encloses(footer),"execute and back footer stays inside viewport")
		await press("戻る");check(game.hud.action_menu and game.pending==null and await snapshot()==before,"skill back returns directly to action list without cost")
		await restore("mp0");await press("スキル");check(text(game.hud.target_box).contains("MP不足（現在0／必要1）") and not node("SkillSelection").disabled and button("実行").disabled,"MP0 cover explains shortage while keeping skill selection available")
		var no_mp=await snapshot();await press("戻る");check(await snapshot()==no_mp,"MP0 inspection and back consume nothing")
	await restore("porter");var before=await snapshot();await press("アイテム")
	check(not node("BattleItem_ether").disabled,"porter can choose ether from the same item list")
	node("BattleItem_ether").pressed.emit();await settle();await game.on_cell(24);await settle();await game.commit();await settle()
	var after=await snapshot();check(game.hud.unit("guard").mp==3 and after.state.battle.ethers==before.state.battle.ethers-1 and after.state.battle.actions==before.state.battle.actions+1,"battle ether preserves MP+3, one item and one action")
	await restore("porter");before=await snapshot();await press("スキル")
	var effect=text(game.hud.target_box)
	check(game.pending=="porter" and game.can_commit() and not game.modal_open(),"formation boost prepares canonical self token without a modal")
	for phrase in ["味方全員","3マス外","成立している間だけ","×1.5","×0.75","×1.75","×0.65","置き換え","使用者の次の番まで","陣形が崩れている間","加算されません"]:check(effect.contains(phrase),"formation effect explains "+phrase)
	await press("戻る");check(await snapshot()==before,"formation content inspection and back never execute")
	await press("スキル");process_frame.connect(observe);await press("実行");process_frame.disconnect(observe);after=await snapshot()
	check(game.hud.unit("porter").boost and game.hud.unit("porter").mp==2 and after.state.battle.actions==before.state.battle.actions+1,"formation execute retains canonical boost, MP1 and one action")
	check(not boost_phases.is_empty() and boost_phases.any(func(value):return value.contains("効果対象: 味方全員")),"formation presentation does not mislabel the porter as the only beneficiary")
	await restore("broken");await press("スキル");check(button("実行").disabled and text(game.hud.target_box).contains("護送陣が未成立"),"broken formation explains inability to execute")
func support_cases():
	for which in ["heal_left","heal_right"]:
		await restore(which);var before=await snapshot();await press("スキル")
		check(game.data.skillReach==2 and game.data.normalAttackReach==2 and game.data.choices.skill.has("guard"),which+" bridge exposes heal reach2 with normal reach unchanged")
		await game.on_cell(24);await settle();check(game.can_commit(),which+" Godot previews heal at distance2")
		await press("実行");check(game.hud.unit("guard").hp==70 and game.hud.unit("mage").mp==before.state.battle.units.filter(func(u):return u.id=="mage")[0].mp-1,which+" executed heal restores60 and costs1MP")
	await restore("cover_staff");await press("スキル")
	check(game.data.skillReach==1 and game.data.normalAttackReach==2 and not game.data.choices.skill.has("guard"),"staff cover has fixed1 while normal staff reach stays2")
	await game.on_cell(24);await settle();check(not game.can_commit(),"staff cover rejects distance2 in Godot controls")
	await game.on_cell(21);await settle();check(game.can_commit(),"staff cover allows adjacent living ally")
	await press("実行");check(game.hud.unit("mage").cover=="porter","staff cover executes for an adjacent ally")
func run():
	var output=[];var executable=OS.get_environment("NATIVE5525_NODE");if executable.is_empty():executable="node"
	var code=OS.execute(executable,PackedStringArray([ProjectSettings.globalize_path("res://tests/followup_ui_fixtures.cjs")]),output,false,false);fixtures=JSON.parse_string("".join(output))
	if code!=0 or not fixtures is Dictionary:print(output);quit(2);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await camp_cases();await battle_cases();await support_cases()
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));var f=FileAccess.open(evidence.path_join("reports/followup-ui.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"gui":false},"  ",true,true));f.close()
	print("FOLLOWUP UI ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
