extends "res://tests/owned_equipment_regression.gd"
var mask=0
var evidence=OS.get_environment("INVENTORY_QA_ROOT")
var observations=[]
func send(at: Vector2,button:=0,pressed:=false,delta:=Vector2.ZERO):
	var event
	if button==0:event=InputEventMouseMotion.new();event.relative=delta
	else:event=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed
	if button>0 and button<=3:
		if pressed:mask|=1<<(button-1)
		else:mask&=~(1<<(button-1))
	event.button_mask=mask;event.position=at;event.global_position=at
	root.push_input(event,true);await frames(3)
func root_point(control: Control) -> Vector2:return Vector2(control.get_window().position)+control.get_global_rect().get_center()
func slot_button(slot: String):
	var index=["rightHand","leftHand","head","body","lowerBody","feet","accessory1","accessory2"].find(slot)
	return game.dialog.body.find_child("EquipmentSlots",true,false).get_child(index)
func drag(slot: String,label: String):
	var source=node("OwnedEquipment_spear-wood");var target=slot_button(slot)
	var start=root_point(source);var end=root_point(target)
	await send(start);await send(start,MOUSE_BUTTON_LEFT,true)
	await send(start+Vector2(18,0),0,false,Vector2(18,0))
	var dragging=root.gui_is_dragging()
	for i in range(1,6):await send(start.lerp(end,float(i)/5),0,false,(end-start)/5)
	await send(end,MOUSE_BUTTON_LEFT,false);await settle()
	var owned=game.pages.party_view.owned_equipment_view;var hover=owned.hover_window
	observations.append({"label":label,"drag_started":dragging,"stage":game.pages.party_view.inventory_view.stage,"source":str(source) if is_instance_valid(source) else "retired","start":str(start),"end":str(end),"hover_visible":hover.visible if is_instance_valid(hover) else false,"hover_rect":str(Rect2(Vector2(hover.position),Vector2(hover.size))) if is_instance_valid(hover) else "none"})
	check(dragging,label+" pointer input starts real viewport drag")
	check(game.pages.party_view.inventory_view.stage=="confirm",label+" drop opens canonical equipment confirmation")
	var inv=game.pages.party_view.inventory_view
	check(inv.quote.get("ownerId")=="guard" and inv.quote.get("itemId")=="spear-wood" and inv.quote.get("slot")==slot and inv.quote.get("action")=="equip" and inv.quote.get("ok",false),label+" canonical quote names exact owner item and hand")
func cancel():
	if game.pages.party_view.inventory_view.stage=="confirm":node("InventoryCancel").pressed.emit();await settle()
	check(node("OwnedEquipment_spear-wood").has_focus(),"NO restores drag origin focus without opening a keyboard comparison")
func run():
	create_timer(120).timeout.connect(func():print("FAIL UI P3 drag watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1180,812);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.characters.guard.inventory={"spear-wood":2,"potion":2}
	for dims in [Vector2i(1180,812),Vector2i(1920,1080)]:
		root.size=dims
		await game.update({"op":"campaign_load","data":seed});await settle()
		game.pages.party_view.open_detail("guard");await settle();var before=await saved()
		await drag("rightHand","initial right hand");await cancel()
		check(await saved()==before,"first NO preserves exact save")
		await drag("rightHand","same item after NO");await cancel()
		await drag("leftHand","different hand after NO");await cancel()
		await choose_slot("rightHand")
		var equip=node("OwnedEquipmentActions_spear-wood")
		await send(root_point(equip));await settle()
		var hover=game.pages.party_view.owned_equipment_view.hover_window
		var source=node("OwnedEquipment_spear-wood")
		check(hover.visible,"real pointer hover opens canonical comparison")
		check(not Rect2(Vector2(hover.position),Vector2(hover.size)).intersects(Rect2(Vector2(source.get_window().position)+source.get_global_rect().position,source.size)),"comparison remains scrollable without covering same item's drag source")
		await drag("rightHand","drag while comparison open");await cancel()
		# Non-drag confirmation keeps its established equipment-button focus origin.
		equip=node("OwnedEquipmentActions_spear-wood")
		var at=root_point(equip);await send(at);await send(at,MOUSE_BUTTON_LEFT,true);await send(at,MOUSE_BUTTON_LEFT,false);await settle()
		check(game.pages.party_view.inventory_view.stage=="confirm","real equipment button still opens canonical confirmation")
		if game.pages.party_view.inventory_view.stage=="confirm":node("InventoryCancel").pressed.emit();await settle()
		check(node("OwnedEquipmentActions_spear-wood").has_focus(),"non-drag NO retains equipment-button focus")
		game.dialog.close();await settle();game.pages.party_view.open_detail("guard");await settle()
		await drag("rightHand","closed and reopened status");await cancel()
		check(await saved()==before,"repeated cancelled drags preserve exact save")
		check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"BGM voice and SE remain OFF")
	var file=FileAccess.open(evidence.path_join("ui-p3-drag-checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"observations":observations},"\t"));file.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
