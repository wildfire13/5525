extends RefCounted
## Full-page character inspection; no inventory copy is kept in UI state.
var ui
var tab="equipment"
var picked: Dictionary={}
var owner=""
var busy=false
var allocating=false
var equip_slot=""
var inventory_column: Control
var page_body: Control
var preview_generation=0
var inventory_filter="all"
const Drag=preload("res://item_drag.gd")
const Tokens=preload("res://ui_tokens.gd")
func _init(frontend):ui=frontend
func refresh():
	if not is_instance_valid(page_body) or not page_body.is_inside_tree() or ui.page!="character":
		ui.render()
		return
	ui.refresh_panel(func():
		ui.clear(page_body)
		render(page_body)
		ui.mock_shell.refresh_roster_selection())

func render(parent):
	page_body=parent
	preview_generation+=1
	var members=ui.roster().filter(func(u):return ui.campaign().get("selected",[]).has(u.id))
	if members.is_empty():return
	if not members.any(func(u):return str(u.id)==ui.pages.party_uid):ui.pages.party_uid=str(ui.campaign().get("selected",[])[0])
	var member=members.filter(func(u):return str(u.id)==ui.pages.party_uid)[0]
	if owner!=str(member.id):owner=str(member.id);picked={};allocating=false
	var split=ui.mock_shell.columns(parent)
	split.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	var column=preload("res://member_loadout_column.gd").new()
	split.add_child(column)
	column.build(ui,member,tab,set_tab,"CharacterTab_",false,true,true)
	column.panel.name="CharacterLoadoutPanel"
	inventory_column=column if tab=="inventory" else null
	var art=column.portrait
	art.name="CharacterPortrait"
	if tab=="ability":
		column.render_ability(ui,member,true,"CharacterAbilityValues","",func(heading):
			var help=ui.button(heading,"",open_portrait.bind(member))
			help.name="CharacterPortraitHelp";help.tooltip_text="クリックで画像変更";help.accessibility_name="画像変更"
			help.icon=preload("res://assets/interface_icons/5525_help_icon_blue_v2.png")
			help.expand_icon=true;help.custom_minimum_size=Vector2(Tokens.BUTTON_MD,Tokens.BUTTON_MD);help.size_flags_horizontal=Control.SIZE_SHRINK_END;help.size_flags_vertical=Control.SIZE_SHRINK_CENTER)
		return
	if tab=="skills":
		column.render_skills(ui,member,"CharacterSkill_","CharacterSkillList")
		return
	if tab=="equipment":
		column.equipment(ui,member,picked.get("equipped_slot",""),"CharacterSlot_",select_equipped,payload)
	else:inventory(column.inventory_overlay(),member)
	if picked.is_empty():return
	var is_comparison=not picked.has("equipped_slot") and picked.get("kind")=="equipment"
	var detail_width=ui.mock_shell.grid_cell().x*(4 if is_comparison else 2)
	var right=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	split.add_child(right)
	var card=ui.card(right);card.get_parent().name="CharacterEquipmentDetail"
	var surface=Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_NONE);card.get_parent().add_theme_stylebox_override("panel",surface)
	card.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	card.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	card.get_parent().custom_minimum_size=Vector2(detail_width,ui.mock_shell.content_height())
	card.get_parent().size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var detail=ui.scroller(card)
	detail.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	if picked.has("equipped_slot"):
		equipped_detail(detail,owner,picked,busy)
	else:
		var footer_divider=ColorRect.new();footer_divider.color=Tokens.BORDER;footer_divider.custom_minimum_size.y=Tokens.BORDER_WIDTH;footer_divider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer_divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(footer_divider)
		var footer_margin=MarginContainer.new()
		for side in ["left","top","right","bottom"]:footer_margin.add_theme_constant_override("margin_"+side,Tokens.SPACE_SM)
		card.add_child(footer_margin)
		var actions=ui.row(footer_margin)
		var explanation=ui.button(actions,"詳しい説明",ui.show_equipment_details.bind(picked.duplicate(true)));explanation.name="CharacterItemDetails";explanation.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;Tokens.apply_button_size(explanation,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_MD)
		var discard=picked.get("discard",{})
		var remove=ui.button(actions,"捨てる",confirm_discard.bind(owner,picked.duplicate(true)),busy or not discard.get("ok",false));remove.name="CharacterDiscard";remove.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;remove.tooltip_text=str(discard.get("reason",""));Tokens.apply_button_size(remove,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_MD)
		if picked.get("kind")=="equipment":
			owned_comparison(detail,card,member,picked,Callable(),actions)
		else:
			var pad=MarginContainer.new();pad.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			for side in ["left","top","right","bottom"]:pad.add_theme_constant_override("margin_"+side,Tokens.SPACE_SM)
			detail.add_child(pad)
			var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",Tokens.SPACE_SM);pad.add_child(body)
			ui.icons.line(ui,body,str(picked.id) if picked.get("kind")!="quest" else "items",str(picked.get("name","")),true)
			ui.label_(body,"所持 %d個" % int(picked.get("count",1)))
			for option in picked.get("useTargets",[]):
				var control=ui.button(body,str(option.targetName)+"に使う",perform.bind(owner,str(picked.id),"use",option.targetId,1,null),busy or not option.ok);control.tooltip_text=str(option.get("reason",""))
				control.theme_type_variation=&"ActionButton"
				control.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
				Tokens.apply_button_size(control,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_LG)

func owned_comparison(detail,card,member,item,cancel:=Callable(),actions_row: HBoxContainer=null):
	var heading=ui.label_(detail,"装備変更",true)
	heading.add_theme_font_size_override("font_size",Tokens.FONT_HEADING)
	var heading_style=StyleBoxFlat.new()
	heading_style.bg_color=Color.TRANSPARENT
	heading_style.border_color=Tokens.BORDER
	heading_style.border_width_bottom=Tokens.BORDER_WIDTH
	heading_style.content_margin_left=Tokens.SPACE_SM
	heading_style.content_margin_right=Tokens.SPACE_SM
	heading_style.content_margin_top=Tokens.SPACE_SM
	heading_style.content_margin_bottom=Tokens.SPACE_SM
	heading.add_theme_stylebox_override("normal",heading_style)
	var comparison=ui.pages.shop_view.comparison_view
	var columns=comparison.equipment_columns(detail,"変更候補")
	var options=item.get("equipSlots",[])
	if options.is_empty():
		ui.label_(detail,"装備できる部位がありません");return
	if not options.any(func(q):return q.slot==equip_slot):equip_slot=str(options[0].slot)
	var selector=OptionButton.new();selector.name="CharacterEquipSlot";Tokens.apply_button_size(selector,Tokens.BUTTON_SM);columns[0].get_child(0).add_child(selector)
	for option in options:
		selector.add_item(str(ui.campaign().slots.get(option.slot,option.slot)));selector.set_item_metadata(selector.item_count-1,str(option.slot))
		if option.slot==equip_slot:selector.select(selector.item_count-1)
	selector.disabled=busy
	selector.item_selected.connect(func(i):equip_slot=str(selector.get_item_metadata(i));refresh())
	var summary=RichTextLabel.new();summary.name="CharacterEquipmentComparison";summary.bbcode_enabled=true;summary.fit_content=true;summary.scroll_active=false;summary.add_theme_color_override("default_color",Tokens.INK);detail.add_child(summary)

	var actions=actions_row
	if actions==null:
		actions=ui.row(card);actions.alignment=BoxContainer.ALIGNMENT_END
	else:
		var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;actions.add_child(spacer)
	var cancel_btn=ui.button(actions,"キャンセル",cancel if cancel.is_valid() else func():picked={};refresh(),busy);cancel_btn.name="CharacterEquipCancel";Tokens.apply_button_size(cancel_btn,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_MD)
	var equip=ui.action_button(ui.button(actions,"変更する",perform.bind(str(member.id),str(item.id),"equip",null,1,equip_slot),true))
	Tokens.apply_button_size(equip,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_MD);equip.size_flags_horizontal=Control.SIZE_SHRINK_END;equip.name="CharacterEquip";equip.tooltip_text=str(options[selector.selected].get("reason",""))
	preview(columns,summary,member,item,equip)

func equipped_detail(parent,uid,item,disabled):
	var pad=MarginContainer.new()
	pad.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","top","right","bottom"]:pad.add_theme_constant_override("margin_"+side,Tokens.SPACE_SM)
	parent.add_child(pad)
	var column=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",Tokens.SPACE_SM)
	pad.add_child(column)
	ui.pages.describe_gear(column,item.get("definition",item),true)
	if item.get("type")!="empty" and not item.get("occupied",false):
		var unequip=ui.button(column,"装備を外す",perform.bind(uid,str(item.id),"unequip",null,1,item.equipped_slot),disabled)
		unequip.theme_type_variation=&"ActionButton"
		unequip.name="UnequipItem"
		unequip.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		Tokens.apply_button_size(unequip,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_MD)

func select_equipped(item: Dictionary):
	picked=item
	refresh()

func inventory(parent,member):
	var list_ui=preload("res://member_inventory.gd")
	var filter=list_ui.add_filter(ui,parent,member,inventory_filter,func(value):inventory_filter=value;picked={};refresh())
	filter.name="CharacterInventoryFilter"
	var list=ui.scroller(parent)
	var entries=ui.campaign().get("inventoryByCharacter",{}).get(str(member.id),{}).get("entries",[])
	for entry in entries:
		if not list_ui.matches(entry,inventory_filter):continue
		var button=list_ui.add_row(ui,list,entry,func():picked=entry;refresh(),picked.get("id")==entry.id,busy)
		Drag.source(button,func():return payload(entry,"transfer",null),str(entry.name),button.icon)
	if list.get_child_count()==0:ui.label_(list,"アイテムはありません")

func payload(item,action,slot,source_owner=owner) -> Dictionary:
	var allowed=[]
	for uid in ui.campaign().get("selected",[]):
		if str(uid)==source_owner:continue
		var inventory=ui.campaign().get("inventoryByCharacter",{}).get(uid,{})
		var capacity=inventory.get("capacity",{})
		if capacity.get("limit")==null or int(capacity.get("used",0))<int(capacity.get("limit",0)) or inventory.get("entries",[]).any(func(e):return e.id==item.id):allowed.append(str(uid))
	if (ui.page=="character" and tab=="inventory" or ui.page=="shop" and ui.pages.shop_view.sale_mode()) and action=="transfer" and item.get("equipSlots",[]).any(func(q):return q.ok):allowed.append(source_owner)
	return {"allowed":allowed,"kind":"character_transfer","owner":source_owner,"item":str(item.id),"action":action,"slot":slot,"count":int(item.get("count",1)),"token":ui.campaign().get("inventoryToken"),"epoch":ui.pages.epoch,"connection":ui.engine.connection_generation}
func drag_entry(data) -> Dictionary:
	if not data is Dictionary or data.get("kind")!="character_transfer" or data.get("action")!="transfer" or busy or ui.locked or ui.presenting or ui.modal_open():return {}
	if ui.page!="character" or tab!="inventory" or data.get("owner")!=owner or data.get("connection")!=ui.engine.connection_generation or data.get("epoch")!=ui.pages.epoch or data.get("token")!=ui.campaign().get("inventoryToken"):return {}
	for item in ui.campaign().get("inventoryByCharacter",{}).get(owner,{}).get("entries",[]):
		if item.id==data.get("item"):return item
	return {}

func outside_drop(data,point: Vector2):
	var item=drag_entry(data)
	if item.is_empty() or not item.get("discard",{}).get("ok",false) or not is_instance_valid(inventory_column):return
	if not ui.get_viewport_rect().has_point(point) or inventory_column.get_global_rect().has_point(point):return
	var roster=ui.content.find_child("PartyRoster",true,false)
	if is_instance_valid(roster) and roster.get_global_rect().has_point(point):return
	confirm_outside_drop.call_deferred(data)

func confirm_outside_drop(data):
	var item=drag_entry(data)
	if item.get("discard",{}).get("ok",false):confirm_discard(owner,item)

func drop(data,target):
	if data.get("owner")==target:
		if ui.page=="shop":
			ui.pages.shop_view.preview_owned_drop(data)
			return
		var item=drag_entry(data)
		if not item.is_empty() and item.get("equipSlots",[]).any(func(q):return q.ok):
			picked=item;refresh()
		return
	if busy or data.get("token")!=ui.campaign().get("inventoryToken") or data.get("epoch")!=ui.pages.epoch:return
	if int(data.count)>1:
		ui.dialog.open("個数",func(body,actions):
			var count=SpinBox.new();count.min_value=1;count.max_value=int(data.count);count.value=int(data.count);body.add_child(count)
			ui.local_button(actions,"OK",func():var amount=int(count.value);ui.dialog.close();commit_drop(data,target,amount)).theme_type_variation=&"ActionButton"
			ui.local_button(actions,"キャンセル",ui.dialog.close))
	else:commit_drop(data,target,1)
func commit_drop(data,target,count):
	if data.get("token")!=ui.campaign().get("inventoryToken") or data.get("epoch")!=ui.pages.epoch:toast("状態が変わりました。もう一度選んでください");return
	perform(data.owner,data.item,data.action,target,count,data.slot)
func perform(uid,item,action,target,count,slot):
	if busy or ui.locked or ui.presenting:return
	busy=true
	var token=ui.campaign().get("inventoryToken");var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var response=await ui.engine.request({"op":"campaign","action":"inventoryQuote","args":[uid,item,action,target,count,slot]})
	var quote=response.get("inventoryQuote",{})
	if not quote.get("ok",false):busy=false;toast(str(quote.get("reason","操作できません")));return
	if token!=ui.campaign().get("inventoryToken") or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:busy=false;return
	var result=await ui.update({"op":"campaign","action":"inventoryAction","args":[uid,item,action,target,count,slot,quote.token]})
	busy=false
	if result.get("ok",false):picked={};toast(str(quote.name)+" ×"+str(count)+(" → "+ui.member_name(str(target)) if target!=null else "：更新しました"))
	else:toast(str(result.get("error","操作できません")))
	ui.render()
func toast(text):
	var panel=PanelContainer.new();panel.name="InventoryToast";panel.add_theme_stylebox_override("panel",ui.mock_shell.surface_style());ui.add_child(panel);panel.z_index=90
	preload("res://screen_grid.gd").place(panel,preload("res://screen_grid.gd").cell_rect(ui.size,7,8,3,1))
	var label=ui.label_(panel,text);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	ui.get_tree().create_timer(3).timeout.connect(panel.queue_free)
func preview(columns,text,member,item,equip):
	var chosen=equip_slot;var ticket=preview_generation;var token=ui.campaign().get("inventoryToken");var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	text.text="比較を確認中…"
	while ui.engine.busy:
		await ui.get_tree().process_frame
		if not is_instance_valid(text) or ticket!=preview_generation:return
	if ticket!=preview_generation:return
	var result=await ui.engine.request({"op":"campaign","action":"previewGear","args":[member.id,item.id,chosen]})
	if not is_instance_valid(text) or not text.is_inside_tree() or ticket!=preview_generation or token!=ui.campaign().get("inventoryToken") or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:return
	var quote=result.get("previewGear",{})
	if quote is Dictionary and quote.has("before"):
		# Keep skills visual; comparison heading identifies the exact selected slot.
		var comparison=ui.pages.shop_view.comparison_view
		var stats=["比較対象："+str(ui.campaign().get("slots",{}).get(chosen,chosen))]
		for change in comparison.stat_changes(member,quote):stats.append(comparison.change(change[0],change[1],change[2]))
		text.text="\n".join(stats).replace("#8ee6ab","#"+Tokens.POSITIVE.to_html(false)).replace("#ffb1a6","#"+Tokens.DANGER.to_html(false)).replace("#d5dbe2","#"+Tokens.MUTED_INK.to_html(false))
		text.hide()
		comparison.fill_columns(columns,quote)
		render_comparison_skills(columns[1],quote,columns[0])
		comparison.equipment_notes(columns[1],item.get("definition",item))
		equip.disabled=busy or not item.get("equipSlots",[]).any(func(q):return q.slot==chosen and q.ok);equip.set_meta("base_disabled",equip.disabled)
	else:
		text.show()
		text.text="比較を取得できません。選び直してください。"

func ability(parent,member,allow_allocation:=true):
	if allow_allocation and allocating:
		ui.pages.party_view.growth(parent,member)
		var back_btn=ui.button(parent,"戻る",end_allocation)
		Tokens.apply_button_size(back_btn,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_SM)
		return
	var values=parent
	var stats=member.get("stats",member)
	ui.label_(values,"HP %d/%d   MP %d/%d" % [int(member.get("hp",0)),int(member.get("max",0)),int(member.get("mp",0)),int(member.get("maxMp",0))])
	for key in ["str","int","agi","speed"]:
		var value=int(stats.get(key,0));var breakdown=stats.get("attributeBreakdown",{}).get(key,{})
		var delta=int(breakdown.get("equipment",0)) if key in ["str","int"] else value-int(stats.get("agi",value)) if key=="speed" else 0
		var line=ui.row(values);line.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;var base_label=ui.label_(line,("SPD" if key=="speed" else key.to_upper())+"  "+str(value));base_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;base_label.autowrap_mode=TextServer.AUTOWRAP_OFF
		var mod=ui.label_(line,"(%+d)" % delta);mod.autowrap_mode=TextServer.AUTOWRAP_OFF;mod.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;mod.add_theme_color_override("font_color",Tokens.POSITIVE if delta>0 else Tokens.DANGER if delta<0 else Tokens.MUTED_INK)
	if member.has("xp"):ui.label_(values,"EXP %d" % int(member.get("xp",0)))
	if member.has("race") or member.has("job"):ui.pages.party_view.identity(values,member)
	var attack=ui.icons.line(ui,values,"attack","通常ATK %d / 射程 %d" % [ui.pages.normal_atk(stats,1),ui.pages.normal_reach(stats)]);attack.name="CharacterAttackProfile";attack.tooltip_text=ui.pages.attack_profile(stats);attack.mouse_filter=Control.MOUSE_FILTER_STOP
	for defense in [false,true]:
		var line=ui.row(values);line.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		line.name="CharacterDefense" if defense else "CharacterElementalAttack"
		if defense:ui.icons.line(ui,line,"defend","DEF 物%d" % stats.get("def",0))
		else:ui.label_(line,"属性ATK").autowrap_mode=TextServer.AUTOWRAP_OFF
		for element in ["fire","water","earth"]:
			preload("res://element_badges.gd").add(line,element)
			var label=preload("res://element_badges.gd").spec(element).label
			ui.label_(line,"%s%d" % [label,stats.get(("def" if defense else "atk")+element.capitalize(),0)]).autowrap_mode=TextServer.AUTOWRAP_OFF
	var points=int(member.get("statPoints",0))
	if allow_allocation:
		var allocate=ui.button(parent,"能力を割り振る  "+str(points),func():allocating=true;refresh(),points<=0);allocate.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;Tokens.apply_button_size(allocate,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_MD)
	elif points>0:
		ui.label_(parent,"未割振ポイント  "+str(points))
func skills(parent,member,prefix:="CharacterSkill_"):
	var stats=member.get("stats",member);var names=ui.campaign().get("skillNames",{});var definitions=ui.campaign().get("skillDefinitions",{});var slot_names=ui.campaign().get("slots",{});var skill_text=preload("res://skill_text.gd")
	var columns=ui.scroller(parent)
	for group in [["active","アクティブスキル"],["passive","パッシブスキル"]]:
		if group[0]=="passive":columns.add_child(HSeparator.new())
		var content=VBoxContainer.new()
		content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		columns.add_child(content)
		var heading=ui.label_(content,group[1],true)
		heading.add_theme_font_size_override("font_size",Tokens.FONT_BODY)
		var grid=VBoxContainer.new();content.add_child(grid)
		var group_sources=[];var counts={}
		for source in stats.get("skillSources",member.get("skillSources",[])):
			var id=str(source.id);var classification=str(source.get("classification",definitions.get(id,{}).get("classification","passive")))
			if classification!=group[0]:continue
			group_sources.append(source)
			counts[id]=int(counts.get(id,0))+1
		for source in group_sources:
			var id=str(source.id);var level=int(source.get("level",1));var name=str(names.get(id,id));var slot_id=str(source.get("slot",""));var gear=member.get("equipmentDetails",{}).get(slot_id,{})
			var caption=name
			if int(counts.get(id,0))>1:
				var source_label=str(slot_names.get(slot_id,gear.get("name",slot_id)))
				var lv=" Lv%d" % level if skill_text.LEVELLED.has(id) else ""
				caption="%s%s（%s）" % [name,lv,source_label] if not source_label.is_empty() else "%s%s" % [name,lv]
			var button=ui.button(grid,caption,ui.show_skill_details.bind(id,name,level,gear));button.name=prefix+group[0]+"_"+id+"_"+slot_id;button.icon=ui.icons.texture(ui.icons.skill(id,level));button.expand_icon=true;button.clip_text=true;button.add_theme_constant_override("icon_max_width",40);button.custom_minimum_size=Vector2(280,Tokens.BUTTON_LG);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			preload("res://comparison_skill_icon.gd").bind_hover(button,id,name,level,ui.campaign(),gear)
		if grid.get_child_count()==0:ui.label_(content,"なし")

func set_tab(value: String):
	if value==tab:
		ui.mock_shell.toggle_character()
		return
	if not ui.pages.party_view.guard_leave(set_tab.bind(value)):return
	tab=value;picked={};allocating=false;refresh()
func end_allocation():
	if not ui.pages.party_view.guard_leave(end_allocation):return
	allocating=false;refresh()
func open_portrait(member: Dictionary):
	if not ui.pages.party_view.guard_leave(open_portrait.bind(member)):return
	ui.dialog.open(str(member.name)+"の画像",func(body,actions):
		var uid=str(member.id)
		var entry: Dictionary=ui.portraits.metadata.characters.get(uid,{})
		if not entry.is_empty():
			var editor=preload("res://portrait_editor.gd").new();body.add_child(editor)
			editor.name="PortraitFraming"
			editor.size_flags_vertical=Control.SIZE_EXPAND_FILL
			editor.setup(ui.portraits.image_for(member),entry.get("framing",{"zoom":1.0,"x":0.0,"y":0.0}))
			editor.custom_minimum_size.y=680
			var apply=ui.local_button(actions,"適用",func():
				if not ui.active_member(uid):return
				var updated=entry.duplicate(true);updated.framing=editor.framing.duplicate(true)
				ui.portraits.assign(uid,updated);ui.dialog.close();ui.render())
			apply.name="PortraitFramingApply";apply.theme_type_variation=&"ActionButton"
		else:
			var picture=ui.portrait(body,member,false,200);picture.custom_minimum_size=Vector2(300,680);picture.size_flags_vertical=Control.SIZE_EXPAND_FILL
		ui.local_button(actions,"画像変更",func():
			ui.dialog.close()
			ui.file_dialog(FileDialog.FILE_MODE_OPEN_FILE,PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.gif ; キャラ画像"]),func(path):
				await ui.import_portrait(path,uid)
				if ui.active_member(uid):open_portrait(member))).name="StatusChangePortrait"
		ui.local_button(actions,"閉じる",ui.dialog.close),Callable(),ui.preferences.overlay_rect(ui.size,Vector2(1400,860),16))
func render_comparison_skills(parent,quote: Dictionary,current=null):
	var helper=ui.pages.shop_view.comparison_view
	var before=quote.before.get("skillSources",[]);var after=quote.after.get("skillSources",[])
	for group in [["追加",helper.removed_sources(after,before),Tokens.POSITIVE],["失う",helper.removed_sources(before,after),Tokens.DANGER]]:
		if group[1].is_empty():continue
		var host=current if group[0]=="失う" and current!=null else parent
		ui.label_(host,group[0]+"スキル").add_theme_color_override("font_color",group[2])
		var line=HFlowContainer.new();line.add_theme_constant_override("h_separation",Tokens.SPACE_SM);host.add_child(line)
		for source in group[1]:
			var id=str(source.id);var level=int(source.get("level",1));var name_=str(ui.campaign().get("skillNames",{}).get(id,id))
			var gear=quote.get("gear",{}) if group[0]=="追加" else quote.get("current",{})
			var button=Button.new();line.add_child(button);button.name="CharacterComparisonSkill_"+group[0]+"_"+id;button.text="Lv%d" % level
			button.icon=helper.skill_texture(id,level);button.custom_minimum_size=Vector2(96,Tokens.BUTTON_LG);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40)
			preload("res://comparison_skill_icon.gd").bind_hover(button,id,name_,level,ui.campaign(),gear)
			button.pressed.connect(ui.show_skill_details.bind(id,name_,level,gear))

func confirm_discard(uid: String,item: Dictionary):
	if busy or ui.locked or ui.modal_open():return
	var token=ui.campaign().get("inventoryToken");var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	ui.dialog.open("アイテムを捨てる",func(body,actions):
		ui.label_(body,str(item.name))
		var count=SpinBox.new();count.name="CharacterDiscardQuantity";count.min_value=1;count.max_value=int(item.count);count.value=1;body.add_child(count)
		var confirm=ui.local_button(actions,"捨てる",func():
			var amount=int(count.value);ui.dialog.close()
			if token!=ui.campaign().get("inventoryToken") or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:toast("状態が変わりました。もう一度選んでください");return
			perform(uid,str(item.id),"discard",null,amount,null))
		confirm.name="CharacterDiscardConfirm";confirm.theme_type_variation=&"ActionButton"
		ui.local_button(actions,"キャンセル",ui.dialog.close))
