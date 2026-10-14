#!/usr/bin/env python3
"""Build the outline page (book/review/outline.html) from the chapter list below.

  python3 book/tools/outline.py

The page is published as the "Just Zone 2? Outline" artifact. Edit the data here when
chapters are added, moved or drafted; styles live in tools/outline_head.html.
"""
import html
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "review", "outline.html")
DATE = "11 October 2026"
DRAFT_URL = "https://claude.ai/artifact/7897dncKjTc7fkjLcHx4KJ"

# (number, title, question, covers, key sources, target words, drafted words or 0, note)
PARTS = [(None,
  None,
  None,
  'front',
  [('Intro',
    'Why ask the question',
    'Why does a cyclist need a book about riding slowly?',
    ["How I came to Zone 2, and what it did and didn't do for me",
     'The claims on social media and podcasts set against what studies actually show',
     'How the book is organised and how it grades evidence'],
    '',
    3000,
    1870,
    'Kept easy-going on purpose; to revisit at the end')]),
 ('Part I',
  'The engine',
  'What limits endurance, how training changes it, and how to judge the evidence.',
  'neutral',
  [('1',
    'What limits endurance',
    'What decides how much power you can hold for an hour, or for five?',
    ["Joyner and Coyle's model: VO₂max, the fraction of it you can sustain, and efficiency",
     'The power–duration curve, critical power and W′',
     'Durability as a fourth factor, and why the older model left it out'],
    'Joyner & Coyle 2008 · Bassett & Howley 2000 · Burnley & Jones 2018 · Maunder et al. 2021',
    5500,
    3460,
    ''),
   ('2',
    'How bodies adapt to training',
    'How does a ride, repeated, become a bigger heart, more blood and more mitochondria?',
    ['The Dallas bed-rest study: three weeks in bed against thirty years of ageing',
     'A session as a disturbance: ATP, the signals it sets off, and PGC-1α',
     'Seven sessions, nine biopsies: how bursts of signal add up to protein',
     'What changes in muscle, blood and heart, how fast, and how fast it goes',
     'Starting late, and why the same training gives different results'],
    'McGuire et al. 2001 · Perry et al. 2010 · Montero et al. 2015 · Howden et al. 2018 · Coyle et al. 1984 · Bouchard et al. 1999',
    6000,
    4910,
    ''),
   ('3',
    'Effort, pain and the brain',
    'What do the brain and nerves contribute, and can some people simply suffer more?',
    ["What makes you stop: the muscle, or the brain's reading of it",
     'Effort and pain as different things',
     'Whether pain tolerance differs between people and whether training changes it',
     'What professionals show, and how much is held back'],
    "Amann et al. 2009 · Marcora et al. 2009 · O'Leary et al. 2017 · Tesarz et al. 2012 · Stone et al. 2012",
    5000,
    4150,
    'Added 10 October'),
   ('4',
    'How to read a training study',
    'How can you judge a training claim yourself?',
    ["Mechanism, observation and experiment: what each can and can't show",
     'Who was studied, what was compared, what was measured',
     'Small samples, with a simulation of 20,000 trials',
     'The t-statistic, p-values, p-hacking and the replication crisis',
     'A very good trial taken apart, and ten questions to ask of any study'],
    'Hopkins et al. 1999, 2001 · Button et al. 2013 · Simmons et al. 2011 · Murphy et al. 2025 · Howden et al. 2018',
    5000,
    4770,
    ''),
   ('5',
    'Intensity, properly defined',
    'What do “Zone 2”, “threshold” and “easy” actually mean?',
    ['Two thresholds and three domains, and a study that rode people to exhaustion in each',
     'Lactate as a fuel, and why the “anaerobic threshold” is misnamed',
     'The second threshold: 4 mmol/L, lactate steady state, critical power and FTP',
     'Three-zone and five-zone models, and the two meanings of Zone 2',
     'Nine markers of Zone 2 in the same 50 cyclists, and the 2025 expert definition'],
    'Seiler & Kjerland 2006 · Black et al. 2017 · Iannetta et al. 2020 · Jones et al. 2019 · Meixner et al. 2025 · Sitko et al. 2025',
    5000,
    4840,
    ''),
   ('6',
    'Finding your zones',
    'Where is the top of your Zone 2, how is it measured, and how good are the shortcuts?',
    ['The first lactate threshold, and what it costs to cross it',
     'The definition this book adopts, and why lactate',
     'Measuring it in a laboratory and with a home meter',
     'The proxies: the talk test, heart rate variability, percentages, drift and feel',
     'A step test on a smart trainer, the second threshold, and how often to repeat'],
    'Seiler et al. 2007 · San Millán & Brooks 2018 · Pallarés et al. 2016 · Olieslagers et al. 2026 · Persinger et al. 2004 · Foster et al. 2008 · Lucía et al. 2000',
    5000,
    6210,
    '')]),
 ('Part II',
  'The easy part',
  'What low-intensity riding does, and why elite athletes do so much of it.',
  'easy',
  [('7',
    'What easy riding does to the body',
    'What does riding below the first threshold change in the body, and do the claims made for Zone 2 hold?',
    ['A small stimulus that can be repeated in very large amounts: which fibres it uses and how strong the signal is',
     'The largest evidence, 353 training studies, and what it cannot say about Zone 2',
     'Three claims tested: best for mitochondria, where you burn most fat, trains lactate clearance',
     'What it is good for, how easy and how long, and who it is for'],
    'Mølmen et al. 2025 · Storoschuk et al. 2025 · Gollnick et al. 1974 · Evertsen et al. 2001 · Achten & Jeukendrup 2004 · Melanson et al. 2002 · Seiler et al. 2007',
    7000,
    5870,
    ''),
   ('8',
    'Why elite athletes ride easy',
    'Why do the best endurance athletes do most of their training easy, and does their example transfer to a rider on six to ten hours a week?',
    ['The diaries of eleven Olympic and world champions: 91% of the time easy, and a steady 1.3 hours a week of hard training',
     'Mostly easy is consistent across sports; polarised is a minority, and road cycling is the untidy case',
     'How the pattern arose, why it might work, and the champions training below Zone 2',
     'The trials: an early advantage for polarised training that shrank to nothing as they accumulated',
     'For six to ten hours: copy the amount of hard training, not the ratio'],
    'Tønnessen et al. 2014 · Solli et al. 2017 · Stöggl & Sperlich 2014 · Silva Oliveira et al. 2024 · Rosenblat et al. 2025 · Cove et al. 2025',
    6000,
    5380,
    ''),
   ('9',
    'Durability',
    "Why do some riders fade after three hours and others don't?",
    ['What durability is and how it is measured',
     'Why thresholds and critical power fall during a long ride',
     "What the professionals' data show",
     'What trains it, and what carbohydrate does to it'],
    'Maunder et al. 2021 · Clark et al. 2019 · Stevenson et al. 2022 · Jones & Kirby 2025 · Norte et al. 2026',
    6500,
    5960,
    'The pilot chapter'),
   ('10',
    'Beyond performance',
    'Does Zone 2 make you live longer, or is that a correlation?',
    ['Fit people live longer: a treadmill cohort of 122,007 patients, and six cohorts on how much activity is enough',
     'Marker or cause: the London busmen, and Finnish twins in which the benefit disappears',
     'The one long trial: Generation 100, five years of training in 1,567 older adults, and no difference in deaths',
     'Blood pressure and blood sugar; Zone 2 as medicine, weighed; lifelong athletes, colds and weight',
     'For six to ten hours: the health benefit is mostly banked, so the split is a performance question'],
    'Mandsager et al. 2018 · Arem et al. 2015 · Karvinen et al. 2015 · Stensvold et al. 2020 · Cornelissen & Smart 2013 · Marijon et al. 2013',
    5000,
    4060,
    '')]),
 ('Part III',
  'The hard part',
  'Intervals: which ones, how hard, and how often.',
  'hard',
  [('11',
    'Time near VO₂max',
    'Why does time spent close to VO₂max keep coming up in interval research?',
    ["Billat's early work on time at VO₂max",
     'What drives oxygen uptake up during an interval, and how fast',
     'The first training study to link it to fitness gains'],
    'Rønnestad & Hansen 2016 · Odden et al. 2024 · Urianstad et al. 2024 · Billat 2001 (to verify)',
    5000,
    0,
    'Partly on the website'),
   ('12',
    'Designing intervals',
    '4 × 4, 4 × 8 or 30/15: which interval session, and why?',
    ['Classic long intervals and the trials behind them',
     'Short intervals, effort matching and the 2025 self-paced result',
     'Fast-start intervals and varied-power efforts',
     'Choosing a session for a goal'],
    'Helgerud et al. 2007 · Sylta et al. 2016 (to verify) · Rønnestad et al. 2015, 2020 · Appelhans et al. 2025',
    7000,
    0,
    'Partly on the website'),
   ('13',
    'How many hard sessions, and how often',
    'Is two hard sessions a week really the right number?',
    ['Frequency trials: one against two against three', 'Recovery physiology and the 48-hour rule', 'Block periodisation and when three works'],
    'Stanley et al. 2013 · Hatle et al. 2014 · Tønnessen et al. 2020 · Rønnestad et al. 2014',
    6000,
    0,
    'Website post exists')]),
 ('Part IV',
  'Everything else',
  'The things besides ordinary training that are credited with making riders faster.',
  'neutral',
  [('14',
    'Fuelling',
    'How much does eating on the bike help, and can the gut be trained?',
    ['Tour riders were eating 94 grams of carbohydrate an hour in the 1980s',
     'The gut-wall limit, and why glucose with fructose gets past it',
     'Why 60 grams an hour gets most of the gain and above 90 is unproven',
     'Gut training: good evidence for comfort, thin evidence for absorbing more',
     'Water, salt, caffeine, ketones, beetroot juice and the red drink at the finish'],
    'Saris et al. 1989 · Smith et al. 2013 · Cox et al. 2010 · Martinez et al. 2023 · Plews et al. 2026 · Southward et al. 2018',
    5000,
    6460,
    'Added 11 October'),
   ('15',
    'Strength training',
    'Does lifting weights make a trained cyclist faster?',
    ["Where the fear that lifting and endurance don't mix came from",
     'The trials in cyclists, and a 2026 pooled analysis of 17 of them',
     'Faster without a higher VO₂max: efficiency and force',
     'Weight gain, how much to do, and how little keeps it',
     "Road cyclists' bone density, a reason to lift that has nothing to do with speed"],
    'Hickson 1980, 1988 · Rønnestad et al. 2010, 2011, 2015 · Vikmoen et al. 2016 · Llanos-Lagos et al. 2026 · Olmedillas et al. 2012',
    4000,
    2840,
    'Added 11 October'),
   ('16',
    'Heat training',
    "Does training in the heat make you faster when it isn't hot?",
    ['Two purposes that get confused: preparing for a hot race, and heat as a substitute for altitude',
     'Plasma volume in a week, haemoglobin mass in five',
     'What the five-week trials show, and the one trial in amateurs',
     'Core-temperature sensors, ice vests and slushies'],
    'Lorenzo et al. 2010 · Rønnestad et al. 2021, 2022 · Mikkelsen et al. 2019 · Oberholzer et al. 2019',
    5000,
    4400,
    'Added 5 October'),
   ('17',
    'Drugs',
    'What was doping for, how much was it worth, and what is legal now?',
    ['What EPO-era doping aimed at, and the biology of EPO',
     'How much it was worth: the Mont Ventoux trial, a real race run double-blind',
     'The risks, and what the era teaches',
     'Getting faster without it, and the edge of the rules'],
    'Heuberger et al. 2017 · USADA 2012 · CIRC 2015 · UCI 2025',
    5500,
    4640,
    'Added 5 October; needs a legal read before publication')]),
 ('Part V',
  'Putting it together',
  "Weeks, special cases, and how to tell it's working.",
  'neutral',
  [('18',
    'The training week',
    'What does a sensible week look like at 4, 8 and 12 hours?',
    ["The planner's rules, explained and justified", 'Worked weeks, and how they change across a season', 'Easier weeks and building volume'],
    'Draws on Finding your zones, What easy riding does and How many hard sessions',
    5000,
    0,
    'Partly on the website'),
   ('19',
    'Special cases',
    'What changes for masters riders, women, and riders short of time or training indoors?',
    ['Ageing, recovery and what the evidence actually shows',
     'Women: what is known, and how little of the research included them',
     'Riding indoors: heat, cardiac drift and ERG mode'],
    'Coyle & González-Alonso 2001 · sources to find for each section',
    7000,
    0,
    'New research'),
   ('20',
    "Knowing it's working",
    "How can you tell you're getting fitter without an FTP test?",
    ['Power at a fixed heart rate, and what adds noise to it', 'Cardiac drift and decoupling', 'How fast fitness is lost when you stop'],
    'Buchheit 2014 · Coyle & González-Alonso 2001 · detraining sources to find',
    6000,
    0,
    'Partly on the website')]),
 (None,
  None,
  None,
  'front',
  [('21', 'The verdict', 'Just Zone 2?', ['A graded answer, claim by claim', "What the research still can't tell us"], '', 3000, 0, 'Written last')])]

e = html.escape


def chapter(c):
    num, title, q, covers, src, target, done, note = c
    word = ' word' if not num.isdigit() else ''
    chip = (f'<span class="chip chip-exists">Draft 1 written</span>' if done else '<span class="chip chip-new">Not started</span>')
    words = (f'{done:,} of {target:,} words' if done else f'{target:,} words')
    srcs = f'<p class="ch-src"><span>Key sources</span> {e(src)}</p>' if src else ''
    status = f'<p class="ch-status">{e(note)}</p>' if note else ''
    return (f'<article class="ch">\n<div class="ch-num{word}">{e(num if num != "—" else "New")}</div>\n<div class="ch-main">\n<h3>{e(title)}</h3>\n'
            f'<p class="ch-q">{e(q)}</p>\n<ul class="ch-covers">' + "".join(f"<li>{e(x)}</li>" for x in covers) + f'</ul>\n{srcs}{status}\n</div>\n'
            f'<div class="ch-side">{chip}<span class="ch-words">{words}</span></div>\n</article>')


def build():
    chapters = [c for p in PARTS for c in p[4]]
    target = sum(c[5] for c in chapters)
    drafted = [c for c in chapters if c[6]]
    written = sum(c[6] for c in drafted)
    body = []
    for label, name, blurb, kind, chs in PARTS:
        if label:
            pw = sum(c[5] for c in chs)
            body.append(f'<section class="part part-{kind}">\n<header class="part-head"><p class="part-label">{label}</p><h2>{e(name)}</h2>'
                        f'<p class="part-blurb">{e(blurb)}</p><p class="part-words">{pw:,} words</p></header>')
        else:
            body.append('<section class="part part-front">')
        body.extend(chapter(c) for c in chs)
        body.append('</section>')
    head = open(os.path.join(HERE, "outline_head.html"), encoding="utf-8").read()
    numbered = sum(1 for c in chapters if c[0].isdigit())
    page = f'''<title>Just Zone 2? Outline</title>
{head}

<div class="wrap">
  <p class="kicker">Book outline · third draft · {DATE}</p>
  <h1>Just Zone <em>2?</em></h1>
  <p class="lede">A research-led look at easy riding, hard intervals and how endurance actually improves, for cyclists who want to read the studies rather than the slogans. Technical where the science needs it, and written for interested riders rather than physiologists.</p>
  <div class="facts">
    <span><b>{numbered}</b> chapters in <b>5</b> parts, + introduction</span>
    <span><b>~{round(target, -2):,}</b> words planned</span>
    <span><b>{len(drafted)}</b> chapters in first draft</span>
    <span><b>~{round(written, -2):,}</b> words written</span>
  </div>
  <p class="lede" style="font-size:15px">The drafted chapters are on the <a href="{DRAFT_URL}">draft page</a>, where you can comment on them.</p>

  <section class="block" aria-labelledby="changes">
    <h2 id="changes">What has changed since the last outline</h2>
    <ul class="back">
      <li><b>Five chapters added:</b> Effort, pain and the brain (3), Fuelling (14), Strength training (15), Heat training (16) and Drugs (17).</li>
      <li><b>A new Part IV, Everything else,</b> holds those last four. Putting it together is now Part V.</li>
      <li><b>Renumbered:</b> every chapter from Intensity onwards has moved. The verdict is now 21.</li>
      <li><b>Fifteen chapters drafted:</b> the introduction, Chapters 1 to 10, Fuelling, Strength training, Heat training and Drugs. All are first drafts awaiting your read. Beyond performance (10) is the newest, which completes Part II. Finding your zones (6) was rewritten on 11 October to lead with the lactate threshold, and the book now defines the top of Zone 2 by lactate (Chapters 5 and 6).</li>
      <li><b>Length:</b> the plan has grown from about 93,000 to about {round(target, -2):,} words.</li>
    </ul>
  </section>

  <section class="block" aria-labelledby="aims">
    <h2 id="aims">Two aims</h2>
    <p class="sub">Training advice goes through fashions, and Zone 2 is the latest. The book is meant to help readers cut through the noise, so every chapter does two things.</p>
    <div class="features">
      <div>
        <h3>Explain the mechanism</h3>
        <p>The biology and physiology a training claim rests on, so readers understand why an effect should happen, not only that a study found one. How bodies adapt to training lays the groundwork and later chapters refer back to it.</p>
      </div>
      <div>
        <h3>Teach readers to judge research</h3>
        <p>Study design, sample size, effect sizes, and the difference between a plausible mechanism and a demonstrated effect. How to read a training study sets out the toolkit, and every chapter then practises one skill on a real study.</p>
      </div>
    </div>
  </section>

  <section class="block" aria-labelledby="spine">
    <h2 id="spine">The spine</h2>
    <p class="sub">Every chapter hangs off one model of endurance performance, which the book calls the engine. Each training question becomes: which of these four does it change, and how good is the evidence?</p>
    <div class="formula">sustainable power ≈ <span>VO₂max</span> × <span>fraction you can sustain</span> × <span>efficiency</span>, then ask how much survives three hours (<span>durability</span>)</div>
    <div class="factors">
      <div class="factor"><h3>VO₂max</h3><p>The ceiling: how much oxygen you can take up and use.</p><p class="chs">Ch 1, 2, 11, 12</p></div>
      <div class="factor"><h3>Fraction sustained</h3><p>How close to that ceiling you can ride for an hour. Where the thresholds sit.</p><p class="chs">Ch 5, 7, 8</p></div>
      <div class="factor"><h3>Efficiency</h3><p>Watts out for each litre of oxygen used.</p><p class="chs">Ch 1, 7, 15</p></div>
      <div class="factor"><h3>Durability</h3><p>How well the other three hold up late in a long ride.</p><p class="chs">Ch 9, 14, 18</p></div>
    </div>
  </section>

  <section class="block" aria-labelledby="contents">
    <h2 id="contents">Contents</h2>
    <p class="sub">The green part covers easy riding and the orange part hard intervals. Word counts are targets; where a chapter is drafted, the count so far comes first.</p>
    {chr(10).join(body)}
  </section>

  <section class="block" aria-labelledby="features">
    <h2 id="features">Running through every chapter</h2>
    <div class="features">
      <div>
        <h3>How it works</h3>
        <p>Each chapter explains the mechanism before the evidence: what's happening in the muscle, heart or blood, with speculation labelled as speculation.</p>
      </div>
      <div>
        <h3>Reading the research</h3>
        <p>A short box per chapter that practises one skill on one of its own studies. In Fuelling: the fastest Ironman athletes eat the most, so does eating more make you fast, or does being fast let you eat?</p>
      </div>
      <div>
        <h3>Evidence grades</h3>
        <p>Each major claim gets a grade, so a reader can see at a glance how much weight it carries.</p>
        <div class="grades">
          <span><b>A</b>Several randomised trials or a solid meta-analysis</span>
          <span><b>B</b>Consistent, but small studies or a single lab</span>
          <span><b>C</b>Observational, mechanistic or expert opinion</span>
        </div>
      </div>
      <div>
        <h3>One study, up close</h3>
        <p>A box per chapter that takes one key paper apart: who was studied, for how long, what changed, and what it can't tell us.</p>
      </div>
      <div>
        <h3>Charts redrawn from the data</h3>
        <p>Figures built from published numbers, in black and white for print, each titled with the point it makes. No figures copied from papers.</p>
      </div>
      <div>
        <h3>From the saddle</h3>
        <p>Your rides, mistakes and opinions, in your words. Several drafted chapters still have a placeholder waiting for one.</p>
      </div>
    </div>
    <ul class="back">
      <li><b>Back matter:</b> glossary, a session library (each session with its evidence grade), and references by chapter.</li>
      <li><b>App mentions:</b> the introduction and a closing page only.</li>
      <li><b>House style:</b> British spelling, watts and W/kg, every number traceable to a source.</li>
    </ul>
  </section>

  <section class="block" aria-labelledby="decisions">
    <h2 id="decisions">Decisions for you</h2>
    <div class="decisions">
      <div class="decision">
        <h3>A name for Part IV</h3>
        <p>Fuelling, Strength training, Heat training and Drugs now have a part of their own. “Everything else” is a working title.</p>
        <ul>
          <li>Everything else</li>
          <li>Besides the training</li>
          <li>The other claims</li>
        </ul>
      </div>
      <div class="decision">
        <h3>Length</h3>
        <p>The plan is about {round(target, -2):,} words, roughly 420 printed pages.</p>
        <p class="rec"><b>Agreed</b>Draft long and edit down towards the end of the review.</p>
      </div>
      <div class="decision">
        <h3>Subtitle</h3>
        <ul>
          <li>The science of easy riding, hard intervals and getting fitter</li>
          <li>What the research says about how cyclists get fitter</li>
          <li>An evidence guide to endurance training for cyclists</li>
        </ul>
        <p class="rec"><b>Suggest</b>The first. It names both halves of the book's question.</p>
      </div>
      <div class="decision">
        <h3>Interviews</h3>
        <p>Original conversations with two or three researchers would set the book apart from anything else on the shelf. They're worth arranging once more of the draft exists.</p>
      </div>
      <div class="decision">
        <h3>What to write next</h3>
        <p>Parts I and II are drafted. Next comes Part III on intervals, starting with Time near VO₂max (11). How many hard sessions (13) has to take up the question Chapter 8 leaves open: whether the champions' steady hour or so of hard training a week is a ceiling, and where it lies for a rider on 6 to 10 hours. Beyond performance (10) leaves Part III a narrower job too: for a rider on six to ten hours, the split between easy and hard riding is a question of performance, not health.</p>
      </div>
    </div>
  </section>

  <p class="foot">Third draft of the outline. Chapters marked “not started” still carry their original descriptions and sources, some of them unchecked. In the drafted chapters most sources have been read as abstracts only; each chapter's research notes say which.</p>
</div>
'''
    open(OUT, "w", encoding="utf-8").write(page)
    print(f"{OUT}: {len(chapters)} chapters, target {target:,}, drafted {len(drafted)}, written {written:,}")


if __name__ == "__main__":
    build()
