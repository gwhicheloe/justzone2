#!/usr/bin/env python3
"""Render chapter drafts to one HTML review page.

  python3 book/tools/render.py OUT.html book/chapters/intro/draft.md book/chapters/limits/draft.md ...
  python3 book/tools/render.py [--trim 6x9] OUT.pdf chapters...   -> the paperback's interior: front matter
                          (front/title.md, front/copyright.md), contents, part pages and chapters at the trim size
                          (default 6 x 9 in), made with Chrome, with running heads and page numbers stamped on;
                          OUT.html is kept beside it. It lists anything that must not reach print (NOT FOR PRINT),
                          and page breaks a reader would notice (SPLIT), such as a list running onto the next page.
back/glossary.md, if it exists, follows the last chapter in both outputs.

Handles the subset of Markdown the drafts use: headings, paragraphs, bold and
italic, numbered and bulleted lists, blockquotes. Book conventions:
  [@key] or [@a; @b]   -> numbered citations, numbered afresh in each chapter,
                          with a reference list built from sources.yaml
  {shadow @key; @b}    -> a source kept with its sentence for checking but not printed: shown faintly
                          on the review page with its own list, dropped from the print proof
                          (style.md says which sources are printed)
  ~~text~~             -> a proposed cut, waiting for George: struck through on the review page,
                          dropped from the print proof and from the word counts
  {grade A|B|C}        -> a small evidence-grade badge
  [GEORGE: ...]        -> a highlighted note for George
  ![caption](figures/x.svg) on its own paragraph -> the SVG inline, numbered, with the caption
  ::: formula ... :::  -> each line inside set as a centred display line (an equation)
  ::: survives ... ::: -> the 'What survives' box that closes a chapter: one short claim per line
  ::: trial ... :::    -> a trial laid out as a table (no blank lines inside):
                            Label: text            a row across the full width (Hypothesis, Design, Authors' conclusion)
                            | | Arm A | Arm B      the groups, one column each (two or more)
                            | Label | a | b        a row of values; fewer values than groups -> the last spans the rest
                            ~ text                 a note under the row above (e.g. not significant)
                            -- Heading             a sub-heading across the table
Parts: PARTS below names the chapter (by folder) that opens each part; a part title page
goes before it, on a right-hand page with its blank back, in print, and a part heading on the review page.
Chapters open on the next page, left or right (CHAPTERS_OPEN). Straight quotes become curly (typography.py).
The output is an HTML fragment (title, style, content) that works both as an
Artifact page and when opened directly in a browser.
"""
import datetime
import html
import os
import re
import subprocess
import sys

from typography import smart_quotes

HERE = os.path.dirname(os.path.abspath(__file__))
BOOK = os.path.dirname(HERE)

# The first chapter of each part (by folder name), and the part's number and title.
PARTS = {
    "limits": ("Part I", "The engine"),
    "easy-riding": ("Part II", "The easy part"),
    "designing-intervals": ("Part III", "The hard part"),
    "fuelling": ("Part IV", "Other ways to get faster"),
    "training-week": ("Part V", "Putting it together"),
}


def part_of(path):
    return PARTS.get(os.path.basename(os.path.dirname(os.path.abspath(path))))


# Back matter: printed after the last chapter and added to the review page, whatever chapters are named.
GLOSSARY = os.path.join(BOOK, "back", "glossary.md")


def is_back(path):
    return os.path.basename(os.path.dirname(os.path.abspath(path))) == "back"


def counted(files):
    """'21 chapters', or '21 chapters and a glossary'."""
    n = sum(1 for f in files if not is_back(f))
    return f"{n} chapters" + (" and a glossary" if any(is_back(f) for f in files) else "")


def load_sources():
    out, cur = {}, None
    for line in open(os.path.join(BOOK, "sources.yaml"), encoding="utf-8"):
        m = re.match(r"\s*-\s*key:\s*(\S+)", line)
        if m:
            cur = m.group(1)
            out[cur] = {}
            continue
        m = re.match(r"\s+(citation|status|doi):\s*\"?(.*?)\"?\s*$", line)
        if m and cur:
            out[cur][m.group(1)] = m.group(2)
    return out


def inline(text, cite):
    t = smart_quotes(html.escape(text, quote=False))  # before any tags, which have quotes of their own
    t = t.replace("₂", "<sub>2</sub>")  # Newsreader has no subscript two; a fallback font's would show
    t = re.sub(r"~~(.+?)~~", r'<del class="cut" title="Proposed cut">\1</del>', t)
    t = re.sub(r"\[GEORGE:(.*?)\]", lambda m: f'<mark class="george">George: {m.group(1).strip()}</mark>', t, flags=re.S)
    t = re.sub(r"[ \t]+(?=\{grade )", "\u00a0", t)  # a badge stays with the word before it, never alone on a line
    t = re.sub(r"\b(Chapters?|Part) (?=\d|[IV]+\b)", "\\1\u00a0", t)  # "Chapter 5" never split over two lines
    t = re.sub(r"\{grade ([ABC])\}", lambda m: f'<span class="grade g{m.group(1)}" title="Evidence grade {m.group(1)}">{m.group(1)}</span>', t)
    # qualified grades, e.g. {grade A for the shape; grade B for the details}: a badge for each grade, the words kept
    badge = lambda m: f'<span class="grade g{m.group(1)}" title="Evidence grade {m.group(1)}">{m.group(1)}</span>'
    t = re.sub(r"\{(grade [ABC][^{}]*)\}", lambda m: '<span class="gradenote">' + re.sub(r"grade ([ABC])", badge, m.group(1)) + "</span>", t)
    t = re.sub(r"\[(@[^\]]+)\]", lambda m: cite(m.group(1)), t)
    t = re.sub(r"\{shadow (@[^{}]+)\}", lambda m: cite(m.group(1), shadow=True), t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", t)
    return t


def render_trial(lines, cite, two_part=False):
    """A trial as a table: full-width rows, one column per group, sub-headings.

    Every row also gets a label row of its own, shown only on narrow screens,
    where the label column is hidden; with three or more groups the values
    stack under the label, each named after its group.

    For print (two_part), the rows above the groups' names are a table of their own and the
    names are the second table's header. The print proof never splits a table over two pages,
    but if a table is ever taller than a page Chrome repeats the header on the next.
    """
    body = [l.strip() for l in lines[1:] if l.strip() != ":::"]
    arms = []
    for l in body:
        cells = [c.strip() for c in l.strip().strip("|").split("|")]
        if l.startswith("|") and cells[0] == "":
            arms = cells[1:]
            break
    n = max(len(arms), 1)
    rows, arms_at = [], None

    def label_rows(label, cls):
        lab = inline(label, cite)
        rows.append(f'<tr class="mlab {cls}"><th colspan="{n + 1}">{lab}</th></tr>')
        return f'<th class="rl" scope="row">{lab}</th>'

    for l in body:
        if l.startswith("|"):
            cells = [c.strip() for c in l.strip().strip("|").split("|")]
            if cells[0] == "":
                heads = "".join(f'<th class="arm" scope="col">{inline(a, cite)}</th>' for a in arms)
                arms_at = len(rows)
                rows.append(f'<tr class="arms"><td class="rl"></td>{heads}</tr>')
                continue
            th = label_rows(cells[0], "data")
            vals = cells[1:] or [""]
            tds = []
            for i, v in enumerate(vals):
                span = n - i if i == len(vals) - 1 else 1
                attrs = f' colspan="{span}"' if span > 1 else ""
                if span == 1 and i < len(arms):
                    # the group's name without any bracketed note, for the stacked layout on narrow screens
                    name = re.sub(r"\s*\*?\(.*?\)\*?", "", arms[i]).strip()
                    attrs += f' data-arm="{html.escape(name, quote=True)}"'
                tds.append(f"<td{attrs}>{inline(v, cite)}</td>")
            rows.append(f'<tr class="data">{th}{"".join(tds)}</tr>')
        elif l.startswith("~"):
            rows.append(f'<tr class="note"><td class="rl"></td><td colspan="{n}">{inline(l[1:].strip(), cite)}</td></tr>')
        elif l.startswith("--"):
            rows.append(f'<tr class="sub"><th colspan="{n + 1}">{inline(l[2:].strip(), cite)}</th></tr>')
        elif ":" in l:
            label, text = l.split(":", 1)
            key = re.sub(r"[^a-z]", "", label.lower())
            cls = "hyp" if key in ("hypothesis", "aim", "question") else "concl" if "conclusion" in key else "span"
            th = label_rows(label.strip(), cls)
            rows.append(f'<tr class="{cls}">{th}<td colspan="{n}">{inline(text.strip(), cite)}</td></tr>')
    wide = " wide" if n > 2 else ""
    cols = '<colgroup><col class="crl">' + "<col>" * n + "</colgroup>"
    if two_part and arms_at:
        lead, head, body = "".join(rows[:arms_at]), rows[arms_at], "".join(rows[arms_at + 1:])
        return (f'<div class="trial{wide}"><table class="lead">{cols}{lead}</table>'
                f'<table class="main">{cols}<thead>{head}</thead><tbody>{body}</tbody></table></div>')
    return f'<div class="trial{wide}"><table>{cols}{"".join(rows)}</table></div>'


def add_probes(block, idx, j, kind):
    """Mark a block for measuring: an id on the block itself (its top) and, except on tables and
    figures, an empty anchor at the end of its last line. Neither changes the layout. Chrome
    records the page and height of each in the PDF, once something links to it (probe_links)."""
    i = block.index(">")
    block = block[:i] + f' id="s{idx}-{j}"' + block[i:]
    if kind in ("trial", "figure"):
        return block
    e = block.rindex("</li>" if kind == "list" else "</")  # inside the last item, or it would add a line
    return block[:e] + f'<a id="e{idx}-{j}">&#8203;</a>' + block[e:]


def probe_links(layouts):
    """Links to every probe, set in 1px type after the last chapter, so Chrome records them."""
    keys = ["top"] + [f"{k}{i}-{j}" for i, seq in enumerate(layouts, 1) for j, kind in seq if kind not in ("h1", "refs")
                      for k in ("s" if kind in ("trial", "figure") else "se")]
    # spaced so the line can wrap: one unbroken run wider than the page makes Chrome shrink every page to fit it
    return '<div class="probes">' + " ".join(f'<a href="#{k}">.</a>' for k in keys) + "</div>"


def render_chapter(md, sources, idx, base=".", probes=False, moves=None, layout=None, print_mode=False):
    """Returns (title, anchor, words, html). For the print proof: probes marks every block,
    moves {block: n} puts a table or figure n blocks later, and layout, if a list, receives
    (block, kind) in the order printed."""
    order, shadows = [], []
    md = re.sub(r"<!--.*?-->", "", md, flags=re.S)  # notes to ourselves, never printed
    if print_mode:
        md = re.sub(r"[ \t]*\{shadow [^{}]*\}", "", md)  # sources kept for checking, never printed
        md = re.sub(r"[ \t]*~~.*?~~", "", md)  # proposed cuts: the proof shows the book as it would be

    def cite(group, shadow=False):
        keys = re.findall(r"@([A-Za-z0-9_:-]+)", group)
        seen, nums = (shadows if shadow else order), []
        for k in keys:
            if k not in seen:
                seen.append(k)
            nums.append(seen.index(k) + 1)
        if shadow:
            links = ",".join(f'<a href="#c{idx}-s{n}">s{n}</a>' for n in nums)
            return f'<sup class="cite shadow" title="Kept for checking, not printed">[{links}]</sup>'
        links = ",".join(f'<a href="#c{idx}-r{n}">{n}</a>' for n in nums)
        return f'<sup class="cite">[{links}]</sup>'

    blocks, buf = [], []
    for line in md.split("\n") + [""]:
        if line.strip() == "":
            if buf:
                blocks.append(buf)
            buf = []
        else:
            buf.append(line)

    out, kinds, title, anchor, fig_n = [], [], "", f"ch{idx}", [0]
    for b in blocks:
        first = b[0]
        kinds.append("survives" if first.startswith("::: survives") else "trial" if first.startswith("::: trial") else "formula" if first.startswith("::: formula") else "h3" if first.startswith("### ") else
                     "h2" if first.startswith("## ") else "h1" if first.startswith("# ") else
                     "figure" if re.match(r"!\[(.*)\]\((\S+\.svg)\)\s*$", " ".join(b)) else
                     "quote" if first.startswith(">") else "list" if re.match(r"(\d+\.|[-*])\s", first) else "p")
        if first.startswith("# "):
            title = first[2:].strip()
            out.append(f'<h1 id="{anchor}">{inline(title, cite)}</h1>')
        elif first.startswith("::: survives"):
            items = "".join(f"<li>{inline(l.strip(), cite)}</li>" for l in b[1:] if l.strip() != ":::")
            out.append(f'<aside class="survives"><div class="sv-h">What survives</div><ul>{items}</ul></aside>')
        elif first.startswith("::: trial"):
            out.append(render_trial(b, cite, two_part=print_mode))
        elif first.startswith("::: formula"):
            rows = "".join(f"<div>{inline(l.strip(), cite)}</div>" for l in b[1:] if l.strip() != ":::")
            out.append(f'<div class="formula">{rows}</div>')
        elif first.startswith("### "):
            out.append(f"<h3>{inline(first[4:], cite)}</h3>")
        elif first.startswith("## "):
            out.append(f"<h2>{inline(first[3:], cite)}</h2>")
        elif re.match(r"!\[(.*)\]\((\S+\.svg)\)\s*$", " ".join(b)):
            m = re.match(r"!\[(.*)\]\((\S+\.svg)\)\s*$", " ".join(b))
            fig_n[0] += 1
            try:
                art = open(os.path.join(base, m.group(2)), encoding="utf-8").read()
            except OSError:
                art = f'<p class="missing">Missing figure: {html.escape(m.group(2))}</p>'
            out.append(f'<figure>{art}<figcaption><b>Figure {fig_n[0]}.</b> {inline(m.group(1), cite)}</figcaption></figure>')
        elif first.startswith(">"):
            text = " ".join(l.lstrip("> ").strip() for l in b)
            out.append(f'<blockquote class="saddle">{inline(text, cite)}</blockquote>')
        elif re.match(r"\d+\.\s", first):
            items = [re.sub(r"^\d+\.\s+", "", l) for l in b]
            out.append("<ol>" + "".join(f"<li>{inline(i, cite)}</li>" for i in items) + "</ol>")
        elif re.match(r"[-*]\s", first):
            items = [re.sub(r"^[-*]\s+", "", l) for l in b]
            out.append("<ul>" + "".join(f"<li>{inline(i, cite)}</li>" for i in items) + "</ul>")
        else:
            out.append(f"<p>{inline(' '.join(l.strip() for l in b), cite)}</p>")

    words = len(re.findall(r"\b\w+\b", re.sub(r"\[@[^\]]+\]|\{shadow [^{}]*\}|\{grade [ABC]\}|~~.*?~~", "", md)))

    def ref_list(keys, prefix):
        refs = []
        for n, k in enumerate(keys, 1):
            s = sources.get(k, {})
            status = s.get("status", "missing")
            doi = s.get("doi")
            link = f' <a href="https://doi.org/{html.escape(doi)}">doi</a>' if doi else ""
            refs.append(f'<li id="c{idx}-{prefix}{n}">{smart_quotes(html.escape(s.get("citation", "MISSING FROM sources.yaml: " + k), quote=False))}{link}'
                        f' <span class="status s-{status}">{status}</span></li>')
        return "".join(refs)

    if order or shadows:
        sec = '<section class="refs"><h2>References</h2><ol>' + ref_list(order, "r") + "</ol>" if order else '<section class="refs">'
        if shadows:  # never in print: print_mode stripped them above
            sec += (f'<h2 class="shadow-h">Kept for checking, not printed ({len(shadows)})</h2>'
                    f'<ol class="shadow">{ref_list(shadows, "s")}</ol>')
        out.append(sec + "</section>")
        kinds.append("refs")
    seq = list(zip(range(len(out)), kinds, out))
    for j in sorted(moves or {}, reverse=True):
        pos = next(p for p, b in enumerate(seq) if b[0] == j)
        seq.insert(pos + moves[j], seq.pop(pos))
    if probes:
        seq = [(j, k, h if k in ("h1", "refs") else add_probes(h, idx, j, k)) for j, k, h in seq]
    if layout is not None:
        layout.extend((j, k) for j, k, _ in seq)
    return title, anchor, words, "\n".join(h for _, _, h in seq)


STYLE = """
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,600;1,6..72,400&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
  :root{--bg:#F6F5F1;--page:#FFFFFF;--ink:#1C1F1D;--muted:#5D6460;--faint:#8B918D;--rule:#E1E3DF;--cut:#A8402C;
    --accent:#1E7F45;--mark:#FFF1B8;--mark-ink:#5A4300;--gA:#1E7F45;--gB:#B07A12;--gC:#9A4E2E;
    --serif:"Newsreader",Georgia,"Times New Roman",serif;--sans:"IBM Plex Sans",-apple-system,"Segoe UI",sans-serif;--mono:"IBM Plex Mono",ui-monospace,Menlo,monospace}
  @media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#111412;--page:#181C19;--ink:#E5E8E5;--muted:#A0A8A3;--faint:#737B76;--rule:#2B312D;--cut:#E58A78;
    --accent:#58C485;--mark:#4A3C0E;--mark-ink:#FFE7A0;--gA:#58C485;--gB:#E0B04A;--gC:#E08A66;color-scheme:dark}}
  :root[data-theme="dark"]{--bg:#111412;--page:#181C19;--ink:#E5E8E5;--muted:#A0A8A3;--faint:#737B76;--rule:#2B312D;--cut:#E58A78;
    --accent:#58C485;--mark:#4A3C0E;--mark-ink:#FFE7A0;--gA:#58C485;--gB:#E0B04A;--gC:#E08A66;color-scheme:dark}
  body{background:var(--bg);color:var(--ink);font-family:var(--serif);font-size:19px;line-height:1.62}
  .wrap{max-width:720px;margin:0 auto;padding-inline:20px;padding-block:28px 90px}
  .banner{font-family:var(--sans);font-size:14px;line-height:1.55;background:var(--page);border:1px solid var(--rule);border-radius:10px;padding:14px 16px;color:var(--muted)}
  .banner b{color:var(--ink)}
  .banner .key{display:flex;flex-wrap:wrap;gap:6px 14px;margin-top:8px;align-items:center}
  nav.toc{font-family:var(--sans);font-size:15px;margin:22px 0 8px}
  nav.toc a{color:var(--accent);text-decoration:none;display:block;padding:3px 0}
  nav.toc span{color:var(--faint);font-family:var(--mono);font-size:12px;margin-left:8px}
  nav.toc .tocpart{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin:14px 0 2px}
  .partpage{font-size:clamp(30px,6vw,40px);font-weight:600;line-height:1.15;text-align:center;margin:56px 0 0;padding:36px 0;border-top:1px solid var(--rule);border-bottom:1px solid var(--rule)}
  .partpage span{display:block;font-family:var(--sans);font-size:13px;font-weight:600;letter-spacing:.14em;text-transform:uppercase;color:var(--accent);margin-bottom:8px}
  article{background:var(--page);border:1px solid var(--rule);border-radius:12px;padding:34px clamp(18px,5vw,48px) 30px;margin-top:28px}
  h1{font-size:clamp(30px,6vw,40px);line-height:1.15;font-weight:600;margin:0 0 6px;text-wrap:balance}
  .meta{font-family:var(--mono);font-size:12px;color:var(--faint);margin-bottom:22px;letter-spacing:.03em}
  h2{font-size:25px;font-weight:600;line-height:1.25;margin:34px 0 8px;text-wrap:balance}
  h3{font-family:var(--sans);font-size:16px;font-weight:600;letter-spacing:.01em;margin:30px 0 6px;color:var(--ink)}
  p{margin:0 0 14px}
  ol,ul{margin:0 0 16px;padding-left:24px} li{margin:4px 0}
  strong{font-weight:600}
  sup.cite{font-family:var(--sans);font-size:11px;line-height:0;margin-left:1px}
  sub{font-size:.7em;line-height:0;vertical-align:-.25em}
  sup.cite a{color:var(--accent);text-decoration:none}
  sup.cite.shadow,sup.cite.shadow a{color:var(--faint)}
  del.cut,del.cut a{color:var(--cut);text-decoration:line-through;text-decoration-thickness:1px}
  section.refs h2.shadow-h{margin-top:22px}
  section.refs ol.shadow{list-style:none;padding-left:0;counter-reset:sh;color:var(--faint)}
  section.refs ol.shadow li{counter-increment:sh;padding-left:2.2em;text-indent:-2.2em}
  section.refs ol.shadow li::before{content:"s" counter(sh) ". ";font-family:var(--mono);font-size:12px}
  .gradenote{font-size:.88em;color:var(--muted,#666)}
  .grade{font-family:var(--mono);font-size:11px;font-weight:500;border-radius:4px;padding:1px 5px;margin-left:3px;border:1px solid currentColor;vertical-align:2px}
  .gA{color:var(--gA)} .gB{color:var(--gB)} .gC{color:var(--gC)}
  mark.george{background:var(--mark);color:var(--mark-ink);font-family:var(--sans);font-size:15px;padding:2px 6px;border-radius:4px;-webkit-box-decoration-break:clone;box-decoration-break:clone}
  figure{margin:26px 0;padding:0} figure svg{display:block;width:100%;height:auto;border:1px solid var(--rule);border-radius:8px;background:#fff}
  figcaption{font-family:var(--sans);font-size:14px;line-height:1.5;color:var(--muted);margin-top:8px}
  figcaption b{color:var(--ink)}
  article.gloss .meta+p{font-style:italic}
  article.gloss p:has(>strong:first-child){padding-left:1.2em;text-indent:-1.2em;margin:0 0 10px}
  blockquote.saddle{margin:18px 0;padding:4px 0 4px 18px;border-left:3px solid var(--accent);font-style:italic}
  .formula{margin:18px 0 20px;text-align:center;line-height:1.7}
  aside.survives{margin:30px 0 8px;padding:14px 18px 12px;border-top:3px solid var(--accent);border-bottom:1px solid var(--rule);background:var(--bg)}
  aside.survives .sv-h{font-family:var(--sans);font-size:12px;font-weight:600;letter-spacing:.12em;text-transform:uppercase;color:var(--accent);margin-bottom:6px}
  aside.survives ul{list-style:none;margin:0;padding:0}
  aside.survives li{margin:6px 0;font-size:17px;line-height:1.45;font-weight:500}
  section.refs{margin-top:34px;padding-top:6px;border-top:1px solid var(--rule)}
  section.refs h2{font-family:var(--sans);font-size:15px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
  section.refs ol{font-family:var(--sans);font-size:14px;line-height:1.5;color:var(--muted)}
  section.refs a{color:var(--accent)}
  .status{font-family:var(--mono);font-size:11px;border-radius:999px;padding:0 7px;margin-left:4px;border:1px solid var(--rule);white-space:nowrap}
  .s-fulltext{color:var(--gA)} .s-abstract{color:var(--gB)} .s-exists{color:var(--gC)} .s-candidate,.s-missing{color:#C0392B}
  .trial{margin:24px 0 26px;border:1px solid var(--rule);border-radius:10px;background:var(--bg);overflow:hidden;font-family:var(--sans);font-size:13.5px;line-height:1.45}
  .trial table{width:100%;border-collapse:collapse;table-layout:fixed;font:inherit}  /* opened without a doctype, tables would not inherit the size */
  .trial col.crl{width:22%} .trial.wide col.crl{width:18%}
  .trial th,.trial td{padding:7px 10px;vertical-align:top;text-align:left;overflow-wrap:break-word}
  .trial tr+tr>*{border-top:1px solid var(--rule)}
  .trial .rl{font-size:12px;font-weight:600;color:var(--muted);line-height:1.4;padding-top:8px}
  .trial tr.data td+td,.trial tr.note td+td{border-left:1px solid var(--rule)}
  .trial tr.note td+td{border-left:0}
  .trial tr.data td{font-variant-numeric:tabular-nums}
  .trial tr.arms th{font-size:14px;font-weight:600;color:var(--ink);padding-top:10px;padding-bottom:6px;border-bottom:2px solid var(--ink)}
  .trial tr.arms th em{display:block;font-size:12px;font-weight:400;color:var(--muted)}
  .trial tr.sub th{font-size:10.5px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:var(--ink);background:var(--page);padding:6px 10px}
  .trial tr.note>*{border-top:0;padding-top:0;font-size:12px;font-style:italic;color:var(--muted)}
  .trial tr.hyp td,.trial tr.concl td{font-family:var(--serif);font-size:15.5px;line-height:1.4}
  .trial tr.hyp td{font-style:italic}
  .trial tr.concl>*{border-top:2px solid var(--ink)}
  .trial tr.mlab{display:none}
  @media (max-width:520px){
    .trial{font-size:13px}
    .trial table{table-layout:auto} .trial col.crl{width:auto}
    .trial th.rl,.trial td.rl{display:none}
    .trial tr.mlab{display:table-row}
    .trial tr.mlab th{font-size:12px;font-weight:600;color:var(--muted);padding:8px 10px 0}
    .trial tr.mlab+tr>*{border-top:0;padding-top:2px}
    .trial tr.mlab.concl th{border-top:2px solid var(--ink)}
    .trial tr.concl>*{border-top:0}
    .trial.wide table,.trial.wide tbody,.trial.wide tr,.trial.wide td,.trial.wide th{display:block;width:auto}
    .trial.wide colgroup,.trial.wide tr.arms,.trial.wide th.rl,.trial.wide td.rl{display:none}
    .trial:not(.wide) tr.data td[data-arm]{width:50%}
    .trial.wide tr.mlab{display:block}
    .trial.wide tr.data td{border-left:0;padding:2px 10px}
    .trial.wide tr.data td:last-child{padding-bottom:8px}
    .trial.wide tr.note td{padding:0 10px 8px}
    .trial.wide tr.data td[data-arm]::before{content:attr(data-arm) ": ";font-weight:600}
  }
  @media (max-width:520px){body{font-size:17.5px} article{padding:24px 16px}}
</style>
"""


# The print proof: the same chapters set as book pages, as the paperback's interior file.
# KDP's rules (Paperback Submission Guidelines, checked 20 October 2026): inside margins at least
# 0.5 in for 151 to 300 pages and 0.625 in for 301 to 500, other margins at least 0.25 in without
# bleed; type at least 7 pt; lines at least 0.75 pt; grey fills at least 10%; no links, bookmarks or
# annotations. Black ink only. Running heads and page numbers are added afterwards (stamp).
PRINT_STYLE = """
<style>
  %(fonts)s
  @page{size:%(w)sin %(h)sin;margin:%(margins)s}
  @page :left{margin-left:%(out)sin;margin-right:%(in)sin}
  @page :right{margin-left:%(in)sin;margin-right:%(out)sin}
  section.part{break-before:page;height:7.5in;display:flex;flex-direction:column;justify-content:center;text-align:center}
  section.part p{font-family:var(--sans);font-size:8.5pt;font-weight:600;letter-spacing:.16em;text-transform:uppercase;margin:0 0 10pt;text-indent:0}
  section.part .pt{font-size:24pt;line-height:1.15;font-weight:600;margin:0;text-align:center}
  .blank{break-before:page;break-after:page;height:1px}
  /* Nothing may be wider than the text area: Chrome would shrink every page to fit it. */
  *{-webkit-print-color-adjust:exact;print-color-adjust:exact;box-sizing:border-box}
  :root{--serif:"Newsreader","Noto Serif",serif;--sans:"IBM Plex Sans",sans-serif;--mono:"IBM Plex Mono",monospace}
  html,body{margin:0;padding:0;background:#fff;color:#000}
  body{font-family:var(--serif);font-size:10.5pt;line-height:14pt;text-align:justify;hyphens:auto;-webkit-hyphens:auto;font-variant-numeric:lining-nums}
  /* Front matter, in KDP's order: half title, its blank back, title page, copyright page, contents. */
  section.fm{break-before:page;break-after:page}
  section.fm p{text-indent:0;hyphens:manual;-webkit-hyphens:manual}
  section.half,section.tpage,section.copy,section.ded{height:7.5in;display:flex;flex-direction:column}
  section.half .ht{margin:1.5in 0 0;font-size:16pt;font-weight:600;text-align:center}
  section.tpage h1.bt{font-size:30pt;line-height:1.1;margin:1.3in 0 12pt;text-align:center}
  section.tpage .sub{font-size:13pt;line-height:1.35;font-style:italic;text-align:center;margin:0 auto;max-width:3.6in}
  section.tpage .au{margin:auto 0 0.5in;font-family:var(--sans);font-size:9pt;font-weight:600;letter-spacing:.16em;text-transform:uppercase;text-align:center}
  section.copy{justify-content:flex-end}
  section.copy p{font-family:var(--sans);font-size:7.5pt;line-height:1.45;text-align:left;margin:0 0 6pt}
  section.ded p{margin:0 0 11pt;font-style:italic;text-align:center;line-height:15pt}
  section.ded p:first-child{margin-top:1.5in}
  section.toc h1{margin:0.32in 0 0.2in}  /* one page, so it needs no running head or number */
  section.toc a{display:flex;align-items:baseline;color:#000}
  section.toc a.tp{font-family:var(--sans);font-size:7.5pt;font-weight:600;letter-spacing:.14em;text-transform:uppercase;margin:6pt 0 2pt}
  section.toc a.tp .sep{margin:0 .5em}
  section.toc a.te{margin:0 0 2pt;text-align:left}
  section.toc a.bm{margin-top:6pt}  /* the glossary, after the last part */
  section.toc .tn{flex:none;width:2em;font-variant-numeric:tabular-nums}
  section.toc .tt{flex:none;max-width:3.6in}
  section.toc .tl{flex:1;min-width:12pt;margin:0 5pt;border-bottom:.75pt dotted #000;position:relative;top:-3pt}
  section.toc .tpg{flex:none;min-width:2em;text-align:right;font-variant-numeric:tabular-nums}
  article{break-before:page}
  h1{font-size:21pt;line-height:1.15;font-weight:600;margin:0.9in 0 0.3in;text-align:left;hyphens:manual;text-wrap:balance}
  h1 .chl{display:block;font-family:var(--sans);font-size:8.5pt;line-height:1.2;font-weight:600;letter-spacing:.16em;text-transform:uppercase;margin:0 0 9pt}
  h2{font-size:12.5pt;line-height:1.25;font-weight:600;margin:15pt 0 5pt;text-align:left;hyphens:manual;break-after:avoid}
  h3{font-family:var(--sans);font-size:8.5pt;font-weight:600;letter-spacing:.02em;margin:12pt 0 3pt;text-align:left;hyphens:manual;break-after:avoid}
  p{margin:0;orphans:2;widows:2} p+p{text-indent:1.2em}
  ol,ul{margin:5pt 0 6pt;padding-left:1.5em} li{margin:2pt 0}
  /* No list item split over two pages, never one item alone at the foot or the head of a page, and the
     sentence that introduces a list or formula kept with it (George, 21 October 2026: a list on page 17) */
  li{break-inside:avoid} li:first-child{break-after:avoid} li:last-child{break-before:avoid}
  p:has(+ol),p:has(+ul),p:has(+.formula){break-after:avoid}
  blockquote.saddle{break-inside:avoid}
  article.gloss h1+p{font-style:italic;margin:0 0 10pt}
  article.gloss p:has(>strong:first-child){text-indent:-1em;padding-left:1em;margin:0 0 4pt;text-align:left;hyphens:manual;-webkit-hyphens:manual;break-inside:avoid}
  strong{font-weight:600}
  a{color:inherit;text-decoration:none}
  sup.cite{font-family:var(--sans);font-size:7pt;line-height:0;margin-left:.5pt}
  sub{font-size:max(.7em,7pt);line-height:0;vertical-align:-.25em}  /* KDP: nothing under 7 pt, even in captions and tables */
  .probes{font-size:1px;line-height:1px;color:#fff;break-before:page}
  .gradenote{font-size:max(.9em,7pt)}
  .grade{font-family:var(--mono);font-size:7pt;border:.75pt solid #000;border-radius:2pt;padding:0 1.5pt;margin-left:2pt;vertical-align:1pt}
  mark.george{background:#e4e4e4;color:#000;font-family:var(--sans);font-size:8pt;padding:0 2pt;-webkit-box-decoration-break:clone;box-decoration-break:clone}
  figure{margin:10pt 0 12pt;break-inside:avoid} figure svg{display:block;width:100%%;height:auto}
  figcaption{font-family:var(--sans);font-size:7.5pt;line-height:1.35;text-align:left;hyphens:manual;margin-top:4pt}
  blockquote.saddle{margin:9pt 0;padding-left:9pt;border-left:1.2pt solid #000;font-style:italic}
  .formula{margin:8pt 0 9pt;text-align:center;line-height:1.6;break-inside:avoid}
  aside.survives{margin:14pt 0 4pt;padding:5pt 0 4pt;border-top:1.2pt solid #000;border-bottom:.75pt solid #000;break-inside:avoid}
  aside.survives .sv-h{font-family:var(--sans);font-size:7pt;font-weight:600;letter-spacing:.12em;text-transform:uppercase;margin-bottom:2pt}
  aside.survives ul{list-style:none;margin:0;padding:0}
  aside.survives li{margin:3pt 0;text-align:left;hyphens:manual;-webkit-hyphens:manual}
  section.refs{margin-top:16pt}
  section.refs h2{font-family:var(--sans);font-size:7.5pt;letter-spacing:.08em;text-transform:uppercase;margin:0 0 4pt}
  section.refs ol{font-family:var(--sans);font-size:7pt;line-height:1.35;text-align:left;hyphens:manual;padding-left:2em;margin:0}
  section.refs li{margin:0 0 1.5pt}
  .status,section.refs a{display:none}
  .missing{font-family:var(--sans);font-size:8pt;border:.75pt dashed #000;padding:6pt}
  .trial{margin:9pt 0 11pt;border:.75pt solid #000;font-family:var(--sans);font-size:7.5pt;line-height:1.35;text-align:left;hyphens:manual;-webkit-hyphens:manual;break-inside:avoid}
  .trial table{width:100%%;border-collapse:collapse;table-layout:fixed}
  .trial col.crl{width:21%%} .trial.wide col.crl{width:17%%}
  .trial th,.trial td{padding:3pt 4.5pt;vertical-align:top;text-align:left}
  .trial tr{break-inside:avoid}
  .trial tr+tr>*{border-top:.75pt solid #bdbdbd}
  .trial .rl{font-weight:600;color:#333}
  .trial tr.data td+td{border-left:.75pt solid #bdbdbd}
  .trial tr.data td{font-variant-numeric:tabular-nums}
  .trial tr.arms th{font-size:8pt;font-weight:600;border-bottom:.9pt solid #000}
  .trial tr.arms th em{display:block;font-size:7pt;font-weight:400;color:#444}
  .trial tr.sub th{font-size:7pt;font-weight:600;letter-spacing:.06em;text-transform:uppercase;background:#e6e6e6;padding:2pt 4.5pt}
  .trial tr.note>*{border-top:0;padding-top:0;font-size:7pt;font-style:italic;color:#444}
  .trial tr.hyp td,.trial tr.concl td{font-family:var(--serif);font-size:8.8pt;line-height:1.3}
  .trial tr.hyp td{font-style:italic}
  .trial tr.concl>*{border-top:.9pt solid #000}
  .trial tr.mlab{display:none}
  .trial table.lead{break-inside:avoid;break-after:avoid}
  .trial table.main thead tr>*{border-top:.75pt solid #bdbdbd}
</style>
"""


FONTS_CSS = ("https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,600;1,6..72,400;1,6..72,600"
             "&family=IBM+Plex+Sans:ital,wght@0,400;0,600;1,400&family=IBM+Plex+Mono:wght@500")


# Newsreader has no Greek, so the α of PGC-1α comes from Noto Serif (also SIL Open Font License),
# not from a system font such as Georgia, whose licence is Microsoft's.
FALLBACK_CSS = "https://fonts.googleapis.com/css2?family=Noto+Serif:ital,wght@0,400;0,600;1,400"


def local_fonts():
    """@font-face rules pointing at copies of the fonts in book/fonts/ (git-ignored), fetched once.

    Chrome prints before web fonts arrive, so the proof uses local files. Newsreader, IBM Plex and
    Noto Serif are under the SIL Open Font License, which allows embedding them in a printed book.
    """
    folder = os.path.join(BOOK, "fonts")
    out = []
    for name, url in (("fonts.css", FONTS_CSS), ("fallback.css", FALLBACK_CSS)):
        css_path = os.path.join(folder, name)
        if not os.path.exists(css_path):
            import urllib.request
            os.makedirs(folder, exist_ok=True)
            get = lambda u: urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "just-zone-2-book-research"})).read()
            css = get(url).decode()
            for u in re.findall(r"url\((https://[^)]+\.ttf)\)", css):
                fn = re.sub(r"[^A-Za-z0-9.]", "", u.split("/s/")[1].replace("/", "-"))
                open(os.path.join(folder, fn), "wb").write(get(u))
                css = css.replace(u, fn)
            open(css_path, "w", encoding="utf-8").write(css)
        css = open(css_path, encoding="utf-8").read()
        out.append(re.sub(r"url\(([^)]+\.ttf)\)", lambda m: "url(file://" + os.path.join(folder, m.group(1)) + ")", css))
    return "\n".join(out)


def chrome_pdf(html_path, pdf_path):
    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    subprocess.run([chrome, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    "--virtual-time-budget=20000", f"--print-to-pdf={os.path.abspath(pdf_path)}", "file://" + os.path.abspath(html_path)],
                   check=True, capture_output=True)


def dest_pages(pdf_path):
    """The page each linked anchor landed on, {id: page}, from the PDF's named destinations.
    Chrome records one for every element that something links to (the contents does this)."""
    import pypdf
    r = pypdf.PdfReader(pdf_path)
    return {k.lstrip("/"): r.get_destination_page_number(d) + 1 for k, d in r.named_destinations.items()}


# Margins of the print proof, in inches: top, outside, bottom, inside. Line height in points.
MARGINS = (0.7, 0.6, 0.75, 0.8)
LINE = 14.0


def fill_gaps(pdf_path, layouts, moves, page_h):
    """Where a table or figure was pushed to the next page and left a gap, move the text that
    follows it up into the gap, as a typesetter would. Tables are never split over two pages
    (George, 14 October 2026), so a table may move past as many paragraphs as it takes, and past
    the heading of the next box (an h3) if it must; a figure, which is numbered, may move past
    the next section heading (an h2) but not into a box. Neither passes another table or figure,
    and a heading is never left at the foot of a page. Returns True if anything moved.

    Positions come from the probes: a top probe at the start of the body calibrates the page,
    and each block's start and end probe give its page and how far down the page it sits.
    """
    import pypdf
    r = pypdf.PdfReader(pdf_path)
    at = {}
    for k, d in r.named_destinations.items():
        k = k.lstrip("/")
        if k == "top" or re.fullmatch(r"[se]\d+-\d+", k):
            at[k] = (r.get_destination_page_number(d) + 1, page_h - float(d["/Top"]))
    zero = at["top"][1]
    down = lambda k: at[k][1] - zero  # points below the top of the text area
    usable = page_h - (MARGINS[0] + MARGINS[2]) * 72
    extra = {"p": 0, "quote": 18, "list": 11, "h2": 20, "h3": 15}
    passes = {"trial": ("p", "quote", "list", "h3"), "figure": ("p", "quote", "list", "h2")}
    changed = False
    for i, seq in enumerate(layouts, 1):
        for pos, (j, kind) in enumerate(seq):
            if kind not in passes or pos == 0:
                continue
            prev, prev_kind = seq[pos - 1]
            if prev_kind not in ("p", "quote", "list", "h2", "h3") or f"s{i}-{j}" not in at:
                continue
            page = at[f"s{i}-{j}"][0]
            if at[f"e{i}-{prev}"][0] != page - 1:
                continue
            gap = usable - (down(f"e{i}-{prev}") + LINE)
            fill, n, last = 0.0, 0, []
            for q, q_kind in seq[pos + 1:]:
                if q_kind not in passes[kind] or f"e{i}-{q}" not in at:
                    break
                (ps, ys), (pe, ye) = at[f"s{i}-{q}"], at[f"e{i}-{q}"]
                ys, ye = ys - zero, ye - zero
                h = (ye - ys if ps == pe else usable - ys + (pe - ps - 1) * usable + ye) + LINE + extra[q_kind]
                if fill + h > gap - 4:
                    break
                fill, n = fill + h, n + 1
                last.append((q_kind, h))
            while last and last[-1][0] in ("h2", "h3"):  # never leave a heading at the foot of the page
                fill, n = fill - last.pop()[1], n - 1
            if n:
                moves[i][j] = moves[i].get(j, 0) + n
                changed = True
    return changed


SPLIT = {"list": "list", "quote": "From the saddle box", "formula": "formula", "survives": "What survives box"}


def check_splits(pdf_path, html_path, layouts, chapters, first):
    """Page breaks a reader would notice, read from a build with probes, which has the book's own layout:
    a list, box or formula running onto the next page, a heading left at the foot of a page, and a sentence
    parted from the list or formula it introduces. A list of four or more items may break between its middle
    items (the print style allows it); it is reported with its length so it can be looked at."""
    pages = dest_pages(pdf_path)
    text = open(html_path, encoding="utf-8").read()
    items = {m.group(2): m.group(3).count("<li") for m in re.finditer(r'<(ol|ul) id="(s\d+-\d+)">(.*?)</\1>', text, re.S)}
    found = []
    for i, seq in enumerate(layouts, 1):
        where = running_title(chapters[i - 1][0])
        for pos, (j, kind) in enumerate(seq):
            s, e = pages.get(f"s{i}-{j}"), pages.get(f"e{i}-{j}")
            if s is None or e is None:
                continue
            nxt = seq[pos + 1] if pos + 1 < len(seq) else None
            ns = pages.get(f"s{i}-{nxt[0]}") if nxt else None
            at = f"{where}, page {folio(s, first)}"
            if kind in SPLIT and s != e:
                n = items.get(f"s{i}-{j}")
                found.append(f"{at}: a {SPLIT[kind]}{f' of {n} items' if n else ''} runs onto the next page")
            elif kind in ("h2", "h3") and ns and ns != e:
                found.append(f"{at}: a heading at the foot of the page")
            elif kind == "p" and nxt and nxt[1] in ("list", "formula") and ns and ns != e:
                found.append(f"{at}: the sentence before a {nxt[1]} is on the page before it")
    return found


def hyphen_turns(pdf_path, first):
    """Printed pages whose last line ends in a hyphen, split by whether the reader has to turn the leaf
    to finish the word (a right-hand page) or only look across the spread (a left-hand page)."""
    import pypdf
    turn, across = [], []
    for p, page in enumerate(pypdf.PdfReader(pdf_path).pages, 1):
        lines = [l for l in (page.extract_text() or "").split("\n") if l.strip()]
        if p >= first and lines and lines[-1].rstrip().endswith(("\u2010", "-")):
            (turn if p % 2 else across).append(folio(p, first))
    return turn, across


# Chapters open on the next page, left or right, as in most paperbacks (George, 20 October 2026, asked
# why there were blank pages between chapters). "right" puts every chapter on a right-hand page, with a
# blank page before any that would open on the left. The Introduction and the part title pages open on
# the right either way.
CHAPTERS_OPEN = "any"

NOCITE = lambda group, shadow=False: ""  # front matter and contents have no citations


def front_matter():
    """The title, subtitle and author (front/title.md), the copyright page (front/copyright.md) and,
    if front/dedication.md exists, a dedication."""
    folder = os.path.join(BOOK, "front")
    read = lambda n: re.sub(r"<!--.*?-->", "", open(os.path.join(folder, n), encoding="utf-8").read(), flags=re.S)
    lines = [l.strip() for l in read("title.md").split("\n") if l.strip()]
    paras = lambda n: "".join(f"<p>{inline(' '.join(p.split()), NOCITE)}</p>" for p in read(n).split("\n\n") if p.strip())
    # the dedication keeps its line breaks, as written
    verse = lambda n: "".join("<p>" + "<br>".join(inline(l.strip(), NOCITE) for l in p.split("\n") if l.strip()) + "</p>"
                              for p in read(n).split("\n\n") if p.strip())
    return {"title": next(l[2:].strip() for l in lines if l.startswith("# ")),
            "sub": next((l[3:].strip() for l in lines if l.startswith("## ")), ""),
            "author": next(l for l in lines if not l.startswith("#")),
            "copyright": paras("copyright.md"),
            "dedication": verse("dedication.md") if os.path.exists(os.path.join(folder, "dedication.md")) else ""}


def split_title(t):
    """'Chapter 1: What limits endurance' -> ('Chapter 1', 'What limits endurance'); likewise 'Introduction: ...'."""
    m = re.match(r"(Chapter \d+|Introduction):\s*(.+)", t)
    return (m.group(1), m.group(2)) if m else ("", t)


def running_title(t):
    lab, name = split_title(t)
    return "Introduction" if lab == "Introduction" else name


def opener(h):
    """A chapter's heading for print: 'Chapter 1' (or 'Introduction') as a small label above the title."""
    return re.sub(r'<h1 id="(ch\d+)">(Chapter[ \u00a0]\d+|Introduction):\s*', r'<h1 id="\1"><span class="chl">\2</span>', h, count=1)


def contents_page(chapters, files, folios):
    """The contents: each part as a heading, then each chapter's number, title and page. Every line links
    to its chapter or part page, which is also how Chrome records where each one starts (dest_pages)."""
    rows, n = [], 0
    for (t, a, _, _), f in zip(chapters, files):
        p = part_of(f)
        if p:
            n += 1
            rows.append(f'<a class="tp" href="#part{n}">{p[0]}<span class="sep">·</span>{inline(p[1], NOCITE)}</a>')
        lab, name = split_title(t)
        num = lab[len("Chapter "):] if lab.startswith("Chapter ") else ""
        cls = "te bm" if not num and lab != "Introduction" else "te"
        rows.append(f'<a class="{cls}" href="#{a}"><span class="tn">{num}</span><span class="tt">{inline(name if num else t, NOCITE)}</span>'
                    f'<span class="tl"></span><span class="tpg">{folios.get(a, "000")}</span></a>')
    return f'<section class="fm toc" id="contents"><h1><a href="#contents">Contents</a></h1>{"".join(rows)}</section>'


def roman(n):
    out = ""
    for v, r in ((1000, "m"), (900, "cm"), (500, "d"), (400, "cd"), (100, "c"), (90, "xc"),
                 (50, "l"), (40, "xl"), (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")):
        while n >= v:
            out, n = out + r, n - v
    return out


def folio(page, first):
    """The printed page number: roman before the Introduction, arabic from 1 on its first page. The
    Introduction opens on a right-hand (odd) page, so even numbers stay on the left, as KDP requires."""
    return str(page - first + 1) if page >= first else roman(page)


def stamp(raw_pdf, out_pdf, chapters, pages, meta, trim):
    """Put the running heads and page numbers on the pages Chrome made, and write the interior file.

    Chrome cannot leave a running head off a chapter's first page, so the heads and numbers are
    printed by Chrome as a second PDF, one overlay page per page in the same fonts, and merged on top.
    Left pages carry the book's title, right pages the chapter's. A chapter's first page gets a
    number but no head; blank pages and part title pages get neither; the front matter is numbered
    in roman, shown only on the contents' later pages. Links, bookmarks and named destinations are
    left out, as KDP asks."""
    import pypdf
    w, h = (float(x) for x in trim)
    raw = pypdf.PdfReader(raw_pdf)
    first = pages["ch1"]
    opens = {pages[f"ch{i}"]: i for i in range(1, len(chapters) + 1)}
    parts = {p for k, p in pages.items() if re.fullmatch(r"part\d+", k)}
    empty = {i for i, pg in enumerate(raw.pages, 1) if not (pg.extract_text() or "").strip()}
    marks, ch = [], 0
    for p in range(1, len(raw.pages) + 1):
        ch = opens.get(p, ch)
        if p < first:
            marks.append(("", roman(p) if p > pages["contents"] and p not in empty else ""))
        elif p in empty or p in parts:
            marks.append(("", ""))
        elif p in opens:
            marks.append(("", folio(p, first)))
        else:
            marks.append((meta["title"] if p % 2 == 0 else running_title(chapters[ch - 1][0]), folio(p, first)))
    divs = []
    for p, (head, num) in enumerate(marks, 1):
        l, r = (MARGINS[3], MARGINS[1]) if p % 2 else (MARGINS[1], MARGINS[3])
        box = f"left:{l}in;right:{r}in"
        divs.append(f'<div class="pg"><div class="hd" style="{box}">{html.escape(smart_quotes(head))}</div>'
                    f'<div class="fo" style="{box}">{num}</div></div>')
    overlay_html = os.path.splitext(raw_pdf)[0] + "-heads.html"
    overlay_pdf = os.path.splitext(raw_pdf)[0] + "-heads.pdf"
    # each head and number centred in its margin, where Chrome's own margin boxes put them
    open(overlay_html, "w", encoding="utf-8").write(f"""<!doctype html>
<html lang="en-GB"><head><meta charset="utf-8"><style>
  {local_fonts()}
  @page{{size:{w}in {h}in;margin:0}}
  html,body{{margin:0;padding:0}}
  .pg{{position:relative;height:{h - 0.1}in;break-after:page}}
  .pg:last-child{{break-after:auto}}
  .hd,.fo{{position:absolute;height:10pt;text-align:center;color:#000;white-space:nowrap}}
  .hd{{top:calc({MARGINS[0] / 2}in - 5pt);font:italic 7.5pt/10pt "Newsreader",serif}}
  .fo{{top:calc({h - MARGINS[2] / 2}in - 5pt);font:7.5pt/10pt "IBM Plex Sans",sans-serif}}
</style></head><body>{"".join(divs)}</body></html>
""")
    chrome_pdf(overlay_html, overlay_pdf)
    over = pypdf.PdfReader(overlay_pdf)
    if len(over.pages) != len(raw.pages):
        sys.exit(f"stamp: {len(over.pages)} overlay pages for {len(raw.pages)} book pages")
    out = pypdf.PdfWriter()
    for page, top in zip(raw.pages, over.pages):
        page.merge_page(top)
        if "/Annots" in page:
            del page["/Annots"]  # the links Chrome made from the contents and the citations
        out.add_page(page)
    out.add_metadata({"/Title": meta["title"], "/Author": meta["author"]})
    with open(out_pdf, "wb") as fh:
        out.write(fh)
    for f in (overlay_html, overlay_pdf, raw_pdf):
        os.remove(f)
    return marks


def render_print(out_pdf, files, sources, trim):
    """Set the book as the paperback's interior: front matter, contents, part pages and chapters, then a
    PDF of it from Chrome, with running heads and page numbers stamped on afterwards.

    Chrome cannot float a table or figure, or start a page on the right, so the book is printed several
    times: first to move text up into gaps left by tables and figures pushed to the next page (tables
    are never split), then to add blank pages so the Introduction and the part pages open on the right
    (and every chapter, if CHAPTERS_OPEN is "right"), then to put the page numbers in the contents.
    """
    w, h = trim
    page_h = float(h) * 72
    out_html = os.path.splitext(out_pdf)[0] + ".html"
    raw_pdf = os.path.splitext(out_pdf)[0] + "-raw.pdf"
    moves = {i: {} for i in range(1, len(files) + 1)}
    meta = front_matter()
    blank = '<div class="blank"></div>'
    # the ids that can have a blank page put before them, in book order, and those that must open on the right
    order, n = [], 0
    for i, f in enumerate(files, 1):
        if part_of(f):
            n += 1
            order.append(f"part{n}")
        order.append(f"ch{i}")
    recto = {k for k in order if k == "ch1" or k.startswith("part") or CHAPTERS_OPEN == "right"}

    def build(probes, blanks=(), folios=None):
        chapters, layouts = [], []
        for i, f in enumerate(files, 1):
            layouts.append([])
            chapters.append(render_chapter(open(f, encoding="utf-8").read(), sources, i, os.path.dirname(os.path.abspath(f)),
                                           probes=probes, moves=moves[i], layout=layouts[-1], print_mode=True))
        # print citations as bare superscript numbers against the word
        cites = lambda x: re.sub(r'\s*<sup class="cite">\[(.*?)\]</sup>', r'<sup class="cite">\1</sup>', x)
        body, n = [], 0
        for i, (c, f) in enumerate(zip(chapters, files), 1):
            p = part_of(f)
            if p:  # a right-hand page with a blank back, so the chapter after it opens on the right too
                n += 1
                body.append((blank if f"part{n}" in blanks else "")
                            + f'<section class="part" id="part{n}"><p>{p[0]}</p><div class="pt">{html.escape(p[1])}</div></section>' + blank)
            cls = ' class="gloss"' if is_back(f) else ""
            body.append((blank if f"ch{i}" in blanks else "") + f'<article{cls}>{opener(cites(c[3]))}</article>')
        title, sub, author = (inline(meta[k], NOCITE) for k in ("title", "sub", "author"))
        top = '<div id="top"></div>' if probes else ""  # the top of the first page's text area, to calibrate fill_gaps
        front = (f'<section class="fm half">{top}<p class="ht">{title}</p></section>{blank}'
                 f'<section class="fm tpage"><h1 class="bt">{title}</h1><p class="sub">{sub}</p><p class="au">{author}</p></section>'
                 f'<section class="fm copy">{meta["copyright"]}</section>'
                 + (f'<section class="fm ded">{meta["dedication"]}</section>{blank}' if meta["dedication"] else "")
                 + contents_page(chapters, files, folios or {}))
        links = probe_links(layouts) if probes else ""
        style = PRINT_STYLE % {"w": w, "h": h, "fonts": local_fonts(),
                               "margins": " ".join(f"{m}in" for m in MARGINS), "out": MARGINS[1], "in": MARGINS[3]}
        page = f"""<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<title>{html.escape(meta["title"])} Print proof</title>
{style}
</head>
<body>
{front}
{"".join(body)}
{links}
</body>
</html>
"""
        open(out_html, "w", encoding="utf-8").write(page)
        chrome_pdf(out_html, raw_pdf)
        return chapters, layouts

    for _ in range(6):
        chapters, layouts = build(True)
        if not fill_gaps(raw_pdf, layouts, moves, page_h):
            break
    # Blank pages from the last layout measured, then checked against the final one (the gap
    # filling can stop before it settles, so the two can differ) and recomputed if need be.
    pages, blanks = dest_pages(raw_pdf), set()
    for _ in range(4):
        natural = {k: pages[k] - sum(1 for b in blanks if order.index(b) <= order.index(k)) for k in order}
        blanks, shift = set(), 0
        for k in order:
            if k in recto and (natural[k] + shift) % 2 == 0:
                blanks.add(k)
                shift += 1
        chapters, _ = build(False, blanks)
        pages = dest_pages(raw_pdf)
        if all(pages[k] % 2 for k in recto):
            break
    # The contents' page numbers, then a check that putting them in moved nothing.
    for _ in range(3):
        folios = {k: folio(p, pages["ch1"]) for k, p in pages.items()}
        build(False, blanks, folios)
        settled, pages = pages, dest_pages(raw_pdf)
        if pages == settled:
            break
    # The same layout once more with probes, to report any page breaks a reader would notice, then the book.
    _, layouts = build(True, blanks, folios)
    probed = dest_pages(raw_pdf)
    splits = check_splits(raw_pdf, out_html, layouts, chapters, pages["ch1"])
    build(False, blanks, folios)
    if any(probed.get(k) != pages[k] for k in order):
        splits.append("the build with probes laid the book out differently, so these checks may be wrong")
    turn, across = hyphen_turns(raw_pdf, pages["ch1"])
    name = lambda k: chapters[int(k[2:]) - 1][0] if k.startswith("ch") else k
    left = [name(k) for k in order if k in recto and pages[k] % 2 == 0]
    marks = stamp(raw_pdf, out_pdf, chapters, pages, meta, trim)
    total = len(marks)
    blank_pages = sum(1 for p, (hd, num) in enumerate(marks, 1) if not hd and not num and p >= pages["ch1"]
                      and p not in {v for k, v in pages.items() if k.startswith("part")})
    moved = sum(len(m) for m in moves.values())
    # Anything that must not reach the printed book
    text = open(out_html, encoding="utf-8").read()
    notes = [re.sub(r"<[^>]+>", "", m) for m in re.findall(r'<mark class="george">(.*?)</mark>', text, re.S)]
    problems = notes + re.findall(r"MISSING FROM sources\.yaml: \S+|Missing figure: [^<]+|\[FIGURE[^\]]*\]", text)
    print(f"{out_pdf}: {counted(files)}, {sum(c[2] for c in chapters):,} words, {w} × {h} in, {total} pages "
          f"({pages['ch1'] - 1} of front matter), {blank_pages} blank pages after the front matter, "
          f"tables or figures moved down to fill a gap: {moved}. Spine: {total * 0.002252:.3f} in on white paper, "
          f"{total * 0.0025:.3f} in on cream (KDP's rule)."
          + (f"\nWARNING, opening on a left-hand page: {left}" if left else "")
          + "".join(f"\nSPLIT: {x}" for x in splits)
          + f"\nWords hyphenated across a page: {len(turn)} where the reader turns the leaf (pages {', '.join(turn) or 'none'}), "
            f"{len(across)} across an open spread"
          + ("".join(f"\nNOT FOR PRINT: {p}" for p in problems)))


def main():
    args = sys.argv[1:]
    trim = (6, 9)
    if args[:1] == ["--trim"]:
        trim = tuple(x for x in args[1].split("x"))
        args = args[2:]
    if len(args) < 2:
        print(__doc__)
        sys.exit(2)
    out_path, files = args[0], args[1:]
    if os.path.exists(GLOSSARY) and GLOSSARY not in map(os.path.abspath, files):
        files = files + [GLOSSARY]
    sources = load_sources()
    if out_path.endswith(".pdf"):
        render_print(out_path, files, sources, trim)
        return
    chapters = [render_chapter(open(f, encoding="utf-8").read(), sources, i, os.path.dirname(os.path.abspath(f))) for i, f in enumerate(files, 1)]
    total = sum(c[2] for c in chapters)
    today = datetime.date.today().strftime("%-d %B %Y")
    parts = [part_of(f) for f in files]
    toc = "".join((f'<div class="tocpart">{p[0]} · {html.escape(p[1])}</div>' if p else "")
                  + f'<a href="#{a}">{html.escape(t)}<span>{w:,} words</span></a>' for (t, a, w, _), p in zip(chapters, parts))
    body = "".join((f'<div class="partpage"><span>{p[0]}</span>{html.escape(p[1])}</div>' if p else "")
                   + f'<article{" class=gloss" if is_back(f) else ""}>{c[3].replace("</h1>", f"</h1><p class=meta>Draft · {c[2]:,} words · {today}</p>", 1)}</article>'
                   for c, p, f in zip(chapters, parts, files))
    cut_key = '<del class="cut">struck through</del> a proposed cut, not yet made &nbsp;' if 'class="cut"' in body else ""
    page = f"""<title>Just Zone 2? Draft</title>
{STYLE}
<div class="wrap">
  <div class="banner"><b>Just Zone 2? First drafts for review.</b> {total:,} words. Read for the argument and the voice first; wording can change.
    <div class="key">Evidence grades: <span class="grade gA">A</span> trials or meta-analysis <span class="grade gB">B</span> small or single-lab <span class="grade gC">C</span> observation, mechanism or opinion</div>
    <div class="key">References show how far each source has been checked: <span class="status s-fulltext">fulltext</span> <span class="status s-abstract">abstract</span> <span class="status s-exists">exists</span> &nbsp;<sup class="cite shadow">[s1]</sup> a source kept for checking, not printed &nbsp;{cut_key}<mark class="george">George: highlighted notes need your input</mark></div>
  </div>
  <nav class="toc">{toc}</nav>
  {body}
</div>
"""
    open(out_path, "w", encoding="utf-8").write(page)
    print(f"{out_path}: {counted(files)}, {total:,} words")


if __name__ == "__main__":
    main()
