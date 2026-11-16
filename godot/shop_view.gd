extends RefCounted
## Payment consent and recipient choice are session-only; Campaign commits once.
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var stage := "S0"
var unknown := false
var quote_worker := false
var background: Array[String]=[]
var return_from_party := false
var from_party := false
var filter_slot := "all"
var filter_location := ""
var generation := 0
var message := ""
var consent: Dictionary={}
var receipt: Dictionary={}
var transaction: Dictionary={}
var comparison_view
var sale
var inventory_tab := "inventory"
var selection_kind := ""
var selected_equipment: Dictionary={}
var purchase_quantity := 1
var inventory_column: Control
var catalog_column: Control
var transaction_column: Control
func _init(owner):owner_ref=weakref(owner);ui=owner.ui;sale=preload("res://facility_sale.gd").new(self);comparison_view=preload("res://shop_comparison.gd").new(self)
func c() -> Dictionary:return pages.c()
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func busy() -> bool:return stage!="S0" or unknown or ui.locked or ui.presenting or ui.closing or ui.engine.disconnected or sale.busy()
func reset(_plan_mode: String="discard",_campaign_id: String=""):
	if comparison_view!=null:comparison_view.invalidate()
	stage="S0";unknown=false;consent={};receipt={};transaction={};message="";generation+=1;sale.reset()
	filter_slot="all";filter_location="";background.clear();return_from_party=false;from_party=false;inventory_tab="inventory";selection_kind="";selected_equipment={}
	if ui.dialog!=null:ui.dialog.close(false)
func slots() -> Array:
	return ["rightHand","leftHand"] if c().get("location")=="east" else ["accessory1","accessory2"] if c().get("location")=="north" else ["head","upperBody","lowerBody","feet"]
const WEAPON_NAMES={"sword":"剣","greatsword":"両手剣","spear":"槍","bow":"弓","hammer":"槌","staff":"杖","shield":"盾","dagger":"短剣","book":"本","gun":"銃","fist":"拳","rope":"鉤縄"}
func offered() -> Array:
	# Legacy slot-specific IDs stay valid in owned inventories and save files.
	# Only the canonical product is offered for new purchases.
	return c().get("shop",[]).filter(func(g):
		if g.get("shopProductId",g.id)!=g.id:return false
		if g.get("type")=="empty":return false
		if filter_slot=="all":return true
		if c().get("location")=="east":return g.get("type","")==filter_slot
		if c().get("location")=="south":return g.id==filter_slot
		var allowed=g.get("allowedSlots",["rightHand"] if g.get("hands",1)==2 else ["rightHand","leftHand"] if g.slot=="weapon" else ["upperBody"] if g.slot=="armor" else [g.slot])
		return allowed.has(filter_slot))
func product_filter(parent):
	if filter_location!=str(c().get("location","")):filter_location=str(c().get("location",""));filter_slot="all"
	var options=[]
	if c().get("location") in ["east","south"]:
		var seen={}
		for item in c().get("shop",[]):
			if item.get("type")=="empty":continue
			var id=str(item.get("type","")) if c().location=="east" else str(item.id)
			if seen.has(id):continue
			seen[id]=true;options.append([id,str(WEAPON_NAMES.get(id,id)) if c().location=="east" else str(item.name),ui.icons.WEAPONS.get(id,"items") if c().location=="east" else id])
	elif c().get("location")=="north":
		options.append(["accessory1","装飾品","accessory"])
	else:
		for id in slots():options.append([id,str(c().get("slots",{}).get(id,id)),ui.icons.slot(id)])
	var slot=OptionButton.new();slot.name="ShopSlotFilter";slot.custom_minimum_size=Vector2(280,44);slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL;slot.fit_to_longest_item=false;slot.clip_text=true;parent.add_child(slot)
	slot.add_item("すべて");slot.set_item_metadata(0,"all")
	for option in options:
		slot.add_icon_item(ui.icons.texture(option[2]),str(option[1]));slot.set_item_metadata(slot.item_count-1,option[0])
		if filter_slot==option[0]:slot.select(slot.item_count-1)
	slot.add_theme_constant_override("icon_max_width",24);slot.disabled=busy()
	slot.item_selected.connect(func(i):select_slot(str(slot.get_item_metadata(i))));ui.memory.key(slot,"shop_filter")
func sale_mode() -> bool:
	return ui.page=="shop" and pages.facility_entry.view!="top" and c().get("phase")=="town"
func selected_owner() -> String:return ui.shop_uid if sale_mode() else ""
func owner_pressed(uid: String) -> bool:
	if not sale_mode():return false
	if busy() or ui.modal_open():return true
	if not c().get("selected",[]).has(uid):return true
	ui.shop_uid=uid;pages.party_uid=uid;sale.apply_owner(uid);selected_equipment={}
	if comparison_view!=null:comparison_view.invalidate()
	if selection_kind!="buy":selection_kind=""
	ui.render();return true
func render(parent):
	if not c().get("selected",[]).has(ui.shop_uid):
		ui.shop_uid=str(c().get("selected",[""])[0])
	if sale.owner_id!=ui.shop_uid:sale.apply_owner(ui.shop_uid)
	var layout=HBoxContainer.new();layout.name="ShopWorkspace";layout.add_theme_constant_override("separation",16);layout.custom_minimum_size.y=ui.mock_shell.content_height();layout.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;parent.add_child(layout)
	var column=preload("res://member_loadout_column.gd").new()
	layout.add_child(column)
	inventory_column=column
	render_inventory_column(column)
	var middle=make_panel(layout,"ShopTransaction",0)
	transaction_column=middle
	var stock=make_panel(layout,"ShopCatalog",440)
	catalog_column=stock
	backdrop(stock,pages.facility_art.npc.texture,"ShopKeeperArt")
	render_transaction(middle,stock)
	render_catalog(stock)
func render_inventory_column(column):
	var person={}
	for member in ui.roster():
		if member.id==ui.shop_uid:person=member;break
	column.build(ui,person,inventory_tab,set_inventory_tab,"ShopInventoryTab_",busy())
	column.panel.name="ShopInventory"
	column.portrait.name="ShopCustomerArt"
	if inventory_tab=="equipment":
		var slot=selected_equipment.get("equipped_slot","") if selection_kind=="equipment" else ""
		column.equipment(ui,person,slot,"ShopEquipped_",select_equipment,Callable(),busy())
	else:
		var overlay=column.inventory_overlay()
		var filter=preload("res://member_inventory.gd").add_filter(ui,overlay,person,sale.inventory_filter,sale.change_filter)
		filter.name="ShopInventoryFilter"
		filter.disabled=busy()
		var inventory=ui.scroller(overlay)
		inventory.get_parent().name="ShopInventoryScroll"
		ui.memory.watch(inventory.get_parent(),"shop_inventory_"+inventory_tab)
		sale.render_inventory(inventory)
func render_transaction(middle,stock):
	l(middle,"購入" if selection_kind=="buy" else "売却" if selection_kind=="sell" else "取引を確認").name="ShopTransactionHeading"
	var detail=ui.scroller(middle);detail.get_parent().name="ShopTransactionScroll"
	render_notice(detail)
	var footer=ui.row(middle);footer.name="ShopTransactionFooter";footer.alignment=BoxContainer.ALIGNMENT_END
	if selection_kind=="sell":
		stock.get_parent().hide()
		sale.render_detail(detail,footer)
		b(footer,"商品一覧へ",func():selection_kind="";ui.render(),busy())
	elif selection_kind=="equipment":
		if not selected_equipment.is_empty():
			pages.describe_gear(detail,selected_equipment)
	elif selection_kind=="buy" and not pages.gear_id.is_empty():
		if c().get("location")=="south":render_consumable_selection(detail,footer)
		else:
			if comparison_view==null:comparison_view=preload("res://shop_comparison.gd").new(self)
			comparison_view.render_inline(detail,footer,pages.gear_id,ui.shop_uid)
	else:l(detail,"商品またはインベントリのアイテムを選択")
	var finish=b(footer,"取引終了",finish_trading,busy());finish.name="ShopExit";finish.custom_minimum_size.y=40;finish.size_flags_horizontal=Control.SIZE_SHRINK_END
func render_catalog(stock):
	l(stock,"商品リスト").name="ShopCatalogHeading";product_filter(stock)
	var products=ui.scroller(stock);products.get_parent().name="ShopProductsScroll";ui.memory.watch(products.get_parent(),"shop_products")
	sync_product_rows(products)

func sync_product_rows(products: Control):
	var items=offered()
	var visible_ids={}
	for index in range(items.size()):
		var item=items[index]
		var key="Product_"+str(item.id)
		var control=products.get_node_or_null(key)
		if control==null:
			render_product(products,item)
			control=products.get_node(key)
		visible_ids[key]=true
		if control.get_index()!=index:products.move_child(control,index)
	for control in products.get_children():
		control.visible=visible_ids.has(str(control.name))
	if items.is_empty():
		var empty=products.get_node_or_null("EmptyStock")
		if empty==null:
			empty=l(products,"販売品はありません")
			empty.name="EmptyStock"
		empty.show()

func make_panel(parent: Control,node_name: String,width: float) -> VBoxContainer:
	var panel=PanelContainer.new();panel.name=node_name;panel.custom_minimum_size.x=width;panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL if width==0 else Control.SIZE_FILL
	var style=StyleBoxFlat.new();style.bg_color=Color("#faf9f5");style.border_color=Color("#cbd0c7");style.set_border_width_all(1);style.set_corner_radius_all(3);style.set_content_margin_all(12);panel.add_theme_stylebox_override("panel",style);parent.add_child(panel)
	var body=VBoxContainer.new();body.add_theme_constant_override("separation",12);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(body)
	return body
func backdrop(body: Control,texture: Texture2D,node_name: String):
	if texture==null:return
	var image=TextureRect.new();image.name=node_name;image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.modulate.a=.2;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# A plain Control is outside the VBox flow, so artwork never changes row sizes.
	var layer=Control.new();layer.name=node_name+"Layer";layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.get_parent().add_child(layer);body.get_parent().move_child(layer,0);layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);
	layer.add_child(image);image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);image.offset_top=64;image.offset_bottom=-8
func list_surface(button: Button,selected: bool):
	ui.mark_selected(button,false)
	for state_ in ["normal","hover","pressed","disabled"]:
		var style=button.get_theme_stylebox(state_).duplicate() as StyleBoxFlat
		style.bg_color=Color("#e0e8dd") if selected or state_ in ["hover","pressed"] else Color(0.98,0.976,0.96,.65)
		button.add_theme_stylebox_override(state_,style)
	if selected:ui.mark_selected(button,true)
func set_inventory_tab(value: String):
	if busy() or value==inventory_tab:return
	inventory_tab=value
	if not is_instance_valid(inventory_column) or not inventory_column.is_inside_tree():
		ui.render();return
	ui.refresh_panel(func():
		ui.clear(inventory_column)
		render_inventory_column(inventory_column))
func render_product(parent: Control,item: Dictionary):
	var choose=b(parent,"",open_comparison.bind(str(item.id)),busy());choose.name="Product_"+str(item.id);choose.custom_minimum_size=Vector2(0,68);choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var margin=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;choose.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.add_theme_constant_override("margin_left",8);margin.add_theme_constant_override("margin_right",8)
	var line=HBoxContainer.new();line.add_theme_constant_override("separation",8);line.mouse_filter=Control.MOUSE_FILTER_IGNORE;margin.add_child(line)
	ui.icons.add(line,str(item.id) if c().location=="south" else ui.icons.equipment(item),36)
	var title=l(line,str(item.name));title.add_theme_font_size_override("font_size",18);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.autowrap_mode=TextServer.AUTOWRAP_OFF;title.clip_text=true;choose.tooltip_text=str(item.name)
	var values=VBoxContainer.new()
	values.mouse_filter=Control.MOUSE_FILTER_IGNORE
	values.alignment=BoxContainer.ALIGNMENT_CENTER
	values.add_theme_constant_override("separation",0)
	line.add_child(values)
	var price=l(values,"%dG" % int(item.price))
	var weight=l(values,"Wt %s" % (str(item.weight) if item.get("weight")!=null else "不明"))
	price.add_theme_font_size_override("font_size",18)
	weight.add_theme_font_size_override("font_size",16)
	for label in [price,weight]:
		label.autowrap_mode=TextServer.AUTOWRAP_OFF
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	list_surface(choose,selection_kind=="buy" and pages.gear_id==str(item.id));ui.memory.key(choose,"product_"+str(item.id))
	preload("res://item_drag.gd").source(choose,func():
		if busy():return null
		return {"kind":"shop_product","item":str(item.id),"connection":ui.engine.connection_generation,"token":c().get("inventoryToken"),"epoch":pages.epoch},str(item.name),ui.icons.texture(str(item.id) if c().location=="south" else ui.icons.equipment(item)))
func select_equipment(gear: Dictionary):
	if busy():return
	selection_kind="equipment";selected_equipment=gear;sale.item_id="";ui.render()
func checkout_fields(actions: Control,unit_price: int,changed: Callable) -> Label:
	var total=actions.get_parent()
	var quantity_line=ui.row(total)
	total.move_child(quantity_line,actions.get_index())
	var caption=ui.label_(quantity_line,"購入数")
	caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	caption.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var quantity=SpinBox.new();quantity.name="ShopPurchaseQuantity";quantity.min_value=1;quantity.max_value=99;quantity.value=purchase_quantity;quantity_line.add_child(quantity)
	ui.label_(quantity_line,"単価 %d G" % unit_price)
	quantity.value_changed.connect(func(value):
		purchase_quantity=int(value)
		changed.call())
	var money=ui.icons.line(ui,actions.get_parent(),"money","費用を確認中…");money.name="ShopComparisonPayment"
	actions.get_parent().move_child(money.get_parent(),actions.get_index())
	return money

func display_payment(money: Label,buy: Button,cost: Dictionary):
	money.text="所持金 %dG − 購入 %dG = 残金 %dG" % [cost.goldBefore,cost.cost,cost.afterGold] if cost.get("ok",false) else "購入不可："+str(cost.reason)+" / 価格 %dG / 所持金 %dG" % [cost.cost,cost.goldBefore]
	money.add_theme_color_override("font_color",Color("#29332f") if cost.get("ok",false) else Color("#a84432"))
	buy.text="%d個の購入へ" % cost.count
	buy.disabled=not cost.get("ok",false) or busy();buy.set_meta("base_disabled",buy.disabled)
	buy.tooltip_text="購入品はインベントリへ入ります。" if not buy.disabled else str(cost.get("reason","購入できません"))
	for state in ["normal","hover","pressed","disabled"]:
		var style=StyleBoxFlat.new();style.bg_color=Color("#33594b") if not buy.disabled else Color("#e8e9e3");style.set_corner_radius_all(5);style.set_content_margin_all(8);buy.add_theme_stylebox_override(state,style)
	buy.add_theme_color_override("font_disabled_color",ui.mock_shell.MUTED_INK)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:buy.add_theme_color_override(key,Color.WHITE)
func consumable_payment(item: Dictionary,uid: String) -> Dictionary:
	var bag: Dictionary=c().characters[uid].inventory
	var capacity: Dictionary=c().inventoryByCharacter[uid].capacity
	var total=int(c().inventoryTotals.get(item.id,0))+int(c().get("warehouse",{}).get(item.id,0))
	var cost=int(item.price)*purchase_quantity
	var reason=""
	if cost>int(c().gold):reason="所持金が不足しています"
	elif total+purchase_quantity>99:reason="所持数の上限を超えます"
	elif capacity.limit!=null and int(capacity.used)+(0 if bag.has(item.id) else 1)>int(capacity.limit):
		reason="選択した人物のインベントリに空きがありません"
	return {"ok":reason.is_empty(),"reason":reason,"count":purchase_quantity,"cost":cost,"goldBefore":c().gold,"afterGold":int(c().gold)-cost}

func render_consumable_selection(parent: Control,actions: Control):
	var items=c().get("shop",[]).filter(func(item):return item.id==pages.gear_id)
	if items.is_empty():return
	var item=items[0]
	var title=ui.icons.line(ui,parent,str(item.id),str(item.name),true)
	title.add_theme_font_size_override("font_size",28)
	var definitions=c().get("itemDefinitions",[]).filter(func(entry):return entry.id==item.id)
	if not definitions.is_empty():
		var definition=definitions[0]
		l(parent,"%sを%d回復" % [str(definition.resource).to_upper(),definition.amount])
	var uid: String=ui.shop_uid
	var held=int(c().characters[uid].inventory.get(item.id,0))
	var owned=l(parent,"")
	owned.name="ShopRecipientStock"
	var buy=b(actions,"購入へ",confirm_purchase.bind(str(item.id),uid),true)
	buy.name="ProductBuy_"+str(item.id)+"_1"
	buy.size_flags_horizontal=Control.SIZE_SHRINK_END
	buy.custom_minimum_size.y=40
	var update=func():
		owned.text="%sの所持数　%d → %d個" % [ui.member_name(uid),held,held+purchase_quantity]
		display_payment(actions.get_parent().find_child("ShopComparisonPayment",true,false),buy,consumable_payment(item,uid))
	checkout_fields(actions,item.price,update)
	update.call()

func finish_trading():
	if busy() or ui.modal_open():return
	if comparison_view!=null:comparison_view.invalidate()
	pages.gear_id="";selection_kind="";selected_equipment={};sale.reset();consent={};receipt={};transaction={};message=""
	pages.facility_entry.back()
func product_summary(item: Dictionary) -> String:
	var parts=[]
	if item.get("atk",0)>0:parts.append("ATK %d / 通常射程%d" % [item.atk,item.get("reach",0)])
	for pair in [["hp","HP"],["mp","MP"],["agiBonus","行動速度"]]:
		if item.get(pair[0],0)!=0:parts.append("%s %+d" % [pair[1],item[pair[0]]])
	return " / ".join(parts) if not parts.is_empty() else "補正なし"
func open_comparison(id: String):
	if busy() or ui.modal_open():return
	var previous_product=pages.gear_id
	var was_buy=selection_kind=="buy"
	selection_kind="buy";pages.gear_id=id;purchase_quantity=1;sale.item_id="";sale.quote={};sale.generation+=1;sale.previewing=false
	if comparison_view!=null:comparison_view.invalidate()
	if not was_buy or not is_instance_valid(transaction_column) or not transaction_column.is_inside_tree() or not is_instance_valid(catalog_column) or not catalog_column.is_inside_tree():
		ui.render();return
	ui.refresh_panel(func():
		ui.clear(transaction_column)
		render_transaction(transaction_column,catalog_column)
		if previous_product!=id:
			for product in [previous_product,id]:
				var control=catalog_column.find_child("Product_"+str(product),true,false)
				if control!=null:list_surface(control,product==id))
func render_notice(parent):
	if message.is_empty():return
	var notice=l(parent,message);notice.name="ShopNotice";notice.add_theme_color_override("font_color",Color("#a44a35"))
func record_sale(q: Dictionary):
	transaction={"kind":"sell","ownerId":q.ownerId,"text":"%sの%s×%dを売却 / 受取%dG" % [q.ownerName,q.name,q.count,q.proceeds]};message="";ui.save_notice.display(str(transaction.text))
func render_recipient(parent):
	if not c().get("selected",[]).has(ui.shop_uid):ui.shop_uid=str(c().selected[0])
	var line=ui.row(parent);l(line,"購入品の受取人")
	var recipient=OptionButton.new();recipient.name="ConsumableRecipient";recipient.custom_minimum_size=Vector2(180,44);line.add_child(recipient)
	for uid in c().get("selected",[]):
		recipient.add_item(ui.member_name(str(uid)));recipient.set_item_metadata(recipient.item_count-1,uid)
		if uid==ui.shop_uid:recipient.select(recipient.item_count-1)
	recipient.item_selected.connect(func(i):if not busy():ui.shop_uid=str(recipient.get_item_metadata(i));ui.render())
func consumable_row(parent,item: Dictionary):
	var line=ui.row(parent);line.name="ProductRow_"+str(item.id);line.custom_minimum_size.y=64
	var label=b(line,str(item.name),show_consumable_details.bind(str(item.id)),busy());label.name="Product_"+str(item.id);label.alignment=HORIZONTAL_ALIGNMENT_LEFT;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.custom_minimum_size=Vector2(240,64);ui.icons.apply(label,str(item.id));ui.memory.key(label,"product_"+str(item.id))
	preload("res://item_drag.gd").source(label,func():
		if busy():return null
		return {"kind":"shop_product","item":str(item.id),"connection":ui.engine.connection_generation,"token":c().get("inventoryToken"),"epoch":pages.epoch},str(item.name),label.icon)
	var price=l(line,"%dG" % int(item.price));price.name="ProductPrice_"+str(item.id);price.custom_minimum_size.x=96;price.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;price.autowrap_mode=TextServer.AUTOWRAP_OFF
	for amount in [1,5]:
		var cost=int(item.price)*amount;var full=int(c().get("inventoryTotals",{}).get(item.id,0))+amount>99
		var result_text="上限99個" if full else "所持金不足" if int(c().gold)<cost else "残金 %dG" % (int(c().gold)-cost)
		var button=b(line,"%d個 / %dG\n%s" % [amount,cost,result_text],purchase_consumable.bind(str(item.id),amount),busy() or int(c().gold)<cost or full);button.name="ProductBuy_"+str(item.id)+"_"+str(amount);button.custom_minimum_size=Vector2(130 if amount==1 else 170,64)
		button.tooltip_text=ui.member_name(ui.shop_uid)+"へ / "+("上限99個" if full else "所持金不足" if int(c().gold)<cost else "購入後 %dG" % (int(c().gold)-cost))
func purchase_consumable(id: String,count: int):
	if busy() or count not in [1,5] or not c().get("selected",[]).has(ui.shop_uid):return
	var item=offered().filter(func(v):return v.id==id)
	if item.is_empty():return
	var owner=ui.shop_uid;var token=c().get("inventoryToken");generation+=1;var ticket=generation;stage="S5"
	var reply=await ui.update({"op":"campaign","action":"buyItem","args":[id,count,owner,token]})
	if ticket!=generation:return
	unknown=reply.get("connection_lost",false);stage="S7" if unknown else "S0"
	if reply.get("ok",false):
		transaction={"kind":"buy","ownerId":owner,"text":"%sへ %s×%d / 支払%dG" % [ui.member_name(owner),item[0].name,count,int(item[0].price)*count]};message="";ui.save_notice.display(str(transaction.text))
	else:message=str(reply.get("error","購入結果を確認してください。"))
	ui.render()
func configure_tooltip(button,item: Dictionary):
	button.set_script(preload("res://equipment_tooltip.gd"))
	button.configure(str(item.name),item,{"names":c().get("skillNames",{}),"definitions":c().get("skillDefinitions",{}),"title_size":24 if ui.size.x>=1800 else 20,"detail_size":18 if ui.size.x>=1800 else 16})
func cancel_pending():
	# Quotes are pure; an in-flight committed purchase must not be discarded here.
	if stage!="S1":return
	generation+=1;stage="S0";consent={}
func valid_ticket(ticket: int,epoch: int,connection: int,place: String) -> bool:
	if ticket!=generation or epoch!=pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return false
	if ui.page!="shop" or c().get("phase")!="town" or str(c().get("location"))!=place or stage=="S1" and (ui.modal_open() or ui.locked):
		cancel_pending();return false
	return true
func cancel_purchase(ticket: int):
	if ticket!=generation or stage=="S5":return
	generation+=1;consent={};stage="S0";ui.render()
func confirm_purchase(id: String="",recipient: String="",count: int=1):
	if busy() or id.is_empty():return
	if not recipient.is_empty() and not c().get("selected",[]).has(recipient):return
	if c().get("location")=="south":
		confirm_consumable(id,recipient);return
	stage="S1";generation+=1;var ticket=generation;var epoch=pages.epoch;var connection=ui.engine.connection_generation;var place=str(c().get("location"))
	var reply=await ui.engine.request({"op":"campaign","action":"purchaseQuote","args":[id,null if recipient.is_empty() else recipient,count]})
	if not valid_ticket(ticket,epoch,connection,place):return
	if reply.get("connection_lost",false):unknown=true;stage="S7";message="接続が失われました。購入は確定していません。";ui.handle_connection_loss(reply,connection);return
	var q: Dictionary=reply.get("purchaseQuote",{})
	if not reply.get("ok",false) or not q.get("ok",false):stage="S0";message=str(q.get("reason",reply.get("error","購入できません")));ui.render();return
	consent=q.duplicate(true);stage="S4"
	ui.dialog.open("購入の確認",func(body,actions):
		l(body,"%s / %d個" % [q.gear.name,q.count],true)
		l(body,"支払 %dG / 所持金 %d → %dG" % [q.cost,q.goldBefore,q.afterGold],true).name="PurchasePayment"
		l(body,ui.member_name(recipient)+"のインベントリへ購入しますか？" if not recipient.is_empty() else "購入しますか？ 同意後に受取人を選びます。自動装備はしません。")
		b(actions,"キャンセル",ui.dialog.close).name="PurchaseDecline"
		ui.primary(b(actions,"購入する",func():
			if ticket!=generation or stage!="S4":return
			ui.dialog.close(false);stage="S9"
			if recipient.is_empty():choose_recipient(ticket)
			else:buy(q,recipient,ticket))).name="PurchaseAgree",
		cancel_purchase.bind(ticket))
func choose_recipient(ticket: int):
	if ticket!=generation or stage!="S9":return
	ui.dialog.open("受取人の選択",func(body,actions):
		l(body,str(consent.gear.name)+" / 1個",true)
		l(body,"支払 %dG / 所持金 %d → %dG" % [consent.cost,consent.goldBefore,consent.afterGold]).name="RecipientPayment"
		l(body,"誰のインベントリに入れますか？ 受取確定まで所持金は減りません。")
		for person in ui.roster():
			if not c().get("selected",[]).has(person.id):continue
			var line=ui.row(body);ui.portrait(line,person,false,56)
			b(line,str(person.name)+"のインベントリへ",buy.bind(consent.duplicate(true),str(person.id),ticket)).name="PurchaseRecipient_"+str(person.id)
		b(actions,"取り消す",ui.dialog.close).name="PurchaseRecipientCancel",
		cancel_purchase.bind(ticket))
func buy(q: Dictionary,uid: String,ticket: int):
	if stage!="S9" or ticket!=generation or ui.locked or unknown:return
	stage="S5";var epoch=pages.epoch;var connection=ui.engine.connection_generation;var place=str(c().get("location"))
	var before=int(c().get("characters",{}).get(uid,{}).get("inventory",{}).get(q.gearId,0))
	ui.dialog.close(false);consent={};ui.render()
	var result=await ui.update({"op":"campaign","action":"buyInventory","args":[uid,q.gearId,q.token,q.count]})
	if not valid_ticket(ticket,epoch,connection,place):return
	var after=int(c().get("characters",{}).get(uid,{}).get("inventory",{}).get(q.gearId,0))
	if result.get("ok",false) and after==before+int(q.count) and c().get("gold")==q.afterGold:
		stage="S0";receipt=q.duplicate(true);receipt.characterId=uid;message=""
		transaction={"kind":"buy","ownerId":uid,"text":"%sへ %s×%d / 支払%dG" % [ui.member_name(uid),q.gear.name,q.count,q.cost]};ui.save_notice.display(str(transaction.text))
	else:
		unknown=result.get("connection_lost",false) or result.get("ok",false);stage="S7" if unknown else "S0"
		message="購入結果を確認できません。再送せず保存済みの進行を読み込んで確認してください。" if unknown else "購入を確定できませんでした。所持金・在庫を確認して選び直してください。"
	ui.render()
func start_trial(id: String=""):
	if busy() or id.is_empty():return
	stage="S1";generation+=1;var ticket=generation;var epoch=pages.epoch;var connection=ui.engine.connection_generation;var place=str(c().get("location"))
	var candidates=[]
	var item: Dictionary={}
	for gear in c().get("shop",[]):
		if gear.id==id:item=gear;break
	if item.is_empty():stage="S0";return
	var slot=str(item.get("allowedSlots",["rightHand"] if item.slot=="weapon" else ["upperBody"] if item.slot=="armor" else [item.slot])[0])
	for person in ui.roster():
		if not c().get("selected",[]).has(person.id):continue
		var reply=await ui.engine.request({"op":"campaign","action":"previewGear","args":[person.id,id,slot]})
		if not valid_ticket(ticket,epoch,connection,place):return
		if reply.get("connection_lost",false):stage="S7";unknown=true;ui.handle_connection_loss(reply,connection);return
		var q: Dictionary=reply.get("previewGear",{});candidates.append({"id":person.id,"person":person,"ok":reply.get("ok",false) and q.get("eligible",false) and q.get("available",false),"reason":q.get("reason","試用できません")})
	stage="S4"
	ui.dialog.open("木人で試す人物",func(body,actions):
		l(body,str(item.name),true);l(body,"誰で試しますか？ 試用後は元の所持金・在庫・装備へ戻ります。")
		for candidate in candidates:
			var line=ui.row(body);ui.portrait(line,candidate.person,false,56)
			var caption=str(candidate.person.name)+(" / "+str(candidate.reason) if not candidate.ok else "")
			b(line,caption,run_trial.bind(str(candidate.id),id,slot,ticket),not candidate.ok).name="TrialRecipient_"+str(candidate.id)
		b(actions,"取り消す",ui.dialog.close).name="TrialRecipientCancel",
		cancel_purchase.bind(ticket))
func run_trial(uid: String,id: String,slot: String,ticket: int):
	if ticket!=generation or stage!="S4" or ui.locked:return
	stage="S8";ui.dialog.close(false);ui.shop_uid=uid;ui.shop_slot=slot;pages.gear_id=id
	await ui.act("trial",[uid,id,slot])
	if ui.data.get("trial")==null:stage="S0";ui.render()
func back_list():
	if stage=="S5" or unknown:return
	generation+=1;stage="S0";consent={};pages.invalidate_quote();ui.render()
func select_slot(id: String):
	if busy() or id==filter_slot:return
	filter_slot=id
	if not is_instance_valid(catalog_column) or not catalog_column.is_inside_tree():
		ui.render()
		return
	var selector=catalog_column.get_node("ShopSlotFilter")
	for index in range(selector.item_count):
		if selector.get_item_metadata(index)==id:selector.select(index);break
	var scroll=catalog_column.get_node("ShopProductsScroll")
	ui.refresh_panel(func():
		ui.memory.scrolls.erase("shop_products")
		sync_product_rows(scroll.get_child(0))
		scroll.scroll_vertical=0)
func select_member(id: String):
	if not busy():ui.shop_uid=id
func select_product(id: String):
	pages.gear_id=id;back_list()
func prefetch_visible():pass
func escape() -> bool:
	if ui.page!="shop":return false
	if stage in ["S1","S5"] or unknown:return true
	if stage!="S0":back_list();return true
	return false

func can_drop_product(data: Dictionary,uid: String) -> bool:
	return not busy() and not ui.modal_open() and ui.page=="shop" and c().get("selected",[]).has(uid) and data.get("kind")=="shop_product" and data.get("connection")==ui.engine.connection_generation and data.get("epoch")==pages.epoch and data.get("token")==c().get("inventoryToken") and offered().any(func(item):return item.id==data.get("item") and int(c().gold)>=int(item.price))

func confirm_consumable(id: String,uid: String):
	var products=offered().filter(func(item):return item.id==id)
	if products.is_empty() or uid.is_empty() or not c().get("selected",[]).has(uid):return
	var item=products[0];var token=c().get("inventoryToken");var count=purchase_quantity;var cost=int(item.price)*count
	if not consumable_payment(item,uid).ok:return
	generation+=1;var ticket=generation;stage="S4"
	ui.dialog.open("購入の確認",func(body,actions):
		l(body,"%s ×%d / 支払%dG / %sのインベントリへ" % [item.name,count,cost,ui.member_name(uid)],true)
		b(actions,"キャンセル",ui.dialog.close).name="PurchaseDecline"
		b(actions,"購入する",func():
			if stage!="S4" or ticket!=generation:return
			stage="S5";ui.dialog.close(false)
			var reply=await ui.update({"op":"campaign","action":"buyItem","args":[id,count,uid,token]})
			if ticket==generation:
				unknown=reply.get("connection_lost",false);stage="S7" if unknown else "S0"
				if reply.get("ok",false):
					transaction={"kind":"buy","ownerId":uid,"text":"%sへ %s×%d / 支払%dG" % [ui.member_name(uid),item.name,count,cost]};message="";ui.save_notice.display(str(transaction.text))
				else:message=str(reply.get("error","購入結果を確認してください。"))
				ui.render()).name="PurchaseAgree",
		cancel_purchase.bind(ticket))

func show_consumable_details(id: String):
	var products=offered().filter(func(item):return item.id==id)
	if products.is_empty():return
	var entry={"id":id,"name":products[0].name,"kind":"consumable","count":c().get("characters",{}).get(ui.shop_uid,{}).get("inventory",{}).get(id,0),"definition":c().get("itemDefinitions",[]).filter(func(item):return item.id==id)[0]}
	ui.show_equipment_details(entry)
