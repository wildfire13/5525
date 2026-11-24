extends CanvasLayer
## Receipts describe successful canonical replies. Display never grants rewards.
var ui
var active := false
var sequence := 0
var pending: Array=[]
var recent: Array=[]
var current: Dictionary={}
var shade: Control
var panel: Panel
var body: Control
var continue_button: Button
var save_button: Button
var intro: Tween
var _replaying := false
var _compact := false
var _layout_queued := false
const Grid=preload("res://screen_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
const GOLD=Tokens.ACCENT
const MUTED=Tokens.MUTED_INK
func _init(frontend=null):ui=frontend
func _ready():
 layer=1500;name="ResultsView"
 shade=Control.new();shade.theme=ui.theme;shade.name="ResultBackground";shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var bg=ColorRect.new();bg.name="ResultPaper";bg.color=Tokens.SURFACE_BACKDROP;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade.add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.anchor_top=0.1;bg.anchor_bottom=0.9
 panel=Panel.new();panel.theme=ui.theme;panel.name="ResultsPanel";panel.clip_contents=true;panel.add_theme_stylebox_override("panel",style(Tokens.SURFACE,Tokens.BORDER,Tokens.SPACE_XL,Tokens.RADIUS_LG));shade.add_child(panel)
 ui.resized.connect(_layout);shade.hide()
func style(fill: Color,border: Color,padding: int,radius: int=Tokens.RADIUS_LG) -> StyleBoxFlat:
 return Tokens.box(fill,border,radius,padding)
func reset():
 active=false;pending.clear();recent.clear();current.clear();shade.hide()
 if intro and intro.is_running():intro.kill()
func _member(c: Dictionary,id: String) -> Dictionary:
 for member in c.get("roster",[]):
  if str(member.id)==id:return member
 return {}
func delivery_status(result: Dictionary) -> String:
 var outcome=result.get("outcome")
 if outcome not in ["success","late"]:return ""
 var text="配達完了"
 var preferred=result.get("preferredMet")
 if preferred is bool:text+=" / "+("希望条件達成" if preferred else "希望条件未達")
 if outcome=="late":text+="（遅配）"
 return text
func receipt_for(action: String,before: Dictionary,battle: Dictionary,reply: Dictionary) -> Dictionary:
 if not reply.get("ok",false) or not reply.get("campaign") is Dictionary:return {}
 var after: Dictionary=reply.campaign
 var kind=""
 if action=="finishBattle" and before.get("phase")=="battle" and after.get("phase") in ["camp","arrival"]:kind="battle"
 elif action=="completeQuest" and after.get("phase")=="result" and after.get("result",{}).get("outcome") in ["success","late"]:kind="quest"
 if kind.is_empty():return {}
 var rows=[]
 for id in before.get("selected",[]):
  var old=_member(before,str(id));var now=_member(after,str(id))
  if old.is_empty() or now.is_empty():continue
  rows.append({"id":str(id),"name":now.name,"member":now.duplicate(true),"xp_before":old.get("xp",0),"xp_after":now.get("xp",0),"xp_gain":int(now.get("xp",0))-int(old.get("xp",0)),"level_before":old.get("level",1),"level_after":now.get("level",1),"stat_gain":int(now.get("statPoints",0))-int(old.get("statPoints",0)),"skill_gain":int(now.get("skillPoints",0))-int(old.get("skillPoints",0))})
 var result: Dictionary=after.get("result",{}) if after.get("result") is Dictionary else {}
 var fallen=battle.get("units",[]).filter(func(u):return u.get("side")=="enemy" and int(u.get("hp",0))<=0).size()
 return {"kind":kind,"title":"BATTLE VICTORY" if kind=="battle" else "QUEST COMPLETE","subtitle":"戦闘勝利" if kind=="battle" else delivery_status(result),"rp_gain":int(result.get("rp",0)),"gold_gain":int(after.get("gold",0))-int(before.get("gold",0)),"gold_after":after.get("gold",0),"members":rows,"quest":str(result.get("quest","")),"hours":result.get("hours"),"actions":battle.get("actions"),"defeated":fallen,"outcome":str(result.get("outcome","")),"location":str(after.get("location","")),"scenario":str(result.get("scenario","")),"storyId":result.get("storyId",""),"story":result.get("story",[]),"portrait":str(result.get("portrait","")),"cast":result.get("cast",[]),"restored":false,"acknowledge":kind=="quest"}
func enqueue(receipt: Dictionary):
 if receipt.is_empty():return
 pending.append(receipt.duplicate(true));recent=[receipt.duplicate(true)]
func restore_quest(c: Dictionary):
 var result=c.get("result",{})
 if c.get("phase")!="result" or not result is Dictionary or result.get("outcome") not in ["success","late"]:return
 var rows=[]
 for id in c.get("selected",[]):
  var now=_member(c,str(id))
  if now.is_empty():continue
  rows.append({"id":str(id),"name":now.name,"member":now.duplicate(true),"xp_before":null,"xp_after":now.get("xp",0),"xp_gain":int(result.get("xp",0)),"level_before":null,"level_after":now.get("level",1),"stat_gain":null,"skill_gain":null})
 enqueue({"kind":"quest","title":"QUEST COMPLETE","subtitle":delivery_status(result),"rp_gain":int(result.get("rp",0)),"gold_gain":int(result.get("gold",0)),"gold_after":c.get("gold",0),"members":rows,"quest":str(result.get("quest","")),"hours":result.get("hours"),"outcome":str(result.get("outcome","")),"location":str(c.get("location","")),"scenario":str(result.get("scenario","")),"storyId":result.get("storyId",""),"story":result.get("story",[]),"portrait":str(result.get("portrait","")),"cast":result.get("cast",[]),"restored":true,"acknowledge":true})
func present_pending():
 if active or pending.is_empty() or ui.closing or ui.loading_screen.active:return
 _replaying=false;_open(pending.pop_front())
func reopen():
 if active or recent.is_empty() or ui.locked or ui.presenting or ui.loading_screen.active or ui.campaign().get("phase") in ["battle","deployment"] or ui.data.get("trial")!=null:return
 _replaying=true;_open(recent[-1].duplicate(true))
func _open(receipt: Dictionary):
 sequence+=1;current=receipt;active=true;shade.theme=ui.theme;panel.theme=ui.theme
 ui.menu.hide()
 if is_instance_valid(ui.dialog.window):ui.dialog.close()
 for window in ui.find_children("*","Window",true,false):window.hide()
 get_parent().move_child(self,-1)
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 body=Control.new();panel.add_child(body)
 _build();shade.show();_layout();continue_button.grab_focus()
 if intro and intro.is_running():intro.kill()
 body.modulate.a=0.0;intro=create_tween();intro.tween_property(body,"modulate:a",1.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func _label(parent: Node,text: String,size_: int,color:=Tokens.INK) -> Label:
 var l=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",size_);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func _build():
 var compact=ui.size.x<1120 or ui.size.y<720
 _compact=compact
 body.add_theme_constant_override("separation",Tokens.SPACE_NONE)
 var heading=HBoxContainer.new();heading.name="ResultHeading";heading.add_theme_constant_override("separation",Tokens.SPACE_XL);body.add_child(heading)
 var crest=TextureRect.new();crest.name="ResultCrest";crest.custom_minimum_size=Vector2(80,80) if compact else Vector2(100,100);crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;crest.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var path="res://assets/results/"+("battle-crest.png" if current.kind=="battle" else "quest-crest.png")
 if ResourceLoader.exists(path):crest.texture=load(path)
 heading.add_child(crest)
 var titles=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;titles.add_theme_constant_override("separation",Tokens.SPACE_XS);heading.add_child(titles)
 var stage_label=_label(titles,current.title,Tokens.FONT_SM,GOLD);stage_label.name="ResultStage"
 var title_label=_label(titles,current.subtitle,Tokens.FONT_HEADING);title_label.name="ResultTitle"
 for label in [stage_label,title_label]:
  label.max_lines_visible=1;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.tooltip_text=label.text
 for line in [stage_label,title_label]:
  line.autowrap_mode=TextServer.AUTOWRAP_OFF;line.clip_text=true
 var summary=Control.new();summary.name="ResultSummary";body.add_child(summary)
 if int(current.gold_gain)>0:_summary(summary,"獲得した所持金","+%d G" % int(current.gold_gain),"ResultGold")
 var gains=current.members.map(func(m):return int(m.xp_gain));var xptext="成長対象なし"
 if not gains.is_empty():
  var lo=gains.min();var hi=gains.max();xptext="+%d EXP / 人" % lo if lo==hi else "+%d〜%d EXP" % [lo,hi]
 if gains.any(func(value):return value>0):_summary(summary,"獲得EXP",xptext,"ResultExperience")
 if int(current.get("rp_gain",0))>0:_summary(summary,"獲得RP","+%d RP" % int(current.rp_gain),"ResultRankPoints")
 var scroll=ScrollContainer.new();scroll.name="ResultMembersScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;scroll.focus_mode=Control.FOCUS_ALL;body.add_child(scroll)
 var members_margin=MarginContainer.new();members_margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL;members_margin.add_theme_constant_override("margin_top",Tokens.SPACE_SM);members_margin.add_theme_constant_override("margin_bottom",Tokens.SPACE_SM);scroll.add_child(members_margin)
 var members=VBoxContainer.new();members.name="ResultMembers";members.size_flags_horizontal=Control.SIZE_EXPAND_FILL;members.add_theme_constant_override("separation",Tokens.SPACE_SM);members_margin.add_child(members)
 var quest_title=str(current.get("quest","")) if current.kind=="quest" else ""
 if not quest_title.is_empty():_label(members,quest_title,Tokens.FONT_SM,MUTED).name="ResultContext"
 ui.pages.quest_board.render_sluice_story(members,current)
 if current.kind=="quest" and current.get("hours")!=null:_label(members,"所要時間 %d時間" % int(current.hours),Tokens.FONT_SM,MUTED).name="ResultFacts"
 var details=VBoxContainer.new();details.name="ResultMemberDetails";details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",Tokens.SPACE_SM);members.add_child(details)
 for row in current.members:_member_card(details,row,compact)
 if current.restored:_label(members,"保存済みの結果です。成長前の値は記録されていません。",Tokens.FONT_XS,MUTED)
 var md_preset := "md" if compact else "md_lg"
 var actions=HBoxContainer.new();actions.name="ResultActions";actions.add_theme_constant_override("separation",Tokens.SPACE_LG);body.add_child(actions)
 save_button=Button.new();save_button.name="ResultSave";save_button.text="セーブ";Tokens.apply_button_preset(save_button,md_preset);save_button.pressed.connect(func():if active and not ui.locked:ui.save_game());actions.add_child(save_button)
 if current.kind=="quest" and not _replaying and str(current.location) in ["east","west","south","north"]:
  var shortcut=Button.new();shortcut.name="ResultShop";shortcut.text=ui.town_name(current.location)+"の"+{"east":"武器店","west":"防具店","south":"道具店","north":"装飾品店"}[str(current.location)]+"へ";Tokens.apply_button_preset(shortcut,md_preset);actions.add_child(shortcut)
  var shortcut_owner=sequence;shortcut.pressed.connect(func():if active and sequence==shortcut_owner:advance_to("shop"))
 var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(spacer)
 continue_button=Button.new();continue_button.name="ResultContinue";continue_button.text="OK";ui.action_button(continue_button,md_preset);actions.add_child(continue_button)
 if current.get("storyId")!="sluice-bell" and current.get("story",[]) is Array and not current.get("story",[]).is_empty():
  var scene=Button.new();scene.name="ResultStory";scene.text="会話を見る";Tokens.apply_button_preset(scene,md_preset);actions.add_child(scene);scene.pressed.connect(func():if active:ui.pages.quest_board.play_scene(current.story,str(current.get("portrait","")),current.get("cast",[]),str(current.get("scenario",""))))
 var owner=sequence;continue_button.pressed.connect(func():if active and sequence==owner:advance())
func _summary(parent: Node,title: String,value: String,node_name: String):
 var card=PanelContainer.new();card.name=node_name;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.size_flags_vertical=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",style(Tokens.SURFACE_ALT,Tokens.BORDER,Tokens.SPACE_SM if _compact else Tokens.SPACE_MD,Tokens.RADIUS_LG));parent.add_child(card)
 var box=VBoxContainer.new();box.alignment=BoxContainer.ALIGNMENT_CENTER;box.add_theme_constant_override("separation",Tokens.SPACE_XS);card.add_child(box)
 for entry in [[title,Tokens.FONT_XS if _compact else Tokens.FONT_SM,MUTED],[value,Tokens.FONT_HEADING,GOLD]]:
  var caption=_label(box,entry[0],entry[1],entry[2])
  caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.clip_text=true;caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
func _member_card(parent: Node,row: Dictionary,compact: bool):
 var card=PanelContainer.new();card.name="ResultMember_"+str(row.id);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",style(Tokens.SURFACE,Tokens.BORDER,Tokens.SPACE_SM,Tokens.RADIUS_SM));parent.add_child(card)
 var line=HBoxContainer.new();line.add_theme_constant_override("separation",Tokens.SPACE_MD);card.add_child(line)
 var portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(56,56) if compact else Vector2(64,64);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture=ui.portraits.texture(row.member,true);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(portrait)
 var info=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.size_flags_vertical=Control.SIZE_SHRINK_CENTER;info.add_theme_constant_override("separation",Tokens.SPACE_XS);line.add_child(info)
 var leveled_up: bool=row.level_before!=null and row.level_after>row.level_before
 var level="Lv.%d" % int(row.level_after)
 if row.level_before!=null and row.level_before!=row.level_after:level="Lv.%d → Lv.%d" % [int(row.level_before),int(row.level_after)]
 var headline=HBoxContainer.new();headline.add_theme_constant_override("separation",Tokens.SPACE_MD);info.add_child(headline)
 var name_level=_label(headline,str(row.name)+"　"+level,Tokens.FONT_BODY,GOLD if leveled_up else Tokens.INK)
 name_level.autowrap_mode=TextServer.AUTOWRAP_OFF
 var points=[]
 if row.stat_gain!=null and row.stat_gain>0:points.append("能力 +%d" % int(row.stat_gain))
 if row.skill_gain!=null and row.skill_gain>0:points.append("スキル +%d" % int(row.skill_gain))
 if not points.is_empty():
  var bonus=_label(headline," / ".join(points),Tokens.FONT_SM,GOLD)
  bonus.name="ResultLevelUpPoints_"+str(row.id)
  bonus.autowrap_mode=TextServer.AUTOWRAP_OFF
  bonus.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var experience="累計EXP %d" % int(row.xp_after) if row.xp_before==null else "累計EXP %d → %d" % [int(row.xp_before),int(row.xp_after)]
 _label(info,experience,Tokens.FONT_SM,MUTED)
 var gain=_label(line,"+%d EXP" % int(row.xp_gain),Tokens.FONT_HEADING,Tokens.POSITIVE);gain.name="ResultGain_"+str(row.id);gain.autowrap_mode=TextServer.AUTOWRAP_OFF;gain.custom_minimum_size.x=128 if compact else 150;gain.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;gain.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
func _queue_layout():
 if _layout_queued:return
 _layout_queued=true;call_deferred("_deferred_layout")
func _deferred_layout():
 _layout_queued=false
 if active and is_inside_tree():_layout()
func _layout():
 if not is_instance_valid(panel):return
 var compact=ui.size.x<1120 or ui.size.y<720
 if active and compact!=_compact:
  if intro and intro.is_running():intro.kill()
  for child in panel.get_children():panel.remove_child(child);child.queue_free()
  body=Control.new();panel.add_child(body);_build();continue_button.grab_focus()
 if not is_instance_valid(body):return
 var view=ui.size
 Grid.place(panel,preload("res://window_grid.gd").frame_rect(view))
 body.position=Vector2.ZERO;body.size=panel.size
 # Keep the receipt body between the heading and the always-visible actions.
 var row_height=Grid.cell_rect(view,0,1,1,1).size.y
 var crest=body.find_child("ResultCrest",true,false)
 crest.custom_minimum_size.y=minf(80 if compact else 100,row_height)
 for entry in [["ResultHeading",1,1,8,1],["ResultSummary",1,2,8,1],["ResultMembersScroll",1,3,8,5],["ResultActions",1,8,8,1]]:
  var region=panel.find_child(entry[0],true,false)
  if region==null:continue
  region.clip_contents=true
  Grid.place(region,Grid.cell_rect(view,entry[1],entry[2],entry[3],entry[4]))
 var summary=panel.find_child("ResultSummary",true,false)
 if summary!=null:
  var cards=summary.get_children()
  var spans={1:[8],2:[4,4],3:[3,3,2]}.get(cards.size(),[])
  var col=1
  for i in range(mini(cards.size(),spans.size())):
   Grid.place(cards[i],Grid.cell_rect(view,col,2,spans[i],1))
   col+=spans[i]
func advance():advance_to("hub")
func advance_to(destination: String):
 if not active or ui.locked:return
 var action=current.get("acknowledge",false) and not _replaying
 active=false;shade.hide();current={}
 if intro and intro.is_running():intro.kill()
 if not pending.is_empty():_open(pending.pop_front());return
 if action:
  ui.page=destination;await ui.act("acknowledge",[])
 else:
  ui.render()
func _input(event):
 if not active:return
 if event is InputEventKey:
  if event.echo:get_viewport().set_input_as_handled();return
  if event.pressed and event.keycode==KEY_ESCAPE:advance();get_viewport().set_input_as_handled();return
  if event.pressed and event.keycode==KEY_TAB:
   var controls=[]
   for control in [shade.find_child("ResultMembersScroll",true,false),save_button,shade.find_child("ResultShop",true,false),shade.find_child("ResultStory",true,false),continue_button]:
    if is_instance_valid(control) and control.is_visible_in_tree():controls.append(control)
   var index=controls.find(get_viewport().gui_get_focus_owner());controls[posmod(index+(-1 if event.shift_pressed else 1),controls.size())].grab_focus();get_viewport().set_input_as_handled();return
  var scroll=shade.find_child("ResultMembersScroll",true,false)
  if event.pressed and is_instance_valid(scroll):
   if event.keycode in [KEY_PAGEDOWN,KEY_PAGEUP,KEY_HOME,KEY_END]:
    var bar=scroll.get_v_scroll_bar();scroll.scroll_vertical=int(bar.max_value) if event.keycode==KEY_END else 0 if event.keycode==KEY_HOME else scroll.scroll_vertical+int(bar.page)*(1 if event.keycode==KEY_PAGEDOWN else -1)
    get_viewport().set_input_as_handled();return
   if get_viewport().gui_get_focus_owner()==scroll and event.keycode in [KEY_UP,KEY_DOWN]:
    scroll.scroll_vertical+=64 if event.keycode==KEY_DOWN else -64;get_viewport().set_input_as_handled();return
  if event.keycode not in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:get_viewport().set_input_as_handled()
