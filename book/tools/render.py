#!/usr/bin/env python3
"""Render chapter drafts to one HTML review page.

  python3 book/tools/render.py OUT.html book/chapters/intro/draft.md book/chapters/limits/draft.md ...

Handles the subset of Markdown the drafts use: headings, paragraphs, bold and
italic, numbered and bulleted lists, blockquotes. Book conventions:
  [@key] or [@a; @b]   -> numbered citations, numbered afresh in each chapter,
                          with a reference list built from sources.yaml
  {grade A|B|C}        -> a small evidence-grade badge
  [GEORGE: ...]        -> a highlighted note for George
  ![caption](figures/x.svg) on its own paragraph -> the SVG inline, numbered, with the caption
The output is an HTML fragment (title, style, content) that works both as an
Artifact page and when opened directly in a browser.
"""
import datetime
import html
import os
import re
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
    t = re.sub(r"\[GEORGE:(.*?)\]", lambda m: f'<mark class="george">George: {m.group(1).strip()}</mark>', t, flags=re.S)
    t = re.sub(r"\{grade ([ABC])\}", lambda m: f'<span class="grade g{m.group(1)}" title="Evidence grade {m.group(1)}">{m.group(1)}</span>', t)
    t = re.sub(r"\[(@[^\]]+)\]", lambda m: cite(m.group(1)), t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", t)
    return t


def render_chapter(md, sources, idx, base="."):
    order = []

    def cite(group):
        keys = re.findall(r"@([A-Za-z0-9_:-]+)", group)
        nums = []
        for k in keys:
            if k not in order:
                order.append(k)
            nums.append(order.index(k) + 1)
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

    out, title, anchor, fig_n = [], "", f"ch{idx}", [0]
    for b in blocks:
        first = b[0]
        if first.startswith("# "):
            title = first[2:].strip()
            out.append(f'<h1 id="{anchor}">{inline(title, cite)}</h1>')
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

    words = len(re.findall(r"\b\w+\b", re.sub(r"\[@[^\]]+\]|\{grade [ABC]\}", "", md)))
    if order:
        refs = []
        for n, k in enumerate(order, 1):
            s = sources.get(k, {})
            status = s.get("status", "missing")
            doi = s.get("doi")
            link = f' <a href="https://doi.org/{html.escape(doi)}">doi</a>' if doi else ""
            refs.append(f'<li id="c{idx}-r{n}">{html.escape(s.get("citation", "MISSING FROM sources.yaml: " + k))}{link}'
                        f' <span class="status s-{status}">{status}</span></li>')
        out.append('<section class="refs"><h2>References</h2><ol>' + "".join(refs) + "</ol></section>")
    return title, anchor, words, "\n".join(out)


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
  sup.cite a{color:var(--accent);text-decoration:none}
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
  @media (max-width:520px){body{font-size:17.5px} article{padding:24px 16px}}
</style>
"""


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    out_path, files = sys.argv[1], sys.argv[2:]
    sources = load_sources()
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
    <div class="key">References show how far each source has been checked: <span class="status s-fulltext">fulltext</span> <span class="status s-abstract">abstract</span> <span class="status s-exists">exists</span> &nbsp;<mark class="george">George: highlighted notes need your input</mark></div>
  </div>
  <nav class="toc">{toc}</nav>
  {body}
</div>
"""
    open(out_path, "w", encoding="utf-8").write(page)
    print(f"{out_path}: {len(chapters)} chapters, {total:,} words")


if __name__ == "__main__":
    main()
