extends RefCounted
const ElementBadges=preload("res://element_badges.gd")
const BattleText=preload("res://battle_text.gd")
const Tokens=preload("res://ui_tokens.gd")
const UiMotion=preload("res://ui_motion.gd")
## State-focused display. Choices, predictions and results remain engine-owned.
var ui
var middle: Control
var board_column: VBoxContainer
var dock: Control
var decision_footer: VBoxContainer
var tools: HBoxContainer
var camera_hint: Label
var actor_box: VBoxContainer
var command_box: VBoxContainer
var target_box: VBoxContainer
var details: PanelContainer
var tabs: TabContainer
var action_visual: Control
var shifted_action := ""
var queue_distance := 0
var animation_trace: Array=[]
var queue_at_start: Array=[]
# Engine replies replace ui.data. Local selections and their previews share one snapshot.
var selection_snapshot: Dictionary
var selection_size: Vector2
var previous_menu := ""
var last_actor := ""
var last_action_count := -1
var selected_enemy := ""
var buttons: Dictionary={}
var presentation_action: Dictionary={}
var expanded_menu := ""
var animate_menu := false
var menu_transition := false
var menu_ticket := 0
var action_menu := true
var opening_generation := 0
var opening_visual: Control
var opening_tween: Tween
var item_list := false
var skill_list := false
const ItemMenu=preload("res://item_menu.gd")
var selected_cell := -1
var range_reference := false
var reference_preview: Dictionary={}
var reference_generation := 0
var reference_pending := false
var reference_error := ""
var reference_kind := "action_attack"
var bottom_commands: VBoxContainer
var left_panel
var right_panel
var deployment_footer: PanelContainer
var deployment_instructions: Label
var deployment_actions: HBoxContainer
var deployment_party_button: Button
var battle_party_button: Button
var party_overlay: PanelContainer
var party_overlay_open := false
var party_overlay_job := ""
var deployment_layout := false
var deployment_workspace=preload("res://deployment_workspace.gd").new()
var loadout_modal
var left_info: VBoxContainer
var person_box: VBoxContainer
var inspected_uid := ""
var inspection_pinned := false
var hover_generation := 0
var hover_stamp := ""
var skill_content_open := false
var _layout_sig: Array=[]
const QUEUE_VISIBLE=5
const QUEUE_CARD_WIDTH=180
const QUEUE_ARROW_WIDTH=24
const QUEUE_GAP=Tokens.SPACE_SM
const QUEUE_PITCH=QUEUE_CARD_WIDTH+QUEUE_ARROW_WIDTH+QUEUE_GAP*2
const COMMANDS=[["action_attack","攻撃"],["action_move","移動"],["action_skill","スキル"],["items","アイテム"],["action_defend","防御"]]
const Grid=preload("res://screen_grid.gd")
func panel_rect(right: bool) -> Rect2:
	var rect=Grid.cell_rect(ui.size,8 if right else 0,1,2,8)
	rect.position-=middle.global_position
	return rect
func actor_panel_rect() -> Rect2:return panel_rect(false)
func target_panel_rect() -> Rect2:return panel_rect(true)
func set_panel_columns(count: int):
	for panel in [left_panel,right_panel]:panel.grid_columns=count
	ui.preferences.config.set_value("battle","panel_columns",count)
func _init(frontend):
	ui=frontend
	loadout_modal=preload("res://battle_loadout_modal.gd").new(ui)
func _format_number(value: float) -> String:
	return String.num(value, 1).trim_suffix(".0")
func l(parent,text,large:=false):
	var label=ui.label_(parent,str(text),large)
	if large:label.add_theme_color_override("font_color",Tokens.INK)
	return label
func b(parent,text,fn,disabled:=false):
	var control=ui.button(parent,text,fn,disabled);control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return control
func local(parent,text,fn):return ui.local_button(parent,text,fn)
func unit(id) -> Dictionary:
	for u in ui.state().get("units",[]):
		if u.id==id:return u
	return {}
func acting() -> Dictionary:
	var phase=ui.data.get("presentation")
	return unit(phase.get("actor_id",ui.state().get("actor"))) if phase is Dictionary else unit(ui.state().get("actor"))
func coord(pos) -> String:return BattleText.coord(pos)
func state_id() -> String:
	if ui.data.get("presentation") is Dictionary:return "B5" if ui.data.presentation.get("phase")=="action" else "B6"
	if range_reference:return "B2R"
	if action_menu:return "B0"
	if item_list:return "B3I"
	if ui.command=="action_move":return "B2" if ui.pending!=null else "B1"
	return "B4" if ui.pending!=null or ui.command=="action_defend" else "B3"
func reset_context():
	selection_snapshot={}
	clear_opening_visual()
	expanded_menu="";menu_transition=false;menu_ticket+=1;clear_action_visual();shifted_action="";queue_distance=0;animation_trace.clear()
	inspected_uid="";inspection_pinned=false;invalidate_hover();skill_content_open=false
	discard_reference();item_list=false;skill_list=false;action_menu=true;selected_cell=-1;selected_enemy="";last_actor="";last_action_count=-1;presentation_action={};queue_at_start=[]
	party_overlay_open=false;party_overlay_job=""
	if is_instance_valid(party_overlay):party_overlay.hide()
func mount():
	selection_snapshot={}
	deployment_workspace.hud=self
	deployment_layout=false
	middle=Control.new();middle.name="BattleOverlay";middle.mouse_filter=Control.MOUSE_FILTER_IGNORE;middle.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.content.add_child(middle);middle.size=Vector2(ui.size.x-48,ui.size.y-130);ui.battle_row=middle
	if not is_instance_valid(ui.board):
		ui.board=preload("res://battle_board.gd").new();ui.board.preferences=ui.preferences;ui.board.portraits=ui.portraits;ui.board.name="BattleBoard";ui.board.deployment_ui=ui;ui.add_child(ui.board);ui.move_child(ui.board,0);ui.board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.memory.key(ui.board,"board");ui.board.cell_clicked.connect(ui.on_cell);ui.board.deployment_assigned.connect(ui.deployment_assigned);ui.board.unit_hovered.connect(inspect_hover.bind(ui.board))
	left_panel=preload("res://floating_panel.gd").new();left_panel.viewport_bounds=true;middle.add_child(left_panel)
	left_panel.configure(ui.preferences,"battle_actor_b","行動者 / コマンド",actor_panel_rect())
	right_panel=preload("res://floating_panel.gd").new();right_panel.viewport_bounds=true;middle.add_child(right_panel)
	right_panel.configure(ui.preferences,"battle_target_b","対象 / 効果",target_panel_rect())
	for panel in [left_panel,right_panel]:
		panel.grid_columns=clampi(int(ui.preferences.config.get_value("battle","panel_columns",2)),2,5)
		panel.columns_changed.connect(set_panel_columns)
	dock=left_panel
	tools=HBoxContainer.new();tools.name="BattleTools";middle.add_child(tools)
	var guidance=Control.new();guidance.name="CameraGuideRegion";guidance.mouse_filter=Control.MOUSE_FILTER_IGNORE;middle.add_child(guidance)
	var hint_chip=PanelContainer.new();hint_chip.name="CameraGuideChip";hint_chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint_chip.add_theme_stylebox_override("panel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_XS))
	guidance.add_child(hint_chip)
	camera_hint=l(hint_chip,preload("res://battle_board.gd").CAMERA_HINT)
	camera_hint.name="BattleCameraHint";camera_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	camera_hint.autowrap_mode=TextServer.AUTOWRAP_OFF
	camera_hint.add_theme_font_size_override("font_size",Tokens.FONT_SM)
	camera_hint.add_theme_color_override("font_color",Tokens.INK)
	camera_hint.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	ui.battle_header=PanelContainer.new();ui.battle_header.name="BattleTurnFooter";ui.battle_header.mouse_filter=Control.MOUSE_FILTER_STOP
	ui.battle_header.add_theme_stylebox_override("panel",Tokens.surface_box())
	ui.battle_header.z_index=1
	middle.add_child(ui.battle_header)
	last_actor="";last_action_count=-1;action_menu=true;item_list=false;selected_cell=-1
	deployment_footer=PanelContainer.new();deployment_footer.name="DeploymentFooter";deployment_footer.mouse_filter=Control.MOUSE_FILTER_STOP
	deployment_footer.add_theme_stylebox_override("panel",Tokens.surface_box())
	deployment_footer.z_index=1
	middle.add_child(deployment_footer)
	var deploy_row=HBoxContainer.new();deploy_row.name="DeploymentFooterRow";deploy_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;deploy_row.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	deploy_row.add_theme_constant_override("separation",Tokens.SPACE_MD)
	deployment_footer.add_child(deploy_row)
	deployment_party_button=local(deploy_row,"パーティ情報",ui.mock_shell.toggle_character)
	deployment_party_button.name="DeploymentPartyButton"
	deployment_party_button.set_meta("base_variation",&"ActionButton")
	deployment_party_button.theme_type_variation=&"ActionButton"
	Tokens.apply_button_preset(deployment_party_button,"md")
	ui.memory.key(deployment_party_button,"battle_footer_party")
	deployment_instructions=Label.new();deployment_instructions.name="DeploymentInstructions";deployment_instructions.text="人物をドラッグ、または人物と配置先を順に選択"
	deployment_instructions.size_flags_horizontal=Control.SIZE_EXPAND_FILL;deployment_instructions.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	deployment_instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	deployment_instructions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	deployment_instructions.add_theme_color_override("font_color",Tokens.INK)
	deploy_row.add_child(deployment_instructions)
	deployment_actions=HBoxContainer.new();deployment_actions.name="DeploymentActions";deployment_actions.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	deployment_actions.add_theme_constant_override("separation",Tokens.SPACE_SM)
	deploy_row.add_child(deployment_actions)
	party_overlay=PanelContainer.new();party_overlay.name="BattlePartyOverlay";party_overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	party_overlay.add_theme_stylebox_override("panel",Tokens.box(Tokens.SURFACE))
	party_overlay.z_index=25;party_overlay.hide()
	middle.add_child(party_overlay)
	ui.board.party_overlay=party_overlay
	# Control input follows sibling order, independently of drawing z_index.
	middle.move_child(left_panel,-1);middle.move_child(right_panel,-1);middle.move_child(party_overlay,-1)
	_layout_sig=[]
	resize()
func layout_camera_guide():
	var region=Grid.cell_rect(ui.size,2,8,3,1)
	var chip: PanelContainer=camera_hint.get_parent()
	var guide: Control=chip.get_parent()
	guide.clip_contents=true
	Grid.place(guide,region)
	camera_hint.autowrap_mode=TextServer.AUTOWRAP_OFF
	var chip_size=chip.get_combined_minimum_size()
	if chip_size.x>region.size.x:
		camera_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		chip_size=Vector2(region.size.x,minf(region.size.y,chip.get_combined_minimum_size().y))
	else:
		chip_size.y=minf(chip_size.y,region.size.y)
	chip.position=Vector2(0.0,maxf(0.0,region.size.y-chip_size.y-float(Tokens.SPACE_SM)))
	chip.size=chip_size
func resize(force:=true):
	if not is_instance_valid(left_panel) or not is_instance_valid(ui.board) or ui.board.is_queued_for_deletion() or middle.size.x<100:return
	var strip_id: int=ui.deployment_party_strip.get_instance_id() if is_instance_valid(ui.deployment_party_strip) else 0
	var sig=[ui.size,middle.global_position,middle.size,left_panel.size,right_panel.size,deployment_layout,ui.board.get_instance_id(),strip_id,ui.battle_header.get_child_count()]
	if not force and _layout_sig==sig:return
	_layout_sig=sig
	# Keep movable panels inside the middle eight rows between header (y=0..1) and footer (y=9..10).
	var central=Grid.cell_rect(ui.size,0,1,10,8)
	for panel in [left_panel,right_panel]:
		panel.reserved_top=central.position.y
		panel.reserved_bottom=ui.size.y-central.end.y
	if deployment_layout:
		deployment_workspace.layout();return
	ui.board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.board.position=Vector2.ZERO
	ui.board.size=ui.size
	ui.board.battle_play_width=maxf(1.0,ui.size.x-left_panel.size.x-right_panel.size.x-64.0)
	layout_camera_guide()
	var queue_scroll=ui.battle_header.find_child("TurnOrderViewport",true,false)
	if queue_scroll!=null:queue_scroll.custom_minimum_size.x=queue_viewport_width()
	var order_region=Grid.cell_rect(ui.size,0,9,10,1)
	Grid.place(ui.battle_header,order_region)
	var order=ui.battle_header.find_child("TurnOrderControls",true,false)
	if order!=null:order.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	ui.board.deployment_bottom_limit=0.0
	ui.board.update_camera()
	left_panel.place_regions(ui.size,Grid.cell_rect(ui.size,0,1,2,8),Grid.cell_rect(ui.size,0,1,2,3),Grid.cell_rect(ui.size,0,4,2,5),Rect2(),true)
	right_panel.place_regions(ui.size,Grid.cell_rect(ui.size,8,1,2,8),Grid.cell_rect(ui.size,8,4,2,4),Grid.cell_rect(ui.size,8,1,2,3),Grid.cell_rect(ui.size,8,8,2,1),true)
	for panel in [left_panel,right_panel]:
		panel.z_index=10
	if is_instance_valid(party_overlay):
		party_overlay.z_index=25
		middle.move_child(party_overlay,-1)
		Grid.place(party_overlay,Grid.cell_rect(ui.size,0,1,2,8))
	Grid.place(tools,Grid.cell_rect(ui.size,6,1,2,1))

func render():
	var opening=false
	var s=ui.state();var phase=ui.data.get("presentation");var a=acting()
	if not (phase is Dictionary) and not ui.presenting:queue_at_start=ui.data.get("queue",[]).duplicate(true)
	if not s.get("deploying",false) and s.get("result")==null and not ui.presenting and not phase is Dictionary and (a.get("id","")!=last_actor or int(s.get("actions",0))!=last_action_count):
		opening=true
		expanded_menu="";item_list=false;skill_list=false;action_menu=true;selected_cell=-1;selected_enemy="";inspected_uid="";inspection_pinned=false;range_reference=false;ui.invalidate_preview();last_actor=str(a.get("id",""));last_action_count=int(s.get("actions",0));ui.memory.request_focus("command_attack")
	if s.get("result")!=null or phase is Dictionary or ui.presenting:clear_inspection()
	var deploying=bool(s.get("deploying",false))
	deployment_instructions.visible=deploying
	camera_hint.add_theme_color_override("font_color",Tokens.INK)
	camera_hint.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	if deploying!=deployment_layout:
		deployment_layout=deploying
		if not deploying:deployment_workspace.restore()
		for pair in [[left_panel,"deployment_ally" if deploying else "battle_actor_b",actor_panel_rect()], [right_panel,"deployment_enemy" if deploying else "battle_target_b",target_panel_rect()]]:
			var panel=pair[0];panel.layout_key=pair[1]
			panel.restore_rect(pair[2])
	left_panel.find_child("DragHandle",true,false).text="配置する味方  ⋮" if deploying else "行動者 / コマンド  ⋮"
	right_panel.find_child("DragHandle",true,false).text="敵の情報  ⋮" if deploying else "対象 / 効果  ⋮"
	deployment_footer.visible=deploying;deployment_actions.visible=deploying;ui.battle_header.visible=not deploying
	ui.clear(deployment_actions)
	if is_instance_valid(deployment_party_button):
		deployment_party_button.name="BattleFooterPartyButton" if deploying else "DeploymentPartyButton"
	if deploying and phase==null and not ui.engine.disconnected:
		party_overlay_open=false
		if is_instance_valid(party_overlay):party_overlay.hide()
		ui.clear(ui.battle_header)
		selection_snapshot={}
		tools.hide()
		render_actor(a)
		render_deployment()
		update_board()
		deployment_workspace.render()
		ui.board.inspected_enemy=""
		refresh_hover()
		return
	update_board()
	render_actor(a)
	var selecting=not deploying and not ui.presenting and phase==null and s.get("result")==null and not ui.engine.disconnected and not range_reference
	var reuse=selecting and not opening and is_same(selection_snapshot,ui.data) and selection_size==ui.size
	if reuse:
		update_resource_preview(left_info,a)
		ui.clear(target_box)
		ui.clear(decision_footer)
		if expanded_menu.is_empty() and previous_menu.is_empty():
			for kind in buttons:
				var selected=command_selected(kind)
				if buttons[kind].get_meta("selected",false)!=selected:
					ui.mark_selected(buttons[kind],selected)
		else:
			ui.clear(bottom_commands)
			render_bottom_commands()
	else:
		build_panels(s,phase,a,deploying)
	selection_snapshot=ui.data if selecting else {}
	selection_size=ui.size
	previous_menu=expanded_menu
	if not deploying:
		if s.get("result")!=null:party_overlay_open=false
		if not reuse:render_party_overlay()
		render_person()
	if ui.engine.disconnected:l(command_box,"接続が終了しました",true)
	elif phase is Dictionary:render_presentation(phase)
	elif s.get("deploying",false):render_deployment()
	elif s.get("result")!=null:render_result()
	elif range_reference:render_reference()
	elif not action_menu and not item_list and not skill_list:presentation_action={};render_target()
	if deploying:
		deployment_workspace.render()
		update_board()
	ui.board.inspected_enemy="";refresh_hover();resize()
	if is_instance_valid(opening_visual):left_panel.hide()
	if opening:open_actor_panel()
func build_panels(s,phase,a,deploying):
	ui.clear(ui.battle_header);ui.clear(tools);ui.clear(left_panel.body);ui.clear(left_panel.lower);ui.clear(right_panel.body);ui.clear(right_panel.lower);ui.clear(right_panel.footer)
	render_queue()
	tools.visible=not deploying;tools.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ui.data.get("trial") is Dictionary:
		var end=b(tools,"試用終了",ui.act.bind("endTrial",[]),ui.presenting);end.name="EndTrial";Tokens.apply_button_preset(end,"md_lg")

	tools.tooltip_text=preload("res://battle_board.gd").CAMERA_HINT
	left_panel.visible=deploying or (a.get("side")=="ally" and not s.get("deploying",false) and s.get("result")==null) or ui.engine.disconnected
	if phase is Dictionary and (is_instance_valid(action_visual) or str(phase.get("action_id",""))==shifted_action):left_panel.hide()
	left_panel.section_with_handle.set_meta("ui_region","BattleActorInfoRegion")
	left_info=left_panel.body;left_info.name="BattleActorInfo"
	if a.get("side")=="ally":
		combat_portrait(left_info,a)
		combat_resources(left_info,a)
		var battle_stats=ui.row(left_info)
		ElementBadges.add(battle_stats,str(a.get("element","none")),28)
		battle_stats.tooltip_text=""
		var speed=l(battle_stats,"SPD %s" % _format_number(float(a.get("agi",0))))
		speed.mouse_filter=Control.MOUSE_FILTER_STOP
		speed.tooltip_text="行動速度。高いほど次の手番が早く回ります。"
		if a.has("carriedWeight"):
			var carried := float(a.get("carriedWeight",0))+float(a.get("fallenWeightShare",0))
			var limit := float(a.get("weightLimit",0))
			var weight=l(battle_stats,"Wt %s / %s" % [_format_number(carried),_format_number(limit)])
			weight.mouse_filter=Control.MOUSE_FILTER_STOP
			weight.tooltip_text="所持重量 / STR上限。上限を超えると行動速度が半減します。"
			if bool(a.get("overburdened",false)) or (limit>0.0 and carried>limit):
				weight.add_theme_color_override("font_color",Tokens.DANGER)
	left_panel.lower_scroll.name="BattleCommandRegion"
	bottom_commands=left_panel.lower;bottom_commands.name="ActorCommands"
	if not deploying:render_bottom_commands()
	actor_box=left_info;command_box=left_info
	right_panel.section_with_handle.set_meta("ui_region","BattlePersonInfoRegion")
	person_box=VBoxContainer.new();person_box.name="BattlePersonInfo";right_panel.lower.add_child(person_box)
	right_panel.body_scroll.set_meta("ui_region","DecisionContentRegion")
	target_box=VBoxContainer.new();target_box.name="DecisionContent";right_panel.body.add_child(target_box);right_panel.body.move_child(target_box,0)
	decision_footer=right_panel.footer

func open_history():
	ui.dialog.open("戦闘履歴",func(body,actions):
		for entry in ui.state().get("log",[]).slice(-40):l(body,ui.display_log(str(entry)))
		ui.local_button(actions,"閉じる",ui.dialog.close),Callable(),Rect2(),preload("res://window_grid.gd").compact_modal_grid())
func update_board():
	ui.board.reference_mode=range_reference
	ui.board.update_state(ui.data,reference_preview if range_reference else ui.preview,ui.command,ui.selected if ui.state().get("deploying",false) else "",ui.chosen)
func render_actor(_a: Dictionary):
	ui.header.text="配置" if ui.state().get("deploying",false) else "戦闘"
	ui.header.tooltip_text=preload("res://battle_board.gd").CAMERA_HINT
func queue_entries() -> Array:
	var entries=[]
	var presenting=ui.data.get("presentation") is Dictionary or ui.presenting
	if presenting and not acting().is_empty():entries.append({"unit":acting(),"label":""})
	var queue_=ui.data.get("queue",[])
	for index in range(queue_.size()):
		if presenting and index==0 and queue_[index].id==acting().get("id"):continue
		var u=unit(queue_[index].id)
		if not u.is_empty() and u.get("hp",0)>0:entries.append({"unit":u,"label":"次回スキップ" if queue_[index].get("skip",false) else ""})
	return entries
func open_order_details():
	ui.dialog.open("順番詳細",func(body,actions):
		for index in range(queue_entries().size()):
			var entry=queue_entries()[index];var u=entry.unit
			var line=l(body,"%d. %s / %s%s" % [index+1,str(u.name),"味方" if u.side=="ally" else "敵"," / "+entry.label if not entry.label.is_empty() else ""])
			line.name="OrderDetail_"+str(index)
		local(actions,"閉じる",ui.dialog.close),Callable(),Rect2(),preload("res://window_grid.gd").compact_modal_grid())
func render_queue():
	var line=ui.row(ui.battle_header);line.name="TurnOrderControls";line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.size_flags_vertical=Control.SIZE_SHRINK_CENTER;line.add_theme_constant_override("separation",Tokens.SPACE_MD)
	battle_party_button=local(line,"パーティ情報",toggle_party_overlay)
	battle_party_button.name="BattleFooterPartyButton"
	battle_party_button.set_meta("base_variation",&"ActionButton")
	Tokens.apply_button_preset(battle_party_button,"md")
	ui.mark_selected(battle_party_button,party_overlay_open)
	ui.memory.key(battle_party_button,"battle_footer_party")
	var queue_scroll=ScrollContainer.new();queue_scroll.name="TurnOrderViewport";queue_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;queue_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	queue_scroll.custom_minimum_size=Vector2(queue_viewport_width(),Tokens.BUTTON_LG if ui.ui_size_mode=="standard" else Tokens.BUTTON_MD)
	queue_scroll.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	queue_scroll.mouse_filter=Control.MOUSE_FILTER_STOP;queue_scroll.focus_mode=Control.FOCUS_ALL;ui.memory.key(queue_scroll,"turn_order");line.add_child(queue_scroll)
	queue_scroll.gui_input.connect(func(event):
		if queue_scroll.has_focus() and event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT,KEY_RIGHT]:
			queue_scroll.scroll_horizontal+=QUEUE_PITCH if event.keycode==KEY_RIGHT else -QUEUE_PITCH
			queue_scroll.accept_event())
	var band=ui.row(queue_scroll);band.name="TurnOrder";band.size_flags_vertical=Control.SIZE_EXPAND_FILL;band.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var available=not ui.state().get("deploying",false) and (ui.state().get("result")==null or ui.data.get("presentation") is Dictionary)
	var entries=queue_entries() if available else []
	var presenting=ui.data.get("presentation") is Dictionary
	# A sixth card exists only behind the clipping boundary during the one-card
	# slide. Controls remain outside that viewport and never slide with it.
	for index in range(QUEUE_VISIBLE+1 if presenting else QUEUE_VISIBLE):
		if index>0:
			var arrow=l(band,"←" if index<entries.size() else "")
			arrow.custom_minimum_size.x=QUEUE_ARROW_WIDTH;arrow.size_flags_horizontal=Control.SIZE_FILL;arrow.size_flags_vertical=Control.SIZE_SHRINK_CENTER;arrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if index>=entries.size():
			var space=Control.new();space.custom_minimum_size.x=QUEUE_CARD_WIDTH;space.mouse_filter=Control.MOUSE_FILTER_IGNORE;band.add_child(space);continue
		var u=entries[index].unit
		var panel=PanelContainer.new();panel.custom_minimum_size.x=QUEUE_CARD_WIDTH;panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER;panel.name="TurnCard_"+str(index);panel.set_meta("unit_id",u.id);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;band.add_child(panel)
		panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		panel.tooltip_text=str(u.name)+(" / "+str(entries[index].label) if not entries[index].label.is_empty() else "")
		var inspect=Button.new()
		inspect.name="InspectTurnMember"
		inspect.set_meta("read_only",true)
		inspect.tooltip_text=str(u.name)+"の装備とインベントリ"
		inspect.accessibility_name=inspect.tooltip_text
		inspect.pressed.connect(open_equipment_sheet.bind(str(u.id)))
		panel.add_child(inspect)
		ui.mark_selected(inspect,index==0)
		var row=ui.row(panel);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ui.mock_shell.bind_button_text(inspect,row)
		# Faction color belongs to the portrait; the whole card is an inspect button.
		var badge=PanelContainer.new();badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(badge)
		var badge_style=Tokens.box(Tokens.BTN_HOVER if u.side=="ally" else Color("#f0deda"),Color.TRANSPARENT,Tokens.RADIUS_SM,Tokens.SPACE_NONE,0)
		badge.add_theme_stylebox_override("panel",badge_style)
		ui.portrait(badge,u,true,32 if ui.ui_size_mode=="standard" else 24).mouse_filter=Control.MOUSE_FILTER_IGNORE
		var label=l(row,("● " if index==0 else "")+str(u.name));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.custom_minimum_size=Vector2(132,24);label.clip_text=true;label.max_lines_visible=1;label.tooltip_text=str(u.name)
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(spacer)
	var all_=local(line,"順番詳細",open_order_details);all_.name="BattleOrderDetails";Tokens.apply_button_preset(all_,"md")
	var history=local(line,"戦闘履歴",open_history);history.name="BattleHistory";history.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;Tokens.apply_button_preset(history,"md")
	if presenting and str(ui.data.presentation.get("action_id",""))==shifted_action:queue_scroll.set_deferred("scroll_horizontal",queue_distance)
func queue_viewport_width() -> float:
	# Keep all five cards, with party info on the left and details/history right-aligned.
	var preferred=QUEUE_PITCH*QUEUE_VISIBLE-QUEUE_ARROW_WIDTH-QUEUE_GAP*2
	var footer_width=Grid.cell_rect(ui.size,0,9,10,1).size.x-float(Tokens.SPACE_SM*2)
	var reserved_buttons=float(Tokens.BUTTON_W_MD*3+Tokens.SPACE_MD*4)
	return minf(preferred,maxf(1.0,footer_width-reserved_buttons))
func toggle_party_overlay():
	if ui.state().get("deploying",false):
		ui.mock_shell.toggle_character()
		return
	party_overlay_open=not party_overlay_open
	render_party_overlay()
	if is_instance_valid(battle_party_button):
		ui.mark_selected(battle_party_button,party_overlay_open)
	resize(true)
	if party_overlay_open and is_instance_valid(party_overlay):
		UiMotion.fade_in(party_overlay,ui,UiMotion.BASE)
func render_party_overlay():
	if not is_instance_valid(party_overlay):return
	ui.clear(party_overlay)
	if not party_overlay_open or ui.state().get("deploying",false):
		party_overlay.hide()
		if is_instance_valid(battle_party_button):ui.mark_selected(battle_party_button,false)
		return
	party_overlay.show()
	party_overlay.add_theme_stylebox_override("panel",Tokens.box(Tokens.SURFACE))
	if is_instance_valid(battle_party_button):ui.mark_selected(battle_party_button,true)
	var body=VBoxContainer.new()
	party_overlay.add_child(body)
	var allies=ui.state().get("units",[]).filter(func(u):return u.get("side")=="ally")
	ui.label_(body,"パーティメンバー     %d / %d" % [allies.size(),int(ui.campaign().get("partyLimit",12))])
	var filter=ui.mock_shell.job_filter(body,party_overlay_job,func(value):
		party_overlay_job=value
		for row in body.find_children("*","Button",true,false):
			if row.has_meta("roster_job"):row.visible=value.is_empty() or row.get_meta("roster_job")==value)
	filter.name="BattlePartyJobFilter"
	var list=ui.scroller(body)
	list.get_parent().name="BattlePartyOverlayScroll"
	list.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",0)
	var inv_by_char=ui.campaign().get("inventoryByCharacter",{})
	for u in allies:
		var uid=str(u.id)
		var button=local(list,"",open_equipment_sheet.bind(uid))
		button.name="BattlePartyMember_"+uid
		button.set_meta("roster_job",str(u.get("job","")))
		button.visible=party_overlay_job.is_empty() or str(u.get("job",""))==party_overlay_job
		button.custom_minimum_size=Vector2(254,88)
		var line=ui.mock_shell.roster_member_line(button,u)
		var info=line.get_node("MemberInfo")
		var inventory=inv_by_char.get(uid,{});var capacity=inventory.get("capacity",{})
		var detail_row=HBoxContainer.new();detail_row.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail_row.add_theme_constant_override("separation",Tokens.SPACE_MD);info.add_child(detail_row)
		var cap_label=Label.new();cap_label.text="%s / %s" % [int(capacity.get("used",0)),int(capacity.get("limit",0)) if capacity.get("limit")!=null else "∞"];cap_label.add_theme_font_size_override("font_size",Tokens.FONT_SM);cap_label.autowrap_mode=TextServer.AUTOWRAP_OFF;cap_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail_row.add_child(cap_label)
		if u.has("carriedWeight"):
			var carried := float(u.get("carriedWeight",0))+float(u.get("fallenWeightShare",0))
			var limit := float(u.get("weightLimit",u.get("str",0)))
			var wt_label=Label.new();wt_label.text="Wt %s / %s" % [_format_number(carried),_format_number(limit)];wt_label.add_theme_font_size_override("font_size",Tokens.FONT_SM);wt_label.autowrap_mode=TextServer.AUTOWRAP_OFF;wt_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail_row.add_child(wt_label)
			if bool(u.get("overburdened",false)) or (limit>0.0 and carried>limit):wt_label.add_theme_color_override("font_color",Tokens.DANGER)
		if int(u.get("hp",0))<=0:
			var ko=Label.new();ko.text="戦闘不能";ko.add_theme_font_size_override("font_size",Tokens.FONT_XS);ko.add_theme_color_override("font_color",Tokens.DANGER);ko.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(ko)
		for child in info.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
func target_name(id) -> String:
	return str(unit(id).get("name","対象不明"))
func command_selected(kind: String) -> bool:
	return not action_menu and (ui.command==kind or kind=="action_skill" and ui.command=="action_return" or kind=="items" and ui.command in ["action_item","action_ether"])
func render_bottom_commands():
	buttons.clear()
	var a=acting()
	for pair in COMMANDS:
		var selected=command_selected(pair[0])
		var control=ui.icons.apply(b(bottom_commands,pair[1],choose_command.bind(pair[0]),a.get("side")!="ally" or ui.state().get("deploying",false) or ui.state().get("result")!=null or ui.data.get("presentation") is Dictionary or range_reference),ui.icons.command(pair[0]),40 if ui.size.x>=1800 else 24);control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;Tokens.apply_button_size(control,Tokens.BUTTON_LG if ui.ui_size_mode=="standard" else Tokens.BUTTON_MD,false)
		control.tooltip_text="装備から得たスキルを選びます。アイコンを押すと効果を確認できます。" if pair[0]=="action_skill" else ui.command_hint(pair[0]);ui.memory.key(control,"command_"+pair[0]);buttons[pair[0]]=control
		control.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
		control.add_theme_constant_override("h_separation",Tokens.SPACE_SM)
		ui.mark_selected(control,selected)
		if pair[0]=="items" and not ui.data.get("itemUseInfo") is Dictionary:
			control.tooltip_text="拳の効果がないため使用できません。クリックで説明"
		if pair[0]=="action_skill" and expanded_menu=="action_skill" and ui.command in ["action_skill","action_return"] and not action_menu:render_skills(bottom_commands)
		if pair[0]=="items" and expanded_menu=="items" and ui.command in ["items","action_item","action_ether"] and not action_menu:render_items()
func choose_command(kind: String):
	if menu_transition:return
	if kind in ["action_skill","items"] and expanded_menu==kind:
		close_menu();return
	if kind not in ["action_skill","items"]:expanded_menu=""
	if kind=="action_skill":open_skills()
	else:ui.choose_command(kind)
func open_skills():
	if menu_transition:return
	expanded_menu="action_skill";animate_menu=true
	if ui.locked or ui.presenting or ui.closing or range_reference:return
	ui.invalidate_preview();action_menu=false;item_list=false;skill_list=true;selected_cell=-1;selected_enemy="";ui.command="action_skill";ui.render()
func back_to_commands():
	if ui.locked or ui.presenting or ui.closing:return
	ui.invalidate_preview();expanded_menu="";item_list=false;skill_list=false;action_menu=true;selected_cell=-1;selected_enemy="";ui.audio.ui("cancel");ui.render()
func open_items():
	if menu_transition:return
	if not ui.data.get("itemUseInfo") is Dictionary:
		ui.notice="拳の効果がないためアイテムを使用できません。片手を空けるか、拳を装備してください。";ui.render();return
	expanded_menu="items";animate_menu=true
	if ui.locked or ui.presenting or ui.closing or range_reference:return
	ui.invalidate_preview();action_menu=false;skill_list=false;item_list=true;selected_cell=-1;selected_enemy="";ui.command="items";ui.render()
func item_count(id: String) -> int:
	if ui.state().has("itemInventories"):return int(ui.state().itemInventories.get(acting().get("id",""),{}).get(id,0))
	return int(ui.state().get("ethers",0)) if id=="ether" else int(ui.state().get("potions",{}).get("ally",0))
func item_range_text() -> String:
	var info=ui.data.get("itemUseInfo")
	return BattleText.item_range(int(info.get("level",0)) if info is Dictionary else 0)
func skill_source_text(skill: Dictionary) -> String:
	var parts=[]
	for source in skill.get("sources",[]):
		parts.append(BattleText.source_name(source, ui.campaign().get("slots", {}), true))
	return " / ".join(parts)
func skill_source_short(skill: Dictionary) -> String:
	var slot=str(skill.get("slot",""))
	if slot.is_empty():return ""
	var label=str(ui.campaign().get("slots",{}).get(slot,slot))
	var options=ui.data.get("skillset",[])+ui.data.get("returnSkillset",[])
	var same_source=options.filter(func(other):return other.get("slot","")==slot and other.get("id","")==skill.get("id",""))
	if same_source.size()>1:label+="・付与%d" % int(skill.get("grantSlot",1))
	return label
func render_items():
	var list=menu_content(bottom_commands,"BattleItemList")
	var grants=ui.data.get("skillset",[]).filter(func(skill):return skill.id=="skill_item_use")
	var item_info=ui.data.get("itemUseInfo")
	if grants.size()>1:
		l(list,"使用するスキル")
		for grant in grants:
			var selected=item_info is Dictionary and item_info.get("key","")==grant.get("key","")
			var text="アイテム使用 Lv%d（" % int(grant.get("level",1))+skill_source_short(grant)+"）"
			if int(grant.get("cooldown",0))>0:text+="\nクールタイム中"
			var choice=b(list,text,ui.select_skill.bind(str(grant.get("key",grant.id))),int(grant.get("cooldown",0))>0)
			choice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			preload("res://comparison_skill_icon.gd").bind_hover(choice,str(grant.id),str(grant.name),int(grant.get("level",1)),ui.campaign())
			choice.tooltip_text+="\n"+skill_source_text(grant)
			ui.mark_selected(choice,selected)
			ui.memory.key(choice,"item_skill_"+str(grant.get("key",grant.id)))
	for item in ItemMenu.definitions(ui.campaign()):
		var kind=str(item.get("battleKind",""))
		if kind.is_empty():continue
		var count=item_count(str(item.id))
		var reason=""
		if not item_info is Dictionary:reason="拳の効果なし"
		elif item_info is Dictionary and int(item_info.get("cooldown",0))>0:reason="使用スキルはクールタイム中"
		elif item.get("battleRole","")=="job_porter" and acting().get("job")!="job_porter":reason="ポーター専用"
		elif count<=0:reason="在庫なし"
		elif ui.data.get("choices",{}).get(kind,[]).is_empty():reason="回復できる生存味方なし"
		var selected=not item_list and ui.command==kind
		var control=b(list,"%s / %d個" % [item.name,count],ui.choose_command.bind(kind),not reason.is_empty())
		control.set_script(preload("res://equipment_tooltip.gd"))
		control.configure_entry({"name":item.name,"kind":"item","definition":item},ui.campaign())
		control.tooltip_text+="\n"+item_range_text()+" / 1個・1行動"+(" / "+reason if not reason.is_empty() else "")
		control.name="BattleItem_"+str(item.id);ui.icons.apply(control,str(item.id));ui.mark_selected(control,selected)

func skill_unavailable_reason() -> String:
	if ui.command=="action_return":
		var selected=ui.data.get("returnSkillInfo")
		return "この付与元の帰還は使用済みです" if selected is Dictionary and selected.get("used",false) else ""
	if ui.command!="action_skill":return ""
	for option in ui.data.get("skillset",[]):
		if option.get("selected",false) and int(option.get("cooldown",0))>0:return "クールタイム中：次の行動機会から使用できます"
	var info=ui.data.get("skillInfo");var cost=int(info.get("cost",1)) if info is Dictionary else 1
	if int(acting().get("mp",0))<cost:return "MP不足（現在%d／必要%d）" % [acting().get("mp",0),cost]
	if ui.data.get("skill")=="陣形強化" and not ui.data.get("formed",{}).get("ally",false):return "護送陣が未成立のため実行できません"
	return ""
func render_target():
	var stage=state_id();var heading=ui.row(target_box) if ui.ui_size_mode!="standard" and ui.command=="action_skill" else target_box
	if stage=="B1" or (stage!="B2" and ui.command!="action_skill"):
		l(heading,"移動先を選択" if stage=="B1" else command_name(),true).name="DecisionTitle"
	var split=VBoxContainer.new();split.add_theme_constant_override("separation",Tokens.SPACE_MD);split.size_flags_vertical=Control.SIZE_EXPAND_FILL;target_box.add_child(split)
	var main=VBoxContainer.new();main.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(main)
	var facts=VBoxContainer.new();facts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(facts)
	facts.add_theme_constant_override("separation",Tokens.SPACE_SM if ui.ui_size_mode=="standard" else Tokens.SPACE_XS)
	if ui.command=="action_move":render_move(main)
	else:render_prediction(main,facts)
	var cost=l(main,cost_text());cost.name="ActionCost";cost.visible=ui.command!="action_skill"
	var availability=l(main,"");availability.name="ActionAvailability"
	if ui.preview_pending:availability.text="予測を取得中…"
	elif ui.can_commit():availability.text=""
	elif not skill_unavailable_reason().is_empty():availability.text=skill_unavailable_reason()
	elif not ui.notice.is_empty():availability.text=ui.notice
	elif not action_menu and selected_cell>=0:availability.text="射程・条件を確認してください。"
	availability.visible=ui.command!="action_move" and (ui.command!="action_skill" or (not availability.text.begins_with("MP不足") and not availability.text.is_empty()))
	for fact in facts.get_children():
		if fact is Label:fact.add_theme_color_override("font_color",Tokens.MUTED_INK)
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm"
	if stage=="B2":
		var reference=b(ui.battle_actions,"仮位置の射程参考",open_range_reference)
		Tokens.apply_button_size(reference,Tokens.BUTTON_MD,false);ui.memory.key(reference,"range_reference")
	var controls=ui.row(ui.battle_actions)
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if stage in ["B2","B4"] or ui.can_commit():
		var commit=ui.action_button(b(controls,"実行",ui.commit,not ui.can_commit()),"sm")
		commit.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ui.memory.key(commit,"battle_commit")
	var cancel=b(controls,"キャンセル",ui.cancel)
	cancel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;Tokens.apply_button_preset(cancel,"sm");ui.memory.key(cancel,"battle_cancel")
func render_move(main):
	if not ui.preview_ready or ui.pending==null:return
	var gate_effect := sluice_move_effect(ui.state(), acting(), ui.preview)
	if gate_effect.is_empty():return
	var note = l(main, gate_effect)
	note.name = "SluiceMoveEffect"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
func sluice_move_effect(state: Dictionary, mover: Dictionary, preview: Dictionary) -> String:
	var gate = state.get("sluice")
	if not gate is Dictionary or preview.get("kind") != "action_move" or mover.get("side") != "ally":
		return ""
	var lever_held := false
	var porter_at_exit := false
	# Preview units already include both ends of a swap.
	for member in preview.units:
		if member.side != "ally" or member.hp <= 0:
			continue
		if member.job == "job_porter":
			porter_at_exit = porter_at_exit or member.pos == gate.exit
		elif member.pos == gate.lever:
			lever_held = true
	var opens: bool = not bool(gate.open) and mover.job != "job_porter" and preview.destination == gate.lever
	var stays_open: bool = lever_held and (bool(gate.open) or opens)
	var effects := PackedStringArray()
	if opens:
		effects.append("水門：開く")
	elif gate.open and not stays_open:
		effects.append("水門：閉じる")
	if stays_open and porter_at_exit:
		effects.append("水門突破")
	return "　".join(effects)

func render_prediction(main,facts):
	var summary="クリックしてターゲットを選択してください。"
	if selected_cell>=0:
		var occupant=ui.board.unit_at(selected_cell)
		summary=coord(selected_cell)+" / "+str(occupant.get("name","空きマス"))
		if not occupant.is_empty():summary+=" HP%d/%d" % [occupant.hp,occupant.max]
	if ui.command=="action_defend":summary="防御 / 対象不要"
	elif ui.pending is String:
		var target=unit(ui.pending);summary=str(target.get("name",ui.pending))+" / "+coord(target.get("pos",0))+" HP%d/%d" % [target.get("hp",0),target.get("max",0)]
	elif ui.pending is Array or not ui.chosen.is_empty():summary="選択 %d人: " % ui.chosen.size()+" / ".join(ui.chosen.map(func(id):return ui.member_name(str(id))))
	if ui.command=="action_skill" and ui.data.get("skill")=="足払い":summary="対象：自分の周囲8マスの生存敵 / ダメージ0"
	if ui.command=="action_skill" and ui.data.get("skill")=="陣形強化":summary="対象：味方全員"
	var target=l(main,summary,true);target.name="TargetSummary";ui.short_name(target,summary)
	target.visible=ui.command!="action_defend" and (not ui.pending is String) and (ui.command!="action_skill" or selected_cell<0)
	var hits=ui.preview.get("damagePreview",[])
	if ui.preview_ready:
		for hit in hits:
			if hit.get("targetId")==hit.get("recipientId"):continue
			var detail=l(main,"肩代わり：%s → %s" % [hit.get("targetName",""),hit.get("recipientName","")],true)
			detail.name="RecipientSummary_"+str(hit.get("recipientId",""))
	if ui.command=="action_defend":ui.icons.line(ui,main,"defense_up","被ダメージ半減 / 次の本人の番まで")
	if ui.preview_ready:
		for effect in ui.preview.get("effectPreview",[]):
			if effect.get("cast",false):l(main,"次の本人の行動で指定マスへ発動 / 構え開始時MP1（中断時も返却なし） / 対象は追尾しません")
			if effect.has("skipChance"):l(main,"%s：次の手番スキップ 成功率%d%%（対象ごとに判定）%s" % [target_name(effect.id),roundi(effect.skipChance*100)," / すでに次回スキップ（重複なし）" if effect.get("alreadySkipping",false) else ""])
			if effect.get("position")!=null:l(main,target_name(effect.id)+" → "+coord(int(effect.position)))
			if effect.get("boost",false):
				ui.icons.line(ui,main,"attack_up","味方全員の攻撃×1.75")
				ui.icons.line(ui,main,"defense_up","味方全員の被ダメージ×0.65")
	if ui.command=="action_skill":
		var info=ui.data.get("skillInfo",{});info=info if info is Dictionary else {}
		if info.get("target")=="pair" and not ui.preview_ready:l(facts,"異なる2人が必要 / 選択 %d/2" % ui.chosen.size())
		elif info.get("target")=="upToTwo":l(facts,"1〜2人を指定 / 選択 %d人" % ui.chosen.size())
		if ui.data.get("skill") in ["スタンプ","足払い"]:l(facts,"空振りでもMP1・1行動を消費")
		if ui.data.get("skill")=="引き寄せ" and ui.preview_ready and not ui.preview.get("effectPreview",[]).any(func(e):return e.get("position")!=null):l(main,"引き寄せ先が占有中：移動なし / MP1・1行動を消費")
func cost_text() -> String:
	if ui.command in ["action_item","action_ether"]:return "本人の所持品を消費: 1個・1行動 / 残り%d個" % item_count("ether" if ui.command=="action_ether" else "potion")
	var info=ui.data.get("skillInfo")
	return "消費MP: %d" % (info.get("cost",1) if info is Dictionary else 1) if ui.command=="action_skill" else "消費MP: 0"
func render_skills(parent):
	var list=menu_content(parent,"BattleSkillList")
	for skill in ui.data.get("skillset",[]):
		var line=ui.row(list)
		var key=str(skill.get("key",skill.id))
		var cooling=int(skill.get("cooldown",0))>0
		var selected=ui.command=="action_skill" and not skill_list and skill.get("selected",false)
		var text=str(skill.name)
		var level=int(skill.get("level",1))
		var has_level=not ui.icons.approved.skills.get(str(skill.id),{}).get("levels",{}).is_empty()
		if has_level:text+=" Lv%d" % level
		var source=skill_source_text(skill)
		var short_source=skill_source_short(skill)
		if not short_source.is_empty():text+="（"+short_source+"）"
		if cooling:text+="\nクールタイム中"
		var control=b(line,text,ui.select_skill.bind(key),cooling)
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		control.name="BattleSkill_"+str(skill.id);ui.mark_selected(control,selected)
		preload("res://comparison_skill_icon.gd").bind_hover(control,str(skill.id),str(skill.name),level,ui.campaign())
		control.tooltip_text+="\n"+source+("\nクールタイム中：次の行動機会から使用できます" if cooling else "")
		ui.memory.key(control,"battle_skill_"+key)
		var info=skill_info_icon(line,str(skill.id),str(skill.name),level)
		ui.memory.key(info,"battle_skill_details_"+key)
	for skill in ui.data.get("returnSkillset",[]):
		var line=ui.row(list)
		var key=str(skill.key)
		var source=skill_source_text(skill)
		var selected=ui.command=="action_return" and not skill_list and skill.get("selected",false)
		var text="帰還（"+skill_source_short(skill)+"）"
		if skill.get("used",false):text+="\n使用済み"
		var control=b(line,text,ui.select_return_skill.bind(key),skill.get("used",false));control.name="BattleSkill_skill_return_home";ui.mark_selected(control,selected)
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		preload("res://comparison_skill_icon.gd").bind_hover(control,"skill_return_home","帰還",1,ui.campaign())
		control.tooltip_text+="\n"+source+"\nこの付与元は1戦闘に1回"
		ui.memory.key(control,"battle_return_"+key)
		var info=skill_info_icon(line,"skill_return_home","帰還",1)
		ui.memory.key(info,"battle_return_details_"+key)
func skill_info_icon(line,id: String,title: String,level: int) -> Button:
	var info=ui.local_button(line,"",ui.show_skill_details.bind(id,title,level))
	info.name="BattleSkillDetails_"+id
	preload("res://comparison_skill_icon.gd").bind_hover(info,id,title,level,ui.campaign())
	ui.icons.apply(info,ui.icons.skill(id,level),32);line.move_child(info,0)
	return info
func has_return() -> bool:return acting().get("effects",[]).has("skill_return_home")
func command_name() -> String:
	if ui.command=="action_return":return "帰還"
	for item in ItemMenu.definitions(ui.campaign()):
		if item.get("battleKind")==ui.command:return str(item.name)
	for pair in COMMANDS:
		if pair[0]==ui.command:return str(ui.data.get("skill","スキル")) if ui.command=="action_skill" else pair[1]
	return ui.command
func discard_reference():
	reference_generation+=1;range_reference=false;reference_preview={};reference_pending=false;reference_error=""
func open_range_reference():
	if ui.command!="action_move" or ui.pending==null or not ui.preview_ready:return
	discard_reference();range_reference=true;reference_kind="action_attack";reference_preview=ui.preview.duplicate(true)
	ui.render()
func close_reference():
	if not range_reference:return
	discard_reference();ui.memory.request_focus("range_reference");ui.render()
func request_reference(which: String):
	if not range_reference:return
	reference_generation+=1;reference_pending=true;reference_error="";reference_kind=which
	reference_preview=ui.preview.duplicate(true);reference_preview.ranges=[];reference_preview.targets=[];reference_preview.cells=[]
	var token=reference_generation;var generation=ui.generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var destination=ui.pending;var actor=ui.state().get("actor");var actions=ui.state().get("actions");var skill=ui.data.get("skill")
	ui.render()
	while ui.engine.busy and not ui.closing:
		await ui.get_tree().process_frame
		if token!=reference_generation:return
	if ui.closing or token!=reference_generation:return
	var reply=await ui.engine.request({"op":"preview","kind":"action_move","target":destination,"previewKind":which})
	if ui.handle_connection_loss(reply,connection):return
	# Reference responses own no movement decision or old UI nodes. Closure/reopen,
	# new/load, actor/skill changes and connection replacement all invalidate them.
	if ui.closing or token!=reference_generation or not range_reference or generation!=ui.generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:return
	if destination!=ui.pending or actor!=ui.state().get("actor") or actions!=ui.state().get("actions") or skill!=ui.data.get("skill"):return
	reference_pending=false
	if reply.get("ok",false):reference_preview=reply.preview
	else:
		reference_error=str(reply.get("error","射程参考を取得できませんでした"))
	ui.render()
func render_reference():
	var compact=ui.ui_size_mode!="standard"
	if compact:target_box.add_theme_constant_override("separation",Tokens.SPACE_XS)
	var position_text="仮位置: "+coord(ui.pending)+" / "+("通常攻撃" if reference_kind=="action_attack" else "スキル")+" / 参考%dマス" % reference_preview.get("ranges",[]).size()
	l(target_box,"仮位置からの射程参考"+(" / "+position_text if compact else ""),not compact)
	l(target_box,"移動で手番終了・ここでは攻撃不可。次の本人の番まで状況は変わります。")
	var values=VBoxContainer.new();values.name="ReferenceValues";target_box.add_child(values)
	if not compact:l(values,position_text)
	l(values,"対象候補: "+("取得中…" if reference_pending else reference_error if not reference_error.is_empty() else " / ".join(reference_preview.get("targets",[]))))
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm"
	var choices=ui.row(ui.battle_actions)
	for entry in [["通常攻撃の参考","action_attack"],["スキルの参考","action_skill"]]:
		var option=b(choices,entry[0],request_reference.bind(entry[1]))
		option.size_flags_horizontal=Control.SIZE_EXPAND_FILL;Tokens.apply_button_size(option,Tokens.BUTTON_MD)
	var back=local(ui.battle_actions,"仮置きに戻る",close_reference)
	Tokens.apply_button_size(back,Tokens.BUTTON_MD,false);ui.memory.key(back,"reference_back")
func render_presentation(phase: Dictionary):
	if phase.get("phase")=="action":presentation_action=phase.duplicate(true)
	elif presentation_action.get("action_id")!=phase.get("action_id"):presentation_action={}
	var action=l(target_box,str(presentation_action.get("label",phase.get("label",""))));action.name="PresentationAction"
	var phase_label=str(phase.get("label",""))
	if phase_label!=action.text:l(target_box,phase_label)
	if phase.get("unit_id")!=null and phase.get("phase") in ["hurt","heal"]:
		var u=unit(phase.unit_id);ui.icons.line(ui,target_box,"healing" if phase.phase=="heal" else "damage","実受領者: "+str(u.get("name","対象不明"))+" / 現在HP%d/%d" % [u.get("hp",0),u.get("max",0)])
	var target=presentation_action.get("target");var names=[]
	for id in (target if target is Array else [target]):
		if id is String:names.append(target_name(id))
		elif id is int or id is float:names.append(coord(id))
	if presentation_action.get("skill_id")=="skill_formation_boost" or str(presentation_action.get("label","")).contains("陣形強化"):
		l(target_box,"効果対象: 味方全員 / 陣形成立中のみ")
		ui.icons.line(ui,target_box,"attack_up","攻撃×1.75");ui.icons.line(ui,target_box,"defense_up","被害×0.65")
	elif not names.is_empty():l(target_box,"指定対象: "+" / ".join(names))
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm"
func render_deployment():
	var s=ui.state()
	if not s.units.any(func(u):return u.id==ui.selected and u.side=="ally" and u.hp>0):
		ui.selected=""
		for u in s.units:
			if u.side=="ally" and u.hp>0:ui.selected=u.id;break
	ui.battle_actions=deployment_actions
	var reset_btn=b(deployment_actions,"配置リセット",reset_deployment)
	reset_btn.name="DeploymentReset"
	Tokens.apply_button_preset(reset_btn,"md_lg")
	var job=ui.campaign().get("activeQuest")
	if not (job is Dictionary and job.get("id")=="sluice-bell"):
		var retreat_btn=b(deployment_actions,"撤退",func():ui.confirm("戦闘から撤退しますか？",ui.act.bind("retreat",[])))
		retreat_btn.name="DeploymentRetreat"
		Tokens.apply_button_preset(retreat_btn,"md_lg")
	var begin_btn=ui.action_button(b(deployment_actions,"戦闘開始",ui.act.bind("begin",[]),not ui.campaign().get("deploymentRoster",{}).get("canBegin",true)),"md_lg")
	begin_btn.name="DeploymentBegin"
func deployment_changed() -> bool:
	for initial in ui.state().get("deploymentInitial",[]):
		if unit(initial.id).get("pos")!=initial.pos:return true
	return false
func reset_deployment():
	if deployment_changed():ui.confirm("配置を初期位置へ戻します。よろしいですか？",ui.act.bind("deployment_reset",[]))
	else:ui.act("deployment_reset",[])
func render_result():
	l(target_box,"木人の結果" if ui.data.get("trial") is Dictionary else "戦闘結果",true);l(target_box,str(ui.state().result))
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm";var finish=ui.action_button(b(ui.battle_actions,"戦闘を終えて街道へ",ui.act.bind("finishBattle",[]),ui.data.get("trial")!=null));Tokens.apply_button_size(finish,Tokens.BUTTON_MD,false)
func open_equipment_sheet(uid: String):
	await loadout_modal.open(uid)
func open_loadout(uid: String):
	await loadout_modal.open(uid)
func draw_loadout(body,member: Dictionary,tab: String):
	loadout_modal.draw(body,member,tab)

func close_detail() -> bool:
	if range_reference:close_reference();return true
	if is_instance_valid(ui.dialog.window):ui.dialog.close();return true
	if party_overlay_open:
		party_overlay_open=false
		render_party_overlay()
		return true
	return false
func live_board(source_id: int=0) -> bool:
	return not ui.closing and is_instance_valid(ui.board) and ui.board.is_inside_tree() and not ui.board.is_queued_for_deletion() and (source_id==0 or source_id==ui.board.get_instance_id())
func render_person(hover_only := false):
	if ui.state().get("deploying",false):return
	if not live_board() or not is_instance_valid(person_box) or not person_box.is_inside_tree() or person_box.is_queued_for_deletion():return
	ui.clear(person_box)
	person_box.remove_meta("inspected_unit")
	if inspection_pinned and inspected_uid.is_empty():
		l(person_box,"このマスに人物はいません。");return
	var focused={}
	if not inspection_pinned and not ui.state().get("deploying",false) and ui.board.has_focus():
		focused=ui.board.unit_at(ui.board.keyboard_cell)
	if hover_only and inspected_uid.is_empty() and focused.is_empty() and ui.pending==null:
		return
	var u=focused if not focused.is_empty() else unit(inspected_uid)
	var reference=not u.is_empty()
	if (u.is_empty() or (not hover_only and not inspection_pinned)) and ui.pending is String:
		u=unit(str(ui.pending))
		for hit in ui.preview.get("damagePreview",[]):
			if hit.get("targetId")==ui.pending:u=unit(str(hit.get("recipientId",ui.pending)));break
	var phase=ui.data.get("presentation")
	if phase is Dictionary and phase.get("unit_id") is String:u=unit(phase.unit_id)
	if u.is_empty() and selected_cell>=0:u=ui.board.unit_at(selected_cell)

	if u.is_empty():
		return
	person_box.set_meta("inspected_unit",u.id)
	l(person_box,"参照" if reference else "能力").name="InspectedPersonHeading"
	render_person_content(person_box,u,true)
func combat_portrait(parent,u: Dictionary):
	var hero=ui.row(parent)
	var face=local(hero,"",open_equipment_sheet.bind(str(u.id)));face.name="BattleFace_"+str(u.id)
	face.custom_minimum_size=Vector2(64,64);face.icon=ui.portraits.texture(u,true);face.expand_icon=true
	face.tooltip_text=str(u.name)+"の装備・インベントリ";l(hero,str(u.name),true)
func combat_resources(parent,u: Dictionary):
	var resources=ui.row(parent) if ui.ui_size_mode!="standard" else parent
	for resource in ["hp","mp"]:
		var bar=preload("res://battle_resource_bar.gd").new()
		resources.add_child(bar);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		bar.setup(resource,int(u.get(resource,0)),int(u.get("max" if resource=="hp" else "maxMp",0)))
	update_resource_preview(parent,u)
func update_resource_preview(parent,u: Dictionary):
	var changes={"hp":0,"mp":0}
	if ui.preview_ready:
		for effect in ui.preview.get("effectPreview",[]):
			if effect.id==u.get("id"):
				for resource in changes:changes[resource]+=int(effect.get(resource,0))
	for resource in changes:
		var bar=parent.find_child("Inspect_"+resource,true,false)
		if bar!=null:bar.preview(changes[resource])
func render_person_content(parent,u: Dictionary,expanded:=false):
	combat_portrait(parent,u)
	var character={}
	for member in ui.roster():
		if member.id==u.id:character=member;break
	if expanded:
		var identity=character if not character.is_empty() else u
		if u.side=="enemy":
			var jobs={"job_warrior":"戦士","job_scout":"スカウト","job_mage":"魔法使い","job_porter":"ポーター"}
			var current_job=str(u.job)
			if jobs.has(current_job):identity=identity.merged({"role":jobs[current_job]},true)
		ui.pages.party_view.identity(parent,identity)
	combat_resources(parent,u)
	if u.get("skipNextTurn",false):l(parent,"足払い：次の1手番をスキップ")
	var stats=character.get("stats",{});var breakdown=stats.get("attributeBreakdown",{})
	var profile=GridContainer.new()
	profile.name="ElementalCombatProfile"
	profile.tooltip_text=ElementBadges.MATCHUP_TIP
	profile.columns=5
	profile.add_theme_constant_override("h_separation",Tokens.SPACE_SM)
	parent.add_child(profile)
	for stat in ["atk","def"]:
		var title=l(profile,stat.to_upper())
		title.tooltip_text=ElementBadges.MATCHUP_TIP
		title.autowrap_mode=TextServer.AUTOWRAP_OFF
		for element in ["","fire","water","earth"]:
			var cell=ui.row(profile)
			cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			cell.add_theme_constant_override("separation",Tokens.SPACE_XS)
			if element.is_empty():
				ui.icons.add(cell,"attack" if stat=="atk" else "defend",20)
				cell.tooltip_text="物理攻撃力" if stat=="atk" else "物理防御力"
			else:ElementBadges.add(cell,element,20)
			var value=l(cell,str(int(u.get(stat+element.capitalize(),0))))
			value.tooltip_text=ElementBadges.MATCHUP_TIP
			value.autowrap_mode=TextServer.AUTOWRAP_OFF
	if u.has("carriedWeight"):
		var carried=float(u.get("carriedWeight",0))+float(u.get("fallenWeightShare",0));var limit=float(u.get("weightLimit",0))
		var weight_line=l(parent,"Wt %s / STR上限 %s%s" % [_format_number(carried),_format_number(limit),"（超過: SPD 50%）" if u.get("overburdened",false) else ""])
		if bool(u.get("overburdened",false)) or (limit>0.0 and carried>limit):
			weight_line.add_theme_color_override("font_color",Tokens.DANGER)
		if float(u.get("fallenWeightShare",0))>0:
			l(parent,"うち戦闘不能者の分担 %s Wt" % _format_number(float(u.fallenWeightShare)))
	for pair in [["str","STR","strength"],["int","INT","intelligence"],["speed","SPD（行動速度）","speed"]]:
		var value=u.get("agi") if pair[0]=="speed" else stats.get(pair[0],u.get(pair[0]))
		var part=breakdown.get(pair[0],{});var suffix="補正：未取得"
		if part.has("growth"):
			suffix="成長＋%d / 基礎%d" % [part.growth,part.base]
			if int(part.get("equipment",0))!=0:suffix+=" / 装備%+d" % int(part.equipment)
		elif part.has("equipment"):suffix="装備%+d / AGI%d" % [part.equipment,part.agi]
		ui.icons.line(ui,parent,pair[2],pair[1]+" "+("未取得" if value==null else String.num(float(value),1).trim_suffix(".0"))+"（"+suffix+"）")
	if ui.state().get("formationVersion")==1:l(parent,"旧戦闘の陣形条件を継続中")
func pin_inspection(pos: int):
	inspection_pinned=true
	inspected_uid=str(ui.board.unit_at(pos).get("id",""))
	render_person()
func clear_inspection():
	if not inspection_pinned:return
	inspection_pinned=false;inspected_uid="";selected_cell=-1
	render_person(true)
func inspect_hover(uid: String,source=null):
	# A queued callback may carry an already freed Node. Validate this Variant
	# before calling any method or passing it through an Object-typed argument.
	if typeof(source)!=TYPE_NIL and not is_instance_valid(source):return
	var source_id: int=source.get_instance_id() if typeof(source)!=TYPE_NIL else 0
	if not live_board(source_id):return
	if not inspection_pinned:
		inspected_uid=uid;render_person(true)
	refresh_hover()
func invalidate_hover():
	hover_generation+=1;hover_stamp=""
	if is_instance_valid(ui.board):ui.board.hover_caption=""
func refresh_hover():
	if not live_board():return
	var uid=ui.board.hover_uid
	var stamp=JSON.stringify([uid,ui.generation,ui.command,ui.chosen,action_menu,ui.state().get("actions"),ui.state().get("actor"),ui.data.get("skill")])
	if stamp==hover_stamp:return
	hover_stamp=stamp;hover_generation+=1
	if uid.is_empty():ui.board.hover_caption="";return
	if action_menu or item_list or skill_list or ui.state().get("deploying",false) or ui.presenting or ui.data.get("presentation") is Dictionary or ui.command not in ["action_attack","action_skill","action_item","action_ether"]:
		ui.board.hover_caption="" if ui.state().get("deploying",false) else "行動を選択すると効果を予測" if action_menu else "命中：対象外";return
	ui.board.hover_caption="予測取得中…"
	request_hover(uid,hover_generation,ui.generation,ui.engine.connection_generation,ui.board.get_instance_id())
func request_hover(uid: String,token: int,generation: int,connection: int,source_id: int):
	# Only a stable ID crosses awaits: an old board can be freed before either
	# the busy wait or transport response completes.
	while ui.engine.busy and not ui.closing:
		await ui.get_tree().process_frame
		if token!=hover_generation or not live_board(source_id):return
	if not live_board(source_id) or token!=hover_generation or ui.engine.disconnected:return
	var reply=await ui.engine.request({"op":"hover_preview","kind":ui.command,"uid":uid,"chosen":ui.chosen.duplicate()})
	if ui.handle_connection_loss(reply,connection):return
	if not live_board(source_id) or token!=hover_generation or generation!=ui.generation or connection!=ui.engine.connection_generation or ui.board.hover_uid!=uid:return
	if not reply.get("ok",false):ui.board.hover_caption="予測：未取得";return
	var prediction=reply.get("hover",{})
	if prediction.get("status")=="insufficient_mp":ui.board.hover_caption="実行不可（MP不足）";return
	if prediction.get("status")!="ready":ui.board.hover_caption="異なる2人の対象を指定" if prediction.get("status")=="needs_targets" else "対象外";return
	var parts=[]
	for hit in prediction.get("damagePreview",[]):
		parts.append("%sが受ける −%d" % [hit.get("recipientName","対象"),hit.hpLoss])
	if prediction.get("fullHealth",false):parts.append("HP ＋0（HP満タン）")
	if parts.is_empty():
		for effect in prediction.get("effectPreview",[]):
			if effect.get("cast",false):parts.append("次の本人の行動で指定マスへ発動・MP1")
			if effect.get("hp",0)>0:parts.append("HP ＋%d" % effect.hp)
			if effect.has("skipChance"):parts.append("%s 次回スキップ %d%%" % [target_name(effect.id),roundi(effect.skipChance*100)])
			if effect.get("position")!=null:parts.append(target_name(effect.id)+" → "+coord(int(effect.position)))
			if effect.get("mp",0)>0:parts.append("MP ＋%d" % effect.mp)
			if effect.get("boost",false):parts.append("攻撃×1.75 / 被害×0.65")
			if effect.get("cover")!=null or not effect.get("covers",[]).is_empty():parts.append("次の本人の番までかばう")
	ui.board.hover_caption=("予測："+" / ".join(parts) if not parts.is_empty() else "予測：効果なし")+"\n命中："+("%d%%" % int(prediction.accuracy) if prediction.get("accuracy")!=null else "対象外")

func menu_content(parent,kind: String) -> VBoxContainer:
	var wrapper=preload("res://sliding_menu.gd").new();wrapper.name=kind+"Slide";wrapper.opening=animate_menu;wrapper.fast=ui.checks_fast;animate_menu=false
	parent.add_child(wrapper);wrapper.content.name=kind;return wrapper.content
func close_menu():
	if ui.locked or ui.presenting or ui.closing or menu_transition:return
	menu_transition=true;menu_ticket+=1;var ticket=menu_ticket
	var wrapper=bottom_commands.find_child("BattleSkillListSlide" if expanded_menu=="action_skill" else "BattleItemListSlide",true,false)
	if wrapper!=null:wrapper.retract()
	await ui.get_tree().create_timer(.001 if ui.checks_fast else .2).timeout
	if ticket!=menu_ticket or ui.closing:return
	menu_transition=false;expanded_menu="";ui.invalidate_preview();item_list=false;skill_list=false;action_menu=true;ui.render()
func visual_only(control: Control):
	control.mouse_filter=Control.MOUSE_FILTER_IGNORE;control.focus_mode=Control.FOCUS_NONE
	control.process_mode=Node.PROCESS_MODE_DISABLED
	for child in control.get_children(true):
		if child is Control:visual_only(child)
func clear_opening_visual():
	opening_generation+=1
	if opening_tween and opening_tween.is_running():opening_tween.kill()
	if is_instance_valid(opening_visual):opening_visual.queue_free()
	opening_visual=null
func open_actor_panel():
	if not is_instance_valid(left_panel) or not left_panel.visible or ui.closing:return
	clear_opening_visual()
	var ticket=opening_generation
	var panel=left_panel
	await ui.get_tree().process_frame
	while is_instance_valid(panel) and panel.pending_restore!=null and not ui.closing:
		await ui.get_tree().process_frame
	if ticket!=opening_generation or not is_instance_valid(panel) or not panel.is_inside_tree() or panel.is_queued_for_deletion() or ui.closing:return
	var first=ui.battle_header.find_child("TurnCard_0",true,false)
	if first==null:return
	opening_visual=panel.duplicate(0);opening_visual.name="CommandOpeningFlight";opening_visual.z_index=0
	middle.add_child(opening_visual);visual_only(opening_visual)
	opening_visual.position=first.global_position-middle.global_position;opening_visual.scale=first.size/panel.size
	ui.battle_header.z_index=1;panel.hide()
	animation_trace.append({"stage":"command_open","actor":last_actor})
	opening_tween=ui.create_tween().bind_node(opening_visual);opening_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);opening_tween.set_parallel(true)
	var open_dur=UiMotion.duration(UiMotion.EMPHASIS,ui)
	opening_tween.tween_property(opening_visual,"position",panel.position,open_dur).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
	opening_tween.tween_property(opening_visual,"scale",Vector2.ONE,open_dur).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
	opening_tween.finished.connect(finish_opening.bind(ticket,panel),CONNECT_ONE_SHOT)
func finish_opening(ticket: int,panel):
	if ticket!=opening_generation:return
	if is_instance_valid(opening_visual):opening_visual.queue_free()
	opening_visual=null
	if is_instance_valid(panel) and not ui.presenting:panel.show()
func clear_action_visual():
	if is_instance_valid(action_visual):action_visual.queue_free()
	action_visual=null
func capture_action_visual():
	if is_instance_valid(opening_visual):clear_opening_visual();left_panel.show()
	clear_action_visual()
	if not is_instance_valid(left_panel) or not left_panel.visible:return
	action_visual=left_panel.duplicate(0);action_visual.name="CommandActionFlight";visual_only(action_visual)
	middle.add_child(action_visual);action_visual.position=left_panel.position;action_visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.battle_header.z_index=1
func prepare_action(phase: Dictionary):
	var id=str(phase.get("action_id",""))
	if phase.get("phase")!="action" or id==shifted_action:return
	await ui.get_tree().process_frame
	if ui.closing or not live_board():clear_action_visual();return
	var band=ui.battle_header.find_child("TurnOrder",true,false)
	if band==null:return
	var first=band.find_child("TurnCard_0",false,false);var second=band.find_child("TurnCard_1",false,false)
	if first==null:return
	var scroll=band.get_parent();scroll.scroll_horizontal=0
	queue_distance=int(second.position.x-first.position.x) if second!=null else int(first.size.x+8)
	if phase.get("kind")=="action_skip":
		var flying=first.duplicate(0);flying.name="TurnSkipFlight";middle.add_child(flying);flying.position=first.global_position-middle.global_position;flying.z_index=30;visual_only(flying)
		first.modulate.a=0
		animation_trace.append({"action":id,"stage":"skip_fly_right","actor":phase.get("actor_id")})
		var flight=ui.create_tween().bind_node(flying);flight.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);flight.tween_property(flying,"position:x",middle.size.x+first.size.x,UiMotion.duration(UiMotion.EMPHASIS,ui)).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
		await flight.finished
		if is_instance_valid(flying):flying.queue_free()
	else:animation_trace.append({"action":id,"stage":"command_shrink"})
	if phase.get("kind")!="action_skip" and is_instance_valid(action_visual):
		left_panel.hide()
		var destination=first.global_position-middle.global_position
		var tween=ui.create_tween();tween.set_parallel(true)
		var shrink_dur=UiMotion.duration(UiMotion.EMPHASIS,ui)
		tween.tween_property(action_visual,"position",destination,shrink_dur).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
		tween.tween_property(action_visual,"scale",first.size/action_visual.size,shrink_dur).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
		await tween.finished
		clear_action_visual()
	if ui.closing or not is_instance_valid(scroll):return
	animation_trace.append({"action":id,"stage":"queue_slide","distance":queue_distance})
	var slide=ui.create_tween();slide.tween_property(scroll,"scroll_horizontal",queue_distance,UiMotion.duration(UiMotion.BASE,ui)).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
	await slide.finished
	if ui.closing:return
	shifted_action=id;animation_trace.append({"action":id,"stage":"turn_skipped" if phase.get("kind")=="action_skip" else "character_action"})
	if animation_trace.size()>90:animation_trace=animation_trace.slice(-90)
