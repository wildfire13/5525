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
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func c() -> Dictionary:return pages.c()
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func busy() -> bool:return stage!="S0" or unknown or ui.locked or ui.presenting or ui.closing or ui.engine.disconnected
func reset(_plan_mode: String="discard",_campaign_id: String=""):
	stage="S0";unknown=false;consent={};receipt={};transaction={};message="";generation+=1
	filter_slot="all";filter_location="";background.clear();return_from_party=false;from_party=false
	if ui.dialog!=null:ui.dialog.close(false)
func slots() -> Array:
	return ["rightHand","leftHand"] if c().get("location")=="east" else ["accessory1","accessory2"] if c().get("location")=="north" else ["head","upperBody","lowerBody","feet"]
func offered() -> Array:
	return c().get("shop",[]).filter(func(g):
		if g.get("type")=="empty":return false
		var allowed=g.get("allowedSlots",["rightHand"] if g.get("hands",1)==2 else ["rightHand","leftHand"] if g.slot=="weapon" else ["upperBody"] if g.slot=="armor" else [g.slot])
		return filter_slot=="all" or allowed.has(filter_slot))
func render(parent):
	if filter_location!=str(c().get("location","")):filter_location=str(c().get("location",""));filter_slot="all"
	var context=ui.row(parent);context.name="ShopContext"
	var shop_name={"east":"イースの武器屋","west":"ウエスの防具屋","north":"ノースの装飾品店"}.get(c().location,"")
	ui.icons.line(ui,context,ui.icons.shop(str(c().location)),shop_name)
	render_notice(parent)
	var filters=ui.row(parent);filters.name="ShopFilters"
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(spacer)
	var filter_label=l(filters,"部位フィルター");filter_label.size_flags_horizontal=Control.SIZE_FILL;filter_label.custom_minimum_size.x=176;filter_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	var slot=OptionButton.new();slot.name="ShopSlotFilter";slot.custom_minimum_size=Vector2(180,44);filters.add_child(slot)
	slot.add_item("すべて");slot.set_item_metadata(0,"all")
	for id in slots():
		slot.add_icon_item(ui.icons.texture(ui.icons.slot(id)),str(c().get("slots",{}).get(id,id)));slot.set_item_metadata(slot.item_count-1,id)
		if filter_slot==id:slot.select(slot.item_count-1)
	slot.add_theme_constant_override("icon_max_width",24);slot.disabled=busy()
	slot.item_selected.connect(func(i):select_slot(str(slot.get_item_metadata(i))));ui.memory.key(slot,"shop_filter")
	var body=ui.scroller(parent);var scroll=body.get_parent();scroll.name="ShopProductsScroll"
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.memory.watch(scroll,"shop_products")
	for item in offered():
		var line=ui.row(body);line.name="ProductRow_"+str(item.id);line.custom_minimum_size.y=80
		var info=b(line,"",func():pass);info.name="Product_"+str(item.id);info.alignment=HORIZONTAL_ALIGNMENT_LEFT
		info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.custom_minimum_size=Vector2(240,80)
		ui.icons.apply(info,ui.icons.gear(item));ui.memory.key(info,"product_"+str(item.id));ui.memory.item(info,str(item.id))
		var margin=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;info.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,48 if side=="left" else 8)
		var copy=HBoxContainer.new();copy.mouse_filter=Control.MOUSE_FILTER_IGNORE;copy.add_theme_constant_override("separation",0);margin.add_child(copy)
		var name_label=l(copy,str(item.name));name_label.name="ProductName_"+str(item.id);name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		configure_tooltip(info,item)
		var price=l(copy,"%dG" % item.price);price.name="ProductPrice_"+str(item.id);price.custom_minimum_size.x=96;price.size_flags_horizontal=Control.SIZE_FILL;price.autowrap_mode=TextServer.AUTOWRAP_OFF;price.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;price.mouse_filter=Control.MOUSE_FILTER_IGNORE
		# The overlay does not participate in Button minimum sizing; measure wrapped names explicitly.
		copy.resized.connect(func():info.custom_minimum_size.y=maxf(80,copy.get_combined_minimum_size().y+16))
		var buy=b(line,"購入",confirm_purchase.bind(str(item.id)),busy() or int(c().gold)<int(item.price));buy.name="ProductBuy_"+str(item.id)
		ui.memory.key(buy,"buy_"+str(item.id));buy.custom_minimum_size=Vector2(130,64)
		if int(c().gold)<int(item.price):buy.tooltip_text="所持金が不足しています"
		var trial_button=b(line,"木人で試す",start_trial.bind(str(item.id)),busy());trial_button.name="ProductTrial_"+str(item.id)
		ui.memory.key(trial_button,"trial_"+str(item.id));trial_button.custom_minimum_size=Vector2(170,64)
func product_summary(item: Dictionary) -> String:
	var parts=[]
	if item.get("atk",0)>0:parts.append("ATK %d / 通常射程%d" % [item.atk,item.get("reach",0)])
	for pair in [["hp","HP"],["mp","MP"],["agiBonus","行動速度"]]:
		if item.get(pair[0],0)!=0:parts.append("%s %+d" % [pair[1],item[pair[0]]])
	var names=[]
	for field in ["skill","effect"]:
		if item.get(field)==null:continue
		var name_=str(c().get("skillNames",{}).get(item[field],item[field]))
		if item[field]=="scout":name_+="Lv%d" % int(item.get("skillLevel",1))
		if not names.has(name_):names.append(name_)
	if not names.is_empty():parts.append("付与："+"/".join(names))
	return " / ".join(parts) if not parts.is_empty() else "補正なし"
func render_notice(parent):
	var region=Control.new();region.name="ShopNoticeRegion";region.custom_minimum_size.y=56;region.clip_contents=true;parent.add_child(region)
	var row=ui.row(region);row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text=message if not message.is_empty() else "直近の取引："+str(transaction.text) if not transaction.is_empty() else ""
	var notice=l(row,text);notice.name="ShopNotice";notice.autowrap_mode=TextServer.AUTOWRAP_OFF;notice.clip_text=true;notice.add_theme_font_size_override("font_size",18);notice.tooltip_text=text
	if not message.is_empty():notice.add_theme_color_override("font_color",Color("#ffd0b8"))
	if message.is_empty() and not unknown and transaction.get("kind")=="buy":
		var uid=str(transaction.ownerId)
		b(row,ui.member_name(uid)+"の所持品を見る",ui.pages.party_view.open_inventory.bind(uid),busy() or not ui.can_inspect_member(uid)).name="PurchasedInventory"
func record_sale(q: Dictionary):
	transaction={"kind":"sell","ownerId":q.ownerId,"text":"%sの%s×%dを売却 / 受取%dG" % [q.ownerName,q.name,q.count,q.proceeds]};message=""
func configure_tooltip(button,item: Dictionary):
	button.set_script(preload("res://equipment_tooltip.gd"))
	var descriptions={};var levels={}
	for field in ["skill","effect"]:
		if item.get(field)==null:continue
		var id=str(item[field]);var level=int(item.get("skillLevel",1));levels[id]=level
		descriptions[id]=pages.skill_description(id,level)
	button.configure(str(item.name),item,{"names":c().get("skillNames",{}),"definitions":c().get("skillDefinitions",{}),"descriptions":descriptions,"effective_levels":levels,"title_size":24 if ui.size.x>=1800 else 20,"detail_size":18 if ui.size.x>=1800 else 16})
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
func confirm_purchase(id: String=""):
	if busy() or id.is_empty():return
	stage="S1";generation+=1;var ticket=generation;var epoch=pages.epoch;var connection=ui.engine.connection_generation;var place=str(c().get("location"))
	var reply=await ui.engine.request({"op":"campaign","action":"purchaseQuote","args":[id]})
	if not valid_ticket(ticket,epoch,connection,place):return
	if reply.get("connection_lost",false):unknown=true;stage="S7";message="接続が失われました。購入は確定していません。";ui.handle_connection_loss(reply,connection);return
	var q: Dictionary=reply.get("purchaseQuote",{})
	if not reply.get("ok",false) or not q.get("ok",false):stage="S0";message=str(q.get("reason",reply.get("error","購入できません")));ui.render();return
	consent=q.duplicate(true);stage="S4"
	ui.dialog.open("購入の確認",func(body,actions):
		l(body,str(q.gear.name)+" / 1個",true)
		l(body,"支払 %dG / 所持金 %d → %dG" % [q.cost,q.goldBefore,q.afterGold],true).name="PurchasePayment"
		l(body,"購入しますか？ 同意後に受取人を選びます。自動装備はしません。")
		b(actions,"購入しない",ui.dialog.close).name="PurchaseDecline"
		ui.primary(b(actions,"購入する",func():
			if ticket!=generation or stage!="S4":return
			ui.dialog.close(false);stage="S9";choose_recipient(ticket))).name="PurchaseAgree",
		cancel_purchase.bind(ticket))
func choose_recipient(ticket: int):
	if ticket!=generation or stage!="S9":return
	ui.dialog.open("受取人の選択",func(body,actions):
		l(body,str(consent.gear.name)+" / 1個",true)
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
	var result=await ui.update({"op":"campaign","action":"buyInventory","args":[uid,q.gearId,q.token]})
	if not valid_ticket(ticket,epoch,connection,place):return
	var after=int(c().get("characters",{}).get(uid,{}).get("inventory",{}).get(q.gearId,0))
	if result.get("ok",false) and after==before+1 and c().get("gold")==q.afterGold:
		stage="S0";receipt=q.duplicate(true);receipt.characterId=uid;message=""
		transaction={"kind":"buy","ownerId":uid,"text":"%sへ %s×1 / 支払%dG" % [ui.member_name(uid),q.gear.name,q.cost]}
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
	if busy():return
	filter_slot=id;ui.memory.scrolls.erase("shop_products");ui.render()
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
