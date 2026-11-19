extends RefCounted
## Mock composition around the native battlefield; all actions use existing APIs.
var hud_ref: WeakRef
var hud:
 get:return hud_ref.get_ref()
 set(value):hud_ref=weakref(value)
var last_selected=""
const Shell=preload("res://mock_shell.gd")
var panel_style=Shell.surface_style()
var button_style=Shell.style()
var highlighted_style=Shell.style(Color("#e0e8dd"))
var normal_panel_style
func restore():
 if normal_panel_style!=null:hud.right_panel.add_theme_stylebox_override("panel",normal_panel_style)
 hud.right_panel.find_child("DragHandle",true,false).show()
 ui.header.remove_theme_color_override("font_color")
var ui:
 get:return hud.ui
const Drag=preload("res://deployment_drag.gd")
func label(parent,text,large=false):
 var control=ui.label_(parent,text,large);control.add_theme_color_override("font_color",Color("#293b33"));return control
func layout():
 var area=hud.middle
 hud.left_panel.hide()
 var sidebar_width=ui.mock_shell.ROSTER_WIDTH
 var roster_width=ui.mock_shell.ROSTER_WIDTH
 var field_left=roster_width+16
 var strip=ui.get("deployment_party_strip")
 var controls_bottom=area.size.y
 if is_instance_valid(strip):
  strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
  strip.position=area.global_position
  strip.size=Vector2(roster_width,controls_bottom-8)
 var field_width=maxf(1,area.size.x-field_left-sidebar_width-20)
 hud.right_panel.pending_restore=null;hud.right_panel.position=Vector2(field_left+field_width+20,0);hud.right_panel.size=Vector2(sidebar_width,controls_bottom-64)
 hud.right_panel.find_child("DragHandle",true,false).hide()
 if normal_panel_style==null:normal_panel_style=hud.right_panel.get_theme_stylebox("panel").duplicate()
 hud.right_panel.add_theme_stylebox_override("panel",panel_style)
 hud.deployment_bar.position=Vector2(field_left,0);hud.deployment_bar.size=Vector2(field_width,72)
 hud.deployment_bar.add_theme_stylebox_override("panel",panel_style)
 hud.deployment_actions.position=Vector2(field_left+field_width-500,controls_bottom-56);hud.deployment_actions.size=Vector2(500,56)
 hud.camera_hint.global_position=Vector2(24,ui.size.y-hud.camera_hint.get_combined_minimum_size().y-8)
 hud.deployment_instructions.position=Vector2(field_left+12,88)
 ui.board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 ui.board.position=area.global_position+Vector2(field_left,80);ui.board.size=Vector2(field_width,maxf(1,controls_bottom-144));ui.board.deployment_bottom_limit=0;ui.board.update_camera()
func render():
 if ui.selected!=last_selected:hud.selected_enemy="";last_selected=ui.selected
 ui.header.add_theme_color_override("font_color",Color("#293b33"))
 hud.left_panel.hide();ui.clear(hud.right_panel.body);ui.clear(hud.right_panel.footer)
 var body=hud.right_panel.body
 var enemies=ui.state().get("units",[]).filter(func(u):return u.side=="enemy")
 label(body,"敵パーティ　%d人" % enemies.size(),true)
 for enemy in enemies:
  var button=ui.local_button(body,"",hud.open_equipment_sheet.bind(str(enemy.id)))
  button.name="DeploymentEnemy_"+str(enemy.id)
  ui.mock_shell.roster_member_line(button,enemy)
 var deployed=Drag.deployed(ui)
 var reserves=ui.roster().filter(func(member):return ui.campaign().get("selected",[]).has(member.id) and not deployed.has(member.id))
 label(body,"控え %d" % reserves.size(),true)
 var reserve_area=VBoxContainer.new();reserve_area.name="DeploymentReserves";reserve_area.custom_minimum_size.y=90;body.add_child(reserve_area)
 reserve_area.set_drag_forwarding(Callable(),func(_at,data):return Drag.valid(ui,data) and data.source=="board",func(_at,data):if Drag.consume(ui,data):ui.deployment_assigned(str(data.uid),null))
 if reserves.is_empty():label(reserve_area,"控えはいません")
 for member in reserves:
  var card=ui.button(reserve_area,str(member.name),ui.mock_shell.activate.bind(str(member.id)));card.alignment=HORIZONTAL_ALIGNMENT_LEFT;card.icon=ui.portraits.texture(member,true);card.expand_icon=true;card.add_theme_constant_override("icon_max_width",40);card.custom_minimum_size.y=56;card.tooltip_text="味方のマスへドラッグして配置"
  card.set_drag_forwarding(func(_at):var data=Drag.make_payload(ui,str(member.id),"party");if data!=null:card.set_drag_preview(Drag.preview(ui,str(member.id)));return data,Callable(),Callable())
 for member in ui.roster():
  if deployed.has(member.id) and member.hp<=0:ui.button(reserve_area,str(member.name)+"を控えに戻す",ui.deployment_assigned.bind(str(member.id),null))
 for box in [hud.right_panel,hud.deployment_options,hud.deployment_actions]:
  for button in box.find_children("*","Button",true,false):
   if box==hud.deployment_actions:button.custom_minimum_size=Vector2(156,56);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   if button.name=="DeploymentBegin":continue
   for state in ["normal","hover","pressed","disabled"]:button.add_theme_stylebox_override(state,highlighted_style if state in ["hover","pressed"] else button_style)
   for color in ["font_color","font_hover_color","font_pressed_color"]:button.add_theme_color_override(color,Color("#293b33"))
 for child in hud.deployment_options.find_children("*","Label",true,false):child.add_theme_color_override("font_color",Color("#293b33"))
 layout()
