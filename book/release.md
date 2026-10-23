# Release checklist

Started 20 October 2026, when George asked to start preparing the book for release. KDP's rules quoted here are from its help pages as fetched that day (Paperback Submission Guidelines, Save Your Manuscript File, Format Front Matter, Paperback Fonts); check them again at upload.

Build the paperback interior from `book/`:

    python3 tools/render.py review/proof-6x9.pdf chapters/{intro,limits,...,verdict}/draft.md

It prints the page count, the spine width and a `NOT FOR PRINT` line for anything that must not reach the printed book: notes for George, missing sources or figures, placeholders. The file is ready to upload only when there are none.

## Decisions for George

1. **Subtitle.** The title page uses the current favourite, *The science of easy riding, hard intervals and getting fitter* (`front/title.md`). KDP checks that the title page, cover and listing match exactly.
2. **ISBN.** It goes on the copyright page, which shows a placeholder for now. KDP gives a free ISBN that can only be used for KDP's own edition. Your own ISBN, from Nielsen in the UK, names you as the publisher and can be used anywhere. The Kindle edition doesn't need one. The paperback and the ebook can't share one.
3. **Paper.** White or cream. At 261 pages the spine is 0.588 in on white and 0.652 in on cream. The cover has to be drawn for the paper chosen.
4. **Copyright page wording** (`front/copyright.md`). Please read it. The health and drugs disclaimer is the usual wording for a training book, not legal advice. If the book comes out in 2027, the year changes.
5. **Acknowledgements.** Optional, and must be in your words. The dedication is done (`front/dedication.md`, 20 October).
6. **Index.** Optional, and the Kindle edition doesn't need one. The glossary (21 October) covers some of the same need. In a research book it helps readers find a study or a name again. It can be built from a term list we agree (about 150 to 250 terms), with page numbers found automatically after the final layout. That adds roughly 8 to 12 pages and has to be redone if the pages move.
7. **Chapter openings.** Chapters now open on the next page, on either side. One setting (`CHAPTERS_OPEN` in `tools/render.py`) puts them all back on the right, which adds about ten blank pages. The eight blank pages left are the backs of the five part title pages, plus three that put a part page on the right. Printing each part's name above its first chapter's heading, with no separate part pages, would remove nearly all of them.
8. **KDP listing.** Description, seven keywords, categories, price, release date or pre-order, and whether to enrol the ebook in KDP Select (exclusive to Amazon). There is also the AI-content question on the submission form: answer it as KDP words it at upload (plan.md, 9 October).

## Still to do before upload

- **Chapter 16, Drugs: no legal read** (George's decision, 22 October). Before upload, check the chapter against the libel rule in its `brief.md` once more: the only living person linked to doping is Armstrong, and no current rider, team or company is named or implied. Any edit to that chapter after 22 October needs the same check.
- **Open editorial items:**
  - the "Worth deciding" points in `george/final-review.md`;
  - the waiting points in `george/structure-review.md`;
  - in plan.md:
    - Part IV and V names to confirm;
    - the Chapter 12 winter paragraph;
    - the four trial tables still to recheck.
- **Cover:** front, spine and back as one PDF.
  - Size: 6.125 + spine + 6.125 in wide by 9.25 in tall, with 0.125 in bleed all round.
  - The spine depends on the final page count.
  - KDP prints the barcode on the back.
  - The cover picture must be one we have the rights to.
- **Kindle edition:** an EPUB built from the same drafts. Not started. It needs:
  - figures as images;
  - trial tables that read on a phone;
  - a linked contents page;
  - references at the end of each chapter.
- **Printed proof:** order a proof copy from KDP before release and read it on paper.
- **Final checks after the last edit:**
  - Rebuild and confirm `NOT FOR PRINT` is empty, and look at each `SPLIT` line the build prints (long lists may break between their middle items; nothing else should break).
  - Words hyphenated across a page turn: the build lists them (8 on 21 October). Fix them by hand only after the last text edit, since any edit moves them.
  - Every contents page number matches its chapter.
  - No table splits across a page.
  - Recheck the Introduction's line that *mitochondria* appears more often than *bike*. On 20 October it was 51 against 35, or 36 counting *bikes*.

## Done, 20 October 2026

- **Front matter, in KDP's order:**
  - half title and its blank back;
  - title page;
  - copyright page;
  - dedication, in George's words, and its blank back;
  - contents on one page, with page numbers;
  - the Introduction on page 1, a right-hand page.
- **Page numbers:** roman in the front matter (not printed), arabic from the Introduction, odd numbers on the right.
- **Running heads:** the book's title on left pages and the chapter's on right pages. There is none on a chapter's first page, a blank page or a part title page.
- **Chapters open on either side.** That leaves 8 blank pages after the front matter, against 17 before.
- **KDP's print limits are met:**
  - type at least 7 pt;
  - lines at least 0.75 pt;
  - grey fills at least 10%;
  - every font embedded, with no Type 3 fonts and no system fonts;
  - no links, bookmarks or annotations in the file.
- **Curly quotes and apostrophes** throughout the text and figures. The drafts were typed with straight ones.

## Done, 21 October 2026

- **Glossary** (`back/glossary.md`, 76 terms), after the Verdict and on the review page, listed in the contents. Each definition follows the chapter it points to.
- **Page breaks:** no list item splits over a page, no list leaves one item alone at the foot or head of a page, the sentence introducing a list or formula stays with it, and From the saddle boxes stay whole. Grade badges and chapter numbers no longer wrap onto a line of their own. The build reports any breaks left (`SPLIT`).

## Done, 22 October 2026

- **Chapter 16 checked instead of a legal read.** One sentence about current teams cut. The facts about named people and organisations were checked against the original documents: USADA's decision on Armstrong, the Tour organiser's records for 1998 to 2005, and the cycling governing body's statements on carbon monoxide, ketones and tramadol. Three wordings were tightened to match them. Details in `chapters/doping/research.md`, last section. Not confirmed at a primary source: the date of the Festina border stop and the list of drugs found, which every account agrees on.
