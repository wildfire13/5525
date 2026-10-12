extends RefCounted
## Purchase intentions are session UI state. They never enter saved inventories.
var owner_ref: WeakRef
var shop:
	get:return owner_ref.get_ref()
var ui
var plans: Dictionary={}
var acknowledged: Dictionary={}
var new_rows: Array=[]
var quoted: Dictionary={}
var quote_stamp := ""
var refreshing := false
var generation := 0
var message := ""
var sale_owner := ""
var sale_item := ""
var sale_count := 1
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func c() -> Dictionary:return ui.campaign()
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func location() -> String:return str(c().get("location",""))
func draft() -> Dictionary:return plans.get(location(),{})
func key(row: Dictionary) -> String:return str(row.characterId)+"/"+str(row.slot)
func entries() -> Array:
	return draft().values().map(func(row):return {"characterId":row.characterId,"gearId":row.gearId,"slot":row.slot})
func stamp() -> String:return JSON.stringify([location(),c().get("inventoryToken"),entries()])
func busy() -> bool:return ui.locked or ui.presenting or ui.closing or ui.engine.disconnected or shop.unknown or shop.stage in ["S4","S5"]
func reset():
	plans={};acknowledged={};new_rows=[];quoted={};quote_stamp="";message="";sale_owner="";sale_item="";sale_count=1;generation+=1
func show(mode: String):
	if busy():return
	shop.view_mode=mode;ui.render()
func existing(q: Dictionary) -> Dictionary:return draft().get(key(q),{})
func add_caption(q: Dictionary) -> String:
	var previous=existing(q)
	return "購入計画に追加" if previous.is_empty() else "追加済み" if previous.gearId==q.gearId else "予定を更新"
func add_current():
	if busy() or not shop.pages.quote_valid():return
	var q=ui.gear_preview
	if not q.get("available",false) or q.get("same",false):return
	var previous=existing(q)
	if previous.get("gearId")==q.gearId:return
	if not plans.has(location()):plans[location()]={}
	var row={"characterId":q.characterId,"gearId":q.gearId,"slot":q.slot,"name":q.gear.name}
	plans[location()][key(row)]=row
	var id=location()+"/"+key(row);acknowledged.erase(id)
	if not new_rows.has(id):new_rows.append(id)
	quote_stamp=""
	message="購入計画に追加しました。" if previous.is_empty() else "予定を更新: %s / %s / %s → %s" % [ui.member_name(row.characterId),c().slots.get(row.slot,row.slot),previous.name,row.name]
	ui.render()
func remove_row(id: String):
	if busy():return
	if plans.has(location()):plans[location()].erase(id)
	acknowledged.erase(location()+"/"+id);quote_stamp="";ui.render()
func cancel_plan():
	if busy() or draft().is_empty():return
	ui.confirm("この店の購入予定を取り消します。\n所持品や所持金、すでに確定した売却は変わりません。",func():plans.erase(location());quoted={};quote_stamp="";message="購入予定を取り消しました。";ui.render())
func ready() -> bool:
	if quote_stamp!=stamp() or not quoted.get("ok",false):return false
	return quoted.get("rows",[]).all(func(row):return acknowledged.get(location()+"/"+key(row))==row.signature)
func refresh():
	if refreshing or draft().is_empty() or ui.closing:return
	refreshing=true;var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var requested=stamp();var place=location()
	while ui.engine.busy or ui.locked:
		await ui.get_tree().process_frame
		if ui.closing or ticket!=generation:refreshing=false;return
	var reply=await ui.engine.request({"op":"campaign","action":"purchasePlan","args":[entries()]})
	refreshing=false
	if ui.closing or ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:return
	if reply.get("connection_lost",false):shop.show_quote_error(reply);return
	if requested!=stamp():ui.render();return
	if reply.get("ok",false):
		quoted=reply.get("purchasePlan",{});quote_stamp=requested
		for row in quoted.get("rows",[]):
			var id=place+"/"+key(row)
			if new_rows.has(id):acknowledged[id]=row.signature;new_rows.erase(id)
	else:quoted={};quote_stamp=requested;message=str(reply.get("error","購入計画を確認できませんでした"))
	ui.render()
func render(parent,mode: String):
	if mode=="sale":render_sale(parent);return
	l(parent,"購入計画 / %d件" % draft().size(),true)
	if draft().is_empty():l(parent,"商品を比較して、購入計画に追加してください。");return
	var current=quote_stamp==stamp()
	var body=ui.scroller(parent);body.get_parent().name="PurchasePlanScroll";ui.memory.watch(body.get_parent(),"purchase_plan_"+location())
	for entry in draft().values():
		var row={}
		for candidate in quoted.get("rows",[]):
			if key(candidate)==key(entry):row=candidate
		var box=ui.card(body);var heading=ui.row(box)
		l(heading,"%s / %s / %s" % [ui.member_name(entry.characterId),c().get("slots",{}).get(entry.slot,entry.slot),entry.name],true)
		b(heading,"予定から外す",remove_row.bind(key(entry)),busy())
		if not row.is_empty() and current:
			l(box,"%s → %s / 購入 %dG" % [row.current.name,row.gear.name,row.cost])
			if row.retained:l(box,"外した装備は本人のインベントリへ")
			if not row.ok:l(box,row.reason)
			elif acknowledged.get(location()+"/"+key(row))!=row.signature:
				l(box,"装備条件または比較内容が変わりました。",true)
				for change in shop.comparison_changes(row):shop.render_change(box,change)
				b(box,"この変更を確認",func():acknowledged[location()+"/"+key(row)]=row.signature;ui.render(),busy()).name="ReviewPlan_"+key(row).replace("/","_")
	if current and not quoted.is_empty():
		var payment=l(parent,"購入合計 %dG / 所持金 %d → %dG" % [quoted.cost,c().gold,quoted.afterGold],true);payment.name="PlanPayment"
		if quoted.shortfall>0:l(parent,"不足 %dG / 所持品を売却して計画を続けられます" % quoted.shortfall)
		elif not quoted.reason.is_empty():l(parent,quoted.reason)
	elif not current:l(parent,"購入計画の条件を更新中…");call_deferred("refresh")
	var actions=ui.row(parent)
	b(actions,"所持品を売却",show.bind("sale"),busy()).name="PlanGoSell"
	b(actions,"購入予定を取消",cancel_plan,busy())
	ui.primary(b(actions,"まとめて購入を確認",confirm_plan,not ready() or busy())).name="PlanCheckout"
func confirm_plan():
	if busy() or not ready():return
	var q=quoted.duplicate(true);var payload=entries().duplicate(true);var expected=stamp();shop.stage="S4"
	ui.dialog.open("購入計画の確認",func(body,actions):
		for row in q.rows:l(body,"%s / %s / %s / %dG" % [row.characterName,c().slots.get(row.slot,row.slot),row.gear.name,row.cost])
		l(body,"合計 %dG / 所持金 %d → %dG" % [q.cost,q.goldBefore,q.afterGold],true)
		l(body,"外した装備は各本人のインベントリに残ります。")
		ui.local_button(actions,"取り消す",ui.dialog.close)
		ui.primary(b(actions,"この内容でまとめて購入",func():
			if expected!=stamp() or not ready():ui.dialog.close();message="状態が変わりました。購入計画を再確認してください。";quote_stamp="";ui.render();return
			ui.dialog.close(false);shop.stage="S5";buy(q,payload))),func():shop.stage="S2" if shop.pages.quote_valid() else "S0";ui.render())
func buy(q: Dictionary,payload: Array):
	var place=location();var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var reply=await ui.update({"op":"campaign","action":"buyPlan","args":[payload,q.token]})
	if ui.closing or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:return
	var matching=q.rows.all(func(row):return c().get("characters",{}).get(row.characterId,{}).get({"rightHand":"weapon","upperBody":"armor"}.get(row.slot,row.slot))==row.gearId)
	if reply.get("ok",false) and matching and c().get("gold")==q.afterGold:
		plans.erase(place);quoted={};quote_stamp="";message="%d件を%dGで購入・装備しました。残金%dG" % [q.rows.size(),q.cost,q.afterGold];shop.stage="S0";shop.pages.invalidate_quote()
	else:await transaction_error(reply)
	ui.render()
func transaction_error(reply: Dictionary):
	shop.stage="S7";shop.unknown=reply.get("connection_lost",false) or reply.get("ok",false)
	shop.error_text="結果を確認できません。自動再送はしません。保存済みの進行を読み込み直して確認してください。" if shop.unknown else str(reply.get("error","取引できませんでした。状態を再確認してください。"))
	if not shop.unknown:
		quote_stamp="";await ui.update({"op":"view"})
func render_sale(parent):
	l(parent,"所持品を売却",true)
	render_sale_budget(parent)
	if not c().get("selected",[]).has(sale_owner):sale_owner=str(c().get("selected",[""])[0])
	var who=OptionButton.new();who.name="SaleOwner";who.custom_minimum_size=Vector2(180,48);parent.add_child(who)
	for uid in c().get("selected",[]):
		who.add_item(ui.member_name(uid)+"の所持品");who.set_item_metadata(who.item_count-1,uid)
		if uid==sale_owner:who.select(who.item_count-1)
	who.disabled=busy();who.item_selected.connect(func(i):sale_owner=str(who.get_item_metadata(i));sale_item="";sale_count=1;ui.render())
	var body=ui.scroller(parent);body.get_parent().name="SaleInventoryScroll";ui.memory.watch(body.get_parent(),"sale_"+sale_owner)
	var available=c().get("inventoryByCharacter",{}).get(sale_owner,{}).get("entries",[]).filter(func(item):return item.kind=="equipment")
	if available.is_empty():l(body,"売却できる所持装備はありません。装備中の品はステータスから外せます。")
	for item in available:
		var row=ui.row(ui.card(body))
		b(row,"%s / %d個 / 売却単価 %dG" % [item.name,item.count,item.definition.price],func():sale_item=item.id;sale_count=1;ui.render(),busy()).name="SaleItem_"+str(item.id)
		if sale_item==item.id:
			sale_count=clampi(sale_count,1,int(item.count))
			var quantity=SpinBox.new();quantity.name="SaleQuantity";quantity.min_value=1;quantity.max_value=item.count;quantity.step=1;quantity.value=sale_count;quantity.custom_minimum_size.x=120;row.add_child(quantity)
			quantity.editable=not busy();quantity.value_changed.connect(func(value):sale_count=int(value))
			b(row,"売却内容を確認",prepare_sale,busy()).name="PrepareSale"
	b(parent,"購入計画へ戻る",show.bind("plan"),busy()).name="SaleBackToPlan"
func render_sale_budget(parent):
	var budget=l(parent,"");budget.name="SalePlanBudget"
	var current=quote_stamp==stamp() and not quoted.is_empty()
	if draft().is_empty() or current:
		var cost=int(quoted.cost) if current and not draft().is_empty() else 0
		var gold=int(c().gold);var after=gold-cost;var shortfall=maxi(0,-after)
		budget.text="購入計画 %d件 / 合計 %dG / 所持金 %dG\n不足 %dG / 購入後残金 %dG" % [draft().size(),cost,gold,shortfall,after]
		budget.set_meta("budget",{"cost":cost,"gold":gold,"shortfall":shortfall,"afterGold":after})
		if shortfall>0:budget.add_theme_color_override("font_color",Color("#ffd0b8"))
		if current and not quoted.get("reason","").is_empty() and shortfall==0:l(parent,quoted.reason)
	else:
		budget.text="購入計画 %d件 / 合計 確認中 / 所持金 %dG\n不足・購入後残金を確認中…" % [draft().size(),c().gold]
		if quote_stamp!=stamp():call_deferred("refresh")
func prepare_sale():
	if busy() or sale_item.is_empty():return
	var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var reply=await ui.update({"op":"campaign","action":"saleQuote","args":[sale_owner,sale_item,sale_count]})
	if ui.closing or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:return
	var q=reply.get("saleQuote",{})
	if not reply.get("ok",false) or not q.get("ok",false):message=str(q.get("reason",reply.get("error","売却内容を確認できません")));ui.render();return
	shop.stage="S4"
	ui.dialog.open("売却の確認",func(body,actions):
		l(body,"%sの %s / %d個" % [q.ownerName,q.name,q.count],true)
		l(body,"単価 %dG / 受取 %dG / 所持金 %d → %dG" % [q.price,q.proceeds,q.goldBefore,q.afterGold])
		l(body,"売却後も購入計画は残ります。")
		ui.local_button(actions,"取り消す",ui.dialog.close)
		ui.primary(b(actions,"この内容で売却",func():
			if q.token!=c().get("inventoryToken"):ui.dialog.close();message="所持品が変わりました。売却内容を選び直してください。";ui.render();return
			ui.dialog.close(false);shop.stage="S5";sell(q))),func():shop.stage="S2" if shop.pages.quote_valid() else "S0";ui.render())
func sell(q: Dictionary):
	var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var reply=await ui.update({"op":"campaign","action":"sellInventory","args":[q.ownerId,q.itemId,q.count,q.token]})
	if ui.closing or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:return
	var remaining=c().get("characters",{}).get(q.ownerId,{}).get("inventory",{}).get(q.itemId,0)
	if reply.get("ok",false) and remaining==q.available-q.count and c().get("gold")==q.afterGold:
		message="%sの%s %d個を%dGで売却しました。" % [q.ownerName,q.name,q.count,q.proceeds];shop.stage="S0";quote_stamp="";shop.pages.invalidate_quote()
	else:await transaction_error(reply)
	ui.render()
