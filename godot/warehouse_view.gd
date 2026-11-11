extends RefCounted
## Session-only selection. Ownership changes atomically in the campaign bridge.
const Inventory=preload("res://member_inventory.gd")
const Loadout=preload("res://member_loadout_column.gd")
var tab := "inventory"
var filters := {"character":"all","warehouse":"all"}
var equipped: Dictionary={}
var unequip_quote: Dictionary={}
var quote_context: Array=[]
var quote_generation := 0
var error_message := ""
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
func reset():
	owner_id="";pending=false;tab="inventory"
	filters={"character":"all","warehouse":"all"}
	clear_selection()

func clear_selection():
	quote_generation+=1
	quote_context=[];unequip_quote={}
	item_id="";source="";quantity=1;equipped={};error_message=""

func select_owner(id: String):
	if busy() or ui.modal_open():
		pages.party_uid=owner_id
		return
	if not available() or not pages.c().get("selected",[]).has(id):return
	owner_id=id;pages.party_uid=id;clear_selection();ui.render()

func set_tab(value: String):
	if busy() or value==tab:return
	tab=value
	if source!="warehouse":clear_selection()
	ui.render()

func set_filter(value: String,side: String):
	if busy():return
	filters[side]=value
	if source==side:clear_selection()
	ui.render()

func select_equipment(item: Dictionary):
	if busy():return
	clear_selection()
	source="equipped";equipped=item;item_id=str(item.id)
	ui.render()

func rows(side: String) -> Array:
	return pages.c().get("warehouseView",{}).get("entries",[]) if side=="warehouse" else pages.c().get("inventoryByCharacter",{}).get(owner_id,{}).get("entries",[])
func selected_row() -> Dictionary:
	for entry in rows(source):
		if str(entry.id)==item_id:return entry
	return {}
func choose(side: String,id: String):
	if busy():return
	clear_selection()
	source=side;item_id=id;quantity=1;ui.render()
func quote(side: String,id: String) -> Dictionary:
	var field="withdrawals" if side=="warehouse" else "deposits"
	for entry in pages.c().get("warehouseView",{}).get("owners",{}).get(owner_id,{}).get(field,[]):
		if str(entry.itemId)==id:return entry
	return {}
func render(parent: Control):
	var ids=pages.c().get("selected",[])
	if not ids.has(owner_id):owner_id=str(pages.party_uid) if ids.has(pages.party_uid) else str(ids[0]) if not ids.is_empty() else ""
	var members=ui.roster().filter(func(member):return member.id==owner_id)
	if members.is_empty():return
	var member=members[0]
	if not pending and source=="equipped" and quote_context!=current_quote_context():
		quote_context=current_quote_context()
		quote_generation+=1;unequip_quote={}
		refresh_unequip_quote.call_deferred(quote_generation,quote_context)
	var split=HBoxContainer.new();split.name="WarehouseColumns";split.custom_minimum_size.y=ui.mock_shell.content_height();split.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;split.add_theme_constant_override("separation",16);parent.add_child(split)
	var loadout=Loadout.new()
	split.add_child(loadout)
	loadout.build(ui,member,tab,set_tab,"WarehouseTab_",busy())
	if tab=="equipment":
		loadout.equipment(ui,member,equipped.get("equipped_slot",""),"WarehouseSlot_",select_equipment,Callable(),busy())
	else:
		var inventory=loadout.inventory_overlay()
		inventory.name="WarehouseCharacter"
		render_list(inventory,"character",member)
	var panel=PanelContainer.new();panel.name="WarehouseSelectedPanel";panel.custom_minimum_size.x=440;panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_child(panel)
	var details=VBoxContainer.new();details.name="WarehouseSelectedItem";details.add_theme_constant_override("separation",16);panel.add_child(details)
	ui.label_(details,"選択アイテム").name="WarehouseHeading"
	var selected=equipped if source=="equipped" else selected_row();var q=quote(source,item_id)
	if selected.is_empty():
		var hint=ui.label_(details,"アイテムを選択すると詳細が表示されます")
		hint.add_theme_font_size_override("font_size",16)
		hint.size_flags_vertical=Control.SIZE_EXPAND_FILL
		hint.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	else:
		var content=ui.scroller(details);content.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
		if source=="equipped":pages.describe_gear(content,selected,true)
		else:render_item_detail(content,selected)
		if source!="equipped":ui.label_(content,"×%d" % int(selected.get("count",0)))
		var reason_text=str(unequip_quote.get("reason","確認中…")) if source=="equipped" else str(q.get("reason",""))
		var reason=ui.label_(details,error_message if not error_message.is_empty() else reason_text);reason.name="WarehouseReason";reason.add_theme_font_size_override("font_size",14)
	var controls=ui.row(details);controls.name="WarehouseControls";controls.alignment=BoxContainer.ALIGNMENT_END
	if source=="equipped":
		var remove=ui.button(controls,"装備を外す",unequip,busy() or not unequip_quote.get("ok",false));remove.name="WarehouseUnequip"
	elif not selected.is_empty():
		var move=ui.button(controls,"預ける" if source=="character" else "取り出す",request_transfer.bind(source,item_id),busy() or not q.get("ok",false));move.name="WarehouseTransfer";move.tooltip_text=str(q.get("reason",""))
	ui.button(controls,"戻る",pages.facility_entry.back,busy()).name="WarehouseReturn"
	var storage=ui.card(split)
	storage.name="WarehouseStorage"
	storage.get_parent().custom_minimum_size.x=420
	ui.label_(storage,"共通倉庫")
	render_list(storage,"warehouse",member)

func render_list(column: Control,side: String,member: Dictionary):
	var filter=Inventory.add_filter(ui,column,member,filters[side],set_filter.bind(side))
	filter.name="WarehouseFilter_"+side
	filter.disabled=busy()
	var body=ui.scroller(column);var scroll=body.get_parent();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.memory.watch(scroll,"warehouse_"+side+"_"+owner_id)
	column.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
	scroll.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
	for entry in rows(side):
		if not Inventory.matches(entry,filters[side]):continue
		var id=str(entry.id)
		var button=Inventory.add_row(ui,body,entry,choose.bind(side,id),side==source and id==item_id,busy())
		button.name="WarehouseItem_"+side+"_"+id
		if entry.get("overCapacity",false):button.tooltip_text+=" / 所持枠を超えています"
		button.set_drag_forwarding(func(_at):return drag(side,id),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
		ui.memory.key(button,"warehouse_item_"+side+"_"+id)
	if body.get_child_count()==0:ui.label_(body,"アイテムはありません").add_theme_font_size_override("font_size",16)
	ui.label_(column,"ここへドラッグして"+("預ける" if side=="warehouse" else "取り出す")).add_theme_font_size_override("font_size",14)
func request_transfer(side: String,id: String):
	if busy() or not available():return
	var entry={}
	for value in rows(side):
		if str(value.id)==id:entry=value;break
	if entry.is_empty():return
	var token=str(pages.c().get("inventoryToken",""))
	var recipient=owner_id
	var epoch=pages.epoch
	if int(entry.get("count",1))<=1:await transfer(side,id,1,token);return
	var amount=SpinBox.new();amount.name="WarehouseQuantity";amount.min_value=1;amount.max_value=int(entry.count);amount.value=1;amount.step=1;amount.custom_minimum_size.x=140
	ui.dialog.open("個数",func(body,actions):
		body.add_child(amount)
		ui.primary(ui.button(actions,"OK",func():
			var count=int(amount.value);ui.dialog.close(false)
			if recipient==owner_id and epoch==pages.epoch:transfer(side,id,count,token)))
		ui.local_button(actions,"キャンセル",ui.dialog.close))
func transfer_selected():
	await transfer(source,item_id,quantity,str(pages.c().get("inventoryToken","")))
func transfer(side: String,id: String,count: int,token: String):
	if busy() or not available() or token!=str(pages.c().get("inventoryToken","")):return
	pending=true
	var epoch=pages.epoch
	var owner=owner_id
	var reply=await ui.act("warehouseAction",[owner_id,id,"withdraw" if side=="warehouse" else "deposit",count,token])
	if epoch!=pages.epoch:return
	pending=false
	if reply is Dictionary and reply.get("ok",false) and available() and owner==owner_id:
		reveal_item("character" if side=="warehouse" else "warehouse",id)
	if not ui.closing:ui.render()
func reveal_item(side: String,id: String):
	clear_selection()
	if side=="character":tab="inventory"
	source=side;item_id=id
	if not Inventory.matches(selected_row(),filters[side]):filters[side]="all"
	ui.memory.request_focus("warehouse_item_"+side+"_"+id,true)
	reveal_destination.call_deferred(side,id,owner_id)

func reveal_destination(side: String,id: String,uid: String):
	# Memory restores both scroll offsets after layout. Reveal the row in the
	# outer viewport as well when the inner inventory list is already visible.
	await ui.get_tree().process_frame
	while not ui.memory.layout_ready:
		if not available() or ui.closing:return
		await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if not available() or uid!=owner_id or side!=source or id!=item_id:return
	var row=ui.find_child("WarehouseItem_"+side+"_"+id,true,false)
	var outer=ui.find_child("MemberWorkspaceScroll",true,false) as ScrollContainer
	if row==null or outer==null:return
	outer.ensure_control_visible(row)
	# Keep the destination heading in view when revealing an early list row.
	if row.position.y<100:outer.scroll_vertical=0

func current_quote_context() -> Array:
	return [owner_id,item_id,equipped.get("equipped_slot",""),pages.c().get("inventoryToken"),pages.epoch,ui.engine.connection_generation]

func quote_is_current(ticket: int,context: Array) -> bool:
	return available() and source=="equipped" and ticket==quote_generation and context==current_quote_context()

func refresh_unequip_quote(ticket: int,context: Array):
	while ui.engine.busy:
		if not quote_is_current(ticket,context):return
		await ui.get_tree().process_frame
	if not quote_is_current(ticket,context):return
	var args=[context[0],context[1],"unequip",null,1,context[2]]
	var response=await ui.engine.request({"op":"campaign","action":"inventoryQuote","args":args})
	if not quote_is_current(ticket,context):return
	var q=response.get("inventoryQuote",{})
	if q.get("token")==context[3] and q.get("ownerId")==context[0] and q.get("itemId")==context[1] and q.get("slot")==context[2]:
		unequip_quote=q
	else:unequip_quote={"ok":false,"reason":"装備の状態を確認できませんでした"}
	ui.render()

func unequip():
	if busy() or not quote_is_current(quote_generation,quote_context) or not unequip_quote.get("ok",false):return
	var context=quote_context
	var ticket=quote_generation
	pending=true
	var args=[owner_id,item_id,"unequip",null,1,equipped.equipped_slot,unequip_quote.token]
	var reply=await ui.act("inventoryAction",args)
	if pages.epoch!=context[4]:return
	pending=false
	if available() and owner_id==context[0] and ticket==quote_generation and context[5]==ui.engine.connection_generation:
		if reply is Dictionary and reply.get("ok",false):reveal_item("character",context[1])
		else:error_message="装備を外せませんでした"
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
