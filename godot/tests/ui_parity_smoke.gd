extends SceneTree
# Current-roster journey and resource parity; retired sidebars and buy/equip flow removed.
var game
var checks=[]
const GUARD="recruit-guard-human-female"
const PORTER="recruit-porter-human-female"
var scratch=OS.get_temp_dir().path_join("5525-ui-parity-%d.json" % OS.get_process_id())
func _initialize():call_deferred("run")
func check(ok,detail):
	checks.append({"passed":bool(ok),"detail":detail})
	print(("PASS " if ok else "FAIL ")+detail)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.presenting or game.engine.busy or game.pages.shop_view.quote_worker:await process_frame
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func node(id):return game.find_child(id,true,false)
func fight():
	var actions=0
	while game.campaign().phase=="battle" and game.state().get("result")==null and actions<250:
		var file=FileAccess.open(scratch,FileAccess.WRITE);file.store_string(JSON.stringify(game.state()));file.close()
		var output=[]
		var status=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/qa_advisor.cjs"),scratch]),output,false,false)
		if status!=0:check(false,"current battle advisor");return
		var command=JSON.parse_string("".join(output))
		var result=await game.update({"op":"act","kind":command.kind,"target":command.get("target"),"presentation":true});await settle()
		if not result.get("ok",false):check(false,"advisor command accepted");return
		actions+=1
	check(game.state().get("result")!=null,"live-roster journey battle reaches result")
func run():
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	game.engine.close_engine();game.engine.node_script=ProjectSettings.globalize_path("res://tests/seeded_rules.cjs");game.engine.start_engine()
	await game.new_game();await settle();var initial=await saved()
	check(game.roster().size()==24 and game.campaign().selected.size()==5,"initial current roster and party resources")
	game.navigate("map");await settle();var chart=node("TownMap")
	check(chart!=null and chart.buttons.size()==5,"five-town schematic remains available")
	chart.buttons.north.pressed.emit();await settle()
	check(game.destination=="north" and await saved()==initial,"map destination selection preserves campaign")
	var quest=game.campaign().board.filter(func(offer):return offer.to=="east")[0]
	await game.act("accept",[quest.id,PORTER]);await settle()
	check(game.campaign().activeQuest!=null and game.campaign().activeQuest.cargoOwnerId==PORTER,"current porter accepts real quest cargo")
	await game.act("depart",[quest.to,"convoy"]);await settle()
	check(game.campaign().phase=="road","accepted current party departs")
	for stage in range(2):
		await game.act("travel",["safe"]);await settle()
		check(game.campaign().phase=="deployment" and game.data.deployment.size()>0,"live party reaches deployment")
		await game.act("begin",[]);await settle();await fight()
		if game.state().get("result")==null:break
		await game.act("finishBattle",[]);await settle()
		check(game.results_view.active,"battle rewards are presented before journey actions")
		if game.results_view.active:game.results_view.continue_button.pressed.emit();await settle()
		if stage==0:
			check(game.campaign().phase=="camp","first battle reaches camp")
			var before_rest=await saved();await game.act("rest",[]);await settle();var rested=await saved()
			check(rested.state.hours==before_rest.state.hours+2 and rested.state.journey.rested,"rest retains canonical two-hour rule "+JSON.stringify({"before":before_rest.state.hours,"after":rested.state.hours,"overflow":game.campaign().get("inventoryOverflow",[]),"notice":game.notice}))
			await game.act("rest",[]);await settle()
			check(await saved()==rested,"repeated rest cannot grant resources twice")
			await game.act("onward",[]);await settle()
	check(game.campaign().phase=="town" and game.campaign().location==quest.to,"second battle enters current destination through automatic arrival")
	if game.campaign().phase=="town" and game.campaign().location==quest.to:
		await game.act("completeQuest",[]);await settle()
		check(game.campaign().location==quest.to and game.campaign().result!=null,"delivery produces current destination result")
	var fixtures=preload("res://tests/ui_current_fixture.gd").fixtures()
	await game.update({"op":"campaign_load","data":fixtures["synthetic-east"]});game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
	var before=await saved();game.pages.shop_view.open_comparison("spear-wood");await settle()
	check(node("ShopComparisonStats")!=null and node("ShopComparisonPayment").text.contains("90G"),"live equipment comparison retains full inventory purchase price")
	await game.pages.shop_view.confirm_purchase("spear-wood",GUARD);await settle();node("PurchaseDecline").pressed.emit();await settle()
	check(await saved()==before,"shop decline preserves all campaign resources")
	await game.act("trial",[GUARD,"hammer-wood","rightHand"]);await settle();await game.select_skill("stamp");await settle()
	if not game.data.choices.skill.is_empty():await game.on_cell(int(game.data.choices.skill[0]));await settle()
	check(game.can_commit() and not game.preview.get("cells",[]).is_empty(),"explicit hammer grants live guard canonical area preview")
	await game.act("endTrial",[]);await settle()
	check(await saved()==before,"trial restores original live-roster equipment and resources")
	var output=OS.get_user_data_dir().path_join("ui-parity-smoke.json")
	var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks},"  "));file.close()
	DirAccess.remove_absolute(scratch)
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
