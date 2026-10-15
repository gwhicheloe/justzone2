#!/usr/bin/env python3
"""Render chapter drafts to one HTML review page.

  python3 book/tools/render.py OUT.html book/chapters/intro/draft.md book/chapters/limits/draft.md ...
  python3 book/tools/render.py [--trim 6x9] OUT.pdf chapters...   -> a print proof: book pages at the
                          paperback's trim size (default 6 x 9 in), made with Chrome; OUT.html is kept beside it

Handles the subset of Markdown the drafts use: headings, paragraphs, bold and
italic, numbered and bulleted lists, blockquotes. Book conventions:
  [@key] or [@a; @b]   -> numbered citations, numbered afresh in each chapter,
                          with a reference list built from sources.yaml
  {shadow @key; @b}    -> a source kept with its sentence for checking but not printed: shown faintly
                          on the review page with its own list, dropped from the print proof
                          (style.md says which sources are printed)
  {grade A|B|C}        -> a small evidence-grade badge
  [GEORGE: ...]        -> a highlighted note for George
  ![caption](figures/x.svg) on its own paragraph -> the SVG inline, numbered, with the caption
  ::: trial ... :::    -> a trial laid out as a table (no blank lines inside):
                            Label: text            a row across the full width (Hypothesis, Design, Authors' conclusion)
                            | | Arm A | Arm B      the groups, one column each (two or more)
                            | Label | a | b        a row of values; fewer values than groups -> the last spans the rest
                            ~ text                 a note under the row above (e.g. not significant)
                            -- Heading             a sub-heading across the table
The output is an HTML fragment (title, style, content) that works both as an
Artifact page and when opened directly in a browser.
"""
import datetime
import html
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BOOK = os.path.dirname(HERE)


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
    t = html.escape(text, quote=False)
    t = t.replace("₂", "<sub>2</sub>")  # Newsreader has no subscript two; a fallback font's would show
    t = re.sub(r"\[GEORGE:(.*?)\]", lambda m: f'<mark class="george">George: {m.group(1).strip()}</mark>', t, flags=re.S)
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
        kinds.append("trial" if first.startswith("::: trial") else "h3" if first.startswith("### ") else
                     "h2" if first.startswith("## ") else "h1" if first.startswith("# ") else
                     "figure" if re.match(r"!\[(.*)\]\((\S+\.svg)\)\s*$", " ".join(b)) else
                     "quote" if first.startswith(">") else "list" if re.match(r"(\d+\.|[-*])\s", first) else "p")
        if first.startswith("# "):
            title = first[2:].strip()
            out.append(f'<h1 id="{anchor}">{inline(title, cite)}</h1>')
        elif first.startswith("::: trial"):
            out.append(render_trial(b, cite, two_part=print_mode))
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

    words = len(re.findall(r"\b\w+\b", re.sub(r"\[@[^\]]+\]|\{shadow [^{}]*\}|\{grade [ABC]\}", "", md)))

    def ref_list(keys, prefix):
        refs = []
        for n, k in enumerate(keys, 1):
            s = sources.get(k, {})
            status = s.get("status", "missing")
            doi = s.get("doi")
            link = f' <a href="https://doi.org/{html.escape(doi)}">doi</a>' if doi else ""
            refs.append(f'<li id="c{idx}-{prefix}{n}">{html.escape(s.get("citation", "MISSING FROM sources.yaml: " + k))}{link}'
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
  :root{--bg:#F6F5F1;--page:#FFFFFF;--ink:#1C1F1D;--muted:#5D6460;--faint:#8B918D;--rule:#E1E3DF;
    --accent:#1E7F45;--mark:#FFF1B8;--mark-ink:#5A4300;--gA:#1E7F45;--gB:#B07A12;--gC:#9A4E2E;
    --serif:"Newsreader",Georgia,"Times New Roman",serif;--sans:"IBM Plex Sans",-apple-system,"Segoe UI",sans-serif;--mono:"IBM Plex Mono",ui-monospace,Menlo,monospace}
  @media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#111412;--page:#181C19;--ink:#E5E8E5;--muted:#A0A8A3;--faint:#737B76;--rule:#2B312D;
    --accent:#58C485;--mark:#4A3C0E;--mark-ink:#FFE7A0;--gA:#58C485;--gB:#E0B04A;--gC:#E08A66;color-scheme:dark}}
  :root[data-theme="dark"]{--bg:#111412;--page:#181C19;--ink:#E5E8E5;--muted:#A0A8A3;--faint:#737B76;--rule:#2B312D;
    --accent:#58C485;--mark:#4A3C0E;--mark-ink:#FFE7A0;--gA:#58C485;--gB:#E0B04A;--gC:#E08A66;color-scheme:dark}
  body{background:var(--bg);color:var(--ink);font-family:var(--serif);font-size:19px;line-height:1.62}
  .wrap{max-width:720px;margin:0 auto;padding-inline:20px;padding-block:28px 90px}
  .banner{font-family:var(--sans);font-size:14px;line-height:1.55;background:var(--page);border:1px solid var(--rule);border-radius:10px;padding:14px 16px;color:var(--muted)}
  .banner b{color:var(--ink)}
  .banner .key{display:flex;flex-wrap:wrap;gap:6px 14px;margin-top:8px;align-items:center}
  nav.toc{font-family:var(--sans);font-size:15px;margin:22px 0 8px}
  nav.toc a{color:var(--accent);text-decoration:none;display:block;padding:3px 0}
  nav.toc span{color:var(--faint);font-family:var(--mono);font-size:12px;margin-left:8px}
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
  blockquote.saddle{margin:18px 0;padding:4px 0 4px 18px;border-left:3px solid var(--accent);font-style:italic}
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


# The print proof: the same chapters set as book pages, for checking how the paperback will look.
# Sizes are KDP's: inside margins must be at least 0.5 in for 151 to 300 pages and 0.625 in for 301 to 500,
# other margins at least 0.25 in without bleed. Black ink only.
PRINT_STYLE = """
<style>
  %(fonts)s
  @page{size:%(w)sin %(h)sin;margin:%(margins)s;
    @bottom-center{content:counter(page);font:7.5pt "IBM Plex Sans",sans-serif;color:#000}}
  @page :left{margin-left:%(out)sin;margin-right:%(in)sin}
  @page :right{margin-left:%(in)sin;margin-right:%(out)sin}
  @page front{@bottom-center{content:none}}
  @page blank{@top-center{content:none}@bottom-center{content:none}}
  .blank{page:blank;height:1px}
  %(heads)s
  /* Nothing may be wider than the text area: Chrome would shrink every page to fit it. */
  *{-webkit-print-color-adjust:exact;print-color-adjust:exact;box-sizing:border-box}
  :root{--serif:"Newsreader",Georgia,serif;--sans:"IBM Plex Sans",sans-serif;--mono:"IBM Plex Mono",monospace}
  html,body{margin:0;padding:0;background:#fff;color:#000}
  body{font-family:var(--serif);font-size:10.5pt;line-height:14pt;text-align:justify;hyphens:auto;-webkit-hyphens:auto;font-variant-numeric:lining-nums}
  section.front{page:front;height:7.5in;display:flex;flex-direction:column;justify-content:center;text-align:left}
  section.front h1{font-size:30pt;line-height:1.1;margin:0 0 10pt;font-weight:600}
  section.front p{font-family:var(--sans);font-size:8.5pt;line-height:1.5;text-align:left;text-indent:0;margin:0 0 6pt;hyphens:manual}
  article{break-before:right}
  h1{font-size:21pt;line-height:1.15;font-weight:600;margin:0.9in 0 0.3in;text-align:left;hyphens:manual;text-wrap:balance}
  h2{font-size:12.5pt;line-height:1.25;font-weight:600;margin:15pt 0 5pt;text-align:left;hyphens:manual;break-after:avoid}
  h3{font-family:var(--sans);font-size:8.5pt;font-weight:600;letter-spacing:.02em;margin:12pt 0 3pt;text-align:left;hyphens:manual;break-after:avoid}
  p{margin:0;orphans:2;widows:2} p+p{text-indent:1.2em}
  ol,ul{margin:5pt 0 6pt;padding-left:1.5em} li{margin:2pt 0}
  strong{font-weight:600}
  a{color:inherit;text-decoration:none}
  sup.cite{font-family:var(--sans);font-size:6pt;line-height:0;margin-left:.5pt}
  sub{font-size:.7em;line-height:0;vertical-align:-.25em}
  .probes{font-size:1px;line-height:1px;color:#fff;break-before:page}
  .gradenote{font-size:.9em}
  .grade{font-family:var(--mono);font-size:6pt;border:.5pt solid #000;border-radius:2pt;padding:0 1.5pt;margin-left:2pt;vertical-align:1pt}
  mark.george{background:#e4e4e4;color:#000;font-family:var(--sans);font-size:8pt;padding:0 2pt;-webkit-box-decoration-break:clone;box-decoration-break:clone}
  figure{margin:10pt 0 12pt;break-inside:avoid} figure svg{display:block;width:100%%;height:auto}
  figcaption{font-family:var(--sans);font-size:7.5pt;line-height:1.35;text-align:left;hyphens:manual;margin-top:4pt}
  blockquote.saddle{margin:9pt 0;padding-left:9pt;border-left:1.2pt solid #000;font-style:italic}
  section.refs{margin-top:16pt}
  section.refs h2{font-family:var(--sans);font-size:7.5pt;letter-spacing:.08em;text-transform:uppercase;margin:0 0 4pt}
  section.refs ol{font-family:var(--sans);font-size:7pt;line-height:1.35;text-align:left;hyphens:manual;padding-left:2em;margin:0}
  section.refs li{margin:0 0 1.5pt}
  .status,section.refs a{display:none}
  .missing{font-family:var(--sans);font-size:8pt;border:.5pt dashed #000;padding:6pt}
  .trial{margin:9pt 0 11pt;border:.6pt solid #000;font-family:var(--sans);font-size:7.5pt;line-height:1.35;text-align:left;hyphens:manual;-webkit-hyphens:manual;break-inside:avoid}
  .trial table{width:100%%;border-collapse:collapse;table-layout:fixed}
  .trial col.crl{width:21%%} .trial.wide col.crl{width:17%%}
  .trial th,.trial td{padding:3pt 4.5pt;vertical-align:top;text-align:left}
  .trial tr{break-inside:avoid}
  .trial tr+tr>*{border-top:.4pt solid #9a9a9a}
  .trial .rl{font-weight:600;color:#333}
  .trial tr.data td+td{border-left:.4pt solid #9a9a9a}
  .trial tr.data td{font-variant-numeric:tabular-nums}
  .trial tr.arms th{font-size:8pt;font-weight:600;border-bottom:.9pt solid #000}
  .trial tr.arms th em{display:block;font-size:6.8pt;font-weight:400;color:#444}
  .trial tr.sub th{font-size:6.5pt;font-weight:600;letter-spacing:.06em;text-transform:uppercase;background:#ececec;padding:2pt 4.5pt}
  .trial tr.note>*{border-top:0;padding-top:0;font-size:6.8pt;font-style:italic;color:#444}
  .trial tr.hyp td,.trial tr.concl td{font-family:var(--serif);font-size:8.8pt;line-height:1.3}
  .trial tr.hyp td{font-style:italic}
  .trial tr.concl>*{border-top:.9pt solid #000}
  .trial tr.mlab{display:none}
  .trial table.lead{break-inside:avoid;break-after:avoid}
  .trial table.main thead tr>*{border-top:.4pt solid #9a9a9a}
</style>
"""


FONTS_CSS = ("https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,600;1,6..72,400;1,6..72,600"
             "&family=IBM+Plex+Sans:ital,wght@0,400;0,600;1,400&family=IBM+Plex+Mono:wght@500")


def local_fonts():
    """@font-face rules pointing at copies of the fonts in book/fonts/ (git-ignored), fetched once.

    Chrome prints before web fonts arrive, so the proof uses local files. Newsreader and
    IBM Plex are under the SIL Open Font License, which allows embedding them in a printed book.
    """
    folder = os.path.join(BOOK, "fonts")
    css_path = os.path.join(folder, "fonts.css")
    if not os.path.exists(css_path):
        import urllib.request
        os.makedirs(folder, exist_ok=True)
        get = lambda u: urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "just-zone-2-book-research"})).read()
        css = get(FONTS_CSS).decode()
        for url in re.findall(r"url\((https://[^)]+\.ttf)\)", css):
            name = re.sub(r"[^A-Za-z0-9.]", "", url.split("/s/")[1].replace("/", "-"))
            open(os.path.join(folder, name), "wb").write(get(url))
            css = css.replace(url, name)
        open(css_path, "w", encoding="utf-8").write(css)
    css = open(css_path, encoding="utf-8").read()
    return re.sub(r"url\(([^)]+\.ttf)\)", lambda m: "url(file://" + os.path.join(folder, m.group(1)) + ")", css)


def css_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def chrome_pdf(html_path, pdf_path):
    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    subprocess.run([chrome, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--generate-pdf-document-outline",
                    "--virtual-time-budget=20000", f"--print-to-pdf={os.path.abspath(pdf_path)}", "file://" + os.path.abspath(html_path)],
                   check=True, capture_output=True)


def chapter_starts(pdf_path):
    """The page number each chapter starts on, from the PDF's outline (one top-level entry per h1)."""
    import pypdf
    r = pypdf.PdfReader(pdf_path)
    return [r.get_destination_page_number(x) + 1 for x in r.outline if not isinstance(x, list)][1:]


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


def render_print(out_pdf, files, sources, trim):
    """Set the chapters as a print proof: an HTML page laid out for paper, then a PDF of it from Chrome.

    Chrome cannot float a table or figure, or start a chapter on a right-hand page, so the proof
    is printed several times: first to move text up into gaps left by tables and figures that
    were pushed to the next page (tables are never split), then to put a blank page before each
    chapter that would start on the left. The running head is the book's title on left-hand pages and the chapter's on
    right-hand pages.
    """
    import pypdf
    w, h = trim
    page_h = float(h) * 72
    today = datetime.date.today().strftime("%-d %B %Y")
    out_html = os.path.splitext(out_pdf)[0] + ".html"
    moves = {i: {} for i in range(1, len(files) + 1)}

    def build(probes, blanks=()):
        chapters, layouts = [], []
        for i, f in enumerate(files, 1):
            layouts.append([])
            chapters.append(render_chapter(open(f, encoding="utf-8").read(), sources, i, os.path.dirname(os.path.abspath(f)),
                                           probes=probes, moves=moves[i], layout=layouts[-1], print_mode=True))
        total = sum(c[2] for c in chapters)
        font = 'font:italic 7.5pt "Newsreader",serif'
        heads = "\n  ".join(
            f'@page p{i}:left{{@top-center{{content:"Just Zone 2?";{font}}}}} '
            f'@page p{i}:right{{@top-center{{content:{css_string(t)};{font}}}}}'
            for i, (t, _, _, _) in enumerate(chapters, 1))
        # print citations as bare superscript numbers against the word
        cites = lambda x: re.sub(r'\s*<sup class="cite">\[(.*?)\]</sup>', r'<sup class="cite">\1</sup>', x)
        body = "".join(('<div class="blank"></div>' if i in blanks else "") + f'<article style="page:p{i}">{cites(c[3])}</article>'
                       for i, c in enumerate(chapters, 1))
        top = '<div id="top" style="page:front"></div>' if probes else ""  # same named page as the title, or Chrome breaks between them
        links = probe_links(layouts) if probes else ""
        style = PRINT_STYLE % {"w": w, "h": h, "heads": heads, "fonts": local_fonts(),
                               "margins": " ".join(f"{m}in" for m in MARGINS), "out": MARGINS[1], "in": MARGINS[3]}
        page = f"""<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<title>Just Zone 2? Print proof</title>
{style}
</head>
<body>{top}
<section class="front">
  <h1>Just Zone 2?</h1>
  <p>George Whicheloe</p>
  <p>Print proof, {w} × {h} in. {len(chapters)} chapters in first draft, {total:,} words. {today}.</p>
  <p>Set to the paperback's size, type and margins, to show how the pages will look. The figures were drawn for the screen and have not yet been redrawn for print.</p>
</section>
{body}
{links}
</body>
</html>
"""
        open(out_html, "w", encoding="utf-8").write(page)
        chrome_pdf(out_html, out_pdf)
        return chapters, layouts

    for _ in range(6):
        chapters, layouts = build(True)
        if not fill_gaps(out_pdf, layouts, moves, page_h):
            break
    # Blank pages from the last layout measured, then checked against the final one (the gap
    # filling can stop before it settles, so the two can differ) and recomputed if need be.
    starts, blanks = chapter_starts(out_pdf), set()
    for _ in range(4):
        natural = [p - sum(1 for k in blanks if k <= i) for i, p in enumerate(starts, 1)]
        blanks, shift = set(), 0
        for i, p in enumerate(natural, 1):
            if (p + shift) % 2 == 0:
                blanks.add(i)
                shift += 1
        chapters, _ = build(False, blanks)
        starts = chapter_starts(out_pdf)
        if all(p % 2 for p in starts):
            break
    left = [chapters[i][0] for i, p in enumerate(starts) if p % 2 == 0]
    pages = len(pypdf.PdfReader(out_pdf).pages)
    moved = sum(len(m) for m in moves.values())
    print(f"{out_pdf}: {len(chapters)} chapters, {sum(c[2] for c in chapters):,} words, {w} × {h} in, {pages} pages, "
          f"tables or figures moved down to fill a gap: {moved}"
          + (f"; WARNING, starting on a left-hand page: {left}" if left else ""))


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
    sources = load_sources()
    if out_path.endswith(".pdf"):
        render_print(out_path, files, sources, trim)
        return
    chapters = [render_chapter(open(f, encoding="utf-8").read(), sources, i, os.path.dirname(os.path.abspath(f))) for i, f in enumerate(files, 1)]
    total = sum(c[2] for c in chapters)
    today = datetime.date.today().strftime("%-d %B %Y")
    toc = "".join(f'<a href="#{a}">{html.escape(t)}<span>{w:,} words</span></a>' for t, a, w, _ in chapters)
    body = "".join(f'<article>{c[3].replace("</h1>", f"</h1><p class=meta>Draft · {c[2]:,} words · {today}</p>", 1)}</article>' for c in chapters)
    page = f"""<title>Just Zone 2? Draft</title>
{STYLE}
<div class="wrap">
  <div class="banner"><b>Just Zone 2? First drafts for review.</b> {total:,} words. Read for the argument and the voice first; wording can change.
    <div class="key">Evidence grades: <span class="grade gA">A</span> trials or meta-analysis <span class="grade gB">B</span> small or single-lab <span class="grade gC">C</span> observation, mechanism or opinion</div>
    <div class="key">References show how far each source has been checked: <span class="status s-fulltext">fulltext</span> <span class="status s-abstract">abstract</span> <span class="status s-exists">exists</span> &nbsp;<sup class="cite shadow">[s1]</sup> a source kept for checking, not printed &nbsp;<mark class="george">George: highlighted notes need your input</mark></div>
  </div>
  <nav class="toc">{toc}</nav>
  {body}
</div>
"""
    open(out_path, "w", encoding="utf-8").write(page)
    print(f"{out_path}: {len(chapters)} chapters, {total:,} words")


if __name__ == "__main__":
    main()
