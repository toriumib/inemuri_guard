"""Build the 1024x500 Play Store feature graphic for 居眠りガード.

⚠️ It must show the real app. A previous app of ours was flagged by Play for
a feature graphic that was an abstract illustration rather than the in-app
experience, so this composites an actual screenshot of the nap timer next to
the icon and tagline instead of inventing artwork.

Play crops this image on some surfaces, so nothing important goes near the
edges and the text block stays comfortably inside.

Run: python tools/gen_feature_graphic.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
STORE = os.path.join(ROOT, "store_assets")
SHOTS = os.path.join(STORE, "screenshots")

W, H = 1024, 500
BG_TOP = (16, 20, 42)
BG_BOTTOM = (32, 26, 62)
AMBER = (255, 194, 75)
CORAL = (255, 107, 74)
CREAM = (247, 240, 226)
DIM = (155, 161, 201)

FONT_DIR = r"C:\Windows\Fonts"
BOLD = os.path.join(FONT_DIR, "YuGothB.ttc")
REG = os.path.join(FONT_DIR, "YuGothR.ttc")


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


img = Image.new("RGB", (W, H), BG_TOP)
d = ImageDraw.Draw(img)

# Vertical gradient ground — flat colour looks dead at this size.
for y in range(H):
    t = y / H
    d.line(
        [(0, y), (W, y)],
        fill=tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)),
    )

# Warm glow behind the phone so the screenshot doesn't float on flat navy.
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r in range(320, 0, -8):
    a = int(26 * (1 - r / 320))
    gd.ellipse([760 - r, 250 - r, 760 + r, 250 + r], fill=AMBER + (a,))
img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
d = ImageDraw.Draw(img)

# ── the real app, in a phone-ish frame ───────────────────────────────
shot = Image.open(os.path.join(SHOTS, "02_nap.png")).convert("RGB")
# Crop away the status bar and bottom nav so the timer itself fills the frame.
sw, sh = shot.size
shot = shot.crop((0, int(sh * 0.055), sw, int(sh * 0.80)))

target_h = 430
scale = target_h / shot.size[1]
shot = shot.resize((int(shot.size[0] * scale), target_h), Image.LANCZOS)

radius = 26
mask = Image.new("L", shot.size, 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, *[v - 1 for v in shot.size]], radius=radius, fill=255)

px, py = 700, (H - target_h) // 2
# Border, drawn first so it reads as a device edge.
d.rounded_rectangle(
    [px - 3, py - 3, px + shot.size[0] + 2, py + target_h + 2],
    radius=radius + 3,
    outline=(70, 78, 120),
    width=3,
)
img.paste(shot, (px, py), mask)

# ── icon + wordmark + tagline ────────────────────────────────────────
icon = Image.open(os.path.join(STORE, "play_icon_512.png")).convert("RGBA")
icon = icon.resize((104, 104), Image.LANCZOS)
img.paste(icon, (64, 96), icon)

d.text((188, 108), "居眠りガード", font=font(BOLD, 52), fill=CREAM)
d.text((190, 172), "DESK NAP GUARD", font=font(REG, 19), fill=DIM)

d.text((64, 258), "目を閉じたら、起こす。", font=font(BOLD, 40), fill=AMBER)

for i, line in enumerate(
    [
        "カメラが目の開閉を見て居眠りを検知",
        "研究にもとづく10分のパワーナップ",
        "映像も音声も端末の外に出ません",
    ]
):
    y = 330 + i * 42
    d.ellipse([66, y + 9, 78, y + 21], fill=CORAL)
    d.text((94, y), line, font=font(REG, 24), fill=CREAM)

out = os.path.join(STORE, "feature_graphic_1024x500.png")
img.save(out, "PNG")
print("wrote", os.path.relpath(out, ROOT), img.size)
