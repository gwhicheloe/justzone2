#!/usr/bin/env python3
"""Build the paperback cover and the Kindle cover from George's painting (cover/power-in-abstraction.jpg).

  python3 tools/cover.py [--paper white|cream] [--pages N]

The page count comes from review/proof-6x9.pdf unless given, so build the interior first. The back-cover text is
cover/back.md. Writes:
  review/cover-paperback-PAPER.pdf  the print cover: back, spine and front as one CMYK image at 600 dpi
  review/cover-kindle.jpg           the ebook's marketing cover, front only, 1707 x 2560 RGB
  review/cover-guides.png           a preview with the trim, folds, safe areas and barcode box drawn on (never upload)

KDP's rules, from Create a Paperback Cover, Barcodes and Cover Image Guidelines for Kindle eBooks (22 October 2026):
one PDF, back + spine + front as one image; 0.125 in bleed on the outside edges; spine = pages x 0.002252 in
(white) or x 0.0025 in (cream); spine text only above 79 pages and at least 0.0625 in from each fold; cover text
at least 0.125 in inside the trim; images at 300 dpi or more, CMYK recommended, no colour profile, one colour space,
transparencies flattened; nothing in the barcode box (KDP prints its own barcode, 2 x 1.2 in, at least 0.25 in
from the spine and trim). Kindle: JPEG preferred, 2560 x 1600 recommended, RGB, no spine or barcode.

The painting is a Midjourney image George made on a paid plan in May 2023 (George, 22 October 2026), so the
KDP form's AI-content question is answered yes for images. The cover's text matches front/title.md, as KDP requires.
"""
import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageCms, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
BOOK = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from render import local_fonts  # noqa: E402

PAINTING = os.path.join(BOOK, "cover", "power-in-abstraction.jpg")
BACK_TEXT = os.path.join(BOOK, "cover", "back.md")
DPI = 600
CSS_DPI = 96  # Chrome's px per inch; the screenshot is taken at DPI / CSS_DPI device pixels per px
BLEED, TRIM_W, TRIM_H = 0.125, 6.0, 9.0
SPINE_PER_PAGE = {"white": 0.002252, "cream": 0.0025}
CHARCOAL = (18, 18, 20)
YELLOW = (250, 214, 60)
DARK_EMERALD = (8, 107, 61)  # the app's deepest green, the foot of the splash screen's "2"
APP_GREEN = (76, 199, 82)    # the app's accent colour
# The title, chosen by George on 22 October 2026: Saira ExtraBold Italic (SIL Open Font License), stacked top left
# in dark emerald. The bright app green cannot be read on the pale paint there, so it is used only on the dark spine.
# PAINT is one colour, or several for a gradient. The size keeps "Zone 2?" 2.75 in wide, clear of the helmet.
TITLE_FONT_URL = "https://fonts.googleapis.com/css2?family=Saira:ital,wght@1,800"
TITLE_FONT, TITLE_SIZE, SPINE_TITLE_SIZE = "italic 800 {size}in/0.92 'Saira'", 0.73, 0.30
TITLE_PAINT, SPINE_TITLE_PAINT = [DARK_EMERALD], [APP_GREEN]
AUTHOR_COLOUR = YELLOW
FADE_START, FADE_LENGTH = 0.66, 0.16  # the dark fade behind the subtitle and name, as fractions of the trimmed height
SPINE_SHADOW = 0.35                   # inches over which the front darkens into the spine


def paint_css(colours, towards):
    """CSS that fills text with one colour, or with a gradient running towards the glyphs' feet ('bottom' on the
    front; 'left' on the spine, where the text is turned so its tops face the front cover)."""
    if len(colours) == 1:
        return f"color: rgb{tuple(colours[0])};"
    stops = ", ".join(f"rgb{tuple(c)}" for c in colours)
    return (f"background: linear-gradient(to {towards}, {stops}); -webkit-background-clip: text; "
            "background-clip: text; color: transparent;")


def title_font_css():
    """@font-face for the title font, fetched once into book/fonts/ (git-ignored) like the book's other fonts."""
    path = os.path.join(BOOK, "fonts", "saira-extrabold-italic.ttf")
    if not os.path.exists(path):
        import re
        import urllib.request
        get = lambda u: urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "just-zone-2-book-research"})).read()
        url = re.findall(r"url\((https://[^)]+\.ttf)\)", get(TITLE_FONT_URL).decode())[-1]
        open(path, "wb").write(get(url))
    return f"@font-face {{ font-family: 'Saira'; font-style: italic; font-weight: 800; src: url(file://{path}); }}"


def title_lines():
    """Title, subtitle and author from front/title.md, so the cover always matches the title page."""
    lines = [l.strip() for l in open(os.path.join(BOOK, "front", "title.md"), encoding="utf-8")
             if l.strip() and not l.startswith("<!--")]
    return lines[0].lstrip("# "), lines[1].lstrip("# "), lines[2]


def back_html(author):
    """The back-cover text from cover/back.md as two pieces of HTML: the headline, paragraphs and list; and the note
    about the author after ---, which sits at the foot beside the barcode."""
    import html
    import re
    text = re.sub(r"<!--.*?-->", "", open(BACK_TEXT, encoding="utf-8").read(), flags=re.S)
    body, _, note = text.partition("\n---\n")
    inline = lambda s: re.sub(r"\*(.+?)\*", r"<i>\1</i>", html.escape(s, quote=False))
    out = []
    for block in body.strip().split("\n\n"):
        lines = block.strip().splitlines()
        if all(l.startswith("# ") for l in lines):  # one "# " line per line of the headline
            out.append("<h1>" + "<br>".join(inline(l[2:]) for l in lines) + "</h1>")
        elif all(l.startswith("- ") for l in lines):
            out.append("<ul>" + "".join(f"<li>{inline(l[2:])}</li>" for l in lines) + "</ul>")
        else:
            out.append(f"<p>{inline(' '.join(lines))}</p>")
    return "\n".join(out), inline(" ".join(note.split())).replace(author, f"<b>{author}</b>", 1)


def page_count():
    import pypdf
    return len(pypdf.PdfReader(os.path.join(BOOK, "review", "proof-6x9.pdf")).pages)


def geometry(paper, pages):
    """Everything in inches, measured from the top left of the full cover including bleed."""
    spine = pages * SPINE_PER_PAGE[paper]
    g = {"spine": spine, "W": 2 * BLEED + 2 * TRIM_W + spine, "H": 2 * BLEED + TRIM_H}
    g["back_x"] = BLEED                    # back cover's trim, left edge
    g["spine_x"] = BLEED + TRIM_W          # back fold
    g["front_x"] = BLEED + TRIM_W + spine  # front fold
    return g


def px(inches):
    return round(inches * DPI)


def background(g, spine_edge=True):
    """The painting on the front, charcoal on the spine and back, with the fades baked in (KDP wants no transparency).
    The Kindle cover has no spine, so it is made without the shadow at the fold (spine_edge=False)."""
    W, H = px(g["W"]), px(g["H"])
    out = Image.new("RGB", (W, H), CHARCOAL)
    src = Image.open(PAINTING).convert("RGB")
    # The front panel runs from the front fold to the outer bleed and over the full height with bleed.
    pw, ph = px(TRIM_W + BLEED), H
    cw = round(src.height * (TRIM_W + BLEED) / g["H"])
    # Centre the visible 6 in where the approved mock-up had it (painting x 905 to 3636 for 6 x 9 in).
    x0 = round(2270.5 - cw * TRIM_W / (TRIM_W + BLEED) / 2)
    panel = src.crop((x0, 0, x0 + cw, src.height)).resize((pw, ph), Image.LANCZOS)
    # Dark fade at the foot, behind the subtitle and name.
    # Left edge: the painting darkens into the spine colour, so a spine that binds up to 1/8 in off shows
    # as a slightly wider or narrower shadow, not a hard line (KDP advises against hard spine edges).
    shade = Image.new("L", (pw, ph), 0)
    d = ImageDraw.Draw(shade)
    for y in range(ph):
        t = max(0.0, (y / DPI - BLEED - FADE_START * TRIM_H) / (FADE_LENGTH * TRIM_H))
        d.line([(0, y), (pw, y)], fill=int(225 * min(1.0, t ** 1.1)))
    if spine_edge:
        edge = Image.new("L", (pw, ph), 0)
        d = ImageDraw.Draw(edge)
        for x in range(px(SPINE_SHADOW)):
            d.line([(x, 0), (x, ph)], fill=int(255 * (1 - x / px(SPINE_SHADOW)) ** 1.6))
        shade = ImageChops.lighter(shade, edge)
    panel = Image.composite(Image.new("RGB", (pw, ph), CHARCOAL), panel, shade)
    out.paste(panel, (px(g["front_x"]), 0))
    return out


def text_html(g, bg_path):
    """The cover's type, set by Chrome in the book's own fonts over the background, one CSS px per 1/96 in."""
    title, subtitle, author = title_lines()
    sub1, sub2 = subtitle.split(", ", 1)
    first, rest = title.split(" ", 1)  # stacked: "Just" over "Zone 2?"
    back_main, about = back_html(author)
    fx, sx, W, H = g["front_x"], g["spine_x"], g["W"], g["H"]
    return f"""<!doctype html><meta charset="utf-8"><style>
{local_fonts()}
{title_font_css()}
html, body {{ margin: 0; padding: 0; background: rgb{CHARCOAL}; }}
.page {{ position: relative; width: {W}in; height: {H}in; overflow: hidden; }}
.page > img {{ position: absolute; left: 0; top: 0; width: {W}in; height: {H}in; }}
.front {{ position: absolute; left: {fx + 0.40}in; width: {TRIM_W - 0.80}in; color: #fff; }}
.title {{ font: {TITLE_FONT.format(size=TITLE_SIZE)}; left: {fx + 0.38}in; top: {BLEED + 0.36}in; }}
.title span {{ {paint_css(TITLE_PAINT, "bottom")} }}
.sub {{ font: 400 0.20in/0.30in 'IBM Plex Sans'; top: {BLEED + 7.62}in; color: rgb(235, 232, 225); }}
.author {{ font: 600 0.17in/1 'IBM Plex Sans'; top: {BLEED + 8.42}in; color: rgb{AUTHOR_COLOUR}; letter-spacing: 0.02em; }}
.spine {{ position: absolute; left: {sx}in; width: {g['spine']}in; top: {BLEED + 0.6}in; height: {TRIM_H - 1.2}in;
         writing-mode: vertical-rl; display: flex; justify-content: space-between; align-items: center; }}
.spine .t {{ font: {TITLE_FONT.format(size=SPINE_TITLE_SIZE)}; line-height: 1; {paint_css(SPINE_TITLE_PAINT, "left")} }}
.spine .a {{ font: 600 0.12in/1 'IBM Plex Sans'; color: rgb{AUTHOR_COLOUR}; letter-spacing: 0.06em; }}
.back {{ position: absolute; left: {BLEED + 0.6}in; top: {BLEED + 0.6}in; width: {TRIM_W - 1.2}in;
        font: 400 0.152in/1.45 'IBM Plex Sans'; color: rgb(235, 232, 225); }}
.back h1 {{ font: {TITLE_FONT.format(size=0.36)}; line-height: 1.02; margin: 0 0 0.28in; {paint_css(SPINE_TITLE_PAINT, "bottom")} }}
.back p {{ margin: 0 0 0.14in; }}
.back ul {{ margin: 0 0 0.16in; padding: 0; list-style: none; }}
.back li {{ position: relative; padding-left: 0.21in; margin-bottom: 0.04in; }}
.back li::before {{ content: ""; position: absolute; left: 0.02in; top: 0.075in; width: 0.075in; height: 0.075in;
                   background: rgb{APP_GREEN}; transform: skewX(-12deg); }}
.about {{ position: absolute; left: {BLEED + 0.6}in; bottom: {BLEED + 0.45}in; width: 2.95in;
         font: 400 0.122in/1.45 'IBM Plex Sans'; color: rgb(190, 188, 182); }}
.about b {{ font-weight: 600; color: rgb{AUTHOR_COLOUR}; }}
</style>
<div class="page"><img src="file://{bg_path}">
<div class="back">{back_main}</div>
<div class="about">{about}</div>
<div class="front title"><span>{first}<br>{rest}</span></div>
<div class="front sub">{sub1},<br>{sub2}</div>
<div class="front author">{author.upper()}</div>
<div class="spine"><span class="t">{title}</span><span class="a">{author.upper()}</span></div>
</div>"""


def chrome_png(html_path, png_path, w_in, h_in):
    """Screenshot the page at DPI. The window is rounded up to whole CSS px and the extra cropped off."""
    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    scale = DPI / CSS_DPI
    win = (-(-w_in * CSS_DPI // 1), -(-h_in * CSS_DPI // 1))
    subprocess.run([chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--virtual-time-budget=20000",
                    "--allow-file-access-from-files", f"--force-device-scale-factor={scale}",
                    f"--window-size={int(win[0])},{int(win[1])}", f"--screenshot={png_path}", "file://" + html_path],
                   check=True, capture_output=True)
    img = Image.open(png_path).convert("RGB")
    want = (px(w_in), px(h_in))
    if img.width < want[0] or img.height < want[1]:
        sys.exit(f"Chrome made a {img.size} screenshot, smaller than the {want} cover")
    return img.crop((0, 0) + want)


def to_cmyk(img):
    """sRGB to CMYK through macOS's Generic CMYK profile; the PDF carries no profile, as KDP asks."""
    srgb = ImageCms.createProfile("sRGB")
    cmyk = ImageCms.getOpenProfile("/System/Library/ColorSync/Profiles/Generic CMYK Profile.icc")
    return ImageCms.profileToProfile(img, srgb, cmyk, renderingIntent=ImageCms.Intent.PERCEPTUAL, outputMode="CMYK")


def check_barcode_box(img, g):
    """KDP rejects a cover with anything in the barcode box, so stop if the back's text reaches it (0.1 in to spare)."""
    x1, y1 = g["spine_x"] - 0.25, g["H"] - BLEED - 0.25
    box = img.crop((px(x1 - 2 - 0.1), px(y1 - 1.2 - 0.1), px(x1), px(y1)))
    marks = ImageChops.difference(box, Image.new("RGB", box.size, CHARCOAL)).convert("L").point(lambda v: 255 * (v > 6))
    if marks.getbbox():
        sys.exit("The back-cover text runs into KDP's barcode box: shorten cover/back.md or set it smaller.")


def guides(img, g, pages):
    """A small preview with KDP's lines drawn on: trim (red), folds (blue), safe areas (green), barcode box (orange)."""
    s = 100 / DPI
    p = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    d = ImageDraw.Draw(p)
    q = lambda v: round(v * 100)
    W, H, b = g["W"], g["H"], BLEED
    d.rectangle([q(b), q(b), q(W - b), q(H - b)], outline=(230, 40, 40), width=2)
    for x in (g["spine_x"], g["front_x"]):
        d.line([(q(x), 0), (q(x), q(H))], fill=(40, 120, 240), width=2)
    for x in (g["spine_x"] + 0.0625, g["front_x"] - 0.0625):
        d.line([(q(x), 0), (q(x), q(H))], fill=(40, 200, 90), width=1)
    for x0, x1 in ((b, g["spine_x"]), (g["front_x"], W - b)):
        d.rectangle([q(x0 + 0.125), q(b + 0.125), q(x1 - 0.125), q(H - b - 0.125)], outline=(40, 200, 90), width=1)
    bx1, by1 = g["spine_x"] - 0.25, H - b - 0.25
    d.rectangle([q(bx1 - 2), q(by1 - 1.2), q(bx1), q(by1)], outline=(255, 150, 0), width=2)
    d.text((q(bx1 - 1.9), q(by1 - 1.1)), "KDP barcode", fill=(255, 150, 0))
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--paper", choices=SPINE_PER_PAGE, default="white")
    ap.add_argument("--pages", type=int)
    a = ap.parse_args()
    pages = a.pages or page_count()
    if pages <= 79:
        sys.exit("KDP prints spine text only on books of more than 79 pages; this cover has spine text.")
    g = geometry(a.paper, pages)
    review = os.path.join(BOOK, "review")
    def render(spine_edge):
        with tempfile.TemporaryDirectory() as tmp:
            bg = os.path.join(tmp, "background.png")
            background(g, spine_edge).save(bg)
            page = os.path.join(tmp, "cover.html")
            open(page, "w", encoding="utf-8").write(text_html(g, bg))
            return chrome_png(page, os.path.join(tmp, "shot.png"), g["W"], g["H"])
    rgb = render(spine_edge=True)
    check_barcode_box(rgb, g)
    pdf = os.path.join(review, f"cover-paperback-{a.paper}.pdf")
    to_cmyk(rgb).save(pdf, "PDF", resolution=DPI, quality=95)
    # The trimmed front at 2560 px tall. KDP recommends 1600 x 2560 (1.6:1) but accepts any shape; cutting the
    # 1.5:1 front down to 1.6:1 would crowd the title, so the Kindle cover keeps the paperback's proportions.
    front = render(spine_edge=False).crop((px(g["front_x"]), px(BLEED), px(g["front_x"] + TRIM_W), px(BLEED + TRIM_H)))
    front.resize((round(2560 * TRIM_W / TRIM_H), 2560), Image.LANCZOS).save(
        os.path.join(review, "cover-kindle.jpg"), quality=92)
    guides(rgb, g, pages).save(os.path.join(review, "cover-guides.png"))
    print(f"Cover for {pages} pages on {a.paper} paper: spine {g['spine']:.3f} in, full cover {g['W']:.3f} x {g['H']:.3f} in "
          f"at {DPI} dpi ({px(g['W'])} x {px(g['H'])} px). PDF {os.path.getsize(pdf) / 1e6:.1f} MB: {pdf}")


if __name__ == "__main__":
    main()
