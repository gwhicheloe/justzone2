# App Store listing copy

Drafted 2026-09-23, ready for the **1.0.1** submission. Nothing here is live yet —
description, keywords and screenshots are version metadata and need a new version
plus a build, so they ship with the next release. (Promotional text is different:
it updates on the live version with no review, and was changed on 2026-09-23.)

---

## Why the current 1.0 description needs replacing

The live description sells the app as a **manual** tool:

> "Set your target power—the KICKR handles the rest in ERG mode"
> "Monitor your heart rate to stay in your Zone 2 range"

A buyer reads that as: set watts, watch your own heart rate, adjust it yourself —
which is a fixed-watt ERG app, i.e. what every competitor already sells. The PID
controller, the single differentiating feature and the thing the website leads
with, is **absent from the listing entirely.** So are iPad, Apple Watch and FTMS.

Three fixes:

1. **Lead with the differentiator.** The app steers the trainer from heart rate.
   Nobody else does this. It should be the first sentence, not omitted.
2. **Broaden past "Wahoo KICKR".** Any FTMS trainer works. Saying so widens both
   the buyer pool and the search surface. Keep the KICKR name in there too — it
   is what people search — but stop implying it is the only supported trainer.
3. **Fix the closing line.** It currently ends on
   *"Requires a Wahoo KICKR ... and a Bluetooth heart rate monitor"* — a barrier
   as the final impression, and no longer accurate now that heart rate can come
   from an Apple Watch or AirPods Pro 3.

Deliberately **not** included, per George (2026-09-23): Demo Mode (built for App
Review, not a user-facing feature — promoting it invites people to expect a free
trial and find a simulation) and Family Sharing (table stakes; most paid apps
have it, so it reads as filler here. It stays on the website's Zwift page, where
it is doing different work — a contrast against Zwift having no household plan).

---

## Promotional text — LIVE as of 2026-09-23 (141/170)

> Most apps hold your power. JustZone2 holds your heart rate, adjusting trainer resistance every second to keep you in Zone 2. No subscription.

---

## Description — draft for 1.0.1

```
Most indoor cycling apps hold your power. JustZone2 holds your heart rate.

Set your zone, start pedalling, and the app takes over. It reads your heart rate every second and continuously adjusts your trainer's resistance to keep you exactly where you meant to be — no watching the numbers, no reaching for the dial halfway through. Just the right effort, for the whole ride.

ADAPTIVE ZONE TARGETING
• A PID controller trims trainer resistance in real time to hold your heart rate in Zone 2
• Handles cardiac drift automatically — as you tire and your heart rate climbs, the power eases back to match
• Optional warm-up and cool-down phases
• Prefer to ride to a number? Run it as a straightforward fixed-power ERG session instead

WORKS WITH YOUR GEAR
• Any smart trainer supporting the FTMS Bluetooth standard, including the Wahoo KICKR range
• Heart rate from an Apple Watch, a Bluetooth chest strap, an optical arm band, or AirPods Pro 3
• Universal — iPhone, iPad and Apple Watch, with a Watch complication for a glance mid-ride

YOUR DATA, WHERE YOU WANT IT
• One-tap upload to Strava with power, heart rate, cadence, distance and calories
• Saves to Apple Health as a full workout
• Live Activity keeps your stats on the Lock Screen and in the Dynamic Island
• Workout history with charts, so you can watch the aerobic base actually build

BUILT TO GET OUT OF THE WAY
• Large, readable metrics you can see from the bars
• No ads, no upsells, nothing to sign up for
• No subscription — one purchase, yours for good
• Interrupted mid-session? It picks up exactly where you left off

WHY ZONE 2
Easy aerobic work is what builds the engine: more mitochondria, more capillaries, better fat metabolism, and a foundation broad enough to carry everything you stack on top. It is the bulk of what elite endurance athletes actually do all year.

Understanding that has never been the hard part. Holding the discipline to ride easy enough, for long enough, is the hard part — and that is precisely the bit JustZone2 takes off your hands.

MADE FOR
• Cyclists building an aerobic base through the winter
• Athletes who want recovery days to stay genuinely easy
• Anyone after structured indoor training without a games engine attached

REQUIREMENTS
A smart trainer that supports FTMS, and a heart-rate source — Apple Watch, chest strap, optical arm band or AirPods Pro 3.

Set your zone once. Every ride after that, just press start.
```

---

## Keywords

Currently live (84/100):

```
zone 2,cycling,indoor,trainer,kickr,erg,heart rate,aerobic,endurance,workout,fitness
```

Proposed (93/100):

```
cycling,indoor,trainer,turbo,kickr,erg,ftms,heart rate,aerobic,endurance,cadence,watts,base
```

Reasoning — and one judgement call worth checking:

- **Dropped "zone 2" and "workout"/"fitness".** Apple indexes the app name and
  subtitle alongside the keyword field, and "Zone 2 Training Made Simple" is the
  subtitle, so "zone 2" is already covered and repeating it wastes characters.
  *This is the judgement call:* it is standard ASO practice, but if you would
  rather not risk the single most important term on it, keep `zone 2` and drop
  `base` and `watts` instead.
- **Added "turbo"** — "turbo trainer" is the normal UK phrasing and is missing.
- **Added "ftms"** — low volume, but it is how people search when checking
  compatibility, and we now genuinely support it.
- **Added "cadence", "watts", "base"** — real terms riders use.
- **Did not add "wahoo" or "strava".** Both were deliberately removed during the
  4.1(b) Copycats round; do not put them back. "kickr" was already live through
  that review and stays.

---

## Screenshots — ready in `docs/app-store-screenshots/1.0.1/`

Captioned frames replacing the raw captures. The first three show in search
results, so they carry the "this is a cycling app" message.

| # | iPhone | iPad | Caption |
|---|---|---|---|
| 1 | ✓ | ✓ | *Indoor cycling* — **Your smart trainer, steered by your heart rate** |
| 2 | ✓ | ✓ | **Pairs with your smart trainer** — any FTMS trainer, plus Apple Watch or a chest strap |
| 3 | ✓ | ✓ | **Every ride, straight to Strava** — power, heart rate, cadence and distance |
| 4 | ✓ | ✓ | **Set your zones once** — Zone 2 drives every ride |
| 5 | ✓ | — | **Every ride, in one place** (left off iPad: nearly empty at that width) |

- The Strava frame is staged: demo rides never upload, so it shows the real
  Summary screen in its uploaded state on a synthetic 60-minute ride.
- No "KICKR" in the images and no Strava logo in the captions — deliberate,
  given the two 4.1(b) rounds.
- Watch screenshots unchanged.
- Regenerate: `python3 scripts/store-frames/set.py iphone|ipad`.

## Also needed in the same submission

- **What's New** is empty and will need copy for 1.0.1.
