# Style guide

The book should read as if a careful, well-read cyclist wrote it: someone who has read the papers, has opinions, and respects the reader's intelligence. Most of what makes text read as machine-written is vagueness and tics. Precision and a real point of view remove most of it.

`tools/check.py` enforces the mechanical parts of this guide. It can't judge whether a paragraph is good. That's George's job and the copy-editor's.

## What every chapter does

The book has two aims (see `plan.md`): explain the mechanism behind each training claim, and teach readers to judge the research themselves. In practice:

- **Separate mechanism from outcome.** Say which claims rest on biology ("this should happen because…"), which on observation ("riders who do X tend to…") and which on trials ("when people were assigned to X, they…"). Fashions spread on the first; only the last shows cause and effect.
- **Explain the biology at the level the argument needs.** Enough for an interested reader to follow why, not a textbook. Name the key molecules and structures (AMPK, PGC-1α, mitochondria, capillaries, stroke volume) once, explain them in the How bodies adapt chapter, and refer back.
- **Show the reasoning, not just the verdict.** When the book grades a claim, the reader should be able to see how they'd have reached the grade themselves.
- **Name the fashion when there is one.** If a claim is popular, say where it came from and what it rested on at the time.

## Choosing what to cover

(George, 11 October 2026.) The well-known papers on a topic are the ones every article and podcast already uses. A book built only from them reads like the average of everything else written on the subject.

- **Cover the big papers.** A reader who has heard of Seiler, Coggan or San Millán expects them to be dealt with, and the argument usually needs them.
- **Then go off the main road.** If something adjacent to the topic looks interesting, follow it and put it in: an odd study design, an old or forgotten paper, work from another sport or another field, a result that cuts against the consensus, a strange episode in the history of an idea. It does not have to be essential to the argument. It has to be interesting and accurately described.
- **Prefer the less-used example** when two would make the same point.
- **The evidence rules still apply.** A side road gets the same checking, the same numbers in `research.md` and the same grade as anything else. An odd study is often a small one: say so.
- **Side roads support a chapter and do not lead it.** George's comment on the first draft of Finding your zones (11 October 2026) was that it spent too long on maximum heart rate and the bad ways of finding it, when the chapter's subject was the lactate threshold. Lead with what the chapter is about: what it is, the biology, and why the reader should care. The less-used material comes after, in proportion. (The wording of this rule is Claude's reading of his comment.)
- **Where the field offers several definitions, the book picks one and says why** (same comment). Say what the choice costs and how strong the case for it is, then hold to it.
- **Look for them on purpose.** At the research stage, list candidate side roads in the chapter's `research.md` under "Side roads", including those not used, so George can pick.

## Voice

- First person singular for George's experience and opinions ("I rode…", "I'm not convinced…"). The book can say "we" only when it means the reader and author together working through an argument, and sparingly.
- Address the reader as "you" when giving practical advice.
- Have opinions, and label them as opinions. "The evidence for this is thin, and I think it's oversold" is better than a careful survey that commits to nothing.
- Disagree with experts when the evidence supports it. Respect for researchers shows in describing their work accurately, not in praising it.
- Technical is fine. Explain a term the first time it appears, then use it. Don't re-explain.
- British spelling and usage: programme, fibre, metre, litre, centre, -ise endings (organise, recognise), haemoglobin, oesophagus, "while" not "whilst".

## Evidence and numbers

- **The Introduction is the exception** (George, 7 October 2026): keep it easy-going. Tell the story of each study and give at most the one or two figures that carry the point, such as how small or short it was. The detail belongs in the later chapters; a wall of numbers on the first pages puts readers off.


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

### Which sources are printed

George, 15 October: "some of the reference lists are massive… if they're not directly quoted or they're not key to a chapter can we drop them". Each chapter prints only the references a reader needs; the rest are kept with their sentence as `{shadow @key}`, which the review page shows faintly and the print proof leaves out. Nothing is deleted: the shadow source stays as the check on the sentence.

Printed, `[@key]`:
- any direct quotation (always: a quotation without a reference is not allowed);
- the *One study, up close* study, and the source of every figure and trial table;
- the studies and reviews the chapter's position rests on, usually the ones carrying a grade, and the main evidence for each section;
- anything said about a named person, team or organisation (the doping chapter keeps nearly everything; so do the race reports and Pogačar's interview);
- safety claims (heat illness, drinking too much, energy deficiency);
- a source another chapter points to ("Chapter 9 describes…"), in the chapter pointed to.

Shadow, `{shadow @key}`: everything else, including supporting studies described in the text, background physiology, history, second sources for one point, and sources described in full in another chapter. The text still names the study in words ("a 2019 Brazilian group"), which is the credit; the reference list is for checking. Any shadow source can be promoted back to `[@key]` if George wants it printed. First applied 15 October: 490 printed references across 18 chapters became 256. If the full list is to be available to readers, it would go online, which is George's decision.

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
- **The announcement.** A sentence whose only job is to say how many points follow or what the section is about to do: "This book has two aims, and every chapter works towards both", "There are three main ways", "Three things in the details matter", "Two caveats belong with that". The count promises a list the next sentences deliver anyway, and the tidy universal ("every chapter", "each of these") is there for symmetry. Start with the first point. Test: delete the sentence; if no information is lost, leave it deleted. A number is fine when it is itself the claim ("the blood adapts in two stages", "only one of the two is well supported") or when it introduces a real numbered list. Avoid sweeping statements about the book itself.
- **The teaser.** Holding back what a sentence is about to make it sound intriguing: "one that tested something unexpected", "it comes with a complication", "the most interesting finding", "one detail matters". Name the thing: "one study of strength training". Call a result surprising only if it surprised the researchers or overturns something the reader was told earlier, and then say what was expected.
- **Uplifting closers** ("…and that's what makes the journey worthwhile").
- **Scare quotes** around ordinary terms.
- **Synonym cycling** (study / paper / investigation / research in four consecutive sentences). Repeat the plain word.

## Terms and units

- **Cycling's own vocabulary gets a definition or it doesn't get used** (George, 10 October 2026). Words like *engine*, *base*, *form*, *sweet spot* and *the bonk* are common in the sport and loose in meaning, and a book that asks readers to be precise can't use them loosely. Either define the word at first use and hold it to that one meaning throughout the book, or write the plain term. Agreed so far: **the engine is the whole aerobic system described by the model in Part I** (defined in the opening of What limits endurance, and matching the Part I title, *The engine*, which George chose to keep). It is never a synonym for VO₂max or any other single measure; where one measure is meant, name it. *Aerobic base* is not used; write "aerobic fitness" or name the adaptation.

- VO₂max (subscript 2). VT1/VT2 and LT1/LT2 defined on first use in each chapter.
- "Zone 2" capitalised; zones written with numerals.
- Power in W, relative power in W/kg, heart rate in beats per minute (bpm after first use), lactate in mmol/L.
- Percentages as numerals with % ("8.7%"). Numbers one to nine in words except with units ("4 minutes", "four sessions").
- Study designs named plainly: randomised controlled trial, crossover, cohort, cross-sectional.

## Special elements

(Loosened by George, 11 October 2026.) The three recurring elements below are a toolkit. A chapter uses the ones that help it and leaves out the rest, so that 21 chapters do not all run in the same order with the same boxes.

- **None is compulsory.** A chapter with no single study worth a close look has no close-up. A chapter that is mostly mechanism does not need a separate How it works section. A chapter can have two close-ups if two studies deserve it.
- **Order follows the argument.** Mechanism does not have to come before evidence. A close-up can open the chapter or close it. Reading the research goes where the skill is needed.
- **Vary the form.** A close-up can be a study, a dataset, a single race, a historical episode or a dispute between two papers. Reading the research can be a box, or a few paragraphs worked into the text with no heading.
- **Keep the heading when it is a box**, so readers recognise the feature: `### One study, up close: <name>` and `### Reading the research: <skill>`.
- **Across the book**, most chapters should still explain the mechanism somewhere, and each skill from How to read a training study should be practised at least once. Check this over the whole book, not chapter by chapter.
- **Openings vary.** Not every chapter starts on a study. A race, a piece of kit, a common piece of advice, a number or George's own experience can open one.

What each element is, when used:

- **One study, up close.** Who was studied, the design, what was measured, the result with numbers, and what the study can't tell us.
- **How it works.** The mechanism. Plain explanations, analogies only where they're accurate, and a diagram where it helps. Mark speculation as speculation.
- **Reading the research.** One skill, practised on a real study from that chapter: e.g. correlation and causation, small samples and unstable correlations, "a trend that didn't reach significance", responders and non-responders, lab markers against performance, who was studied. Short: 300 to 500 words.
- **From the saddle.** George's experience, in a blockquote headed `> **From the saddle.**`. His words, lightly edited. Never invented. Use it only where George has already said something (his words are kept in `george/notes.md`); otherwise the chapter has no box. No placeholders asking for his experience: George, 15 October, asked for them to be filled or dropped, and they were dropped. It can sit anywhere, more than once.
- **Figures.** Redrawn from published data, with the source in the caption. No copied figures.
- **Chart titles state the point** (George, 11 October 2026): a chart's title is the main thing it is meant to show, written as a claim ("Small trials that reach significance overstate the effect"), not a description of what was plotted. What was plotted goes in the line under the title or in the caption.

## Quotations

- Quote researchers sparingly and briefly, with attribution. A few words from a paper or interview, never long passages.
- Summarise in our own words otherwise.
