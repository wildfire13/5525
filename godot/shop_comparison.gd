extends RefCounted
## Read-only canonical quotes; purchase still uses the existing consent flow.
var shop_ref: WeakRef
var shop:
	get:return shop_ref.get_ref()
var ui
var item_id := ""
var owner_id := ""
var slot := ""
var generation := 0
var money_label
var comparison_label
var condition_label
var skill_rows
var buy_button
func _init(owner):shop_ref=weakref(owner);ui=owner.ui
func invalidate():generation+=1
func item() -> Dictionary:
	for gear in shop.c().get("shop",[]):
		if gear.id==item_id:return gear
	return {}
func slots_for(gear: Dictionary) -> Array:
	return gear.get("allowedSlots",["rightHand"] if gear.get("hands",1)==2 else ["rightHand","leftHand"] if gear.slot=="weapon" else ["upperBody"] if gear.slot=="armor" else [gear.slot])
func open(id: String):
	item_id=id
	var gear=item()
	if gear.is_empty():return
	if not shop.c().get("selected",[]).has(ui.shop_uid):ui.shop_uid=str(shop.c().selected[0])
	owner_id=ui.shop_uid
	var slots=slots_for(gear)
	slot=ui.shop_slot if slots.has(ui.shop_slot) else str(slots[0])
	ui.dialog.open("商品と装備の比較",func(_body,actions):
		ui.local_button(actions,"商品一覧へ戻る",ui.dialog.close).name="ShopComparisonBack",
		invalidate)
	render()
func render():
	generation+=1
	var body=ui.dialog.body;ui.clear(body)
	var gear=item()
	if gear.is_empty():ui.dialog.close();return
	var title=ui.label_(body,str(gear.name),true);title.name="ShopComparisonProduct"
	var selectors=ui.row(body)
	ui.label_(selectors,"対象")
	var people=OptionButton.new();people.name="ShopComparisonOwner";people.fit_to_longest_item=false;people.clip_text=true;people.size_flags_horizontal=Control.SIZE_EXPAND_FILL;people.custom_minimum_size.x=150;selectors.add_child(people)
	for uid in shop.c().selected:
		people.add_item(ui.member_name(str(uid)));people.set_item_metadata(people.item_count-1,uid)
		if uid==owner_id:people.select(people.item_count-1)
	people.item_selected.connect(func(i):switch_target(str(people.get_item_metadata(i)),slot))
	var slots=slots_for(gear)
	var positions=OptionButton.new();positions.name="ShopComparisonSlot";positions.size_flags_horizontal=Control.SIZE_EXPAND_FILL;positions.custom_minimum_size.x=130;selectors.add_child(positions)
	for id in slots:
		positions.add_item(str(shop.c().get("slots",{}).get(id,id)));positions.set_item_metadata(positions.item_count-1,id)
		if id==slot:positions.select(positions.item_count-1)
	positions.item_selected.connect(func(i):switch_target(owner_id,str(positions.get_item_metadata(i))))
	var money=ui.label_(body,"費用を確認中…");money.name="ShopComparisonPayment"
	var comparison=RichTextLabel.new();comparison.name="ShopComparisonStats";comparison.bbcode_enabled=true;comparison.fit_content=true;comparison.scroll_active=false;comparison.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(comparison);comparison.text="比較を読み込み中…"
	skill_rows=VBoxContainer.new();skill_rows.name="ShopComparisonSkills";body.add_child(skill_rows)
	var conditions=ui.label_(body,"条件を確認中…");conditions.name="ShopComparisonConditions"
	if not str(gear.get("flavor","")).is_empty():
		ui.label_(body,"説明\n"+str(gear.flavor)).name="ShopComparisonFlavor"
	if gear.has("note") and not str(gear.note).is_empty():
		ui.label_(body,"装備メモ（原文）\n"+str(gear.note)).name="ShopComparisonNotes"
	var buy=ui.button(ui.dialog.actions,"確認中…",purchase,true);buy.name="ShopComparisonBuy";ui.icons.apply(buy,"money");buy.size_flags_horizontal=Control.SIZE_SHRINK_END;buy.custom_minimum_size.x=220
	money_label=money;comparison_label=comparison;condition_label=conditions;buy_button=buy
	refresh(money,comparison,conditions,buy)
func switch_target(uid: String,position: String):
	generation+=1;owner_id=uid;slot=position;ui.shop_uid=uid;ui.shop_slot=position
	# Keep the selectors alive: replacing an open popup can replay Enter on the
	# new control and lose keyboard focus. Clear old values before any request.
	comparison_label.text="比較を読み込み中…";money_label.text="費用を確認中…";condition_label.text="条件を確認中…"
	ui.clear(skill_rows);buy_button.disabled=true;buy_button.set_meta("base_disabled",true)
	refresh(money_label,comparison_label,condition_label,buy_button)
func valid(ticket: int,window,epoch: int,connection: int,token) -> bool:
	return ticket==generation and is_instance_valid(window) and window==ui.dialog.window and ui.page=="shop" and not ui.closing and epoch==ui.pages.epoch and connection==ui.engine.connection_generation and token==shop.c().get("inventoryToken")
func refresh(money,comparison,conditions,buy):
	var ticket=generation;var window=ui.dialog.window;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var token=shop.c().get("inventoryToken")
	while ui.engine.busy:
		await ui.get_tree().process_frame
		if not valid(ticket,window,epoch,connection,token):return
	var reply=await ui.engine.request({"op":"campaign","action":"previewGear","args":[owner_id,item_id,slot]})
	if not valid(ticket,window,epoch,connection,token):return
	if ui.handle_connection_loss(reply,connection):return
	var q=reply.get("previewGear")
	if not q is Dictionary or not q.has("before"):
		comparison.text="比較を取得できません。商品一覧へ戻って選び直してください。";conditions.text="条件：未確認";return
	var person={}
	for u in ui.roster():
		if u.id==owner_id:person=u;break
	var entry={"name":item().name,"equipSlots":[]}
	comparison.text=ui.pages.party_view.owned_equipment_view.comparison(person,entry,slot,q,true)
	render_skills(q)
	conditions.text="条件：装備可能" if q.get("eligible",false) else "条件：装備不可 / "+str(q.get("reason","正規判定を確認できません"))
	var payment=await ui.engine.request({"op":"campaign","action":"purchaseQuote","args":[item_id,owner_id]})
	if not valid(ticket,window,epoch,connection,token):return
	if ui.handle_connection_loss(payment,connection):return
	var cost=payment.get("purchaseQuote",{})
	if cost.is_empty():money.text="費用を取得できません。";return
	money.text="1個 / 支払 %dG / 所持金 %d → 購入後 %dG" % [cost.cost,cost.goldBefore,cost.afterGold] if cost.get("ok",false) else "購入不可："+str(cost.reason)+" / 価格 %dG / 所持金 %dG" % [cost.cost,cost.goldBefore]
	buy.text="%dGで購入する" % int(cost.cost)
	buy.disabled=not cost.get("ok",false) or shop.busy();buy.set_meta("base_disabled",buy.disabled)
	buy.tooltip_text="購入品はインベントリへ入ります。" if not buy.disabled else str(cost.get("reason","購入できません"))
	for state in ["normal","hover","pressed","disabled"]:
		var style=StyleBoxFlat.new();style.bg_color=Color("#246044") if not buy.disabled else Color("#783b3b");style.set_corner_radius_all(5);style.set_content_margin_all(8);buy.add_theme_stylebox_override(state,style)
	buy.add_theme_color_override("font_disabled_color",Color.WHITE)
func purchase():
	if shop.busy():return
	var id=item_id;var uid=owner_id
	invalidate();ui.dialog.close(false)
	shop.confirm_purchase(id,uid)

func source_key(source: Dictionary) -> String:
	return str(source.id)+":"+str(int(source.get("level",1)))
func removed_sources(before: Array,after: Array) -> Array:
	var remaining=after.duplicate(true);var result=[]
	for source in before:
		var found=-1
		for i in range(remaining.size()):
			if source_key(source)==source_key(remaining[i]):found=i;break
		if found<0:result.append(source)
		else:remaining.remove_at(found)
	return result
func render_skills(q: Dictionary):
	ui.clear(skill_rows)
	var before=q.before.get("skillSources",[]);var after=q.after.get("skillSources",[])
	for group in [["追加",removed_sources(after,before),"#8ee6ab"],["失う",removed_sources(before,after),"#ffb1a6"]]:
		if group[1].is_empty():continue
		var label=ui.label_(skill_rows,group[0]+"スキル");label.add_theme_color_override("font_color",Color(group[2]))
		var line=HFlowContainer.new();line.add_theme_constant_override("h_separation",8);skill_rows.add_child(line)
		for source in group[1]:
			var id=str(source.id);var level=int(source.get("level",1));var name_=str(shop.c().get("skillNames",{}).get(id,id))
			var gear=q.get("gear",{}) if group[0]=="追加" else q.get("current",{})
			var doc=preload("res://skill_text.gd").document(id,name_,level,shop.c(),gear)
			var button=preload("res://comparison_skill_icon.gd").new();line.add_child(button);button.name="ComparisonSkill_"+group[0]+"_"+id+"_"+str(line.get_child_count());button.text="Lv%d" % level
			button.custom_minimum_size=Vector2(96,52);button.icon=skill_texture(id,level);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40)
			button.tooltip_text=group[0]+"："+str(shop.c().get("slots",{}).get(source.get("slot",""),source.get("slot","")))+" / 付与枠%d\n" % int(source.get("grantSlot",1))+preload("res://skill_text.gd").plain(doc)
			button.pressed.connect(func():
				var detail=preload("res://skill_details.gd").new();ui.dialog.window.add_child(detail);detail.configure(ui,doc,group[0]+"スキル / "+name_))

func skill_texture(id: String,level: int) -> Texture2D:
	# Older adopted recipes may only have a Lv1 badge. Use the unchanged art
	# without that badge; the adjacent Lv label remains the authoritative level.
	var spec: Dictionary=ui.icons.approved.skills.get(id,{})
	if not spec.is_empty() and not spec.get("levels",{}).has(str(level)):
		return ImageTexture.create_from_image(ui.icons.fit_image(ui.icons.approved_image(spec),64))
	return ui.icons.texture(ui.icons.skill(id,level))
