extends Node
## Explicit opt-in native diagnostics. Never stores payloads, paths or save data.
const MAX_ENTRIES=200
const Tokens=preload("res://ui_tokens.gd")
var owner_ref: WeakRef
var ui:
 get:return owner_ref.get_ref()
var window: Window
var heading: Label
var music: Label
var seek_button: Button
var previous_music := ""
var music_entries: Array[String]=[]
var history_filter: OptionButton
var click_entries: Array[String]=[]
var click_trace
var click_number := 0
var status: Label
var persistence: Label
var history: TextEdit
var entries: Array[String]=[]
var previous: Dictionary={}
var elapsed:=0.0
func is_enabled() -> bool:return OS.is_debug_build()
func _ready():set_process(is_enabled())
func configure(owner):
 owner_ref=weakref(owner);set_process(is_enabled())
func sample() -> Dictionary:
 if ui==null or ui.engine==null:return {}
 return {"処理待ち":bool(ui.locked),"演出":bool(ui.presenting),"予測待ち":bool(ui.preview_pending),"見積待ち":bool(ui.pages.quote_pending),"エンジン処理":bool(ui.engine.busy),"接続断":bool(ui.engine.disconnected),"ロード画面":bool(ui.loading_screen.active)}
func state_text(value: Dictionary) -> String:
 var parts: Array[String]=[]
 for key in value:parts.append(str(key)+": "+("ON" if value[key] else "OFF"))
 return " / ".join(parts)
func append_entry(message: String,category := 0):
 var line := "%0.3f  %s" % [Time.get_ticks_msec()/1000.0,message]
 entries.append(line)
 if category!=0:
  var filtered: Array[String]=music_entries if category==1 else click_entries
  filtered.append(line)
  if filtered.size()>MAX_ENTRIES:filtered.pop_front()
 if entries.size()>MAX_ENTRIES:entries.pop_front()
 if is_instance_valid(history_filter) and history_filter.selected in [0,category]:refresh_history()
func request_finished(file_operation: bool,ok: bool,duration: int):
 if not is_enabled():return
 # These typed primitives are deliberately the whole logging interface.
 append_entry(("ファイル要求" if file_operation else "ゲーム要求")+" / "+("成功" if ok else "失敗")+" / %d ms" % maxi(0,duration))
func refresh_state():
 if not is_enabled():return
 var current=sample()
 if current!=previous:
  previous=current;append_entry(state_text(current))
  if "debug_store" in ui.engine and is_instance_valid(ui.engine.debug_store):ui.engine.debug_store.state_changed({"locked":current.get("処理待ち",false),"presenting":current.get("演出",false),"preview_pending":current.get("予測待ち",false),"quote_pending":current.get("見積待ち",false),"busy":current.get("エンジン処理",false),"disconnected":current.get("接続断",false),"loading":current.get("ロード画面",false)})
 if is_instance_valid(status):status.text=state_text(current).replace(" / エンジン処理:", "\nエンジン処理:")
 if is_instance_valid(persistence):persistence.text="ローカルDB："+str(ui.engine.debug_store.status if "debug_store" in ui.engine and is_instance_valid(ui.engine.debug_store) else "無効")
func clock_text(seconds: float) -> String:
 var total := maxi(0, floori(seconds))
 return "%02d:%02d" % [floori(total / 60.0), total % 60]

func track_status(player: AudioStreamPlayer) -> String:
 if player.stream == null:return "停止"
 var file := player.stream.resource_path.get_file()
 if file.is_empty():file = player.stream.resource_name
 var state := "再生中" if player.playing else "停止"
 if player.stream_paused:state = "一時停止"
 return "%s　%s" % [file if not file.is_empty() else "音源名不明",state]

func track_time(player: AudioStreamPlayer) -> String:
 if player.stream == null:return ""
 return "　%s / %s" % [clock_text(player.get_playback_position()),clock_text(player.stream.get_length())]

func seekable_player() -> AudioStreamPlayer:
 var active: AudioStreamPlayer
 for player: AudioStreamPlayer in [ui.audio.bgm,ui.audio.quest]:
  if player.playing and not player.stream_paused:
   if active != null:return null
   active = player
 return active

func seek_loop_end():
 var active := seekable_player()
 if active == null:return
 active.seek(maxf(0.0,active.stream.get_length()-5.0))
 refresh_music()

func refresh_music():
 if not is_instance_valid(window) or not window.visible:return
 var screen: String = ui.ui_labels.screen_id(ui.get_window())
 var scene: String = ui.ui_labels.CATALOG.data.screens[screen].label
 if screen == "entry":scene += "／"+ui.pages.facility_entry.facility_name(ui.page)
 var campaign: Dictionary = ui.campaign()
 if campaign.get("phase") == "town":scene = ui.town_name(campaign.get("location",""))+" ／ "+scene
 var volume := "ミュート" if not ui.audio.audible("bgm") else "%d%%" % int(ui.audio.volumes.bgm)
 if AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):volume += "・マスター消音"
 heading.text = "%s　｜　BGM %s" % [scene,volume]
 var main_track := track_status(ui.audio.bgm)
 var road_track := track_status(ui.audio.quest)
 music.text = "場面曲　%s%s\n道中曲　%s%s" % [main_track,track_time(ui.audio.bgm),road_track,track_time(ui.audio.quest)]
 seek_button.disabled = seekable_player() == null
 var change := "%s ／ 場面曲 %s ／ 道中曲 %s" % [heading.text,main_track,road_track]
 if change != previous_music:
  previous_music = change
  append_entry(change,1)

func _process(delta):
 elapsed+=delta
 if elapsed<.2:return
 elapsed=0;refresh_state();refresh_music()
func refresh_history():
 if not is_instance_valid(window) or not window.visible:return
 history.text="\n".join([entries,music_entries,click_entries][history_filter.selected])
 # Wrapped visual lines can exceed logical line_count. Wait for the range
 # to update, then follow its actual bottom instead of a logical line index.
 follow_latest.call_deferred()
func follow_latest():
 if not is_instance_valid(window) or not window.visible:return
 history.scroll_vertical=history.get_v_scroll_bar().max_value
func clear_history():
 entries.clear();music_entries.clear();click_entries.clear();refresh_history()
func open():
 if not is_enabled():return
 if not is_instance_valid(window):build()
 window.theme=ui.theme
 refresh_state();window.show();refresh_music();refresh_history();window.grab_focus();history.grab_focus()
func build():
 if not is_enabled():return
 window=Window.new();window.visible=false;window.name="DeveloperWindow";window.title="5525 開発情報";window.force_native=true;window.transient=false;window.exclusive=false;window.size=Vector2i(720,480);window.min_size=Vector2i(440,480);window.visible=false;window.theme=ui.theme;add_child(window)
 ui.preferences.bind_window(window,"developer",ui.size,Vector2(960,864),Vector2(768,864))
 window.visibility_changed.connect(track_visibility)
 window.close_requested.connect(window.hide)
 window.window_input.connect(func(event):
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
   window.hide();window.set_input_as_handled())
 var background=ColorRect.new();background.color=Tokens.SURFACE;background.mouse_filter=Control.MOUSE_FILTER_IGNORE;window.add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin=MarginContainer.new();window.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,0)
 var column=preload("res://window_grid.gd").new();margin.add_child(column)
 heading=Label.new();heading.name="DebugHeading";heading.add_theme_font_size_override("font_size",Tokens.FONT_HEADING);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(heading)
 music=Label.new();music.name="DebugMusic";music.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(music)
 status=Label.new();status.name="DebugState";status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
 persistence=Label.new();persistence.name="DebugPersistence";persistence.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(persistence)
 var hint=Label.new();hint.name="DebugHistoryHint";hint.text="表示履歴（最新200件）";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(hint)
 var inset:=StyleBoxEmpty.new()
 inset.content_margin_left=Tokens.SPACE_MD;inset.content_margin_right=Tokens.SPACE_MD
 for label: Label in [heading,music,status,persistence,hint]:
  label.add_theme_stylebox_override("normal",inset)
 history=TextEdit.new();history.name="DebugHistory";history.editable=false;history.custom_minimum_size.y=120;history.size_flags_vertical=Control.SIZE_EXPAND_FILL;history.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;column.add_child(history)
 history.get_v_scroll_bar().changed.connect(follow_latest,CONNECT_DEFERRED)
 var actions=HBoxContainer.new();actions.name="DebugActions";actions.add_theme_constant_override("separation",Tokens.SPACE_SM);column.add_child(actions)
 seek_button=Button.new();seek_button.name="DebugSeekLoop";seek_button.text="曲末5秒へ";Tokens.apply_button_size(seek_button,Tokens.BUTTON_MD);seek_button.pressed.connect(seek_loop_end);actions.add_child(seek_button)
 history_filter=OptionButton.new();history_filter.name="DebugHistoryFilter";history_filter.tooltip_text="表示する履歴";history_filter.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 for title in ["全履歴","BGM履歴のみ","クリック履歴のみ"]:history_filter.add_item(title)
 history_filter.item_selected.connect(func(_index):refresh_history());actions.add_child(history_filter)
 var clear=Button.new();clear.theme_type_variation=&"ActionButton";clear.name="DebugClear";clear.text="表示履歴を消去";Tokens.apply_button_size(clear,Tokens.BUTTON_MD);clear.pressed.connect(clear_history);actions.add_child(clear)
 var close=Button.new();close.name="DebugClose";close.text="閉じる";Tokens.apply_button_size(close,Tokens.BUTTON_MD);close.pressed.connect(window.hide);actions.add_child(close)

func track_visibility():
 if window.visible:
  click_trace=preload("res://debug_click_trace.gd").new()
  add_child(click_trace)
 elif is_instance_valid(click_trace):
  if "click_observer" in ui.engine:ui.engine.click_observer=Callable()
  click_trace.queue_free()
  click_trace=null
