import os
"""Record permission-review evidence on our Android emulator, never a phone.

Commands: ui, tap TEXT, shot NAME, record NAME SECONDS, evidence NAME.
Record commands run asynchronously so UI actions can be performed separately.
Only app-specific diagnostic lines are retained; no notification contents.
"""
import subprocess, sys, re
from pathlib import Path
import xml.etree.ElementTree as ET

ADB = os.environ.get('ADB', os.path.expandvars(r'%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe'))
OUT = Path(__file__).resolve().parents[1] / 'store_assets/fgs_review'
OUT.mkdir(parents=True, exist_ok=True)

def adb(*args):
    return subprocess.check_output([ADB, '-s', 'emulator-5554', *args], timeout=45)

def ui():
    adb('shell', 'uiautomator', 'dump', '/data/local/tmp/fgs-ui.xml')
    return ET.fromstring(adb('shell', 'cat', '/data/local/tmp/fgs-ui.xml'))

cmd = sys.argv[1]
if cmd in ('ui', 'tap'):
    nodes = list(ui().iter('node'))
    if cmd == 'ui':
        for n in nodes:
            a = n.attrib
            label = a.get('content-desc') or a.get('text')
            if label:
                print(label.replace('\n', ' / '), a['bounds'], 'enabled='+a['enabled'])
    else:
        matches = [n for n in nodes if
                   (n.attrib.get('content-desc') == sys.argv[2] or
                    n.attrib.get('text') == sys.argv[2]) and n.attrib['enabled'] == 'true']
        if len(matches) != 1:
            raise RuntimeError(f'Expected one enabled exact match; got {len(matches)}')
        x,y,a,b = map(int,re.findall(r'\d+',matches[0].attrib['bounds']))
        adb('shell','input','tap',str((x+a)//2),str((y+b)//2))
elif cmd == 'shot':
    adb('shell','screencap','-p','/data/local/tmp/fgs-shot.png')
    adb('pull','/data/local/tmp/fgs-shot.png',str(OUT/(sys.argv[2]+'.png')))
elif cmd == 'record':
    name = sys.argv[2]
    if not re.fullmatch(r'[a-z0-9-]+',name): raise ValueError('Invalid recording name')
    subprocess.run([ADB,'-s','emulator-5554','shell','screenrecord','--size','540x1200','--bit-rate','1500000',
        '--time-limit',sys.argv[3],'/data/local/tmp/'+name+'.mp4'],check=True,timeout=int(sys.argv[3])+45)
    adb('pull','/data/local/tmp/'+name+'.mp4',str(OUT/(name+'.mp4')))
elif cmd == 'evidence':
    output = adb('logcat','-d','-v','time','EyeService:D','flutter:I','*:S').decode('utf-8',errors='replace')
    lines = [line for line in output.splitlines() if 'EyeService' in line or 'マイク受信中' in line]
    print('\n'.join(lines[-35:]))
