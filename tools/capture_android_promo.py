"""Capture only the app on the dedicated emulator, not a user's phone."""
import subprocess
import time
from pathlib import Path
import xml.etree.ElementTree as ET
import re

ADB='C:/Users/tori/AppData/Local/Android/Sdk/platform-tools/adb.exe'
OUT=Path(__file__).resolve().parents[1]/'store_assets/promo_real'
OUT.mkdir(exist_ok=True)
def adb(*args):
    return subprocess.check_output([ADB,'-s','emulator-5554',*args])
def ui():
    adb('shell','uiautomator','dump','/sdcard/inemuri-promo-ui.xml')
    return ET.fromstring(adb('shell','cat','/sdcard/inemuri-promo-ui.xml'))
def bounds(node):
    return list(map(int,re.findall(r'\d+',node.attrib['bounds'])))
def tap_desc(tree,desc):
    node=next(n for n in tree.iter('node') if n.attrib.get('content-desc','').startswith(desc))
    x,y,a,b=bounds(node); adb('shell','input','tap',str((x+a)//2),str((y+b)//2))
def shot(name):
    adb('shell','screencap','-p','/sdcard/inemuri-promo.png')
    adb('pull','/sdcard/inemuri-promo.png',str(OUT/name))

adb('shell','input','keyevent','KEYCODE_WAKEUP')
adb('shell','wm','dismiss-keyguard')
tree=ui()
tap_desc(tree,'検知\nTab')
tree=ui()
shot('android-home.png')
slider=next(n for n in tree.iter('node') if n.attrib.get('class')=='android.widget.SeekBar')
x,y,a,b=bounds(slider)
record=subprocess.Popen([ADB,'-s','emulator-5554','shell','screenrecord','--time-limit','18','--bit-rate','3000000','/sdcard/inemuri-promo-v2.mp4'])
time.sleep(1)
adb('shell','input','swipe',str(x+50),str((y+b)//2),str(x+270),str((y+b)//2),'1100')
time.sleep(.5)
shot('android-slider.png')
tap_desc(tree,'仮眠\nTab')
time.sleep(1.5)
shot('android-nap.png')
record.wait(timeout=35)
adb('pull','/sdcard/inemuri-promo-v2.mp4',str(OUT/'android-recording.mp4'))
print('Captured Android app: slider and nap tab; emulator development build.')
