#!/usr/bin/env python3
"""Style and sourcing checks for book chapters.

Usage:  python3 book/tools/check.py book/chapters/durability/draft.md [more.md ...]

Flags the mechanical habits listed in book/style.md (AI-ish words, phrases and
sentence patterns, dash overuse, flat sentence rhythm, bullet lists in prose)
and sourcing problems (numbers with no citation nearby, citation keys missing
from sources.yaml or not yet checked). It can't judge quality; it catches tics.

Exit code 0 if nothing was flagged, 1 otherwise.
"""
import os
import re
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BOOK = os.path.dirname(HERE)

WORDS = """delve delves delving tapestry realm crucial pivotal paramount nuanced intricate multifaceted
foster fosters fostering leverage leverages leveraging unlock unlocks unlocking harness harnesses harnessing
embark embarks embarking testament game-changer game-changing revolutionary groundbreaking cutting-edge seamless
seamlessly holistic synergy elevate elevates elevating empower empowers empowering supercharge unleash unleashes
myriad plethora vibrant bustling meticulous meticulously invaluable transformative ever-evolving underscore
underscores underscoring showcase showcases showcasing boasts nestled beacon cornerstone linchpin""".split()

# Words that are only wrong when used figuratively: flagged as "check".
FIGURATIVE = ["landscape", "journey", "navigate", "navigating", "robust", "dive"]

PHRASES = [
    "the honest answer", "the honest reading", "the honest truth", "honestly", "to be honest",
    "in all honesty", "let's be honest", "frankly",
    "it's worth noting", "it is worth noting", "worth noting", "it is important to note", "it's important to note",
    "interestingly", "importantly", "notably", "crucially", "when it comes to", "at the end of the day",
    "in today's world", "in the world of", "the reality is", "the truth is", "here's the thing",
    "let's dive in", "let's explore", "in conclusion", "ultimately", "in summary", "all in all",
    "needless to say", "it goes without saying", "a deep dive", "the key takeaway", "food for thought",
    "double-edged sword", "the elephant in the room", "stands as a", "serves as a reminder",
    "treasure trove", "dive deep", "studies show", "research shows", "research suggests", "experts agree",
    "in this chapter we", "as we'll see", "as we will see", "may potentially", "could potentially",
]

PATTERNS = [
    (r"\bnot (?:just|only|merely|simply)\b[^.?!]{1,80}?\bbut\b", "'not just X, but Y'"),
    (r"\b(?:it'?s|it is|this is|that'?s|that is) not\b[^.?!]{1,60}?[,;:—–-]\s*(?:it'?s|it is|this is|that'?s)\b", "'it's not X, it's Y'"),
    (r"\b(?:isn'?t|wasn'?t|aren'?t)\b[^.?!]{1,50}?[,;—–]\s*(?:it'?s|they'?re|it was)\b", "'isn't X; it's Y'"),
    (r"(?:^|[.!]\s+)(?:The|Here'?s the|And the)\s+(?:answer|truth|catch|kicker|twist|result|secret|problem)\?", "colon/question reveal"),
    (r"\?\s+(?:Yes|No|Not quite|Absolutely|Exactly)[.!,]", "rhetorical question answered"),
]

UNIT_NUM = re.compile(
    r"(?<![\w@])\d+(?:[.,]\d+)?\s?(?:%|W\b|W/kg|watts?\b|bpm|beats|mmol|mL|ml\b|L/min|kg\b|kJ\b|min\b|minutes?|"
    r"s\b|seconds?|h\b|hours?|weeks?|days?|km\b|percentage points?|participants|cyclists|riders|athletes|men|women)",
    re.I)
CITE = re.compile(r"\[@[^\]]+\]")
KEY = re.compile(r"@([A-Za-z0-9_:-]+)")


def load_sources():
    path = os.path.join(BOOK, "sources.yaml")
    sources = {}
    if not os.path.exists(path):
        return sources
    key = None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\s*-\s*key:\s*(\S+)", line)
        if m:
            key = m.group(1)
            sources[key] = "candidate"
            continue
        m = re.match(r"\s*status:\s*(\S+)", line)
        if m and key:
            sources[key] = m.group(1)
    return sources


def strip_markup(text):
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    return text


def paragraphs(text):
    """Yield (line_no, kind, text) for each block. kind: heading, quote, list, para."""
    lines = text.split("\n")
    block, start = [], 0
    for i, line in enumerate(lines + [""], 1):
        if line.strip() == "":
            if block:
                first = block[0].lstrip()
                kind = ("heading" if first.startswith("#") else
                        "quote" if first.startswith(">") else
                        "table" if first.startswith("|") else
                        "list" if re.match(r"([-*+]|\d+\.)\s", first) else "para")
                yield start, kind, "\n".join(block)
            block = []
        else:
            if not block:
                start = i
            block.append(line)


def sentences(text):
    text = re.sub(r"\[@[^\]]+\]|\{grade [ABC]\}", "", text)
    parts = re.split(r"(?<=[.!?])\s+(?=[A-Z\"'(])", text.strip())
    return [p for p in parts if len(p.split()) > 0]


def line_of(text, idx, base):
    return base + text.count("\n", 0, idx)


def check(path, sources):
    raw = open(path, encoding="utf-8").read()
    text = strip_markup(raw)
    flags = []
    words_total = len(re.findall(r"\b\w+\b", text))

    # Vocabulary and phrases (everywhere except George's quotes? No: check everything)
    low = text.lower()
    for w in WORDS:
        for m in re.finditer(r"\b" + re.escape(w) + r"\b", low):
            flags.append((low.count("\n", 0, m.start()) + 1, "word", f"'{w}'"))
    for w in FIGURATIVE:
        for m in re.finditer(r"\b" + re.escape(w) + r"\b", low):
            flags.append((low.count("\n", 0, m.start()) + 1, "check", f"'{w}': only if literal"))
    for p in PHRASES:
        for m in re.finditer(r"\b" + re.escape(p) + r"\b", low):
            flags.append((low.count("\n", 0, m.start()) + 1, "phrase", f"'{p}'"))

    sentence_lengths = []
    for start, kind, block in paragraphs(text):
        if kind in ("heading", "table"):
            continue
        for rx, label in PATTERNS:
            for m in re.finditer(rx, block, flags=re.I | re.M):
                flags.append((line_of(block, m.start(), start), "pattern", label))
        if kind == "list":
            flags.append((start, "structure", "bullet/numbered list: only for real lists (sessions, steps, tables)"))
        if kind == "para":
            sents = sentences(block)
            lens = [len(s.split()) for s in sents]
            sentence_lengths += lens
            if len(lens) >= 4 and statistics.pstdev(lens) < 4:
                flags.append((start, "rhythm", f"sentence lengths all similar ({lens})"))
            if sents and sents[0].rstrip().endswith("?") and start > 1:
                flags.append((start, "pattern", "paragraph opens with a question"))
            # Numbers need a citation in the same sentence or paragraph.
            if not CITE.search(block):
                for s in sents:
                    if UNIT_NUM.search(s):
                        flags.append((start, "source", f"number with no citation in paragraph: \"{s[:70]}…\""))
                        break

    # Dashes: more than ~1 per 500 words is a habit.
    dashes = len(re.findall(r"—|\s–\s|\s-\s", text))
    if words_total and dashes > max(2, words_total / 500):
        flags.append((0, "dashes", f"{dashes} dashes in {words_total} words (aim for under {max(2, words_total // 500)})"))

    # Citation keys must exist; specific numbers want full-text-checked sources.
    for m in KEY.finditer(text):
        k = m.group(1)
        ln = text.count("\n", 0, m.start()) + 1
        if k not in sources:
            flags.append((ln, "citation", f"@{k} not in sources.yaml"))
        elif sources[k] == "candidate":  # 'exists', 'abstract' and 'fulltext' are fine to cite
            flags.append((ln, "citation", f"@{k} is only a candidate: read it before citing"))

    # Summary
    flags.sort()
    name = os.path.relpath(path)
    print(f"\n{name}: {words_total} words, {len(flags)} flags")
    if sentence_lengths:
        print(f"  sentences: mean {statistics.mean(sentence_lengths):.1f} words, "
              f"spread {statistics.pstdev(sentence_lengths):.1f} (low spread reads as monotonous; aim for 7+)")
    for ln, kind, msg in flags:
        where = f"line {ln}" if ln else "whole file"
        print(f"  {where:>10}  {kind:<9} {msg}")
    return len(flags)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sources = load_sources()
    total = sum(check(p, sources) for p in sys.argv[1:])
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
