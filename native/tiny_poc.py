"""Disposable native GUI feasibility test. No dependency on the browser game."""
from dataclasses import dataclass
import tkinter as tk


@dataclass
class Unit:
    name: str
    side: str
    x: int
    y: int
    hp: int = 6


class Game:
    def __init__(self):
        self.reset()

    def reset(self):
        self.units = [Unit('剣士', 'ally', 1, 2), Unit('弓士', 'ally', 0, 4),
                      Unit('敵Ａ', 'enemy', 3, 2), Unit('敵Ｂ', 'enemy', 5, 0)]
        self.selected = None
        self.actions = 0
        self.log = ['リセット完了 — 味方を選択してください']

    def at(self, x, y):
        return next((u for u in self.units if u.hp > 0 and (u.x, u.y) == (x, y)), None)

    def click(self, x, y):
        if not (0 <= x < 6 and 0 <= y < 5):
            return
        target = self.at(x, y)
        if target and target.side == 'ally':
            self.selected = target
            self.log.append(f'選択: {target.name} ({x+1}, {y+1})')
            return
        if not self.selected:
            self.log.append('無効: 先に味方を選択してください')
            return
        u = self.selected
        if abs(u.x-x) + abs(u.y-y) != 1:
            self.log.append('無効: 移動・攻撃は上下左右の隣接１マスのみ')
            return
        self.actions += 1
        if target:
            target.hp = max(0, target.hp-3)
            self.log.append(f'攻撃: {u.name} → {target.name} / 3ダメージ / HP {target.hp}/6')
            if target.hp == 0:
                self.log.append(f'撃破: {target.name} — 盤面から除去')
        else:
            u.x, u.y = x, y
            self.log.append(f'移動: {u.name} → ({x+1}, {y+1})')


class App:
    def __init__(self, root):
        self.game = Game()
        root.title('5525 Native PoC — クラウド操作検証')
        root.geometry('950x660+80+60')
        root.resizable(False, False)
        root.configure(bg='#111827')
        tk.Label(root, text='5525 / NATIVE PROOF OF CONCEPT', bg='#111827', fg='#e5e7eb',
                 font=('sans-serif', 21, 'bold')).pack(anchor='w', padx=24, pady=(18, 4))
        tk.Label(root, text='味方をクリック → 隣接の空きマスで移動 / 隣接の敵で攻撃（3ダメージ）',
                 bg='#111827', fg='#cbd5e1', font=('sans-serif', 12)).pack(anchor='w', padx=24)
        body = tk.Frame(root, bg='#111827')
        body.pack(padx=24, pady=18, fill='both', expand=True)
        self.canvas = tk.Canvas(body, width=540, height=450, highlightthickness=0, bg='#111827')
        self.canvas.pack(side='left', anchor='n')
        self.canvas.bind('<Button-1>', self.clicked)
        side = tk.Frame(body, bg='#111827')
        side.pack(side='left', padx=(20, 0), fill='both', expand=True)
        self.status = tk.Label(side, bg='#111827', fg='#f8fafc', font=('sans-serif', 12), justify='left')
        self.status.pack(anchor='w')
        tk.Button(side, text='リセット / RESET', command=self.reset, font=('sans-serif', 13),
                  bg='#dbeafe', padx=14, pady=8).pack(anchor='w', pady=16)
        tk.Label(side, text='操作ログ', bg='#111827', fg='#94a3b8', font=('sans-serif', 12)).pack(anchor='w')
        self.log = tk.Text(side, width=32, height=18, wrap='char', bg='#1e293b', fg='#e2e8f0',
                           font=('sans-serif', 11), relief='flat', padx=10, pady=10)
        self.log.pack(fill='both', expand=True)
        tk.Label(root, text='独立した実験版 • ターン制・AI・スキル未実装 • 既存ブラウザ版には接続しません',
                 bg='#111827', fg='#94a3b8', font=('sans-serif', 11)).pack(anchor='w', padx=24, pady=(0, 18))
        self.draw()

    def reset(self):
        self.game.reset()
        self.draw()

    def clicked(self, e):
        self.game.click(e.x//90, e.y//90)
        self.draw()

    def draw(self):
        c, g = self.canvas, self.game
        c.delete('all')
        for y in range(5):
            for x in range(6):
                left, top = x*90, y*90
                fill = '#243449' if (x+y)%2 else '#2e4056'
                if g.selected and abs(x-g.selected.x)+abs(y-g.selected.y) == 1:
                    fill = '#365a56'
                c.create_rectangle(left+2, top+2, left+88, top+88, fill=fill, outline='')
                c.create_text(left+12, top+12, text=f'{x+1},{y+1}', fill='#8295aa', font=('sans-serif', 8))
        for u in g.units:
            if u.hp <= 0:
                continue
            x, y = u.x*90+45, u.y*90+45
            color = '#60a5fa' if u.side == 'ally' else '#fb7185'
            c.create_oval(x-29, y-29, x+29, y+29, fill=color,
                          outline='#fde047' if u is g.selected else color,
                          width=4 if u is g.selected else 1)
            c.create_text(x, y-3, text=u.name, font=('sans-serif', 14, 'bold'), fill='#0f172a')
            c.create_text(x, y+17, text=f'HP {u.hp}/6', font=('sans-serif', 9), fill='#0f172a')
        alive = sum(u.hp > 0 and u.side == 'enemy' for u in g.units)
        self.status.config(text=f'選択: {g.selected.name if g.selected else "なし"}\n行動数: {g.actions}\n残りの敵: {alive} / 2')
        self.log.config(state='normal')
        self.log.delete('1.0', 'end')
        self.log.insert('end', '\n\n'.join(g.log))
        self.log.see('end')
        self.log.config(state='disabled')


if __name__ == '__main__':
    root = tk.Tk()
    App(root)
    root.mainloop()
