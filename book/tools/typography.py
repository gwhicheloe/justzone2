"""Typographer's quotes for the printed book. The drafts are typed with straight quotes.

  smart_quotes("It's \"easy\", isn't it?")  ->  It’s “easy”, isn’t it?

Call it on plain text (escaped or not), before any HTML tags are added, since it would
change the quotes around attribute values too.
"""
import re

OPENS = r"(^|[\s(\[{—–/*_\"“‘-])"  # a quote after one of these opens; anywhere else it closes


def smart_quotes(t):
    t = re.sub(r"'(?=\d0s\b)", "’", t)              # ’90s
    t = re.sub(OPENS + "'", r"\1‘", t)
    t = t.replace("'", "’")                          # apostrophes and closing single quotes
    t = re.sub(OPENS + '"', r"\1“", t)
    return t.replace('"', "”")
