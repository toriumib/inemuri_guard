"""Reproducible 15-second portrait promo. Original vector motion + synthesized audio."""
from pathlib import Path
import math
import subprocess
import wave
import struct
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'store_assets' / 'promo'
OUT.mkdir(exist_ok=True)
W, H, FPS, SECONDS = 1080, 1920, 30, 15
BG, INK, MUTED, GREEN, ORANGE = '#F5F3EB', '#142C31', '#617478', '#C7F36B', '#FF6949'
FONT = 'C:/Windows/Fonts/YuGothB.ttc'
fonts = {n: ImageFont.truetype(FONT, n) for n in [26, 30, 34, 38, 44, 50, 58, 68, 78, 88]}

def text(d, xy, s, size=44, fill=INK):
    d.text(xy, s, font=fonts[size], fill=fill, stroke_width=0)

def center(d, y, s, size=44, fill=INK):
    length = d.textlength(s, font=fonts[size])
    text(d, ((W-length)/2, y), s, size, fill)

def pill(d, box, label, fill=GREEN, color=INK, size=30):
    d.rounded_rectangle(box, radius=30, fill=fill)
    length = d.textlength(label, font=fonts[size])
    text(d, ((box[0]+box[2]-length)/2, box[1]+11), label, size, color)

def face(d, cx, cy, closed=False, scale=1):
    r = int(145*scale)
    d.ellipse((cx-r, cy-r, cx+r, cy+r), fill='#E8D9C0')
    for dx in [-57,57]:
        x = cx+dx*scale
        if closed:
            d.arc((x-25*scale,cy-20*scale,x+25*scale,cy+12*scale), 0,180, fill=INK,width=7)
        else:
            d.ellipse((x-8*scale,cy-13*scale,x+8*scale,cy+10*scale),fill=INK)
    d.arc((cx-35*scale,cy+28*scale,cx+35*scale,cy+65*scale),0,180,fill=INK,width=5)

def frame(t):
    im = Image.new('RGB',(W,H),BG)
    d = ImageDraw.Draw(im)
    text(d,(80,115),'居眠りガード',34)
    text(d,(80,168),'DESK BREAK / CAMERA ALERT',26,MUTED)
    d.line((80,225,960,225),fill='#D6DCD2',width=2)
    if t < 4:
        text(d,(80,290),'カメラで',78)
        text(d,(80,395),'居眠りを検知',88)
        pill(d,(80,530,715,620),'→ 音・振動でアラート',ORANGE,size=44)
        closed = t >= 1.0 and t < 2.5
        alert = t >= 2.2
        shake = int(7*math.sin(t*70)) if alert else 0
        x = 280+shake
        d.rounded_rectangle((x,730,x+500,1400),radius=66,fill=INK)
        d.rounded_rectangle((x+20,750,x+480,1380),radius=48,fill='#E4EADA')
        d.rounded_rectangle((x+165,760,x+335,787),radius=12,fill=INK)
        face(d,x+250,1040,closed)
        color = ORANGE if alert else '#5D9E7C'
        d.rounded_rectangle((x+68,850,x+432,1230),radius=40,outline=color,width=6)
        pill(d,(x+55,1270,x+445,1343),'アラート！' if alert else 'まぶたをチェック',ORANGE if alert else GREEN)
        if alert:
            for offset in [30,60]:
                d.arc((x-offset,870,x+500+offset,1290),-40,40,fill=ORANGE,width=7)
        center(d,1480,'うとうとに、気づくきっかけ。',44)
        center(d,1570,'動作イメージ・時間短縮',26,MUTED)
    elif t < 8:
        text(d,(80,300),'スマホを立てて、',68)
        text(d,(80,405),'顔に向ける。',88)
        pill(d,(80,545,480,620),'使い方はシンプル',size=30)
        face(d,380,935,False,1.18)
        d.rounded_rectangle((180,1130,580,1320),radius=80,fill='#5F8B79')
        d.line((110,1340,940,1340),fill=INK,width=12)
        d.polygon([(730,1335),(860,1335),(812,1140)],fill=MUTED)
        d.rounded_rectangle((705,1000,830,1265),radius=25,fill=INK)
        d.rounded_rectangle((718,1018,817,1235),radius=15,fill=GREEN)
        for i in range(6):
            xx=540+i*28
            d.ellipse((xx,1030,xx+9,1039),fill='#5D9E7C')
        center(d,1435,'カメラを許可 →「検知を開始」',44)
        center(d,1530,'デスクワークのおともに。',38,MUTED)
    elif t < 11:
        text(d,(80,300),'何秒閉じたら',78)
        text(d,(80,405),'知らせる？',88)
        pill(d,(80,545,650,620),'スライダーで調整できる',size=30)
        d.rounded_rectangle((80,810,960,1360),radius=48,fill='white')
        text(d,(125,880),'目を閉じている時間',44)
        value = round(10+10*min(1,(t-8)/1.8))
        center(d,985,f'{value} 秒',88)
        d.rounded_rectangle((145,1155,895,1167),radius=6,fill='#DEE3D9')
        knob=145+(value-3)/57*750
        d.rounded_rectangle((145,1155,knob,1167),radius=6,fill='#477D64')
        d.ellipse((knob-24,1137,knob+24,1185),fill=INK)
        text(d,(140,1220),'3秒',30,MUTED)
        text(d,(802,1220),'60秒',30,MUTED)
        center(d,1470,'自分に合わせて、設定。',44)
        center(d,1570,'設定画面のイメージ',26,MUTED)
    else:
        pill(d,(80,300,420,377),'居眠り対策アプリ',size=30)
        text(d,(80,460),'そのうとうとに、',68)
        text(d,(80,565),'アラートを。',88)
        d.rounded_rectangle((80,800,960,1230),radius=48,fill=INK)
        center(d,885,'居眠りガード',78,GREEN)
        center(d,1020,'カメラ検知 × 音・振動',44,'white')
        center(d,1110,'仮眠タイマーも搭載',38,'#D4DFD5')
        center(d,1360,'詳しくは、こちら',44)
        center(d,1450,'inemuri.toriumis.com',50)
        center(d,1560,'眠いときは、無理せず休憩を。',30,MUTED)
    for i in range(4):
        a,b=[(0,4),(4,8),(8,11),(11,15)][i]
        x=80+i*224
        d.rounded_rectangle((x,1690,x+204,1697),radius=3,fill='#D6DCD2')
        progress=max(0,min(1,(t-a)/(b-a)))
        if progress:
            d.rounded_rectangle((x,1690,x+204*progress,1697),radius=3,fill=INK)
    return im

def audio():
    rate=44100
    cues=[(0,523,.16),(2.2,880,.18),(2.48,1108,.18),(4,659,.14),(8,740,.14),(11,523,.25),(11.15,659,.3)]
    with wave.open(str(OUT/'promo_audio.wav'),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate)
        data=bytearray()
        for n in range(rate*SECONDS):
            t=n/rate
            s=0
            for start,hz,duration in cues:
                dt=t-start
                if 0 <= dt < duration:
                    s += .15*math.sin(2*math.pi*hz*dt)*math.sin(math.pi*dt/duration)**2
            data.extend(struct.pack('<h',int(s*32767)))
        f.writeframes(data)

if __name__ == '__main__':
    audio()
    command=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-',
             '-i',str(OUT/'promo_audio.wav'),'-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p',
             '-c:a','aac','-b:a','128k','-movflags','+faststart','-shortest',str(OUT/'inemuri_short_15s.mp4')]
    p=subprocess.Popen(command,stdin=subprocess.PIPE)
    for n in range(FPS*SECONDS):
        p.stdin.write(frame(n/FPS).tobytes())
    p.stdin.close()
    if p.wait(): raise RuntimeError('ffmpeg failed')
    frame(0).save(OUT/'cover.png')
    contact=Image.new('RGB',(1080,960),BG)
    for i,t in enumerate([0,2.6,5,9,12,14]):
        contact.paste(frame(t).resize((270,480)),((i%4)*270,(i//4)*480))
    contact.save(OUT/'storyboard.jpg')
    print(OUT/'inemuri_short_15s.mp4')
