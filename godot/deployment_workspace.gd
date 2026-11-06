extends RefCounted
## Mock composition around the native battlefield; all actions use existing APIs.
var hud_ref: WeakRef
var hud:
 get:return hud_ref.get_ref()
 set(value):hud_ref=weakref(value)
var last_selected=""
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
 var sidebar_width=360.0
 var field_width=maxf(600,area.size.x-sidebar_width-20)
 hud.right_panel.pending_restore=null;hud.right_panel.position=Vector2(field_width+20,0);hud.right_panel.size=Vector2(sidebar_width,area.size.y-80)
 hud.right_panel.find_child("DragHandle",true,false).hide()
 if normal_panel_style==null:normal_panel_style=hud.right_panel.get_theme_stylebox("panel").duplicate()
 hud.right_panel.add_theme_stylebox_override("panel",ui.mock_shell.surface_style())
 hud.deployment_bar.position=Vector2.ZERO;hud.deployment_bar.size=Vector2(field_width,72)
 hud.deployment_bar.add_theme_stylebox_override("panel",ui.mock_shell.surface_style())
 hud.deployment_actions.position=Vector2(field_width-500,area.size.y-64);hud.deployment_actions.size=Vector2(500,56)
 ui.board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 ui.board.position=area.global_position+Vector2(0,80);ui.board.size=Vector2(field_width,maxf(300,area.size.y-160));ui.board.deployment_bottom_limit=0;ui.board.update_camera()
 var strip=ui.get("deployment_party_strip")
 if is_instance_valid(strip):strip.hide()
func render():
 if ui.selected!=last_selected:hud.selected_enemy="";last_selected=ui.selected
 ui.header.add_theme_color_override("font_color",Color("#293b33"))
 hud.left_panel.hide();ui.clear(hud.right_panel.body);ui.clear(hud.right_panel.footer)
 var body=hud.right_panel.body
 var unit=hud.unit(hud.selected_enemy if not hud.selected_enemy.is_empty() else ui.selected)
 if unit.is_empty():
  var allies=ui.state().get("units",[]).filter(func(u):return u.side=="ally")
  if not allies.is_empty():unit=allies[0]
 if not unit.is_empty():
  var head=ui.row(body);ui.portrait(head,unit,true,64);label(head,str(unit.name),true)
  label(body,"HP %d/%d    MP %d/%d" % [unit.hp,unit.max,unit.mp,unit.maxMp])
  var matches=ui.roster().filter(func(m):return m.id==unit.id)
  if not matches.is_empty():
   var member=matches[0]
   label(body,"装備",true)
   var grid=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);body.add_child(grid)
   for slot in member.get("equipmentSlots",[]):
    var item=member.get("equipmentDetails",{}).get(slot.slot,{})
    var button=ui.button(grid,"",func():ui.dialog.open(str(item.get("name","装備")),func(content,actions):label(content,str(item.get("note","")));ui.local_button(actions,"閉じる",ui.dialog.close)));button.custom_minimum_size=Vector2(72,64)
    button.icon=ui.icons.texture(ui.icons.equipment(item));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40);button.tooltip_text=str(item.get("name",slot));button.disabled=item.is_empty()
   label(body,"装備スキル",true)
   var skills=GridContainer.new();skills.columns=4;body.add_child(skills)
   for source in member.get("stats",{}).get("skillSources",[]):
    var id=str(source.id);var level=int(source.get("level",1));var name=str(ui.campaign().get("skillNames",{}).get(id,id));var gear=member.get("equipmentDetails",{}).get(source.slot,{})
    var button=ui.button(skills,"",ui.show_skill_details.bind(id,name,level,gear));button.custom_minimum_size=Vector2(72,56);button.icon=ui.icons.texture(ui.icons.skill(id,level));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",36);button.tooltip_text=name
  ui.local_button(body,"能力・効果の詳細",func():ui.dialog.open(str(unit.name),func(content,actions):hud.render_person_content(content,unit,true);ui.local_button(actions,"閉じる",ui.dialog.close)))
  if unit.side=="enemy":ui.local_button(body,"味方の配置確認に戻る",func():hud.selected_enemy="";render())
 body.add_child(HSeparator.new())
 var deployed=Drag.deployed(ui)
 var reserves=ui.roster().filter(func(member):return ui.campaign().get("selected",[]).has(member.id) and not deployed.has(member.id))
 label(body,"控え %d" % reserves.size(),true)
 var reserve_area=VBoxContainer.new();reserve_area.name="DeploymentReserves";reserve_area.custom_minimum_size.y=90;body.add_child(reserve_area)
 reserve_area.set_drag_forwarding(Callable(),func(_at,data):return Drag.valid(ui,data) and data.source=="board",func(_at,data):if Drag.consume(ui,data):ui.deployment_assigned(str(data.uid),null))
 if reserves.is_empty():label(reserve_area,"控えはいません")
 for member in reserves:
  var card=ui.button(reserve_area,str(member.name),func():ui.pages.party_view.open_detail(str(member.id)));card.alignment=HORIZONTAL_ALIGNMENT_LEFT;card.icon=ui.portraits.texture(member,true);card.expand_icon=true;card.add_theme_constant_override("icon_max_width",40);card.custom_minimum_size.y=56;card.tooltip_text="味方のマスへドラッグして配置"
  card.set_drag_forwarding(func(_at):var data=Drag.make_payload(ui,str(member.id),"party");if data!=null:card.set_drag_preview(Drag.preview(ui,str(member.id)));return data,Callable(),Callable())
 for member in ui.roster():
  if deployed.has(member.id) and member.hp<=0:ui.button(reserve_area,str(member.name)+"を控えに戻す",ui.deployment_assigned.bind(str(member.id),null))
 label(hud.right_panel.footer,"人物をドラッグ、または人物と配置先を順に選択")
 var hint=label(hud.right_panel.footer,"右ドラッグ: 移動 / 中ドラッグ: 角度 / ホイール: 拡大縮小");hint.add_theme_font_size_override("font_size",14);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 for box in [hud.right_panel,hud.deployment_options,hud.deployment_actions]:
  for button in box.find_children("*","Button",true,false):
   if box==hud.deployment_actions:button.custom_minimum_size=Vector2(156,56);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   if button.name=="DeploymentBegin":continue
   for state in ["normal","hover","pressed","disabled"]:button.add_theme_stylebox_override(state,ui.mock_shell.style(Color("#e0e8dd") if state in ["hover","pressed"] else Color("#faf9f5")))
   for color in ["font_color","font_hover_color","font_pressed_color"]:button.add_theme_color_override(color,Color("#293b33"))
 for child in hud.deployment_options.find_children("*","Label",true,false):child.add_theme_color_override("font_color",Color("#293b33"))
 layout()
