#!/usr/bin/env python3
"""Proposed rewrites in the drafts, marked {~~wording now~>proposed wording~~}.

  python3 tools/rewrites.py propose FILE.json   mark each {"chapter": folder, "old": ..., "new": ...} in its draft
  python3 tools/rewrites.py list                count the rewrites waiting in each chapter
  python3 tools/rewrites.py accept [WHO ...]    keep the proposed wording (no WHO: every rewrite in the book)
  python3 tools/rewrites.py reject WHO ...      keep the wording as it was

WHO is a chapter (its folder, or its number, with "intro" for the Introduction) for all of its rewrites, or
CHAPTER.N for one, N being the number the review page shows beside it (counted from 1 within each chapter).
Accept or reject the single ones first: numbers count the rewrites still waiting, so they shift after each run.
The review page shows the old wording struck through with the new beside it; the print proof and check.py
read the new wording.
"""
import glob
import json
import os
import re
import sys

BOOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARK = re.compile(r"\{~~(.*?)~>(.*?)~~\}")


def drafts():
    """{folder: path}, plus {chapter number or 'intro': folder} read from each draft's heading."""
    paths, names = {}, {}
    for p in sorted(glob.glob(os.path.join(BOOK, "chapters", "*", "draft.md"))):
        folder = os.path.basename(os.path.dirname(p))
        paths[folder] = p
        m = re.match(r"# (?:Chapter (\d+)|(Introduction))", open(p, encoding="utf-8").readline())
        if m:
            names[m.group(1) or "intro"] = folder
    return paths, names


def propose(json_path):
    paths, _ = drafts()
    done, failed = 0, []
    for item in json.load(open(json_path, encoding="utf-8")):
        path = paths.get(item["chapter"])
        text = open(path, encoding="utf-8").read() if path else ""
        old, new = item["old"], item["new"]
        at = text.find(old)
        inside = any(m.start() < at + len(old) and at < m.end() for m in MARK.finditer(text))
        if not path or text.count(old) != 1 or inside or old == new:
            why = "no such chapter" if not path else f"found {text.count(old)} times" if text.count(old) != 1 else \
                "overlaps another rewrite" if inside else "no change"
            failed.append(f"{item['chapter']}: {why}: {old[:70]}")
            continue
        open(path, "w", encoding="utf-8").write(text.replace(old, "{~~" + old + "~>" + new + "~~}"))
        done += 1
    print(f"{done} rewrites marked")
    for f in failed:
        print("NOT MARKED", f)


def resolve(keep, who):
    paths, names = drafts()
    chosen = {}  # folder -> set of numbers, or None for all
    for w in who or paths:
        ch, _, n = w.partition(".")
        folder = names.get(ch, ch)
        if folder not in paths:
            sys.exit(f"no chapter {ch}")
        if n:
            if chosen.get(folder, set()) is not None:
                chosen.setdefault(folder, set()).add(int(n))
        else:
            chosen[folder] = None
    total = 0
    for folder, nums in chosen.items():
        text = open(paths[folder], encoding="utf-8").read()
        count = [0]

        def one(m):
            count[0] += 1
            if nums is None or count[0] in nums:
                return m.group(2 if keep == "new" else 1)
            return m.group(0)
        out = MARK.sub(one, text)
        changed = sum(1 for _ in MARK.finditer(text)) - sum(1 for _ in MARK.finditer(out))
        open(paths[folder], "w", encoding="utf-8").write(out)
        total += changed
    print(f"{total} rewrites {'accepted' if keep == 'new' else 'rejected'}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "propose" and len(args) == 1:
        propose(args[0])
    elif cmd == "list":
        paths, _ = drafts()
        for folder, p in paths.items():
            k = len(MARK.findall(open(p, encoding="utf-8").read()))
            if k:
                print(f"{k:4} {folder}")
    elif cmd == "accept":
        resolve("new", args)
    elif cmd == "reject" and args:
        resolve("old", args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
