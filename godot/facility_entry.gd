extends RefCounted
## Session-only facility navigation; services keep their canonical campaign APIs.
var owner_ref: WeakRef
var pages:
 get:return owner_ref.get_ref()
var ui
var view := "top"
var visit := ""
var speech_key := ""
var speech_started := 0
const SpeechBubble=preload("res://speech_bubble.gd")
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func supported(page: String) -> bool:
 if pages.c().get("phase")!="town":return false
 if page=="shop":return pages.c().get("location") in ["east","west","south","north"]
 return page in ["inn","party"] and pages.c().get("location")=="astaris" and (page!="party" or pages.c().get("guildAvailable",false))
func reset():view="top";visit="";speech_key="";speech_started=0
func navigate(page: String):
 if page!=ui.page:
  view="top";visit="";speech_key="";pages.shop_view.sale.reset()
func resume_buy():
 view="buy";visit=str(pages.c().get("location",""))+":shop";pages.shop_view.sale.reset()
func sync():
 var key=str(pages.c().get("location",""))+":"+ui.page
 if key!=visit:visit=key;view="top"
func at_top(page: String="") -> bool:
 if page.is_empty():page=ui.page
 return supported(page) and view=="top"
func return_label() -> String:return "戻る" if supported(ui.page) and view!="top" else "広場に移動"
func back():
 if pages.shop_view.busy():return
 if supported(ui.page) and view!="top":
  pages.shop_view.cancel_pending();pages.shop_view.sale.reset();view="top";ui.render()
 else:ui.navigate("hub")
func choose(value: String):
 if value not in ["buy","sell","inn","guild","warehouse"] or value=="sell" and not pages.c().get("saleAvailable",false):return
 if ui.locked or ui.presenting or ui.modal_open() or pages.shop_view.busy():return
 if ui.page=="shop" and value in ["buy","sell"] and pages.c().get("selected",[]).has(pages.party_uid):ui.shop_uid=pages.party_uid
 view=value;pages.shop_view.sale.reset();ui.memory.focus_key="";ui.render()
func render_top(parent: Control,page: String) -> bool:
 sync()
 if not at_top(page):return false
 var title={"shop":{"east":"武器屋","west":"防具屋","south":"道具屋","north":"装飾品店"}.get(str(pages.c().get("location")),"商店"),"inn":"宿屋","party":"ギルド"}.get(page,"")
 var layout=HBoxContainer.new();layout.name="FacilityEntry";layout.custom_minimum_size.y=ui.mock_shell.content_height();layout.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;layout.add_theme_constant_override("separation",32);parent.add_child(layout)
 var options=VBoxContainer.new();options.name="FacilityChoices";options.custom_minimum_size.x=300;options.add_theme_constant_override("separation",16);layout.add_child(options)
 var town_label=ui.label_(options,ui.town_name(pages.c().get("location","")));town_label.add_theme_font_size_override("font_size",20);town_label.add_theme_color_override("font_color",Color("#faf9f5"));town_label.add_theme_color_override("font_outline_color",Color("#283128"));town_label.add_theme_constant_override("outline_size",6)
 var title_label=ui.label_(options,title,true);title_label.name="FacilityEntryTitle";title_label.add_theme_font_size_override("font_size",30);title_label.add_theme_color_override("font_color",Color("#faf9f5"));title_label.add_theme_color_override("font_outline_color",Color("#283128"));title_label.add_theme_constant_override("outline_size",6)
 var gap=Control.new();gap.custom_minimum_size.y=24;options.add_child(gap)
 var choices=[]
 if page=="shop":
  choices=[["取引する","buy",true]]
  if pages.c().get("location")!="south":choices.append(["強化する","upgrade",false])
  choices.append(["納品する","delivery",false])
 elif page=="inn":choices=[["休息する","inn",true]]
 else:choices=[["パーティメンバー編成","guild",true],["倉庫を利用する","warehouse",true]]
 for choice in choices:
  var button=ui.button(options,choice[0],choose.bind(choice[1]),not choice[2]);button.name="FacilityChoice_"+str(choice[1]);button.custom_minimum_size=Vector2(300,64);
  if choice[2]:ui.green_button(button)
  button.custom_minimum_size.y=64
  ui.memory.key(button,"facility_"+str(choice[1]))
  if not choice[2]:button.tooltip_text="この機能はまだ利用できません。"
 var exit_button=ui.button(options,"店を出る",ui.navigate.bind("hub"));exit_button.name="FacilityExit";exit_button.custom_minimum_size=Vector2(300,64)
 render_entry_art(layout)
 return true
func render_entry_art(layout: Control):
 # All facility entrances share A's right-side framing and B's left choices.
 var stage=Control.new();stage.name="FacilityNpcStage";stage.mouse_filter=Control.MOUSE_FILTER_IGNORE;layout.add_child(stage)
 # Entry art leaves with the view; cached backgrounds remain independent.
 var art=Control.new();art.name="FacilityEntryArt";art.top_level=true;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(art);art.position=Vector2.ZERO;art.size=ui.size
 pages.facility_art.npc.portrait_layer(art)
 var speech=make_speech(greeting_text(),"normal");speech.name="FacilityEntrySpeech";art.add_child(speech)
 var speech_width=minf(640,ui.size.x-680)
 var line_count=ceili(float(speech.words.text.length())/maxf(1,floorf(speech_width*.8/22)))
 speech.size=Vector2(speech_width,maxf(190,float(line_count)*32/.52))
 speech.position=(ui.size-speech.size)*.5
 speech.words.add_theme_font_size_override("font_size",22);speech.set_speaker_visible(false)
func greeting_text() -> String:
 return "いらっしゃい。今日はどうしますか？" if ui.page=="shop" and view=="top" else ("売る品物の持ち主を、下の人物から選んでください。" if pages.shop_view.selected_owner().is_empty() else "売却する品物を選んでください。") if ui.page=="shop" and view=="sell" else "商品をご覧ください。" if ui.page=="shop" else "お泊まりですか？" if ui.page=="inn" else "仲間の編成はこちらでどうぞ。"
func make_speech(text: String,kind: String) -> Control:
 var key=visit+":"+view+":"+kind+":"+text
 if key!=speech_key:speech_key=key;speech_started=Time.get_ticks_usec()
 var bubble=SpeechBubble.new();bubble.configure(text,kind,speech_started)
 return bubble
func fit_inline_speech(bubble: Control):
 # Keep compact greetings proportional to their artwork, instead of filling
 # the entire content width and pushing useful service controls below them.
 bubble.custom_minimum_size=Vector2(minf(420,ui.size.x-64),110 if bubble.words.text.length()<=20 else 140)
 bubble.size_flags_horizontal=Control.SIZE_SHRINK_END;bubble.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
 bubble.set_speaker_visible(false)
func render_dialogue(_text_override: String="",_kind: String="normal") -> bool:
 # Service pages reserve the working area for the operation. The entry page
 # owns the NPC and conversation, so no detached speech overlaps service UI.
 return true
