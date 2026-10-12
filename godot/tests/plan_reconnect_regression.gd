extends SceneTree
var game
var probe
var evidence=""
var checks=[]
var owned=[]
func _initialize():call_deferred("run")
func check(id,passed,detail):
	checks.append({"id":id,"passed":bool(passed),"detail":detail});print(("PASS " if passed else "FAIL ")+id+" "+detail)
func shop():return game.pages.shop_view
func plan():return shop().plan
func node(id):return game.find_child(id,true,false)
func saved():return (await probe.request({"op":"campaign_save"})).data
func settle():
	for i in range(8):await process_frame
	while game.locked or probe.busy or game.presenting or shop().quote_worker or plan().refreshing:await process_frame
func write_fixture(name,data):
	var path=evidence.path_join(name+".json");var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close();return path
func save_via_ui(name):
	var path=evidence.path_join(name+".json")
	await game.save_game();await settle()
	var dialog
	for child in game.get_children():
		if child is FileDialog:dialog=child
	dialog.file_selected.emit(path);await settle()
	# The evidence directory is fresh; a rerun may require confirming only this fixture.
	var overwrite=node("OverwriteConfirmation")
	if overwrite!=null:overwrite.confirmed.emit();await settle()
	return path
func add_plans():
	game.shop_uid="guard";game.shop_slot="rightHand";game.navigate("shop");await settle()
	await shop().select_product("staff-wood");await settle();node("AddPurchasePlan").pressed.emit();await settle()
	await shop().select_member("archer");await shop().select_product("bow-wood-1");await settle();node("AddPurchasePlan").pressed.emit();await settle()
	node("ShopMode_plan").pressed.emit();await settle()
	# Additional store intention: it is UI state, not a purchased or equipped item.
	plan().plans.north={"guard/accessory1":{"characterId":"guard","gearId":"return-ring-1","slot":"accessory1","name":"帰還の指輪"}}
func cut_connection():
	var pid=int(probe.handles.pid);OS.kill(pid)
	for i in range(4):await process_frame
	await game.update({"op":"view"});await settle()
	check("OWNED-exit-"+str(pid),probe.disconnected and not OS.is_process_running(pid),"only the test-owned Node was terminated")
func reconnect():
	await game.reconnect_engine();await settle();owned.append(int(probe.handles.pid))
func buy_calls():return probe.calls.filter(func(call):return call.get("op")=="campaign" and call.get("action")=="buyPlan").size()
func review_current():
	for row in plan().quoted.rows:
		var button=node("ReviewPlan_"+plan().key(row).replace("/","_"))
		if button!=null:button.pressed.emit();await settle()
func recovery_cases(seed):
	await game.update({"op":"campaign_load","data":seed});await settle();await add_plans()
	var intended=plan().plans.duplicate(true);var old_quote=plan().quoted.duplicate(true);var before=await saved()
	var original_path=await save_via_ui("original-campaign")
	var original=JSON.parse_string(FileAccess.get_file_as_string(original_path))
	var identity=game.campaign_identity.current_id
	check("SAVE-identity",original.godotCampaignId==identity and original.state==before.state and not original.has("plans"),"save records campaign identity but no purchase intentions")
	# Latest authorized state differs from the plan's previously reviewed equipment and cash.
	game.navigate("board");await settle()
	await game.act("inventoryAction",["guard","guard-shield-wood","unequip",null,1,"leftHand",game.campaign().inventoryToken])
	await game.act("sellInventory",["mage","hammer-wood",1,game.campaign().inventoryToken]);await settle()
	var latest=await saved();var latest_path=await save_via_ui("latest-same-campaign")
	var source_bytes=FileAccess.get_file_as_bytes(latest_path)
	await cut_connection()
	check("HOLD-disconnect",plan().held.get("plans")==intended and plan().plans.is_empty(),"both stores remain held without attaching to disconnected state")
	await reconnect();var bootstrap=await saved()
	check("HOLD-bootstrap",plan().held.get("plans")==intended and plan().plans.is_empty() and bootstrap.state.gold==180,"reconnect bootstrap does not inherit or execute old plans")
	# A second transient cut before loading must not erase the original held campaign.
	await cut_connection();await reconnect()
	check("HOLD-repeat",plan().held.get("plans")==intended,"repeated reconnect preserves waiting intentions")
	var corrupt=original.duplicate(true);corrupt.state.gold=-1
	await game.load_game(write_fixture("invalid-state",corrupt));await settle()
	check("HOLD-invalid-load",plan().held.get("plans")==intended and plan().plans.is_empty(),"rejected state does not discard held intentions")
	corrupt=original.duplicate(true);corrupt.godotCampaignId="invalid"
	await game.load_game(write_fixture("invalid-identity",corrupt));await settle()
	check("HOLD-invalid-id",plan().held.get("plans")==intended,"invalid identity is rejected without clearing recovery")
	await game.load_game(latest_path);await settle();game.navigate("shop");plan().show("plan");await settle()
	check("RESTORE-same",game.campaign_identity.current_id==identity and plan().plans==intended and plan().held.is_empty(),"same campaign restores all stores against the loaded latest state")
	check("RESTORE-state",await saved()==latest and FileAccess.get_file_as_bytes(latest_path)==source_bytes,"load and plan recovery change neither canonical state nor source file")
	check("RESTORE-fresh",plan().quoted.cost==210 and plan().quoted.goldBefore==220 and plan().quoted.afterGold==10 and plan().quoted.token!=old_quote.token,"new connection re-quotes current cash with a fresh token")
	check("RESTORE-review",not plan().ready() and node("PlanCheckout").disabled and node("ReviewPlan_guard_rightHand")!=null and node("ReviewPlan_archer_rightHand")!=null,"every restored row requires an explicit fresh review")
	check("RESTORE-difference",plan().recovery_rows["east/guard/rightHand"]!=plan().quoted.rows.filter(func(row):return row.characterId=="guard")[0].signature,"changed equipment is detected against previously acknowledged comparison")
	check("RESTORE-no-buy",buy_calls()==0,"disconnect, bootstrap, load and quote never submit a purchase")
	var stale=await probe.request({"op":"campaign","action":"buyPlan","args":[plan().entries(),old_quote.token]})
	check("RESTORE-stale",not stale.ok and await saved()==latest,"pre-disconnect checkout token cannot execute")
	await review_current();check("RESTORE-ready",plan().ready() and not node("PlanCheckout").disabled and await saved()==latest,"review enables only a new confirmation, without purchasing")
	plan().confirm_plan();await settle();game.dialog.actions.get_child(0).pressed.emit();await settle()
	check("RESTORE-cancel",plan().plans==intended and await saved()==latest,"cancel after recovery keeps intentions and consumes nothing")
	await game.load_game(latest_path);await settle();game.navigate("shop");plan().show("plan");await settle()
	check("RESTORE-connected-reload",plan().plans==intended and not plan().ready(),"same-campaign explicit reload also retains plans but invalidates approvals")
	await cut_connection();await reconnect()
	var other=original.duplicate(true);other.godotCampaignId="ffffffffffffffffffffffffffffffff"
	await game.load_game(write_fixture("other-campaign",other));await settle()
	check("DISCARD-other",plan().plans.is_empty() and plan().held.is_empty(),"another campaign with similar state never receives held plans")
	await add_plans();await cut_connection();await reconnect();await game.new_game();await settle()
	check("DISCARD-new",plan().plans.is_empty() and plan().held.is_empty(),"explicit new game still discards held intentions")
func legacy_cases(seed):
	var path=write_fixture("legacy-no-identity",seed)
	await game.load_game(path);await settle();await add_plans();var intended=plan().plans.duplicate(true);var before=FileAccess.get_file_as_bytes(path)
	await cut_connection();await reconnect();await game.load_game(path);await settle()
	check("LEGACY-same-source",plan().plans==intended and FileAccess.get_file_as_bytes(path)==before,"unchanged legacy source is recognized in this UI session without rewriting it")
	await cut_connection();await reconnect();await game.load_game(write_fixture("other-legacy-source",seed));await settle()
	check("LEGACY-distinct-source",plan().plans.is_empty() and plan().held.is_empty(),"different unidentified file is not assumed to be the same campaign")
func stale_update_case(seed):
	await game.update({"op":"campaign_load","data":seed});await settle();await add_plans()
	var intended=plan().plans.duplicate(true);var path=await save_via_ui("delayed-response-campaign")
	var old_connection=probe.connection_generation;var old_pid=int(probe.handles.pid)
	probe.hold_loss=true;OS.kill(old_pid);game.update({"op":"view"})
	var deadline=Time.get_ticks_msec()+5000
	while not probe.loss_held and Time.get_ticks_msec()<deadline:await process_frame
	check("STALE-held",probe.loss_held and probe.disconnected and not OS.is_process_running(old_pid),"a real failed main update response is delayed before its UI handler")
	await reconnect();await game.load_game(path);await settle();game.navigate("shop");plan().show("plan");await settle()
	var before=await saved();var epoch=game.pages.epoch;var quote=plan().quoted.duplicate(true)
	probe.release_loss=true;await settle()
	check("STALE-current-context",probe.connection_generation>old_connection and not probe.disconnected and not game.locked and game.notice.is_empty() and game.pages.epoch==epoch and plan().plans==intended and plan().quoted==quote,"old main update cannot clear recovered intentions, fresh quote or connection state")
	check("STALE-state",await saved()==before,"discarding the delayed response does not mutate the new canonical campaign")
func sale_cases(seed):
	for place in ["east","west","north","south","astaris"]:
		var fixture=seed.duplicate(true);fixture.state.location=place
		await game.update({"op":"campaign_load","data":fixture});game.navigate("shop");await settle()
		var allowed=place in ["east","west","north"];var reply=await probe.request({"op":"campaign","action":"saleQuote","args":["mage","hammer-wood",1]})
		check("SALE-scope-"+place,game.campaign().saleAvailable==allowed and (node("ShopMode_sale")!=null)==allowed and reply.saleQuote.ok==allowed,"visible sale entry and canonical API agree")
		if not allowed:
			var before=await saved();var rejected=await probe.request({"op":"campaign","action":"sellInventory","args":["mage","hammer-wood",1,game.campaign().inventoryToken]})
			check("SALE-reject-"+place,not rejected.ok and await saved()==before,"hidden/direct sale route cannot mutate stock or gold")
func fault_mode(action="",kind="",label=""):
	write_fixture("quote-fault-mode",{"action":action,"kind":kind,"label":label})
func fault_journal(label):
	var rows=[]
	for line in FileAccess.get_file_as_string(evidence.path_join("quote-fault-"+label+".jsonl")).strip_edges().split("\n"):
		if not line.is_empty():rows.append(JSON.parse_string(line))
	return rows
func quote_fault_cases(seed):
	fault_mode();probe.close_engine();probe.node_script=ProjectSettings.globalize_path("res://tests/plan_quote_faults.cjs");probe.start_engine();owned.append(int(probe.handles.pid))
	for action in ["inventoryQuote","saleQuote","purchasePlan","previewGear"]:
		for kind in ["eof_pre","timeout_post"]:
			var label=action+"-"+kind;await game.new_game();var fixture=seed.duplicate(true);fixture.state.gold=600
			await game.update({"op":"campaign_load","data":fixture});await settle();await add_plans()
			var before=await saved();var intended=plan().plans.duplicate(true);var previous_quote=plan().quoted.duplicate(true);var buys=buy_calls()
			var path=write_fixture("recovery-"+label,game.campaign_identity.save_metadata(before))
			if action=="inventoryQuote":
				game.pages.party_view.open_inventory("guard");await settle();var inv=game.pages.party_view.inventory_view;inv.pick("potion");inv.choose("discard");await settle()
			elif action=="saleQuote":plan().show("sale");plan().sale_owner="mage";plan().sale_item="hammer-wood";await settle()
			elif action=="previewGear":plan().show("products");await settle();game.pages.cached_quotes.clear()
			var f=FileAccess.open(evidence.path_join("quote-fault-"+label+".jsonl"),FileAccess.WRITE);f.close()
			fault_mode(action,kind,label);probe.timeout_ms=450;var pid=int(probe.handles.pid)
			if action=="inventoryQuote":await game.pages.party_view.inventory_view.prepare(null,null)
			elif action=="saleQuote":await plan().prepare_sale()
			elif action=="purchasePlan":plan().quote_stamp="";await plan().refresh()
			else:await shop().select_product("staff-wood")
			await settle();var journal=fault_journal(label);var snapshots=journal.filter(func(row):return row.stage=="authoritative_pre_fault_save")
			check("READ-"+label+"-held",probe.disconnected and not OS.is_process_running(pid) and plan().held.get("plans")==intended and plan().plans.is_empty(),"real read failure holds both stores without attaching stale quotes")
			check("READ-"+label+"-unchanged",snapshots.size()==1 and snapshots[0].response.data==before and game.campaign().gold==before.state.gold and game.campaign().characters==before.state.characters,"read failure preserves authoritative and displayed resources")
			check("READ-"+label+"-once",journal.filter(func(row):return row.stage=="request" and row.request.get("action")==action).size()==1 and buy_calls()==buys,"no read retry or automatic purchase")
			fault_mode("","",label);probe.timeout_ms=15000;await reconnect()
			check("READ-"+label+"-reconnect",not probe.disconnected and plan().held.get("plans")==intended and plan().plans.is_empty(),"reconnect keeps original intentions separate from bootstrap")
			await game.load_game(path);await settle();game.navigate("shop");plan().show("plan");await settle()
			check("READ-"+label+"-review",plan().plans==intended and plan().quoted.goldBefore==600 and plan().quoted.cost==210 and plan().quoted.token!=previous_quote.token and not plan().ready(),"same-campaign recovery obtains a fresh quote and requires all-row review")
			journal=fault_journal(label)
			check("READ-"+label+"-no-mutation",await saved()==before and journal.filter(func(row):return row.stage=="request" and row.request.get("action") in ["buyPlan","buyGear","buyItem","inventoryAction","sellInventory","useItem"]).is_empty(),"the complete fault/reconnect/reload sequence performs no economic mutation")
			fault_mode()
func run():
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("User data must be isolated");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;game.engine.close_engine();game.engine.queue_free();await process_frame
	probe=load("res://tests/plan_reconnect_probe.gd").new();game.add_child(probe);game.engine=probe;probe.start_engine();owned.append(int(probe.handles.pid));await game.new_game();await settle()
	var seed=await saved();seed.state.location="east";seed.state.gold=120;seed.state.characters.mage.inventory["hammer-wood"]=1
	await recovery_cases(seed);await legacy_cases(seed);await stale_update_case(seed);await sale_cases(seed);await quote_fault_cases(seed)
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();probe.close_engine();game.queue_free()
	for i in range(8):await process_frame
	check("OWNED-cleanup",owned.all(func(pid):return not OS.is_process_running(pid)),"all reconnect test Node processes exited")
	var f=FileAccess.open(evidence.path_join("plan-reconnect.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
