"""JSON-lines client for exercising the native game bridge in tests."""
import json
from pathlib import Path
import subprocess

BASE = Path(__file__).resolve().parent


class Session:
    def __init__(self, seed=5525):
        self.process = subprocess.Popen(
            ['node', f'--random-seed={seed}', str(BASE / 'bridge.cjs')],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding="utf-8", cwd=BASE)

    def call(self, **request):
        self.process.stdin.write(json.dumps(request) + '\n')
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError('Bridge exited: ' + self.process.stderr.read())
        return json.loads(line)

    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=5)
        self.process.stdout.close()
        self.process.stderr.close()
