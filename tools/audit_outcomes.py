#!/usr/bin/env python3
"""audit_outcomes.py — declared outcomes/skills vs actual activity types.

Structural audit (Phase 5.1 groundwork, 2026-09-26): compares the modality
skills DECLARED on lesson activities against the activity types (and media)
that actually exercise those modalities, across all five bundled packs
(Condisco/Content/packs/*.json). Editorial quality is NOT this tool's job —
that is tools/audit_editorial.swift. This tool answers one question per
lesson: does an activity type that actually trains the declared modality
exist in the lesson?

Where skills live: `skills` is `[Skill]` on activities only (never on
lessons/steps/stimuli — verified across all five packs). The Skill enum
(Condisco/Models/CoursePack.swift:99-100) is exactly:
    reading, listening, writing, speaking, grammar, vocabulary
The four modality skills are checked; grammar/vocabulary are content tags and
are reported only as census. Any token outside that set is a WARNING (never a
failure), in case a pack introduces a new skill token.

Evidence rules (a "skill tag on a choice question is NOT speaking evidence"
— the plan's explicit rule; choices/matching are reception, not production):

  listening  a lesson contains an audio-backed step: an activity whose
             stimulus carries `mediaId` (kind "audio" stimulus), OR an
             activity with `modelAudioId` (self-compare model reference).
             The referenced media id must be DECLARED in the pack's `media`
             array or allowlisted in tools/device-speech-media.txt (device
             speech still plays audio at lesson time — the on-device course
             voice reads the transcript; see docs/audio-provenance/index.md).
  speaking   a lesson contains at least one `self-compare` activity OR a
             spoken `open-task` activity (self-assessed production: the
             learner speaks a 60-90s response and ticks the rubric — plan
             6.2). No other activity kind is production. A "speaking" tag
             on a selection/text/dialogue-choice activity without a
             self-compare or spoken open-task anywhere in the lesson is
             UNBACKED.
  writing    a lesson contains at least one `text` or `cloze` activity
             (constrained written production) OR a written `open-task`
             activity (self-assessed written production — plan 6.2).
             Selection/matching/ordering/dialogue-choice are receptive,
             not written production.
  reading    a lesson contains at least one text-bearing step: an activity
             with `prompt` or `body`, or a stimulus with `body`/`pairs`/
             `translation` (stories, mission transcripts, example pairs,
             information bodies, prompt text).

The five standalone Listen tracks (Condisco/Content/listen-tracks/*.json)
are separate bundled-audio content, not lesson steps; they are out of scope
here by design and never count as lesson listening evidence.

Exit codes:
  0  every declared modality claim is backed by an exercising activity type
  1  at least one unbacked modality claim (the findings are listed)
  2  usage/schema error (unreadable pack, missing top-level arrays,
     malformed `skills`, or bad command line)

Current state (2026-09-26, phase 6.2): with spoken open tasks counted as
self-assessed production, every declared modality claim across all five
packs is backed (exit 0). The tool is a manual diagnostic; it is
intentionally NOT wired into tools/preflight.sh (that is Phase 5.4).

Usage:
  python3 tools/audit_outcomes.py [--root DIR] [--packs DIR] [--allowlist FILE]
    --root DIR       repo root; default = parent of the tools/ directory
                     (packs: <root>/Condisco/Content/packs,
                      allowlist: <root>/tools/device-speech-media.txt)
    --packs DIR      directory holding the five pack JSONs (override)
    --allowlist FILE device-speech allowlist file (override; a missing file
                     is fine — declared media still counts as audio-backed)

Output is deterministic: pack order (fr/it/de/pt/es), lesson ids sorted,
findings sorted. Suitable for CI diffing.
"""

import argparse
import json
import os
import sys
from collections import Counter

PACK_ORDER = ["french", "italian", "german", "portuguese", "spanish"]
PACK_DISPLAY = {
    "french": "fr-foundations",
    "italian": "it-foundations",
    "german": "de-foundations",
    "portuguese": "pt-foundations",
    "spanish": "es-foundations",
}

# Empirically derived from the five packs + the Swift Skill enum
# (Condisco/Models/CoursePack.swift:99-100). Anything else is a warning.
KNOWN_SKILLS = {"reading", "listening", "writing", "speaking", "grammar", "vocabulary"}
MODALITY_SKILLS = {"reading", "listening", "writing", "speaking"}

WRITING_KINDS = {"text", "cloze"}
PRODUCTION_KINDS = {"self-compare"}
# Phase 6.2 open tasks: a self-assessed production activity in its own
# right — the learner produces a response (60-90s spoken, or a few written
# sentences) and ticks the rubric, the same evidence contract as
# self-compare. The declared `mode` picks the modality it backs:
# spoken -> speaking, written -> writing. Receptive kinds (selection,
# dialogue-choice, …) and the 5.1.4 repairs are untouched.
OPEN_TASK_SPOKEN_MODES = {"spoken"}
OPEN_TASK_WRITTEN_MODES = {"written"}


class SchemaError(Exception):
    """Usage/schema problem -> exit 2."""


def load_pack(path):
    with open(path, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as exc:
            raise SchemaError(f"{path}: invalid JSON ({exc})") from exc
    for key in ("lessons", "activities", "stimuli", "media", "units"):
        if key not in data:
            raise SchemaError(f"{path}: missing top-level key '{key}'")
    return data


def read_allowlist(path):
    """Return the set of declared media ids listed as intentional device speech."""
    if not path or not os.path.isfile(path):
        return set()
    ids = set()
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.split("#", 1)[0].strip()
            if line:
                ids.add(line.split()[0])
    return ids


def lesson_activities(lesson, activities):
    """Resolve lesson steps to activity dicts; missing refs surface as warnings."""
    refs = [step.get("activityId") for step in lesson.get("steps", [])]
    missing = [r for r in refs if r not in activities]
    found = [activities[r] for r in refs if r in activities]
    return found, missing


def activity_skills(activity):
    """Return (skills, ok). ok=False when the skills value is malformed."""
    skills = activity.get("skills")
    if skills is None:
        return set(), True
    if not isinstance(skills, list) or not all(isinstance(s, str) for s in skills):
        return set(), False
    return set(skills), True


def is_text_bearing(activity, stimuli):
    """A step the learner reads: activity prompt/body, or a text stimulus."""
    if activity.get("prompt") or activity.get("body"):
        return True
    sid = activity.get("stimulusId")
    if not sid:
        return False
    stim = stimuli.get(sid)
    if not stim:
        return False
    return bool(stim.get("body") or stim.get("pairs") or stim.get("translation"))


def audio_refs(activity, stimuli, media_ids):
    """Media ids this activity actually plays (stimulus media + model audio)."""
    refs = set()
    sid = activity.get("stimulusId")
    if sid and sid in stimuli and stimuli[sid].get("mediaId"):
        refs.add(stimuli[sid]["mediaId"])
    if activity.get("modelAudioId"):
        refs.add(activity["modelAudioId"])
    return refs


def audit_pack(data, allowlist):
    """Audit one pack; return (findings, warnings, census)."""
    lessons = data["lessons"]
    activities = {a["id"]: a for a in data["activities"]}
    stimuli = {s["id"]: s for s in data["stimuli"]}
    media_ids = {m["id"] for m in data["media"]}
    units = {u["id"]: u for u in data["units"]}

    findings = []
    warnings = []
    census = Counter()  # skill token census across the pack

    # Per-lesson audit, deterministic order.
    for lesson in sorted(lessons, key=lambda l: l["id"]):
        lid = lesson["id"]
        unit_id = lesson.get("unitId", "?")
        unit_obj = units.get(unit_id, {})
        family = lesson.get("family", "?")

        acts, missing_refs = lesson_activities(lesson, activities)
        for ref in missing_refs:
            warnings.append(
                f"  {lid}: step references missing activity '{ref}' (data anomaly, not a modality claim)"
            )
        if not acts:
            warnings.append(f"  {lid}: no activities to audit")
            continue

        # Declared modality skills (union over the lesson's activities).
        declared = Counter()
        claiming = {}  # skill -> [(activityId, kind)]
        for act in acts:
            skills, ok = activity_skills(act)
            if not ok:
                warnings.append(
                    f"  {lid}: malformed 'skills' value on '{act.get('id')}' "
                    f"(expected list of strings) — treated as no skills"
                )
                continue
            census.update(skills)
            for skill in skills:
                declared[skill] += 1
                claiming.setdefault(skill, []).append((act["id"], act.get("kind")))
                if skill not in KNOWN_SKILLS:
                    warnings.append(
                        f"  {lid}: unknown skill token '{skill}' on '{act['id']}'"
                    )

        # Actual evidence in the lesson.
        has_audio = any(
            audio_refs(a, stimuli, media_ids) & (media_ids | allowlist) for a in acts
        )
        dangling_audio = [
            r
            for a in acts
            for r in audio_refs(a, stimuli, media_ids)
            if r not in (media_ids | allowlist)
        ]
        for ref in sorted(set(dangling_audio)):
            warnings.append(
                f"  {lid}: audio reference '{ref}' is neither declared in the pack "
                f"nor allowlisted (still counted as no listening evidence)"
            )
        has_production = any(
            a.get("kind") in PRODUCTION_KINDS
            or (a.get("kind") == "open-task"
                and a.get("mode") in OPEN_TASK_SPOKEN_MODES)
            for a in acts
        )
        has_writing = any(
            a.get("kind") in WRITING_KINDS
            or (a.get("kind") == "open-task"
                and a.get("mode") in OPEN_TASK_WRITTEN_MODES)
            for a in acts
        )
        has_reading = any(is_text_bearing(a, stimuli) for a in acts)

        # Check each declared modality claim.
        for skill in MODALITY_SKILLS:
            if not declared.get(skill):
                continue
            if skill == "listening" and not has_audio:
                findings.append(
                    (lid, unit_id, family, "listening",
                     claiming[skill], "audio-backed step (stimulus mediaId or modelAudioId)")
                )
            elif skill == "speaking" and not has_production:
                findings.append(
                    (lid, unit_id, family, "speaking",
                     claiming[skill], "self-compare or spoken open-task activity")
                )
            elif skill == "writing" and not has_writing:
                findings.append(
                    (lid, unit_id, family, "writing",
                     claiming[skill], "text/cloze or written open-task activity")
                )
            elif skill == "reading" and not has_reading:
                findings.append(
                    (lid, unit_id, family, "reading",
                     claiming[skill], "text-bearing step")
                )

    return findings, warnings, census


def fmt_claiming(acts):
    kinds = Counter(k for _, k in acts)
    ids = ", ".join(a for a, _ in acts)
    return f"{len(acts)} activity(ies) {ids} [{', '.join(f'{k}×{n}' for k, n in sorted(kinds.items()))}]"


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="audit_outcomes.py",
        description=(
            "Structural audit: declared modality skills vs actual activity types "
            "across the five bundled packs. Exit 0 = all declared claims backed, "
            "1 = unbacked modality claims listed, 2 = usage/schema error."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Evidence rules: listening = audio-backed step (stimulus 'mediaId' or "
            "'modelAudioId', declared or allowlisted); speaking = self-compare or spoken "
            "open-task activity; writing = text/cloze or written open-task activity; "
            "reading = text-bearing step. A skill tag on a choice question is NOT "
            "speaking evidence. Standalone Listen tracks are out of scope (separate "
            "bundled-audio content, not lesson steps)."
        ),
    )
    parser.add_argument("--root", metavar="DIR", default=None,
                        help="repo root (default: parent of this script's directory)")
    parser.add_argument("--packs", metavar="DIR", default=None,
                        help="directory with the five pack JSONs")
    parser.add_argument("--allowlist", metavar="FILE", default=None,
                        help="device-speech allowlist file (tools/device-speech-media.txt)")
    args = parser.parse_args(argv)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    root = args.root or os.path.dirname(script_dir)
    packs_dir = args.packs or os.path.join(root, "Condisco", "Content", "packs")
    allowlist_path = args.allowlist or os.path.join(root, "tools", "device-speech-media.txt")

    if not os.path.isdir(packs_dir):
        print(f"audit_outcomes: ERROR packs directory not found: {packs_dir}", file=sys.stderr)
        return 2

    allowlist = read_allowlist(allowlist_path)

    print("OUTCOMES AUDIT — declared modality skills vs actual activity types")
    print(f"packs:     {packs_dir}")
    print(f"allowlist: {allowlist_path} ({len(allowlist)} id(s) read)"
          if os.path.isfile(allowlist_path) else f"allowlist: {allowlist_path} (absent — declared media only)")
    print()

    pack_results = []
    any_findings = False
    all_warnings = []
    all_census = Counter()

    for language in PACK_ORDER:
        path = os.path.join(packs_dir, f"{language}.json")
        if not os.path.isfile(path):
            print(f"audit_outcomes: ERROR pack not found: {path}", file=sys.stderr)
            return 2
        try:
            data = load_pack(path)
        except SchemaError as exc:
            print(f"audit_outcomes: ERROR {exc}", file=sys.stderr)
            return 2
        findings, warnings, census = audit_pack(data, allowlist)
        pack_results.append((language, data, findings, warnings, census))
        any_findings = any_findings or bool(findings)
        all_warnings.extend(warnings)
        all_census.update(census)

    # ---- Summary ---------------------------------------------------------
    print(f"{'Pack':<16}{'Lessons':>8}{'Declaring':>10}{'Audio-back':>12}"
          f"{'Self-cmp':>9}{'Write-kinds':>12}{'Unbacked':>10}")
    print("-" * 77)
    for language, data, findings, warnings, census in pack_results:
        lessons = data["lessons"]
        declaring = 0
        audio_backed = 0
        self_compare = 0
        write_kinds = 0
        for lesson in lessons:
            acts, _ = lesson_activities(lesson, {a["id"]: a for a in data["activities"]})
            skills = set()
            for a in acts:
                s, ok = activity_skills(a)
                if ok:
                    skills |= s
                if a.get("kind") in PRODUCTION_KINDS:
                    self_compare += 1
                if a.get("kind") in WRITING_KINDS:
                    write_kinds += 1
            if skills & MODALITY_SKILLS:
                declaring += 1
            stimuli = {s["id"]: s for s in data["stimuli"]}
            media_ids = {m["id"] for m in data["media"]}
            if any(audio_refs(a, stimuli, media_ids) & (media_ids | allowlist) for a in acts):
                audio_backed += 1
        print(f"{PACK_DISPLAY[language]:<16}{len(lessons):>8}{declaring:>10}"
              f"{audio_backed:>12}{self_compare:>9}{write_kinds:>12}{len(findings):>10}")
    print()

    # ---- Findings ---------------------------------------------------------
    if any_findings:
        print(f"FINDINGS — unbacked modality claims ({sum(len(f) for _, _, f, _, _ in pack_results)} total) -> exit 1")
        for language, data, findings, warnings, census in pack_results:
            if not findings:
                continue
            print(f"\n{PACK_DISPLAY[language]}:")
            for lid, unit_id, family, skill, claiming, needed in sorted(findings):
                print(f"  {lid} ({unit_id}, {family}): '{skill}' declared by "
                      f"{fmt_claiming(claiming)} but no {needed} in the lesson")
        print()
    else:
        print("FINDINGS — none; every declared modality claim is backed -> exit 0")
        print()

    # ---- Warnings ----------------------------------------------------------
    if all_warnings:
        print("WARNINGS (not failures):")
        for w in sorted(set(all_warnings)):
            print(w)
        print()
    else:
        print("WARNINGS — none.")
        print()

    # ---- Informational census ----------------------------------------------
    print("SKILL-TOKEN CENSUS (informational; grammar/vocabulary are content "
          "tags, reading/listening/writing/speaking are the checked modalities):")
    for token in ("reading", "listening", "writing", "speaking", "grammar", "vocabulary"):
        print(f"  {token:<12}{all_census.get(token, 0):>6}")
    unknown = sorted(t for t in all_census if t not in KNOWN_SKILLS)
    if unknown:
        print(f"  unknown tokens (warned above): {', '.join(unknown)}")
    print()
    print("Note: standalone Listen tracks (Condisco/Content/listen-tracks/) are separate")
    print("bundled-audio content and are intentionally out of scope for this audit.")

    return 1 if any_findings else 0


if __name__ == "__main__":
    sys.exit(main())