"""Legacy journey shell and stable launcher for the native campaign prototype."""
from datetime import datetime
import json
from pathlib import Path
from tk_bootstrap import prepare_tk
prepare_tk()
import tkinter as tk
from tkinter import filedialog, messagebox
from app import App, Bridge, BASE
from portraits import resolve_portrait

BG='#111827';FG='#e2e8f0'
class JourneyApp:
    def __init__(self,root):
        self.root,self.bridge=root,Bridge();self.images={}
        for path in (BASE/'assets').rglob('*.png'):
            image=tk.PhotoImage(master=root,file=str(path));self.images[path.relative_to(BASE/'assets').as_posix()]=image.subsample(max(1,image.width()//48))
        self.battle_window=None;self.selected=None;self.drag_start=None
        self.data=self.bridge.call(op='journey_start');self.notice='';self.kit=tk.StringVar(value='medicine');self.formation=tk.StringVar(value='convoy')
        root.title('5525 Native Journey — Official Prototype');root.geometry('1180x850+20+20');root.configure(bg=BG)
        root.protocol('WM_DELETE_WINDOW',self.close)
        top=tk.Frame(root,bg=BG);top.pack(fill='x',padx=20,pady=12)
        tk.Label(top,text='5525 / COURIER’S ROAD',bg=BG,fg=FG,font=('sans-serif',22,'bold')).pack(side='left')
        tk.Button(top,text='プレイログ保存 JSON',command=self.export).pack(side='right')
        tk.Button(top,text='戦闘単体版',command=self.open_standalone).pack(side='right',padx=8)
        self.status=tk.Label(root,bg=BG,fg='#93c5fd',font=('sans-serif',12));self.status.pack(anchor='w',padx=20)
        self.panel=tk.Frame(root,bg=BG);self.panel.pack(fill='both',expand=True,padx=20,pady=15)
        self.foot=tk.Label(root,bg=BG,fg='#fcd34d',font=('sans-serif',11),wraplength=1100,justify='left');self.foot.pack(side='bottom',fill='x',padx=20,pady=8)
        self.panel.pack_forget();self.panel.pack(fill='both',expand=True,padx=20,pady=10)
        self.render()
    def open_standalone(self):
        App(tk.Toplevel(self.root))

    def close(self):
        if self.battle_window and self.battle_window.winfo_exists():self.battle_window.destroy()
        self.bridge.close();self.root.destroy()
    def label(self,text,size=13,parent=None,color=FG):
        w=tk.Label(parent or self.panel,text=text,bg=BG,fg=color,font=('sans-serif',size),justify='left',wraplength=1110,anchor='w');w.pack(anchor='w',pady=5);return w
    def button(self,text,command,parent=None,disabled=False):
        w=tk.Button(parent or self.panel,text=text,command=command,font=('sans-serif',12),padx=12,pady=7,state='disabled' if disabled else 'normal');w.pack(anchor='w',pady=5);return w
    def act(self,action,*args):
        self.data=self.bridge.call(op='journey',action=action,args=list(args),presentation=action=='begin')
        self.notice='' if self.data['ok'] else self.data.get('error','失敗');self.render()
    def qa_fixture(self,name):
        self.data=self.bridge.call(op='qa_fixture',name=name);self.selected=None
        self.notice=self.data['qa']['label'];self.render()

    def restart(self):
        self.data=self.bridge.call(op='journey_start');self.selected=None;self.kit.set('medicine');self.formation.set('convoy');self.notice='新しい旅を開始しました';self.render()
    def export(self):
        result=self.bridge.call(op='export')
        path=filedialog.asksaveasfilename(parent=self.root,title='プレイログを保存',defaultextension='.json',initialdir=str(Path(__file__).resolve().parent),initialfile='5525-native-journey-'+datetime.now().strftime('%Y%m%d-%H%M%S')+'.json',filetypes=[('JSON','*.json')])
        if not path:self.notice='ログ保存を取り消しました';self.foot.config(text=self.notice);return
        try:
            Path(path).write_text(json.dumps(result['data'],ensure_ascii=False,indent=2),encoding='utf-8');self.notice='ログ保存完了: '+path
        except OSError as e:self.notice='ログを保存できませんでした: '+str(e)
        self.foot.config(text=self.notice)
    def party_text(self):
        j=self.data['journey'];members=j.get('party') or [dict(u,hp=u['max']) for u in self.data['roster'] if u['id'] in j['selected']]
        return '\n'.join(f'{u["name"]}［{u["role"]}］ HP {u["hp"]}/{u["max"]} MP {u["mp"]}'+(' 戦闘不能' if u['hp']<=0 else '') for u in members)
    def choose(self,uid):
        ids=self.data['journey']['selected'][:]
        if uid in ids:ids.remove(uid)
        else:ids.append(uid)
        self.act('select',ids)
    def deadline(self,choice):
        d=self.bridge.call(op='journey',action='forecast',args=[choice]);f=d['forecast'];j=d['journey']
        action='rest' if choice=='rest' else 'travel';args=[] if choice=='rest' else [choice]
        if not f['late']:self.act(action,*args);return
        self.bridge.call(op='record',type='deadline.prompted',details={'choice':choice,'forecast':f})
        dialog=tk.Toplevel(self.root);dialog.title('配達期限の確認');dialog.geometry('550x280+300+220');dialog.transient(self.root);dialog.grab_set();dialog.configure(bg=BG)
        tk.Label(dialog,text=f'配達期限を超過します\n最短の配達: 出発から{f["hours"]}時間後 / 納期 {j["job"]["deadline"]}時間\n超過 {f["over"]}時間 / 報酬65%: {int(j["job"]["reward"]*.65)}G\nこのまま進みますか？',bg=BG,fg=FG,font=('sans-serif',15),pady=25).pack()
        def cancel():
            self.bridge.call(op='record',type='deadline.cancelled',details={'choice':choice});dialog.destroy();self.notice='期限警告を取り消しました。時間・状態は変わりません';self.render()
        def proceed():
            self.bridge.call(op='record',type='deadline.confirmed',details={'choice':choice});dialog.destroy();self.act(action,*args)
        tk.Button(dialog,text='戻る / Esc',command=cancel,font=('sans-serif',13)).pack(side='left',padx=65)
        tk.Button(dialog,text='このまま進む',command=proceed,font=('sans-serif',13)).pack(side='right',padx=65)
        dialog.bind('<Escape>',lambda _:cancel());dialog.protocol('WM_DELETE_WINDOW',cancel)
    def render(self):
        for w in self.panel.winfo_children():w.destroy()
        j=self.data['journey'];p=j['phase'];self.foot.config(text=self.notice)
        self.status.config(text=f'{j["job"]["cargo"]} / {j["hours"]}時間経過・納期{j["job"]["deadline"]}時間 / {j["stage"]}/2区間' if j['job'] else '今日、誰の荷物を運ぶ？')
        if self.data.get('qa'):self.status.config(text=self.data['qa']['label']+' / '+self.status.cget('text'))
        if p=='jobs':
            for job in self.data['jobs']:
                self.label(job['name'],19);self.label(f'{job["client"]} / {job["text"]}\n荷物 {job["weight"]}/8枠 / 納期 {job["deadline"]}時間 / 報酬 {job["reward"]}G')
                self.button('この依頼を引き受ける',lambda id=job['id']:self.act('accept',id))
            self.label('以下は境界画面を確認するためのQA局面です。通常プレイではありません。',11,color='#fcd34d')
            self.button('QA: 納期内配達直前（実戦2回から生成）',lambda:self.qa_fixture('ontime_delivery'))
            self.button('QA: ポーター失敗結果（実戦から生成）',lambda:self.qa_fixture('failed_result'))
        elif p=='prepare':
            self.label(f'護送隊を編成 {len(j["selected"])}/5人（候補11人・受注時にポーター最低1人）',18)
            grid=tk.Frame(self.panel,bg=BG);grid.pack(anchor='w')
            for n,u in enumerate(self.data['roster']):
                checked=u['id'] in j['selected'];v=tk.BooleanVar(value=checked)
                cb=tk.Checkbutton(grid,text=f'{u["name"]} / {u["role"]}\nHP{u["max"]} MP{u["mp"]} ATK{u["atk"]} AGI{u["agi"]}',variable=v,command=lambda id=u['id']:self.choose(id),bg=BG,fg=FG,selectcolor='#334155',activebackground=BG,activeforeground=FG,font=('sans-serif',11),anchor='w',width=27,state='normal' if checked or len(j['selected'])<5 else 'disabled')
                cb.var=v;cb.grid(row=n//3,column=n%3,padx=5,pady=5,sticky='w')
            self.label('ポーターを1人でも失うと失敗。槌戦士: スタンプ / 弓手: スナイプ（仮仕様）',11)
            self.label(f'積載: {j["job"]["weight"]}+補給2 = {j["job"]["weight"]+2}/8枠')
            opts=tk.Frame(self.panel,bg=BG);opts.pack(anchor='w')
            for text,value in [('救護セット: 回復薬3個','medicine'),('魔力セット: 薬1個・初期MP+2','ether')]:
                tk.Radiobutton(opts,text=text,variable=self.kit,value=value,bg=BG,fg=FG,selectcolor='#334155').pack(side='left',padx=5)
            opts2=tk.Frame(self.panel,bg=BG);opts2.pack(anchor='w')
            for text,value in [('基本配置','convoy'),('切り込み配置','flank')]:
                tk.Radiobutton(opts2,text=text,variable=self.formation,value=value,bg=BG,fg=FG,selectcolor='#334155').pack(side='left',padx=5)
            populated=bool(j['selected'])
            self.label('この編成で出発できます' if populated else 'パーティーを最低1人選んでください',12,color='#86efac' if populated else '#fca5a5')
            self.button('この編成で出発',lambda:self.act('depart',self.kit.get(),self.formation.get()),disabled=not populated)
        elif p=='road':
            self.label(f'第{j["stage"]+1}区間: 次の道を選ぶ',20);self.label(self.party_text())
            self.button(f'峠の近道: 2時間 / 敵{3 if j["stage"]==0 else 4}人',lambda:self.deadline('short'))
            self.button(f'川沿いの道: 4時間 / 敵{2 if j["stage"]==0 else 3}人',lambda:self.deadline('safe'))
            self.label(f'回復薬 {j["potions"]}個 / 納期まで {j["job"]["deadline"]-j["hours"]}時間')
        elif p=='deployment':self.deployment()
        elif p=='battle':
            self.label('戦闘中: 別のネイティブ戦闘ウィンドウで操作します',19)
            self.button('戦闘画面を開く / 再開',self.open_battle)
        elif p=='camp':
            self.label('街道の野営地',20);self.label(self.party_text());self.label(f'回復薬 {j["potions"]}個。残り一区間、最短あと3時間')
            self.button('休息済み' if j['rested'] else '2時間休む: HP+60 / MP+2',lambda:self.deadline('rest'),disabled=j['rested'])
            self.button('先へ進む',lambda:self.act('onward'))
        elif p=='delivery':
            self.label(f'{j["job"]["client"]}が待っている',20);self.label(f'{j["job"]["cargo"]} / 所要 {j["hours"]}時間')
            self.button('荷物を渡す',lambda:self.act('deliver'))
        elif p=='result':
            if j['outcome']!='failed' and not j.get('completionSeen'):
                self.label('任務達成',26,color='#86efac');self.label(j['job']['name'],20)
                self.label(('木箱を受け取ったイネスは、中身を確かめて大きく息をついた。\n診療所の扉が開き、待っていた人たちが顔を上げる。' if j['job']['id']=='medicine' else '包みをほどいたトマが、部品を両手で持ち上げた。\n水車小屋の仲間たちにも、ようやく笑顔が戻る。'),13)
                self.label(('「待っていたよ。さあ、薬を届けに行こう。\nここまで運んでくれて、本当にありがとう」' if j['outcome']=='late' else '「間に合った……！ これで診療を始められる。\nここまで運んでくれて、本当にありがとう」') if j['job']['id']=='medicine' else '「これだ。この部品があれば、また水車を回せる。\n重かっただろう。よく届けてくれたね」',16)
                portraits=tk.Frame(self.panel,bg=BG);portraits.pack(anchor='w',pady=5)
                for u in j['party']:
                    if u['image'] in self.images:tk.Label(portraits,image=self.images[u['image']],text=u['name'],compound='top',bg=BG,fg=FG,padx=12).pack(side='left')
                self.label(self.party_text());self.label(f'{j["hours"]}時間 / '+('納期内に達成' if j['outcome']=='success' else '遅配での達成'))
                self.button('報酬と成長を確認する',lambda:self.act('rewards'))
            else:
                self.label('クエスト失敗' if j['outcome']=='failed' else '報酬と成長',22)
                self.label(j.get('failureReason',''));self.label(f'報酬 {j["gold"]}G / 経験値 {j["xp"]}/100 / 隊Lv.{j["level"]}',19)
                self.label('Lv.2: ニカの奇襲が前方限定から左右へ成長' if j['level']==2 else 'Lv.2で奇襲が前方限定から左右へ成長')
                self.button('別の選択でもう一度',self.restart)
        if p not in ('deployment','prepare') and j['history']:self.label('\n'.join(j['history'][-5:]),11,color='#94a3b8')
    def deployment(self):
        s=self.data['state'];allies=[u for u in s['units'] if u['side']=='ally']
        if self.selected not in [u['id'] for u in allies if u['hp']>0]:self.selected=next((u['id'] for u in allies if u['hp']>0),None)
        self.label('敵を見て、隊を配置する',20);self.label('味方ボタン → マスをクリックで移動/交換。味方をドラッグでも配置できます。時間・HP・MP消費なし',12)
        row=tk.Frame(self.panel,bg=BG);row.pack(anchor='w')
        for u in allies:
            b=tk.Button(row,text=f'{u["name"]}\nHP{u["hp"]} MP{u["mp"]}',command=lambda id=u['id']:self.select_deploy(id),font=('sans-serif',11),relief='sunken' if u['id']==self.selected else 'raised',state='normal' if u['hp']>0 else 'disabled');b.pack(side='left',padx=5,pady=5)
        a=next((u for u in allies if u['id']==self.selected),None)
        self.label(f'選択: {a["name"] if a else "なし"} / 護送陣 {"成立" if self.data["formed"]["ally"] else "未成立"} / 金枠: 陣形 / 青: 攻撃範囲 / 緑枠: 奇襲対象',12)
        c=tk.Canvas(self.panel,width=1000,height=350,bg=BG,highlightthickness=0);c.pack(anchor='w');self.deploy_canvas=c
        for p in range(50):
            x,y=(p%10)*100,(p//10)*70
            fill='#253b51' if p%10<5 else '#492f41'
            if a and p in self.data.get('deployment',{}).get(a['id'],{}).get('ranges',[]):fill='#315b73'
            c.create_rectangle(x+2,y+2,x+98,y+68,fill=fill,outline='#fbbf24' if p in [24,13,33,25,16,36] else '',width=3)
            c.create_text(x+18,y+12,text=f'{p%10+1},{p//10+1}',fill='#94a3b8',font=('sans-serif',9))
            if a and p in self.data.get('deployment',{}).get(a['id'],{}).get('ambush',[]):c.create_rectangle(x+6,y+6,x+94,y+64,outline='#4ade80',width=4)
        for u in s['units']:
            if u['hp']<=0:continue
            x,y=u['pos']%10*100+50,u['pos']//10*70+37
            portrait = resolve_portrait(self.images, u)
            if portrait is not None:c.create_image(x,y-7,image=portrait)
            if u['id']==self.selected:c.create_rectangle(x-34,y-30,x+34,y+31,outline='#fff',width=2)
            c.create_text(x,y+11,text=u['name'] if len(u['name'])<6 else u['icon'],fill='#93c5fd' if u['side']=='ally' else '#fda4af',font=('sans-serif',10,'bold'))
            c.create_text(x,y+25,text=f'HP{u["hp"]} MP{u["mp"]}',fill='#f8fafc',font=('sans-serif',9))
        c.bind('<ButtonPress-1>',self.drag_begin);c.bind('<ButtonRelease-1>',self.drop)
        buttons=tk.Frame(self.panel,bg=BG);buttons.pack(anchor='w')
        self.button('初期配置に戻す',lambda:self.act('deployment_reset'),buttons)
        self.button('この配置で戦闘開始',self.begin,buttons)
    def select_deploy(self,uid):self.selected=uid;self.bridge.call(op='record',type='deployment.selected',details={'id':uid});self.render()
    def drag_begin(self,e):
        p=e.y//70*10+e.x//100
        u=next((u for u in self.data['state']['units'] if u['pos']==p and u['hp']>0 and u['side']=='ally'),None)
        self.drag_start=(e.x,e.y,u['id'] if u else None)
    def drop(self,e):
        if not (0<=e.x<1000 and 0<=e.y<350):self.notice='盤面外には配置できません';self.foot.config(text=self.notice);return
        x,y,uid=self.drag_start or (e.x,e.y,None)
        is_drag=abs(e.x-x)+abs(e.y-y)>8
        target=e.y//70*10+e.x//100
        chosen=uid if is_drag and uid else self.selected
        if is_drag and not uid:return
        self.data=self.bridge.call(op='journey',action='deploy',args=[chosen,target]);self.selected=chosen
        self.notice='配置しました（消費なし）' if self.data['ok'] else '無効な配置です。味方陣のマスを選んでください';self.render()
    def begin(self):
        self.act('begin')
        if self.data['ok']:self.open_battle(initial_voice_events=self.data.pop('voiceEvents', []))
    def open_battle(self, initial_voice_events=None):
        if self.battle_window and self.battle_window.winfo_exists():self.battle_window.lift();return
        self.battle_window=tk.Toplevel(self.root)
        App(self.battle_window,bridge=self.bridge,on_finish=lambda:self.act('finish'),on_close=self.refresh,
            initial_voice_events=initial_voice_events)
    def refresh(self):self.data=self.bridge.call(op='view');self.render()

if __name__=='__main__':
    import sys
    root=tk.Tk()
    if '--legacy' in sys.argv:
        JourneyApp(root)
    else:
        from campaign_app import CampaignApp
        CampaignApp(root)
    root.mainloop()
