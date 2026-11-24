extends RefCounted
## A facility projection of character inventories; the bridge owns sale pricing.
const Tokens=preload("res://ui_tokens.gd")
var shop_ref: WeakRef
var shop:
 get:return shop_ref.get_ref()
var ui
var owner_id := ""
var item_id := ""
var inventory_filter := "all"
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
 inventory_filter="all";confirmation=null;owner_id="";item_id="";amount=1;stage="list";quote={};message="";generation+=1;previewing=false;observed_token=null
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
 var count=int(item.count)
 var weight=item.get("definition",{}).get("weight",item.get("weight"))
 var total=str(snappedf(float(weight)*count,0.01)).trim_suffix(".0") if weight!=null else "不明"
 var choose=ui.button(parent,"%s  ×%d　Wt %s" % [item.name,count,total],select_item.bind(str(item.id)),busy())
 choose.name="SaleItem_"+str(item.id)
 choose.alignment=HORIZONTAL_ALIGNMENT_LEFT
 choose.custom_minimum_size.y=Tokens.BUTTON_LG
 choose.clip_text=true
 var icon=ui.icons.equipment(item) if item.get("kind")=="equipment" else "items" if item.get("kind")=="quest" else str(item.id)
 choose.icon=ui.icons.texture(icon)
 choose.expand_icon=true
 choose.add_theme_constant_override("icon_max_width",40)
 ui.mark_selected(choose,shop.selection_kind=="sell" and item_id==str(item.id))
 preload("res://equipment_tooltip.gd").bind_hover(choose,item.duplicate(true),ui.campaign())
 preload("res://item_drag.gd").source(choose,shop.pages.party_view.workspace.payload.bind(item,"transfer",null,owner_id),str(item.name),choose.icon,shop.can_drop_product.bind(owner_id),shop.drop_inventory)
 ui.memory.key(choose,"sale_"+str(item.id));ui.memory.item(choose,str(item.id))
 var reason=str(item.get("sale",{}).get("reason",""))
 if not reason.is_empty():choose.tooltip_text=reason
func change_filter(value: String):
 if busy():return
 inventory_filter=value
 if shop.selection_kind=="sell" and not selected().is_empty() and not preload("res://member_inventory.gd").matches(selected(),value):
  apply_owner(owner_id);shop.selection_kind=""
 ui.render()
func render_inventory(parent):
 var token=ui.campaign().get("inventoryToken")
 if stage!="pending" and observed_token!=token:
  observed_token=token;quote={};generation+=1;previewing=false
  if not item_id.is_empty() and selected().is_empty():item_id="";stage="list";amount=1
 for item in entries():
  if preload("res://member_inventory.gd").matches(item,inventory_filter):row(parent,item)
 if parent.get_child_count()==0:ui.label_(parent,"アイテムはありません")
func render_detail(parent,footer):
 var item=selected()
 if item.is_empty():ui.label_(parent,"インベントリのアイテムを選択");return
 var pad=MarginContainer.new()
 pad.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for side in ["left","top","right","bottom"]:pad.add_theme_constant_override("margin_"+side,Tokens.SPACE_SM)
 parent.add_child(pad)
 var detail_body=VBoxContainer.new()
 detail_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 detail_body.add_theme_constant_override("separation",Tokens.SPACE_SM)
 pad.add_child(detail_body)
 var icon=ui.icons.equipment(item) if item.get("kind")=="equipment" else "items" if item.get("kind")=="quest" else str(item.id)
 if item.get("kind")=="equipment":shop.pages.describe_gear(detail_body,item.get("definition",item),true)
 else:ui.icons.line(ui,detail_body,icon,str(item.name),true).name="FacilitySaleTarget"
 amount=clampi(amount,1,int(item.count))
 var totals=shop.transaction_fields(footer,false,int(item.get("sale",{}).get("price",0)),amount,int(item.count),func(value):amount=int(value);quote={};generation+=1;request_quote())
 if not message.is_empty():totals.text=message
 var button=ui.action_button(ui.button(footer,"買取明細へ",confirm_sale,not item.get("sale",{}).get("ok",false) or busy(),"md"),"md");button.name="FacilitySalePrepare";button.size_flags_horizontal=Control.SIZE_SHRINK_END
 button.tooltip_text=str(item.get("sale",{}).get("reason",""))
 if not quote.is_empty():show_quote(totals)
 elif not busy() and not previewing:request_quote()
func show_quote(label: Label):
 label.text="所持金 %d G ＋ 売却 %d G = 残金 %d G" % [quote.goldBefore,quote.proceeds,quote.afterGold] if quote.get("ok",false) else str(quote.get("reason","金額を取得できません。"))
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
 var dialog=ui.facility_receipt("買取明細",selected(),confirmed.ownerName,commit.bind(confirmed,ticket,epoch,connection),func(body,d):
  ui.receipt_line(body,"売却数 × 単価").text="%d × %d G" % [confirmed.count,confirmed.price]
  ui.receipt_line(body,"受取金額").text="+%d G" % confirmed.proceeds
  ui.receipt_line(body,"所持金").text="%d → %d G" % [confirmed.goldBefore,confirmed.afterGold]
  ui.receipt_line(body,"手元に残る数").text="%d → %d" % [confirmed.available,confirmed.available-confirmed.count]
  d.ok_button_text="%d個売却する" % confirmed.count)
 confirmation=dialog;dialog.name="FacilitySaleConfirmation"
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
