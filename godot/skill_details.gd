extends Window
## A read-only child window; the underlying selection and preview stay intact.
var ui
var origin: Control
var origin_name := ""
var host_ref: WeakRef
var epoch := 0
var connection := 0
var context_stamp := ""
const Layout=preload("res://window_grid.gd")
func stamp() -> String:return JSON.stringify([ui.page,ui.state().get("actor"),ui.state().get("actions"),ui.pages.party_uid,ui.campaign().get("inventoryToken")])
func configure(frontend,doc: Dictionary,context: String,note: String="",flavor: String=""):
 ui=frontend;epoch=ui.pages.epoch;connection=ui.engine.connection_generation;context_stamp=stamp()
 name="SkillDetailsWindow";title=doc.get("window_title","スキルの説明");exclusive=true;transient=true
 origin=get_parent().gui_get_focus_owner() if get_parent() is Window else ui.get_viewport().gui_get_focus_owner()
 host_ref=weakref(get_parent())
 if is_instance_valid(origin):origin_name=str(origin.name)
 var layout=Layout.new();add_child(layout);layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var heading=Layout.title_label(doc.title);heading.name="SkillDetailsTitle";layout.add_child(heading)
 var column=VBoxContainer.new();column.set_meta("ui_region","SkillDetailsSummary");layout.add_child(column)
 column.add_theme_constant_override("separation",0)
 var summary_content=ui.scroller(column)
 var summary_scroll=summary_content.get_parent()
 summary_scroll.size_flags_vertical=Control.SIZE_FILL
 var fit_summary=func():summary_scroll.custom_minimum_size.y=Layout.local_rect(Vector2(get_tree().root.size),2,2,7,1).size.y
 size_changed.connect(fit_summary)
 fit_summary.call()
 if not context.is_empty() and doc.has("summary_text"):
  var who=ui.label_(summary_content,context);who.name="SkillDetailsContext";who.max_lines_visible=1;who.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;who.tooltip_text=context
 var summary=ui.label_(summary_content,doc.get("summary_text",preload("res://skill_text.gd").summary(doc)));summary.name="SkillDetailsSummary";summary.set_meta("ui_region","")
 var tabs=TabContainer.new();tabs.name="SkillDetailsTabs";tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
 var pages=[["効果",doc.get("body_text",preload("res://skill_text.gd").body(doc)),"SkillDetailsBody"],["用語","","SkillDetailsGlossary"]]
 if not flavor.is_empty():pages.append(["説明",flavor,"SkillDetailsFlavor"])
 if not note.is_empty():pages.append(["装備メモ（原文）",note,"SkillDetailsNote"])
 for spec in pages:
  var scroll=ScrollContainer.new();scroll.name=spec[0];scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
  var text=ui.label_(scroll,spec[1]);text.name=spec[2];text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 tabs.set_tab_disabled(1,true)
 var actions=ui.row(layout);actions.name="SkillDetailsActions"
 layout.set_regions(heading,column,actions)
 var back=ui.local_button(actions,"閉じる・元の選択へ",finish);back.name="SkillDetailsBack"
 close_requested.connect(finish)
 window_input.connect(func(event):
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
   set_input_as_handled();ui.modal_escape_frame=Engine.get_process_frames();finish())
 ui.preferences.place_detail_frame(self)
 popup();back.grab_focus()
func _process(_delta):
 if ui==null:return
 if ui.closing or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or context_stamp!=stamp():hide();queue_free()
func finish():
 hide();restore_focus.call_deferred();queue_free()
func restore_focus():
 if not is_instance_valid(ui) or ui.closing or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or context_stamp!=stamp():return
 var target=null
 if is_instance_valid(origin) and origin.is_inside_tree() and not origin.is_queued_for_deletion() and str(origin.name)==origin_name:target=origin
 elif not origin_name.is_empty() and not origin_name.begins_with("@"):
  var host=host_ref.get_ref()
  if is_instance_valid(host):target=host.find_child(origin_name,true,false)
 if target is Control and target.is_inside_tree() and not target.is_queued_for_deletion() and target.is_visible_in_tree():target.grab_focus()
