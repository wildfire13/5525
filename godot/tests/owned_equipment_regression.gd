extends SceneTree
const OWNER="recruit-guard-human-female"
const PORTER="recruit-porter-human-female"
class DelayedEngine extends Node:
	var actual
	var hold_next=true
	var held=false
	var release=false
	var busy:
		get:return actual.busy
	var disconnected:
		get:return actual.disconnected
	var connection_generation:
		get:return actual.connection_generation
	var handles:
		get:return actual.handles
	var last_error:
		get:return actual.last_error
	func request(payload):
		var hold=hold_next and payload.get("action")=="previewGear"
		if hold:hold_next=false
		var reply=await actual.request(payload)
		if hold:
			held=true
			while not release:await get_tree().process_frame
			held=false
		return reply
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func node(n):return game.find_child(n,true,false)
func frames(n:=10):
	for i in range(n):await process_frame
func settle():
	await frames()
	while game.locked or game.engine.busy or game.presenting:await process_frame
	await frames()
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func tap(n):node(n).pressed.emit();await settle()
func pick_owned(uid,id):
	var entry=game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id==id)[0]
	var list=node("CharacterInventoryFilter").get_parent()
	var rows=list.find_children("*","Button",true,false).filter(func(b):return b.tooltip_text==entry.name)
	check(rows.size()==1,"one personal inventory row for "+id)
	if rows.size()==1:rows[0].pressed.emit();await settle()
func choose_slot(id):
	var chooser=node("CharacterEquipSlot")
	for i in range(chooser.item_count):
		if chooser.get_item_metadata(i)==id:
			chooser.select(i);chooser.item_selected.emit(i);await settle();return
	check(false,"equipment slot exists "+id)
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	var seed=await saved();seed.state.gold=0;seed.state.characters[OWNER].inventory={"potion":2,"ether":1,"spear-wood":2,"swift-boots":1,"bow-wood":1,"lone-ring-2":1}
	check((await game.update({"op":"campaign_load","data":seed})).get("ok",false),"valid fixture with zero gold outside equipment shop")
	var p=game.pages.party_view;p.open_inventory(OWNER);await settle()
	var ws=p.workspace
	await tap("CharacterTab_equipment")
	check(game.find_children("CharacterSlot_*","Button",true,false).size()==8,"eight equipped slots retained")
	await tap("CharacterTab_inventory")
	var before=await saved()
	for id in ["potion","ether","swift-boots","lone-ring-2","spear-wood"]:
		await pick_owned(OWNER,id)
		if id=="swift-boots":
			check(not node("CharacterEquip").disabled and not node("CharacterEquipmentComparison").text.contains("購入"),"zero gold permits owned boots comparison and equip")
		if id=="lone-ring-2":
			for slot in ["accessory1","accessory2"]:
				await choose_slot(slot)
				check(node("CharacterEquipmentComparison").text.contains(game.campaign().slots[slot]),"comparison identifies "+slot)
	check(ws.picked.count==2,"owned spear quantity")
	await choose_slot("leftHand")
	check(node("CharacterEquipmentComparison").text.contains(game.campaign().slots.leftHand) and await saved()==before,"selecting a hand updates comparison without mutation")
	var expected=(await game.engine.request({"op":"campaign","action":"previewGear","args":[OWNER,"spear-wood","leftHand"]})).previewGear.after
	await tap("CharacterEquip");var equipped=await saved()
	check(game.roster().filter(func(u):return u.id==OWNER)[0].stats==expected,"preview stats equal equipped result")
	check(equipped.state.characters[OWNER].inventory["spear-wood"]==1 and equipped.state.gold==0,"equip uses one owned item without purchase")
	await pick_owned(OWNER,"spear-wood")
	check(ws.picked.count==1,"list refreshes remaining quantity")
	await ws.perform(OWNER,"spear-wood","transfer",PORTER,1,null);await settle()
	check(not game.campaign().inventoryByCharacter[OWNER].entries.any(func(e):return e.id=="spear-wood"),"transferred last copy disappears from owner")
	check((await game.update({"op":"campaign_load","data":equipped})).get("ok",false),"reload accepts equipped inventory")
	if game.page=="character":await tap("RosterMember_"+PORTER)
	else:p.open_inventory(PORTER);await settle()
	check(ws.owner==PORTER and ws.picked.is_empty() and not game.campaign().inventoryByCharacter[PORTER].entries.any(func(e):return e.id=="spear-wood"),"owner change clears selection and previous stock")
	await tap("RosterMember_"+OWNER);await pick_owned(OWNER,"bow-wood");await choose_slot("rightHand")
	check(node("CharacterEquip").disabled and not node("CharacterEquip").tooltip_text.is_empty(),"two-handed conflict explains disabled equip")
	var unchanged=await saved();var actual=game.engine;var delayed=DelayedEngine.new();delayed.actual=actual;game.add_child(delayed);game.engine=delayed
	ws.equip_slot="leftHand";game.render()
	var deadline=Time.get_ticks_msec()+5000
	while not delayed.held and Time.get_ticks_msec()<deadline:await process_frame
	check(delayed.held,"comparison response held before switching owner")
	node("RosterMember_"+PORTER).pressed.emit();delayed.release=true;await settle()
	check(ws.owner==PORTER and node("CharacterEquipmentComparison")==null and await saved()==unchanged,"late comparison cannot overwrite new owner or mutate save")
	game.engine=actual;delayed.queue_free();await frames()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("owned-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(r):return r.passed) else 1)

func enter_facility(page: String):
	game.navigate(page);await settle()
	var service={"shop":"buy","party":"guild","inn":"inn"}.get(page,"")
	var choice=game.find_child("FacilityChoice_"+service,true,false)
	if choice!=null and choice.is_visible_in_tree():
		choice.pressed.emit();await settle()
