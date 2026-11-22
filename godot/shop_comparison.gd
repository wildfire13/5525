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
var panels: Array = []
var skill_rows
var buy_button
var inline_host: Control
func _init(owner):shop_ref=weakref(owner);ui=owner.ui
func invalidate():generation+=1
func item() -> Dictionary:
	for gear in shop.c().get("shop",[]):
		if gear.id==item_id:return gear
	return {}
func slots_for(gear: Dictionary) -> Array:
	return gear.get("allowedSlots",["rightHand"] if gear.get("hands",1)==2 else ["rightHand","leftHand"] if gear.slot=="weapon" else ["upperBody"] if gear.slot=="armor" else [gear.slot])
func render_inline(body: Control,actions: Control,id: String,uid: String):
	generation+=1;inline_host=body;item_id=id;owner_id=uid
	var gear=item()
	if gear.is_empty():return
	var choices=slots_for(gear)
	slot=ui.shop_slot if choices.has(ui.shop_slot) else str(choices[0])
	ui.shop_slot=slot;shop.mark_comparison_slot(slot)
	panels.clear()
	var comparison=RichTextLabel.new();comparison.name="ShopComparisonStats";comparison.bbcode_enabled=true;comparison.fit_content=true;comparison.scroll_active=false;comparison.add_theme_font_size_override("normal_font_size",22);comparison.add_theme_color_override("default_color",Color("#29332f"));comparison.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(comparison);comparison.text="比較を読み込み中…"
	panels=equipment_columns(body,"購入候補")
	if shop.c().get("location")=="north":
		var header=panels[0].get_child(0)
		var positions=OptionButton.new();positions.name="ShopComparisonSlot";positions.custom_minimum_size=Vector2(140,36);header.add_child(positions)
		for id_ in choices:
			positions.add_item(str(shop.c().get("slots",{}).get(id_,id_)));positions.set_item_metadata(positions.item_count-1,id_)
			if id_==slot:positions.select(positions.item_count-1)
		positions.item_selected.connect(func(i):switch_target(owner_id,str(positions.get_item_metadata(i))))
	skill_rows=null
	var conditions=ui.label_(body,"");conditions.name="ShopComparisonConditions";conditions.add_theme_font_size_override("font_size",20)
	# Keep payment/rejection beside the decision, outside long scrolling notes.
	var money=shop.checkout_fields(actions,gear.price,func():switch_target(owner_id,slot))
	var trial=ui.button(actions,"木人で試す",shop.start_trial.bind(item_id),shop.busy());trial.name="ProductTrial_"+item_id;trial.size_flags_horizontal=Control.SIZE_SHRINK_END;trial.custom_minimum_size.y=40;trial.add_theme_font_size_override("font_size",20)
	var buy=ui.primary(ui.button(actions,"取引を確認",purchase,true));buy.name="ShopComparisonBuy";buy.custom_minimum_size.y=40;buy.size_flags_horizontal=Control.SIZE_SHRINK_END
	money_label=money;comparison_label=comparison;condition_label=conditions;buy_button=buy
	refresh(money,comparison,conditions,buy)
func equipment_notes(body: Control,gear: Dictionary):
	# Mechanics in the original equipment note must remain visible at purchase.
	var note=str(gear.get("note","")).strip_edges()
	var flavor=str(gear.get("flavor","")).strip_edges()
	if not flavor.is_empty() and not note.contains(flavor):
		var description=ui.label_(body,flavor);description.name="ShopComparisonFlavor";description.add_theme_font_size_override("font_size",20)
	if not note.is_empty():
		var memo=ui.label_(body,note);memo.name="ShopComparisonNotes";memo.add_theme_font_size_override("font_size",20)

func equipment_columns(body: Control,candidate: String) -> Array:
	var pair=ui.row(body);pair.name="ShopComparisonSkills"
	pair.add_theme_constant_override("separation",0)
	pair.custom_minimum_size.y=ui.mock_shell.grid_cell().y*5
	var columns=[]
	for heading in ["現在の装備",candidate]:
		var scroll=ScrollContainer.new()
		scroll.name="ComparisonCurrentColumn" if columns.is_empty() else "ComparisonCandidateColumn"
		scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		pair.add_child(scroll)
		var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
		ui.label_(ui.row(column),heading)
		columns.append(column)
	return columns

func fill_columns(columns: Array,q: Dictionary):
	var rows=equipment_rows(q.current,q.gear)
	for i in range(2):
		var panel=columns[i]
		while panel.get_child_count()>1:
			var child=panel.get_child(-1);panel.remove_child(child);child.queue_free()
		var gear=q.get("current" if i==0 else "gear",{})
		gear_summary(panel,gear,rows[i],i==1)

func gear_summary(parent,gear: Dictionary,rows: Array,candidate:=false):
	var label=ui.local_button(parent,str(gear.get("name","なし")),func():pass)
	label.icon=ui.icons.texture(ui.icons.equipment(gear));label.expand_icon=true;label.add_theme_constant_override("icon_max_width",40)
	if candidate:
		label.name="ShopComparisonProduct";label.add_theme_font_size_override("font_size",28)
	preload("res://equipment_tooltip.gd").bind_details(label,ui,gear)
	for line in rows:ui.label_(parent,line)

func open(id: String):
	panels.clear();inline_host=null;item_id=id
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
	buy.theme_type_variation=&"ActionButton"
	money_label=money;comparison_label=comparison;condition_label=conditions;buy_button=buy
	refresh(money,comparison,conditions,buy)
func switch_target(uid: String,position: String):
	generation+=1;owner_id=uid;slot=position;ui.shop_uid=uid;ui.shop_slot=position
	if is_instance_valid(inline_host):
		shop.mark_comparison_slot(position)
		var selector=inline_host.find_child("ShopComparisonSlot",true,false)
		if selector!=null:
			for index in range(selector.item_count):
				if selector.get_item_metadata(index)==position:selector.select(index);break
	# Keep the selectors alive: replacing an open popup can replay Enter on the
	# new control and lose keyboard focus. Clear old values before any request.
	comparison_label.text="比較を読み込み中…";money_label.text="費用を確認中…";condition_label.text="条件を確認中…"
	if panels.is_empty():ui.clear(skill_rows)
	comparison_label.show()
	buy_button.disabled=true;buy_button.set_meta("base_disabled",true)
	refresh(money_label,comparison_label,condition_label,buy_button)
func valid(ticket: int,window,epoch: int,connection: int,token) -> bool:
	return ticket==generation and is_instance_valid(window) and (window==inline_host and window.is_inside_tree() or window==ui.dialog.window) and ui.page=="shop" and not ui.closing and epoch==ui.pages.epoch and connection==ui.engine.connection_generation and token==shop.c().get("inventoryToken")
func refresh(money,comparison,conditions,buy):
	var ticket=generation;var window=inline_host if is_instance_valid(inline_host) else ui.dialog.window;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var token=shop.c().get("inventoryToken")
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
	comparison.text=comparison_text(person,entry,slot,q).replace("#8ee6ab","#277242").replace("#ffb1a6","#a84432").replace("#d5dbe2","#6e786f")
	if not panels.is_empty():
		comparison.hide()
		fill_columns(panels,q)
	render_skills(q)
	if not panels.is_empty():equipment_notes(panels[1],item())
	conditions.text="" if q.get("eligible",false) else "装備不可："+str(q.get("reason","正規判定を確認できません"))
	var payment=await ui.engine.request({"op":"campaign","action":"purchaseQuote","args":[item_id,owner_id,shop.purchase_quantity if not panels.is_empty() else 1]})
	if not valid(ticket,window,epoch,connection,token):return
	if ui.handle_connection_loss(payment,connection):return
	var cost=payment.get("purchaseQuote",{})
	if cost.is_empty():money.text="費用を取得できません。";return
	shop.display_payment(money,buy,cost)

func purchase():
	if shop.busy() or (is_instance_valid(inline_host) and ui.modal_open()):return
	var id=item_id;var uid=owner_id
	invalidate();ui.dialog.close(false)
	shop.confirm_purchase(id,uid,shop.purchase_quantity if not panels.is_empty() else 1,not panels.is_empty())

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
	if panels.is_empty():ui.clear(skill_rows)
	var before=q.before.get("skillSources",[]);var after=q.after.get("skillSources",[])
	for group in [["追加",removed_sources(after,before),"#277242"],["失う",removed_sources(before,after),"#a84432"]]:
		if group[1].is_empty():continue
		var parent=skill_rows if panels.is_empty() else panels[1 if group[0]=="追加" else 0]
		var label=ui.label_(parent,group[0]+"スキル");label.add_theme_color_override("font_color",Color(group[2]))
		var line=HFlowContainer.new();line.add_theme_constant_override("h_separation",8);parent.add_child(line)
		for source in group[1]:
			var id=str(source.id);var level=int(source.get("level",1));var name_=str(shop.c().get("skillNames",{}).get(id,id))
			var gear=q.get("gear",{}) if group[0]=="追加" else q.get("current",{})
			var button=Button.new();line.add_child(button);button.name="ComparisonSkill_"+group[0]+"_"+id+"_"+str(line.get_child_count());button.text="Lv%d" % level
			button.custom_minimum_size=Vector2(96,52);button.icon=skill_texture(id,level);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40)
			preload("res://comparison_skill_icon.gd").bind_hover(button,id,name_,level,shop.c(),gear)
			button.pressed.connect(ui.show_skill_details.bind(id,name_,level,gear))

func skill_texture(id: String,level: int) -> Texture2D:
	# Older adopted recipes may only have a Lv1 badge. Use the unchanged art
	# without that badge; the adjacent Lv label remains the authoritative level.
	var spec: Dictionary=ui.icons.approved.skills.get(id,{})
	if not spec.is_empty() and not spec.get("levels",{}).has(str(level)):
		return ImageTexture.create_from_image(ui.icons.fit_image(ui.icons.approved_image(spec),64))
	return ui.icons.texture(ui.icons.skill(id,level))

func equipment_escape(value) -> String:return str(value).replace("[","[lb]")
static func equipment_rows(current: Dictionary,candidate: Dictionary) -> Array:
	var rows=[[],[]]
	var fields={"atk":"物理ATK","reach":"武器射程","def":"物理DEF","atkFire":"火ATK","atkWater":"水ATK","atkEarth":"地ATK","defFire":"火DEF","defWater":"水DEF","defEarth":"地DEF","hp":"HP上限","mp":"MP上限","agiBonus":"行動速度補正"}
	for field in fields:
		var values=[]
		for gear in [current,candidate]:
			var value=int(gear.get(field,0))
			if gear.get("type")=="empty" or (field=="reach" and gear.get("slot")!="weapon"):
				value=0
			values.append(value)
		var delta=int(values[1])-int(values[0])
		if values[0]!=0:
			rows[0].append("%s：%d" % [fields[field],values[0]])
		if values[1]!=0 or delta!=0:
			var suffix="" if delta==0 else "（%s%d）" % ["↑" if delta>0 else "↓",absi(delta)]
			rows[1].append("%s：%d%s" % [fields[field],values[1],suffix])
	return rows
func change(title: String,before,after) -> String:
	var delta=int(after)-int(before);var color="#8ee6ab" if delta>0 else "#ffb1a6" if delta<0 else "#d5dbe2"
	return "%s: %d → %d [color=%s](%+d)[/color]" % [title,before,after,color,delta]
func stat_changes(u: Dictionary,q: Dictionary) -> Array:
	var a: Dictionary=q.before;var z: Dictionary=q.after;
	var lines=[]
	for pair in [["HP上限","max"],["MP上限","maxMp"],["行動速度","speed"],["物理DEF","def"],["火DEF","defFire"],["水DEF","defWater"],["地DEF","defEarth"],["火ATK","atkFire"],["水ATK","atkWater"],["地ATK","atkEarth"]]:
		if int(a.get(pair[1],0))!=int(z.get(pair[1],0)):lines.append([pair[0],a.get(pair[1],0),z.get(pair[1],0)])
	var before_reach=ui.pages.normal_reach(a);var after_reach=ui.pages.normal_reach(z)
	if before_reach!=after_reach:lines.append(["通常射程",before_reach,after_reach])
	for distance in range(1,maxi(before_reach,after_reach)+1):
		var before_atk=ui.pages.normal_atk(a,distance);var after_atk=ui.pages.normal_atk(z,distance)
		if before_atk!=after_atk:lines.append(["通常ATK 距離%d" % distance,before_atk,after_atk])
	for pair in [["現在HP","hp","max"],["現在MP","mp","maxMp"]]:
		var before=int(u.get(pair[1],0));var after=mini(before,int(z.get(pair[2],before)))
		if before!=after:lines.append([pair[0],before,after])
	return lines
func comparison_text(u: Dictionary,entry: Dictionary,chosen: String,q: Dictionary) -> String:
	var lines=[]
	for stat in stat_changes(u,q):lines.append(change(stat[0],stat[1],stat[2]))
	for candidate in entry.equipSlots:
		if candidate.slot==chosen and not candidate.ok:lines.append("装備不可: "+equipment_escape(candidate.reason))
	var heading="現在：%s → 候補：%s" % [equipment_escape(q.get("current",{}).get("name","現在の装備")),equipment_escape(entry.get("name",q.get("gear",{}).get("name","候補装備")))]
	return heading+"\n"+("\n".join(lines) if not lines.is_empty() else "能力値の変化なし")
