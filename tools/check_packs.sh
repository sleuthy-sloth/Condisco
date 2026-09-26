#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/condisco-pack-check.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc \
  "$project_root/Condisco/Models/CoursePack.swift" \
  "$project_root/Condisco/Store/PackLoader.swift" \
  "$project_root/Condisco/Store/LearningEvents.swift" \
  "$project_root/Condisco/Engine/AnswerEngine.swift" \
  "$project_root/Condisco/Engine/ActivityEvaluation.swift" \
  "$project_root/tools/check_packs.swift" \
  -o "$check_dir/check-packs"
ln -s "$project_root/Condisco/Content" "$check_dir/Content"
# The checker derives packs/ and listen-tracks/ from the Content root and
# consults the checked-in allowlist for intentionally missing (device-speech)
# assets.
"$check_dir/check-packs" \
  "$project_root/Condisco/Content" \
  "$project_root/tools/device-speech-media.txt"
