# Style guide

The book should read as if a careful, well-read cyclist wrote it: someone who has read the papers, has opinions, and respects the reader's intelligence. Most of what makes text read as machine-written is vagueness and tics. Precision and a real point of view remove most of it.

`tools/check.py` enforces the mechanical parts of this guide. It can't judge whether a paragraph is good. That's George's job and the copy-editor's.

## What every chapter does

The book has two aims (see `plan.md`): explain the mechanism behind each training claim, and teach readers to judge the research themselves. In practice:

- **Separate mechanism from outcome.** Say which claims rest on biology ("this should happen because…"), which on observation ("riders who do X tend to…") and which on trials ("when people were assigned to X, they…"). Fashions spread on the first; only the last shows cause and effect.
- **Explain the biology at the level the argument needs.** Enough for an interested reader to follow why, not a textbook. Name the key molecules and structures (AMPK, PGC-1α, mitochondria, capillaries, stroke volume) once, explain them in the How bodies adapt chapter, and refer back.
- **Show the reasoning, not just the verdict.** When the book grades a claim, the reader should be able to see how they'd have reached the grade themselves.
- **Name the fashion when there is one.** If a claim is popular, say where it came from and what it rested on at the time.

## Voice

- First person singular for George's experience and opinions ("I rode…", "I'm not convinced…"). The book can say "we" only when it means the reader and author together working through an argument, and sparingly.
- Address the reader as "you" when giving practical advice.
- Have opinions, and label them as opinions. "The evidence for this is thin, and I think it's oversold" is better than a careful survey that commits to nothing.
- Disagree with experts when the evidence supports it. Respect for researchers shows in describing their work accurately, not in praising it.
- Technical is fine. Explain a term the first time it appears, then use it. Don't re-explain.
- British spelling and usage: programme, fibre, metre, litre, centre, -ise endings (organise, recognise), haemoglobin, oesophagus, "while" not "whilst".

## Evidence and numbers

- Name the study. "A 2015 Norwegian trial in 16 trained cyclists" beats "research shows". Never write "studies show", "research suggests" or "experts agree" without saying which.
- Give the number, with its comparison. "VO₂max rose 8.7%, against 2.6% in the long-interval group" beats "a significant improvement".
- Say how big the study was and how long it ran whenever a result carries weight.
- Separate statistically significant results from trends and effect sizes. Say "a trend that fell just short of significance" when that's what it was.
- Every number traces to `research.md`, and from there to a page, table or figure in the paper. Rounding is fine; changing a number is not.
- Hedge once, and only where the evidence is genuinely uncertain. "May potentially help to" is three hedges. Pick one, or state the grade instead.
- Don't give every point equal weight. Say which findings matter most.

### Evidence grades

Mark major claims with a grade after the citation:

- **{grade A}** several randomised trials, or a well-conducted meta-analysis, pointing the same way.
- **{grade B}** consistent findings, but from small studies, short studies, a single lab, or one well-designed trial.
- **{grade C}** observational data, mechanism, case studies or expert opinion.

Grade the claim, not the paper. A strong trial can support only a weak version of a claim.

## Structure

- Prose, in paragraphs. Lists only for things that really are lists: session structures, steps of a test, a reference table. Never bold-led bullet points standing in for an argument.
- Paragraphs vary in length. Some are one sentence. Most are three to six.
- Sentences vary in length. A long sentence that builds an explanation can be followed by a short one.
- A paragraph can end on a fact. It doesn't need a summary line or a moral.
- No signposting ("In this chapter we will explore…", "Let's dive in", "As we'll see"). Start with the substance.
- No conclusion paragraphs that repeat the chapter. End on the most important or most useful point.
- Headings name the content plainly. No puns, and no colon-subtitles on every heading.

## Sentences the reader could have written

Cut any sentence a reader could have supplied without opening the book. The usual form is a general truth placed in front of the real point: "A solo win depends on who is chasing, the course and the wind", "Everyone responds differently to training", "Many factors affect performance". They sound balanced and say nothing.

Three tests:

- **Could the reader have written it?** If an interested cyclist already knows it, it isn't doing any work.
- **Is anything in it specific to this case?** A name, a number, an event, a finding. If the sentence would fit unchanged in any chapter of any cycling book, cut it.
- **Does the paragraph lose anything without it?** Delete it and reread. Usually the specific sentence that followed makes the point on its own.

Make the general point through the particular. Not "a solo win depends on the chase" but "his lead fell by two and a half minutes in the last 45 km, and nothing public says whether he was fading or the bunch was finally racing". The same goes for lists of generic factors ("depends on X, Y and Z"), for caveats that apply to all research ("more studies are needed", "results may vary"), and for sentences that only announce that something is complicated. If a caveat matters, say which study it applies to and what it changes.

Real races told in detail are the model for the particular (George, 5 October 2026, on the van der Poel and Pogačar openings of Durability): where the attack went, how far out, the gap at a named point, the margin, what the rider said afterwards. Use them where a chapter has a natural one, with every detail checked against official results.

## Words and phrases to avoid

The checker flags these. A few have legitimate uses (a "robust" statistical method, a "landscape" photo); keep those only when the plain meaning is intended.

**Words:** delve, tapestry, landscape (figurative), realm, crucial, pivotal, paramount, robust (outside statistics), nuanced, intricate, multifaceted, foster, leverage, unlock, harness, navigate (figurative), journey (figurative), embark, testament, game-changer, revolutionary, groundbreaking, cutting-edge, seamless, holistic, synergy, elevate, empower, supercharge, unleash, myriad, plethora, vibrant, bustling, meticulous, invaluable, transformative, ever-evolving, underscore, showcase, boasts, nestled, beacon, cornerstone, linchpin, treasure trove, dive deep.

**Phrases:** the honest answer, the honest reading, honestly, to be honest, in all honesty, let's be honest, frankly, it's worth noting, it is important to note, interestingly, importantly, notably, crucially, when it comes to, at the end of the day, in today's world, in the world of, the reality is, the truth is, here's the thing, let's dive in, let's explore, in conclusion, ultimately, in summary, all in all, needless to say, it goes without saying, not only … but also, a deep dive, the key takeaway, food for thought, a double-edged sword, the elephant in the room, stands as a, serves as a reminder.

## Patterns to avoid

- **"It's not X, it's Y"** and **"not just X, but Y"**. State Y.
- **The colon reveal.** "The answer? Mitochondria." Write the sentence.
- **Rhetorical questions** as openers or transitions. A real question the chapter then answers is fine, once.
- **Lists of three** by reflex. Use the number of items the content has.
- **Dashes as all-purpose punctuation.** Use commas, colons, brackets or a full stop. The checker flags more than about one em dash per 500 words.
- **Stacked adjectives** ("a powerful, elegant, deeply influential study"). One accurate adjective, or a number.
- **The mirrored pair.** Two short sentences built to the same pattern and set against each other, usually to close a paragraph: "The races illustrate what durability looks like. The claims rest on the studies." Also its one-sentence forms: "an individual without his numbers, numbers without individuals"; "It can tell you X. It can't tell you Y." The symmetry makes a line sound like a conclusion whether or not it says anything, and it is often a summary of what the paragraph already showed. Say the point once, in an ordinary sentence with the specifics in it, or cut it. A real contrast between two findings is fine; give each its numbers.
- **The teaser.** Holding back what a sentence is about to make it sound intriguing: "one that tested something unexpected", "it comes with a complication", "the most interesting finding", "one detail matters". Name the thing: "one study of strength training". Call a result surprising only if it surprised the researchers or overturns something the reader was told earlier, and then say what was expected.
- **Uplifting closers** ("…and that's what makes the journey worthwhile").
- **Scare quotes** around ordinary terms.
- **Synonym cycling** (study / paper / investigation / research in four consecutive sentences). Repeat the plain word.

## Terms and units

- VO₂max (subscript 2). VT1/VT2 and LT1/LT2 defined on first use in each chapter.
- "Zone 2" capitalised; zones written with numerals.
- Power in W, relative power in W/kg, heart rate in beats per minute (bpm after first use), lactate in mmol/L.
- Percentages as numerals with % ("8.7%"). Numbers one to nine in words except with units ("4 minutes", "four sessions").
- Study designs named plainly: randomised controlled trial, crossover, cohort, cross-sectional.

## Special elements

- **From the saddle.** George's experience, in a blockquote headed `> **From the saddle.**`. His words, lightly edited. Never invented: if George hasn't supplied it, the draft leaves a placeholder `> **From the saddle.** [GEORGE: …question…]`.
- **One study, up close.** One per chapter, headed `### One study, up close: <name>`. Who was studied, the design, what was measured, the result with numbers, and what the study can't tell us.
- **How it works.** The mechanism, before the evidence. Plain explanations, analogies only where they're accurate, and a diagram where it helps. Mark speculation as speculation.
- **Reading the research.** One skill per chapter, practised on a real study from that chapter: e.g. correlation and causation, small samples and unstable correlations, "a trend that didn't reach significance", responders and non-responders, lab markers against performance, who was studied. Short: 300 to 500 words.
- **Figures.** Redrawn from published data, with the source in the caption. No copied figures.

## Quotations

- Quote researchers sparingly and briefly, with attribution. A few words from a paper or interview, never long passages.
- Summarise in our own words otherwise.
