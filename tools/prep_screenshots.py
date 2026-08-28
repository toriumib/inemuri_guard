"""Make raw device captures acceptable to the Play Console.

Modern phones are 20:9, so a straight screenshot is 1080x2400 — an aspect
ratio of 2.22:1. Play rejects phone screenshots above 2:1, so every raw
capture has to be adjusted before upload.

Padding the sides is preferred over cropping: cropping would eat the bottom
navigation or the status hero, and the padding colour is sampled from the
screenshot's own background, so the result reads as a slightly wider app
rather than as a letterboxed image.

Run after capturing:  python tools/prep_screenshots.py
"""

import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
RAW = os.path.join(ROOT, "store_assets", "screenshots")
OUT = os.path.join(ROOT, "store_assets", "screenshots_play")

MAX_RATIO = 2.0
MIN_SIDE, MAX_SIDE = 320, 3840

os.makedirs(OUT, exist_ok=True)

for name in sorted(os.listdir(RAW)):
    if not name.lower().endswith(".png"):
        continue
    img = Image.open(os.path.join(RAW, name)).convert("RGB")
    w, h = img.size

    if h / w > MAX_RATIO:
        target_w = -(-h // int(MAX_RATIO))  # ceil, so the ratio lands under 2:1
        # Sample the app's own background from a corner well away from any
        # card or the status bar icons.
        bg = img.getpixel((4, h // 2))
        canvas = Image.new("RGB", (target_w, h), bg)
        canvas.paste(img, ((target_w - w) // 2, 0))
        img = canvas

    w, h = img.size
    ratio = max(w, h) / min(w, h)
    ok = MIN_SIDE <= min(w, h) and max(w, h) <= MAX_SIDE and ratio <= MAX_RATIO
    img.save(os.path.join(OUT, name), "PNG")
    print(f"{name}: {w}x{h} ratio={ratio:.2f} {'OK' if ok else 'STILL INVALID'}")

print(f"\nUpload the files in {os.path.relpath(OUT, ROOT)} to Play.")
