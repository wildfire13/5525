extends RefCounted
## Inn presentation never writes character stats: the canonical inn action commits
## the entire party and payment before the transient count-up begins.
const RECOVERY_SECONDS := 1.2
const FULL_GREETING := "みなさん、お元気ですね。今は休まなくても大丈夫ですよ。"
const RESTED_GREETING := "おはようございます。みなさん、ゆっくり休めましたね。"
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
 var shown=pages.facility_entry.render_dialogue(dialogue)
 var q: Dictionary=pages.c().get("inn",{})
 var heading_parent=parent
 var compact_header=not shown and ui.size.y<720
 var header=pages.row(parent) if compact_header else parent
 if compact_header:
  heading_parent=VBoxContainer.new();heading_parent.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(heading_parent)
 ui.icons.line(ui,heading_parent,"inn","宿屋",true)
 if not q.get("available",false):pages.l(heading_parent,"宿屋はアスタリスで利用できます。");return
 if q.get("needsRecovery",false):pages.l(heading_parent,"パーティ全員で%dG" % q.price)
 var recovery_hint=pages.muted(heading_parent,"編成中の全員のHP・MPを全回復。控えは対象外、時間は経過しません。");recovery_hint.add_theme_font_size_override("font_size",16)
 if not shown:
  var speech=pages.facility_entry.make_speech(dialogue if not dialogue.is_empty() else pages.facility_entry.greeting_text(),"normal")
  pages.facility_entry.fit_inline_speech(speech)
  if compact_header:speech.custom_minimum_size.y=140
  header.add_child(speech)

 cards(parent)
 if not q.get("needsRecovery",false):
  var status=pages.l(parent,"宿泊完了。全員のHP・MPが回復しました。" if not healing_party.is_empty() else "全員が全回復しています。料金はかかりません。")
  status.name="InnRecoveryStatus";status.add_theme_font_size_override("font_size",16)
 elif not q.get("affordable",false):pages.l(parent,"所持金が足りません。宿泊には%dG必要です。" % q.price)
 var actions=pages.row(parent);actions.alignment=BoxContainer.ALIGNMENT_CENTER
 var caption="ひと休みする" if not q.get("needsRecovery",false) else "%dGで宿泊する / 確認" % q.price
 var disabled=pending or (q.get("needsRecovery",false) and not q.get("affordable",false))
 ui.green_button(pages.b(actions,caption,stay,disabled)).name="InnStay"
func cards(parent):
 var scroll=ScrollContainer.new();scroll.name="InnPartyScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.custom_minimum_size.y=96;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(scroll)
 var compact=ui.size.y<720
 if not compact:
  scroll.size_flags_vertical=Control.SIZE_FILL
  scroll.custom_minimum_size.y=mini(560.0,ui.size.y*0.52)
 var members=ui.member_grid(scroll,"InnParty",280.0 if compact else 170.0,3 if compact else 6)
 if not compact:
  var fit_cards=func():scroll.custom_minimum_size.y=minf(560.0,members.get_combined_minimum_size().y)
  members.minimum_size_changed.connect(fit_cards);fit_cards.call_deferred()
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
  var name_label=pages.l(copy,u.name);name_label.name="InnName_"+str(id);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;ui.short_name(name_label,str(u.name));name_label.add_theme_font_size_override("font_size",16)
  var vitals=pages.row(copy) if compact else copy
  for stat in ["hp","mp"]:
   var maximum=int(u.max if stat=="hp" else u.maxMp);var current=int(u.get(stat,0))
   var label=pages.l(vitals,"");label.name="Inn"+stat.to_upper()+"_"+str(id);label.add_theme_font_size_override("font_size",14 if compact else 16);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   var before=current
   if recovered.has(str(id)) and recovered[str(id)].get("after",{}).get(stat)==current:before=int(recovered[str(id)].before.get(stat,current))
   labels.append({"label":label,"stat":stat,"before":before,"after":current,"maximum":maximum})
   if before<current and progress()<1.0:label.add_theme_color_override("font_color",Color("#97edb5"));label.set_meta("recovering",true)
  if u.hp<=0:pages.l(member,"戦闘不能")
 paint(progress(),labels)
 if progress()<1.0:
  var tween=members.create_tween();tween.tween_method(paint.bind(labels),progress(),1.0,RECOVERY_SECONDS*(1.0-progress()))
func paint(amount: float,labels: Array):
 for entry in labels:
  if not is_instance_valid(entry.label):continue
  var shown=roundi(lerpf(float(entry.before),float(entry.after),amount))
  entry.label.text="%s %d/%d" % [str(entry.stat).to_upper(),shown,entry.maximum]
  if amount>=1.0:entry.label.remove_theme_color_override("font_color");entry.label.set_meta("recovering",false)
func stay():
 if not available() or pending or ui.locked or ui.presenting or ui.modal_open() or ui.closing:return
 var q: Dictionary=pages.c().get("inn",{})
 if not q.get("needsRecovery",false):
  dialogue=FULL_GREETING;recovered={};healing_party=[];recovery_started=0;ui.render();return
 if not q.get("affordable",false):return
 var token=pages.c().get("inventoryToken");var epoch=pages.epoch;var connection=ui.engine.connection_generation;var request=sequence
 ui.confirm("%dGを支払い、編成中の全員のHP・MPを全回復しますか？\n戦闘不能も回復。控えは対象外、時間は経過しません。" % q.price,commit.bind(token,epoch,connection,request))
func commit(token,epoch: int,connection: int,request: int):
 if pending or not available() or ui.locked or ui.presenting or ui.closing or request!=sequence or epoch!=pages.epoch or connection!=ui.engine.connection_generation or token!=pages.c().get("inventoryToken"):return
 var q: Dictionary=pages.c().get("inn",{})
 if not q.get("needsRecovery",false) or not q.get("affordable",false):return
 pending=true;sequence+=1;var operation=sequence
 var before={}
 for u in pages.roster():
  if pages.c().get("selected",[]).has(u.id):before[str(u.id)]={"hp":u.hp,"mp":u.mp}
 var reply=await ui.act("inn",[])
 if operation!=sequence or epoch!=pages.epoch or connection!=ui.engine.connection_generation:return
 pending=false
 if not reply is Dictionary or not reply.get("ok",false):return
 recovered={}
 for u in pages.roster():
  if before.has(str(u.id)) and (int(before[str(u.id)].hp)<int(u.hp) or int(before[str(u.id)].mp)<int(u.mp)):
   recovered[str(u.id)]={"before":before[str(u.id)],"after":{"hp":u.hp,"mp":u.mp}}
 healing_party=before.keys();recovery_started=Time.get_ticks_msec();dialogue=RESTED_GREETING
 if available() and not ui.closing:ui.render()
