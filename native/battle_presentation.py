"""Nonblocking, acknowledged battle phases. No gameplay rules live here."""


def low_hp(unit):
    return unit.get('max', 0) > 0 and unit['hp'] * 4 < unit['max']


class BattlePresentation:
    def __init__(self, app):
        self.app = app
        self.timer = None
        self.closed = False
        self.generation = 0
        self.token = None

    @property
    def busy(self):
        return self.token is not None

    def accept(self, data):
        phase = data.get('presentation')
        self.app.data = data
        if not phase:
            self.token = None
            self.app.message = data.get('error') or '行動が完了しました。'
            self.app.draw()
            return
        token = (phase['id'], phase['index'])
        if token == self.token:
            return
        self.token = token
        self.generation += 1
        generation = self.generation
        self.app.message = phase.get('label', '行動結果')
        self.app.draw()
        events = phase.get('voiceEvents', [])
        self.app.voice.play_events(events)
        sound_duration=self.app.sounds.phase(phase, data['state']) if getattr(self.app,'sounds',None) else 0
        durations = [self.app.voice.catalog.lookup(event) for event in events]
        audible = self.app.voice.available and not self.app.voice.preferences['muted']
        duration = max([int(clip[1] * 1000) + 80 for clip in durations if clip] or [0]) if audible else 0
        total = max(duration, sound_duration, 420 if phase['phase'] != 'settled' else 240)
        ticks = max(1, (total + 29) // 30)
        tag = 'portrait:' + str(phase.get('unit_id'))
        origin = self.app.canvas.coords(tag)

        def tick(n=0):
            if self.closed or generation != self.generation:
                return
            x = y = 0
            if n < 12 and phase['phase'] in ('action', 'hurt'):
                x = (0, -5, 5, -4, 4, -3, 3, -2, 2, 0, 0, 0)[n]
            elif n < 12 and phase['phase'] == 'move':
                start, end = phase['from'], phase['to']
                x = ((start % 10) - (end % 10)) * 74 * (1 - n / 11)
                y = ((start // 10) - (end // 10)) * 74 * (1 - n / 11)
            current=self.app.canvas.coords(tag)
            if origin and current:
                self.app.canvas.move(tag, origin[0]+x-current[0], origin[1]+y-current[1])
            if n < ticks:
                self.timer = self.app.root.after(30, lambda: tick(n + 1))
            else:
                self.timer = None
                try:
                    result = self.app.bridge.call(op='presentation_next', id=token[0], index=token[1])
                except (OSError, RuntimeError, ValueError) as error:
                    self.app.message = '演出の通信が止まりました。ウィンドウを閉じてください: ' + str(error)
                    self.app.draw()
                    return
                if not result.get('ok'):
                    self.app.message = result.get('error', '演出を進められません')
                    self.app.draw()
                    return
                self.accept(result)
        tick()

    def close(self):
        if self.closed:
            return
        self.closed = True
        self.generation += 1
        if self.timer is not None:
            self.app.root.after_cancel(self.timer)
            self.timer = None
        self.app.voice.close()
        if getattr(self.app, "sounds", None):self.app.sounds.stop()
        if self.token is not None:
            try:
                self.app.bridge.call(op='presentation_finish', id=self.token[0])
            except (OSError, RuntimeError, ValueError):
                pass
        self.token = None
