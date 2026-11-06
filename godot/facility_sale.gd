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
 item_id=id;amount=1;quote={};stage="selected";message="";generation+=1;previewing=false;shop.selection_kind="sell";ui.render()
func row(parent,item: Dictionary):
 var choose=ui.button(parent,"",select_item.bind(str(item.id)),busy());choose.name="SaleItem_"+str(item.id);choose.custom_minimum_size=Vector2(0,64);choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var margin=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;choose.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.add_theme_constant_override("margin_left",8);margin.add_theme_constant_override("margin_right",8)
 var line=HBoxContainer.new();line.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_theme_constant_override("separation",8);margin.add_child(line)
 ui.icons.add(line,ui.icons.equipment(item) if item.get("kind")=="equipment" else "items" if item.get("kind")=="quest" else str(item.id),36)
 var name_=ui.label_(line,str(item.name));name_.add_theme_font_size_override("font_size",14);name_.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var count=ui.label_(line,"×%d" % int(item.count));count.add_theme_font_size_override("font_size",13);count.size_flags_horizontal=Control.SIZE_SHRINK_END;count.autowrap_mode=TextServer.AUTOWRAP_OFF;count.mouse_filter=Control.MOUSE_FILTER_IGNORE
 shop.list_surface(choose,shop.selection_kind=="sell" and item_id==str(item.id));ui.memory.key(choose,"sale_"+str(item.id));ui.memory.item(choose,str(item.id))
 choose.tooltip_text=str(item.get("sale",{}).get("reason",""))
func render_inventory(parent):
 var token=ui.campaign().get("inventoryToken")
 if stage!="pending" and observed_token!=token:
  observed_token=token;quote={};generation+=1;previewing=false
  if not item_id.is_empty() and selected().is_empty():item_id="";stage="list";amount=1
 for item in entries():row(parent,item)
 if entries().is_empty():ui.label_(parent,"アイテムはありません")
func render_detail(parent,footer):
 var item=selected()
 if item.is_empty():ui.label_(parent,"インベントリのアイテムを選択");return
 var icon=ui.icons.equipment(item) if item.get("kind")=="equipment" else "items" if item.get("kind")=="quest" else str(item.id)
 ui.icons.line(ui,parent,icon,str(item.name),true).name="FacilitySaleTarget"
 if item.get("kind")=="equipment":shop.pages.describe_gear(parent,item.get("definition",item))
 var controls=ui.row(parent);ui.label_(controls,"個数")
 var count=SpinBox.new();count.name="FacilitySaleQuantity";count.min_value=1;count.max_value=int(item.count);amount=clampi(amount,1,int(item.count));count.step=1;count.value=amount;count.custom_minimum_size.x=104;count.editable=not busy();controls.add_child(count)
 count.value_changed.connect(func(value):amount=int(value);quote={};generation+=1;request_quote())
 var totals=ui.label_(parent,message if not message.is_empty() else "売却額を確認中…");totals.name="FacilitySaleTotals"
 var button=ui.green_button(ui.button(footer,"取引を確認",confirm_sale,not item.get("sale",{}).get("ok",false) or busy()));button.name="FacilitySalePrepare";button.size_flags_horizontal=Control.SIZE_SHRINK_END
 button.tooltip_text=str(item.get("sale",{}).get("reason",""))
 if not quote.is_empty():show_quote(totals)
 elif not busy() and not previewing:request_quote()
func render(parent):
 # Compatibility entry point. The shop now presents both sides together.
 shop.render(parent)
func show_quote(label: Label):
 label.text="売却 %dG\n所持金 %d → %d G" % [quote.proceeds,quote.goldBefore,quote.afterGold] if quote.get("ok",false) else "売却不可："+str(quote.get("reason","金額を取得できません。"))
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
 var dialog=ui.confirm("売却しますか？\n%sの %s ×%d\n受取 %dG / 所持金 %d → %dG" % [confirmed.ownerName,confirmed.name,confirmed.count,confirmed.proceeds,confirmed.goldBefore,confirmed.afterGold],commit.bind(confirmed,ticket,epoch,connection));confirmation=dialog;dialog.name="FacilitySaleConfirmation";dialog.ok_button_text="売却する";dialog.cancel_button_text="キャンセル"
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
