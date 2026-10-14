# Beyond performance (Chapter 10): research notes

Written 14 October 2026 with the first draft, at George's request ("then do the next chapter"). Tags: [FT] read in the full text (file in `papers/`), [Abs] from the abstract, [Rep] reported by another source, [GK] general knowledge with no source in the list, [Own] my arithmetic or inference.

**Read in full for this chapter:** Stensvold 2020 (Generation 100: methods, results, tables 2 and 3, limitations), Mandsager 2018 (methods, table 1, limitations), Karvinen 2015 (the human twin results; the rat results skimmed), Campbell & Turner 2018 (the section on the marathon studies and the "open window"). The results section of Arem 2015 read from the PMC author manuscript page (the Europe PMC full-text service returned an error). **Everything else is abstract only.** Storoschuk 2025 was read in full for Chapter 7.

## 1. Fitness, activity and mortality: the cohorts

### Mandsager et al. 2018, JAMA Netw Open [FT]
- Retrospective cohort, Cleveland Clinic. Consecutive adult patients referred for a symptom-limited treadmill test, 1991 to 2014; median follow-up 8.4 years [Abs].
- 122,007 patients, mean age 53.4, 59.2% men. 13,637 deaths in 1.1 million person-years [Abs].
- Fitness = peak estimated METs from treadmill speed and grade (not measured gas exchange) [FT]. Groups by age- and sex-specific percentile: low (<25th), below average, above average, high (75th to 97.6th), elite (≥97.7th, i.e. 2 SD above the mean) [Abs].
- **Excluded:** patients who had pharmacological stress testing (38,828) or were converted to it because they could not exercise [FT]. [Own] The people too ill to walk on a treadmill were left out, which matters for reverse causation.
- Most common reasons for referral: evaluation for coronary artery disease and symptoms [FT].
- Deaths by group (Table 1) [FT]: low 6,904 of 29,181 (23.7%); below average 2,888 (10.6%); above average 2,340 (7.3%); high 1,412 (4.7%); elite 93 of 3,570 (2.6%).
- Adjusted HR elite vs low 0.20 (0.16 to 0.24); low vs elite 5.04 (4.10 to 6.20); elite vs high 0.77 (0.63 to 0.95); below average vs above average 1.41 [Abs].
- Comparison risk factors: coronary artery disease HR 1.29; smoking 1.41; diabetes 1.40 [Abs].
- Authors' conclusion: "no observed upper limit of benefit"; fitness is "a modifiable indicator" [Abs].
- **Limitations, in the authors' words (paraphrase) [FT]:** retrospective, so association not causation; "The degree to which high CRF preselects patients with lower mortality vs causes a reduction in mortality is not discernible from our study"; possible unmeasured confounders; genetic factors and unmeasured health habits may contribute to fitness; patients referred for testing differ from the general population.
- [Own] The comparison with smoking is low vs elite fitness (bottom quarter vs top 2.3%) against smokers vs non-smokers. The two are not like for like.

### Arem et al. 2015, JAMA Intern Med [Abs; results text from PMC author manuscript]
- Six cohorts in the NCI Cohort Consortium, US and Europe, baseline 1992 to 2003; 661,137 adults, median age 62, 116,686 deaths, median follow-up 14.2 years. **Self-reported** leisure-time activity [Abs].
- The guideline minimum: 150 min moderate or 75 min vigorous a week = 7.5 MET-hours a week [Abs].
- HR against no leisure activity [Abs, with the 5–10× category from the PMC results text]:
  - below the minimum (0.1 to <7.5 MET-h/wk): 0.80 (0.78 to 0.82), 20% lower
  - 1 to 2× (7.5 to <15): 0.69 (0.67 to 0.70), 31% lower
  - 2 to 3× (15 to <22.5): 0.63 (0.62 to 0.65), 37% lower
  - 3 to 5× (22.5 to <40): 0.61 (0.59 to 0.62), 39% lower
  - 5 to 10× (40 to <75): 0.61 (0.58 to 0.64) [FT, PMC text]
  - 10× or more (75+): 0.69 (0.59 to 0.78) in the published abstract; the author manuscript gives 0.68 and "32% lower". I use the abstract.
- Authors: meeting the minimum "was associated with nearly the maximum longevity benefit"; "no evidence of harm at 10 or more times" [Abs].
- **Data for `dose-response.svg`.** Percent lower: 0, 20, 31, 37, 39, 39, 31.

### Where a trained rider sits on that curve [Own]
- 1 MET = 3.5 mL/kg/min of oxygen [GK].
- Example rider: VO₂max 55 mL/kg/min (the Leiden amateurs averaged 55.6 [FT, doping research]; the Copenhagen club riders about 58 [FT, heat research]). The first lactate rise came at 61% and 69% of VO₂max in the two studies of Chapter 7's fat-max figure (fatmax-feeding.csv). Take 60% as easy riding near the top of Zone 2.
- 0.60 × 55 = 33 mL/kg/min; 33 / 3.5 = 9.4 METs. One hour = 9.4 MET-hours = 1.26 × the 7.5 minimum.
- 6 h = 56.6 MET-h = 7.5×; 10 h = 94 MET-h = 12.6×. **So six to ten hours of riding sits at roughly 7 to 13 times the minimum**, across the 5–10× and 10×-plus categories.
- In Arem's surveys a rider's MET value would have been assigned from a table, not measured; the conversion is a rough placing, not a calculation the study made.

### Ekelund et al. 2019, BMJ [Abs]
- Harmonised meta-analysis of 8 cohorts with accelerometers; 36,383 people, mean age 62.6, 72.8% women; median follow-up 5.8 years; 2,149 deaths.
- Total activity, quarters from least to most active: HR 1.00, 0.48, 0.34, 0.27.
- Light activity alone: 1.00, 0.60, 0.44, 0.38. Moderate-to-vigorous: 1.00, 0.64, 0.55, 0.52.
- Sedentary time, least to most: 1.00, 1.28, 1.71, 2.63.
- "Any physical activity, regardless of intensity" associated with lower risk; non-linear.
- [Own] Light activity here means mostly walking about; the point for this chapter is that the lowest intensities carry an association too.

### Celis-Morales et al. 2017, BMJ [Abs]
- UK Biobank, 263,450 people, mean age 52.6; median follow-up 5.0 years; 2,430 deaths.
- Cycle commuting vs non-active commuting: all-cause mortality HR 0.59 (0.42 to 0.83); cancer incidence 0.55; CVD incidence 0.54; CVD mortality 0.48.
- Walking commuting: lower CVD incidence (0.73) but no significant association with all-cause mortality.

### Marijon et al. 2013, Eur Heart J [Abs]
- All 786 French riders who started the Tour de France at least once, 1947 to 2012; 208 (26%) had died by 1 September 2012.
- Mortality 41% lower than French men of the same age: SMR 0.59 (0.51 to 0.68); unchanged over time. Cancer 0.56; cardiovascular 0.67; external causes 1.06 (no difference).
- Authors: cannot separate the effect of the sport from the selection of healthy athletes, or weigh "any potential deleterious effects of excessive physical exercise or alleged doping".
- [Own] Riders from the doping era are included; the Drugs chapter's rules mean no rider is named and no era comparison is drawn.

## 2. Reading the research: is fitness a cause or a marker?

### The London busmen
- Paffenbarger, Blair & Lee 2001, Int J Epidemiol [Abs]: Morris and colleagues showed "an apparent protection against CHD enjoyed by active conductors compared with sedentary drivers of London double-decker buses"; postmen "seemed to be protected" like conductors, compared with less active government workers; Morris's analyses "dealt with possible selection and confounding biases". Later work moved to leisure-time activity in civil servants.
- Heady, Morris & Raffle 1956, Lancet, "Physique of London busmen; epidemiology of uniforms" [title only; no abstract, not read]. The title shows the group studied busmen's physique from uniform sizes. **What it found is not stated in the draft**: I recall that drivers were already bigger round the waist when they joined, but I have not read it. Check before adding that.
- [GK] Conductors climbed the stairs of the double-decker all day; drivers sat. The original paper is Morris et al. 1953 in the Lancet; not found by the search tool and not read.

### Small facts used in the draft
- [Own] Mandsager's elite group is the top 2.3% (100 − 97.7).
- [FT, Stensvold 2020 introduction] cardiorespiratory fitness "is currently regarded as the single best predictor of longevity and health"; the draft's "predicts lifespan better than most things a doctor measures" rests on this and on Mandsager's comparison with smoking, diabetes and coronary disease.
- [GK] Light activity on an accelerometer is the kind involved in slow walking and housework.
- [GK] HbA1c reflects average blood sugar over the previous two or three months.
- [GK] Non-identical twins share about half their genes on average; identical twins all of them.
- [GK] Atrial fibrillation is an irregular rhythm of the heart's upper chambers.

### Karvinen et al. 2015, Sci Rep [FT for the twin results]
- Finnish Twin Cohort; activity asked in 1975, 1981 and 1990; deaths followed from 1990 to July 2013.
- Individuals with persistent vigorous activity vs none: HR 0.55 (0.46 to 0.64) for age and sex; 0.73 (0.61 to 0.88) after adjusting for education, smoking, alcohol, BMI, work activity and health status [FT].
- 179 pairs persistently discordant for vigorous activity: 34 identical (MZ) pairs, 134 non-identical (DZ) pairs [FT]. ("179" includes 11 of unknown zygosity, [Own] from 179 − 34 − 134.)
- Pairwise HR, all discordant pairs: 0.65 (0.46 to 0.91), 0.72 (0.48 to 1.07) adjusted [FT].
- DZ pairs: 0.58 (0.39 to 0.88). **MZ pairs: 1.00 (0.52 to 1.94)** [FT].
- Heritability of leisure physical activity estimated at 53% [FT].
- Authors propose "genetic pleiotropy": the same genes influence activity, fitness and risk of death [Abs].
- Rats bred for high or low fitness: voluntary wheel-runners lived about 16% shorter than caged controls in both strains [FT]. Not used: a strange result in caged rats that the paper does not explain well.
- [Own] The MZ result is 34 pairs and its interval runs from halving to doubling the risk. It is an absence of evidence of a benefit within identical twins, not evidence of no benefit.

### Waller et al. 2010, Eur J Epidemiol [Abs]
- Earlier analysis of the same cohort: 146 pairs discordant in 1975 and 1981 (29 MZ); inactive vs active co-twin HR 2.08 (1.06 to 4.09); in DZ pairs 2.67; "no mortality difference among the smaller number of discordant MZ pairs". 19 inactive and 10 active co-twins died.

### Healthy-volunteer and reverse causation in the trial [FT, Stensvold 2020]
- Controls' mortality was "less than half" the 10% five-year death rate of the general population of older adults in Norway; participants were more active and healthier than those who did not take part.

## 3. The trial: Generation 100 (Stensvold et al. 2020, BMJ) [FT]
- Every resident of Trondheim aged 70 to 77 invited in 2012 (6,966); 1,567 included (790 women); mean age 72.8.
- **Primary hypothesis:** "systematic exercise training lowers all cause mortality compared with giving advice to follow the national guidelines for physical activity". **Exploratory hypothesis:** that HIIT lowers mortality more than MICT.
- Randomised 2:1:1, stratified by sex and living alone: control 780, MICT 387, HIIT 400.
- Control: asked to follow the 2012 Norwegian guidelines (30 minutes of moderate activity almost every day); no supervision.
- MICT and HIIT: replace two of the five 30-minute sessions a week with two HIIT sessions (10-min warm-up, 4 × 4 min at about 90% of peak heart rate, Borg about 16) or two energy-matched MICT sessions (50 min continuous at about 70% of peak heart rate, Borg about 13). Supervised spinning with heart-rate monitors every sixth week; supervised outdoor sessions offered twice a week. Five years.
- Measured supervised intensity: HIIT 90% and MICT 72% of peak heart rate; Borg 16.9 and 13.8.
- Baseline: 87.5% reported good health; 80% medium or high activity.
- Adherence (≥50% of prescribed sessions) at 1, 3, 5 years: HIIT 50%, 49%, 47%; MICT 63%, 55%, 51%. Controls meeting guidelines 78%, 70%, 69%; controls who had switched to HIIT 23%, 22%, 18%. MICT participants who switched to HIIT 12%, 14%, 11%.
- Drop-outs (death, withdrawal, exclusion) at 5 years: HIIT 33%, MICT 26%, control 20%; analysed by intention to treat.
- **Deaths at five years (Table 2):** control 4.7% (37); MICT 5.9% (23); HIIT 3.0% (12); MICT + HIIT combined 4.5% (35). Overall 4.6% (72).
- HR vs control: HIIT 0.63 (0.33 to 1.20), absolute risk 1.7 points lower; MICT 1.24 (0.73 to 2.10), 1.2 points higher. HIIT vs MICT 0.51 (0.25 to 1.02). None significant.
- Peak oxygen uptake at 5 years: HIIT 0.7 mL/kg/min higher than control (P = 0.02) and than MICT (P = 0.04). Combined exercise vs control: 0.8, 0.7, 0.3 mL/kg/min higher at 1, 3 and 5 years.
- Quality of life: HIIT higher physical and mental summary scores than both other groups at five years.
- Safety: three fractures on slippery outdoor surfaces (two MICT, one HIIT); no cardiovascular events during supervised sessions.
- Authors' conclusion: combined MICT and HIIT "has no effect on all cause mortality compared with recommended physical activity levels", with "a lower all cause mortality trend after HIIT compared with controls and MICT".
- Authors' limitations: controls very active, many doing HIIT; only half the HIIT group followed the protocol; selection bias; the null result does not refute a causal link between activity and longevity; possible ceiling effect.
- [Own] MICT at about 70% of peak heart rate, "somewhat hard" on the Borg scale, in 70-year-olds is the nearest the trial comes to steady Zone 2 riding; whether it was below their first threshold was not measured.

## 4. Training and the risk factors (trials)

### Cornelissen & Smart 2013, J Am Heart Assoc [Abs]
- 93 randomised trials, ≥4 weeks, healthy adults; 5,223 participants.
- Endurance training: systolic −3.5 mmHg (−4.6 to −2.3), diastolic −2.5.
- In hypertensive groups −8.3 / −5.2; prehypertensive −2.1 / −1.7; normal blood pressure −0.75 (−2.2 to +0.69) / −1.1.
- [Own] The effect is largest in people whose blood pressure is high; in someone with normal pressure it is about a millimetre.

### Umpierre et al. 2011, JAMA [Abs]
- 47 RCTs, 8,538 patients with type 2 diabetes, ≥12 weeks.
- Structured exercise: HbA1c −0.67 percentage points (−0.84 to −0.49); aerobic −0.73; resistance −0.57; combined −0.51.
- More than 150 min a week: −0.89; 150 min or less: −0.36.
- Advice alone: no change unless combined with dietary advice.

### Weston, Wisløff & Coombes 2014, Br J Sports Med [Abs]
- 10 studies, 273 patients with coronary disease, heart failure, hypertension, metabolic syndrome or obesity.
- HIIT raised VO₂peak 3.03 mL/kg/min (2.00 to 4.07) more than MICT, "equivalent to 9.1%"; "almost double".

### Jelleyman et al. 2015, Obes Rev [Abs]
- 50 studies of HIIT, ≥2 weeks.
- Insulin resistance: HIIT vs control SMD −0.49 (−0.87 to −0.12); HIIT vs continuous training −0.35 (−0.68 to −0.02).
- HbA1c −0.19% and body weight −1.3 kg vs control.
- Fasting glucose −0.92 mmol/L in people at risk of or with type 2 diabetes.
- Authors call for larger and longer trials.

## 5. Zone 2 as medicine
- San-Millán & Brooks 2018 [Abs]: cross-sectional comparison of professional endurance athletes, moderately active people and people with metabolic syndrome; told in Chapters 6 and 7. Not a training study.
- Storoschuk 2025 [FT, read for Chapter 7]: narrative review of Zone 2 in the general population at about 150 min a week; concludes Zone 2 has not been shown to be optimal for mitochondrial capacity or cardiorespiratory fitness. One author declares an interest in a longevity company (Chapter 7 says so).
- The book's own position on the mitochondrial claims is in Chapter 7; this chapter refers to it and does not repeat it.

## 6. Can it be too much?

### Andersen et al. 2013, Eur Heart J [Abs]
- Vasaloppet (90 km ski race) finishers 1989 to 1998 without cardiovascular disease, followed to December 2005; 52,755 participants; 919 had an arrhythmia.
- ≥5 races vs 1: any arrhythmia HR 1.30 (1.08 to 1.58); atrial fibrillation 1.29 (1.04 to 1.61); slow heart rhythms 2.10 (1.28 to 3.47).
- Fastest (100 to 160% of the winning time vs >240%): any arrhythmia 1.30 (1.04 to 1.62); atrial fibrillation 1.20 (0.93 to 1.55), not significant.
- No association with dangerous ventricular rhythms or cardiac arrest.
- The conclusion is stated for **men**.

### Aengevaeren et al. 2017, Circulation [Abs]
- 284 men, age 55, competitive or recreational athletes; CT scans.
- Coronary calcium present in 53%. Lifelong >2,000 MET-min/wk (n = 75) vs <1,000 (n = 88): calcium in 68% vs 43% (adjusted OR 3.2); plaque 77% vs 56% (OR 3.3).
- Very vigorous exercise (≥9 METs) associated with calcium (OR 1.47) and plaque (OR 1.56).
- But the most active had fewer mixed plaques (48% vs 69%) and more purely calcified plaques (38% vs 16%), which the authors call "a more benign composition".
- [Own] 2,000 MET-min/wk = 33 MET-h/wk = about 3.5 hours at the 9.4 METs of the example rider above. A rider on six to ten hours is in this group.

## 7. Colds and infections

### Nieman et al. 2011, Br J Sports Med [Abs]
- 1,002 adults aged 18 to 85, followed 12 weeks in autumn and winter; symptoms by questionnaire; adjusted for seven confounders.
- Days with upper respiratory symptoms 43% fewer in people doing aerobic exercise ≥5 days a week than in those ≤1 day; 46% fewer in the fittest third (self-rated) than the least fit. Severity 32% to 41% lower.
- Observational; self-rated fitness.

### Nieman et al. 1990, J Sports Med Phys Fitness [Abs]
- 1987 Los Angeles Marathon applicants; 2,311 respondents.
- Training ≥97 vs <32 km a week: odds of infection in the two months before the race 2.0 (1.2 to 3.4).
- 12.9% of finishers without infection before the race reported one in the week after, against 2.2% (3 of 134) of experienced runners who did not take part; OR 5.9 (1.9 to 18.8).
- Self-reported.

### Campbell & Turner 2018, Front Immunol [FT, part]
- Review arguing that the "open window" theory of exercise-induced immune suppression is a myth.
- None of the marathon-era infections was confirmed in a laboratory. In a later study of elite athletes with swabs (Spence 2007), 11 of 37 reported episodes (30%) had a positive laboratory diagnosis [Rep]; the rest may be allergy, asthma or airway irritation from heavy breathing of cold air.
- Mass events expose people to more infection (crowds, travel).
- The fall in blood lymphocytes 1 to 2 h after hard exercise is a redistribution of immune cells to the tissues, not suppression.

### Simpson et al. 2020, Exerc Immunol Rev [Abs]
- A debate article by authors on both sides (Campbell, Turner, Nieman, Gleeson and others). Agreed: moderate exercise of up to about 45 minutes is good for immune defence; infection risk in athletes has many causes (sleep, travel, anxiety, exposure). Unresolved: whether hard exercise in itself raises infection risk.

### George
- His winter: "I generally felt better and fell ill less often with coughs and colds" (george/notes.md; used in Chapter 7's From the saddle). One person's experience; not evidence.

## 8. Weight (brief; the fat-max question is Chapter 7's)

### Donnelly et al. 2013, Obesity [Abs]
- Midwest Exercise Trial 2: 141 overweight or obese adults, mean age 22.6, BMI 31; supervised exercise 5 days a week for 10 months at 400 or 600 kcal a session, no diet; per-protocol analysis of those completing ≥90% of sessions.
- Weight change: −3.9 kg (4.3%) at 400 kcal, −5.2 kg (5.7%) at 600 kcal; controls +0.5 kg. No significant difference between the exercise groups or between men and women.
- [Own] 600 kcal five days a week is 3,000 kcal a week, about the work of four to five hours of moderate riding for many riders; I don't use this conversion in the draft.

### Jelleyman 2015 [Abs]: HIIT vs control body weight −1.3 kg (above).

## Side roads
- **Used:** the London busmen (the origin of the cause-or-marker question); the Finnish twins; Tour de France riders' lifespans; the Vasaloppet skiers' heart rhythms; the Los Angeles Marathon and the "open window" dispute; cycle commuting in UK Biobank.
- **Not used:** voluntary wheel-running rats bred for high and low fitness that lived shorter lives than caged controls (Karvinen 2015); a 2019 accelerometer replication of the busmen study that found smaller waists in more active workers (Gay 2019, abstract seen in a search, not added); the Hajj, where about 40% of pilgrims report respiratory infections (Campbell & Turner, on crowds).

## Not used, and why
- Stamatakis 2022 (short bursts of vigorous everyday activity): not looked up; the chapter has enough on intensity from the trial and the cohorts.
- Lee 2022 (vigorous vs moderate activity in two US cohorts): not looked up.
- Wewege 2017 (HIIT vs MICT and body fat): the search did not find it; not used.
- The rat result in Karvinen 2015 (above).

## Added while drafting
- Chapter 7 already answers whether Zone 2 is the best way to build mitochondria and whether it clears lactate. This chapter refers back and stays on health and lifespan.
- The book's Introduction names the host of the 2019 podcast; this chapter does not, and does not cite the podcast for any claim.
