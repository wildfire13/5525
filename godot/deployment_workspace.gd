extends RefCounted
## Mock composition around the native battlefield; all actions use existing APIs.
var hud_ref: WeakRef
var hud:
 get:return hud_ref.get_ref()
 set(value):hud_ref=weakref(value)
var last_selected=""
const Grid=preload("res://screen_grid.gd")
const Shell=preload("res://mock_shell.gd")
var panel_style=Shell.surface_style()
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
 var view=ui.size
 hud.left_panel.hide()
 var strip=ui.get("deployment_party_strip")
 if is_instance_valid(strip):
  strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
  Grid.place(strip,Grid.cell_rect(view,0,1,2,8))
 hud.right_panel.place_regions(view,Grid.cell_rect(view,8,1,2,8),Grid.cell_rect(view,8,1,2,5),Grid.cell_rect(view,8,6,2,3),Rect2())
 hud.right_panel.find_child("DragHandle",true,false).hide()
 if normal_panel_style==null:normal_panel_style=hud.right_panel.get_theme_stylebox("panel").duplicate()
 panel_style.set_content_margin_all(0)
 hud.right_panel.add_theme_stylebox_override("panel",panel_style)
 Grid.place(hud.deployment_bar,Grid.cell_rect(view,2,1,4,1))
 hud.deployment_bar.add_theme_stylebox_override("panel",panel_style)
 Grid.place(hud.deployment_actions,Grid.cell_rect(view,5,8,3,1))
 hud.layout_camera_guide()
 Grid.place(hud.deployment_instructions,Grid.cell_rect(view,6,1,2,1))
 hud.deployment_instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 ui.board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 Grid.place(ui.board,Grid.cell_rect(view,2,2,6,6))
 ui.board.deployment_bottom_limit=0;ui.board.update_camera()
func render():
 if ui.selected!=last_selected:hud.selected_enemy="";last_selected=ui.selected
 ui.header.add_theme_color_override("font_color",Color("#293b33"))
 hud.left_panel.hide();ui.clear(hud.right_panel.body);ui.clear(hud.right_panel.lower);ui.clear(hud.right_panel.footer)
 var body=hud.right_panel.body
 var enemies=ui.state().get("units",[]).filter(func(u):return u.side=="enemy")
 label(body,"敵パーティ　%d人" % enemies.size(),true)
 for enemy in enemies:
  var button=ui.local_button(body,"",hud.open_equipment_sheet.bind(str(enemy.id)))
  button.name="DeploymentEnemy_"+str(enemy.id)
  ui.mock_shell.roster_member_line(button,enemy)
 var deployed=Drag.deployed(ui)
 var reserves=ui.roster().filter(func(member):return ui.campaign().get("selected",[]).has(member.id) and not deployed.has(member.id))
 hud.right_panel.lower_scroll.name="DeploymentReserveRegion"
 label(hud.right_panel.lower,"控え %d" % reserves.size(),true)
 var reserve_area=VBoxContainer.new();reserve_area.name="DeploymentReserves";reserve_area.custom_minimum_size.y=90;hud.right_panel.lower.add_child(reserve_area)
 reserve_area.set_drag_forwarding(Callable(),func(_at,data):return Drag.valid(ui,data) and data.source=="board",func(_at,data):if Drag.consume(ui,data):ui.deployment_assigned(str(data.uid),null))
 if reserves.is_empty():label(reserve_area,"控えはいません")
 for member in reserves:
  var card=ui.button(reserve_area,str(member.name),ui.mock_shell.activate.bind(str(member.id)));card.alignment=HORIZONTAL_ALIGNMENT_LEFT;card.icon=ui.portraits.texture(member,true);card.expand_icon=true;card.add_theme_constant_override("icon_max_width",40);card.custom_minimum_size.y=56;card.tooltip_text="味方のマスへドラッグして配置"
  ui.mark_selected(card,ui.selected==str(member.id))
  card.set_drag_forwarding(func(_at):var data=Drag.make_payload(ui,str(member.id),"party");if data!=null:card.set_drag_preview(Drag.preview(ui,str(member.id)));return data,Callable(),Callable())
 for member in ui.roster():
  if deployed.has(member.id) and member.hp<=0:ui.button(reserve_area,str(member.name)+"を控えに戻す",ui.deployment_assigned.bind(str(member.id),null))
 for button in hud.deployment_actions.find_children("*","Button",true,false):
  button.custom_minimum_size=Vector2(156,56);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for child in hud.deployment_options.find_children("*","Label",true,false):child.add_theme_color_override("font_color",Color("#293b33"))
 layout()
