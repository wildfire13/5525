extends RefCounted
## Session-only selection. Ownership changes atomically in the campaign bridge.
const Inventory=preload("res://member_inventory.gd")
const Loadout=preload("res://member_loadout_column.gd")
const Tokens=preload("res://ui_tokens.gd")
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
var ledger_panel: Control
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
	# Re-selecting the active source still clears its item/quantity/error state.
	if filters.get(side)==value and source!=side:return
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
	source=side;item_id=id;quantity=1
	if side=="warehouse" and is_instance_valid(ledger_panel) and ledger_panel.is_inside_tree():
		# The ledger checks its recipient and inventory token before updating the row.
		if ledger_panel.get_meta("select_row").call(id):return
	ui.render()
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
	var split=ui.mock_shell.columns(parent);split.name="WarehouseColumns";split.custom_minimum_size.y=ui.mock_shell.content_height()
	split.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	var loadout=Loadout.new()
	split.add_child(loadout)
	loadout.build(ui,member,tab,set_tab,"WarehouseTab_",busy(),true,true)
	if tab=="equipment":
		loadout.equipment(ui,member,equipped.get("equipped_slot",""),"WarehouseSlot_",select_equipment,Callable(),busy())
	elif tab=="inventory":
		var inventory=loadout.inventory_overlay()
		inventory.name="WarehouseCharacter"
		render_list(inventory,"character",member)
	elif tab=="ability":
		var overlay=loadout.inventory_overlay()
		var pad=MarginContainer.new();pad.size_flags_vertical=Control.SIZE_EXPAND_FILL;pad.add_theme_constant_override("margin_left",Tokens.SPACE_SM);pad.add_theme_constant_override("margin_right",Tokens.SPACE_SM);pad.add_theme_constant_override("margin_top",Tokens.SPACE_SM);overlay.add_child(pad)
		var values=ui.scroller(pad)
		values.get_parent().name="WarehouseAbilityValues"
		ui.label_(values,str(member.name)+" / Lv."+str(int(member.level)),true)
		pages.party_view.workspace.ability(values,member,false)
	elif tab=="skills":
		var overlay=loadout.inventory_overlay()
		var pad=MarginContainer.new();pad.size_flags_vertical=Control.SIZE_EXPAND_FILL;pad.add_theme_constant_override("margin_left",Tokens.SPACE_SM);pad.add_theme_constant_override("margin_right",Tokens.SPACE_SM);pad.add_theme_constant_override("margin_top",Tokens.SPACE_SM);overlay.add_child(pad)
		var skill_list=VBoxContainer.new();skill_list.name="WarehouseSkillList";skill_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;pad.add_child(skill_list)
		pages.party_view.workspace.skills(skill_list,member,"WarehouseSkill_")
	if source not in ["character","equipped"]:
		render_ledger(split,member)
		return
	var panel=PanelContainer.new();panel.name="WarehouseSelectedPanel";panel.custom_minimum_size.x=440;panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_child(panel)
	panel.add_theme_stylebox_override("panel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_NONE))
	var details=VBoxContainer.new();details.name="WarehouseSelectedItem";details.add_theme_constant_override("separation",Tokens.SPACE_NONE);panel.add_child(details)
	var selected_heading=ui.label_(details,"選択アイテム");selected_heading.name="WarehouseHeading"
	var selected_heading_style=StyleBoxFlat.new();selected_heading_style.bg_color=Color.TRANSPARENT;selected_heading_style.border_color=Tokens.BORDER;selected_heading_style.border_width_bottom=Tokens.BORDER_WIDTH;selected_heading_style.set_content_margin_all(Tokens.SPACE_SM);selected_heading.add_theme_stylebox_override("normal",selected_heading_style)
	var selected=equipped if source=="equipped" else selected_row();var q=quote(source,item_id)
	if selected.is_empty():
		var hint=ui.label_(details,"アイテムを選択すると詳細が表示されます")
		hint.add_theme_font_size_override("font_size",Tokens.FONT_SM)
		hint.size_flags_vertical=Control.SIZE_EXPAND_FILL
		hint.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	else:
		var content=ui.scroller(details);content.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
		var content_pad=StyleBoxEmpty.new();content_pad.content_margin_left=Tokens.SPACE_SM;content_pad.content_margin_right=Tokens.SPACE_SM;content_pad.content_margin_top=Tokens.SPACE_SM;content.get_parent().add_theme_stylebox_override("panel",content_pad)
		if source=="equipped":pages.describe_gear(content,selected,true)
		else:render_item_detail(content,selected)
		if source!="equipped":ui.label_(content,"×%d" % int(selected.get("count",0)))
		var reason_text=str(unequip_quote.get("reason","確認中…")) if source=="equipped" else str(q.get("reason",""))
		var reason=ui.label_(details,error_message if not error_message.is_empty() else reason_text);reason.name="WarehouseReason";reason.add_theme_font_size_override("font_size",Tokens.FONT_XS)
	var selected_divider=ColorRect.new();selected_divider.name="WarehouseSelectedFooterDivider";selected_divider.color=Tokens.BORDER;selected_divider.custom_minimum_size.y=Tokens.BORDER_WIDTH;selected_divider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selected_divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(selected_divider)
	var controls=ui.row(details);controls.name="WarehouseControls";controls.alignment=BoxContainer.ALIGNMENT_END
	controls.custom_minimum_size.y=ui.mock_shell.grid_cell().y
	if source=="equipped":
		var remove=ui.button(controls,"装備を外す",unequip,busy() or not unequip_quote.get("ok",false),"md");remove.name="WarehouseUnequip"
		remove.theme_type_variation=&"ActionButton"
	elif not selected.is_empty():
		var move=ui.button(controls,"預ける" if source=="character" else "取り出す",request_transfer.bind(source,item_id),busy() or not q.get("ok",false),"md");move.name="WarehouseTransfer";move.tooltip_text=str(q.get("reason",""))
		move.theme_type_variation=&"ActionButton"
	var back=ui.button(controls,"戻る",pages.facility_entry.back,busy(),"sm");back.name="WarehouseReturn"
	var ledger_back=ui.button(controls,"出庫台帳",func():clear_selection();ui.render(),busy(),"md");ledger_back.name="WarehouseLedgerReturn"
	var controls_pad=Control.new();controls_pad.custom_minimum_size.x=Tokens.SPACE_SM;controls_pad.mouse_filter=Control.MOUSE_FILTER_IGNORE;controls.add_child(controls_pad)
	split.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data,"warehouse"),func(_at,data):drop(data,"warehouse"))

func owned_count(id: String) -> int:
	for entry in rows("character"):
		if str(entry.id)==id:return int(entry.get("count",0))
	return 0

func render_ledger(parent: Control,member: Dictionary):
	var panel=PanelContainer.new();panel.name="WarehouseStorage";panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(panel)
	panel.add_theme_stylebox_override("panel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_NONE))
	ledger_panel=panel
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",Tokens.SPACE_NONE);panel.add_child(column)
	var ledger_head_margin=MarginContainer.new()
	for edge in ["left","right","top","bottom"]:ledger_head_margin.add_theme_constant_override("margin_"+edge,Tokens.SPACE_SM)
	column.add_child(ledger_head_margin)
	var ledger_head=VBoxContainer.new();ledger_head.add_theme_constant_override("separation",Tokens.SPACE_XS);ledger_head_margin.add_child(ledger_head)
	ui.label_(ledger_head,"出庫台帳 — "+str(member.get("name",owner_id)))
	var filter=Inventory.add_filter(ui,ledger_head,member,filters.warehouse,set_filter.bind("warehouse"))
	filter.name="WarehouseFilter_warehouse";filter.disabled=busy()
	var ledger_head_divider=ColorRect.new();ledger_head_divider.name="WarehouseLedgerHeaderDivider";ledger_head_divider.color=Tokens.BORDER;ledger_head_divider.custom_minimum_size.y=Tokens.BORDER_WIDTH;ledger_head_divider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ledger_head_divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(ledger_head_divider)
	var body=ui.scroller(column);body.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	var body_pad=StyleBoxEmpty.new();body_pad.content_margin_left=Tokens.SPACE_SM;body_pad.content_margin_right=Tokens.SPACE_SM;body_pad.content_margin_top=Tokens.SPACE_XS;body.get_parent().add_theme_stylebox_override("panel",body_pad)
	ui.memory.watch(body.get_parent(),"warehouse_warehouse_"+owner_id)
	var table=GridContainer.new();table.columns=4;table.size_flags_horizontal=Control.SIZE_EXPAND_FILL;table.add_theme_constant_override("h_separation",Tokens.SPACE_LG);table.add_theme_constant_override("v_separation",Tokens.SPACE_SM);body.add_child(table)
	for title in ["品名","倉庫",str(member.name)+"所持","取り出す数"]:
		var heading=ui.label_(table,title)
		heading.custom_minimum_size.x=148 if title!="品名" else 220
	var ledger_footer_divider=ColorRect.new();ledger_footer_divider.name="WarehouseLedgerFooterDivider";ledger_footer_divider.color=Tokens.BORDER;ledger_footer_divider.custom_minimum_size.y=Tokens.BORDER_WIDTH;ledger_footer_divider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ledger_footer_divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(ledger_footer_divider)
	var summary_margin=MarginContainer.new();summary_margin.add_theme_constant_override("margin_left",Tokens.SPACE_SM);summary_margin.add_theme_constant_override("margin_right",Tokens.SPACE_SM);summary_margin.add_theme_constant_override("margin_top",Tokens.SPACE_XS);column.add_child(summary_margin)
	var summary_box=VBoxContainer.new();summary_box.add_theme_constant_override("separation",Tokens.SPACE_NONE);summary_margin.add_child(summary_box)
	var summary=ui.label_(summary_box,"");summary.name="WarehouseBeforeAfter"
	var reason=ui.label_(summary_box,"");reason.name="WarehouseReason";reason.add_theme_font_size_override("font_size",Tokens.FONT_XS)
	var controls=ui.row(column);controls.alignment=BoxContainer.ALIGNMENT_END
	controls.name="WarehouseControls";controls.custom_minimum_size.y=ui.mock_shell.grid_cell().y
	var recipient=owner_id;var epoch=pages.epoch;var token=str(pages.c().get("inventoryToken",""))
	var withdraw=func():
		if recipient==owner_id and epoch==pages.epoch and source=="warehouse":transfer("warehouse",item_id,quantity,token)
	var confirm=ui.primary(ui.button(controls,"取り出す",withdraw,true),"md");confirm.name="WarehouseTransfer";confirm.size_flags_horizontal=Control.SIZE_SHRINK_END
	var back=ui.button(controls,"戻る",pages.facility_entry.back,busy(),"sm");back.name="WarehouseReturn"
	var ledger_controls_pad=Control.new();ledger_controls_pad.custom_minimum_size.x=Tokens.SPACE_SM;ledger_controls_pad.mouse_filter=Control.MOUSE_FILTER_IGNORE;controls.add_child(ledger_controls_pad)
	var update_footer=func():
		var selected=selected_row() if source=="warehouse" else {}
		var count=int(selected.get("count",0));var held=owned_count(item_id);var q=quote("warehouse",item_id)
		summary.text="品名と数量を選択してください" if selected.is_empty() else "%s  倉庫 %d → %d ／ 所持 %d → %d" % [str(selected.get("name",item_id)),count,count-quantity,held,held+quantity]
		confirm.text="取り出す" if selected.is_empty() else "%d個取り出す" % quantity
		confirm.disabled=busy() or selected.is_empty() or quantity<1 or quantity>count or not q.get("ok",false)
		confirm.set_meta("base_disabled",confirm.disabled)
		reason.text=error_message if not error_message.is_empty() else str(q.get("reason","")) if not selected.is_empty() else ""
	var visible_rows=0
	for entry in rows("warehouse"):
		if not Inventory.matches(entry,filters.warehouse):continue
		visible_rows+=1
		var id=str(entry.id);var count=int(entry.get("count",0))
		var button=Inventory.add_row(ui,table,entry,choose.bind("warehouse",id),source=="warehouse" and item_id==id,busy())
		button.text=str(entry.name)
		button.name="WarehouseItem_warehouse_"+id;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		ui.memory.key(button,"warehouse_item_warehouse_"+id)
		button.set_drag_forwarding(func(_at):return drag("warehouse",id),func(_at,data):return can_drop(data,"warehouse"),func(_at,data):drop(data,"warehouse"))
		ui.label_(table,str(count));ui.label_(table,str(owned_count(id)))
		var amount=SpinBox.new();amount.name="WarehouseQuantity_"+id;amount.min_value=0;amount.max_value=maxi(1,count);amount.step=1;amount.value=quantity if source=="warehouse" and item_id==id else 0;amount.custom_minimum_size.x=112;amount.size_flags_vertical=Control.SIZE_SHRINK_CENTER;amount.editable=not busy();table.add_child(amount)
		amount.value_changed.connect(func(value):
			if busy() or recipient!=owner_id or epoch!=pages.epoch or token!=str(pages.c().get("inventoryToken","")):return
			source="warehouse";item_id=id;quantity=int(value)
			for cell in table.get_children():
				if cell is SpinBox and cell!=amount:cell.set_value_no_signal(0)
				if cell is Button:ui.mark_selected(cell,cell==button)
			update_footer.call())
	if visible_rows==0:ui.label_(body,"アイテムはありません")
	var select_ledger_row=func(id):
		if recipient!=owner_id or epoch!=pages.epoch or token!=str(pages.c().get("inventoryToken","")):return false
		var selected_button=table.get_node_or_null("WarehouseItem_warehouse_"+id)
		if selected_button==null:return false
		for cell in table.get_children():
			if cell is SpinBox:cell.set_value_no_signal(1 if cell.name=="WarehouseQuantity_"+id else 0)
			if cell is Button:ui.mark_selected(cell,cell==selected_button)
		update_footer.call()
		return true
	panel.set_meta("select_row",select_ledger_row)
	panel.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data,"warehouse"),func(_at,data):drop(data,"warehouse"))
	update_footer.call()

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
	if body.get_child_count()==0:ui.label_(body,"アイテムはありません").add_theme_font_size_override("font_size",Tokens.FONT_SM)
	if source!="character":
		var hint_margin=MarginContainer.new();hint_margin.add_theme_constant_override("margin_left",Tokens.SPACE_SM);hint_margin.add_theme_constant_override("margin_right",Tokens.SPACE_SM);hint_margin.add_theme_constant_override("margin_top",Tokens.SPACE_XS);hint_margin.add_theme_constant_override("margin_bottom",Tokens.SPACE_SM);column.add_child(hint_margin)
		ui.label_(hint_margin,"ここへドラッグして"+("預ける" if side=="warehouse" else "取り出す")).add_theme_font_size_override("font_size",Tokens.FONT_XS)
func request_transfer(side: String,id: String):
	if busy() or not available():return
	var entry={}
	for value in rows(side):
		if str(value.id)==id:entry=value;break
	if entry.is_empty():return
	var token=str(pages.c().get("inventoryToken",""))
	var recipient=owner_id
	var epoch=pages.epoch
	if side=="character":
		if ui.modal_open() or not quote(side,id).get("ok",false):return
		var amount=SpinBox.new()
		amount.name="WarehouseQuantity";amount.min_value=1;amount.max_value=int(entry.count)
		var stored=int(pages.c().get("warehouse",{}).get(id,0))
		var submit=func():
			if recipient==owner_id and epoch==pages.epoch:transfer(side,id,int(amount.value),token)
		ui.facility_receipt("預け入れ明細",entry,ui.member_name(recipient),submit,func(body,d):
			d.name="WarehouseDepositConfirmation"
			var line=ui.row(body);ui.label_(line,"預ける数");line.add_child(amount)
			var personal=ui.receipt_line(body,ui.member_name(recipient)+"の所持数")
			var warehouse=ui.receipt_line(body,"共通倉庫の在庫")
			var update=func(value):
				var count=int(value)
				personal.text="%d → %d" % [entry.count,entry.count-count]
				warehouse.text="%d → %d" % [stored,stored+count]
				d.ok_button_text="%d個預ける" % count
			amount.value_changed.connect(update);update.call(amount.value)
			d.get_ok_button().name="WarehouseDepositConfirm"
			d.get_cancel_button().name="WarehouseDepositCancel")
		return
	if int(entry.get("count",1))<=1:await transfer(side,id,1,token);return
	var amount=SpinBox.new();amount.name="WarehouseQuantity";amount.min_value=1;amount.max_value=int(entry.count);amount.value=1;amount.step=1;amount.custom_minimum_size.x=140
	ui.dialog.open("個数",func(body,actions):
		body.add_child(amount)
		ui.primary(ui.button(actions,"OK",func():
			var count=int(amount.value);ui.dialog.close(false)
			if recipient==owner_id and epoch==pages.epoch:transfer(side,id,count,token)))
		ui.local_button(actions,"キャンセル",ui.dialog.close))
func transfer(side: String,id: String,count: int,token: String):
	if busy() or not available() or token!=str(pages.c().get("inventoryToken","")):return
	pending=true
	var epoch=pages.epoch
	var owner=owner_id
	var reply=await ui.act("warehouseAction",[owner_id,id,"withdraw" if side=="warehouse" else "deposit",count,token])
	if epoch!=pages.epoch:return
	pending=false
	if reply is Dictionary and reply.get("ok",false) and available() and owner==owner_id:
		if side=="warehouse" and source=="warehouse":
			if rows("warehouse").any(func(entry):return str(entry.id)==id):
				reveal_item("warehouse",id)
			else:
				clear_selection()
		else:
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
