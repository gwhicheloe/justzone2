import os, sys; sys.path.insert(0, os.path.dirname(__file__))
# Frames the raw simulator captures in docs/app-store-screenshots/1.0.1 into
# captioned App Store images.  Usage: python3 scripts/store-frames/set.py iphone|ipad
ROOT = os.path.join(os.path.dirname(__file__), "../../docs/app-store-screenshots/1.0.1")
from frame import frame
CAPS = [  # (raw name, eyebrow, headline, subline)
 ("workout",  "Indoor cycling", "Your smart trainer,\nsteered by your\nheart rate", "Power adjusts every second to\nhold you in Zone 2"),
 ("setup",    None, "Pairs with your\nsmart trainer",  "Any FTMS trainer, plus Apple Watch\nor a chest strap"),
 ("summary",  None, "Every ride, straight\nto Strava",     "Power, heart rate, cadence and\ndistance — uploaded for you"),
 ("zones",    None, "Set your zones once",               "Zone 2 drives every ride"),
 ("hist_list",None, "Every ride,\nin one place",          "Duration, power and heart rate\nat a glance"),
]
def build(raw_dir, out_dir, W, H, shot_w, prefix, bleed=False, skip=(), whole=()):
    caps=[c for c in CAPS if c[0] not in skip]
    for i,(n,eb,hd,sub) in enumerate(caps, 1):
        out=f"{out_dir}/{prefix}{i}-{n}.png"
        frame(f"{raw_dir}/{n}.png", hd, sub, out, eb, W=W, H=H, shot_w=shot_w, bleed=bleed and n not in whole)
        print(" ", out.split('/')[-1])
if __name__ == "__main__":
    kind=sys.argv[1]
    if kind=="iphone": build(f"{ROOT}/raw-iphone", ROOT, 1284, 2778, 0.80, "iphone-")
    else:              # iPad: History is nearly empty at iPad width, so it is left out; the Strava
        # shot must show its upload button, so it is shown whole rather than bled.
        build(f"{ROOT}/raw-ipad", ROOT, 2064, 2752, 0.80, "ipad-", bleed=True, skip=("hist_list",), whole=("summary",))
