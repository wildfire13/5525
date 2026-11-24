extends VBoxContainer
## Shared 4-tab character sheet (equipment, inventory, ability, skills) reused
## across Party Info, Shop, Warehouse, Guild, and Battle Loadout Modal.
const Tokens=preload("res://ui_tokens.gd")
const ART_SIZE := Vector2(384,760)
const SLOT_POSITIONS := {
	"head": Vector2(148,16), "rightHand": Vector2(28,152),
	"upperBody": Vector2(148,152), "leftHand": Vector2(268,152),
	"lowerBody": Vector2(148,296), "feet": Vector2(148,440),
	"accessory1": Vector2(88,584), "accessory2": Vector2(208,584)
}

var stage: Control
var equipment_layer: Control
var portrait: TextureRect
var panel: PanelContainer
var stage_height_px := 0.0

static func align_column(column: Control):
	column.custom_minimum_size.x=preload("res://screen_grid.gd").cell_rect(Vector2(column.get_tree().root.size),0,0,2,1).size.x
	column.size_flags_horizontal=(column.size_flags_horizontal & Control.SIZE_EXPAND) | Control.SIZE_SHRINK_BEGIN

func build(ui, member: Dictionary, tab: String, choose: Callable, prefix: String, disabled:=false, character_tabs:=true, framed_tabs:=true, total_height:=-1.0):
	align_column(self)
	add_theme_constant_override("separation",Tokens.SPACE_NONE)
	var column_height=ui.mock_shell.content_height() if total_height<0.0 else total_height
	custom_minimum_size.y=column_height
	if framed_tabs:
		var display=ui.card(self)
		panel=display.get_parent();panel.name="MemberLoadoutPanel"
		panel.add_theme_stylebox_override("panel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_NONE))
		panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		display.add_theme_constant_override("separation",Tokens.SPACE_NONE)
		var inset=MarginContainer.new();inset.name="LoadoutTabBar";display.add_child(inset)
		var tab_height=ui.mock_shell.grid_cell().y
		inset.custom_minimum_size.y=tab_height
		inset.add_theme_constant_override("margin_left",Tokens.SPACE_SM)
		inset.add_theme_constant_override("margin_right",Tokens.SPACE_SM)
		inset.add_theme_constant_override("margin_top",Tokens.SPACE_XS)
		inset.add_theme_constant_override("margin_bottom",Tokens.SPACE_XS)
		var tab_stack=VBoxContainer.new();tab_stack.alignment=BoxContainer.ALIGNMENT_CENTER;tab_stack.add_theme_constant_override("separation",Tokens.SPACE_XS);inset.add_child(tab_stack)
		add_tabs(ui,tab_stack,[["equipment","装備"],["inventory","インベントリ"]],tab,choose,prefix,disabled,0)
		if character_tabs:
			add_tabs(ui,tab_stack,[["ability","能力"],["skills","スキル"]],tab,choose,prefix,disabled,0)
		build_art(ui,display,member,maxf(1.0,column_height-tab_height))
		if tab=="equipment": stage.name="RegionEquipment"
		elif tab=="inventory": stage.name="RegionInventory"
		return
	var inset=MarginContainer.new();inset.name="LoadoutTabBar";add_child(inset)
	inset.custom_minimum_size.y=ui.mock_shell.grid_cell().y
	add_tabs(ui,inset,[["equipment","装備"],["inventory","インベントリ"]],tab,choose,prefix,disabled)
	var display=ui.card(self)
	panel=display.get_parent();panel.name="MemberLoadoutPanel"
	var grid_style=Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_NONE)
	panel.add_theme_stylebox_override("panel",grid_style)
	display.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if character_tabs:
		add_tabs(ui,display,[["ability","能力"],["skills","スキル"]],tab,choose,prefix,disabled).name="CharacterInfoTabs"
	else:
		var spacer=Control.new();spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
		spacer.custom_minimum_size.y=ui.mock_shell.grid_cell().y
		display.add_child(spacer)
	build_art(ui,display,member)
	if tab=="equipment": stage.name="RegionEquipment"
	elif tab=="inventory": stage.name="RegionInventory"

func add_tabs(ui,parent,entries,tab,choose,prefix,disabled,row_height:=-1):
	var tabs=ui.row(parent)
	tabs.custom_minimum_size.y=ui.mock_shell.grid_cell().y if row_height<0 else row_height
	for entry in entries:
		var button=ui.button(tabs,entry[1],choose.bind(entry[0]),disabled)
		button.name=prefix+entry[0]
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		Tokens.apply_button_size(button)
		ui.mark_selected(button,tab==entry[0])
	return tabs

func build_art(ui,display,member,stage_height:=-1.0):
	var height=ui.mock_shell.content_height()-ui.mock_shell.grid_cell().y*2 if stage_height<0 else stage_height
	stage_height_px=height
	stage=Control.new()
	stage.custom_minimum_size=Vector2(custom_minimum_size.x,height)
	stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stage.clip_contents=true
	display.add_child(stage)
	equipment_layer=Control.new()
	equipment_layer.name="EquipmentLayer"
	equipment_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	equipment_layer.size=ART_SIZE
	stage.add_child(equipment_layer)
	if not member.is_empty():
		portrait=ui.portrait(equipment_layer,member,false,1)
		portrait.position=Vector2(0,8)
		portrait.size=Vector2(ART_SIZE.x,minf(ART_SIZE.y,maxf(1.0,height-16.0))) if stage_height>0 else ART_SIZE
		portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		portrait.modulate.a=.22
	else:
		portrait=null
	fit_stage_height(height)

func fit_stage_height(height: float):
	stage_height_px=height
	if not is_instance_valid(equipment_layer):return
	var scale_factor=1.0
	if height>0.0 and height<700.0:
		scale_factor=minf(custom_minimum_size.x/ART_SIZE.x,height/704.0)
	equipment_layer.scale=Vector2.ONE*scale_factor
	equipment_layer.position=Vector2((custom_minimum_size.x-ART_SIZE.x*scale_factor)*0.5,0.0)
	if is_instance_valid(portrait):
		portrait.size=Vector2(ART_SIZE.x,minf(ART_SIZE.y,maxf(1.0,(height/scale_factor)-16.0))) if height>0.0 else ART_SIZE

func inventory_overlay() -> VBoxContainer:
	var overlay=VBoxContainer.new()
	stage.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay

func render_ability(ui, member: Dictionary, allow_allocation:=false, scroll_name:="", memory_key:="", header_extra: Callable=Callable()) -> VBoxContainer:
	var overlay=inventory_overlay()
	var values=ui.scroller(overlay)
	var scroll=values.get_parent() as ScrollContainer
	var pad=StyleBoxEmpty.new()
	pad.content_margin_left=Tokens.SPACE_SM;pad.content_margin_right=Tokens.SPACE_SM
	pad.content_margin_top=Tokens.SPACE_SM;pad.content_margin_bottom=Tokens.SPACE_SM
	scroll.add_theme_stylebox_override("panel",pad)
	if not scroll_name.is_empty():scroll.name=scroll_name
	if not memory_key.is_empty():ui.memory.watch(scroll,memory_key)
	var heading=ui.row(values)
	ui.label_(heading,str(member.get("name",""))+" / Lv."+str(int(member.get("level",1))),true)
	if header_extra.is_valid():header_extra.call(heading)
	ui.pages.party_view.workspace.ability(values,member,allow_allocation)
	return values

func render_skills(ui, member: Dictionary, prefix:="CharacterSkill_", host_name:="CharacterSkillList") -> VBoxContainer:
	var overlay=inventory_overlay()
	if not host_name.is_empty():overlay.name=host_name
	var pad=MarginContainer.new()
	pad.size_flags_vertical=Control.SIZE_EXPAND_FILL
	pad.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:pad.add_theme_constant_override("margin_"+side,Tokens.SPACE_SM)
	overlay.add_child(pad)
	var host=VBoxContainer.new()
	host.size_flags_vertical=Control.SIZE_EXPAND_FILL
	host.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	pad.add_child(host)
	ui.pages.party_view.workspace.skills(host,member,prefix)
	return host

func render_readonly_inventory(ui, member: Dictionary, prefix:="", on_select: Callable=Callable(), entries_override=null, list_name:="", empty_text:="アイテムはありません", bind_click_details:=true) -> VBoxContainer:
	var overlay=inventory_overlay()
	var list=ui.scroller(overlay)
	var scroll=list.get_parent() as ScrollContainer
	var pad=StyleBoxEmpty.new()
	pad.content_margin_left=Tokens.SPACE_SM;pad.content_margin_right=Tokens.SPACE_SM
	pad.content_margin_top=Tokens.SPACE_XS;pad.content_margin_bottom=Tokens.SPACE_XS
	scroll.add_theme_stylebox_override("panel",pad)
	if not list_name.is_empty():list.name=list_name
	var entries: Array=entries_override if entries_override is Array else ui.campaign().get("inventoryByCharacter",{}).get(str(member.get("id","")),{}).get("entries",[])
	var inv_helper=preload("res://member_inventory.gd")
	for entry in entries:
		var item: Dictionary=entry.duplicate(true)
		var callback=on_select.bind(item) if on_select.is_valid() else func():pass
		var button: Button
		if bind_click_details:
			button=inv_helper.add_row(ui,list,item,callback,false,false)
		else:
			var count=int(item.get("count",1))
			var weight=item.get("definition",{}).get("weight",item.get("weight"))
			var total=str(snappedf(float(weight)*count,0.01)).trim_suffix(".0") if weight!=null else "不明"
			button=ui.button(list,"%s  ×%d　Wt %s" % [item.get("name",""),count,total],callback,false)
			button.alignment=HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y=Tokens.BUTTON_LG
			button.clip_text=true
			button.tooltip_text=str(item.get("name",""))
			var icon=ui.icons.equipment(item) if item.get("kind")=="equipment" else "items" if item.get("kind")=="quest" else str(item.get("id",""))
			button.icon=ui.icons.texture(icon)
			button.expand_icon=true
			button.add_theme_constant_override("icon_max_width",40)
			preload("res://equipment_tooltip.gd").bind_hover(button,item,ui.campaign())
		if not prefix.is_empty():button.name=prefix+str(item.get("id",""))
	if list.get_child_count()==0:ui.label_(list,empty_text)
	return list

func equipment(ui,member: Dictionary,selected_slot: String,prefix: String,choose: Callable,drag: Callable=Callable(),disabled:=false,click_details:=true):
	var host=equipment_layer if is_instance_valid(equipment_layer) else stage
	for slot in ordered_slots(member):
		var item=slot_item(ui,member,slot)
		var button=ui.button(host,"",choose.bind(item) if not disabled else func():pass,false)
		button.name=prefix+str(slot.slot)
		button.position=SLOT_POSITIONS[slot.slot]
		button.custom_minimum_size=Vector2(88,88)
		button.size=button.custom_minimum_size
		button.tooltip_text=str(slot.label)+" / "+str(item.name)
		ui.mark_selected(button,selected_slot==slot.slot)
		button.icon=ui.icons.texture(ui.icons.equipment(item))
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",68)
		if item.get("type")!="empty":
			if click_details:preload("res://equipment_tooltip.gd").bind_details(button,ui,item)
			else:
				var hover_entry=item.duplicate(true)
				if not hover_entry.has("definition"):hover_entry={"id":hover_entry.get("id",""),"name":hover_entry.get("name",""),"kind":"equipment","count":1,"definition":hover_entry}
				preload("res://equipment_tooltip.gd").bind_hover(button,hover_entry,ui.campaign())
		var caption=ui.label_(host,str(slot.label))
		caption.position=button.position+Vector2(0,90)
		caption.size=Vector2(90,12)
		caption.autowrap_mode=TextServer.AUTOWRAP_OFF
		caption.add_theme_font_size_override("font_size",Tokens.FONT_SM)
		if drag.is_valid() and item.get("type")!="empty" and not item.occupied:
			preload("res://item_drag.gd").source(button,drag.bind(item,"transferEquipped",str(slot.slot)),str(item.name),button.icon)

static func ordered_slots(member: Dictionary) -> Array:
	var ordered=[]
	var slots=member.get("equipmentSlots",[])
	for id in SLOT_POSITIONS:
		for slot in slots:
			if slot.slot==id:
				ordered.append(slot)
				break
	return ordered

static func slot_item(ui,member: Dictionary,slot: Dictionary) -> Dictionary:
	var item=member.get("equipmentDetails",{}).get(slot.slot,{}).duplicate(true)
	item.equipped_slot=slot.slot
	item.occupied=slot.get("occupiedBy")!=null
	item.id=slot.get("id","")
	item.name=ui.pages.party_view.equipment_name(slot)
	return item
