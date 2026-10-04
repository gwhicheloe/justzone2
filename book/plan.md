# Just Zone 2? — book plan

Working title: **Just Zone 2?**
Subtitle (undecided): *The science of easy riding, hard intervals and getting fitter* is the current favourite.
Author: George Whicheloe. Publishing: Amazon KDP, ebook and print-on-demand paperback.
Outline review page: https://claude.ai/artifact/SBWhKnpVRAbQ2X69ZNoG9n
Draft review page (Intro + Chapter 1): https://claude.ai/artifact/SyoahnZLDrP2RVLxXWRZ1E
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

**Where things stand**
- Introduction and Chapter 1 (What limits endurance): first drafts, published for review at https://claude.ai/artifact/SyoahnZLDrP2RVLxXWRZ1E (source `book/review/intro-ch1.html`; republish that same file path to update it, or pass the URL from a new session). Awaiting George's comments and three [GEORGE: ...] answers: (1) is he happy for the intro to correct his own May blog claim about mitochondria; (2) a short bio; (3) whether to state how the book was written.
- Chapter 8 (Durability): brief approved; research in progress. Remaining work is listed at the end of `chapters/durability/research.md`. George has been asked to fetch five paywalled papers (`papers-wanted.md`); check `book/papers/` for any that have arrived.
- Chapter 1 is about 3,400 words against a 5,500 target: expand after George's review, not before.

**Suggested next steps, in order**
1. Act on George's review of the Intro and Chapter 1 when it comes.
2. Finish Durability research (free papers via `tools/lookup.py oa` and `fulltext`; race facts against official results), then draft it.
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
| 8 | Durability | `durability` | II | 6,500 | — | **next: research, in progress** (see research.md: to-do list at the end) |
| 9 | Beyond performance | `beyond-performance` | II | 5,000 | parts of the evidence review | — |
| 10 | Time near VO₂max | `time-near-vo2max` | III The hard part | 5,000 | parts of the 30/15 post | — |
| 11 | Designing intervals | `designing-intervals` | III | 7,000 | `website/research/30-15-intervals.html` | — |
| 12 | How many hard sessions, and how often | `how-many` | III | 6,000 | `website/research/how-many-hard-sessions.html` | — |
| 13 | The training week | `training-week` | IV Putting it together | 5,000 | planner logic (`website/js/planner.js`) | — |
| 14 | Special cases | `special-cases` | IV | 7,000 | — | — |
| 15 | Knowing it's working | `knowing` | IV | 6,000 | — | — |
| 16 | The verdict | `verdict` | — | 3,000 | — | — |

Total target: about 93,000 words. To get back nearer 80,000 if wanted: trim Beyond performance and fold The training week into The verdict.

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
