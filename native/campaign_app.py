"""Replayable native campaign: towns, trade-ins, travel and local save files.

The JavaScript campaign owns every gameplay mutation.  This shell only selects
actions and reuses JourneyApp's deployment board and App's real battle controls.
"""
from datetime import datetime
import json
import os
from pathlib import Path
import tempfile

from tk_bootstrap import prepare_tk
prepare_tk()
import tkinter as tk
from tkinter import filedialog, messagebox

from app import App, BASE, Bridge
from journey_app import JourneyApp
from music import MusicPlayer


BG = '#111827'
FG = '#e2e8f0'
MUTED = '#94a3b8'
CARD = '#1e293b'


def atomic_json_write(path, data):
    """Replace only after a complete, flushed JSON file exists beside the target."""
    path = Path(path)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile('w', encoding='utf-8',
                                         dir=path.parent, prefix='.' + path.name + '.',
                                         suffix='.tmp', delete=False) as handle:
            temporary = Path(handle.name)
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def campaign_formation_info(data):
    """Explain existing side-wide factors; never infer formation from a preview."""
    lines = ['陣形条件: 金枠3マスを同陣営の生存者で埋める']
    for side, name, slots in [('ally', '味方', (24, 13, 33)),
                              ('enemy', '敵', (25, 16, 36))]:
        occupied = sum(any(u['side'] == side and u['hp'] > 0 and u['pos'] == p
                           for u in data['state']['units']) for p in slots)
        formed = data['formed'][side]
        boosted = formed and data.get('boosted', {}).get(side, False)
        status = '強化ON' if boosted else 'ON' if formed else 'OFF'
        attack, received = ('1.75', '0.65') if boosted else ('1.5', '0.75') if formed else ('1', '1')
        lines.append(f'{name}: {occupied}/3 {status} 攻撃×{attack} / 被ダメ×{received}')
    lines += ['通常ON: 攻撃×1.5 / 被ダメ×0.75',
              '強化ON: 攻撃×1.75 / 被ダメ×0.65',
              '※陣営全体への補正。防御・かばう・丸めは別']
    if data.get('trial'):
        lines.insert(0, data['trial'].get('notice', '木人: 反撃なし / 陣形OFF同士なら基礎ATK比較'))
    return lines


class CampaignBattleApp(App):
    """Explicit opt-in retreat; ordinary battle/window-close behavior is unchanged."""
    def __init__(self, *args, **kwargs):
        self.retreat_pending = False
        self.retreat_closed = False
        super().__init__(*args, **kwargs)
        self.info.config(height=25)

    def formation_info(self):
        return campaign_formation_info(self.data)

    def draw(self):
        super().draw()
        active = not self.data['state']['result']
        self.return_button.config(
            text='撤退して出発前へ戻る' if active else '戦闘を終えて街道へ',
            command=self.ask_retreat if active else self.finish,
            state='disabled' if self.retreat_pending or self.porter_confirmation is not None else 'normal')

    def ask_retreat(self):
        if (self.retreat_pending or self.retreat_closed
                or self.porter_confirmation is not None or self.data['state']['result']):
            return
        # The native modal owns keyboard/mouse input. NO is the default, and
        # Escape/window close cancel. Keep an existing move preview on cancel.
        expected = self.data['state']
        self.retreat_pending = True
        try:
            accepted = messagebox.askyesno(
                '戦闘から撤退',
                '戦闘をやめて、受注／出発前の状態へ戻りますか？\n'
                '今回の旅の報酬・成長は取り消され、所持金・装備・HP・MP・道具は復元されます。\n'
                '追加のペナルティはありません。',
                parent=self.root, default=messagebox.NO)
            if not accepted or self.retreat_closed:
                return
            current = self.bridge.call(op='view')
            if current.get('state') != expected or current.get('trial'):
                # Another window may have loaded a save or finished the battle.
                # Never apply an old confirmation to the replacement state.
                self.close()
                return
            result = self.bridge.call(op='campaign', action='retreat', args=[])
            if result.get('ok'):
                self.pending = self.preview = None
                self.close()
            else:
                self.message = result.get('error', '現在は撤退できません')
        finally:
            self.retreat_pending = False
            if not self.retreat_closed:
                self.draw()

    def close(self):
        self.retreat_closed = True
        super().close()


class TrialBattleApp(App):
    """The normal battle controls, with an always-available exit from try-on."""
    def __init__(self, root, bridge, on_return, images=None, music=None):
        self.on_return = on_return
        self.returned = False
        super().__init__(root, bridge=bridge, on_finish=self.return_to_shop, images=images, music=music)
        self.info.config(height=26)
        root.title('5525 / 購入前の木人試用')
        self.return_button.config(text='試用を終えてお店へ戻る', command=self.return_to_shop,
                                  state='normal')
        self.message = '試着用の独立した木人戦です。試すだけでは購入されず、所持金・装備・HP・MP・アイテムは変わりません。'
        self.draw()

    def formation_info(self):
        return campaign_formation_info(self.data)

    def draw(self):
        super().draw()
        if hasattr(self, 'return_button'):
            self.return_button.config(state='normal', text='試用を終えてお店へ戻る')

    def return_to_shop(self):
        if self.returned:
            return
        self.returned = True
        self.root.destroy()
        self.on_return()

    def finish(self):
        self.return_to_shop()

    def close(self):
        self.return_to_shop()


class CampaignApp(JourneyApp):
    def __init__(self, root, bridge=None):
        self.root = root
        self.music = MusicPlayer(root)
        self.bridge = bridge or Bridge()
        self.images = {}
        for path in (BASE / 'assets').rglob('*.png'):
            image = tk.PhotoImage(master=root, file=str(path))
            self.images[path.relative_to(BASE / 'assets').as_posix()] = image.subsample(
                max(1, image.width() // 48))
        self.battle_window = None
        self.selected = None
        self.drag_start = None
        self.notice = ''
        self.page = 'board'
        self.shop_uid = None
        self.item_uid = None
        self.destination = None
        self.trial_purchase = None
        self.inn_pending = False
        self.closed = False
        self._scroll_sync_job = None
        self._scroll_reset_pending = True
        self._render_key = None
        self.formation = tk.StringVar(master=root, value='convoy')
        self.kit = tk.StringVar(master=root, value='medicine')
        self.data = self.bridge.call(op='campaign_start')

        root.title('5525 / GoGo To Go — Native Campaign')
        root.geometry('1180x850+20+20')
        root.minsize(1080, 700)
        root.configure(bg=BG)
        root.protocol('WM_DELETE_WINDOW', self.close)
        header = tk.Frame(root, bg=BG)
        header.pack(fill='x', padx=20, pady=(12, 4))
        tk.Label(header, text='5525 / COURIER’S ROAD', bg=BG, fg=FG,
                 font=('sans-serif', 22, 'bold')).pack(side='left')
        tools = tk.Frame(root, bg=BG)
        tools.pack(fill='x', padx=20, pady=(0, 6))
        self.music.control(tools)
        for title, command in [('進行を保存', self.save), ('進行を読込', self.load),
                               ('プレイログ保存', self.export), ('新しく始める', self.restart)]:
            tk.Button(tools, text=title, command=command, padx=8, pady=4).pack(side='left', padx=(0, 8))
        tk.Label(tools, text='数値・商品・道の接続は試作値', bg=BG, fg=MUTED,
                 font=('sans-serif', 10)).pack(side='right')
        self.status = tk.Label(root, bg=BG, fg='#93c5fd', font=('sans-serif', 12),
                               anchor='w', justify='left', wraplength=1100)
        self.status.pack(fill='x', padx=20, pady=4)
        self.foot = tk.Label(root, bg=BG, fg='#fcd34d', font=('sans-serif', 11),
                             wraplength=1100, justify='left', anchor='w')
        self.foot.pack(side='bottom', fill='x', padx=20, pady=8)
        body = tk.Frame(root, bg=BG)
        body.pack(fill='both', expand=True, padx=20, pady=8)
        self.scroll = tk.Canvas(body, bg=BG, highlightthickness=0)
        scrollbar = tk.Scrollbar(body, orient='vertical', command=self.scroll.yview)
        scrollbar.pack(side='right', fill='y')
        self.scroll.pack(side='left', fill='both', expand=True)
        self.scroll.configure(yscrollcommand=scrollbar.set)
        self.panel = tk.Frame(self.scroll, bg=BG)
        self.panel_id = self.scroll.create_window((0, 0), window=self.panel, anchor='nw')
        self.panel.bind('<Configure>', self._queue_scroll_sync)
        self.scroll.bind('<Configure>', self._resize_scroll)
        root.bind('<MouseWheel>', self.scroll_wheel, add='+')
        root.bind('<Button-4>', lambda _: self.scroll.yview_scroll(-3, 'units'), add='+')
        root.bind('<Button-5>', lambda _: self.scroll.yview_scroll(3, 'units'), add='+')
        self.render()

    def scroll_wheel(self, event):
        if event.widget.winfo_toplevel() == self.root:
            self.scroll.yview_scroll(-1 if event.delta > 0 else 1, 'units')

    def _resize_scroll(self, event):
        self.scroll.itemconfigure(self.panel_id, width=event.width)
        self._queue_scroll_sync()

    def _queue_scroll_sync(self, event=None, reset=False):
        """Wait for pack/grid geometry before restoring a valid canvas origin."""
        self._scroll_reset_pending = self._scroll_reset_pending or reset
        if self._scroll_sync_job is None:
            self._scroll_sync_job = self.root.after_idle(self._sync_scroll_region)

    def _sync_scroll_region(self):
        self._scroll_sync_job = None
        previous_top = self.scroll.canvasy(0)
        width = max(1, self.scroll.winfo_width())
        viewport = max(1, self.scroll.winfo_height())
        height = max(viewport, self.panel.winfo_reqheight())
        # A region shorter than the viewport can leave a confined Tk canvas at
        # a negative origin when a long shop page is replaced by a short board.
        self.scroll.coords(self.panel_id, 0, 0)
        self.scroll.configure(scrollregion=(0, 0, width, height))
        top = 0 if self._scroll_reset_pending else min(max(0, previous_top), height - viewport)
        self.scroll.xview_moveto(0)
        self.scroll.yview_moveto(top / height)
        self._scroll_reset_pending = False

    @property
    def campaign(self):
        return self.data.get('campaign') or {}

    def label(self, text, size=12, parent=None, color=FG):
        target = parent or self.panel
        wraplength = getattr(target, 'text_width', 1030)
        if target.winfo_toplevel() != self.root:
            wraplength = min(wraplength, 710)
        widget = tk.Label(target, text=text, bg=target.cget('bg'), fg=color,
                          font=('sans-serif', size), justify='left', wraplength=wraplength, anchor='w')
        widget.pack(anchor='w', pady=4)
        return widget

    def button(self, text, command, parent=None, disabled=False):
        widget = tk.Button(parent or self.panel, text=text, command=command,
                           font=('sans-serif', 11), padx=10, pady=6,
                           state='disabled' if disabled else 'normal')
        widget.pack(anchor='w', pady=4)
        return widget

    def row_button(self, parent, text, command, disabled=False):
        widget = tk.Button(parent, text=text, command=command, font=('sans-serif', 11),
                           padx=10, pady=6, state='disabled' if disabled else 'normal')
        widget.pack(side='left', padx=(0, 8), pady=4)
        return widget

    def card(self, parent=None):
        frame = tk.Frame(parent or self.panel, bg=CARD, padx=14, pady=9)
        frame.pack(fill='x', pady=6)
        return frame

    def request(self, **request):
        try:
            result = self.bridge.call(**request)
        except (OSError, RuntimeError, ValueError) as error:
            self.notice = '処理できませんでした: ' + str(error)
            self.foot.config(text=self.notice)
            return {'ok': False, 'error': self.notice}
        if result.get('campaign') is not None:
            self.data = result
        if not result.get('ok', False):
            self.notice = result.get('error') or '現在の状態では実行できません'
        return result

    def act(self, action, *args):
        self.notice = ''
        result = self.request(op='campaign', action=action, args=list(args))
        if result.get('ok'):
            self.selected = None if action in ('depart', 'arrive', 'acknowledge') else self.selected
        self.render()
        return result

    def refresh(self):
        self.request(op='view')
        self.render()

    def set_page(self, page):
        self.page = page
        self.notice = ''
        self.render(reset_scroll=True)

    def close_battle(self):
        if self.battle_window and self.battle_window.winfo_exists():
            self.battle_window.destroy()
        self.battle_window = None

    def close(self):
        self.closed = True
        if self._scroll_sync_job is not None:
            self.root.after_cancel(self._scroll_sync_job)
            self._scroll_sync_job = None
        self.close_battle()
        self.bridge.close()
        self.root.destroy()

    def restart(self):
        if not messagebox.askyesno('新しく始める', '現在の未保存の進行を終了し、新しい旅を始めますか？', parent=self.root):
            return
        result = self.request(op='campaign_start')
        if result.get('ok'):
            self.close_battle()
            self.page = 'board'
            self.destination = None
            self.trial_purchase = None
            self.notice = '新しい旅を始めました'
        self.render(reset_scroll=bool(result.get('ok')))

    def save(self):
        result = self.request(op='campaign_save')
        if not result.get('ok'):
            self.render()
            return
        path = filedialog.asksaveasfilename(parent=self.root, title='進行をローカルJSONに保存',
                    defaultextension='.json', initialdir=str(BASE),
                    initialfile='5525-save-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.json',
                    filetypes=[('5525進行JSON', '*.json')])
        if not path:
            self.notice = '進行保存を取り消しました'
        else:
            try:
                data = result['data']
                if isinstance(data, str):
                    data = json.loads(data)
                atomic_json_write(path, data)
                self.notice = '進行を保存しました: ' + str(path)
            except (OSError, ValueError, KeyError, TypeError) as error:
                self.notice = '進行を保存できませんでした: ' + str(error)
        self.foot.config(text=self.notice)

    def load(self):
        path = filedialog.askopenfilename(parent=self.root, title='進行JSONを読み込む',
                    initialdir=str(BASE), filetypes=[('5525進行JSON', '*.json')])
        if not path:
            self.notice = '進行読込を取り消しました'
            self.foot.config(text=self.notice)
            return
        if not messagebox.askyesno('進行を読み込む', '現在の未保存の進行を、選んだファイルの進行に置き換えますか？', parent=self.root):
            return
        try:
            if Path(path).stat().st_size > 8 * 1024 * 1024:
                raise ValueError('ファイルが大きすぎます（上限8MiB）')
            data = json.loads(Path(path).read_text(encoding='utf-8-sig'))
        except (OSError, ValueError) as error:
            self.notice = '進行を読み込めませんでした: ' + str(error)
            self.foot.config(text=self.notice)
            return
        result = self.request(op='campaign_load', data=data)
        if result.get('ok'):
            self.close_battle()
            self.page = 'board'
            self.destination = None
            self.selected = None
            self.trial_purchase = None
            self.notice = '進行を読み込みました: ' + Path(path).name
        self.render(reset_scroll=bool(result.get('ok')))

    def export(self):
        result = self.request(op='export')
        if not result.get('ok'):
            self.render()
            return
        path = filedialog.asksaveasfilename(parent=self.root, title='プレイログを保存（進行セーブとは別）',
                    defaultextension='.json', initialdir=str(BASE),
                    initialfile='5525-campaign-log-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.json',
                    filetypes=[('JSON', '*.json')])
        if not path:
            self.notice = 'ログ保存を取り消しました'
        else:
            try:
                atomic_json_write(path, result['data'])
                self.notice = 'プレイログを保存しました: ' + str(path)
            except (OSError, ValueError, KeyError, TypeError) as error:
                self.notice = 'ログを保存できませんでした: ' + str(error)
        self.foot.config(text=self.notice)

    def drop(self, event):
        if not (0 <= event.x < 1000 and 0 <= event.y < 350):
            self.notice = '盤面外には配置できません'
            self.foot.config(text=self.notice)
            return
        x, y, uid = self.drag_start or (event.x, event.y, None)
        dragging = abs(event.x - x) + abs(event.y - y) > 8
        if dragging and not uid:
            return
        chosen = uid if dragging and uid else self.selected
        result = self.request(op='campaign', action='deploy',
                              args=[chosen, event.y // 70 * 10 + event.x // 100])
        self.selected = chosen
        self.notice = '配置しました（消費なし）' if result.get('ok') else result.get('error', '味方陣のマスを選んでください')
        self.render()

    def begin(self):
        result = self.act('begin')
        if result.get('ok'):
            self.open_battle(initial_voice_events=result.pop('voiceEvents', []))

    def open_battle(self, initial_voice_events=None):
        if self.battle_window and self.battle_window.winfo_exists():
            self.battle_window.lift()
            return
        self.battle_window = tk.Toplevel(self.root)
        CampaignBattleApp(self.battle_window, bridge=self.bridge,
            on_finish=lambda: self.act('finishBattle'), on_close=self.refresh, images=self.images,
            initial_voice_events=initial_voice_events, music=getattr(self, 'music', None))

    def start_trial(self, uid, gear_id, dialog=None):
        if dialog:
            dialog.destroy()
        result = self.request(op='campaign', action='trial', args=[uid, gear_id])
        if not result.get('ok'):
            self.render()
            return
        self.trial_purchase = (uid, gear_id)
        self.close_battle()
        self.battle_window = tk.Toplevel(self.root)
        TrialBattleApp(self.battle_window, bridge=self.bridge, on_return=self.end_trial, images=self.images,
                       music=self.music)
        self.notice = '木人で装備を試用中。終了すると購入前の画面へ戻ります'
        self.foot.config(text=self.notice)

    def end_trial(self):
        purchase = self.trial_purchase
        result = self.request(op='campaign', action='endTrial', args=[])
        self.battle_window = None
        if result.get('ok'):
            self.trial_purchase = None
            self.notice = '試用を終了しました。所持金・装備・HP・MP・アイテムは試用前のままです'
            self.render()
            if purchase:
                self.preview_gear(*purchase)
        else:
            self.render()

    def roster(self):
        return self.campaign.get('roster') or self.data.get('roster') or []

    def towns(self):
        return self.campaign.get('locations') or []

    def town_id(self):
        return self.campaign.get('location')

    def town_name(self, town_id):
        return next((town['name'] for town in self.towns() if town['id'] == town_id), town_id or '')

    def selected_ids(self):
        return self.campaign.get('selected') or []

    def party_text(self):
        journey = self.data.get('journey') or {}
        party = journey.get('party') or [member for member in self.roster() if member['id'] in self.selected_ids()]
        return '\n'.join(f'{member["name"]}［{member.get("role", "")}］ '
                         f'HP {member.get("hp", member.get("max", 0))}/{member.get("max", 0)} '
                         f'MP {member.get("mp", 0)}/{member.get("maxMp", member.get("mp", 0))}'
                         + (' 戦闘不能' if member.get('hp', 1) <= 0 else '') for member in party)

    def choose(self, uid):
        ids = self.selected_ids()[:]
        if uid in ids:
            ids.remove(uid)
        else:
            ids.append(uid)
        if not any(member['id'] in ids and member.get('job') == 'porter' for member in self.roster()):
            self.notice = 'ポーターは最低1人必要です。別のポーターを加えてから外してください'
            self.render()
            return
        self.act('select', ids)

    def render(self, reset_scroll=False):
        if getattr(self, 'music', None):self.music.sync(self.data)
        for widget in self.panel.winfo_children():
            widget.destroy()
        campaign = self.campaign
        journey = self.data.get('journey') or {}
        phase = campaign.get('phase', journey.get('phase', 'town'))
        render_key = (phase, self.town_id(), self.page if phase == 'town' else None)
        reset_scroll = reset_scroll or render_key != self._render_key
        self._render_key = render_key
        self.foot.config(text=self.notice)
        display_town = journey.get('destination') if phase == 'arrival' else self.town_id()
        self.status.config(text=f'{self.town_name(display_town)}  |  所持金 {campaign.get("gold", 0)}G'
                               f'  |  経験値 {campaign.get("xp", 0)} / 隊Lv.{campaign.get("level", 1)}'
                               f'  |  編成 {len(self.selected_ids())}/5人 / 累計{campaign.get("hours", 0)}時間')
        if not campaign:
            self.label(self.data.get('error', 'キャンペーンを開始できませんでした'), color='#fca5a5')
            self._queue_scroll_sync(reset=reset_scroll)
            return
        if phase == 'town':
            self.render_town()
        elif phase == 'deployment':
            self.deployment()
        elif phase == 'battle':
            self.label('戦闘中', 22)
            self.label('別の戦闘ウィンドウで操作します。閉じても途中から再開できます。')
            self.button('戦闘画面を開く / 再開', self.open_battle)
        elif phase in ('road', 'camp', 'delivery', 'arrival'):
            self.render_road(phase, journey)
        elif phase == 'result':
            self.render_result()
        elif phase == 'prepare':
            self.render_map()
        else:
            self.label('現在の状態: ' + str(phase))
            self.button('画面を更新', self.refresh)
        self._queue_scroll_sync(reset=reset_scroll)

    def render_town(self):
        town = next((town for town in self.towns() if town['id'] == self.town_id()), {})
        self.label(self.town_name(self.town_id()), 22)
        self.label(town.get('description', town.get('text', '掲示板で依頼を選ぶか、依頼を受けずに次の拠点へ移動できます。')), color=MUTED)
        tabs = tk.Frame(self.panel, bg=BG)
        tabs.pack(fill='x', pady=(4, 9))
        pages = [('board', '掲示板'), ('map', '地図・出発'), ('party', '仲間・装備'), ('shop', 'お店・道具')]
        if 'inn' in town.get('facilities', []):
            pages.append(('inn', '宿屋'))
        for key, name in pages:
            button = self.row_button(tabs, name, lambda page=key: self.set_page(page))
            button.config(relief='sunken' if key == self.page else 'raised')
        {'board': self.render_board, 'map': self.render_map,
         'party': self.render_party, 'shop': self.render_shop, 'inn': self.render_inn}.get(self.page, self.render_board)()

    def render_inn(self):
        quote = self.campaign.get('inn') or {}
        if not quote.get('available'):
            self.label('宿屋はアスタリスで利用できます。')
            return
        price = quote['price']
        self.label(f'宿屋 / パーティ全員で{price}G（仮料金）', 20)
        self.label('編成中の全員のHP・MPを上限まで回復します。戦闘不能の仲間も回復します。')
        self.label('控えの仲間は対象外。時間は経過しません（試作仕様）。', color=MUTED)
        self.label(self.party_text(), 12)
        if not quote.get('needsRecovery'):
            self.label('全員が全回復しています。料金はかかりません。', color='#86efac')
        elif not quote.get('affordable'):
            self.label(f'所持金が足りません。宿泊には{price}G必要です。', color='#fca5a5')
        self.button(f'{price}Gで宿泊する / 確認', self.stay_inn,
                    disabled=not quote.get('needsRecovery') or not quote.get('affordable'))

    def stay_inn(self):
        if self.inn_pending or self.closed:
            return
        quote = self.campaign.get('inn') or {}
        if not all(quote.get(key) for key in ('available', 'affordable', 'needsRecovery')):
            return
        expected = self.campaign
        self.inn_pending = True
        try:
            accepted = messagebox.askyesno('宿屋で休む',
                f'パーティ全員で{quote["price"]}Gを支払い、編成中の全員のHP・MPを全回復しますか？\n'
                '戦闘不能も回復します。控えの仲間は対象外です。',
                parent=self.root, default=messagebox.NO)
            if not accepted or self.closed:
                return
            current = self.request(op='view')
            if not current.get('ok') or current.get('campaign') != expected or current.get('trial'):
                self.notice = '状態が変わりました。宿泊内容を確認し直してください。'
                return
            result = self.request(op='campaign', action='inn', args=[])
            if result.get('ok'):
                self.notice = f'{quote["price"]}Gを支払い、パーティ全員のHP・MPが全回復しました。'
        finally:
            self.inn_pending = False
            if not self.closed:
                self.render()

    def deadline(self, choice):
        journey = self.data.get('journey') or {}
        job = journey.get('job') or self.campaign.get('activeQuest')
        action = 'rest' if choice == 'rest' else 'travel'
        args = [] if choice == 'rest' else [choice]
        if not job or journey.get('questless'):
            self.act(action, *args)
            return
        result = self.request(op='campaign', action='forecast', args=[choice])
        forecast = result.get('forecast')
        if not result.get('ok') or not forecast:
            self.notice = result.get('error') or '配達期限を確認できませんでした'
            self.foot.config(text=self.notice)
            return
        hours = forecast['hours']
        deadline = job.get('deadline', 0)
        if hours > deadline:
            proceed = messagebox.askyesno('配達期限の確認',
                    f'以降を最短で進んでも納期を超えます。\n見込み {hours}時間 / 納期 {deadline}時間'
                    f'\n超過 {hours - deadline}時間 / 見込み報酬 {int(job.get("reward", 0) * .65)}G'
                    '\nこのまま進みますか？', parent=self.root)
            if not proceed:
                self.notice = '期限警告を取り消しました。時間・状態は変わりません'
                self.foot.config(text=self.notice)
                return
        self.act(action, *args)

    def render_road(self, phase, journey):
        destination = self.campaign.get('destination') or journey.get('destination')
        job = self.campaign.get('activeQuest')
        self.label(f'{self.town_name(destination)}への旅', 22)
        self.label((job.get('name', '') + f' / {journey.get("hours", 0)}時間経過・納期{job.get("deadline", 0)}時間')
                   if job else f'自由移動 / {journey.get("hours", 0)}時間経過 / 配達報酬なし', color='#93c5fd')
        self.label(self.party_text())
        if phase == 'road':
            stage = journey.get('stage', 0)
            self.label(f'第{stage + 1}区間: 進む道を選ぶ', 17)
            self.button(f'峠の近道: 2時間 / 敵{3 if stage == 0 else 4}人', lambda: self.deadline('short'))
            self.button(f'川沿いの道: 4時間 / 敵{2 if stage == 0 else 3}人', lambda: self.deadline('safe'))
        elif phase == 'camp':
            self.label('街道の野営地 / あと一区間', 17)
            row = tk.Frame(self.panel, bg=BG)
            row.pack(anchor='w')
            self.row_button(row, '休息済み' if journey.get('rested') else '2時間休む: HP+60 / MP+2',
                            lambda: self.deadline('rest'), disabled=journey.get('rested', False))
            self.row_button(row, '先へ進む', lambda: self.act('onward'))
        else:
            self.label(f'{self.town_name(journey.get("destination"))}に到着しました', 17, color='#86efac')
            self.button('荷物を渡して報酬を確認' if job else '町へ入る（配達報酬なし）', lambda: self.act('arrive'))
        if phase == 'camp':
            self.render_items()
        if journey.get('history'):
            self.label('\n'.join(journey['history'][-4:]), 10, color=MUTED)

    def render_board(self):
        quest = self.campaign.get('activeQuest')
        self.label('掲示板 / 同時に受ける依頼は一件', 17)
        if quest:
            frame = self.card()
            self.label('受注中: ' + quest['name'], 16, parent=frame, color='#86efac')
            self.label(f'行先 {self.town_name(quest["to"])} / 納期 {quest["deadline"]}時間 / 報酬 {quest["reward"]}G', parent=frame)
            self.button('地図で出発を準備', lambda: self.set_page('map'), parent=frame)
            return
        self.label('依頼文・期限・報酬は、繰り返し試遊のための仮設定です。', 10, color=MUTED)
        board = self.campaign.get('board', [])
        if not board:
            self.label('いま受注できる依頼はありません。地図から自由移動できます。')
        for quest in board:
            frame = self.card()
            self.label(quest['name'], 16, parent=frame)
            self.label(f'行先 {self.town_name(quest["to"])} / {quest.get("client", "")}', parent=frame, color='#93c5fd')
            self.label(quest.get('text', ''), parent=frame)
            self.label(f'荷物 {quest.get("cargo", "")} / {quest.get("weight", 0)}枠'
                       f' / 納期 {quest["deadline"]}時間 / 報酬 {quest["reward"]}G', parent=frame)
            self.button('この依頼を引き受ける', lambda qid=quest['id']: self.accept_quest(qid), parent=frame,
                        disabled=not self.campaign.get('hasPorter'))
        if not self.campaign.get('hasPorter'):
            self.label('受注・出発にはポーターが必要です。ギルドで編成してください。', color='#fca5a5')

    def accept_quest(self, quest_id):
        result = self.act('accept', quest_id)
        if result.get('ok'):
            self.destination = self.campaign['activeQuest']['to']
            self.set_page('map')

    def select_destination(self, destination):
        self.destination = destination
        self.render()

    def render_map(self):
        self.label('次の行先を選ぶ', 18)
        quest = self.campaign.get('activeQuest')
        available = self.campaign.get('destinations', [])
        available_ids = [place['id'] if isinstance(place, dict) else place for place in available]
        if quest:
            self.destination = quest['to']
            self.label(f'受注中: {quest["name"]} → {self.town_name(quest["to"])}', color='#86efac')
        elif self.destination not in available_ids:
            self.destination = available_ids[0] if available_ids else None
        self.label('接続・距離・方角は試作用の模式図です。各移動は二つの区間を通ります。', 10, color=MUTED)
        canvas = tk.Canvas(self.panel, width=950, height=255, bg=CARD, highlightthickness=0)
        canvas.pack(anchor='w', pady=5)
        positions = {'astaris': (465, 125), 'east': (765, 125), 'west': (165, 125),
                     'north': (465, 40), 'south': (465, 215)}
        for key, point in positions.items():
            if key != 'astaris':
                canvas.create_line(465, 125, *point, fill='#475569', width=3, dash=(5, 4))
        for place in self.towns():
            if place['id'] not in positions:
                continue
            x, y = positions[place['id']]
            current = place['id'] == self.town_id()
            chosen = place['id'] == self.destination
            tag = 'town_' + place['id']
            canvas.create_rectangle(x - 78, y - 27, x + 78, y + 27,
                                    fill='#1d4a4b' if current else '#243c58',
                                    outline='#fbbf24' if chosen else '#64748b',
                                    width=3 if chosen else 1, tags=tag)
            canvas.create_text(x, y - 7, text=place['name'], fill=FG,
                               font=('sans-serif', 13, 'bold'), tags=tag)
            canvas.create_text(x, y + 13, text='現在地' if current else '選択中' if chosen else '目的地',
                               fill='#86efac' if current else MUTED, font=('sans-serif', 10), tags=tag)
            if place['id'] in available_ids and (not quest or quest['to'] == place['id']):
                canvas.tag_bind(tag, '<Button-1>', lambda _, uid=place['id']: self.select_destination(uid))
        choices = tk.Frame(self.panel, bg=BG)
        choices.pack(anchor='w')
        for place in available:
            uid = place['id'] if isinstance(place, dict) else place
            button = self.row_button(choices, self.town_name(uid), lambda key=uid: self.select_destination(key),
                                     disabled=bool(quest and quest['to'] != uid))
            button.config(relief='sunken' if uid == self.destination else 'raised')
        self.label('未受注での移動も戦闘・消耗があります。配達報酬はありません。追加の移動料金はありません。', 11, color=MUTED)
        self.label('編成: ' + ' / '.join(member['name'] for member in self.roster() if member['id'] in self.selected_ids()))
        formations = tk.Frame(self.panel, bg=BG)
        formations.pack(anchor='w')
        for title, value in [('基本配置', 'convoy'), ('切り込み配置', 'flank')]:
            tk.Radiobutton(formations, text=title, variable=self.formation, value=value,
                           bg=BG, fg=FG, selectcolor='#334155', activebackground=BG).pack(side='left', padx=(0, 18))
        self.button(f'{self.town_name(self.destination)}へ出発' if self.destination else '行先がありません',
                    lambda: self.act('depart', self.destination, self.formation.get()),
                    disabled=not self.destination or not self.campaign.get('hasPorter'))

    def member_stats(self, member):
        stats = member.get('stats') or member
        return f'STR {stats.get("str", 0)} / INT {stats.get("int", 0)} / AGI {stats.get("agi", 0)}' \
               f' / ATK {stats.get("atk", 0)} / 射程 {stats.get("reach", 0)}'

    def render_party(self):
        guild = self.campaign.get('guildAvailable', False)
        self.label('アスタリスのギルド' if guild else '仲間と装備', 18)
        self.label('候補11人・最大5人 / 雇用無料 / 出発にはポーター必須' if guild else
                   '編成変更はアスタリスのギルドで行います。装備はキャラクターごとに保持されます。', 11, color=MUTED)
        selected = self.selected_ids()
        grid = tk.Frame(self.panel, bg=BG)
        grid.pack(fill='x')
        for n, member in enumerate(self.roster()):
            frame = tk.Frame(grid, bg=CARD, padx=10, pady=8)
            frame.text_width = 310
            frame.grid(row=n // 3, column=n % 3, sticky='nsew', padx=(0, 8), pady=5)
            grid.columnconfigure(n % 3, weight=1)
            active = member['id'] in selected
            title = f'{member["name"]} / {member.get("role", "")}'
            if guild:
                value = tk.BooleanVar(master=self.root, value=active)
                check = tk.Checkbutton(frame, text=title, variable=value,
                    command=lambda uid=member['id']: self.choose(uid),
                    state='normal' if active or len(selected) < 5 else 'disabled',
                    bg=CARD, fg=FG, activebackground=CARD, activeforeground=FG,
                    selectcolor='#334155', font=('sans-serif', 11, 'bold'), anchor='w')
                check.var = value
                check.pack(anchor='w')
            else:
                self.label(('● ' if active else '○ ') + title, 11, parent=frame)
            stats = member.get('stats') or member
            self.label(f'HP {member.get("hp", stats.get("max", 0))}/{stats.get("max", 0)}'
                       f' / MP {member.get("mp", stats.get("maxMp", 0))}/{stats.get("maxMp", 0)}', 10, parent=frame)
            self.label(self.member_stats(member), 9, parent=frame)
            self.label(f'武器: {member.get("weaponName", member.get("weapon", ""))}\n'
                       f'防具: {member.get("armorName", member.get("armor", ""))}\n'
                       f'スキル: {member.get("skillName", stats.get("skill", ""))}', 10, parent=frame)
            self.label(' / '.join(member.get('accessoryNames', []))+'\n装飾効果: '+'・'.join(member.get('effectNames', [])), 9, parent=frame, color=MUTED)
            points = member.get('statPoints', 0)
            self.label(f'Lv.{member.get("level", 1)} / 能力ポイント {points}', 10, parent=frame, color=MUTED)
            if member.get('skillPoints'):
                self.label(f'スキルポイント {member["skillPoints"]}（配分は未実装）', 10, parent=frame, color=MUTED)
            if points:
                row = tk.Frame(frame, bg=CARD)
                row.pack(anchor='w')
                for key in ('str', 'int', 'agi'):
                    tk.Button(row, text=key.upper() + '+1', font=('sans-serif', 9),
                              command=lambda uid=member['id'], stat=key: self.act('allocate', uid, stat, 1)).pack(side='left', padx=(0, 4))
        self.label('離脱・再編入しても買い替えた装備は保持されます。能力値・装備条件・成長値は試作値です。', 10, color=MUTED)

    def render_shop(self):
        location = self.town_id()
        title = {'east': 'イースの武器屋', 'west': 'ウエスの防具屋',
                 'south': 'サウスの道具屋'}.get(location, 'この拠点にお店はありません')
        self.label(title, 18)
        if location in ('east', 'west'):
            self.label('買い替え時に現在の装備を下取りします。購入前に木人で試せます。', 11, color=MUTED)
            members = [member for member in self.roster() if member['id'] in self.selected_ids()]
            if not members:
                self.label('編成中の仲間がいません')
                return
            if self.shop_uid not in [member['id'] for member in members]:
                self.shop_uid = next((member['id'] for member in members if member.get('job') != 'porter'), members[0]['id'])
            member = next(member for member in members if member['id'] == self.shop_uid)
            row = tk.Frame(self.panel, bg=BG)
            row.pack(anchor='w', pady=4)
            tk.Label(row, text='買い替える仲間:', bg=BG, fg=FG, font=('sans-serif', 12)).pack(side='left')
            pairs = {person['name']: person['id'] for person in members}
            self.shop_member_var = tk.StringVar(master=self.root, value=member['name'])
            tk.OptionMenu(row, self.shop_member_var, *pairs.keys(),
                          command=lambda name: self.select_shop_member(pairs[name])).pack(side='left', padx=8)
            self.label(self.member_stats(member))
            self.label(f'現在の武器: {member["weaponName"]}\n現在の防具: {member["armorName"]}'
                       f' / スキル: {member["skillName"]}', 11, color='#93c5fd')
            self.label('武器セット・身体防具・装飾2枠の試作。装飾はウエス。枠番号を選んで交換します。\n'+' / '.join(member.get('accessoryNames',[])), 10, color=MUTED)
            for gear in self.campaign.get('shop', []):
                if 'slot' not in gear:
                    continue
                frame = self.card()
                self.label(f'{gear["name"]} / {gear["price"]}G', 15, parent=frame)
                requirement = ' / '.join(f'{key.upper()} {gear.get(key, 0)}' for key in ('str', 'int', 'agi') if gear.get(key, 0)) or 'なし'
                effect = f'ATK {gear.get("atk", 0)} / 射程 {gear.get("reach", 0)}' if gear['slot'] == 'weapon' else f'最大HP +{gear.get("hp", 0)}'
                self.label(f'{effect} / 必要能力 {requirement}', 11, parent=frame)
                if gear.get('note'):
                    self.label(gear['note'], 10, parent=frame, color=MUTED)
                self.button('差額・条件を確認 / 試着',
                            lambda uid=member['id'], gid=gear['id']: self.preview_gear(uid, gid), parent=frame)
        elif location == 'south':
            self.label('所持上限は各99個（試作値）。回復量はHP+55 / MP+3です。', 11, color=MUTED)
            for item in self.campaign.get('shop', []):
                frame = self.card()
                count = self.campaign.get('inventory', {}).get(item['id'], 0)
                self.label(f'{item["name"]}: {item["price"]}G / 所持 {count}個', 15, parent=frame)
                self.button(f'{item["price"]}Gで1個購入', lambda iid=item['id']: self.act('buyItem', iid, 1),
                            parent=frame, disabled=count >= 99 or self.campaign.get('gold', 0) < item['price'])
        elif location == 'north':
            self.label('ノースの施設は掲示板です。お店や固有施設はまだ設定されていません。', color=MUTED)
        else:
            self.label('武器はイース、防具はウエス、道具はサウスで購入できます。', color=MUTED)
        self.render_items()

    def select_shop_member(self, uid):
        self.shop_uid = uid
        self.render()

    def stats_summary(self, stats):
        return f'HP上限 {stats.get("max", 0)} / MP上限 {stats.get("maxMp", 0)} / ATK {stats.get("atk", 0)}' \
               f' / 射程 {stats.get("reach", 0)} / 行動速度 {stats.get("speed", stats.get("agi", 0))}'

    def preview_gear(self, uid, gear_id):
        result = self.request(op='campaign', action='previewGear', args=[uid, gear_id])
        quote = result.get('previewGear')
        if not quote:
            self.render()
            return
        member = next((member for member in self.roster() if member['id'] == uid), {})
        gear = quote.get('gear') or {}
        current = quote.get('current') or {}
        dialog = tk.Toplevel(self.root)
        dialog.title('買い替え前の確認 / ' + member.get('name', ''))
        dialog.geometry('780x590+160+100')
        dialog.transient(self.root)
        dialog.grab_set()
        dialog.configure(bg=BG)
        content = tk.Frame(dialog, bg=BG, padx=20, pady=15)
        content.pack(fill='both', expand=True)
        self.label(f'{member.get("name", "")}の装備を買い替え', 18, parent=content)
        self.label(f'現在: {current.get("name", quote.get("oldGearId", ""))}\n'
                   f'候補: {gear.get("name", gear_id)}', 13, parent=content)
        self.label(f'価格 {quote["price"]}G − 下取り {quote["tradeIn"]}G = 差額 {quote["cost"]}G\n'
                   f'所持金 {self.campaign.get("gold", 0)}G → 購入後 {quote.get("afterGold", self.campaign.get("gold", 0) - quote["cost"])}G',
                   14, parent=content, color='#93c5fd')
        self.label('変更前: ' + self.stats_summary(quote.get('before', {})), 11, parent=content)
        self.label('変更後: ' + self.stats_summary(quote.get('after', {})), 11, parent=content)
        self.label('装備中のスキル: ' + quote.get('skillName', ''), 12, parent=content)
        if quote.get('effectDescription'):
            self.label(quote['effectDescription'], 10, parent=content)
        reasons = []
        if not quote.get('eligible'):
            reasons.append(quote.get('reason') or '装備条件を満たしていません')
        elif quote.get('reason'):
            self.label(quote['reason'], 11, parent=content, color='#fcd34d')
        if not quote.get('affordable'):
            reasons.append('所持金が不足しています。購入せずに試着できます。')
        if quote.get('same'):
            reasons.append('すでにこの装備を装備しています')
        if not quote.get('available'):
            reasons.append('このお店では購入できません')
        if reasons:
            self.label('\n'.join(reasons), 12, parent=content, color='#fca5a5')
        self.label('購入すると現在の同じ枠の装備は下取りされます。予備装備としては残りません。', 11, parent=content, color='#fcd34d')
        self.label(quote.get('warning', '試着と取消では所持金・装備は変わりません'), 10, parent=content, color=MUTED)
        buttons = tk.Frame(content, bg=BG)
        buttons.pack(side='bottom', fill='x', pady=10)
        self.row_button(buttons, '木人で試す', lambda: self.start_trial(uid, gear_id, dialog),
                        disabled=not quote.get('eligible') or not quote.get('available'))
        self.row_button(buttons, 'この差額で買い替える', lambda: self.buy_gear(uid, gear_id, dialog),
                        disabled=not all(quote.get(key) for key in ('eligible', 'affordable', 'available')) or quote.get('same', False))
        self.row_button(buttons, '取消 / 戻る', dialog.destroy)
        dialog.bind('<Escape>', lambda _: dialog.destroy())

    def buy_gear(self, uid, gear_id, dialog):
        dialog.destroy()
        result = self.act('buyGear', uid, gear_id)
        if result.get('ok'):
            self.notice = '装備を買い替えました。以前の装備は下取りされました'
            self.foot.config(text=self.notice)

    def render_items(self):
        self.label('道具を使う / 町と野営地で使用可能', 15)
        inventory = self.campaign.get('inventory', {})
        self.label(f'ポーション {inventory.get("potion", 0)}個 / エーテル {inventory.get("ether", 0)}個', 11)
        members = [member for member in self.roster() if member['id'] in self.selected_ids()]
        if not members:
            return
        if self.item_uid not in [member['id'] for member in members]:
            self.item_uid = members[0]['id']
        member = next(member for member in members if member['id'] == self.item_uid)
        pairs = {person['name']: person['id'] for person in members}
        self.item_member_var = tk.StringVar(master=self.root, value=member['name'])
        row = tk.Frame(self.panel, bg=BG)
        row.pack(anchor='w')
        tk.OptionMenu(row, self.item_member_var, *pairs.keys(),
                      command=lambda name: self.select_item_member(pairs[name])).pack(side='left', padx=(0, 10))
        stats = member.get('stats') or member
        for iid, name, resource, maximum in [('potion', 'ポーションを使う', 'hp', 'max'), ('ether', 'エーテルを使う', 'mp', 'maxMp')]:
            disabled = not inventory.get(iid, 0) or member.get('hp', 0) <= 0 or member.get(resource, 0) >= stats.get(maximum, 0)
            self.row_button(row, name, lambda item=iid, uid=member['id']: self.act('useItem', item, uid), disabled=disabled)
        self.label(f'{member["name"]}: HP {member.get("hp", 0)}/{stats.get("max", 0)} / '
                   f'MP {member.get("mp", 0)}/{stats.get("maxMp", 0)}', 10, color=MUTED)

    def select_item_member(self, uid):
        self.item_uid = uid
        self.render()

    def render_result(self):
        result = self.campaign.get('result') or {}
        outcome = result.get('outcome')
        failed = outcome == 'failed'
        self.label({'success': '配達達成', 'late': '配達達成 / 遅配',
                    'failed': 'クエスト失敗 / 出発前へ', 'travel': '目的地に到着'}.get(outcome, '旅の結果'),
                   26, color='#fca5a5' if failed else '#86efac')
        if failed:
            self.label(result.get('reason', '護送隊が敗北しました'), 16)
            self.label('今回の試作では、受注直前の状態へ戻しました。自由移動の場合は出発直前へ戻ります。')
            self.label('所持金・装備・編成・HP/MP・道具・経験値・経過時間を復元しています。', color=MUTED)
        elif outcome == 'travel':
            self.label('依頼を受けずに移動しました。配達報酬はありません。戦闘の経験値は保持されます。')
        else:
            self.label('荷物を届けました。報酬と成長を持ち越して、次の依頼や買い物へ進めます。')
        self.label(f'今回の配達報酬 {result.get("gold", 0)}G / 配達経験値 {result.get("xp", 0)}', 18)
        self.label(f'所持金 {self.campaign.get("gold", 0)}G / 累計経験値 {self.campaign.get("xp", 0)} / 隊Lv.{self.campaign.get("level", 1)}', 15)
        if result.get('hours') is not None:
            self.label(f'所要時間 {result["hours"]}時間')
        self.label(self.party_text(), 12)
        place = self.town_name(self.town_id())
        self.label(f'現在地: {place}。ここで施設を利用し、次の出発を選べます。', 15)
        self.button(f'{place}に留まる / 掲示板へ', self.acknowledge)
        if self.town_id() in ('east', 'west', 'south'):
            self.button(f'{place}のお店へ', lambda: self.acknowledge('shop'))
        elif self.town_id() == 'astaris':
            self.button('アスタリスの宿屋へ', lambda: self.acknowledge('inn'))
        history = self.campaign.get('history', [])
        if history:
            self.label('\n'.join(history[-5:]), 10, color=MUTED)

    def acknowledge(self, page='board'):
        self.page = page
        self.destination = None
        self.act('acknowledge')


if __name__ == '__main__':
    root = tk.Tk()
    CampaignApp(root)
    root.mainloop()
