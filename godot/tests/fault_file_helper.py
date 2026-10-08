"""Fault injection only: no production configuration or global environment edits."""
import json,sys,time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'native'))
import godot_files as files
request=json.loads(sys.stdin.readline())
mode=request.get('fault_mode','before_publish')
if mode=='invalid_reply':
    print('not json',flush=True);sys.exit()
if mode=='eof':sys.exit()
original=files.publish_new
def delayed_publish(temp,path):
    if mode=='after_publish':original(temp,path);time.sleep(3)
    else:time.sleep(3);original(temp,path)
files.publish_new=delayed_publish
if request['action']!='write':time.sleep(3)
try:print(json.dumps({'ok':True,'data':files.run(request)},ensure_ascii=False),flush=True)
except Exception as error:print(json.dumps({'ok':False,'error':str(error)},ensure_ascii=False),flush=True)
