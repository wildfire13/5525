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
	ui.label_(parent,"倉庫",true).name="WarehouseHeading"
	ui.label_(parent,"下の人物を選び、品物を選んで移動するか、反対側へドラッグしてください。")
	var split=HBoxContainer.new();split.name="WarehouseColumns";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",16);parent.add_child(split)
	for side in ["warehouse","character"]:
		var panel=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_child(panel)
		var style=StyleBoxFlat.new();style.bg_color=Color(0.08,0.10,0.14,0.82);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=8;style.content_margin_bottom=8;panel.add_theme_stylebox_override("panel",style)
		var column=VBoxContainer.new();column.name="WarehouseStorage" if side=="warehouse" else "WarehouseCharacter";column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(column)
		var title="倉庫（枠数制限なし）" if side=="warehouse" else ui.member_name(owner_id)+"のインベントリ"

		if side=="character":
			var capacity=pages.c().get("inventoryByCharacter",{}).get(owner_id,{}).get("capacity",{})
			title+="（%d / %s枠）" % [int(capacity.get("used",0)),"∞" if capacity.get("limit")==null else str(int(capacity.limit))]
		var heading=ui.label_(column,title,true);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.custom_minimum_size.x=0
		var body=ui.scroller(column);var scroll=body.get_parent();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ui.memory.watch(scroll,"warehouse_"+side+("_"+owner_id if side=="character" else ""))
		column.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
		scroll.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
		for entry in rows(side):
			var id=str(entry.id);var selected=side==source and id==item_id
			var button=ui.button(body,("● " if selected else "")+str(entry.name)+" ×"+str(int(entry.count)),choose.bind(side,id),busy());button.name="WarehouseItem_"+side+"_"+id;button.clip_text=true;button.tooltip_text=str(entry.name);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			if selected:pages.party_view.tint(button,Color("#605025"))
			elif entry.get("overCapacity",false):pages.party_view.tint(button,Color("#683b40"));button.text="枠超過・"+button.text
			button.set_drag_forwarding(func(_at):return drag(side,id),func(_at,data):return can_drop(data,side),func(_at,data):drop(data,side))
			ui.memory.key(button,"warehouse_item_"+side+"_"+id)
		if rows(side).is_empty():ui.label_(body,"品物はありません")
	var controls=ui.row(parent);controls.name="WarehouseControls"
	var selected=selected_row();var q=quote(source,item_id)
	var caption=ui.label_(controls,str(selected.get("name","移動する品物を選んでください")));caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var amount=SpinBox.new();amount.name="WarehouseQuantity";amount.min_value=1;amount.max_value=maxi(1,int(selected.get("count",1)));quantity=mini(quantity,int(amount.max_value));amount.value=quantity;amount.step=1;amount.editable=not busy() and not selected.is_empty();amount.custom_minimum_size.x=130;controls.add_child(amount);amount.value_changed.connect(func(value):quantity=int(value))
	var move=ui.button(controls,"← 預ける" if source=="character" else "取り出す →",transfer_selected,busy() or selected.is_empty() or not q.get("ok",false));move.name="WarehouseTransfer";move.custom_minimum_size.x=160
	ui.label_(parent,str(q.get("reason",""))).name="WarehouseReason"
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
	await transfer(str(data.side),str(data.id),int(data.count),str(data.token))
