#!/usr/bin/env python3
"""Look up papers for the book, from free scholarly databases.

  python3 book/tools/lookup.py search 'TITLE:"critical power" AND cycling' [more queries...]
      Europe PMC search: first hit per query, with citation, IDs and abstract.
  python3 book/tools/lookup.py list N 'query' [more...]
      Europe PMC: top N hits per query, most cited first (for surveying a topic).
  python3 book/tools/lookup.py pmid 31295069 [more...]
      Europe PMC record by PubMed ID: citation, open-access status, abstract.
  python3 book/tools/lookup.py oa 10.1113/jp284205 [more DOIs...]
      OpenAlex: is there a legal free copy, and where.
  python3 book/tools/lookup.py fulltext PMC9977827 out.txt
      Europe PMC open-access full text, as plain text with section headings.

Abstracts and full texts are for reading and note-taking only. Don't paste
them into drafts; summarise in our own words (see style.md).
"""
import html
import json
import re
import sys
import textwrap
import time
import urllib.parse
import urllib.request

EPMC = "https://www.ebi.ac.uk/europepmc/webservices/rest/"


def get_json(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "just-zone-2-book-research"})
            return json.load(urllib.request.urlopen(req, timeout=40))
        except Exception as e:  # network hiccups: retry with backoff
            err = e
            time.sleep(3 * (i + 1))
    raise SystemExit(f"failed: {url}\n{err}")


def clean(text):
    text = re.sub(r"</?(?:h4|i|b|sub|sup|p|em|strong|span)[^>]*>", "", text or "")
    return html.unescape(text)


def show(r):
    j = r.get("journalInfo", {})
    cite = (f"{r.get('authorString', '')[:150]}. {r.get('title')} "
            f"{j.get('journal', {}).get('isoabbreviation')} {j.get('yearOfPublication') or r.get('pubYear')};"
            f"{j.get('volume', '')}:{r.get('pageInfo', '')}")
    print("=" * 100)
    print(cite)
    print(f"PMID {r.get('pmid')} | PMC {r.get('pmcid')} | OA {r.get('isOpenAccess')} | doi {r.get('doi')}")
    print(textwrap.fill(clean(r.get("abstractText", "(no abstract)")), 110))


def search(queries, n=1, lite=False):
    for q in queries:
        params = {"query": q, "resultType": "lite" if lite else "core", "format": "json", "pageSize": n}
        if lite:
            params["sort"] = "CITED desc"
        res = get_json(EPMC + "search?" + urllib.parse.urlencode(params))["resultList"]["result"]
        if not res:
            print(f"NO RESULT: {q}")
        if lite:
            print(f"=== {q}")
            for r in res:
                print(f"- [{r.get('citedByCount', 0)} cites] {r.get('authorString', '')[:60]} | {r.get('title')} | "
                      f"{r.get('journalTitle')} {r.get('pubYear')} | PMID {r.get('pmid')} doi {r.get('doi')}")
        else:
            for r in res[:n]:
                show(r)


def openalex(dois):
    for d in dois:
        w = get_json(f"https://api.openalex.org/works/doi:{d}")
        oa = w.get("open_access", {})
        locs = [(l.get("source") or {}).get("display_name") for l in w.get("locations", []) if l.get("is_oa")]
        print(f"{d}: {oa.get('oa_status')} | {oa.get('oa_url')} | {locs} | {w.get('title')}")


def fulltext(pmcid, out):
    req = urllib.request.Request(EPMC + f"{pmcid}/fullTextXML", headers={"User-Agent": "just-zone-2-book-research"})
    x = urllib.request.urlopen(req, timeout=60).read().decode("utf-8")
    x = re.sub(r"<xref[^>]*>.*?</xref>", "", x, flags=re.S)
    t = re.sub(r"<title>(.*?)</title>", r"\n\n## \1\n", x, flags=re.S)
    t = re.sub(r"</p>|</tr>", "\n", t)
    t = re.sub(r"</td>|</th>", " | ", t)
    t = html.unescape(re.sub(r"<[^>]+>", "", t))
    t = re.sub(r"\s*\n\s*±\s*\n\s*", " ± ", t)
    t = re.sub(r"\n\s*\n+", "\n\n", t)
    open(out, "w").write(t)
    print(f"{pmcid}: {len(t)} characters -> {out}")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "search":
        search(args)
    elif cmd == "list":
        search(args[1:], n=int(args[0]), lite=True)
    elif cmd == "pmid":
        search([f"EXT_ID:{p} AND SRC:MED" for p in args])
    elif cmd == "oa":
        openalex(args)
    elif cmd == "fulltext":
        fulltext(args[0], args[1])
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
