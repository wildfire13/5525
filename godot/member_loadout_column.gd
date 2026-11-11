extends VBoxContainer
## The party sheet and shop share the same portrait, tabs and equipment hitboxes.
const WIDTH := 400
const ART_SIZE := Vector2(384,760)
const SLOT_POSITIONS := {
	"head": Vector2(148,0), "rightHand": Vector2(28,136),
	"upperBody": Vector2(148,136), "leftHand": Vector2(268,136),
	"lowerBody": Vector2(148,284), "feet": Vector2(148,432),
	"accessory1": Vector2(88,596), "accessory2": Vector2(208,596)
}

var stage: Control
var portrait: TextureRect
var panel: PanelContainer

func build(ui, member: Dictionary, tab: String, choose: Callable, prefix: String, disabled:=false):
	custom_minimum_size=Vector2(WIDTH,ui.mock_shell.content_height())
	var tabs=ui.row(self)
	for entry in [["equipment","装備"],["inventory","インベントリ"]]:
		var button=ui.button(tabs,entry[1],choose.bind(entry[0]),disabled)
		button.name=prefix+entry[0]
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		ui.mark_selected(button,tab==entry[0])
	var display=ui.card(self)
	panel=display.get_parent()
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	ui.label_(display,{"equipment":"装備","inventory":"インベントリ","ability":"能力","skills":"スキル"}[tab])
	stage=Control.new()
	stage.custom_minimum_size=ART_SIZE
	stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	display.add_child(stage)
	portrait=ui.portrait(stage,member,false,1)
	portrait.position=Vector2(0,8)
	portrait.size=ART_SIZE
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if tab in ["equipment","inventory"]:portrait.modulate.a=.22

func inventory_overlay() -> VBoxContainer:
	var overlay=VBoxContainer.new()
	stage.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay

func equipment(ui,member: Dictionary,selected_slot: String,prefix: String,choose: Callable,drag: Callable=Callable(),disabled:=false):
	for slot in ordered_slots(member):
		var item=slot_item(ui,member,slot)
		var button=ui.button(stage,"",choose.bind(item),disabled)
		button.name=prefix+str(slot.slot)
		button.position=SLOT_POSITIONS[slot.slot]
		button.custom_minimum_size=Vector2(88,88)
		button.size=button.custom_minimum_size
		button.tooltip_text=str(slot.label)+" / "+str(item.name)
		ui.mark_selected(button,selected_slot==slot.slot)
		button.icon=ui.icons.texture(ui.icons.equipment(item))
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",68)
		var caption=ui.label_(stage,str(slot.label))
		caption.position=button.position+Vector2(0,90)
		caption.size=Vector2(90,12)
		caption.autowrap_mode=TextServer.AUTOWRAP_OFF
		caption.add_theme_font_size_override("font_size",16)
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
