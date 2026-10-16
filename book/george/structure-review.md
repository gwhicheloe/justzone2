# Structure and engagement review

Whole-book review of 16 October 2026, after George asked for "another whole book review, particularly looking for structural issues, like does the book flow and additionally how can we keep the reader engaged and wanting to continue reading". Figures are from the drafts at commit 5dae526 (about 82,000 words of prose, 269-page proof).

Status key: **open**, **in progress**, **done** (with date), **decided against**.

## Words by part

| Part | Chapters | Words |
|---|---|---|
| Introduction | | 1,836 |
| I The engine | 1–6 | 26,307 |
| II The easy part | 7–10 | 18,978 |
| III The hard part | 11–12 | 8,351 |
| IV Everything else | 13–16 | 16,298 |
| V | 17–19 | 8,651 |
| The verdict | 20 | 1,898 |

## Structure and flow

### 1. Readers wait a long time to reach the question in the title — done 16 Oct (option B)
The chapter that takes on the title's question, Chapter 7, starts about 28,000 words in: roughly a third of the book. Before it come six foundation chapters, two of them away from the question: Effort and pain (Ch 3) and How to read a training study (Ch 4, 4,500 words of method).
- Option A: move Ch 4 to sit between Parts II and III, as an interlude, when readers have met conflicting studies and want the tools. Cost: about 12 cross-references to "Chapter 4" to renumber.
- Option B: keep the order, but end each of Chapters 1–6 on what it means for the Zone 2 claim, so the build-up visibly builds towards it. Chapter 5 already does ("Before Part II can ask what easy riding does…").
- George decided on 10 October to keep Ch 3 in Part I; not reopened.
- Done: option B. Ch 4 stays, because Chapters 6 and 8 and the Reading the research boxes use its tools, and moving it would turn those into forward references. Ch 1 now ends on which of its four factors the Zone 2 claims are about (Ch 7 and Ch 9 test them); Ch 3 ends on the O'Leary result as the first sign that riding only in Zone 2 may leave something untrained. Chapters 2, 5 and 6 already ended that way; Ch 4 left alone.

### 2. Part III is out of proportion with its job — done 16 Oct
The verdict (two hard sessions a week) comes from Part III, the shortest part at 8,351 words; Part IV, on everything outside the title, is 16,298. Fuelling is the longest chapter (about 6,000 words, 13 sections) and finishes with a run of mini-verdicts (caffeine, ketones, beetroot, cherry juice). Proposal: shrink Part IV rather than pad Part III, e.g. turn Fuelling's mini-verdicts into one short table.
- Done: Caffeine, Ketones and Beetroot juice merged into one section, "Caffeine, ketones, beetroot and cherry juice", led by a five-row table; the three gut-training trials condensed. Fuelling down by about 400 words (to about 6,000 including the From the saddle prompt).

### 3. The core advice is spelled out in full several times — done 16 Oct (partly)
"Two hard sessions, 48 hours apart, the rest easy near the top of Zone 2." On checking, the full restatements are fewer than the review first said: How many (Ch 12, its thesis), The training week (Ch 17, where the week is built), Special cases (Ch 18, opening) and the Verdict (opening answer, the graded claim, and "The week, once more"). Ch 8's ending is a one-line pointer, not a restatement.
- Done: Ch 18's opening restatement cut to a reference back.
- Left: Ch 12 and Ch 17 (each is where the advice is derived or built); the Verdict's three, which are the answer, the scorecard and the closing recap.
- Decided 16 Oct: the Verdict keeps all three, as each does a different job (the answer, the evidence, the checklist a reader will look up). George can overrule.

### 4. Two features cover the same study back to back — done 16 Oct
- Drugs: the close-up and Reading the research are both on the Leiden EPO trial (about 1,200 words together).
- Heat: the Copenhagen close-up is followed straight away by a box on markers covering the same trials.
- Designing intervals: Seiler 2013 is told in the opening and set out again as the close-up table.
Not every chapter needs both features; where a table now does the job, the close-up could go.
- Done: Designing intervals now opens on Zátopek and tells Seiler 2013 in three sentences, leaving the detail to the table. Heat's markers box no longer repeats the trials' numbers. Drugs: kept both (the box is the chapter's main lesson in reading a null result), and tightened where the box repeated the close-up.

### 5. No navigation between parts — done 16 Oct
- The parts exist only in the Introduction's outline paragraph; the proof has no part title pages.
- Part IV's title, "Everything else", is still a working title.
- Chapter endings use eight names ("What to do with it", "What to take from it", "What this means for training", "What this means for a rider on six to ten hours", "Who it is for", "What changes and what doesn't", "The sessions, in brief", and others). One consistent name for the practical ending would help readers looking something up.
- Done: part title pages (right-hand, blank back) in the proof, and part headings on the review page and in its contents; set in `PARTS` in render.py. Part IV renamed *Other ways to get faster* and Part V named *Putting it together* (George to confirm both). Practical endings are now all "What to do with it" (Chapters 1, 2, 3, 9, 10, 13, 14, 15, 17, 18, 19); chapters whose ending is something else keep their own (4 The questions, 5 The terms, 6 Keeping the numbers right, 7 Who it is for, 8 Six to ten hours a week, 11 The sessions in brief, 12, 16).

## Keeping the reader wanting more

### 6. The book's built-in mystery isn't used — done 16 Oct
The Introduction asks why George rode Sa Calobra 2:11 faster; the answer (regularity, not the lower intensity) is in a subsection near the end of Ch 7. Sa Calobra appeared only in the Introduction and the Verdict.
- Done: Ch 7 now opens with the winter and the explanation George gave at the time, and says the studies point to a plainer one; the payoff stays where it was, late in the chapter.
- Done: Ch 12, the end of Part III, closes by setting the winter against the part's finding. **George to check** that paragraph, as it describes his winter (from his own words in the Introduction and Ch 7's From the saddle).
- The Verdict already closes the loop ("What I believed, and what I found").

### 7. George's voice disappears halfway through — done 16 Oct
All seven From the saddle boxes are in Chapters 2–9; Chapters 10–20 (about 45,000 words) have none. Questions only George can answer:
- **Ch 11 Designing intervals:** which interval sessions do you actually ride, and how do they feel by the last rep?
- **Ch 13 Fuelling:** your habit of out-eating the people you ride with (currently in Durability) could get a sister box here.
- **Ch 15 Heat training:** training in a 37 °C garage in the 2026 heatwave (currently in Durability); its natural home is Heat.
- **Ch 17 The training week:** what does your week look like now?
- **Ch 18 Special cases, Indoors:** your whole winter happened on a trainer in the garage.
- **Ch 14 Strength:** do you lift?
- **Ch 19 Knowing it's working:** how do you tell whether your training is working?
(Standing rule: never ask about weight.)
- 16 Oct, at George's request: each question is now a highlighted `> **From the saddle.** [GEORGE: …]` box in its chapter, where the answer would go. `check.py` flags every `[GEORGE:` so none can reach print.
- Done: George answered all seven on the review page the same evening; each box is his words lightly edited, with his original text in that chapter's research.md. Chapters 11, 13, 14, 15, 17, 18 and 19 now have a From the saddle box. Only one line was added outside a box (Ch 17: one rider over a few weeks can't separate the intervals from anything else that changed).

### 8. The chapter openings repeat one formula — done 16 Oct (partly)
Nine of the twenty chapters open "In [year], [researcher]…". Chapters 6 and 7 opened with definitions instead of a scene.
- Ch 7: done (point 6).
- Ch 11: done. Opens on Zátopek's 40 or 60 × 400 m, then Seiler 2013 as the measured answer.
- Open: the other "In [year], [researcher]" openings are left; with two changed, nine of twenty is now seven.

### 9. Many chapters end by deflating — done 16 Oct
Chapters 3, 7, 12, 18 and 19 end on a caveat and a grade badge. Keep the caveat a paragraph earlier and end on the open tension the next chapter takes up, stated as a fact (style.md bans signposting and rhetorical questions). Example: Ch 7 could end on "per hour, harder riding wins, and the champions still rode easy", which leads into Ch 8. Endings that already work: Ch 5 (hands over to Part II), Durability ("it will change this chapter"), Heat (how a fashion forms), the Verdict ("ask what it was compared with"). Ch 12's ending changed under point 6.
- Done: Ch 3 (caveat moved up; ends on the Zone 2 tension), Ch 7 (caveat moved up; ends on "per hour, harder riding does more, and yet the best endurance athletes in the world do most of their training easy", into Ch 8), Ch 18 and Ch 19 (grade badges moved off the last line).

### 10. The middle is the heaviest stretch — done 16 Oct (partly)
- Numbers per 100 words: Ch 8 6.9, Ch 11 6.4, Ch 5 5.9; book average about 3.5.
- Longest sentences: Chapters 11 and 12, about 24–25 words against about 20 elsewhere.
- Done: Ch 11's five short sections (How hard, Fixed power or all-out, Recoveries and warm-up, Order and variety, Women and men) merged into one, "Riding the sessions"; Ch 11 now has 11 sections instead of 15.
- Done 16 Oct: about 25 of the longest sentences in Ch 11 and 12 split (mean now 23.2 and 21.8 words). Numbers trimmed where a figure or an earlier paragraph already carries them: Ch 8 from 7.6 to 7.1 numbers per 100 words by my count, after adding Brownlee; Ch 5 from 5.9 to 5.5. What is left is mostly in the trials and tables.

## What already works
- The Introduction's opening and the Verdict's "No, it isn't just Zone 2."
- The scene openings of Effort and pain, Durability, Heat and Drugs.
- One line of humour per chapter.
- The new tables (Chapters 5, 6, 8, 13, 15).
- Drugs is the most gripping chapter; just before the practical Part V it is a good change of pace.

## Suggested order (as of 16 Oct, all ten points done or decided)
1. George's From the saddle answers (point 7).
2. The Sa Calobra thread and Ch 7's opening (point 6). Done 16 Oct.
3. The repeated advice and Ch 11's short sections (points 3 and 10). Done 16 Oct.
4. Whether Ch 4 moves and whether Fuelling's tail shrinks (points 1 and 2).
5. Part title pages (point 5).
