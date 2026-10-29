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
 view=value;pages.shop_view.sale.reset();ui.memory.focus_key="";ui.render()
func render_top(parent: Control,page: String) -> bool:
 sync()
 if not at_top(page):return false
 var title={"shop":{"east":"武器店","west":"防具店","south":"道具店","north":"装飾品店"}.get(str(pages.c().get("location")),"商店"),"inn":"宿屋","party":"ギルド"}.get(page,"")
 var surface=VBoxContainer.new();surface.name="FacilityEntry";surface.size_flags_vertical=Control.SIZE_EXPAND_FILL;surface.add_theme_constant_override("separation",24);parent.add_child(surface)
 ui.icons.line(ui,surface,"inn" if page=="inn" else "castle" if page=="party" else ui.icons.shop(str(pages.c().location)),title,true).name="FacilityEntryTitle"
 var layout=HBoxContainer.new() if ui.size.x>=1120 else VBoxContainer.new();layout.name="FacilityEntryLayout";layout.add_theme_constant_override("separation",32);surface.add_child(layout)
 var options=VBoxContainer.new();options.name="FacilityChoices";options.custom_minimum_size.x=280;options.add_theme_constant_override("separation",14);layout.add_child(options)
 var choices=[]
 if page=="shop":
  choices=[["購入する","buy",true],["売却する" if pages.c().get("saleAvailable",false) else "売却する（利用不可）","sell",pages.c().get("saleAvailable",false)]]
  if pages.c().get("location")!="south":choices.append(["強化する（未実装）","upgrade",false])
  choices.append(["納品する（未実装）","delivery",false])
 elif page=="inn":choices=[["宿泊する","inn",true]]
 else:choices=[["パーティーを編成する","guild",true],["倉庫を利用する","warehouse",true],["納品する（未実装）","delivery",false]]
 for choice in choices:
  var button=ui.button(options,choice[0],choose.bind(choice[1]),not choice[2]);button.name="FacilityChoice_"+str(choice[1]);button.custom_minimum_size=Vector2(280,54);ui.memory.key(button,"facility_"+str(choice[1]))
  if not choice[2]:
   button.tooltip_text="この施設では売却できません。" if choice[1]=="sell" else "この機能はまだ利用できません。"
   if choice[1]=="sell":
    for inventory in pages.c().get("inventoryByCharacter",{}).values():
     if not inventory.get("entries",[]).is_empty():button.tooltip_text=str(inventory.entries[0].get("sale",{}).get("reason",button.tooltip_text));break
 if not render_dialogue():
  var greeting=make_speech(greeting_text(),"normal");fit_inline_speech(greeting);layout.add_child(greeting)
 return true
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
func render_dialogue(text_override: String="",kind: String="normal") -> bool:
 if not pages.facility_art.npc.available(ui.size):return false
 for previous in ui.backdrop_layer.get_children():
  if previous.name=="FacilityGreeting":ui.backdrop_layer.remove_child(previous);previous.queue_free()
 var bubble=make_speech(greeting_text() if text_override.is_empty() else text_override,kind);ui.backdrop_layer.add_child(bubble)
 var width=clampf(ui.size.x*.25,280,480);bubble.position=Vector2(ui.size.x-width-24,28);bubble.size=Vector2(width,160)
 bubble.point_to(pages.facility_art.npc.mouth_anchor(ui.backdrop_layer))
 return true
