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
var body: VBoxContainer
var continue_button: Button
var save_button: Button
var intro: Tween
var _replaying := false
var _compact := false
var _layout_queued := false
const GOLD=Color("#e5ca8e")
const MUTED=Color("#b5c2cf")
func _init(frontend=null):ui=frontend
func _ready():
 layer=1500;name="ResultsView"
 shade=Control.new();shade.name="ResultsBlocker";shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var bg=ColorRect.new();bg.color=Color("#101924");bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade.add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=Panel.new();panel.name="ResultsPanel";panel.clip_contents=true;panel.add_theme_stylebox_override("panel",style(Color("#172330"),Color("#b79b64"),24));shade.add_child(panel)
 ui.resized.connect(_layout);shade.hide()
func style(fill: Color,border: Color,padding: int) -> StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(10);s.set_content_margin_all(padding);return s
func reset():
 active=false;pending.clear();recent.clear();current.clear();shade.hide()
 if intro and intro.is_running():intro.kill()
func _member(c: Dictionary,id: String) -> Dictionary:
 for member in c.get("roster",[]):
  if str(member.id)==id:return member
 return {}
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
 return {"kind":kind,"title":"BATTLE VICTORY" if kind=="battle" else "QUEST COMPLETE","subtitle":"戦闘勝利" if kind=="battle" else "配達達成 / 遅配" if result.get("outcome")=="late" else "配達達成","gold_gain":int(after.get("gold",0))-int(before.get("gold",0)),"gold_after":after.get("gold",0),"members":rows,"quest":str(result.get("quest","")),"hours":result.get("hours"),"actions":battle.get("actions"),"defeated":fallen,"outcome":str(result.get("outcome","")),"location":str(after.get("location","")),"restored":false,"acknowledge":kind=="quest"}
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
 enqueue({"kind":"quest","title":"QUEST COMPLETE","subtitle":"配達達成 / 遅配" if result.get("outcome")=="late" else "配達達成","gold_gain":int(result.get("gold",0)),"gold_after":c.get("gold",0),"members":rows,"quest":str(result.get("quest","")),"hours":result.get("hours"),"outcome":str(result.get("outcome","")),"location":str(c.get("location","")),"restored":true,"acknowledge":true})
func present_pending():
 if active or pending.is_empty() or ui.closing or ui.loading_screen.active:return
 _replaying=false;_open(pending.pop_front())
func reopen():
 if active or recent.is_empty() or ui.locked or ui.presenting or ui.loading_screen.active or ui.campaign().get("phase") in ["battle","deployment"] or ui.data.get("trial")!=null:return
 _replaying=true;_open(recent[-1].duplicate(true))
func _open(receipt: Dictionary):
 sequence+=1;current=receipt;active=true
 ui.menu.hide()
 if is_instance_valid(ui.dialog.window):ui.dialog.close()
 for window in ui.find_children("*","Window",true,false):window.hide()
 get_parent().move_child(self,-1)
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 body=VBoxContainer.new();body.add_theme_constant_override("separation",18);panel.add_child(body);body.minimum_size_changed.connect(_queue_layout)
 _build();shade.show();_layout();continue_button.grab_focus()
 if intro and intro.is_running():intro.kill()
 body.modulate.a=0.0;intro=create_tween();intro.tween_property(body,"modulate:a",1.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func _label(parent: Node,text: String,size_: int,color:=Color("#f0ede5")) -> Label:
 var l=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",size_);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func _build():
 var compact=ui.size.x<1120 or ui.size.y<720
 _compact=compact
 body.add_theme_constant_override("separation",8 if compact else 18)
 var heading=HBoxContainer.new();heading.name="ResultHeading";heading.add_theme_constant_override("separation",24);body.add_child(heading)
 var crest=TextureRect.new();crest.name="ResultCrest";crest.custom_minimum_size=Vector2(80,80) if compact else Vector2(172,172);crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;crest.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var path="res://assets/results/"+("battle-crest.png" if current.kind=="battle" else "quest-crest.png")
 if ResourceLoader.exists(path):crest.texture=load(path)
 heading.add_child(crest)
 var titles=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;titles.add_theme_constant_override("separation",6);heading.add_child(titles)
 _label(titles,current.title,20 if compact else 25,GOLD).name="ResultStage"
 _label(titles,current.subtitle,28 if compact else 44).name="ResultTitle"
 var context=str(current.get("quest","")) if current.kind=="quest" else "敵部隊を退けました。同行者の戦果と成長を確認できます。"
 if context.is_empty():context="配達の報酬は所持金と同行者に反映済みです。"
 var context_label=_label(titles,context,16 if compact else 21,MUTED);context_label.name="ResultContext";context_label.max_lines_visible=2;context_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;context_label.tooltip_text=context
 var summary=GridContainer.new();summary.name="ResultSummary";summary.columns=2;summary.add_theme_constant_override("h_separation",16);summary.add_theme_constant_override("v_separation",12);body.add_child(summary)
 _summary(summary,"獲得した所持金","獲得なし" if int(current.gold_gain)==0 else "+%d G" % int(current.gold_gain),"確定時の所持金 %d G" % int(current.gold_after),"ResultGold")
 var gains=current.members.map(func(m):return int(m.xp_gain));var xptext="成長対象なし"
 if not gains.is_empty():
  var lo=gains.min();var hi=gains.max();xptext="+%d EXP / 人" % lo if lo==hi else "+%d〜%d EXP" % [lo,hi]
 var detail="配達経験値" if current.kind=="quest" else "戦闘経験値"
 _summary(summary,detail,xptext,"確定済み / %d人" % current.members.size(),"ResultExperience")
 var meta=""
 if current.kind=="battle":meta="敵戦闘不能 %d人" % current.get("defeated",0)+("　戦闘行動 %d" % int(current.actions) if current.get("actions")!=null else "")
 elif current.get("hours")!=null:meta="所要時間 %d時間" % int(current.hours)
 var scroll=ScrollContainer.new();scroll.name="ResultMembersScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size.y=100;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;scroll.focus_mode=Control.FOCUS_ALL;body.add_child(scroll)
 var members=VBoxContainer.new();members.name="ResultMembers";members.size_flags_horizontal=Control.SIZE_EXPAND_FILL;members.add_theme_constant_override("separation",10);scroll.add_child(members)
 if not meta.is_empty():_label(members,meta,18,MUTED).name="ResultFacts"
 if str(current.get("quest","")).length()>40:_label(members,str(current.quest),18,MUTED)
 _label(members,"同行者の成長",20 if compact else 22,GOLD)
 for row in current.members:_member_card(members,row,compact)
 if current.members.is_empty():_label(members,"今回、成長が確定した同行者はいません。",20,MUTED)
 var hint="報酬はすでに反映されています。この画面を開き直しても再取得しません。"
 if current.restored:hint="保存済みの配達結果です。成長前の値は記録されていないため表示しません。"
 _label(body,hint,16,MUTED).name="ResultReceiptHint"
 var actions=HBoxContainer.new();actions.name="ResultActions";actions.add_theme_constant_override("separation",16);body.add_child(actions)
 save_button=Button.new();save_button.name="ResultSave";save_button.text="セーブ";save_button.custom_minimum_size=Vector2(140,46);save_button.pressed.connect(func():if active and not ui.locked:ui.save_game());actions.add_child(save_button)
 if current.kind=="quest" and not _replaying and str(current.location) in ["east","west","south","north"]:
  var shortcut=Button.new();shortcut.name="ResultShop";shortcut.text=ui.town_name(current.location)+"の"+{"east":"武器店","west":"防具店","south":"道具店","north":"装飾品店"}[str(current.location)]+"へ";shortcut.custom_minimum_size=Vector2(180,46);actions.add_child(shortcut)
  var shortcut_owner=sequence;shortcut.pressed.connect(func():if active and sequence==shortcut_owner:advance_to("shop"))
 var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(spacer)
 continue_button=Button.new();continue_button.name="ResultContinue";continue_button.text="次の結果へ" if not pending.is_empty() else "閉じる" if _replaying else "広場へ" if current.get("acknowledge",false) else "旅程へ戻る";continue_button.custom_minimum_size=Vector2(220,46);ui.primary(continue_button);actions.add_child(continue_button)
 var owner=sequence;continue_button.pressed.connect(func():if active and sequence==owner:advance())
func _summary(parent: Node,title: String,value: String,detail: String,node_name: String):
 var card=PanelContainer.new();card.name=node_name;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",style(Color("#223243"),Color("#47586b"),10 if _compact else 16));parent.add_child(card)
 var box=VBoxContainer.new();box.add_theme_constant_override("separation",5);card.add_child(box);_label(box,title,15 if _compact else 17,MUTED);_label(box,value,24 if _compact else 30,GOLD);_label(box,detail,14 if _compact else 16,MUTED)
func _member_card(parent: Node,row: Dictionary,compact: bool):
 var card=PanelContainer.new();card.name="ResultMember_"+str(row.id);card.add_theme_stylebox_override("panel",style(Color("#1c2b39"),Color("#364857"),12));parent.add_child(card)
 var line=HBoxContainer.new();line.add_theme_constant_override("separation",14);card.add_child(line)
 var portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(62,62) if compact else Vector2(76,76);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture=ui.portraits.texture(row.member,true);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(portrait)
 var info=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.add_theme_constant_override("separation",3);line.add_child(info)
 var level="Lv%d" % int(row.level_after)
 if row.level_before!=null and row.level_before!=row.level_after:level="Lv%d → Lv%d" % [int(row.level_before),int(row.level_after)]
 _label(info,str(row.name)+"　"+level,20,GOLD if row.level_before!=null and row.level_after>row.level_before else Color("#f0ede5"))
 var experience="累計EXP %d" % int(row.xp_after) if row.xp_before==null else "累計EXP %d → %d" % [int(row.xp_before),int(row.xp_after)]
 _label(info,experience,16,MUTED)
 var points=[]
 if row.stat_gain!=null and row.stat_gain>0:points.append("能力ポイント +%d" % int(row.stat_gain))
 if row.skill_gain!=null and row.skill_gain>0:points.append("スキルポイント +%d" % int(row.skill_gain))
 if not points.is_empty():_label(info," / ".join(points),16,GOLD)
 var gain=_label(line,"+%d EXP" % int(row.xp_gain),23,Color("#b7e1d2"));gain.name="ResultGain_"+str(row.id);gain.autowrap_mode=TextServer.AUTOWRAP_OFF;gain.custom_minimum_size.x=128 if compact else 150;gain.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
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
  body=VBoxContainer.new();panel.add_child(body);body.minimum_size_changed.connect(_queue_layout);_build();continue_button.grab_focus()
 var available=ui.size;var margin=16.0 if available.x>=1120 and available.y>=720 else 8.0
 var width=minf(1160,available.x-margin*2);var height=minf(870,available.y-margin*2)
 panel.position=Vector2((available.x-width)*.5,(available.y-height)*.5);panel.size=Vector2(width,height)
 var padding=24 if available.y>=720 else 12
 if is_instance_valid(body):body.position=Vector2(padding,padding);body.size=Vector2(width-padding*2,height-padding*2)
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
   for control in [shade.find_child("ResultMembersScroll",true,false),save_button,shade.find_child("ResultShop",true,false),continue_button]:
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
