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
func delivery_here(page: String) -> bool:
 var c=pages.c();var q=c.get("activeQuest")
 if not q is Dictionary or q.get("to")!=c.location:return false
 var facility=pages.hub_view.FACILITIES.get(q.get("deliveryFacility",""),[])
 return not facility.is_empty() and facility[1]==page
func choose(value: String):
 if value=="delivery":
  if at_top() and delivery_here(ui.page) and pages.c().get("cargoAboard",false) and not ui.locked and not ui.modal_open():ui.act("completeQuest",[])
  return
 if value not in ["buy","sell","inn","guild","warehouse"] or value=="sell" and not pages.c().get("saleAvailable",false):return
 if ui.locked or ui.presenting or ui.modal_open() or pages.shop_view.busy():return
 if ui.page=="shop" and value in ["buy","sell"] and pages.c().get("selected",[]).has(pages.party_uid):ui.shop_uid=pages.party_uid
 view=value;pages.shop_view.sale.reset();ui.memory.focus_key="";ui.render()
func facility_name(page: String) -> String:
 return str({"shop":{"east":"武器屋","west":"防具屋","south":"道具屋","north":"装飾品店"}.get(str(pages.c().get("location")),"商店"),"inn":"宿屋","party":"ギルド"}.get(page,""))
func place_region(control: Control,cells: Rect2):
 control.top_level=true
 var reference=weakref(control)
 var place=func():
  var target=reference.get_ref()
  if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():return
  ui.mock_shell.Grid.place(target,ui.mock_shell.Grid.cell_rect(ui.size,int(cells.position.x),int(cells.position.y),int(cells.size.x),int(cells.size.y)))
 ui.resized.connect(place)
 control.minimum_size_changed.connect(place.call_deferred)
 control.tree_exiting.connect(func():ui.resized.disconnect(place),CONNECT_ONE_SHOT)
 place.call_deferred()
func render_title(parent: Control,page: String):
 var layer=Control.new();layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.top_level=true;parent.add_child(layer)
 var heading=ui.label_(layer,facility_name(page),true);heading.name="FacilityEntryTitle"
 heading.autowrap_mode=TextServer.AUTOWRAP_OFF
 heading.custom_minimum_size=Vector2.ZERO
 heading.add_theme_font_size_override("font_size",30);heading.add_theme_color_override("font_color",Color("#faf9f5"));heading.add_theme_color_override("font_outline_color",Color("#283128"));heading.add_theme_constant_override("outline_size",6)
 place_region(heading,Rect2(1,1,8,1))
func render_top(parent: Control,page: String) -> bool:
 sync()
 if not at_top(page):return false
 var layout=Control.new();parent.add_child(layout);layout.name="FacilityEntry";layout.custom_minimum_size.y=ui.mock_shell.content_height();layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var cell=ui.mock_shell.grid_cell()
 var options=VBoxContainer.new();options.name="FacilityChoices";options.add_theme_constant_override("separation",0);layout.add_child(options)
 place_region(options,Rect2(0,2,6,7))
 var town_label=ui.label_(options,ui.town_name(pages.c().get("location","")));town_label.add_theme_font_size_override("font_size",20);town_label.add_theme_color_override("font_color",Color("#faf9f5"));town_label.add_theme_color_override("font_outline_color",Color("#283128"));town_label.add_theme_constant_override("outline_size",6)
 render_title(layout,page)
 town_label.custom_minimum_size.y=cell.y
 var choices=[]
 if page=="shop":
  choices=[["取引する","buy",true]]
  if pages.c().get("location")!="south":choices.append(["強化する","upgrade",false])

 elif page=="inn":choices=[["休息する","inn",true]]
 else:choices=[["パーティメンバー編成","guild",true],["倉庫を利用する","warehouse",true]]
 var handoff=delivery_here(page)
 if page=="shop" or handoff:
  choices.append(["納品する","delivery",handoff and pages.c().get("cargoAboard",false)])
 for choice in choices:
  var button=ui.button(options,choice[0],choose.bind(choice[1]),not choice[2]);button.name="FacilityChoice_"+str(choice[1]);button.custom_minimum_size=Vector2(300,64);
  if choice[2]:ui.green_button(button)
  button.custom_minimum_size=Vector2(cell.x*2,cell.y)
  button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
  ui.memory.key(button,"facility_"+str(choice[1]))
  if not choice[2]:
   if choice[1]=="delivery":button.tooltip_text="荷物を持つポーターを同行させてください。" if handoff else "この施設に届ける依頼はありません。"
   else:button.tooltip_text="この機能はまだ利用できません。"
 if handoff and not pages.c().get("cargoAboard",false):
  ui.label_(options,"同行ポーターがこの依頼の荷物を持っていません。依頼は未完了です。")
 var exit_button=ui.button(options,"店を出る",ui.navigate.bind("hub"));exit_button.name="FacilityExit";exit_button.custom_minimum_size=Vector2(300,64)
 render_entry_art(layout)
 return true
func render_entry_art(layout: Control,words: String="",inn_service: bool=false):
 # All facility entrances share A's right-side framing and B's left choices.
 var stage=Control.new();stage.name="FacilityNpcStage";stage.mouse_filter=Control.MOUSE_FILTER_IGNORE;layout.add_child(stage)
 # Entry art leaves with the view; cached backgrounds remain independent.
 var art=Control.new();art.name="FacilityEntryArt";art.top_level=true;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(art);art.position=Vector2.ZERO;art.size=ui.size
 var npc=pages.facility_art.npc
 if npc.texture!=null:
  var region=Control.new();region.name="InnKeeperRegion" if inn_service else "FacilityNpcRegion";region.mouse_filter=Control.MOUSE_FILTER_IGNORE;region.clip_contents=true;art.add_child(region)
  place_region(region,Rect2(6,4,4,5))
  var image=TextureRect.new();image.name="InnKeeper" if inn_service else "FacilityNpc";image.texture=npc.texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;region.add_child(image)
  image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var speech=make_speech(greeting_text() if words.is_empty() else words,"normal");speech.name="InnKeeperSpeech" if inn_service else "FacilityEntrySpeech";art.add_child(speech)
 place_region(speech,Rect2(6,2,4,2))
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
