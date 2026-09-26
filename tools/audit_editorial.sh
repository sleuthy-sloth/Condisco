#!/bin/bash
# Editorial backlog audit for the bundled packs. Modeled on check_packs.sh:
# compile the production pack model with xcrun swiftc and run the report
# against the checked-in Content root.
#
# This is a REPORTING tool, not a gate: it prints counts and exits 0 when
# every pack loads, non-zero only if a pack cannot be read/decoded.
#
# Optional flags are forwarded to the binary (default invocation is
# byte-identical to calling with no flags):
#   --jsonl <path>   additionally write one JSON object per lesson to <path>
#   --strict         exit 1 on strictly-enforceable violations (open-ended
#                    prompts falsely auto-graded; ungraded wired to answers)
#                    while hint/error-feedback gaps stay report-only.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/condisco-editorial-audit.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc \
  "$project_root/Condisco/Models/CoursePack.swift" \
  "$project_root/tools/audit_editorial.swift" \
  -o "$check_dir/audit-editorial"
"$check_dir/audit-editorial" \
  "$project_root/Condisco/Content" "$@"