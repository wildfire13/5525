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
def delayed(original):
    def publish(*args):
        if mode=='after_publish':original(*args);time.sleep(3)
        else:time.sleep(3);original(*args)
    return publish
files.publish_new=delayed(files.publish_new)
files.publish_replace=delayed(files.publish_replace)
if request['action']!='write':time.sleep(3)
try:print(json.dumps({'ok':True,'data':files.run(request)},ensure_ascii=False),flush=True)
except Exception as error:print(json.dumps({'ok':False,'error':str(error)},ensure_ascii=False),flush=True)
