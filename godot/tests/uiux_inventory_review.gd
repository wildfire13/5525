extends SceneTree
var game
var checks=[]
var evidence=""
func _initialize():call_deferred("run")
func check(id,passed,detail):
	checks.append({"id":id,"passed":bool(passed),"detail":detail});print(("PASS " if passed else "FAIL ")+id+" "+detail)
func shop():return game.pages.shop_view
func plan():return shop().plan
func inventory():return game.pages.party_view.inventory_view
func node(id):return game.find_child(id,true,false)
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or shop().quote_worker or plan().refreshing:await process_frame
func colors():
	var q=game.gear_preview.duplicate(true);q.after=q.before.duplicate(true)
	q.after.max-=10;q.after.maxMp+=2
	var entries=shop().comparison_changes(q,true)
	for rule in [["HP上限","loss","#ffd0b8"],["MP上限","gain","#b4eedb"],["行動速度","neutral","#d2dce4"]]:
		var entry=entries.filter(func(e):return e.text.contains(rule[0]))[0]
		check("COLOR-meaning-"+rule[1],entry.direction==rule[1],"direction follows before/after values")
		entry.text="同じ表示記号 ▼ ▲ ＝" # Color must not parse display text.
		var label=shop().render_change(game.content,entry)
		check("COLOR-render-"+rule[1],label.get_theme_color("font_color")==Color(rule[2]),"loss/gain/zero color is independent of symbols")
	var live=game.find_children("*","Label",true,false).filter(func(label):return label.has_meta("comparison_direction"))
	check("COLOR-live",not live.is_empty() and live.all(func(label):return label.get_theme_color("font_color")==shop().CHANGE_COLORS[label.get_meta("comparison_direction")]),"live comparison nodes use semantic colors")
func budget(expected):
	var label=node("SalePlanBudget")
	return label!=null and label.get_meta("budget",{})==expected and not node("SaleInventoryScroll").is_ancestor_of(label) and root.get_visible_rect().encloses(label.get_global_rect())
func shop_cases():
	await shop().select_product("staff-wood");await settle();colors()
	node("AddPurchasePlan").pressed.emit();await settle();var before=await saved()
	await shop().select_product("hammer-wood");await settle()
	check("PLAN-replace-before",node("AddPurchasePlan").text=="予定を更新" and node("PlanReplacement").text.contains("→") and node("PlanReplacement").text.contains(plan().draft()["guard/rightHand"].name),"replacement button names update and exposes previous plan")
	var old=plan().draft()["guard/rightHand"].name;var next=game.gear_preview.gear.name
	node("AddPurchasePlan").pressed.emit();await settle()
	check("PLAN-replace-after",plan().draft().size()==1 and plan().draft()["guard/rightHand"].gearId=="hammer-wood" and node("PlanNotice").text.contains("予定を更新") and node("PlanNotice").text.contains(old+" → "+next),"update notice explicitly shows old-to-new in product view")
	check("PLAN-replace-pure",await saved()==before and node("AddPurchasePlan").disabled,"replacing intentions never purchases or duplicates a row")
	await shop().select_product("staff-wood");await settle();node("AddPurchasePlan").pressed.emit();await settle()
	await shop().select_member("archer");await shop().select_product("bow-wood-1");await settle();node("AddPurchasePlan").pressed.emit();await settle()
	var entries=plan().entries().duplicate(true);var recipient=game.shop_uid
	# Enter sale directly from products: sale must request its own current plan quote.
	node("ShopMode_sale").pressed.emit();await settle()
	check("SALE-budget-before",budget({"cost":210,"gold":120,"shortfall":90,"afterGold":-90}),"pinned sale summary exposes all four current plan values")
	var owner=node("SaleOwner");owner.select(2);owner.item_selected.emit(2);await settle();node("SaleItem_hammer-wood").pressed.emit();await settle()
	await plan().prepare_sale();await settle();before=await saved();game.dialog.actions.get_child(0).pressed.emit();await settle()
	check("SALE-cancel-budget",await saved()==before and budget({"cost":210,"gold":120,"shortfall":90,"afterGold":-90}),"cancel keeps stock, cash and visible deficit")
	await plan().prepare_sale();await settle();game.dialog.actions.get_child(1).pressed.emit();await settle()
	check("SALE-budget-after",shop().view_mode=="sale" and budget({"cost":210,"gold":220,"shortfall":0,"afterGold":10}),"sale updates plan funding without leaving sale view")
	check("SALE-context",entries==plan().entries() and recipient==game.shop_uid,"sale keeps plans and purchase recipient")
	for size_ in [Vector2i(1920,1080),Vector2i(800,600)]:
		root.size=size_;game.render();await settle();check("SALE-visible-"+str(size_.x),budget({"cost":210,"gold":220,"shortfall":0,"afterGold":10}),"summary remains outside scrolling stock list and inside viewport")
	root.size=Vector2i(1920,1080)
func open_status():game.pages.party_view.open_inventory("guard");await settle()
func close_cases():
	for stage in ["actions","targets","confirm"]:
		await open_status();inventory().pick("potion")
		if stage in ["targets","confirm"]:inventory().choose("use")
		if stage=="confirm":await inventory().prepare("mage",null)
		await settle();var before=await saved();node("StatusClose").pressed.emit();await settle()
		check("CLOSE-one-"+stage,not game.modal_open() and await saved()==before and inventory().owner_id.is_empty(),"one close leaves Status and cancels unsubmitted inventory choice")
	await open_status();inventory().pick("potion");inventory().choose("use");await inventory().prepare("mage",null);await settle()
	var before=await saved();node("StatusBack").pressed.emit();await settle()
	check("CLOSE-back",game.modal_open() and inventory().stage=="actions" and await saved()==before,"Back navigates inside Status without consumption")
	game.dialog.window.close_requested.emit();await settle();check("CLOSE-window",not game.modal_open() and await saved()==before,"window close is direct and nonconsuming")
	await open_status();inventory().pick("potion");inventory().choose("discard");await inventory().prepare(null,null);await settle()
	var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;game.dialog.window.window_input.emit(escape);await settle()
	check("CLOSE-escape",not game.modal_open() and await saved()==before,"embedded Escape closes unsubmitted discard directly")
func pending_cases(seed):
	game.engine.close_engine();game.engine.queue_free();await process_frame
	var probe=load("res://tests/inventory_pending_probe.gd").new();game.add_child(probe);game.engine=probe;probe.start_engine()
	await game.new_game();await game.update({"op":"campaign_load","data":seed});await settle();await open_status()
	inventory().pick("potion");inventory().choose("use");var before=await saved();probe.hold_action="inventoryQuote";inventory().prepare("mage",null)
	while not probe.waiting:await process_frame
	check("LOCK-quote-controls",node("StatusBack").disabled and node("StatusClose").disabled,"pending quote visibly locks both controls")
	node("StatusClose").pressed.emit();game.dialog.window.close_requested.emit();inventory().back()
	check("LOCK-quote-kept",game.modal_open() and inventory().stage=="pending" and await saved()==before,"pending quote cannot close or navigate through signal repeats")
	probe.deliver=true;await settle();node("StatusClose").pressed.emit();await settle()
	check("LOCK-quote-cancel",not game.modal_open() and await saved()==before,"after quote completion close remains nonconsuming")
	await open_status();inventory().pick("potion");inventory().choose("use");await inventory().prepare("mage",null)
	probe.hold_action="inventoryAction";inventory().commit();inventory().commit()
	while not probe.waiting:await process_frame
	node("StatusClose").pressed.emit();game.dialog.window.close_requested.emit()
	check("LOCK-commit",game.modal_open() and inventory().stage=="pending" and node("StatusClose").disabled,"pending accepted mutation cannot masquerade as cancellation")
	probe.deliver=true;await settle();var after=await saved()
	check("LOCK-once",after.state.characters.guard.inventory.potion==2 and after.state.characters.mage.hp==56,"held response and duplicate confirmation consume exactly once")
	node("StatusClose").pressed.emit();await settle();check("LOCK-final-close",not game.modal_open() and await saved()==after,"close after completion changes no resources")
func run():
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("User data must be isolated");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.location="east";seed.state.gold=120;seed.state.characters.mage.inventory["hammer-wood"]=1;seed.state.characters.mage.hp=1
	await game.update({"op":"campaign_load","data":seed});game.shop_uid="guard";game.shop_slot="rightHand";game.navigate("shop");await settle()
	await shop_cases();await close_cases();await pending_cases(seed)
	var f=FileAccess.open(evidence.path_join("uiux-inventory-review.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"\t"));f.close()
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
