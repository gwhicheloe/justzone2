import os, sys; sys.path.insert(0, os.path.dirname(__file__))
# Frames the raw simulator captures in docs/app-store-screenshots/1.0.2 into
# captioned App Store images.  Usage: python3 scripts/store-frames/set.py iphone|ipad
ROOT = os.path.join(os.path.dirname(__file__), "../../docs/app-store-screenshots/1.0.2")
from frame import frame, frame_cards
CAPS = [  # (raw name, eyebrow, headline, subline) — in App Store order; the first three show in search.
          # Chart screens (workout, progress, summary) are kept apart so similar charts never sit side by side.
 ("workout",  "Indoor cycling", "Your smart trainer,\nsteered by your\nheart rate", "Power adjusts every second to\nhold you in Zone 2"),
 ("setup",    None, "Pairs with your\nsmart trainer",  "Any FTMS trainer, plus Apple Watch\nor a chest strap"),
 ("progress", None, "Measure your fitness\nwithout FTP tests", "Same heart rate, more power:\nwatch your aerobic fitness grow"),
 ("zones",    None, "Set your zones once",               "Zone 2 drives every ride"),
 ("summary",  None, "Every ride, straight\nto Strava",     "Power, heart rate, cadence and\ndistance — uploaded for you"),
]
# The progress frame shows the app's two History charts large (no phone): on a
# full-phone capture the chart fills only the top half and is too small to read.
CARDS = [os.path.join(os.path.dirname(__file__), "../../website/images/progress/history-trend.png"),
         os.path.join(os.path.dirname(__file__), "../../website/images/progress/history-bubbles.png")]
def build(raw_dir, out_dir, W, H, shot_w, prefix, bleed=False, skip=(), whole=()):
    caps=[c for c in CAPS if c[0] not in skip]
    for i,(n,eb,hd,sub) in enumerate(caps, 1):
        out=f"{out_dir}/{prefix}{i}-{n}.png"
        if n == "progress":
            frame_cards(CARDS, hd, sub, out, eb, W=W, H=H, card_w=0.88 if H / W > 1.6 else 0.70)
        else:
            frame(f"{raw_dir}/{n}.png", hd, sub, out, eb, W=W, H=H, shot_w=shot_w, bleed=bleed and n not in whole)
        print(" ", out.split('/')[-1])

if __name__ == "__main__":
    kind=sys.argv[1]
    if kind=="iphone": build(f"{ROOT}/raw-iphone", ROOT, 1284, 2778, 0.80, "iphone-")
    else:              # iPad: the Strava shot must show its upload button, so it is shown whole rather than bled.
        build(f"{ROOT}/raw-ipad", ROOT, 2064, 2752, 0.80, "ipad-", bleed=True, whole=("summary",))
