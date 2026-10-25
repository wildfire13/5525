"""Render on an existing isolated X display and send OS mouse events via XTest.

Requires DISPLAY, libX11/libXtst, Godot, Node, Python and Pillow.
Evidence and all user profiles must be outside the checkout.
"""
import argparse
import ctypes as C
import ctypes.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

p = argparse.ArgumentParser()
p.add_argument('--evidence', required=True, type=Path)
p.add_argument('--script', choices=['facility_gui_261022','facility_input_extra_261022','brushup_gui','facility_npc_gui','research2_gui','layout_fixes_gui','equipment_hover_gui','skill_effects_gui','ui_p3_gui','turn_order_keyboard_gui','deployment_start_gui','guard_feedback_gui','individual_icons_gui','audio_options_gui'], default='facility_gui_261022')
a = p.parse_args()
repo = Path(__file__).resolve().parents[2]
out = a.evidence.resolve()
if out == repo or repo in out.parents or not os.environ.get('DISPLAY'):
    p.error('Use an existing isolated DISPLAY and evidence outside checkout')
out.mkdir(parents=True, exist_ok=True)
if (out/'request.json').exists():
    p.error('Use a fresh evidence directory')
x = C.CDLL(ctypes.util.find_library('X11'))
xt = C.CDLL(ctypes.util.find_library('Xtst'))
x.XOpenDisplay.argtypes = [C.c_char_p]
x.XOpenDisplay.restype = C.c_void_p
x.XFlush.argtypes = [C.c_void_p]
x.XCloseDisplay.argtypes = [C.c_void_p]
x.XResizeWindow.argtypes = [C.c_void_p, C.c_ulong, C.c_uint, C.c_uint]
x.XDefaultRootWindow.argtypes = [C.c_void_p]
x.XDefaultRootWindow.restype = C.c_ulong
x.XQueryPointer.argtypes = [C.c_void_p,C.c_ulong,C.POINTER(C.c_ulong),C.POINTER(C.c_ulong),C.POINTER(C.c_int),C.POINTER(C.c_int),C.POINTER(C.c_int),C.POINTER(C.c_int),C.POINTER(C.c_uint)]
x.XSetInputFocus.argtypes = [C.c_void_p,C.c_ulong,C.c_int,C.c_ulong]
x.XStringToKeysym.argtypes = [C.c_char_p]
x.XStringToKeysym.restype = C.c_ulong
x.XKeysymToKeycode.argtypes = [C.c_void_p, C.c_ulong]
x.XKeysymToKeycode.restype = C.c_uint
xt.XTestFakeKeyEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
xt.XTestFakeMotionEvent.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_ulong]
xt.XTestFakeButtonEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
display = x.XOpenDisplay(os.environ['DISPLAY'].encode())
if not display:
    p.error('Could not open the isolated display')

def move(px, py):
    xt.XTestFakeMotionEvent(display, -1, int(px), int(py), 0)
    x.XFlush(display)

def button(pressed, number=1):
    xt.XTestFakeButtonEvent(display, number, int(pressed), 0)
    x.XFlush(display)

env = dict(os.environ, NATIVE5525_NODE=shutil.which('node'), NATIVE5525_PYTHON=sys.executable, NATIVE5525_AUDIO_OFF='1',
           INVENTORY_QA_ROOT=str(out), UIUX_REVIEW_EVIDENCE=str(out), LIBGL_ALWAYS_SOFTWARE='1')
for key, child in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
    path = out/child
    path.mkdir()
    env[key] = str(path)
requests = []
with (out/'gui.log').open('w') as log:
    proc = subprocess.Popen([shutil.which('godot'), '--display-driver','x11','--rendering-method','gl_compatibility',
        '--audio-driver','Dummy','--path',str(repo/'godot'),'--script','res://tests/'+a.script+'.gd'],
        cwd=repo, env=env, stdout=log, stderr=subprocess.STDOUT)
    deadline = time.monotonic()+630
    try:
        while proc.poll() is None and time.monotonic()<deadline:
            try:
                request = json.loads((out/'request.json').read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                time.sleep(.03)
                continue
            if request['id'] <= len(requests):
                time.sleep(.03)
                continue
            if request['action'] == 'resize_window':
                x.XResizeWindow(display, int(request['window']), int(request['width']), int(request['height']))
                x.XFlush(display)
                time.sleep(.3)
            elif request['action'] == 'key':
                code = x.XKeysymToKeycode(display, x.XStringToKeysym(request['key'].encode()))
                if not code:
                    raise ValueError('Unknown X11 keysym: ' + request['key'])
                xt.XTestFakeKeyEvent(display, code, True, 0)
                x.XFlush(display)
                time.sleep(.08)
                xt.XTestFakeKeyEvent(display, code, False, 0)
                x.XFlush(display)
                time.sleep(.12)
            else:
                move(request['x'], request['y'])
                time.sleep(.08)
                # This display intentionally has no window manager. Give the real
                # window under the pointer keyboard focus before its first click.
                root_window, child = C.c_ulong(), C.c_ulong()
                rx, ry, wx, wy, mask = C.c_int(), C.c_int(), C.c_int(), C.c_int(), C.c_uint()
                x.XQueryPointer(display,x.XDefaultRootWindow(display),C.byref(root_window),C.byref(child),C.byref(rx),C.byref(ry),C.byref(wx),C.byref(wy),C.byref(mask))
                if child.value:
                    x.XSetInputFocus(display,child.value,1,0)
                    x.XFlush(display)
                    time.sleep(.08)
                if request['action'] in ('wheel_down', 'wheel_up'):
                    number = 5 if request['action'] == 'wheel_down' else 4
                    for _ in range(max(1, min(100, int(request.get('steps', 1))))):
                        button(True, number)
                        button(False, number)
                        time.sleep(.02)
                elif request['action'] in ('click','drag','camera_drag'):
                    number = 2 if request['action']=='camera_drag' else 1
                    button(True, number)
                    time.sleep(.08)
                    if request['action'] in ('drag','camera_drag'):
                        for step in range(1,13):
                            move(request['x']+(request['end_x']-request['x'])*step/12,
                                 request['y']+(request['end_y']-request['y'])*step/12)
                            time.sleep(.035)
                    button(False, number)
            requests.append(request)
            temp=out/'response.tmp'
            temp.write_text(json.dumps({'id':request['id']}))
            temp.replace(out/'response.json')
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=10)
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        x.XCloseDisplay(display)
text = (out/'gui.log').read_text()
errors = [s for s in text.splitlines() if 'ERROR:' in s or s.startswith('FAIL ') or 'leaked' in s.lower()]
checks = json.loads((out/'checks.json').read_text()) if (out/'checks.json').exists() else []
result = {'passed':proc.returncode==0 and not errors and bool(checks) and all(c['passed'] for c in checks),
          'exit':proc.returncode,'errors':errors,'checks':len(checks),'os_mouse_requests':len(requests),
          'screenshots':len(list(out.glob('*.png'))),'display':os.environ['DISPLAY']}
(out/'os-mouse-requests.json').write_text(json.dumps(requests,indent=2)+'\n')
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
sys.exit(0 if result['passed'] else 1)
