"""Compose verified screen recordings, not simulated detector UI."""
from pathlib import Path
import subprocess
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'store_assets/promo_detection'
W,H,FPS,DURATION=1080,1920,15,28
BG='#F5F3EB'; INK='#142C31'
def font(size): return ImageFont.truetype('C:/Windows/Fonts/YuGothB.ttc',size)
def decode(file,w,h):
    p=subprocess.Popen(['ffmpeg','-v','error','-threads','2','-i',str(file),'-vf',f'fps=10,scale={w}:{h}','-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
    frames=[]
    while True:
        b=p.stdout.read(w*h*3)
        if len(b)!=w*h*3:break
        frames.append(Image.frombytes('RGB',(w,h),b))
    if p.wait():raise RuntimeError('decode failed')
    return frames
web=decode(OUT/'web.webm',640,600)
mobile=decode(OUT/'iphone-viewport.webm',390,844)
android=decode(ROOT/'store_assets/promo_real/android-recording.mp4',324,720)
def clip(frames,t):return frames[min(len(frames)-1,max(0,int(t*10)))]
def center(d,y,text,size=44):
    f=font(size);d.text(((W-d.textlength(text,font=f))/2,y),text,font=f,fill=INK)
def panel(im,src,y,w,h):
    scale=min(w/src.width,h/src.height)
    src=src.resize((int(src.width*scale),int(src.height*scale)),Image.Resampling.LANCZOS)
    im.paste(src,((W-src.width)//2,y+(h-src.height)//2))
def frame(t,lang):
    ja=lang=='ja';im=Image.new('RGB',(W,H),BG);d=ImageDraw.Draw(im)
    center(d,95,'居眠りガード' if ja else 'DROWSINESS GUARD',36)
    center(d,165,'作業中・勉強中、うとうとしちゃう人へ' if ja else 'KEEP NODDING OFF AT YOUR DESK?',32)
    center(d,270,'カメラで居眠りを検知' if ja else 'CAMERA DETECTS CLOSED EYES',66 if ja else 44)
    center(d,365,'音・振動でアラート' if ja else 'SOUND + VIBRATION ALERTS',58 if ja else 45)
    if t<2:
        panel(im,clip(web,9).crop((115,115,530,490)),555,930,1030)
        center(d,1610,'目を閉じ続ける → お知らせ' if ja else 'EYES STAY CLOSED → ALERT',40)
    elif t<14:
        panel(im,clip(web,t).crop((105,35,535,600)),525,910,1160)
        center(d,1705,'Web実画面・実際の検知結果' if ja else 'ACTUAL WEB APP · REAL DETECTOR OUTPUT',30)
    elif t<21:
        panel(im,clip(mobile,5+t-14),515,640,1180)
        center(d,1705,'iPhone幅のWeb表示 / iPhone実機ではありません' if ja else 'IPHONE-SIZED WEB VIEW · NOT AN IOS DEVICE',26)
    elif t<25:
        panel(im,clip(android,t-21).crop((0,37,324,465)),515,870,1160)
        center(d,1705,'Android実画面：秒数設定 / 顔入力の検証は未完了' if ja else 'ANDROID SETTINGS · FACE INPUT NOT YET VERIFIED',25)
    else:
        panel(im,clip(web,11.8).crop((105,35,535,600)),565,690,950)
        center(d,1550,'Webで試す / AndroidはGoogle Playへ' if ja else 'TRY WEB / FIND ANDROID ON GOOGLE PLAY',32)
        center(d,1625,'inemuri.toriumis.com',44)
    center(d,1800,'AI生成の架空人物・テスト映像入力' if ja else 'FICTIONAL AI FACE · PRERECORDED TEST INPUT',28)
    center(d,1850,'眠いときは休憩を。運転中の安全を保証するものではありません。' if ja else 'TAKE A BREAK WHEN SLEEPY. NOT A DRIVING SAFETY SYSTEM.',21)
    return im
for lang in ['ja','en']:
    p=subprocess.Popen(['ffmpeg','-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s','1080x1920','-r',str(FPS),'-i','-',
        '-f','lavfi','-i','anullsrc=r=44100:cl=stereo','-t',str(DURATION),'-c:v','libx264','-threads','2','-preset','fast','-crf','20','-pix_fmt','yuv420p','-r','30','-c:a','aac','-movflags','+faststart',str(OUT/f'detection-demo-{lang}.mp4')],stdin=subprocess.PIPE)
    for n in range(FPS*DURATION):p.stdin.write(frame(n/FPS,lang).tobytes())
    p.stdin.close()
    if p.wait():raise RuntimeError('encode failed')
    frame(0,lang).save(OUT/f'cover-{lang}.jpg',quality=94)
    print('Rendered',lang,flush=True)
