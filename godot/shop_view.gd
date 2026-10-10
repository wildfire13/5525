extends RefCounted
## Quotes and mutations come from Campaign; this object owns presentation only.
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var stage := "S0"
var receipt: Dictionary={}
var error_text := ""
var unknown := false
var quote_worker := false
var selected_request := ""
var background: Array[String]=[]
var row_labels: Dictionary={}
var list_scroll: ScrollContainer
var modal_ticket := -1
var return_from_party := false
var from_party := false
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func c() -> Dictionary:return pages.c()
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func compact() -> bool:return ui.ui_size_mode!="standard"
func reset():
	stage="S0";receipt={};error_text="";unknown=false;selected_request="";background.clear();row_labels.clear();return_from_party=false;from_party=false
	if ui.dialog!=null:ui.dialog.close(false)
func slots() -> Array:
	return ["rightHand","leftHand"] if c().get("location")=="east" else ["head","upperBody","lowerBody","feet","accessory1","accessory2"]
func member() -> Dictionary:
	for u in ui.roster():
		if u.id==ui.shop_uid:return u
	return {}
func render(parent):
	if not c().get("selected",[]).has(ui.shop_uid):ui.shop_uid=str(c().get("selected",[""])[0])
	if not slots().has(ui.shop_slot):ui.shop_slot=str(slots()[0])
	var context=ui.row(parent);context.name="ShopContext";context.custom_minimum_size.y=56
	var shop_name={"east":"イースの武器屋","west":"ウエスの防具屋"}.get(c().location,"")
	l(context,shop_name)
	if from_party:b(context,"仲間へ戻る",func():pages.party_uid=ui.shop_uid;pages.party_view.highlight_slot=ui.shop_slot;ui.page="party";ui.render(),stage=="S5")
	var face=ui.portrait(context,member(),true,40);face.name="ShopMemberPortrait"
	var who=b(context,str(member().get("name",ui.shop_uid))+" ▾",open_members,stage=="S5" or unknown);who.custom_minimum_size.x=96;ui.memory.key(who,"shop_member")
	var slot=OptionButton.new();slot.custom_minimum_size=Vector2(112,44);context.add_child(slot)
	for id in slots():
		slot.add_item(str(c().get("slots",{}).get(id,id)));slot.set_item_metadata(slot.item_count-1,id)
		if ui.shop_slot==id:slot.select(slot.item_count-1)
	slot.disabled=stage=="S5" or unknown or ui.locked or ui.engine.disconnected
	slot.item_selected.connect(func(i):select_slot(str(slot.get_item_metadata(i))));ui.memory.key(slot,"shop_slot")
	var gold=l(context,"所持金 %dG" % c().get("gold",0));gold.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	if stage=="S6":render_receipt(parent);return
	if stage=="S7":render_error(parent);return
	var split=HBoxContainer.new();split.name="ShopSplit";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",12);parent.add_child(split)
	row_labels.clear();list_scroll=null
	if not compact() or stage=="S0":render_list(split)
	if stage!="S0" or not compact():
		var box=ui.card(split);box.name="GearQuote";box.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
		if stage=="S0":l(box,"商品を選択して比較します",true);l(box,"人物と装備枠を選ぶと、店の正規条件を確認します。")
		elif stage=="S1":l(box,"装備条件・見積を取得中…",true);b(box,"一覧へ",back_list)
		elif stage=="S5":l(box,"購入・装備を処理中…",true);receipt_summary(box,receipt);l(box,"結果を確認しています。操作を受け付けません。")
		elif pages.quote_valid():render_comparison(box)
		else:l(box,"見積が更新されています");b(box,"最新の見積を取得",select_product.bind(pages.gear_id))
	if list_scroll!=null:ui.call_deferred("prefetch_shop_rows")
func render_list(parent):
	var body=ui.scroller(parent);list_scroll=body.get_parent();list_scroll.name="ShopProductsScroll"
	list_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if compact():list_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	else:list_scroll.custom_minimum_size.x=360;list_scroll.size_flags_horizontal=Control.SIZE_FILL
	ui.memory.watch(list_scroll,"shop_products")
	for item in pages.offered():
		var btn=b(body,"",select_product.bind(str(item.id)));btn.custom_minimum_size.y=64;btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		btn.name="Product_"+str(item.id);ui.memory.key(btn,"product_"+str(item.id));ui.memory.item(btn,str(item.id))
		var selected=is_selected_product(str(item.id));btn.set_meta("product_selected",selected)
		if selected:
			for state_ in ["normal","hover","pressed"]:
				var style=btn.get_theme_stylebox(state_).duplicate();style.bg_color=Color("#31545b");style.border_color=Color("#91dacf");style.set_border_width_all(2);btn.add_theme_stylebox_override(state_,style)
		var margin=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;btn.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,8)
		var label=l(margin,product_caption(item));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",16);row_labels[str(item.id)]=label
		btn.tooltip_text=str(item.name)+" / "+str(item.get("price","?"))+"G";btn.set_meta("product_id",str(item.id))
		# A wrapped name or reason increases its row instead of hiding conditions.
		label.minimum_size_changed.connect(func():
			if is_instance_valid(btn):btn.custom_minimum_size.y=maxf(64,label.get_minimum_size().y+16))
	list_scroll.get_v_scroll_bar().value_changed.connect(func(_v):ui.call_deferred("prefetch_shop_rows"))
func is_selected_product(id: String) -> bool:
	return id==pages.gear_id and stage in ["S1","S2","S3","S4","S5","S8"]
func product_caption(item: Dictionary) -> String:
	var quote=pages.cached_quotes.get(pages.selection_key(str(item.id)),{})
	var condition="条件確認中…" if quote.is_empty() else reason(quote)
	if condition.is_empty():condition="✓ 装備可"+(" / "+str(quote.reason) if quote.get("reason")!=null and not str(quote.reason).is_empty() else "")
	return "%s  %sG\n%s / %s / %s" % [("▶ 選択中 / " if is_selected_product(str(item.id)) else "")+str(item.name),number(item.get("price","?")),pages.gear_type(item),"両手" if item.get("hands",1)==2 else "占有0枠" if item.get("type")=="empty" else "片手" if ui.shop_slot in ["rightHand","leftHand"] else str(c().slots.get(ui.shop_slot,ui.shop_slot)),condition]
func can_quote() -> bool:
	return not ui.closing and not ui.engine.disconnected and ui.page=="shop" and c().get("phase")=="town" and ui.data.get("trial")==null and stage not in ["S5","S6","S7","S8"]
func prefetch_visible():
	if not can_quote() or not is_instance_valid(list_scroll) or not list_scroll.is_visible_in_tree():return
	var last=-1;var children=list_scroll.get_child(0).get_children()
	for i in range(children.size()):
		var child=children[i]
		if child.position.y+child.size.y>=list_scroll.scroll_vertical and child.position.y<=list_scroll.scroll_vertical+list_scroll.size.y:last=i;queue_background(str(child.get_meta("product_id","")))
	if last>=0 and last+1<children.size():queue_background(str(children[last+1].get_meta("product_id","")))
	pump_quotes()
func queue_background(id: String):
	if not id.is_empty() and not pages.cached_quotes.has(pages.selection_key(id)) and not background.has(id):background.append(id)
func select_product(id: String):
	if id.is_empty() or stage=="S5" or unknown or ui.locked or ui.presenting:return
	ui.memory.capture();ui.memory.scrolls.erase("shop_compare");ui.skip_capture_once=true;pages.gear_id=id;pages.invalidate_quote();stage="S1";pages.quote_pending=true;selected_request=id
	ui.memory.request_focus("shop_comparison_heading");ui.render();await pump_quotes()
	while quote_worker and not ui.closing:await ui.get_tree().process_frame
func pump_quotes():
	if quote_worker:return
	quote_worker=true
	while not ui.closing and (not selected_request.is_empty() or not background.is_empty()):
		if not can_quote():break
		while ui.engine.busy or ui.locked:
			await ui.get_tree().process_frame
			if not can_quote():break
		if not can_quote():break
		if selected_request.is_empty() and background.is_empty():break
		var priority=not selected_request.is_empty()
		var id=selected_request if priority else background.pop_front();if priority:selected_request=""
		var stamp=pages.selection_key(id);var generation=pages.quote_generation;var epoch=pages.epoch;var connection=ui.engine.connection_generation
		var reply: Dictionary
		if pages.cached_quotes.has(stamp):reply={"ok":true,"previewGear":pages.cached_quotes[stamp]}
		else:reply=await ui.engine.request({"op":"campaign","action":"previewGear","args":[ui.shop_uid,id,ui.shop_slot]})
		if ui.closing:break
		if epoch!=pages.epoch or connection!=ui.engine.connection_generation:continue
		# A transport loss applies to the current connection even if this quote was cancelled.
		if reply.get("connection_lost",false):show_quote_error(reply);break
		if stamp!=pages.selection_key(id):continue
		var current=priority and generation==pages.quote_generation and id==pages.gear_id
		if reply.get("ok",false) and reply.get("previewGear") is Dictionary:
			pages.cached_quotes[stamp]=reply.previewGear.duplicate(true)
			if current:
				ui.gear_preview=reply.previewGear;pages.quote_stamp=stamp;pages.quote_pending=false;stage="S2";ui.notice="";ui.render()
			else:
				if row_labels.has(id) and is_instance_valid(row_labels[id]):
					for item in pages.offered():
						if item.id==id:row_labels[id].text=product_caption(item)
		elif current:show_quote_error(reply);break
	quote_worker=false
func show_quote_error(reply: Dictionary):
	pages.quote_pending=false;stage="S7";unknown=false;error_text=str(reply.get("error","見積を取得できませんでした"));ui.render()
func reason(q: Dictionary) -> String:
	if not c().get("selected",[]).has(ui.shop_uid):return "× 編成中の仲間が購入対象です"
	if not q.get("available",false):return "× この店では購入できません"
	if not q.get("eligible",false):return "× "+str(q.get("reason","装備条件を満たしません"))
	if q.get("same",false):return "＝ 装備中の品です"
	if not q.get("affordable",false):return "× 所持金が不足しています"
	return ""
func comparison_lines(q: Dictionary,all_values:=false) -> Array[String]:
	var losses: Array[String]=[];var gains: Array[String]=[];var unchanged: Array[String]=[]
	var before: Dictionary=q.before;var after: Dictionary=q.after
	for field in [["max","HP上限"],["maxMp","MP上限"],["speed","行動速度"]]:
		if not before.has(field[0]) or not after.has(field[0]):continue
		var a=int(before[field[0]]);var z=int(after[field[0]]);var line="%s: %d → %d (%+d)" % [field[1],a,z,z-a]
		if z<a:losses.append("▼ "+line)
		elif z>a:gains.append("▲ "+line)
		elif all_values:unchanged.append("＝ "+line)
	var br=pages.normal_reach(before);var ar=pages.normal_reach(after)
	for d in range(1,maxi(br,ar)+1):
		var a=pages.normal_atk(before,d);var z=pages.normal_atk(after,d)
		var line="通常ATK・距離%d: %s → %s%s" % [d,str(a) if d<=br else "射程外",str(z) if d<=ar else "射程外"," (%+d)" % (z-a) if d<=br and d<=ar else ""]
		if d>ar or z<a:losses.append("▼ "+line)
		elif d>br or z>a:gains.append("▲ "+line)
		elif all_values:unchanged.append("＝ "+line)
	if br!=ar:(losses if ar<br else gains).append("%s 通常攻撃の届く距離: %d → %d" % ["▼" if ar<br else "▲",br,ar])
	elif all_values:unchanged.append("＝ 通常攻撃の届く距離: %d" % br)
	for pair in [["activeSkills","スキル"],["effects","効果"]]:
		var old=before.get(pair[0],[]);var now=after.get(pair[0],[])
		for name_ in old:
			if not now.has(name_):losses.append("− 失う"+pair[1]+": "+change_description(str(name_),pair[0]=="effects"))
		for name_ in now:
			if not old.has(name_):gains.append("＋ 得る"+pair[1]+": "+change_description(str(name_),pair[0]=="effects"))
		if all_values:unchanged.append(pair[1]+": "+" / ".join(old.map(func(id):return str(c().get("skillNames",{}).get(id,id))))+" → "+" / ".join(now.map(func(id):return str(c().get("skillNames",{}).get(id,id)))))
	# Named source changes are meaningful even if they grant the same skill.
	if all_values:
		for side in ["before","after"]:
			for source in q[side].get("skillSources",[]):unchanged.append(("現在" if side=="before" else "候補")+"の由来: "+str(c().get("skillNames",{}).get(source.id,source.id))+" / "+str(c().slots.get(source.slot,source.slot))+" / "+source_name(q,source))
	return losses+gains+unchanged
func render_comparison(parent):
	var q=ui.gear_preview;var title=ui.row(parent)
	if compact():b(title,"一覧へ",back_list)
	var heading=l(title,str(q.current.name)+" → "+str(q.gear.name),true);heading.focus_mode=Control.FOCUS_ALL;ui.memory.key(heading,"shop_comparison_heading")
	l(parent,"%s / %s / %s" % [ui.member_name(ui.shop_uid),c().slots.get(ui.shop_slot,ui.shop_slot),"両手" if q.gear.get("hands",1)==2 else "片手" if ui.shop_slot in ["rightHand","leftHand"] else "装備"])
	var why=reason(q)
	if not why.is_empty():var warning=l(parent,why);warning.add_theme_color_override("font_color",Color("#ffc9a8"))
	var body=ui.scroller(parent);body.get_parent().name="ShopComparisonScroll";body.get_parent().custom_minimum_size.y=64;ui.memory.watch(body.get_parent(),"shop_compare")
	var lines=comparison_lines(q)
	if lines.is_empty():l(body,"数値・スキル・効果の変更はありません。")
	for text in lines:l(body,text)
	var payment=l(parent,"%s    所持金 %d → %dG" % [payment_text(q.cost),c().gold,q.afterGold],true);payment.name="PaymentSummary"
	l(parent,"価格 %d − 下取 %d = %dG / 下取: %s は手元に残りません" % [q.price,q.tradeIn,q.cost,q.current.name])
	var actions=ui.row(parent);actions.name="ShopActions"
	b(actions,"全性能・説明",open_details);b(actions,"木人で試す",start_trial,not q.get("eligible",false) or not q.get("available",false))
	var purchase_button=ui.primary(b(actions,"購入内容を確認",confirm_purchase,not why.is_empty()));ui.memory.key(purchase_button,"purchase")
	body.get_parent().resized.connect(pages.refresh_purchase_availability.bind(purchase_button));body.get_parent().visibility_changed.connect(pages.refresh_purchase_availability.bind(purchase_button));pages.refresh_purchase_availability(purchase_button)
func open_details():
	if not pages.quote_valid():return
	var q=ui.gear_preview.duplicate(true);stage="S3"
	ui.dialog.open("装備の全性能・説明",func(body,actions):
		l(body,ui.member_name(ui.shop_uid)+" / "+str(c().slots.get(ui.shop_slot,ui.shop_slot)),true)
		l(body,str(q.current.name)+" → "+str(q.gear.name),true)
		for line in comparison_lines(q,true):l(body,line)
		l(body,"通常ATK = その距離に届く武器のATK合算 + 成長補正1回。陣形・スキル・防御は戦闘予測で確認。")
		for pair in [["current","現在の装備"],["gear","購入候補"]]:
			l(body,pair[1],true)
			pages.describe_gear(body,q[pair[0]])
		l(body,"装備条件: "+(str(q.reason) if q.get("reason")!=null else "適合"))
		var notes=VBoxContainer.new();body.add_child(notes);notes.visible=false;l(notes,q.get("warning",""))
		ui.local_button(body,"開発注記 ▾",func():notes.visible=not notes.visible)
		ui.local_button(actions,"比較に戻る",ui.dialog.close),func():stage="S2";ui.render())
func confirm_purchase():
	if not pages.quote_valid() or not pages.comparison_visible() or not reason(ui.gear_preview).is_empty() or stage!="S2":return
	var q=ui.gear_preview.duplicate(true);var stamp=pages.quote_stamp;var ticket=pages.quote_generation;stage="S4";modal_ticket=ticket
	ui.dialog.open("購入・装備の確認",func(body,actions):
		receipt_summary(body,q)
		for line in comparison_lines(q):l(body,line)
		ui.local_button(actions,"比較に戻る",ui.dialog.close)
		ui.primary(b(actions,"%dGで購入・装備" % q.cost if q.cost>=0 else "%dGを受け取り購入・装備" % -q.cost,func():
			if stage!="S4" or ticket!=pages.quote_generation or stamp!=pages.selection_key(str(q.gearId)) or not pages.quote_valid():
				ui.dialog.close(false);stage="S7";error_text="見積の前提が変わりました。最新の見積を確認してください。";ui.render();return
			stage="S5";ui.dialog.close(false);buy(q))),func():stage="S2";ui.render())
func number(value) -> String:
	return str(int(value)) if value is float or value is int else str(value)
func receipt_summary(parent,q: Dictionary):
	l(parent,str(q.get("gear",{}).get("name","購入品")),true)
	var identity=ui.row(parent)
	for u in ui.roster():
		if u.id==q.get("characterId",ui.shop_uid):
			var face=ui.portrait(identity,u,true,40);face.name="ConfirmationMemberPortrait";break
	l(identity,ui.member_name(str(q.get("characterId",ui.shop_uid)))+" / "+str(c().get("slots",{}).get(q.get("slot",ui.shop_slot),ui.shop_slot)))
	l(parent,str(q.get("current",{}).get("name",""))+" → "+str(q.get("gear",{}).get("name","")))
	l(parent,"価格 %s − 下取 %s = %s" % [number(q.get("price","未確認")),number(q.get("tradeIn","未確認")),payment_text(q.get("cost",0))],true)
	l(parent,"所持金 %s → %sG" % [number(q.get("goldBefore",c().get("gold","未確認"))),number(q.get("afterGold","未確認"))])
	l(parent,"下取: "+str(q.get("current",{}).get("name",""))+" は手元に残りません。")
func buy(q: Dictionary):
	if stage!="S5":return
	receipt=q.duplicate(true);receipt.goldBefore=c().gold;selected_request="";background.clear();pages.invalidate_quote();ui.render()
	var result=await ui.update({"op":"campaign","action":"buyGear","args":[q.characterId,q.gearId,q.slot]})
	if ui.closing:return
	var equipped=false
	for person in ui.roster():
		if person.id==q.characterId:
			for slot in person.get("equipmentSlots",[]):
				if slot.get("slot",slot.get("id"))==q.slot and slot.get("id")==q.gearId:equipped=true
	# Canonical serialized character storage is also returned by Campaign.view.
	var storage={"rightHand":"weapon","upperBody":"armor","accessory1":"accessory"}.get(q.slot,q.slot)
	var character=c().get("characters",{}).get(q.characterId,{})
	if character.get(storage)==q.gearId:equipped=true
	if result.get("ok",false) and equipped and c().get("gold")==q.afterGold:stage="S6";pages.cached_quotes.clear();ui.notice=""
	else:stage="S7";unknown=result.get("connection_lost",false) or result.get("ok",false);error_text="購入の成否を確認できません。自動再送はしません。保存済みの進行を明示的に読み込んで確認してください。" if unknown else str(result.get("error","購入を拒否されました。見積を更新してください。"))
	ui.render()
func render_receipt(parent):
	var box=ui.card(parent);box.name="PurchaseReceipt";box.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	l(box,"✓ 購入完了",true);l(box,str(receipt.gear.name)+" を装備しました",true)
	l(box,ui.member_name(receipt.characterId)+" / "+str(c().slots.get(receipt.slot,receipt.slot)))
	l(box,"%s / 残金 %dG" % [payment_text(receipt.cost),c().gold],true)
	l(box,str(receipt.current.name)+" → "+str(receipt.gear.name));l(box,str(receipt.current.name)+" は下取済みです。")
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(spacer)
	var actions=ui.row(box);b(actions,"仲間・装備で見る",view_purchased);ui.memory.key(ui.primary(b(actions,"買い物を続ける",back_list)),"purchase_continue")
func render_error(parent):
	var box=ui.card(parent);l(box,"購入結果の確認が必要です" if unknown else "処理できませんでした",true);l(box,error_text)
	if not unknown and not ui.engine.disconnected:b(box,"最新の見積を取得",recover_quote)
	b(box,"一覧へ",back_list,unknown)
func recover_quote():
	if unknown or ui.engine.disconnected:return
	var id=pages.gear_id;pages.cached_quotes.clear()
	var reply=await ui.update({"op":"view"})
	if reply.get("ok",false):await select_product(id)
func back_list():
	if stage=="S5" or unknown:return
	pages.invalidate_quote();selected_request="";stage="S0";ui.memory.request_focus("product_"+pages.gear_id);ui.render()
func select_member(id: String):
	if stage=="S5" or unknown:return
	ui.shop_uid=id;context_changed()
func select_slot(id: String):
	if stage=="S5" or unknown:return
	ui.shop_slot=id;context_changed()
func context_changed():
	pages.invalidate_quote();background.clear();selected_request=""
	if not pages.gear_id.is_empty() and pages.offered().any(func(g):return g.id==pages.gear_id):await select_product(pages.gear_id)
	else:pages.gear_id="";stage="S0";ui.render()
func open_members():
	ui.dialog.open("装備先の仲間",func(body,actions):
		for person in ui.roster():
			if not c().get("selected",[]).has(person.id):continue
			var line=ui.row(body);ui.portrait(line,person,false,56)
			ui.local_button(line,str(person.name)+" / "+str(person.get("role","")),func():ui.dialog.close(false);select_member(str(person.id)))
		ui.local_button(actions,"戻る",ui.dialog.close))
func start_trial():
	if not pages.quote_valid():return
	stage="S8";await ui.act("trial",[ui.shop_uid,pages.gear_id,ui.shop_slot])
	if ui.data.get("trial")==null:stage="S2";ui.render()
func view_purchased():
	pages.party_uid=receipt.characterId;pages.party_view.tab=0;pages.party_view.highlight_slot=receipt.slot;return_from_party=true;ui.page="party";ui.render()
func escape() -> bool:
	if ui.page!="shop":return false
	if stage=="S5":return true
	if stage in ["S1","S2","S6","S7"]:back_list();return true
	return false

func payment_text(cost) -> String:
	return "支払 %dG" % cost if cost>=0 else "受取 %dG" % -cost
func source_name(q: Dictionary,source: Dictionary) -> String:
	for gear in [q.current,q.gear]:
		if gear.get("id")==source.get("itemId"):return str(gear.name)
	return str(member().get("equipmentDetails",{}).get(source.slot,{}).get("name","装備"))

func change_description(id: String,is_effect: bool) -> String:
	var name_=str(c().get("skillNames",{}).get(id,id))
	var description=str(c().get("skillDefinitions",{}).get(id,{}).get("description","")) if is_effect else ""
	return name_+(" / "+description if not description.is_empty() else "")
