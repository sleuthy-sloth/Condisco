#!/usr/bin/env python3
"""
Render pronunciation audio for the five café opener missions and wire it
into the course packs.

For each café mission (fr/it/de/pt/es), this script:
  1. Reads the mission's step-1 example pairs from the pack JSON.
  2. Renders each pair's target phrase with macOS `say` using a native
     voice for that language, converted to 64 kbps AAC (.m4a) with
     `afconvert` -> Content/audio/cafe/.
  3. Appends `audio` media entries (with real sha256 hashes) to the pack
     and sets `mediaId` on each example pair.

The Swift side plays per-pair audio through a speaker button on example
rows (ConceptExample.mediaId -> MediaItem -> MediaResolver).

Usage:
    python3 tools/render_cafe_audio.py [--stub] [--root DIR]

    --stub   Write placeholder audio files instead of calling `say`
             (for testing the pack-patching logic on non-macOS machines).
    --root   Project root containing Condisco/ (default: parent of tools/).

Voice selection per language (override with CONDISCO_VOICE_FR etc.):
    fr -> Amélie, Thomas (fr-FR)      it -> Alice, Luca (it-IT)
    de -> Anna (de-DE)                pt -> Joana (pt-PT)
    es -> Mónica, Jorge (es-ES)

Idempotent: pairs that already have a mediaId with an existing media
entry and audio file on disk are skipped.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------

MISSIONS = [
    # (pack file, lesson id, locale, preferred voices, env override name)
    ("french.json",     "fr-cafe-mission", "fr-FR", ["Amélie", "Thomas"],        "CONDISCO_VOICE_FR"),
    ("italian.json",    "it-cafe-mission", "it-IT", ["Alice", "Luca"],           "CONDISCO_VOICE_IT"),
    ("german.json",     "de-cafe-mission", "de-DE", ["Anna"],                    "CONDISCO_VOICE_DE"),
    ("portuguese.json", "pt-cafe-mission", "pt-PT", ["Joana"],                   "CONDISCO_VOICE_PT"),
    ("spanish.json",    "es-cafe-mission", "es-ES", ["Mónica", "Jorge", "Paulina", "Diego"], "CONDISCO_VOICE_ES"),
]

AUDIO_SUBDIR = os.path.join("audio", "cafe")   # under Condisco/Content/
SPEAK_RATE = 160                                # wpm; a touch slower than default for A1 learners
AAC_BITRATE = 64000

DUMP_KWARGS = {"indent": 2, "ensure_ascii": False}


# --------------------------------------------------------------------------
# Voices
# --------------------------------------------------------------------------

def list_voices():
    """Parse `say -v '?'` into [(name, locale)]."""
    out = subprocess.run(["say", "-v", "?"], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError("`say -v '?'` failed; is macOS speech available?")
    voices = []
    for line in out.stdout.splitlines():
        parts = re.split(r"\s{2,}", line.strip())
        if len(parts) >= 2:
            voices.append((parts[0], parts[1]))
    return voices


def pick_voice(locale, preferred, env_name):
    override = os.environ.get(env_name)
    voices = list_voices()
    by_name = {name: loc for name, loc in voices}
    if override:
        if override not in by_name:
            raise RuntimeError(
                f"{env_name}={override!r} is not an installed voice.\n"
                f"Installed voices:\n" + "\n".join(f"  {n}  ({loc})" for n, loc in voices))
        return override, by_name[override]
    for name in preferred:
        if name in by_name:
            return name, by_name[name]
    lang = locale.split("-")[0].lower()
    for name, loc in voices:
        if loc.lower().startswith(lang):
            print(f"  note: preferred voices missing, falling back to {name} ({loc})")
            return name, loc
    raise RuntimeError(
        f"No voice installed for locale {locale}.\n"
        f"Install one in System Settings > Accessibility > Spoken Content > System voice,\n"
        f"or set {env_name} to an installed voice name.\n"
        f"Installed voices:\n" + "\n".join(f"  {n}  ({loc})" for n, loc in voices))


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

def render_phrase(voice, text, dest_path, stub=False):
    """Render `text` with `say` -> AAC .m4a at `dest_path`."""
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    if stub:
        with open(dest_path, "wb") as f:
            f.write(b"STUB-M4A-PLACEHOLDER:" + text.encode("utf-8") * 4)
        return
    tmp = dest_path + ".tmp.aiff"
    try:
        subprocess.run(
            ["say", "-v", voice, "-r", str(SPEAK_RATE), "-o", tmp, text],
            check=True, capture_output=True, text=True)
        subprocess.run(
            ["afconvert", "-f", "m4af", "-d", "aac", "-b", str(AAC_BITRATE),
             tmp, dest_path],
            check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            f"audio render failed for {dest_path!r}:\n{e.stderr}") from e
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


# --------------------------------------------------------------------------
# Pack patching
# --------------------------------------------------------------------------

def load_pack(path):
    """Parse the pack; return (pack, raw_text). No reformatting is ever done."""
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    return json.loads(raw), raw


def _find_line_starting(raw, marker, start=0):
    """Index of the start of the line containing `marker` at/after `start`."""
    idx = raw.find(marker, start)
    if idx == -1:
        raise RuntimeError(f"anchor not found: {marker!r}")
    return raw.rfind("\n", 0, idx) + 1


def mission_stimulus_id(pack, lesson_id):
    lesson = next((l for l in pack["lessons"] if l["id"] == lesson_id), None)
    if lesson is None:
        raise RuntimeError(f"lesson {lesson_id} not found in pack")
    activities = {a["id"]: a for a in pack["activities"]}
    stimuli = {s["id"]: s for s in pack["stimuli"]}
    first_step = lesson["steps"][0]
    activity = activities[first_step["activityId"]]
    stimulus = stimuli[activity["stimulusId"]]
    if stimulus.get("kind") != "examples":
        raise RuntimeError(
            f"{lesson_id}: step-1 stimulus is {stimulus.get('kind')!r}, expected 'examples'")
    pairs = stimulus["pairs"]
    if len(pairs) != 3:
        print(f"  warning: {lesson_id} has {len(pairs)} pairs (expected 3)")
    return stimulus["id"], pairs


def insert_pair_media_ids(raw, stim_id, pairs, lesson_id):
    """Surgically add "mediaId" after each pair's "target" line.

    Scoped to the stimulus block and verified against the parsed pairs,
    so unrelated identical phrases elsewhere in the pack are untouched.
    Returns the edited text.
    """
    # Scope: from the stimulus's "id" line to the next stimulus object
    # close (4-space indented) or the stimuli array close.
    block_start = _find_line_starting(raw, f'"id": "{stim_id}"')
    m = re.search(r'\n    [}\]]', raw[block_start:])
    block_end = block_start + (m.start() if m else len(raw) - block_start)
    block = raw[block_start:block_end]

    edits = []  # (absolute insert offset, text)
    search_from = 0
    for i, pair in enumerate(pairs):
        if pair.get("mediaId"):
            continue  # already wired
        tm = re.search(r'^([ ]+)"target": ', block[search_from:], re.M)
        if not tm:
            raise RuntimeError(f"{stim_id}: could not find target line for pair {i + 1}")
        line_start = search_from + tm.start()
        line_end = block.find("\n", line_start)
        line = block[line_start:line_end]
        expected = f'{tm.group(1)}"target": {json.dumps(pair["target"], ensure_ascii=False)},'
        if line != expected:
            raise RuntimeError(
                f"{stim_id}: pair {i + 1} target mismatch:\n  file: {line!r}\n  pack: {expected!r}")
        media_id = f"{lesson_id}-audio-{i + 1}"
        indent = tm.group(1)
        edits.append((block_start + line_end,
                      f'\n{indent}"mediaId": "{media_id}",'))
        search_from = line_end
    # Apply back-to-front so offsets stay valid.
    for offset, text in reversed(edits):
        raw = raw[:offset] + text + raw[offset:]
    return raw


def _indent_block(entry, indent):
    dumped = json.dumps(entry, **DUMP_KWARGS)
    return "\n".join(indent + ln if ln.strip() else ln
                     for ln in dumped.splitlines())


def append_media_entries(raw, pack, new_entries):
    """Surgically append entries to the top-level "media" array."""
    if not new_entries:
        return raw
    media_key = _find_line_starting(raw, '"media": [')
    if not pack["media"]:
        # Empty array: insert right after the opening line.
        line_end = raw.find("\n", media_key)
        indent = "    "
        body = ",\n".join(_indent_block(e, indent) for e in new_entries)
        return raw[:line_end] + "\n" + body + raw[line_end:]
    last_id = pack["media"][-1]["id"]
    id_pos = _find_line_starting(raw, f'"id": "{last_id}"', media_key)
    # The object's closing line: first "<indent>}" + optional "," after it.
    cm = re.search(r'^([ ]+)\}(,?)$', raw[id_pos:], re.M)
    if not cm:
        raise RuntimeError(f"could not find close of last media entry ({last_id})")
    close_start = id_pos + cm.start()
    close_end = id_pos + cm.end()
    indent = cm.group(1)
    body = ",\n".join(_indent_block(e, indent) for e in new_entries)
    if cm.group(2) == ",":
        # Unusual: last entry already comma-terminated; append after it.
        return raw[:close_end] + "\n" + body + raw[close_end:]
    return raw[:close_start] + indent + "}," + "\n" + body + raw[close_end:]


def _refresh_sha(raw, media_id, new_sha):
    """Replace the sha256 of an existing media entry (partial re-render)."""
    id_pos = raw.find(f'"id": "{media_id}"')
    if id_pos == -1:
        raise RuntimeError(f"media entry not found for sha refresh: {media_id}")
    sm = re.search(r'"sha256": "[0-9a-f]{64}"', raw[id_pos:id_pos + 2000])
    if not sm:
        raise RuntimeError(f"sha256 not found after media entry {media_id}")
    start = id_pos + sm.start()
    end = id_pos + sm.end()
    return raw[:start] + f'"sha256": "{new_sha}"' + raw[end:]


def patch_pack(pack_path, lesson_id, voice, locale, content_dir, stub=False):
    pack, raw = load_pack(pack_path)
    stim_id, pairs = mission_stimulus_id(pack, lesson_id)
    media_ids = {m["id"] for m in pack["media"]}
    audio_dir = os.path.join(content_dir, AUDIO_SUBDIR)
    new_entries = []
    rendered = []

    for i, pair in enumerate(pairs):
        media_id = pair.get("mediaId") or f"{lesson_id}-audio-{i + 1}"
        filename = f"{lesson_id}-{i + 1}.m4a"
        rel_url = f"{AUDIO_SUBDIR}/{filename}".replace(os.sep, "/")
        dest = os.path.join(audio_dir, filename)

        if pair.get("mediaId") and media_id in media_ids and os.path.exists(dest):
            print(f"  skip pair {i + 1}: already wired ({media_id})")
            continue

        text = pair["target"]
        print(f"  render pair {i + 1}: {text!r} -> {rel_url}")
        render_phrase(voice, text, dest, stub=stub)
        digest = sha256_of(dest)

        if media_id not in media_ids:
            new_entries.append({
                "kind": "audio",
                "id": media_id,
                "url": rel_url,
                "sha256": digest,
                "attribution": f"Synthesized speech via macOS \u201c{voice}\u201d ({locale}); rendered for Condisco.",
                "transcript": text,
            })
            media_ids.add(media_id)
        else:
            # Media entry exists but the pair or file was missing (partial
            # state): keep the entry, refresh its hash to the new render.
            raw = _refresh_sha(raw, media_id, digest)
        rendered.append((media_id, rel_url, digest, os.path.getsize(dest)))

    # Surgical, byte-preserving pack edits (no full-file rewrite).
    raw = insert_pair_media_ids(raw, stim_id, pairs, lesson_id)
    raw = append_media_entries(raw, pack, new_entries)
    with open(pack_path, "w", encoding="utf-8") as f:
        f.write(raw)
    return rendered


def verify_pack(pack_path, lesson_id, content_dir):
    """Reload the written pack and check every pair mediaId resolves."""
    pack, _ = load_pack(pack_path)
    media = {m["id"]: m for m in pack["media"]}
    _, pairs = mission_stimulus_id(pack, lesson_id)
    problems = []
    for i, pair in enumerate(pairs):
        mid = pair.get("mediaId")
        if not mid:
            problems.append(f"pair {i + 1}: missing mediaId")
            continue
        m = media.get(mid)
        if m is None:
            problems.append(f"pair {i + 1}: mediaId {mid!r} has no media entry")
            continue
        if m.get("kind") != "audio":
            problems.append(f"pair {i + 1}: media {mid!r} is not audio")
        disk = os.path.join(content_dir, m.get("url", ""))
        if not os.path.exists(disk):
            problems.append(f"pair {i + 1}: audio file missing: {m.get('url')}")
        if not m.get("sha256"):
            problems.append(f"pair {i + 1}: media {mid!r} missing sha256")
    if problems:
        raise RuntimeError(f"{pack_path} verification failed:\n" + "\n".join(problems))
    print(f"  verified {len(pairs)} pairs resolve to audio on disk")


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--stub", action="store_true",
                    help="write placeholder audio (test pack patching without macOS TTS)")
    ap.add_argument("--root", default=None,
                    help="project root containing Condisco/ (default: parent of tools/)")
    args = ap.parse_args()

    root = args.root or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pack_dir = os.path.join(root, "Condisco", "Content", "packs")
    content_dir = os.path.join(root, "Condisco", "Content")
    for d in (pack_dir, content_dir):
        if not os.path.isdir(d):
            sys.exit(f"not found: {d} (pass --root pointing at the VerbaLibera checkout)")

    if not args.stub:
        for tool in ("say", "afconvert"):
            if shutil.which(tool) is None:
                sys.exit(f"required tool missing: {tool}")

    total_files = 0
    total_bytes = 0
    for pack_file, lesson_id, locale, preferred, env_name in MISSIONS:
        print(f"== {lesson_id} ==")
        if args.stub:
            voice = preferred[0]
        else:
            voice, voice_locale = pick_voice(locale, preferred, env_name)
            print(f"  voice: {voice} ({voice_locale})")
        pack_path = os.path.join(pack_dir, pack_file)
        rendered = patch_pack(pack_path, lesson_id, voice, locale, content_dir,
                              stub=args.stub)
        verify_pack(pack_path, lesson_id, content_dir)
        for media_id, url, digest, size in rendered:
            print(f"  wrote {url} ({size} bytes, sha256 {digest[:12]}…")
            total_files += 1
            total_bytes += size

    print(f"\ndone: {total_files} new audio files, {total_bytes} bytes total "
          f"({total_bytes / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
