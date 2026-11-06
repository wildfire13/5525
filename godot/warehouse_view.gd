extends RefCounted
## Session-only selection. Ownership changes atomically in the campaign bridge.
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var owner_id := ""
var item_id := ""
var source := ""
var quantity := 1
var pending := false
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func available() -> bool:return ui.page=="party" and pages.facility_entry.view=="warehouse" and pages.c().get("warehouseView",{}).get("available",false)
func busy() -> bool:return pending or ui.locked or ui.presenting or ui.closing or ui.engine.disconnected
func reset():owner_id="";item_id="";source="";quantity=1;pending=false
func select_owner(id: String):
	if busy() or not available() or not pages.c().get("selected",[]).has(id):return
	owner_id=id;item_id="";source="";quantity=1;ui.render()
func rows(side: String) -> Array:
	return pages.c().get("warehouseView",{}).get("entries",[]) if side=="warehouse" else pages.c().get("inventoryByCharacter",{}).get(owner_id,{}).get("entries",[])
func selected_row() -> Dictionary:
	for entry in rows(source):
		if str(entry.id)==item_id:return entry
	return {}
func choose(side: String,id: String):
	if busy():return
	source=side;item_id=id;quantity=1;ui.render()
func quote(side: String,id: String) -> Dictionary:
	var field="withdrawals" if side=="warehouse" else "deposits"
	for entry in pages.c().get("warehouseView",{}).get("owners",{}).get(owner_id,{}).get(field,[]):
		if str(entry.itemId)==id:return entry
	return {}
func render(parent: Control):
	var ids=pages.c().get("selected",[])
	if not ids.has(owner_id):owner_id=str(ids[0]) if not ids.is_empty() else ""
	var split=HBoxContainer.new();split.name="WarehouseColumns";split.custom_minimum_size.y=ui.mock_shell.content_height();split.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;split.add_theme_constant_override("separation",16);parent.add_child(split)
	render_list(split,"character")
	var panel=PanelContainer.new();panel.name="WarehouseSelectedPanel";panel.custom_minimum_size.x=440;panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_child(panel)
	var details=VBoxContainer.new();details.name="WarehouseSelectedItem";details.add_theme_constant_override("separation",16);panel.add_child(details)
	ui.label_(details,"選択アイテム").name="WarehouseHeading"
	var selected=selected_row();var q=quote(source,item_id)
	if selected.is_empty():ui.label_(details,"アイテムを選択すると詳細が表示されます").add_theme_font_size_override("font_size",16)
	else:
		var content=ui.scroller(details);content.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
		render_item_detail(content,selected)
		ui.label_(content,"×%d" % int(selected.get("count",0)))
		var reason=ui.label_(details,str(q.get("reason","")));reason.name="WarehouseReason";reason.add_theme_font_size_override("font_size",14)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;details.add_child(spacer)
	var controls=ui.row(details);controls.name="WarehouseControls";controls.alignment=BoxContainer.ALIGNMENT_END
	if not selected.is_empty():
		var move=ui.button(controls,"預ける" if source=="character" else "取り出す",request_transfer.bind(source,item_id),busy() or not q.get("ok",false));move.name="WarehouseTransfer";move.tooltip_text=str(q.get("reason",""))
	ui.button(controls,"戻る",pages.facility_entry.back,busy()).name="WarehouseReturn"
	render_list(split,"warehouse")
func render_list(parent: Control,side: String):
	var panel=PanelContainer.new();panel.custom_minimum_size.x=420;panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(panel)
	if side=="character":
		var members=ui.roster().filter(func(member):return str(member.id)==owner_id)
		if not members.is_empty():
			var portrait=TextureRect.new();portrait.texture=ui.portraits.texture(members[0],false);portrait.modulate.a=.16;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;panel.add_child(portrait)
	var column=VBoxContainer.new();column.name="WarehouseStorage" if side=="warehouse" else "WarehouseCharacter";column.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(column)
	ui.label_(column,"共通倉庫" if side=="warehouse" else "インベントリ")
	var body=ui.scroller(column);var scroll=body.get_parent();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.memory.watch(scroll,"warehouse_"+side+"_"+owner_id)
	column.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
	scroll.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
	for entry in rows(side):
		var id=str(entry.id);var button=ui.button(body,str(entry.name)+"  ×"+str(int(entry.count)),choose.bind(side,id),busy());button.name="WarehouseItem_"+side+"_"+id;button.clip_text=true;button.custom_minimum_size=Vector2(296,56);button.tooltip_text=str(entry.name)
		ui.icons.apply(button,id if id in ["potion","ether"] else "items" if entry.get("kind")=="quest" else item_icon(entry),32)
		ui.mark_selected(button,side==source and id==item_id)
		if entry.get("overCapacity",false):button.tooltip_text+=" / 所持枠を超えています"
		button.set_drag_forwarding(func(_at):return drag(side,id),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
		ui.memory.key(button,"warehouse_item_"+side+"_"+id)
	if rows(side).is_empty():ui.label_(body,"アイテムはありません").add_theme_font_size_override("font_size",16)
	ui.label_(column,"ここへドラッグして"+("預ける" if side=="warehouse" else "取り出す")).add_theme_font_size_override("font_size",14)
func request_transfer(side: String,id: String):
	if busy() or not available():return
	var entry={}
	for value in rows(side):
		if str(value.id)==id:entry=value;break
	if entry.is_empty():return
	var token=str(pages.c().get("inventoryToken",""))
	if int(entry.get("count",1))<=1:await transfer(side,id,1,token);return
	var amount=SpinBox.new();amount.name="WarehouseQuantity";amount.min_value=1;amount.max_value=int(entry.count);amount.value=1;amount.step=1;amount.custom_minimum_size.x=140
	ui.dialog.open("個数",func(body,actions):
		body.add_child(amount)
		ui.primary(ui.button(actions,"OK",func():
			var count=int(amount.value);ui.dialog.close(false);transfer(side,id,count,token)))
		ui.local_button(actions,"キャンセル",ui.dialog.close))
func transfer_selected():
	await transfer(source,item_id,quantity,str(pages.c().get("inventoryToken","")))
func transfer(side: String,id: String,count: int,token: String):
	if busy() or not available() or token!=str(pages.c().get("inventoryToken","")):return
	pending=true
	await ui.act("warehouseAction",[owner_id,id,"withdraw" if side=="warehouse" else "deposit",count,token])
	pending=false
	if not ui.closing:ui.render()
func drag(side: String,id: String):
	if busy() or not available() or not quote(side,id).get("ok",false):return null
	return {"kind":"warehouse_item","owner":owner_id,"side":side,"id":id,"count":quantity if side==source and id==item_id else 1,"token":str(pages.c().get("inventoryToken","")),"epoch":pages.epoch,"consumed":false}
func can_drop(data,side: String) -> bool:
	return not busy() and available() and data is Dictionary and data.get("kind")=="warehouse_item" and data.get("side")!=side and data.get("owner")==owner_id and data.get("token")==str(pages.c().get("inventoryToken","")) and data.get("epoch")==pages.epoch and data.get("consumed")==false
func drop(data,side: String):
	if not can_drop(data,side):return
	data.consumed=true
	request_transfer(str(data.side),str(data.id))

func render_item_detail(parent,entry: Dictionary):
	var definition=item_definition(entry)
	if definition.is_empty():
		for item in pages.c().get("itemDefinitions",[]):
			if str(item.id)==str(entry.id):definition=item;break
	if definition.is_empty():
		var loading=ui.label_(parent,"詳細を確認中…")
		var id=str(entry.id);var epoch=pages.epoch;var connection=ui.engine.connection_generation
		while ui.engine.busy:
			await ui.get_tree().process_frame
			if not is_instance_valid(parent) or id!=item_id:return
		var response=await ui.engine.request({"op":"campaign","action":"previewGear","args":[owner_id,id,null]})
		if not is_instance_valid(parent) or not parent.is_inside_tree() or id!=item_id or epoch!=pages.epoch or connection!=ui.engine.connection_generation:return
		loading.queue_free()
		var preview=response.get("previewGear",{})
		if preview is Dictionary:definition=preview.get("gear",{})
	if not definition.is_empty() and not definition.has("resource"):
		pages.describe_gear(parent,definition)
		return
	ui.icons.line(ui,parent,str(entry.id) if str(entry.id) in ["potion","ether"] else "items",str(entry.get("name","")),true)
	if definition.has("resource"):
		ui.label_(parent,str(definition.resource).to_upper()+"を%d回復" % int(definition.get("amount",0))).name="WarehouseItemEffect"
	var weight=definition.get("weight",entry.get("weight",null))
	if weight!=null:ui.label_(parent,"Wt %s" % str(weight))

func item_definition(entry: Dictionary) -> Dictionary:
	if not entry.get("definition",{}).is_empty():return entry.definition
	for inventory in pages.c().get("inventoryByCharacter",{}).values():
		for item in inventory.get("entries",[]):
			if str(item.id)==str(entry.id):return item.get("definition",{})
	for item in pages.c().get("shop",[])+pages.c().get("itemDefinitions",[]):
		if str(item.id)==str(entry.id):return item
	for member in ui.roster():
		for item in member.get("equipmentDetails",{}).values():
			if str(item.get("id",""))==str(entry.id):return item
	return {}

func item_icon(entry: Dictionary) -> String:
	var definition=item_definition(entry)
	if not definition.is_empty():return ui.icons.equipment(definition)
	var id=str(entry.id)
	return ui.icons.equipment({"id":id}) if ui.icons.approved.equipment.has(id) or ui.icons.equipment_paths.has(id) else "items"
