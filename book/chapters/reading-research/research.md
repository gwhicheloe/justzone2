# How to read a training study: research notes

Written 10 October 2026. Tags: [FT] full text; [Abs] the paper's abstract; [Rep] reported by another source; [GK] general knowledge, not checked for this book; [Own] calculated for this book.

**The ten sources gathered on 10 October are abstract only.** Murphy 2025 (added 11 October) was read in full. Two (Abt 2020 on sample sizes in sport science; Skorski & Hecksteden 2021) were found but have no abstract in the database and are not used.

## Beedie 2006 [Abs]

- Six well-trained male cyclists; two baseline and three experimental 10 km time trials.
- Told they would receive a placebo, 4.5 mg/kg caffeine and 9.0 mg/kg caffeine in random order. Placebo given every time.
- Mean power against baseline: all experimental trials +1.0% (95% limits −1.4 to 3.6), "likely trivial"; trials where they believed they had caffeine +2.2% (−0.8 to 5.4), "likely beneficial".
- By belief: placebo −1.4% (−4.6 to 1.9); 4.5 mg/kg +1.3% (−1.4 to 4.1); 9.0 mg/kg +3.1% (−0.4 to 6.7).
- "All subjects reported caffeine-related symptoms."
- Canterbury Christ Church University. [GK, from memory: check]
- "Before each ride the rider was told which one he had been given": inferred from "when they believed they had ingested". Check in the full text.

## Design and generalising

- Jones 2014 groups self-selected and differing in fitness at baseline; O'Leary 2017 computer-generated block randomisation stratified by fitness. [Rep / FT, O'Leary 2017; already in the Effort, pain and the brain notes]
- Perry 2010: nine men, peak oxygen uptake +12% in two weeks. [FT; Adaptation notes]
- Hopkins 1999: "Outcomes can be generalized only to athletes with abilities and practices represented in the study." Smallest worthwhile enhancement for an athlete in an international event is 0.7 to 0.4 of the typical within-athlete variation between events; a crossover needs 16 to 65 athletes, a fully controlled study 65 to 260. [Abs]
- Hopkins is based in New Zealand. [GK]
- Hopkins 2001: 101 studies; most reliable tests have a coefficient of variation of about 0.9 to 2.0%; non-athletes 1.3 times more variable than athletes; performance improved 1.2% between the first two trials and 0.2% between subsequent ones. [Abs]
- Halperin 2015: instructions, volume and frequency of verbal encouragement, knowledge of the endpoint, number and gender of observers, music, mental fatigue. [Abs] Australian Institute of Sport. [GK]
- MacInnis 2017 work-matched single-leg design: Adaptation notes.

## Measures

- Currell & Jeukendrup 2008: time trials more valid than time to exhaustion; time-to-exhaustion coefficient of variation above 10%, time trials below 5%; first and second place separated by less than 1%. [Abs]
- Worked example [Own]: time above critical power = W′ / (P − CP), from the What limits endurance chapter. CP 250 W, W′ 20 kJ, P 300 W: 20,000 / 50 = 400 s. CP 260 W: 20,000 / 40 = 500 s. +4% in CP, +25% in time.
- O'Leary 2017 time to exhaustion +148%. [Abs; Effort notes]

## Sample size

- Tally [Own] of studies in people described in How bodies adapt and Effort, pain and the brain, by number of participants: McGuire 5, Andersen 5, Coyle 7, Amann (2011) 7, Egan 8, Amann (2009) 8, Perry 9, Stone 9, MacInnis 10, Marcora & Staiano 10, Arbab-Zadeh 12, Mauger 13, Montero 16, Marcora 16, O'Leary 20, Martin 20, Jones 24, Astokorki 32, Howden 61, Montero & Lundby 78, HERITAGE 481. 21 studies, median 12, three above 50. Excluded: animal studies, reviews and the Tesarz meta-analysis. **Recount if either chapter changes.**
- Simulation [Own], `tools/simulate_small_trials.py`, seed 20261010, 20,000 trials per group size, true difference 3, SD 5, two-sample t-test at 5%:
  - 10 per group: significant in 24.8%; mean difference among significant trials 5.7; wrong direction 8.8%; middle 90% of results −0.7 to 6.7.
  - 50 per group: significant in 84.3%; mean among significant 3.3; wrong direction 0.1%; middle 90% 1.3 to 4.7.
- SD of 5 is "modest": Montero 2015 reports VO₂peak +9 ± 8%. [Abs]
- Button 2013: low power reduces the chance of detecting a true effect and the likelihood that a significant result is true; consequences are overestimated effect sizes and low reproducibility. [Abs] About neuroscience.
- "Journals publish significant results far more readily": publication bias. [GK]

## Analysis choices

- Simmons 2011: flexibility in data collection, analysis and reporting "dramatically increases actual false-positive rates"; simulations and two experiments. [Abs] The specific rates are not in the abstract and are not quoted.
- Büttner 2020: four journals, 1 January to 31 May 2019; 129 studies with at least one hypothesis; 106 (82.2%) supported. Authors' own hypothesis preregistered. Dublin. [Abs; city GK]
- Sainani 2018: used the proponents' simulation code; at the "optimal" small-to-moderate sample sizes the type I error rate is two to six times that of standard testing; "Magnitude-based inference should not be used." [Abs] Stanford. [GK]
- "For about a decade", "had to abandon", and the gloss that "likely beneficial" should be read as "not statistically significant by ordinary standards": [GK and my interpretation]. **Check before publication.**
- Preregistration required for clinical trials in medicine. [GK]
- Heat-suit pooling example: Heat training notes (Rønnestad 2022a).

## The t-statistic (added 11 October 2026, at George's request)

- t = observed difference / its standard error; standard error falls with the square root of n. [GK: textbook statistics]
- Two-sided 5% critical value of t: 2.101 for 18 degrees of freedom (10 per group), 1.984 for 98 (50 per group). [Own: standard tables; the same values are in `tools/simulate_small_trials.py`]

## Replication (added 11 October 2026, at George's request)

- Open Science Collaboration 2015: replications of 100 experimental and correlational studies from three psychology journals, "using high-powered designs and original materials when available". 97% of originals significant; 36% of replications significant; replication effects half the magnitude of the originals; 47% of original effect sizes inside the replication's 95% confidence interval; 39% subjectively rated as replicated. [Abs]
- Gilbert et al. 2016 (comment in Science): the OSC paper "contains three statistical errors and provides no support for such a conclusion"; data "consistent with the opposite conclusion, namely, that the reproducibility of psychological science is quite high". [Abs] The OSC authors replied; reply not read.
- "Now known as the replication crisis": [GK]. "p-hacking" as the name for the practice Simmons 2011 describes: [GK; the term is not in that paper's abstract].
- Murphy et al. 2025, Sports Med. **[FT, Europe PMC, PMC12513899.]** A correction (PMC12513940) changes author names and one affiliation only.
  - Quartile 1 sports science journals, 2016 to 2021. 9,385 studies screened; pool divided into applied biomechanics, psychology, physiology, nutrition and injury prevention; a study drawn at random from the stratified pool for each volunteer laboratory, matched on equipment and expertise.
  - 25 replications analysed (10 paired t-tests, 1 independent t-test, 14 ANOVAs).
  - 56% significant in the same way as the original ("Considering our NHST-only results"). 14 of 25: my arithmetic.
  - 36% (9) had effect sizes statistically compatible with the original; 64% (16) not.
  - 28% (7) successful on all criteria; 36% informative failures; 28% practical failures; 8% inconclusive.
  - 88% (22) of effect sizes smaller on replication; median decrease 75%.
  - Limitations, in the authors' words: 95% power aimed for but "far from realistic to assume we achieved this"; many replications doubled the original sample, "and this undoubtedly led to underpowered replication studies"; "certainly not a representative estimate"; some original effect sizes had to be conservatively estimated.
  - First author's affiliation and funding: Technological University Dublin.
  - **Not checked:** how many of the 25 were training interventions (the tables did not extract). One reference in the list is an eight-week bench-press study, so "none" would be wrong; the draft says only that months-long training studies are harder to repeat.
- "I know of no project that has repeated a set of [training studies]": my statement, from not finding one. Not a searched-for negative. **Check before publication.**
- Grade B on "a striking effect from one small study is probably overestimated": rests on the simulation [Own], Button 2013, OSC 2015 and Murphy 2025. My grading.
- Finance parallels George raised (Harvey, Liu & Zhu 2016; McLean & Pontiff 2016; Hou, Xue & Zhang 2020): not looked up and not used. Intended for a From the saddle passage in his words.

## Howden 2018 (One study, up close; added 11 October 2026 after George's comment that the chapter leaned too much on Beedie) **[FT: PMC5893372 via NCBI, read 11 Oct]**

- Prospective, parallel-group, randomised controlled trial, two years. 262 screened; 61 healthy sedentary adults aged 45 to 64 randomised.
- Exclusions: hypertension, BMI of 30 or more, thyroid disease, sleep apnoea, COPD, tobacco in the past 10 years, coronary or structural heart disease, exercising more than 30 minutes three or more times a week.
- Block randomisation by a statistician, 1.2 : 1 training to control, stratified by sex. 34 training, 27 control [Abs]; 28 and 24 completed [FT] (so 6 and 3 left: my arithmetic). **The Adaptation notes say 53 completed, from the abstract; the full text says 52 in total.** One withdrew straight after baseline testing.
- Control: yoga, balance and strength three times a week for two years; "allowed for a similar level of interaction with research staff"; each participant in both groups assigned an exercise physiologist; exercise log and heart-rate monitor in both.
- Primary outcome: change in ventricular chamber stiffness. Sample size calculation: 21 per group for 80% power.
- Training: periodised; base pace, maximal steady state, 4 × 4 intervals from month 3, long session, two strength sessions a week; 5 to 6 hours a week by month 6; one interval session a week in the maintenance phase. Most sessions unsupervised but tracked by heart-rate monitor. Compliance 88 ± 11%.
- VO₂max by Douglas bag: +5.3 mL/kg/min (95% CI 4.15 to 6.40), 18% (15 to 22); control −0.3 (−1.3 to 0.7). Group × time P < 0.0001.
- Individual LV stiffness constant: group × time P = 0.040.
- Right heart catheterisation before and after; filling lowered by lower-body negative pressure and raised by saline infusion. Cardiologist analysing LV volume "blinded to filling pressures".
- Registered on ClinicalTrials.gov (NCT02039154); independent data safety and monitoring board. **Registration date not checked** (recruitment began August 2012); the draft says only "registered".
- "The primary analysis included all participants who completed the two-year follow-up."
- Sex analysis post hoc: "should be interpreted with caution".
- "The data, analytic methods, and study materials will not be made available to other researchers."
- "This study is the longest, prospective randomized controlled trial that has documented the physiological effects of supervised, structured exercise training in a group of sedentary but healthy middle-aged adults."
- Limitations stated: wedge pressure as a surrogate; volunteers "willing and able to participate in an intensive exercise regimen"; "predominantly Caucasian".
- No comparison with elite or masters athletes in the results (masters athletes appear only as background). Supports the Adaptation chapter's sentence.
- "One of the best training trials there is", "completing the analysis only in finishers can flatter a treatment", and the point that the trial cannot separate the parts of its programme: my judgements.
- Considered for this slot and not used: Helgerud 2007 (the 4 × 4 trial; 40 men, four work-matched groups, 8 weeks). Paywalled, abstract only (journal site and Ovid tried 11 Oct). On papers-wanted.

## Individual responses

- Atkinson & Batterham 2015: simulated blood pressure data in which the true response is identical in everyone still suggests large individual differences; true differences are shown only by comparing the SD of changes in the intervention arm with that in a comparator arm; "very few researchers have compared these SDs". [Abs]

## Gaps

- No source on the typical sample size in sport science as a whole (Abt 2020 would be it).
- Nothing on meta-analysis, though the book relies on several.
- Nothing on funding or conflicts of interest.
