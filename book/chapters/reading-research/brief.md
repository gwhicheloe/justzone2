# How to read a training study (Chapter 4): brief

Status: **written with the first draft on 10 October 2026, at George's request ("let's do the next"). The argument has not been separately approved.**
Target: 5,000 words. Part I, *The engine*. First draft: about 3,750 words.

## The question

When a study says one way of training beats another, how much should you believe it?

## The argument (to approve)

1. A striking study usually supports a more modest sentence than the one that gets repeated. The chapter shows how to get from one to the other, using a study of six cyclists and a placebo (Beedie 2006) as the worked example.
2. Claims rest on mechanism, observation or experiment, and only randomised experiments show cause. The book's grades A, B and C follow from that.
3. Results apply to people like those studied. Most volunteers are untrained young men, in whom almost anything works.
4. What the comparison group did, and what was matched (work or time), often decides the result.
5. Markers, capacities and performance are different levels. Time to exhaustion is noisier than a time trial and exaggerates gains several-fold; a worked example with W′ shows why.
6. Small studies miss real effects and overestimate the ones they find. Shown with a simulation run for the book, and supported by Button 2013.
7. Effect size and confidence interval matter more than the p-value. The effects worth having for trained riders (about 1%) are smaller than the noise in the tests.
8. Analyses chosen after seeing the data inflate false positives (Simmons 2011); 82% of sports medicine studies report their hypothesis supported (Büttner 2020); sports science's own method, magnitude-based inference, was shown to do this (Sainani 2018). Preregistration is the remedy.
9. Individual "responders" can be pure noise (Atkinson & Batterham 2015).
10. Replication settles more than any single study.

## How it differs from the other chapters

- No separate *Reading the research* box: the chapter is one. The other chapters' boxes each practise one of its skills, and it points to several of them.
- *One study, up close* is the opening study revisited with the ten questions.
- It ends on a numbered list of ten questions. That is a real list, so the checker's flag on it stands.
- No *From the saddle* passage. George reads finance research for a living (his bio in the Introduction says so): a paragraph on what that taught him about small samples and data-mined results would fit well here, in his words.

## Checker flags left, and why

- Line 51 and 55: the time-to-exhaustion arithmetic. Illustrative numbers using Chapter 1's formula, labelled as an illustration.
- Line 61: the tally of sample sizes in Chapters 2 and 3. My own count; list in research.md.
- Line 73: simulation results. From `tools/simulate_small_trials.py`.
- Line 51 rhythm: left.
- Line 143: the list of ten questions.

## Figures

- `small-trials.svg`: histograms of 20,000 simulated trials at 10 and 50 per group. Drawn.
- Possible: time to exhaustion against power, showing a small shift in critical power becoming a large change in time. Not drawn.

## Questions for George

1. Would you write a few lines on what reading finance research taught you about small samples and results that don't repeat? It would be the chapter's *From the saddle* (or a differently named box), and it is a real qualification for writing this chapter.
2. The chapter is short of its target by about 1,250 words. Candidates to add: meta-analyses and how to read them (the book cites several); crossover against parallel designs; regression to the mean; funding and conflicts of interest. Which, if any?
3. The simulation is original work, not a citation. Are you comfortable with the book containing it, described as "I ran a simulation"? You can run it yourself: `python3 book/tools/simulate_small_trials.py`. **Answered 11 October: yes, George is comfortable with it.**
4. The chapter says of magnitude-based inference that sports science "had to abandon" it. That is strong. I believe at least one major journal stopped accepting it, but I have only Sainani's abstract; soften, or check first?
