"""Compose actual app recordings into bilingual portrait promos and campaign assets.
No simulated detection data. Web alert footage comes from the app's test button.
"""
from pathlib import Path
import subprocess
import math
import struct
import wave
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'store_assets/promo_real'
SITE=ROOT.parent/'inemuri-web/public/media'
SITE.mkdir(exist_ok=True)
W,H,FPS,DURATION=1080,1920,30,24
BG,INK,KEY,ORANGE,MUTED='#F5F3EB','#142C31','#C7F36B','#FF6949','#536669'
F={s:ImageFont.truetype('C:/Windows/Fonts/YuGothB.ttc',s) for s in [24,26,28,30,32,34,38,40,44,48,50,56,60,66,72,78,84,88]}
images={n:Image.open(OUT/(n+'.png')).convert('RGB') for n in ['web-home','web-alert','web-settings','android-home','android-slider','android-nap']}

def decode(file,width,height):
    p=subprocess.Popen(['ffmpeg','-v','error','-threads','2','-i',str(OUT/file),'-vf',f'fps=10,scale={width}:{height}','-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
    result=[]; size=width*height*3
    while True:
        data=p.stdout.read(size)
        if len(data)!=size: break
        result.append(Image.frombytes('RGB',(width,height),data))
    if p.wait(): raise RuntimeError('decode failed')
    return result
web=decode('web-recording.webm',360,660)
android=decode('android-recording.mp4',324,720)
def clip(frames,t): return frames[min(len(frames)-1,max(0,int(t*10)))]
def text(d,x,y,s,size=44,color=INK): d.text((x,y),s,font=F[size],fill=color)
def center(d,y,s,size=44,color=INK): text(d,(W-d.textlength(s,font=F[size]))/2,y,s,size,color)
def panel(im,source,x,y,w,h):
    scale=min(w/source.width,h/source.height)
    source=source.resize((round(source.width*scale),round(source.height*scale)),Image.Resampling.LANCZOS)
    x+=int((w-source.width)/2);y+=int((h-source.height)/2)
    d=ImageDraw.Draw(im)
    d.rounded_rectangle((x-7,y-7,x+source.width+7,y+source.height+7),radius=18,fill=INK)
    im.paste(source,(x,y))
def pill(d,x,y,w,label,size=30,fill=KEY):
    d.rounded_rectangle((x,y,x+w,y+66),radius=22,fill=fill)
    text(d,x+(w-d.textlength(label,font=F[size]))/2,y+9,label,size)

def frame(t,lang):
    ja=lang=='ja'
    im=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(im)
    text(d,72,104,'居眠りガード' if ja else 'DROWSINESS GUARD',32)
    text(d,72,156,'PC作業・勉強中のうとうとに' if ja else 'FOR WORK & STUDY',26,MUTED)
    if t<2 or t>=20:
        center(d,274,'居眠りしちゃう人へ' if ja else 'KEEP NODDING OFF?',48)
        center(d,350,'カメラで検知' if ja else 'CAMERA DETECTS',84 if ja else 66)
        center(d,459,'音・振動で起こす' if ja else 'SOUND + VIBRATION',72 if ja else 60)
        pill(d,145,598,350,'Web / PC・スマホ' if ja else 'WEB',28)
        pill(d,545,598,390,'Android / Google Play' if not ja else 'Androidアプリ',28)
        panel(im,images['web-alert'],90,716,425,740)
        # Crop only the app's camera/settings card; no fabricated screen elements.
        panel(im,images['android-slider'].crop((0,125,1080,1565)),565,716,425,740)
        center(d,1510,'WebとAndroid、選べます。' if ja else 'TRY WEB OR ANDROID.',38)
        center(d,1600,'inemuri.toriumis.com',40)
        center(d,1690,'実画面 / Webアラートはテスト機能' if ja else 'Actual UI · Web alert shown with test button',24,MUTED)
    elif t<8:
        text(d,72,266,'まずはWebで。' if ja else 'TRY IT IN YOUR BROWSER.',60 if ja else 40)
        text(d,72,365,'検知したらアラート。' if ja else 'AN ALERT WHEN YOU NEED IT.',50 if ja else 38)
        panel(im,clip(web,t),180,530,720,1090)
        center(d,1680,'実画面：起こし方のテストを実行' if ja else 'Actual app: built-in alarm test',28,MUTED)
    elif t<13:
        text(d,72,266,'Androidでも。' if ja else 'ON ANDROID, TOO.',60)
        text(d,72,365,'何秒閉じたら知らせる？' if ja else 'CHOOSE YOUR TIMING.',48)
        screen=clip(android,t-8)
        # Focus on the actual camera card and slider, excluding peripheral settings.
        panel(im,screen.crop((0,37,324,470)),100,515,880,1120)
        center(d,1680,'Android開発版の実画面（エミュレーター）' if ja else 'Android development build · emulator',26,MUTED)
    elif t<17:
        text(d,72,266,'設定は、自分に合わせて。' if ja else 'MAKE IT WORK FOR YOU.',48)
        text(d,72,366,'音・振動・秒数をチェック' if ja else 'CHECK SOUND, VIBRATION & TIMING',40 if ja else 30)
        panel(im,clip(web,6+(t-13)*.6),180,530,720,1090)
        center(d,1680,'イヤホン利用時も出力先を事前に確認' if ja else 'Using earphones? Test the audio output first.',26,MUTED)
    else:
        text(d,72,266,'眠いときは、休もう。' if ja else 'SLEEPY? TAKE A BREAK.',56 if ja else 44)
        text(d,72,366,'仮眠タイマーも搭載。' if ja else 'A NAP TIMER IS INCLUDED.',48 if ja else 38)
        panel(im,images['android-nap'].crop((0,370,1080,1900)),145,530,790,1090)
        center(d,1680,'Android開発版 / 睡眠の代わりにはなりません' if ja else 'Development build · Alerts do not replace sleep',24,MUTED)
    d.rounded_rectangle((72,1770,1008,1777),radius=3,fill='#D6DCD2')
    if t>0:d.rounded_rectangle((72,1770,72+936*t/DURATION,1777),radius=3,fill=INK)
    return im

def audio():
    rate=44100
    cues=[(0,523,.2),(2,659,.2),(4.1,880,.15),(4.4,1108,.15),(8,587,.2),(13,659,.2),(17,523,.2),(20,784,.3)]
    with wave.open(str(OUT/'soundtrack.wav'),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate)
        buf=bytearray()
        for n in range(rate*DURATION):
            t=n/rate;s=0
            for start,hz,duration in cues:
                dt=t-start
                if 0<=dt<duration:s+=.12*math.sin(2*math.pi*hz*dt)*math.sin(math.pi*dt/duration)**2
            buf.extend(struct.pack('<h',int(s*32767)))
        f.writeframes(buf)

def landscape(lang,w,h,store=False):
    im=Image.new('RGB',(1200,630),BG);d=ImageDraw.Draw(im);ja=lang=='ja'
    text(d,65,65,'居眠りガード' if ja else 'DROWSINESS GUARD',30)
    text(d,65,157,'居眠りしちゃう人へ' if ja else 'KEEP NODDING OFF?',44)
    text(d,65,251,'カメラで検知' if ja else 'CAMERA ALERTS',66 if ja else 56)
    text(d,65,337,'音・振動でお知らせ' if ja else 'SOUND + VIBRATION',48 if ja else 38)
    text(d,65,454,('Androidアプリ' if store else 'Web ＋ Android') if ja else ('ANDROID APP' if store else 'WEB + ANDROID'),34)
    shot=Image.open(ROOT/'store_assets/screenshots_play/01_detect.png').convert('RGB') if store else images['android-slider']
    panel(im,shot.crop((0,120,shot.width,1600)),815,58,315,510)
    return im.resize((w,h),Image.Resampling.LANCZOS)

audio()
for lang in ['ja','en']:
    dest=OUT/f'inemuri-real-{lang}.mp4'
    p=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1080x1920','-r',str(FPS),'-i','-',
                        '-i',str(OUT/'soundtrack.wav'),'-c:v','libx264','-threads','2','-preset','fast','-crf','19','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart','-shortest',str(dest)],stdin=subprocess.PIPE)
    for n in range(FPS*DURATION):p.stdin.write(frame(n/FPS,lang).tobytes())
    p.stdin.close()
    if p.wait():raise RuntimeError('encode failed')
    frame(0,lang).save(OUT/f'cover-{lang}.jpg',quality=94)
    landscape(lang,1200,630).save(OUT/f'og-{lang}.jpg',quality=94)
    landscape(lang,1280,720).save(OUT/f'thumbnail-wide-{lang}.jpg',quality=94)
    landscape(lang,1024,500,store=True).save(OUT/f'play-feature-{lang}.png')
    for name in [dest.name,f'cover-{lang}.jpg',f'og-{lang}.jpg']:
        shutil.copy2(OUT/name,SITE/name)
for name in ['web-settings.png','android-slider.png']:shutil.copy2(OUT/name,SITE/name)
sheet=Image.new('RGB',(1080,960),BG)
for i,t in enumerate([0,4.5,9,14,18,22]):sheet.paste(frame(t,'ja').resize((270,480)),((i%4)*270,(i//4)*480))
sheet.save(OUT/'review-sheet.jpg',quality=92)
print('Rendered JA / EN videos, thumbnails, Play feature graphics, and site media.')
