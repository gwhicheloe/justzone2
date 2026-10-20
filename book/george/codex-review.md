# Editorial review: clarity and voice

18 October 2026. Applied to the Introduction and all 20 chapter drafts.

The initial editorial pass reduced the manuscript from 87,066 to 80,061 words: a net reduction of 7,005 words (8.0%). Both totals use the existing review renderer’s counting method, including headings and captions and excluding citation markup.

The book’s strongest thread is George testing his own explanation for the Sa Calobra improvement against the evidence. The studies are most readable when they answer a specific question in that story. The remaining machine-like habits were mainly structural: repeated interpretations, balanced pairs of short sentences, announcements of what a section would do, and generic caveats. These were more common than conspicuous vocabulary.

The edit removes those habits without imposing a uniform sentence length or opening formula. Anecdotes, humour, useful historical examples and the practical reference material remain. Some repetition between evidence chapters, practical chapters and the Verdict is deliberate, so readers can use those sections independently.

## Changes by chapter

| Chapter | Words removed, net | Main change |
|---|---:|---|
| Introduction: Why ask the question | 140 | Shortened the aims and removed the final transition announcing Chapter 1. |
| Chapter 1: What limits endurance | 224 | Removed repeated descriptions of the model and formulaic closing contrasts. |
| Chapter 2: How bodies adapt to training | 268 | Cut repeated explanations of signalling; shortened the interpretation around the studies. |
| Chapter 3: Effort, pain and the brain | 187 | Removed repeated verdicts and generic caveats; kept the distinctions between effort, pain and fatigue. |
| Chapter 4: How to read a training study | 352 | Shortened general warnings; kept the worked examples and study questions. Corrected the stray median of 12 to 11. |
| Chapter 5: Intensity, properly defined | 219 | Tightened explanations of domains and zone systems; removed announcements and repeated conclusions. |
| Chapter 6: Finding your zones | 343 | Removed the repeated three-part rhythm around easy effort and repeated readings of the HRV table. |
| Chapter 7: What easy riding does to the body | 329 | Reduced repeated recovery and volume arguments; kept the winter story and its explanation. |
| Chapter 8: Why elite athletes ride easy | 258 | Reduced repeated accounts of the champions’ hard dose; kept the history and comparisons between sports. |
| Chapter 9: Durability | 426 | Removed the second discussion of the race openings; kept their limits beside the professional data. |
| Chapter 10: Beyond performance | 312 | Shortened repeated marker-versus-outcome explanations; clarified the review’s conclusion and the active control group. |
| Chapter 11: Designing intervals | 353 | Shortened the opening summary and repetitions after tables; distinguished running injury findings from cycling evidence. |
| Chapter 12: How many hard sessions, and how often | 428 | Removed repeated diary/history material and shortened the significance lesson and recovery explanation. |
| Chapter 13: Fuelling | 510 | Cut repeated modern-versus-historical comparisons and commentary around gut training and reviews. |
| Chapter 14: Strength training | 253 | Removed the repeated “why racing is faster” aside; shortened generic caveats and unsupported injury rhetoric. |
| Chapter 15: Heat training | 326 | Shortened the two-purpose introduction and repeated mechanism summaries; clarified no advantage over controls versus no improvement. |
| Chapter 16: Drugs | 439 | Removed signposting and numbered moralising; kept attribution and naming restrictions. Corrected the fuelling comparison and null-result interpretation. |
| Chapter 17: The training week | 644 | Removed the obsolete website-planner aside and repeated explanations of the hard-dose ratio; kept the worked weeks. |
| Chapter 18: Special cases | 314 | Removed repeated declarations about women’s training; shortened the indoor interpretation and time-limited advice. |
| Chapter 19: Knowing it's working | 392 | Shortened repeated comparisons with watches and software, simulation commentary and explanations after the HRV table. |
| Chapter 20: The verdict | 288 | Kept the answer, graded scorecard and closing week; shortened repeated personal conclusions and research gaps. |

## Corrections affecting the argument

- The second reference to median study size in Chapter 4 now agrees with its own tally: 11, rather than 12.
- Beyond performance now distinguishes no extra survival benefit over activity guidelines from a comparison with no exercise. Its Canadian-review paragraph also makes clear that the trials challenge the superiority claim, rather than contradicting the sceptical review.
- Heat training now says the heat groups gained no performance advantage over controls, rather than saying performance did not move at all.
- Drugs no longer compares the entire benefit of fuelling versus water with the historical gain from EPO as if that established the contribution of modern fuelling. It also keeps the uncertainty around the Ventoux result when discussing amateurs, and drops an unsupported summary calling medically supervised drug risk small.
- The practical advice distinguishes controlled threshold sessions from the harder pacing of long intervals and 30/15s. It no longer presents running-sprint injury findings as a general cycling risk.
- Finding your zones now describes lactate as the book’s chosen reference in its closing box, matching the chapter’s admission that its superiority over breathing has not been demonstrated.

## Evidence questions resolved at George’s request

Both questions were resolved on 18 October 2026 after George asked to downgrade the first and adjust the second.

1. **Grades for descriptive evidence.** The two diary-based claims in Chapter 8’s closing box and the Verdict’s elite-pattern claim now carry grade C. The scorecard’s CSV source and generated SVG also carry C. The book’s grading definitions are unchanged.
2. **One hard session a week maintains fitness for months.** Chapter 12 now separates the grade B maintenance findings for reduced training with intensity retained from the grade C suggestion to keep one hard session plus easy riding during a busy period. It explicitly says the studies did not test that exact mix. Chapters 17, 18, 19 and the Verdict use the same qualified advice; the promise of maintaining fitness for months on one hard session has been removed.

This was an editorial correction using the evidence already described in the manuscript, not a new verification of the original studies.

## Verification and review files

- All 21 drafts were read and edited. The original drafts were clean in Git at the start, so their changes can be reviewed in the diff.
- Automated comparisons at the end of the initial pass confirmed every From the saddle block, trial table, formula, figure caption/path and evidence-grade tag was unchanged. The follow-up changed the grades and scorecard described above. No figures or study tables were removed.
- Every remaining citation key resolves in sources.yaml. Three chapter-local source keys disappeared with repeated passages; those studies remain in the source catalogue and other chapters.
- At the end of the initial pass, the style checker reported 79 heuristic flags, against 83 before. The announcement-pattern and crowded-citation warnings are gone. Remaining flags concern source proximity, sentence rhythm, legitimate lists, Carl Foster’s surname and a quoted phrase. The checker still exits 1; this is not a clean checker pass.
- The Introduction’s mitochondria/bike line still holds: 49 occurrences against 35 in the drafts.
- book/review/book.html has been rebuilt in reading order. It contains 21 chapters, and all internal navigation and reference links resolve.
- The PDF proof has now been rebuilt from the edited drafts; see the verification below.

Follow-up verification: review HTML rebuilt at 80,117 words; chapter grades, scorecard data/SVG and rendered grade agree. The former one-session maintenance promises are absent from every draft, all citation keys and internal links resolve, and `git diff --check` is clean. The style checker now reports 80 heuristic flags, including one additional sentence-rhythm warning. The PDF proof has since been rebuilt.

## PDF proof regenerated

18 October 2026, at George’s request. The current 6 × 9 inch proof has 262 pages and 80,117 words across the Introduction and 20 chapters. It is saved at `book/review/proof-6x9.pdf`, with the deliverable copy at `output/pdf/proof-6x9.pdf`.

All 262 pages were rendered and reviewed in contact sheets, with full-size checks of the scorecard and dense tables. All 21 chapter openings fall on right-hand pages, all 16 trial tables have their first and final content on the same page, and no extracted text lies outside the page bounds. The elite-pattern scorecard row shows grade C, and the qualified maintenance advice is present. Both saved PDF copies have identical hashes.
