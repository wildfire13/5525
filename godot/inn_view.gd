extends RefCounted
## Inn presentation never writes character stats: the canonical inn action commits
## the entire party and payment before the transient count-up begins.
const RECOVERY_SECONDS := 1.2
const FULL_GREETING := "みなさん、お元気ですね。今は休まなくても大丈夫ですよ。"
const RESTED_GREETING := "おはようございます。みなさん、ゆっくり休めましたね。"
const HelpBadge=preload("res://help_badge.gd")
const ScreenGrid=preload("res://screen_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
var owner_ref: WeakRef
var pages:
 get:return owner_ref.get_ref()
var ui
var pending := false
var sequence := 0
var dialogue := ""
var recovered: Dictionary = {}
var healing_party: Array = []
var recovery_started := 0
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func reset():
 sequence+=1;pending=false;dialogue="";recovered={};healing_party=[];recovery_started=0
func available() -> bool:
 return ui.page=="inn" and pages.c().get("phase")=="town" and pages.c().get("inn",{}).get("available",false)
func progress() -> float:
 return clampf(float(Time.get_ticks_msec()-recovery_started)/(RECOVERY_SECONDS*1000.0),0.0,1.0) if recovery_started>0 else 1.0
func render(parent):
 if pages.facility_entry.render_top(parent,"inn"):reset();return
 var surface=Control.new();parent.add_child(surface);surface.name="InnService";surface.custom_minimum_size.y=ui.mock_shell.content_height();surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var panel=PanelContainer.new();panel.name="FacilityChoices";surface.add_child(panel)
 panel.add_theme_stylebox_override("panel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_NONE))
 panel.top_level=true
 var panel_ref=weakref(panel)
 var place_panel=func():
  var target=panel_ref.get_ref()
  if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():return
  var area=ScreenGrid.cell_rect(ui.size,0,2,6,7)
  var h=clampf(target.get_combined_minimum_size().y,0.0,area.size.y)
  ScreenGrid.place(target,Rect2(area.position,Vector2(area.size.x,h)))
 ui.resized.connect(place_panel)
 panel.minimum_size_changed.connect(place_panel.call_deferred)
 panel.tree_exiting.connect(func():if ui.resized.is_connected(place_panel):ui.resized.disconnect(place_panel),CONNECT_ONE_SHOT)
 place_panel.call_deferred()
 var content=VBoxContainer.new();content.add_theme_constant_override("separation",Tokens.SPACE_NONE);panel.add_child(content)
 var q: Dictionary=pages.c().get("inn",{})
 var words=dialogue if not dialogue.is_empty() else FULL_GREETING if not q.get("needsRecovery",false) else pages.facility_entry.greeting_text()
 pages.facility_entry.render_entry_art(surface,words,true)
 parent=inset(content,0,true)
 var heading=pages.row(parent)
 ui.icons.line(ui,heading,"inn","宿泊・回復",true)
 HelpBadge.attach(heading,"戦闘不能者の救命","ポーター以外の仲間は、倒れた戦闘の終了から12時間まで宿泊で救命できます。「残り0時間」でも、ゲーム内の時間を進めずに泊まれば間に合います。\n期限を過ぎると死亡します。主人公が死亡した場合は、その人物をギルドに残すか選び、次の主人公へ進みます。","HelpInnRescue",24)
 if not q.get("available",false):pages.l(parent,"宿屋はアスタリスで利用できます。");return
 if q.get("needsRecovery",false):
  var price_label=pages.l(heading,"パーティ全員で %d G" % q.price)
  price_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 cards(content)
 parent=inset(content,0,false,true)
 var actions=pages.row(parent);actions.name="InnActions";actions.alignment=BoxContainer.ALIGNMENT_END
 if not q.get("needsRecovery",false):
  var status=pages.l(actions,"宿泊完了" if not healing_party.is_empty() else "全快済み")
  status.name="InnRecoveryStatus";status.add_theme_font_size_override("font_size",Tokens.FONT_SM);status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 elif not q.get("affordable",false):
  var lack=pages.l(actions,"所持金不足（%d G 必要）" % q.price)
  lack.add_theme_font_size_override("font_size",Tokens.FONT_SM);lack.add_theme_color_override("font_color",Tokens.DANGER);lack.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var caption="休息する"
 var disabled=pending or not q.get("needsRecovery",false) or not q.get("affordable",false)
 var stay_btn=ui.action_button(pages.b(actions,caption,stay,disabled),"md");stay_btn.name="InnStay"
 var back_btn=pages.b(actions,"戻る",pages.facility_entry.back,pending,"md");back_btn.name="InnReturn"
func inset(parent: Control,cells: int,bottom_divider:=false,top_divider:=false) -> VBoxContainer:
 var box=VBoxContainer.new()
 box.add_theme_constant_override("separation",Tokens.SPACE_NONE)
 if cells>0:box.custom_minimum_size.y=pages.grid_height(cells+1)-pages.grid_height(1)
 parent.add_child(box)
 if top_divider:
  var top_line=ColorRect.new();top_line.name="InnFooterDivider";top_line.color=Tokens.BORDER;top_line.custom_minimum_size.y=Tokens.BORDER_WIDTH;top_line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top_line.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(top_line)
 var margin=MarginContainer.new()
 margin.size_flags_vertical=Control.SIZE_EXPAND_FILL
 for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,Tokens.SPACE_SM)
 box.add_child(margin)
 var body=VBoxContainer.new()
 margin.add_child(body)
 if bottom_divider:
  var bottom_line=ColorRect.new();bottom_line.name="InnHeaderDivider";bottom_line.color=Tokens.BORDER;bottom_line.custom_minimum_size.y=Tokens.BORDER_WIDTH;bottom_line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bottom_line.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(bottom_line)
 return body
func cards(parent):
 var selected_ids=pages.c().get("selected",[])
 var compact=ui.size.y<720
 var cols=3 if compact else 6
 var card_rows=maxi(1,ceili(float(maxi(1,selected_ids.size()))/float(cols)))
 var has_ko=pages.roster().any(func(u):return selected_ids.has(u.id) and int(u.get("hp",1))<=0)
 var row_height=104.0 if compact else (268.0 if has_ko else 248.0)
 var max_scroll=float(pages.grid_height(7)-pages.grid_height(3))
 var scroll=ScrollContainer.new();scroll.name="InnPartyScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.custom_minimum_size.y=minf(max_scroll,row_height*card_rows)
 var scroll_pad=StyleBoxEmpty.new();scroll_pad.content_margin_left=Tokens.SPACE_SM;scroll_pad.content_margin_right=Tokens.SPACE_SM;scroll_pad.content_margin_top=Tokens.SPACE_SM;scroll_pad.content_margin_bottom=Tokens.SPACE_SM;scroll.add_theme_stylebox_override("panel",scroll_pad)
 parent.add_child(scroll)
 var members=ui.member_grid(scroll,"InnParty",280.0 if compact else 170.0,cols)
 var labels=[]
 for id in pages.c().get("selected",[]):
  var matches=pages.roster().filter(func(u):return u.id==id)
  if matches.is_empty():continue
  var u=matches[0];var member=pages.card(members);member.name="InnMember_"+str(id)
  member.get_parent().custom_minimum_size.x=112;member.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var content=pages.row(member) if compact else member
  var face=ui.portrait(content,u,false,40 if compact else 64);face.name="InnPortrait_"+str(id);face.custom_minimum_size.y=118 if ui.ui_size_mode=="standard" else 40;face.size_flags_horizontal=Control.SIZE_FILL if compact else Control.SIZE_EXPAND_FILL
  if healing_party.has(str(id)) and progress()<1.0:
   var effect=preload("res://inn_heal_effect.gd").new();effect.name="InnHeal_"+str(id);effect.started=recovery_started;effect.duration=RECOVERY_SECONDS;face.add_child(effect)
  var copy=VBoxContainer.new() if compact else member
  if compact:content.add_child(copy);copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var name_label=pages.l(copy,u.name);name_label.name="InnName_"+str(id);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;ui.short_name(name_label,str(u.name));name_label.add_theme_font_size_override("font_size",Tokens.FONT_SM)
  var vitals=pages.row(copy) if compact else copy
  for stat in ["hp","mp"]:
   var maximum=int(u.max if stat=="hp" else u.maxMp);var current=int(u.get(stat,0))
   var label=pages.l(vitals,"");label.name="Inn"+stat.to_upper()+"_"+str(id);label.add_theme_font_size_override("font_size",Tokens.FONT_XS if compact else Tokens.FONT_SM);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   var before=current
   if recovered.has(str(id)) and recovered[str(id)].get("after",{}).get(stat)==current:before=int(recovered[str(id)].before.get(stat,current))
   labels.append({"label":label,"stat":stat,"before":before,"after":current,"maximum":maximum})
   if before<current and progress()<1.0:label.add_theme_color_override("font_color",Tokens.POSITIVE);label.set_meta("recovering",true)
  if u.hp<=0:pages.l(member,"死亡" if u.get("dead",false) else "戦闘不能")
 paint(progress(),labels)
 if progress()<1.0:
  var tween=members.create_tween();tween.tween_method(paint.bind(labels),progress(),1.0,RECOVERY_SECONDS*(1.0-progress()))
func paint(amount: float,labels: Array):
 for entry in labels:
  if not is_instance_valid(entry.label):continue
  var shown=roundi(lerpf(float(entry.before),float(entry.after),amount))
  entry.label.text="%s %d → %d" % [str(entry.stat).to_upper(),shown,entry.maximum]
  if shown<entry.maximum or (entry.before<entry.after and amount<1.0):
   entry.label.add_theme_color_override("font_color",Tokens.POSITIVE)
  else:
   entry.label.remove_theme_color_override("font_color")
  if amount>=1.0:entry.label.set_meta("recovering",false)
func stay():
 if not available() or pending or ui.locked or ui.presenting or ui.modal_open() or ui.closing:return
 var q: Dictionary=pages.c().get("inn",{})
 if not q.get("needsRecovery",false):
  dialogue=FULL_GREETING;recovered={};healing_party=[];recovery_started=0;ui.render();return
 if not q.get("affordable",false):return
 var token=pages.c().get("inventoryToken");var epoch=pages.epoch;var connection=ui.engine.connection_generation;var request=sequence
 ui.confirm("%d Gを支払い、編成中の生存者のHP・MPを全回復しますか？\n戦闘不能も回復。控えは対象外、時間は経過しません。" % q.price,commit.bind(token,epoch,connection,request))
func commit(token,epoch: int,connection: int,request: int):
 if pending or not available() or ui.locked or ui.presenting or ui.closing or request!=sequence or epoch!=pages.epoch or connection!=ui.engine.connection_generation or token!=pages.c().get("inventoryToken"):return
 var q: Dictionary=pages.c().get("inn",{})
 if not q.get("needsRecovery",false) or not q.get("affordable",false):return
 pending=true;sequence+=1;var operation=sequence
 await ui.act("inn",[])
 if operation==sequence:pending=false

# Apply the receipt before the main window draws the new gold and party stats.
func finish_rest(previous: Dictionary,success: bool):
 if not pending:return
 pending=false
 if not success:return
 var before={}
 for u in previous.get("roster",[]):
  if previous.get("selected",[]).has(u.id):before[str(u.id)]={"hp":u.hp,"mp":u.mp}
 recovered={}
 for u in pages.roster():
  if before.has(str(u.id)) and (int(before[str(u.id)].hp)<int(u.hp) or int(before[str(u.id)].mp)<int(u.mp)):
   recovered[str(u.id)]={"before":before[str(u.id)],"after":{"hp":u.hp,"mp":u.mp}}
 healing_party=before.keys();recovery_started=Time.get_ticks_msec();dialogue=RESTED_GREETING
