"""Generate the launcher icons for 居眠りガード.

The mark is an open, alert eye — the thing the app actually watches — drawn
in the app's own palette (amber iris ring and coral pupil on deep indigo).

Two rules learned the hard way on a previous app:
  * Adaptive icons are masked to a circle/squircle by the launcher, so the
    artwork must sit inside the centre ~66% "safe zone" or the edges get
    sliced off. The foreground layer here is drawn well inside that.
  * No text in the launcher icon. At 48px it turns to mud, and the launcher
    already prints the app name underneath.

Run: python tools/gen_icons.py
"""

import math
import os

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "store_assets")

BG = (20, 26, 56, 255)  # deep indigo, matches the app's dark surface
AMBER = (255, 194, 75, 255)  # --accent-nap (dark theme)
CORAL = (255, 107, 74, 255)  # --accent-alert (dark theme)
HILITE = (255, 250, 240, 255)
SCLERA = (247, 240, 226, 255)  # warm off-white, borrowed from the light theme

# Supersample everything, then downscale — gives clean edges without needing
# a real vector rasteriser.
SS = 4


def lens_points(cx, cy, half_w, half_h, steps=200):
    """Outline of an almond/lens eye shape.

    The lens is the overlap of two circles. Given the half-width `a` and
    half-height `h` we want, the circle radius that produces it is
    R = (a^2 + h^2) / (2h) — derived from R - sqrt(R^2 - a^2) = h.
    """
    a, h = half_w, half_h
    r = (a * a + h * h) / (2 * h)
    c = math.sqrt(max(r * r - a * a, 0.0))
    upper, lower = [], []
    for i in range(steps + 1):
        x = -a + (2 * a) * i / steps
        dy = math.sqrt(max(r * r - x * x, 0.0)) - c
        upper.append((cx + x, cy - dy))
        lower.append((cx + x, cy + dy))
    return upper + lower[::-1]


def draw_eye(size, inset=0.0, with_bg=False, rounded=False):
    """Render the eye mark on a `size`x`size` canvas.

    `inset` shrinks the mark (used to keep the adaptive foreground inside the
    launcher's safe zone).
    """
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if with_bg:
        if rounded:
            d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=BG)
        else:
            d.rectangle([0, 0, s, s], fill=BG)

    cx = cy = s / 2
    scale = 1.0 - inset
    half_w = s * 0.33 * scale
    half_h = s * 0.20 * scale
    stroke = s * 0.055 * scale

    outer = lens_points(cx, cy, half_w, half_h)
    inner = lens_points(cx, cy, half_w - stroke * 1.15, half_h - stroke)

    # Sclera fills the inside of the lens, so the corners read as an eye
    # rather than as holes punched through to the background.
    sclera = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(sclera).polygon(inner, fill=SCLERA)
    img.alpha_composite(sclera)

    # Iris, clipped to that same lens interior. A real iris disappears behind
    # the lids; letting the circle spill past the outline reads as a ball
    # sitting on a leaf rather than as an eye.
    iris = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    idr = ImageDraw.Draw(iris)
    iris_r = half_h * 0.95
    idr.ellipse([cx - iris_r, cy - iris_r, cx + iris_r, cy + iris_r], fill=CORAL)
    pupil_r = iris_r * 0.46
    idr.ellipse(
        [cx - pupil_r, cy - pupil_r, cx + pupil_r, cy + pupil_r],
        fill=(26, 14, 8, 255),
    )
    # Specular highlight — the small thing that makes an eye read as awake
    # rather than as a camera lens.
    hr = iris_r * 0.22
    hx, hy = cx - iris_r * 0.30, cy - iris_r * 0.34
    idr.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=HILITE)

    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).polygon(inner, fill=255)
    iris.putalpha(ImageChops.multiply(iris.getchannel("A"), mask))
    img.alpha_composite(iris)

    # Eye outline last, so it sits cleanly over the clipped iris. Drawn as a
    # filled lens with the inside knocked out, which keeps the stroke even
    # around the sharp corners where a plain polygon outline breaks up.
    ring = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.polygon(outer, fill=AMBER)
    rd.polygon(inner, fill=(0, 0, 0, 0))
    img.alpha_composite(ring)

    return img.resize((size, size), Image.LANCZOS)


def write(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print("wrote", os.path.relpath(path, ROOT))


# Launcher densities. Legacy icons are 48dp, adaptive layers are 108dp.
DENSITIES = {
    "mdpi": 1,
    "hdpi": 1.5,
    "xhdpi": 2,
    "xxhdpi": 3,
    "xxxhdpi": 4,
}

for name, mult in DENSITIES.items():
    legacy = int(48 * mult)
    adaptive = int(108 * mult)
    folder = os.path.join(RES, f"mipmap-{name}")
    # Legacy (pre-API 26): the composed icon, rounded so it looks intentional
    # on launchers that don't apply their own mask.
    write(draw_eye(legacy, with_bg=True, rounded=True), os.path.join(folder, "ic_launcher.png"))
    # Adaptive foreground: transparent, mark pulled well inside the safe zone.
    write(draw_eye(adaptive, inset=0.30), os.path.join(folder, "ic_launcher_foreground.png"))

# Play Store listing icon. No text: Play prints the app name beside the icon,
# so lettering here only competes with the mark at small sizes.
write(draw_eye(512, with_bg=True, rounded=True), os.path.join(STORE, "play_icon_512.png"))

print("done")
