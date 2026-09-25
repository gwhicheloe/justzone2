"""Compose a captioned App Store frame: headline + subline over the brand
background, with the real app screenshot below. Output is App Store 6.5" size."""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BG = (5, 5, 13)
GREEN = (52, 199, 89)
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"

def frame(shot_path, headline, subline, out, eyebrow=None, W=1284, H=2778, shot_w=0.80, bleed=False):
    k = 1.0   # same type size on phone and iPad canvases (both are shown at similar scale)
    canvas = Image.new("RGB", (W, H), BG)
    # soft green glow behind the headline, like the website hero
    glow = Image.new("RGB", (W, H), BG)
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-300, -700, W + 300, int(900 * k)), fill=(18, 70, 38))
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    canvas = Image.blend(canvas, glow, 0.9)
    d = ImageDraw.Draw(canvas)

    # Every frame reserves the same header (room for an eyebrow, three headline
    # lines and two sub lines) and centres its own caption inside it, so the
    # phones sit at the same height across the whole set.
    fe = ImageFont.truetype(FONT, int(40 * k))
    fh = ImageFont.truetype(FONT, int(92 * k))
    fs = ImageFont.truetype(FONT, int(46 * k))
    le, lh, ls, gap = int(80 * k), int(112 * k), int(62 * k), int(16 * k)
    header_top, header_h = int(130 * k), le + 3 * lh + gap + 2 * ls
    hl, sl = headline.split("\n"), subline.split("\n")
    block = (le if eyebrow else 0) + len(hl) * lh + gap + len(sl) * ls
    y = header_top + (header_h - block) // 2
    if eyebrow:
        d.text((W / 2, y), eyebrow.upper(), font=fe, fill=GREEN, anchor="mt"); y += le
    for line in hl:
        d.text((W / 2, y), line, font=fh, fill=(255, 255, 255), anchor="mt"); y += lh
    y += gap
    for line in sl:
        d.text((W / 2, y), line, font=fs, fill=(170, 176, 170), anchor="mt"); y += ls
    y = header_top + header_h

    # the real screenshot, scaled to fit what's left, rounded like a device
    shot = Image.open(shot_path).convert("RGB")
    top = y + int(70 * k)
    avail_h = H - top - int(60 * k)
    sw = int(W * shot_w)
    sh = int(shot.height * sw / shot.width)
    if sh > avail_h and not bleed:   # iPad: let the device run off the bottom edge
        sh = avail_h
        sw = int(shot.width * sh / shot.height)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    r = int(sw * (0.11 if H / W > 1.6 else 0.04))
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), r, fill=255)
    x = (W - sw) // 2
    # hairline bezel
    bez = Image.new("RGB", (sw + 8, sh + 8), (60, 64, 70))
    bm = Image.new("L", (sw + 8, sh + 8), 0)
    ImageDraw.Draw(bm).rounded_rectangle((0, 0, sw + 8, sh + 8), r + 4, fill=255)
    canvas.paste(bez, (x - 4, top - 4), bm)
    canvas.paste(shot, (x, top), mask)
    canvas.save(out)

if __name__ == "__main__":
    frame(*sys.argv[1:6]) if len(sys.argv) > 5 else frame(*sys.argv[1:5])
