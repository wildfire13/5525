"""Native Tk frontend using an unchanged snapshot of the existing battle engine."""
import json
from pathlib import Path
import subprocess
import tkinter as tk
from tkinter import filedialog
from datetime import datetime

BASE = Path(__file__).resolve().parent


class Bridge:
    def __init__(self):
        self.process = subprocess.Popen(['node', str(BASE/'bridge.cjs')], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, text=True, encoding='utf-8', cwd=BASE)

    def call(self, **request):
        self.process.stdin.write(json.dumps(request)+'\n')
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError('Battle engine stopped')
        return json.loads(line)

    def close(self):
        self.process.terminate()
        self.process.wait(timeout=3)
        self.process.stdin.close()
        self.process.stdout.close()


class App:
    def __init__(self, root, bridge=None, on_finish=None, on_close=None):
        self.owns_bridge = bridge is None
        self.on_finish, self.on_close = on_finish, on_close
        self.root, self.bridge = root, bridge or Bridge()
        self.mode, self.pending = 'attack', None
        self.preview, self.preview_kind = None, 'attack'
        self.images={}
        for path in (BASE/'assets').rglob('*.png'):
            image=tk.PhotoImage(master=root,file=str(path));self.images[path.relative_to(BASE/'assets').as_posix()]=image.subsample(max(1,image.width()//48))
        self.data = self.bridge.call(op='reset' if self.owns_bridge else 'view')
        root.title('5525 Native Battle — Official Prototype')
        root.geometry('1210x820+30+25')
        root.resizable(False, False)
        root.configure(bg='#111827')
        root.protocol('WM_DELETE_WINDOW', self.close)
        tk.Label(root, text='5525 / NATIVE BATTLE LAB', font=('sans-serif', 22, 'bold'),
                 bg='#111827', fg='#f1f5f9').pack(anchor='w', padx=20, pady=(14, 2))
        tk.Label(root, text='ネイティブ画面 + 既存JS戦闘エンジン / コマンド → 緑の対象 → 確定（取消可）',
                 font=('sans-serif', 12), bg='#111827', fg='#94a3b8').pack(anchor='w', padx=20)
        body = tk.Frame(root, bg='#111827')
        body.pack(padx=20, pady=14, fill='both', expand=True)
        left = tk.Frame(body, bg='#111827');left.pack(side='left', anchor='n')
        self.turn = tk.Label(left, bg='#111827', fg='#f1f5f9', font=('sans-serif', 14, 'bold'), anchor='w')
        self.turn.pack(fill='x', pady=(0, 8))
        self.canvas = tk.Canvas(left, width=740, height=370, bg='#111827', highlightthickness=0)
        self.canvas.pack();self.canvas.bind('<Button-1>', self.click_cell)
        self.queue = tk.Label(left, bg='#111827', fg='#cbd5e1', font=('sans-serif', 10), wraplength=730, justify='left')
        self.queue.pack(anchor='w', pady=10)
        commands = tk.Frame(left, bg='#111827');commands.pack(anchor='w')
        self.buttons = {}
        for mode, label in [('move','移動'),('attack','攻撃'),('skill','スキル'),('item','回復薬'),('guard','防御')]:
            b=tk.Button(commands,text=label,command=lambda m=mode:self.set_mode(m),font=('sans-serif',12),width=8,pady=7)
            b.pack(side='left',padx=(0,7));self.buttons[mode]=b
        self.notice = tk.Label(left,bg='#1e293b',fg='#fde68a',font=('sans-serif',12),wraplength=710,
                               justify='left',anchor='w',padx=12,pady=12,height=3)
        self.notice.pack(fill='x',pady=10)
        confirm=tk.Frame(left,bg='#111827');confirm.pack(anchor='w')
        self.confirm=tk.Button(confirm,text='確定',command=self.commit,font=('sans-serif',13),width=13,pady=7,bg='#a7f3d0')
        self.confirm.pack(side='left',padx=(0,10))
        tk.Button(confirm,text='取消 / Esc',command=self.cancel,font=('sans-serif',13),width=13,pady=7).pack(side='left')
        self.preview_attack=tk.Button(confirm,text='仮: 攻撃範囲',command=lambda:self.inspect_preview('attack'),font=('sans-serif',10))
        self.preview_attack.pack(side='left',padx=6)
        self.preview_skill=tk.Button(confirm,text='仮: スキル範囲',command=lambda:self.inspect_preview('skill'),font=('sans-serif',10))
        self.preview_skill.pack(side='left')
        root.bind('<Escape>',lambda _:self.cancel())
        controls=tk.Frame(left,bg='#111827');controls.pack(anchor='w',pady=16)
        if not self.owns_bridge:
            controls.pack_forget()
            self.return_button=tk.Button(left,text='戦闘を終えて街道へ',command=self.finish,font=('sans-serif',12))
            self.return_button.pack(anchor='w',pady=12)
        tk.Label(controls,text='局面:',bg='#111827',fg='#cbd5e1').pack(side='left')
        self.scenario=tk.StringVar(value='標準4対4')
        tk.OptionMenu(controls,self.scenario,'標準4対4','QA: 勝利直前','QA: 敗北直前','QA: ポーター危機','QA: スタンプ','QA: かばう').pack(side='left',padx=10)
        tk.Button(controls,text='新規戦闘 / RESET',command=self.reset,font=('sans-serif',11)).pack(side='left')
        tk.Button(controls,text='ログ保存',command=self.export,font=('sans-serif',11)).pack(side='left',padx=8)
        right=tk.Frame(body,bg='#111827');right.pack(side='left',padx=(20,0),fill='both',expand=True)
        tk.Label(right,text='状態・敵の予告・操作ログ',bg='#111827',fg='#94a3b8',font=('sans-serif',12)).pack(anchor='w')
        self.info=tk.Text(right,width=39,height=21,bg='#1e293b',fg='#e2e8f0',font=('sans-serif',10),wrap='char',relief='flat',padx=10,pady=10)
        self.info.pack(fill='x',pady=(8,10))
        self.log=tk.Text(right,width=39,height=22,bg='#1e293b',fg='#e2e8f0',font=('sans-serif',10),wrap='char',relief='flat',padx=10,pady=10)
        self.log.pack(fill='both',expand=True)
        self.message='移動後の攻撃は次の本人の番。金枠=陣形 / 赤枠=敵の攻撃予告 / ↓=敵移動先'
        self.draw()

    def export(self):
        data=self.bridge.call(op='export')['data']
        path=filedialog.asksaveasfilename(parent=self.root,initialdir=str(BASE),title='プレイログを保存',defaultextension='.json',initialfile='5525-native-battle-'+datetime.now().strftime('%Y%m%d-%H%M%S')+'.json',filetypes=[('JSON','*.json')])
        if not path:self.message='保存を取り消しました';self.draw();return
        try:
            Path(path).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8');self.message='ログ保存完了: '+Path(path).name
        except OSError as error:self.message='ログ保存失敗: '+str(error)
        self.draw()

    def inspect_preview(self,kind=None):
        if not self.pending:return
        if kind:self.preview_kind=kind
        mode,target=self.pending
        result=self.bridge.call(op='preview',kind=mode,target=target,previewKind=self.preview_kind)
        self.preview=result.get('preview')
        if self.preview:
            p=self.preview;f='維持' if p['formationBefore'] and p['formationAfter'] else '再成立' if p['formationAfter'] else '解除' if p['formationBefore'] else '未成立'
            if mode=='move' or (mode=='skill' and self.actor()['job']=='scout'):
                d=p['destination'];name=next((u['name'] for u in self.data['state']['units'] if u['id']==p['swap']),None)
                self.message=f'仮位置 ({d%10+1},{d//10+1})'+(f' / {name}と交換' if name else '')+f' / 護送陣:{f}\n対象: '+('・'.join(p['targets']) or 'なし')+' / 着地点の敵予告: '+('・'.join(p['risks']) or 'なし')+'\n確定まで行動・MP消費なし'
            elif p['cells']:
                targets=[u['name'] for u in self.data['state']['units'] if u['hp']>0 and u['side']=='enemy' and u['pos'] in p['cells']]
                self.message=f'スタンプ: {len(p["cells"])}マス / 敵: '+('・'.join(targets) or 'なし（空振り）')+'\nオレンジ枠が範囲。確定でMP1・一行動。味方は巻き込みません。'
        self.draw()

    def finish(self):
        if self.data["state"]["result"] and self.on_finish:
            self.root.destroy();self.on_finish()

    def close(self):
        if self.owns_bridge:self.bridge.close()
        self.root.destroy()
        if self.on_close:self.on_close()

    def actor(self):
        return next((u for u in self.data['state']['units'] if u['id']==self.data['state']['actor']),None)

    def unit_at(self,p):
        return next((u for u in self.data['state']['units'] if u['hp']>0 and u['pos']==p),None)

    def mode_hint(self,mode):
        a=self.actor()
        if not a:return '戦闘終了。再挑戦できます。'
        active='stamp' if a.get('weapon')=='hammer' else a['job']
        skills={
          'guard':'かばう: 隣接する自分以外の味方を、次の本人の番まで肩代わり。MP1',
          'mage':'ヒール: 射程2の傷ついた味方/自分のHPを60回復（最大HPまで）。MP1',
          'archer':f'スナイプ: その一撃だけ射程{a["reach"]+1}（通常+1）。通常威力。MP1',
          'stamp':'スタンプ: 縦横の隣接中心から3マス。空/味方中心も可。敵のみ通常威力。空振りでもMP1',
          'scout':'奇襲: 同じ横列の'+('前方のみ' if a.get('skillStage')==1 else '左右')+'。遮るキャラなしで手前に着地+通常攻撃。MP1',
          'porter':'陣形強化: 護送陣成立時に自分を選ぶ。次の本人の番まで攻撃+75%/被害-35%。重複なし。MP1'}
        text={'attack':f'通常攻撃: 縦横距離{a["reach"]}以内の敵。','move':'移動: 経路2以内、キャラを通り抜け不可。スカウトのみ境界越え可。'+('味方を選ぶと位置交換。MP消費なし。' if a['job']=='porter' else ''),'skill':skills.get(active,''),'item':'回復薬: 距離制限なし、傷ついた生存味方のHP+55（上限まで）。共有在庫を1消費。','guard':'防御: 次の本人の番まで被ダメージ半減。MP消費なし。'}[mode]
        if mode!='guard' and not self.data['choices'].get(mode):text+='\n今は合法な対象なし。射程・HP/MP・陣形・進路を確認してください。'
        return text

    def set_mode(self,mode):
        self.bridge.call(op='record',type='battle.command',details={'mode':mode})
        self.mode,self.pending=mode,None
        self.preview=None
        a=self.actor()
        if not a:return
        if mode=='guard':
            self.pending=('guard',None);self.message=self.mode_hint(mode)+' 確定で一行動。'
        else:self.message=self.mode_hint(mode)
        self.draw()

    def click_cell(self,e):
        x,y=e.x//74,e.y//74
        if not (0<=x<10 and 0<=y<5):return
        p=y*10+x;a=self.actor()
        if not a:self.message='戦闘は終了しました。RESETで再挑戦できます。';self.draw();return
        u=self.unit_at(p)
        target=p if self.mode=='move' or (self.mode=='skill' and a.get('weapon')=='hammer') else u['id'] if u else None
        if target not in self.data['choices'].get(self.mode,[]):
            self.pending=None;self.preview=None
            self.message='無効な対象です。緑の範囲・対象を選んでください。';self.draw();return
        self.pending=(self.mode,target)
        self.preview_kind='skill' if a['job']=='porter' else 'attack'
        self.bridge.call(op='record',type='battle.preview',details={'kind':self.mode,'target':target})
        name=f'({x+1}, {y+1})' if isinstance(target,int) else u['name']
        self.message=f'プレビュー: {self.buttons[self.mode].cget("text")} → {name}\n確定まで位置・HP・MP・行動数は変わりません。'
        self.inspect_preview()

    def cancel(self):
        self.bridge.call(op='record',type='battle.preview.cancelled')
        self.pending=None;self.preview=None;self.message='取消しました。行動・MPは消費していません。';self.draw()

    def commit(self):
        if not self.pending:return
        mode,target=self.pending;self.pending=None;self.preview=None
        self.data=self.bridge.call(op='act',kind=mode,target=target)
        self.mode='attack';self.message='行動確定。敵の行動も既存ルールで処理されました。' if self.data['ok'] else self.data['error']
        self.draw()

    def reset(self):
        scenario={'標準4対4':'normal','QA: 勝利直前':'victory','QA: 敗北直前':'defeat','QA: ポーター危機':'porter','QA: スタンプ':'stamp','QA: かばう':'support'}[self.scenario.get()]
        self.data=self.bridge.call(op='reset',scenario=scenario)
        self.mode,self.pending='attack',None;self.preview=None
        self.message='新規戦闘を開始しました。' if scenario=='normal' else 'QA固定局面です。標準戦闘のバランス評価には使用しません。'
        self.draw()

    def draw(self):
        c,s=self.canvas,self.data['state'];a=self.actor();c.delete('all')
        if a and a['job']=='porter' and self.mode=='attack':self.mode='move'
        shown=self.preview['units'] if self.preview else s['units']
        targets=self.data['choices'].get(self.mode,[])
        cells={t if isinstance(t,int) else next(u['pos'] for u in s['units'] if u['id']==t) for t in targets}
        for p in range(50):
            x,y=(p%10)*74,(p//10)*74
            fill=('#23384c' if p%10<5 else '#482e3e')
            if p in self.data.get('ranges',{}).get(self.mode,[]):fill='#2f526a'
            if p in cells:fill='#326351'
            if self.preview and p in self.preview['ranges']:fill='#2f6579'
            c.create_rectangle(x+2,y+2,x+72,y+72,fill=fill,outline='#eab308' if p in [24,13,33,25,16,36] else '',width=3)
            c.create_text(x+11,y+10,text=f'{p%10+1},{p//10+1}',fill='#91a0b4',font=('sans-serif',8))
            threats=[u for u in s['units'] if u['hp']>0 and u['side']=='enemy' and p in u.get('intent',{}).get('cells',[])]
            incoming=[u for u in s['units'] if u['hp']>0 and u['side']=='enemy' and u.get('intent',{}).get('destination')==p]
            if threats:
                c.create_rectangle(x+5,y+5,x+69,y+69,outline='#fb7185',width=3)
                c.create_text(x+60,y+12,text=f'!{len(threats)}',fill='#fff',font=('sans-serif',10,'bold'))
            if incoming:c.create_text(x+60,y+62,text='↓',fill='#fda4af',font=('sans-serif',16,'bold'))
        for u in shown:
            if u['hp']<=0:continue
            x,y=(u['pos']%10)*74+37,(u['pos']//10)*74+39
            color='#93c5fd' if u['side']=='ally' else '#fda4af'
            key=('enemy/enemy_' if u['side']=='enemy' else '')+u['image']
            if key in self.images:c.create_image(x,y-8,image=self.images[key])
            else:c.create_oval(x-22,y-25,x+22,y+20,fill=color,outline='')
            c.create_text(x,y+16,text=(u['name'] if len(u['name'])<5 else u['icon']) if u['side']=='ally' else '敵'+u['icon'],font=('sans-serif',10,'bold'),fill=color)
            c.create_text(x,y+29,text=f'{u["hp"]}/{u["max"]}'+(' 防' if u['guard'] else ''),font=('sans-serif',8),fill='#f8fafc')
            if a and a['id']==u['id']:c.create_rectangle(x-32,y-35,x+32,y+34,outline='#fde047',width=2)
            if self.preview and u['id']==s['actor']:c.create_text(x,y-29,text='仮',fill='#fff',font=('sans-serif',10,'bold'))
        if self.pending:
            target=self.pending[1]
            p=target if isinstance(target,int) else next((u['pos'] for u in s['units'] if u['id']==target),None)
            if p is not None:
                for q in self.data.get('stampAreas',{}).get(str(p),[]) if self.pending[0]=='skill' else []:
                    qx,qy=q%10*74,q//10*74
                    c.create_rectangle(qx+7,qy+7,qx+67,qy+67,outline='#fb923c',width=4)
                x,y=p%10*74,p//10*74;c.create_rectangle(x+5,y+5,x+69,y+69,outline='#fef08a',width=4)
        if not self.owns_bridge:self.return_button.config(state='normal' if s['result'] else 'disabled')
        self.turn.config(text=s['result'] or f'行動者: {a["name"]}  HP {a["hp"]}/{a["max"]}  MP {a["mp"]} 射程{a["reach"]} | 行動数: {s["actions"]}')
        self.queue.config(text='行動順: '+' → '.join(('味方 ' if q['side']=='ally' else '敵 ')+q['name'] for q in self.data['queue'][:10]))
        for k,b in self.buttons.items():
            b.config(state='normal' if a and not self.pending and not(k=='attack' and a['job']=='porter') and not(k=='skill' and a['mp']<=0) and not(k=='item' and s['potions']['ally']<=0) else 'disabled',relief='sunken' if k==self.mode else 'raised')
        self.buttons['skill'].config(text=self.data['skill'] or 'スキル')
        can_inspect=bool(self.pending and self.pending[0]=='move' and a)
        self.preview_attack.config(state='normal' if can_inspect and a['job']!='porter' else 'disabled')
        self.preview_skill.config(state='normal' if can_inspect else 'disabled')
        self.confirm.config(state='normal' if self.pending and a else 'disabled')
        self.notice.config(text=self.message)
        info=[f'回復薬: 味方{s["potions"]["ally"]} / 敵{s["potions"]["enemy"]}',f'陣形: 味方{"強化中" if self.data.get("boosted",{}).get("ally") else "ON" if self.data["formed"]["ally"] else "OFF"} / 敵{"ON" if self.data["formed"]["enemy"] else "OFF"}', '']
        for u in s['units']:
            info.append(f'{u["name"]}: HP {u["hp"]}/{u["max"]} MP {u["mp"]} AGI {u["agi"]}'+(' 防御' if u['guard'] else '')+(' 戦闘不能' if u['hp']<=0 else ''))
            if u.get('cover'):info.append('  かばう → '+next(v['name'] for v in s['units'] if v['id']==u['cover']))
            if u['side']=='enemy' and u['hp']>0 and u.get('intent'):
                i=u['intent'];cells=i.get('cells',[])
                target_name=next((v['name'] for v in s['units'] if v['id']==i.get('target')),'')
                info.append('  予告: '+i['name']+(' → '+target_name if target_name else '')+(' → '+','.join(f'({p%10+1},{p//10+1})' for p in cells) if cells else '')+' / '+i.get('reason',''))
        for w,text in [(self.info,'\n'.join(info)),(self.log,'\n\n'.join(s['log'][-40:]))]:
            w.config(state='normal');w.delete('1.0','end');w.insert('end',text);w.config(state='disabled')
        self.log.see('end')


if __name__=='__main__':
    root=tk.Tk();App(root);root.mainloop()
