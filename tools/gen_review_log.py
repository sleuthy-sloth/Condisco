#!/usr/bin/env python3
"""Seed / refresh docs/reviews/review-log.jsonl from the five packs.

One JSON object per lesson (255 today), the initial state of the review
tracker specified in docs/native-review-kit.md:

    disposition: "unreviewed", reviewMethod: null, empty sourcesChecked /
    unresolvedQuestions / notes.

Re-runnable without losing review work: the script reads the existing
review-log.jsonl (when present), preserves every row whose `disposition` is
no longer "unreviewed" VERBATIM, and re-derives only the unreviewed rows from
the packs. The design contract is append/update-by-lessonId: editors edit the
JSONL directly (fill in reviewer / date / reviewMethod / disposition / ...),
never this generator. Rows are keyed by `lessonId` (globally unique across
the five packs).

Output is deterministic: fixed pack order (french, italian, german,
portuguese, spanish) then lesson id ascending, keys sorted.

Usage: python3 tools/gen_review_log.py
"""
import json
import os
import sys

PACKS = ["french", "italian", "german", "portuguese", "spanish"]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKS_DIR = os.path.join(ROOT, "Condisco", "Content", "packs")
OUT = os.path.join(ROOT, "docs", "reviews", "review-log.jsonl")

REVIEWED = {"pass", "pass-with-notes", "needs-work", "reject"}


def unreviewed_record(pack, lesson):
    return {
        "date": None,
        "packId": pack["id"],
        "packVersion": pack["version"],
        "unitId": lesson["unitId"],
        "lessonId": lesson["id"],
        "reviewMethod": None,
        "modelOrTool": None,
        "reviewer": None,
        "variant": None,
        "disposition": "unreviewed",
        "sourcesChecked": [],
        "unresolvedQuestions": [],
        "notes": [],
    }


def main():
    existing = {}
    if os.path.exists(OUT):
        with open(OUT, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                rec = json.loads(line)
                existing[rec["lessonId"]] = rec

    lines = []
    for pack_name in PACKS:
        with open(os.path.join(PACKS_DIR, pack_name + ".json"), encoding="utf-8") as fh:
            pack = json.load(fh)
        for lesson in sorted(pack["lessons"], key=lambda l: l["id"]):
            prior = existing.get(lesson["id"])
            # Preserve reviewed / partially recorded rows verbatim; only
            # unseen or still-unreviewed lessons are re-derived.
            if prior is not None and prior.get("disposition") in REVIEWED:
                lines.append(json.dumps(prior, ensure_ascii=False, sort_keys=True))
            else:
                lines.append(
                    json.dumps(
                        unreviewed_record(pack, lesson),
                        ensure_ascii=False,
                        sort_keys=True,
                    )
                )

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"wrote {len(lines)} lesson records to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())