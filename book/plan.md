# Just Zone 2? — book plan

Working title: **Just Zone 2?**
Subtitle (undecided): *The science of easy riding, hard intervals and getting fitter* is the current favourite.
Author: George Whicheloe. Publishing: Amazon KDP, ebook and print-on-demand paperback.
Outline review page: https://claude.ai/artifact/SBWhKnpVRAbQ2X69ZNoG9n
Review and commenting page (all drafted chapters): https://claude.ai/artifact/7897dncKjTc7fkjLcHx4KJ (the three older per-chapter review pages were deleted on 8 October 2026)
Render drafts for review: `python3 book/tools/render.py book/review/<name>.html book/chapters/<a>/draft.md ...`. Look up papers: `python3 book/tools/lookup.py` (search, list, pmid, oa, fulltext).

## What the book is

A research-led book for interested cyclists about how endurance actually improves: what easy riding does, what hard intervals do, and how to combine them. It leans on published research and named researchers, explains studies properly, and can be technical. It should read as carefully written by a person, with as few AI habits as possible (see `style.md`). The app gets a mention in the introduction and on a closing page, nowhere else.

**Purpose (George, 3 October 2026).** Training advice goes through fashions, and Zone 2 is the latest. The book should help readers cut through the noise by doing two things in every chapter:

1. **Explain the mechanism.** The biology and physiology a training claim rests on, so readers understand *why* an effect should happen, not only that a study found one.
2. **Teach readers to judge research themselves.** Study design, sample size, effect sizes, trial against observation against mechanism, and the gap between a plausible mechanism and a demonstrated effect, so they can assess the next fashion without needing this book.

Fashions usually spread on a plausible mechanism before the outcome evidence exists. A reader who can tell "plausible" from "shown to work" can cut through the noise without us.

**Spine.** Joyner and Coyle's model of endurance performance (VO₂max × the fraction of it you can sustain × efficiency), plus durability as a fourth factor. Every training question in the book becomes: which of these does it change, and how good is the evidence?

## Handover (4 October 2026)

The book now has its own Claude session, separate from app work in the same repo.

**Two-session rules**
- Book sessions edit and commit **only `book/`**: stage with `git add book/...`, never `git add -A` or `git commit -a`. App work happens in another session at the same time.
- Don't run git commands while the other session might be committing. If git reports an `index.lock`, wait a few seconds and retry.
- Commit and push only when George says so.

**Where things stand (updated 5 October 2026)**
- Introduction and Chapter 1 (What limits endurance): first drafts, published for review at the whole-book page (the per-chapter page was deleted 8 Oct) (source `book/review/intro-ch1.html`; republish that same file path to update it, or pass the URL from a new session). No comments on the page and nothing new in `george/notes.md` as of 5 October. Still awaiting George's review and three [GEORGE: ...] answers: (1) answered 7 October by page comment: yes, happy for the intro to correct his own May blog claim (placeholder removed); (2) a short bio; (3) whether to state how the book was written.
- Chapter 8 (Durability): **complete first draft** (5 October, about 6,000 words against 6,500), self-reviewed, with George for review at the whole-book page (the per-chapter page was deleted 8 Oct) (source `book/review/durability.html`; publish with that URL to update). `check.py` leaves five flags, each justified: two rhythm notes, a worked kJ example, the figure placeholder and a paragraph of George's own reasoning. Open items are listed at the end of the "Added while drafting" section of `chapters/durability/research.md`: the figure (needs Mateo-March 2022), one [GEORGE: ...] placeholder on his own long rides, whether his golfer friend walks his rounds, race facts against official results, the direction of the Spragg 2023a correlations, researchers' names.
- George decided on 5 October: "durability" is the book's term; One study, up close is Norte 2026; Pogačar examples are Strade Bianche 2024 and Zürich 2024.
- In the draft for George to check: the Pyrenees passage says "In 2025" (his note said "last year"); the chapter refers to Chapters 1 and 2 by number, as Chapter 1's draft does.
- Chapter 1 is about 3,400 words against a 5,500 target: expand after George's review, not before.

- **Heat training (new chapter, requested by George 5 October):** brief, research notes and a complete first draft written in one session at his request (`chapters/heat-training/`). Covers the 2026 Tour heatwave, heat as a substitute for altitude, the five-week haemoglobin trials, the CORE sensor's validation studies, and cooling on the day (ice vests, slushies: added at George's request). George has no CORE sensor. Review page: the whole-book page (the per-chapter page was deleted 8 Oct) (source `book/review/heat-training.html`). Open: whether it stays a chapter or becomes a section of Special cases; one [GEORGE: ...] placeholder on the 2026 heatwave; news facts read through a summarising tool need checking on the pages; several papers are abstract only (list in research.md).
- Style guide gained four rules from George on 5 October: sentences the reader could have written, race anecdotes in detail, the mirrored pair, the teaser. **The Intro and Chapter 1 drafts have not been checked against them.**

- **Drugs (new chapter, requested by George 5 October):** brief, research notes and a complete first draft in `chapters/doping/`. Covers what EPO-era doping aimed at, the biology of EPO (George asked for this), how much it was worth (including the Leiden trial with the Mont Ventoux race), the risks and the "18 deaths" story, lessons from the era, why riders are faster now, and the moving edge of the rules (tramadol, carbon monoxide, ketones). **Libel rule in the chapter's brief: read it before editing.** No current rider is connected with doping; George's stated position ("I assume they are clean but perhaps pushing boundaries") is written as his. Firmed up later on 5 October: López 2011 read in full and the EPO-deaths passage rewritten from it; 1998 Tour, Pantani and EPO-approval facts checked and corrected (see "Firmed up" in research.md). Open: a legal read; remaining [Rep] facts to verify at primary sources (list in research.md); one [GEORGE: ...] placeholder. (Heuberger 2017 arrived from George on 6 October, was read in full and the Mont Ventoux box rewritten from it.) Not published as an artifact: George to say if he wants a review page. **6 October: George will not use a lawyer, so the chapter was rewritten to minimum risk** (rules and the list of named people are in the chapter's brief): the 2024 climbing comparison and every mention of Pogačar removed at his request ("he's my hero"), the only living person linked to doping is Armstrong, the French Senate retest list is not used.

- **Unlisted web copy for George to read (6 October):** all five drafted chapters on one page at https://www.justzone2.com/book/draft-6bd51bf9ce/ . Not linked from any page or the sitemap; `noindex` in the page and in `website/_headers` for `/book/*`. It is public to anyone with the URL, so do not share it, and take it down before anything else about the Drugs chapter changes its risk. To rebuild and redeploy: `python3 book/tools/render.py <tmp>.html book/chapters/{intro,limits,durability,heat-training,doping}/draft.md`, wrap it in a full HTML document with the robots meta tag, save as `website/book/draft-6bd51bf9ce/index.html`, then `npx wrangler pages deploy . --project-name=justzone2 --commit-dirty=true` from `website/`. `website/_headers` and `website/book/` are uncommitted (they are outside `book/`, so the book session does not commit them without George saying so). To remove: delete `website/book/` and redeploy.

- **Figures (started 7 October):** `python3 book/tools/figures.py` draws SVG figures from CSV data kept beside them in `chapters/<name>/figures/`. Greyscale only (the paperback prints in black ink; colour would add about £11 a copy). A draft includes a figure with `![caption](figures/name.svg)` on its own paragraph; `render.py` numbers and inlines it. Done and placed in the drafts (George: "good diagrams"): the EPO feedback loop and the Leiden trial forest plot (Drugs); oxygen's route (What limits endurance); critical power and W′ over two hours, and fall in critical power by carbohydrate dose (Durability); haemoglobin mass during and after five weeks of heat (Heat training). Not drawn: haemoglobin gain across the six heat trials (two report grams only, so a common percentage scale needs their baselines from the full texts); the Mateo-March figure (needs that paper). Every figure was checked by screenshot at 680 px; none has been checked at print size.
- **Commenting (7 October):** the whole book so far is one private artifact, https://claude.ai/artifact/7897dncKjTc7fkjLcHx4KJ (source `book/review/book.html`; republish that path to update, or pass the URL from a new session). George comments on the page; read them with the ArtifactComments tool (`action: "read"`, that URL), make the changes in the drafts, re-render, republish, and reply to or resolve the threads he has sent to Claude. The older per-chapter review artifacts are superseded.

**Suggested next steps, in order**
1. Act on George's review of the Intro and Chapter 1 when it comes.
2. Durability: act on George's review; then the revise stage (figure, re-check every number, the open items above).
3. Then follow the order of work in the status table.

## Start of every session

1. Read this file, then `style.md`.
2. Find the chapter marked **next** in the status table and read its `brief.md`, `research.md` and `draft.md`, whichever exist.
3. Check `george/notes.md` for anything new from George.
4. Do one stage (or one or two sections of drafting). Run `python3 book/tools/check.py <file>` on any draft text.
5. Update the status table and the chapter's files before stopping. Nothing important should exist only in the conversation.

Commit only when George says so (his standing rule for this repo).

## Stages per chapter

| Stage | Output | Gate |
|---|---|---|
| 1. Brief | `brief.md`: question, argument, sections with word budgets, sources needed, questions for George | George approves the argument |
| 2. Research | `research.md`: each finding checked against the paper, with numbers and where they appear (table, figure or page) | No number reaches a draft unless it is in here |
| 3. Draft | `draft.md`, written a section at a time | `check.py` passes, or each warning is justified |
| 4. George's pass | Notes, stories, disagreements in `george/notes.md` or comments in the draft | |
| 5. Revise | George's material worked in, figures and the "one study, up close" box added | `check.py` again; every number re-checked |
| 6. Done | Status set to done | |

## Status

Stage values: — (not started), brief, research, draft, review, revise, done.

| # | Chapter | Folder | Part | Words (target) | Existing material | Stage |
|---|---|---|---|---|---|---|
| Intro | Why ask the question | `intro` | — | 3,000 | George's blog posts | **draft 1** (4 Oct; awaiting George's review; revisit at the end) |
| 1 | What limits endurance | `limits` | I The engine | 5,500 | — | **draft 1** (4 Oct, ~3,400 words; awaiting George's review) |
| 2 | How bodies adapt to training | `adaptation` | I | 6,000 | — | — (new, 3 Oct) |
| 3 | How to read a training study | `reading-research` | I | 5,000 | — | — (new, 3 Oct) |
| 4 | Intensity, properly defined | `intensity` | I | 5,000 | parts of the Zone 2 and find-your-zone posts | — |
| 5 | Finding your zones | `finding-zones` | I | 5,000 | `website/research/how-to-find-your-zone-2.html` | — |
| 6 | What easy riding does to the body | `easy-riding` | II The easy part | 7,000 | `website/research/zone-2-evidence-review.html` | — |
| 7 | Why elite athletes ride easy | `elites` | II | 6,000 | parts of the evidence review | — |
| 8 | Durability | `durability` | II | 6,500 | — | **draft 1 complete** (5 Oct, ~6,000 words; awaiting George's review). Next chapter in the order of work: Finding your zones |
| 9 | Beyond performance | `beyond-performance` | II | 5,000 | parts of the evidence review | — |
| 10 | Time near VO₂max | `time-near-vo2max` | III The hard part | 5,000 | parts of the 30/15 post | — |
| 11 | Designing intervals | `designing-intervals` | III | 7,000 | `website/research/30-15-intervals.html` | — |
| 12 | How many hard sessions, and how often | `how-many` | III | 6,000 | `website/research/how-many-hard-sessions.html` | — |
| 13 | The training week | `training-week` | IV Putting it together | 5,000 | planner logic (`website/js/planner.js`) | — |
| new | Heat training | `heat-training` | IV (proposed, before Special cases; number to assign) | 5,000 | — | **draft 1 complete** (5 Oct, ~4,400 words; awaiting George's review; brief not separately approved) |
| new | Drugs | `doping` | IV (proposed, after Heat training; number to assign) | 5,500 | — | **draft 1 complete** (5 Oct, ~4,100 words; awaiting George's review; **needs a legal read before publication**) |
| 14 | Special cases | `special-cases` | IV | 7,000 | — | — |
| 15 | Knowing it's working | `knowing` | IV | 6,000 | — | — |
| 16 | The verdict | `verdict` | — | 3,000 | — | — |

Total target: about 103,000 words with Heat training and Drugs (both added 5 October 2026). To get back nearer 80,000 if wanted: trim Beyond performance and fold The training week into The verdict.

Chapter folders are named by topic, never by number, so the order can change without renaming anything. Refer to other chapters by name in briefs and notes.

**Order of work:** Durability (pilot, to test the process, the voice and the new "How it works" and "Reading the research" elements), then Finding your zones, What easy riding does and How many hard sessions (rewrites of existing research), then What limits endurance, How bodies adapt and How to read a training study (the foundations later chapters refer back to), then the rest of Parts I to III, then Part IV. The introduction and The verdict last.

Existing website posts are rewritten for the book, never copied: the book has more room, a different reader and its own voice.

## Conventions

- **Citations:** Pandoc style, `[@maunder2021]` or `[@spragg2023a; @maunder2021]`. Every key must exist in `sources.yaml`. Later, Pandoc turns these into numbered references.
- **Sources:** `sources.yaml` records each paper and how far it has been checked: `candidate` (found, not read), `abstract` (abstract read), `fulltext` (results read). A number stated in an abstract can be cited exactly as given (it is the paper's own reported result). Anything beyond the abstract (per-condition tables, methods detail, limitations) needs `fulltext`. In `research.md`, tag every number [FT], [Abs] or [Rep].
- **Papers:** PDFs go in `book/papers/`, which is git-ignored. They are publishers' copyright and stay local. Papers George needs to get for me are listed in `book/papers-wanted.md`; free copies are found via OpenAlex (`api.openalex.org/works/doi:…`, look at `open_access.oa_url`).
- **Evidence grades:** after a major claim, `{grade A}`, `{grade B}` or `{grade C}` (defined in `style.md`).
- **George's material:** blockquotes starting `> **From the saddle.**` His words are kept, lightly edited.
- **How it works:** the mechanism section of each chapter, before the evidence: the biology behind the claim, pointing back to the How bodies adapt chapter rather than re-explaining it.
- **Reading the research:** a box per chapter, headed `### Reading the research: <skill>`, practising one skill from the How to read a training study chapter on a real study from that chapter.
- **Study boxes:** a section headed `### One study, up close: <short name>`.
- **Figures:** data in `chapters/NN-slug/figures/*.csv` with the source noted; charts drawn from that data, never copied from a paper.

## Decisions so far

- Title *Just Zone 2?* (agreed). Subtitle open.
- Audience: cyclists, drawing on other sports where the evidence is better (suggested; not yet confirmed).
- Length: full book, about 80,000 words (outline; not yet confirmed against a shorter first edition).
- Expert interviews: worth arranging once a draft exists. George to decide.
- All work lives in this repo under `book/` (George, 3 October 2026).
- Amazon will probably require an "AI-generated content" declaration at upload. Check KDP's wording before publishing.
