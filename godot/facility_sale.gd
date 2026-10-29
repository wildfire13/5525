extends RefCounted
## A facility projection of character inventories; the bridge owns sale pricing.
var shop_ref: WeakRef
var shop:
 get:return shop_ref.get_ref()
var ui
var owner_id := ""
var item_id := ""
var amount := 1
var stage := "list"
var quote: Dictionary={}
var message := ""
var generation := 0
var previewing := false
var observed_token=null
var confirmation: ConfirmationDialog
func _init(controller):shop_ref=weakref(controller);ui=controller.ui
func reset():
 if is_instance_valid(confirmation):confirmation.hide();confirmation.queue_free()
 confirmation=null;owner_id="";item_id="";amount=1;stage="list";quote={};message="";generation+=1;previewing=false;observed_token=null
func busy() -> bool:return stage in ["confirm","pending","unknown"]
func entries() -> Array:return ui.campaign().get("inventoryByCharacter",{}).get(owner_id,{}).get("entries",[])
func selected() -> Dictionary:
 for item in entries():
  if str(item.id)==item_id:return item
 return {}
func apply_owner(uid: String):
 # Called only after the shop has validated the allowed interaction context.
 owner_id=uid;item_id="";amount=1;quote={};stage="list";message="";generation+=1;previewing=false;ui.memory.scrolls.erase("facility_sale")
func select_owner(uid: String):
 if busy() or ui.locked or ui.modal_open():return
 apply_owner(uid);ui.render()
func select_item(id: String):
 if busy() or ui.locked or ui.modal_open():return
 item_id=id;amount=1;quote={};stage="selected";message="";generation+=1;ui.render()
func row(parent,item: Dictionary):
 var line=ui.row(parent);line.name="SaleRow_"+str(item.id);line.custom_minimum_size.y=64
 var choose=ui.button(line,str(item.name),select_item.bind(str(item.id)),busy());choose.name="SaleItem_"+str(item.id);choose.custom_minimum_size=Vector2(240,64);choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choose.alignment=HORIZONTAL_ALIGNMENT_LEFT
 ui.icons.apply(choose,ui.icons.equipment(item) if item.get("kind")=="equipment" else str(item.id));ui.memory.key(choose,"sale_"+str(item.id));ui.memory.item(choose,str(item.id));choose.tooltip_text=str(item.name)
 var count=ui.label_(line,"所持 %d個" % int(item.count));count.custom_minimum_size.x=110;count.size_flags_horizontal=Control.SIZE_FILL;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;count.autowrap_mode=TextServer.AUTOWRAP_OFF
 var can=item.get("sale",{}).get("ok",false);var action=ui.button(line,"売却" if can else "売却不可",select_item.bind(str(item.id)),busy() or not can);action.name="SaleSelect_"+str(item.id);action.custom_minimum_size=Vector2(130,64);action.tooltip_text=str(item.get("sale",{}).get("reason",""))
func render(parent):
 var token=ui.campaign().get("inventoryToken")
 if stage!="pending" and observed_token!=token:
  observed_token=token;quote={};generation+=1;previewing=false
  if not item_id.is_empty() and selected().is_empty():item_id="";stage="list";amount=1
 var compact=ui.size.y<720;var panel=PanelContainer.new();panel.name="FacilitySalePanel";panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;panel.custom_minimum_size.x=maxf(600,ui.size.x*2.0/3.0-parent.global_position.x);var style=StyleBoxFlat.new();style.bg_color=Color("#1e232bed");style.border_color=Color("#666b73");style.set_border_width_all(1);style.set_corner_radius_all(8);style.set_content_margin_all(14);panel.add_theme_stylebox_override("panel",style);parent.add_child(panel)
 var body=VBoxContainer.new();body.add_theme_constant_override("separation",8 if compact else 12);panel.add_child(body)
 var heading=ui.row(body);var title=ui.label_(heading,"売却",true);title.name="FacilitySaleHeading";title.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;title.autowrap_mode=TextServer.AUTOWRAP_OFF
 var close=ui.button(heading,"×",finish,busy());close.name="FacilitySaleClose";close.tooltip_text="売却を終了する";close.custom_minimum_size.x=44
 var end=ui.button(body,"売却を終了する",finish,busy());end.name="FacilitySaleEnd";end.size_flags_horizontal=Control.SIZE_SHRINK_END
 if owner_id.is_empty():
  ui.label_(body,"下の人物を選ぶと、その人物の所持品がここに表示されます。");body.move_child(end,-1);return
 var owner=ui.label_(heading," / "+ui.member_name(owner_id)+"の所持品",true);owner.name="FacilitySaleOwner";owner.size_flags_horizontal=Control.SIZE_EXPAND_FILL;owner.max_lines_visible=2;owner.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;owner.tooltip_text=owner.text;heading.move_child(close,-1)
 var list=ui.scroller(body);list.get_parent().name="FacilitySaleScroll";list.get_parent().custom_minimum_size.y=80 if compact else 100;list.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.memory.watch(list.get_parent(),"facility_sale")
 for item in entries():row(list,item)
 if entries().is_empty():ui.label_(list,"この人物の所持品はありません。")
 body.move_child(end,-1)
 if item_id.is_empty():return
 var item=selected()
 if item.is_empty():return
 var actions=VBoxContainer.new();actions.name="FacilitySaleActions";body.add_child(actions)
 body.move_child(end,-1)
 var target=ui.label_(actions,ui.member_name(owner_id)+" / "+str(item.name),true);target.name="FacilitySaleTarget"
 if compact:target.add_theme_font_size_override("font_size",18)
 var controls=ui.row(actions);ui.label_(controls,"売却個数")
 var count=SpinBox.new();count.name="FacilitySaleQuantity";count.min_value=1;count.max_value=int(item.count);amount=clampi(amount,1,int(item.count));count.step=1;count.value=amount;count.custom_minimum_size.x=132;count.editable=not busy();controls.add_child(count)
 count.value_changed.connect(func(value):amount=int(value);quote={};generation+=1;request_quote())
 ui.primary(ui.button(controls,"売却を確認",confirm_sale,not item.get("sale",{}).get("ok",false) or busy())).name="FacilitySalePrepare"
 var totals=ui.label_(actions,message if not message.is_empty() else "売却額を確認中…");totals.name="FacilitySaleTotals"
 if compact:totals.add_theme_font_size_override("font_size",18)
 if not quote.is_empty():show_quote(totals)
 elif not busy():request_quote()
func show_quote(label: Label):
 label.text="%sの%s ×%d / 受取 %dG / 所持金 %d → 売却後 %dG" % [quote.ownerName,quote.name,quote.count,quote.proceeds,quote.goldBefore,quote.afterGold] if quote.get("ok",false) else "売却不可："+str(quote.get("reason","金額を取得できません。"))
func valid(ticket: int,epoch: int,connection: int,owner: String,item: String,count: int,token) -> bool:
 return ticket==generation and epoch==ui.pages.epoch and connection==ui.engine.connection_generation and owner==owner_id and item==item_id and count==amount and token==ui.campaign().get("inventoryToken") and shop.sale_mode() and not ui.closing
func request_quote():
 var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var owner=owner_id;var item=item_id;var count=amount;var token=ui.campaign().get("inventoryToken")
 previewing=true
 while ui.engine.busy:
  await ui.get_tree().process_frame
  if not valid(ticket,epoch,connection,owner,item,count,token):return
 var reply=await ui.engine.request({"op":"campaign","action":"saleQuote","args":[owner,item,count]})
 if not valid(ticket,epoch,connection,owner,item,count,token):return
 previewing=false;quote=reply.get("saleQuote",{})
 if quote.get("ok",false):message=""
 if reply.get("connection_lost",false):stage="unknown";message="結果を確認できません。再送せず保存済みの進行を確認してください。";ui.handle_connection_loss(reply,connection);return
 var label=ui.find_child("FacilitySaleTotals",true,false)
 if is_instance_valid(label):show_quote(label)
func confirm_sale():
 if busy() or ui.locked or ui.modal_open() or previewing or not quote.get("ok",false):return
 stage="confirm";var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var confirmed=quote.duplicate(true)
 var dialog=ui.confirm("売却しますか？\n%sの %s ×%d\n受取 %dG / 所持金 %d → %dG" % [confirmed.ownerName,confirmed.name,confirmed.count,confirmed.proceeds,confirmed.goldBefore,confirmed.afterGold],commit.bind(confirmed,ticket,epoch,connection));confirmation=dialog;dialog.name="FacilitySaleConfirmation";dialog.ok_button_text="YES";dialog.cancel_button_text="NO"
 dialog.get_ok_button().name="FacilitySaleConfirm";dialog.get_cancel_button().name="FacilitySaleCancel"
 var cancel=func():
  if ticket==generation and stage=="confirm":stage="selected";ui.render()
 dialog.canceled.connect(cancel);dialog.close_requested.connect(cancel);dialog.get_cancel_button().grab_focus()
func commit(confirmed: Dictionary,ticket: int,epoch: int,connection: int):
 if stage!="confirm" or not valid(ticket,epoch,connection,str(confirmed.ownerId),str(confirmed.itemId),int(confirmed.count),confirmed.token) or ui.locked:return
 confirmation=null;stage="pending"
 var reply=await ui.update({"op":"campaign","action":"sellInventory","args":[confirmed.ownerId,confirmed.itemId,confirmed.count,confirmed.token]})
 if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
 if reply.get("connection_lost",false):stage="unknown";message="結果を確認できません。保存済みの進行を確認してください。";ui.render();return
 if reply.get("ok",false):
  stage="list";item_id="";amount=1;quote={};shop.record_sale(confirmed)
 else:stage="selected";message=str(reply.get("error","売却できません。"));quote={}
 generation+=1;ui.render()

func finish():
 if busy() or ui.locked or ui.modal_open():return
 shop.pages.facility_entry.back()
