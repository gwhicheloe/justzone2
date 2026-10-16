# The training week (Chapter 18): research notes

Written 15 October 2026, with the brief and first draft, in one batch with Special cases, Knowing it's working and The verdict at George's request ("Can you do the remaining chapters now - don't forget diagrams"). Tags: [FT] full text read, [Abs] abstract, [Rep] reported second hand, [GK] general knowledge, [Own] my arithmetic or reasoning.

Most of this chapter assembles what earlier chapters established. Their numbers are cited there; this file lists only what is new here, and the chapter-to-chapter links.

## What earlier chapters settled (the rules the week is built from)

- Two hard sessions a week, at least 48 hours apart and ideally 72 (How many hard sessions: Stanley 2013, Tønnessen 2020, Seiler 2013). Grade B.
- One hard session maintains fitness for months (Hickson 1981, Spiering 2021). Grade B.
- Three only as a short block (Rønnestad 2014b, Breil 2010, Hatle 2014). Grade B.
- The hard sessions: long intervals of four to eight minutes adding up to about half an hour (4 × 8 beat 4 × 4 in recreational cyclists on about six hours a week, Seiler 2013), or 30/15s (Rønnestad 2015b, 2020). Threshold intervals count as a cheaper hard session (grade C). Designing intervals.
- Easy riding at the top of Zone 2, a few beats under the ceiling (What easy riding does; Finding your zones). Grade C.
- A ride between the thresholds costs about as much to recover from as a hard session (Seiler 2007; Why elite athletes ride easy). Grade B for the recovery; C for counting it as hard.
- The long ride: a reasonable bet for durability, not shown (Durability). Grade C. Eat on rides over about 90 minutes (Durability; Fuelling).
- Hard dose: 40 to 65 minutes of hard work a week in the trials, close to the champions' 1.3 hours (How many hard sessions; my inference, grade C).
- Riding regularly: four or five sessions a week is where the Norwegian analysis found gains growing (Mølmen 2025, What easy riding does).

## Numbers reused from earlier chapters (tags as in those chapters' research notes)

- Seiler 2013 [Abs]: 35 recreational cyclists, about six hours a week; 4 × 8 at about 90% of peak HR gained 11.4% against 5.5% for 4 × 4 ("doubled"). Designing intervals.
- Stanley 2013 [Abs]: autonomic recovery up to 24 h after easy, 24–48 h after threshold, at least 48 h after high-intensity work. How many.
- Mølmen 2025 [FT]: 353 studies; gains grew with four or five sessions a week. What easy riding does.
- Tønnessen 2014 [FT]: champions about 1.3 h a week above the first threshold, steady through the year; easy hours 15.2, 14.4, 9.8 by phase. Why elite athletes ride easy.
- Hard dose in trials: 4 × 8 twice = 64 min (Seiler 2013); 30/15 ≈ 39 min (Rønnestad 2015b); 4 × 4 three times = 48 min (Helgerud 2007): "40 minutes to an hour". How many.
- Hickson 1981 [Abs]: cut from six days to four or two at the same intensity and duration; VO₂max kept for 15 weeks. Spiering 2021 [Abs]: endurance held up to 15 weeks on as few as two sessions a week, or a third to two thirds less volume, if intensity is kept. How many.
- Sylta 2016 [Abs]: 63 cyclists, 24 sessions over 12 weeks in three orders, all improved similarly (5–10%). How many; Designing intervals.
- Seiler 2007 [Abs]: recovery after a session between the thresholds about as long as after intervals. Finding your zones; Why elite athletes ride easy.
- Meeusen 2013 [Abs]: consensus on functional and non-functional overreaching and overtraining. How many.

- Strength (Strength training chapter): twice a week for about 12 weeks builds it (Rønnestad 2010a [Abs]: 3 × 4–10 RM, twice a week); once a week kept it for 13 weeks (Rønnestad 2010b [Abs]). Ride less in the first two or three weeks (that chapter's advice). Lifting on the same day as a hard ride is my arrangement [Own], untested.
- Fuel: eat on rides over about 90 minutes, roughly where critical power began to fall (Clark 2019a [FT], Durability; Fuelling).
- Heat: one to two weeks in the heat before a hot event (Karlsen 2015, Keiser 2015; Heat training).

## The website planner (`website/js/planner.js`, read 15 October)

The planner on justzone2.com builds a week from hours (3 to 15) and an optional long ride. Its rules, from the code's own comments and logic:
- Two hard sessions always, Tuesday and Thursday: one "VO₂max" (4 × 4 min below 6 h; 5 × 4 at 6 to 10 h; 6 × 4 at 10 h and over) and one threshold (3 × 8, 3 × 10 or 2 × 20 min). Each hard day is 1, 1.25 or 1.5 hours long.
- Everything else is Zone 2, and it is what grows with hours.
- The long ride is optional, about 30% of the week (1.5 to 4.5 h), on Saturday, and goes in only if the week holds it on top of the two hard sessions.
- Hard days never back to back; at least one rest day (two at 6 hours or under).
- No Zone 2 ride shorter than 45 minutes; leftovers go onto the long ride or onto the hard days as easy riding afterwards.

Where the book differs [Own]:
- The book's evidence favours 4 × 8 over 4 × 4 for this rider (Seiler 2013, abstract only), so the long-interval session in the book's weeks is four to eight minutes per effort, about 30 minutes of work. The planner's 4 × 4 is 16 to 24 minutes of work.
- Threshold as the second hard session is the book's grade C, and the planner treats it as a fixed rule. The book offers 30/15 or threshold.
- The planner's hard-day lengths (1 to 1.5 h) and the 45-minute minimum are reasonable conventions, not tested.

## Tapering

- **Bosquet 2007** [Abs], meta-analysis, 27 of 182 studies, competitive athletes, field or competition performance. Best strategy: a taper of 2 weeks (overall effect 0.59 ± 0.33, P < 0.001), training volume decreased exponentially by 41–60% (0.72 ± 0.36), without changing intensity (0.33 ± 0.14) or frequency (0.35 ± 0.17). Effects are standardised mean differences, pre to post taper; there is no control group in a pre–post comparison [Own: some of the gain is the athletes being rested and the competition being the target, which is the point of a taper]. Bosquet with Mujika, the leading taper researcher [GK].

## Building volume: the 10% rule

- **Buist 2008 (GRONORUN)** [Abs], randomised controlled trial, 532 novice runners preparing for a 4-mile (6.7 km) recreational event. Hypothesis (stated): a graded programme would reduce the number of running-related injuries compared with a standard programme. Graded 13-week programme based on the 10% rule against a standard 8-week programme. Injury defined as a musculoskeletal complaint of the lower limb or back restricting running for at least a week. Injuries: 20.8% graded, 20.3% standard (χ² = 0.016, P = .90). Conclusion: no effect of the graded 13-week programme applying the 10% rule. Group sizes per arm not in the abstract.
- [Own] Runners, not cyclists; injury, not fitness; novices. Cycling has far fewer overuse injuries per hour than running [GK], so the rule matters less on the bike, and the trial is evidence only that a rule of thumb about weekly increases was not protective where it was tested.

## Load ratios

- **Gabbett 2016** [Abs], BJSM, the "training-injury prevention paradox": athletes used to high loads have fewer injuries; "excessive and rapid increases" are likely responsible for many soft-tissue injuries; describes the acute:chronic workload ratio (ACWR) as "a best practice predictor of training-related injuries". Team sports.
- **Impellizzeri 2020** [Abs], IJSPP: no study has estimated causal effects properly; ACWR is an inaccurate ratio (fails to normalise the numerator by the denominator), ambiguous, not consistently related to injury; "There is no evidence supporting the use of ACWR in training-load-management systems or for training recommendations aimed at reducing injury risk"; "it adds noise and creates statistical artifacts".
- **Lolli 2019** [exists: title only, no abstract], BJSM: "Mathematical coupling causes spurious correlation within the conventional acute-to-chronic workload ratio calculations". [Own, explaining coupling] The conventional chronic load is the average of the last four weeks, and that average includes the acute week itself, so the two are partly the same number; a ratio of a number to an average that contains it is correlated with its own numerator whatever the training does.

## Training monotony

- **Foster 1998** [Abs], 25 experienced athletes, session RPE × duration as load; monotony = daily mean / standard deviation; strain = load × monotony. "A high percentage of illnesses could be accounted for when individual athletes exceeded individually identifiable training thresholds, mostly related to the strain of training." Observational; illness self-reported.
- [Own] Use: a week where every day is the same moderate load scores as monotonous; the hard-easy week is low monotony by construction.

## Periodisation

- **Kiely 2012** [Abs], IJSPP review: periodisation models share historical assumptions that are "no longer scientifically justifiable"; training responses vary widely; recommends responsive, context-specific planning over generic rule-based plans.
- **Mølmen 2019** [Abs], meta-analysis of block periodisation in trained to well-trained athletes: 20 records; six pooled; small favourable effects for block over traditional on VO₂max (SMD 0.40, 95% CI 0.02 to 0.79) and Wmax (0.28, 0.01 to 0.54); "small studies with generally low methodological quality (mean PEDro score = 3.7/10)". Rønnestad, a co-author, ran several of the block trials [GK; Rønnestad 2014b is one].
- Sylta 2016 (order of sessions across 12 weeks made no difference; 63 cyclists) — in Designing intervals and How many.

## Easier weeks

- No trial found comparing a fixed pattern of easier weeks (three weeks on, one easier) with none in cyclists [Own: searched for it in Europe PMC and found nothing; say "I found no trial"]. The pattern is coaching convention [GK].
- The taper evidence (Bosquet) and the block trials (Rønnestad 2014b: a hard week followed by easier ones) are the nearest evidence that reducing volume while keeping intensity lets fitness show, and the overreaching literature (Meeusen 2013; Halson 2004, in How many) that unrelieved load leads to stagnation.

## Worked weeks (figure `figures/worked-weeks.csv`) [Own]

Built from the rules above, not from the planner's code, and not tested as a whole. Hours are the day's total including warm-up and cool-down; hard minutes are time in the work intervals only. 30/15 × 3 sets = 3 × 13 × 30 s = 19.5 min of work; 4 × 8 = 32 min; 5 × 8 = 40 min.

| Week | Mon | Tue | Wed | Thu | Fri | Sat | Sun | Total | Hard work | Hard share of time |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 h | rest | 1.0 hard (4 × 8) | rest | 1.0 easy | rest | 1.25 hard (30/15 × 3) | 0.75 easy | 4.0 | 51.5 min | 21% |
| 8 h | rest | 1.25 hard (4 × 8) | 1.5 easy | 1.0 easy | 1.25 hard (30/15 × 3) | 3.0 long, easy | rest | 8.0 | 51.5 min | 11% |
| 12 h | rest | 1.5 hard (5 × 8) | 2.0 easy | 1.5 easy | 1.5 hard (30/15 × 3) | 4.0 long, easy | 1.5 easy | 12.0 | 59.5 min | 8% |

Spacing: 4 h week Tue→Sat 96 h, Sat→Tue 72 h. 8 h week Tue→Fri 72 h, Fri→Tue 96 h. 12 h week the same as 8 h. All at least 72 h.
Shares: 51.5/240 = 21.5%; 51.5/480 = 10.7%; 59.5/720 = 8.3%. The hard dose barely changes; the easy hours carry the growth (compare Why elite athletes ride easy: 19% of a seven-hour week, 8% for the champions in summer).

## A season (figure `figures/season.csv`) [Own, illustration, not data]

Twenty weeks for a rider who starts at 6 hours and builds to 9.5 by week 10, then holds, with an event at the end: hours rise by half an hour in each full week; every fourth week is about 30% lighter (convention, not tested); two hard sessions every week except in the lighter weeks, where one; a two-week taper cutting volume by about half (Bosquet 2007's 41–60%) with both hard sessions kept, shortened. Values in the CSV.

## From the saddle (George, review-page comment, 16 October 2026)
[George] "My training week has massively changed since embarrking on this book . My mates used to tease me about how much zone 2 I was doing, Ive introduced structured intervals and have seen a massive benefit, within a few weeks and it's still building. My zone 2 output has notched up, I'm feeling stronger. I now do 2 intervals a week, and 2 zone 2 sessions and a longer ride at the weekend. Now that I know what I'm doing it's given me confidence that I'm on the right track"
Set as the box before "A planner, and where the book differs", lightly edited. One sentence added after it in the book's voice: a single rider over a few weeks can't separate the intervals from anything else that changed (no claim about George's experience). Not stated, so not written: days, session lengths, weekly hours, figures for the gain. His week (two hard, two Zone 2, one long) is the week this chapter builds. His sessions are in Chapter 11's box.
