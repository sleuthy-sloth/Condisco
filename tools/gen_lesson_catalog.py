#!/usr/bin/env python3
"""Regenerate Condisco/DeepLink/LessonCatalog.generated.swift.

Usage:
    python3 tools/gen_lesson_catalog.py <packs-dir> <out-file>

Reads the five bundled course packs from <packs-dir> and emits a Swift
snapshot of every lesson entry (packId, lessonId, title, languageName,
unitTitle) for the Siri/Shortcuts lesson picker. The output is written
verbatim to <out-file> — it must stay byte-identical with the committed
Condisco/DeepLink/LessonCatalog.generated.swift.

Pure Python 3 stdlib (json, pathlib, sys, argparse).
"""

import argparse
import json
import re
import sys
from pathlib import Path

# Pack basenames in the order the Courses tab lists them — must match
# PackLoader.packFilenames in Condisco/Store/PackLoader.swift.
PACK_ORDER = ["french", "italian", "german", "portuguese", "spanish"]

# Pack language code -> display name; mirrors CourseLanguage.displayName
# in Condisco/Models/CoursePack.swift.
LANGUAGE_NAMES = {
    "it": "Italian",
    "fr": "French",
    "es": "Spanish",
    "pt": "Portuguese",
    "de": "German",
}

# Header is fixed text: the regenerate hint always names the canonical
# output path, regardless of the <out-file> argument given on the command
# line, so the committed file stays byte-identical. "{count}" is filled in
# from the packs actually read.
HEADER_LINES = [
    "// LessonCatalog.generated.swift",
    "//",
    "// GENERATED FILE — do not edit by hand.",
    "// Regenerate with: python3 tools/gen_lesson_catalog.py <packs-dir> \\",
    "//     Condisco/DeepLink/LessonCatalog.generated.swift",
    "//",
    "// Source: the five bundled course packs ({count} lessons).",
    "// This snapshot backs the Siri/Shortcuts lesson picker in processes",
    "// where the app bundle's Content folder is not reachable; the intent",
    "// query prefers the live packs via PackLoader when they are available.",
    "",
    "import Foundation",
    "",
    "enum GeneratedLessonCatalog {",
    "    static let entries: [LessonCatalogEntry] = [",
]


def swift_string(value: str) -> str:
    """Encode a string as a complete single-line Swift string literal.

    JSON escaping is a close superset of Swift's; the only differences are
    Python's bare \\uXXXX escapes (Swift needs \\u{XXXX}) and the \\b/\\f
    escapes, which Swift does not accept at all.
    """
    encoded = json.dumps(value, ensure_ascii=False)
    encoded = re.sub(r"\\u([0-9a-fA-F]{4})", r"\\u{\1}", encoded)
    encoded = encoded.replace("\\b", "\\u{8}").replace("\\f", "\\u{C}")
    return encoded


def load_pack(packs_dir: Path, basename: str) -> dict:
    path = packs_dir / f"{basename}.json"
    if not path.is_file():
        raise FileNotFoundError(
            f"Missing course pack: {path} (expected one of: "
            f"{', '.join(PACK_ORDER)}.json)")
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def build_entries(packs: list) -> list:
    lines: list = []
    for pack in packs:
        language_code = pack["language"]
        try:
            language_name = LANGUAGE_NAMES[language_code]
        except KeyError:
            sys.exit(f"error: pack {pack['id']} has unknown language code "
                     f"{language_code!r} (known: {sorted(LANGUAGE_NAMES)})")
        unit_titles = {unit["id"]: unit["title"] for unit in pack["units"]}
        for lesson in pack["lessons"]:
            try:
                unit_title = unit_titles[lesson["unitId"]]
            except KeyError:
                sys.exit(f"error: lesson {lesson['id']} in pack {pack['id']} "
                         f"references unknown unit {lesson['unitId']!r}")
            lines.append("        LessonCatalogEntry(")
            lines.append(
                f"            packId: {swift_string(pack['id'])},"
            )
            lines.append(
                f"            lessonId: {swift_string(lesson['id'])},"
            )
            lines.append(
                f"            title: {swift_string(lesson['title'])},"
            )
            lines.append(
                f"            languageName: {swift_string(language_name)},"
            )
            lines.append(
                f"            unitTitle: {swift_string(unit_title)}"
            )
            lines.append("        ),")
    return lines


def generate(packs_dir: Path, out_file: Path) -> None:
    packs = [load_pack(packs_dir, basename) for basename in PACK_ORDER]
    lesson_count = sum(len(pack["lessons"]) for pack in packs)
    if lesson_count == 0:
        sys.exit("error: no lessons found in any course pack")

    header = "\n".join(HEADER_LINES).replace("{count}", str(lesson_count))
    body = "\n".join(build_entries(packs))
    footer = "    ]\n}"

    out_file.write_text(header + "\n" + body + "\n" + footer + "\n",
                        encoding="utf-8")
    print(f"Wrote {lesson_count} lesson entries to {out_file}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Regenerate Condisco/DeepLink/LessonCatalog.generated.swift "
                    "from the bundled course packs.")
    parser.add_argument("packs_dir", type=Path,
                        help="directory containing french.json, italian.json, "
                             "german.json, portuguese.json, spanish.json")
    parser.add_argument("out_file", type=Path,
                        help="Swift file to write (e.g. "
                             "Condisco/DeepLink/LessonCatalog.generated.swift)")
    args = parser.parse_args()

    if not args.packs_dir.is_dir():
        sys.exit(f"error: packs directory not found: {args.packs_dir}")
    generate(args.packs_dir, args.out_file)
    return 0


if __name__ == "__main__":
    main()