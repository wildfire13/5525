extends SceneTree
var game
var failures: Array[String]=[]
var count=0
var scratch=OS.get_temp_dir().path_join("5525-ui-parity-"+str(Time.get_ticks_usec())+".json")
func check(ok: bool,label: String):
	count+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func settle():
	await process_frame;await process_frame
	while game.locked or game.presenting or game.engine.busy or game.pages.shop_view.quote_worker:await process_frame
func text_of(node: Node) -> String:
	var result=[]
	if node is Label or node is Button:result.append(node.text)
	for child in node.get_children():result.append(text_of(child))
	return "\n".join(result)
func contains(value: String) -> bool:return text_of(game).contains(value)
func button_named(value: String):
	for button in game.find_children("*","Button",true,false):
		if button.text==value:return button
	return null
func press(value: String):
	var button=button_named(value);check(button!=null and not button.disabled,"enabled control: "+value)
	if button==null or button.disabled:return
	button.pressed.emit();await settle()
func snapshot():
	await settle()
	return (await game.engine.request({"op":"campaign_save"})).data
func restore(envelope: Dictionary):
	game.gear_preview={};await game.update({"op":"campaign_load","data":envelope});await settle()
func fight():
	var actions=0
	while game.state().get("result")==null and actions<250:
		var file=FileAccess.open(scratch,FileAccess.WRITE);file.store_string(JSON.stringify(game.state(),"",true,true));file.close()
		var output=[]
		var status=OS.execute("C:/Program Files/nodejs/node.exe",PackedStringArray([ProjectSettings.globalize_path("res://tests/qa_advisor.cjs"),scratch]),output,false,false)
		if status!=0:check(false,"battle advisor");break
		var command=JSON.parse_string("".join(output))
		await game.update({"op":"act","kind":command.kind,"target":command.get("target"),"presentation":true})
		if not game.notice.is_empty():check(false,"battle progress: "+game.notice);break
		actions+=1
	check(game.state().get("result")!=null,"fixture journey battle finishes")
func run():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():check(false,"initialization");quit(1);return
	game.checks_fast=true;game.audio.fast_mode=true
	# Keep the full journey deterministic without changing production randomization.
	await settle()
	game.engine.close_engine()
	game.engine.node_script=ProjectSettings.globalize_path("res://tests/seeded_rules.cjs")
	game.engine.start_engine()
	await game.new_game()
	var initial=await snapshot()
	check(contains("経験値0・隊Lv.1") and contains("編成5/5人 / 累計0時間"),"campaign status includes XP, party count and hours")
	for quest in game.campaign().board:
		check(contains(quest.client) and contains(quest.cargo) and contains("%d枠 / 納期 %d時間 / 報酬 %dG" % [quest.weight,quest.deadline,quest.reward]),"offer has client, cargo, weight, deadline and reward: "+quest.id)
	game.navigate("map");await settle()
	var chart=game.content.find_child("TownMap",true,false)
	check(chart!=null and chart.buttons.size()==5,"five-town schematic available")
	check(chart.buttons.astaris.disabled and ["east","west","north","south"].all(func(id):return not chart.buttons[id].disabled),"star connections from city")
	chart.buttons.north.pressed.emit();await settle()
	check(game.destination=="north" and contains("ノースへ出発"),"map selection updates departure destination")
	check(await snapshot()==initial,"map selection does not depart or consume resources")
	var quest=game.campaign().board[0]
	await game.pages.accept(quest.id);await settle()
	check(game.page=="map" and game.destination==quest.to,"accept goes to map with quest destination")
	chart=game.content.find_child("TownMap",true,false)
	check(chart.buttons.values().filter(func(v):return not v.disabled).size()==1,"active quest locks all other destinations")
	game.navigate("board");await settle()
	check(contains("受注中: "+quest.name) and contains(quest.client) and contains("%d時間 / 報酬 %dG" % [quest.deadline,quest.reward]),"accepted quest retains all offer details")
	await game.act("depart",[quest.to,"convoy"])
	check(contains("第1区間") and contains("敵3人") and contains("敵2人") and contains("納期6時間"),"first road has exact stage enemy counts and deadline")
	check(game.campaign().selected.all(func(id):return contains(game.member_name(id)+"［")),"journey shows every party member resource status")
	await game.act("travel",["safe"]);await settle()
	check(contains("奇襲対象") and game.board.legal_target_cells()==game.data.deployment.get(game.selected,{}).get("ambush",[]),"deployment shows attack range and ambush indicators")
	await game.act("begin",[]);await fight()
	await game.act("finishBattle",[])
	check(game.campaign().phase=="camp" and contains("あと一区間") and contains("ポーション HP+55"),"camp includes party resources and item controls")
	var before_rest=await snapshot()
	await game.forecast_action("rest","rest",[]);await settle()
	var dialog
	for child in game.get_children():
		if child is ConfirmationDialog:dialog=child
	check(dialog!=null and dialog.dialog_text.contains("見込み 10時間 / 納期 6時間") and dialog.dialog_text.contains("超過 4時間 / 見込み報酬 117G"),"deadline modal exposes projected time, overrun and reduced reward")
	if dialog!=null:dialog.canceled.emit();await settle()
	check(await snapshot()==before_rest,"deadline cancellation preserves exact campaign")
	await game.act("rest",[])
	check(button_named("休息済み")!=null and button_named("休息済み").disabled,"camp prevents repeated rest and explains why")
	await game.act("onward",[])
	check(contains("第2区間") and contains("敵4人") and contains("敵3人"),"second road updates enemy counts")
	await game.act("travel",["short"]);await game.act("begin",[]);await fight();await game.act("finishBattle",[])
	check(game.campaign().phase=="arrival" and game.header.text.contains("イース"),"arrival status uses destination town")
	await game.act("arrive",[])
	check(contains("配達達成 / 遅配") and contains("所要時間 10時間") and contains("今回の配達報酬 117G"),"late result exposes actual hours and reward")
	check(contains("累計経験値") and game.campaign().selected.all(func(id):return contains(game.member_name(id)+"［")),"result retains growth and party status")
	await press("イースのお店へ")
	check(game.campaign().phase=="town" and game.page=="shop","result shortcut acknowledges once and opens correct facility")
	var earned=await snapshot()
	game.navigate("party");await settle()
	var guard=game.roster().filter(func(u):return u.id=="guard")[0]
	game.pages.party_view.tab=1;game.render();await settle()
	check(contains("Lv.%d" % guard.level) and contains("能力ポイント %d" % guard.statPoints) and contains(game.pages.attack_profile(guard.stats)),"party growth tab exposes level, points, distance ATK and reach")
	check(contains("スキル配分は未実装") and contains("ギルドで編成"),"growth tab retains guild and unimplemented skill-point restrictions")
	game.pages.party_view.tab=0;game.render();await settle()
	check(game.find_child("EquipmentSlots",true,false).get_child_count()==8,"equipment tab retains eight slots including accessories")
	game.navigate("shop");await settle()
	check(game.pages.shop_view.stage=="S0" and not game.pages.cached_quotes.is_empty(),"shop list uses canonical row conditions")
	game.shop_uid="guard";game.shop_slot="rightHand";await game.preview_gear("sword-iron-1");await settle()
	var quote=game.gear_preview
	var lines=game.pages.shop_view.comparison_lines(quote,true)
	for key in ["max","maxMp","speed"]:
		var before=int(quote.before[key]);var after=int(quote.after[key])
		check(str(lines).contains("%d → %d (%+d)" % [before,after,after-before]),"full comparison retains rule values: "+key)
	check(str(lines).contains("通常ATK・距離1"),"comparison includes reaching-weapon ATK")
	game.pages.shop_view.open_details();await settle()
	check(contains(quote.current.name) and contains("成長補正1回") and not contains("<null>"),"full details explain current gear and normal attack formula")
	game.dialog.close();await settle()
	check(contains("→ %dG" % quote.afterGold),"comparison shows canonical resulting gold")
	var before_quote=await snapshot()
	game.pages.cancel_quote();await settle()
	check(game.gear_preview.is_empty() and await snapshot()==before_quote,"quote cancel clears preview without any campaign mutation")
	var poor=initial.duplicate(true);poor.state.location="east";poor.state.gold=0
	await restore(poor);game.navigate("shop");await game.preview_gear("sword-iron-1")
	check(contains("所持金が不足") and button_named("購入内容を確認").disabled and not button_named("木人で試す").disabled,"unaffordable quote explains rejection but allows isolated trial")
	await game.preview_gear("sword-wood")
	check(contains("装備中の品") and button_named("購入内容を確認").disabled,"same gear purchase disabled with reason")
	var village=initial.duplicate(true);village.state.location="north"
	await restore(village);game.navigate("map");await settle()
	chart=game.content.find_child("TownMap",true,false)
	check(not chart.buttons.astaris.disabled and chart.buttons.east.disabled,"village map allows only city connection")
	game.navigate("shop")
	check(contains("お店や固有施設はまだ設定されていません"),"north explains existing facility availability")
	var stock=initial.duplicate(true);stock.state.location="south";stock.state.gold=39;stock.state.inventory.potion=99
	await restore(stock);game.navigate("shop")
	var one=game.find_children("*","Button",true,false).filter(func(v):return v.text=="1個購入")
	check(one.size()==2 and one[0].disabled and not one[1].disabled,"item purchase respects cap and affordability")
	check(contains("所持上限は各99個") and contains("HP+55 / MP+3"),"item shop preserves capacity and recovery amounts")
	await restore(initial);game.navigate("inn")
	check(contains("全員が全回復") and button_named("30Gで宿泊する / 確認").disabled,"full party inn has explanation and no charge")
	var injured=initial.duplicate(true);injured.state.characters.guard.hp=0;injured.state.characters.guard.mp=0
	await restore(injured);game.navigate("inn")
	check(contains("戦闘不能") and contains("控えの仲間は対象外") and not button_named("30Gで宿泊する / 確認").disabled,"inn explains KO recovery and reserve exclusion")
	await press("30Gで宿泊する / 確認")
	for child in game.get_children():
		if child is ConfirmationDialog:child.confirmed.emit()
	await settle()
	check(game.campaign().gold==initial.state.gold-30 and game.roster()[0].hp==game.roster()[0].max,"inn action heals active party and charges once")
	await restore(earned)
	await game.act("trial",["guard","sword-wood","rightHand"])
	game.hud.toggle_details();await settle()
	check(game.state().units.all(func(u):return contains("%s: HP %d/%d MP %d AGI %d" % [u.name,u.hp,u.max,u.mp,u.agi])),"battle detail includes every unit HP, MP and speed")
	game.dialog.close();await settle();game.choose_command("guard")
	check(contains("次の本人の番まで被ダメージ半減"),"legacy command help retained")
	game.choose_command("attack")
	if not game.data.choices.attack.is_empty():
		for u in game.state().units:
			if u.id==game.data.choices.attack[0]:await game.on_cell(int(u.pos));break
		game.hud.open_action_details();await settle()
		check(contains("成長補正+") and contains("予測:"),"damage preview includes recipients and growth bonus")
	game.dialog.close();await settle();game.hud.toggle_details();await settle()
	check(contains("敵0") and contains("条件マス") and contains("直近40件"),"battle detail includes enemy inventory, formation occupancy and full legacy log depth")
	game.dialog.close(false)
	await game.act("endTrial",[])
	await game.act("trial",["guard","hammer-wood","rightHand"])
	game.choose_command("skill")
	if not game.data.choices.skill.is_empty():await game.on_cell(int(game.data.choices.skill[0]))
	game.hud.open_action_details();await settle()
	check(not game.preview.get("cells",[]).is_empty() and contains("空/味方中心も可"),"stamp preview exposes exact affected cells and legacy instructions")
	game.dialog.close(false)
	await game.act("endTrial",[])
	var before_save=await snapshot()
	await game.save_game();await settle()
	var save_dialog
	for child in game.get_children():
		if child is FileDialog:save_dialog=child
	check(save_dialog!=null and save_dialog.file_mode==FileDialog.FILE_MODE_SAVE_FILE and not save_dialog.use_native_dialog and save_dialog.current_file.begins_with("5525-godot-"),"save restores embedded destination chooser with unique default name")
	if save_dialog!=null:save_dialog.canceled.emit();await settle()
	check(await snapshot()==before_save,"save destination cancellation preserves campaign")
	await game.save_log();await settle()
	var log_dialog
	for child in game.get_children():
		if child is FileDialog:log_dialog=child
	check(log_dialog!=null and log_dialog.current_file.begins_with("5525-log-"),"log has separate destination chooser and filename")
	if log_dialog!=null:log_dialog.canceled.emit();await settle()
	var output_path=OS.get_temp_dir().path_join("5525-ui-save-"+str(Time.get_ticks_usec())+".json")
	await game.write_snapshot(output_path,before_save,"進行")
	var saved_bytes=FileAccess.get_file_as_bytes(output_path)
	await game.write_snapshot(output_path,{"invalid":"overwrite attempt"},"進行")
	var overwrite=game.find_child("OverwriteConfirmation",false,false)
	check(overwrite!=null and FileAccess.get_file_as_bytes(output_path)==saved_bytes,"existing save waits for overwrite confirmation")
	if overwrite!=null:overwrite.canceled.emit();await settle()
	check(FileAccess.get_file_as_bytes(output_path)==saved_bytes,"cancelled overwrite preserves original save")
	DirAccess.remove_absolute(output_path)
	game.portrait_dialog();await settle()
	check(contains("16MiBまで") and contains("先頭フレーム") and contains("割当を残すには進行を保存"),"portrait dialog retains import limits and persistence instructions")
	for child in game.get_children():
		if child is Window:child.queue_free()
	await settle()
	DirAccess.remove_absolute(scratch)
	game.audio.close_audio();game.engine.close_engine();await create_timer(.15).timeout
	game.queue_free();await process_frame
	print(JSON.stringify({"suite":"ui_parity","checks":count,"failures":failures,"visible_gui":false,"subjective_listening":false}))
	quit(0 if failures.is_empty() else 1)
