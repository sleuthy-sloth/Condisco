#!/bin/bash
#
# tools/preflight.sh — Condisco pre-share gate.
#
# The single gate to run before sharing a build (TestFlight, review builds,
# external testers, screenshots). Runs the independent checks IN ORDER and
# STOPS at the first required failure, printing a clear PASS/FAIL per step
# and a final verdict. Exits 0 only when every required step is green.
#
# Usage:
#     bash tools/preflight.sh                 # required steps only
#     bash tools/preflight.sh --with-ui       # also run the UI smoke (slower)
#     bash tools/preflight.sh --help
#
# Steps (in order) and what each blocks on:
#
#   1. Pack + media integrity  — tools/check_packs.sh            [required]
#        Compiles the real production pack model with `xcrun swiftc`,
#        decodes all five packs, and verifies every declared media asset
#        (file exists, extension matches kind, SHA-256 matches). The 23
#        intentionally missing device-speech assets (fr 5 + it 16 + es 2)
#        are allowlisted in tools/device-speech-media.txt. Any other
#        missing/mismatched asset fails the gate: content is not shippable.
#
#   2. Editorial backlog       — tools/audit_editorial.sh        [report only]
#        Standalone report of editorial gaps (missing authored error
#        feedback, generic-only hints, ungraded activities, mission/story
#        lessons without a text final-response step). REPORT-ONLY by design:
#        it never fails the gate; its SUMMARY lines and the "OPEN-ENDED
#        GRADING CHECK" exit-gate line (P1.1 status, informational) are
#        printed for the record so the backlog and gate status are visible in
#        the preflight log.
#
#   3. Modality-claims audit   — tools/audit_outcomes.py         [required]
#        Structural audit (Phase 5.4): compares the modality skills
#        DECLARED on each lesson's activities against the activity types
#        that actually exercise them (listening needs an audio-backed step,
#        speaking a self-compare, writing a text/cloze step, reading a
#        text-bearing step). Exit 0 = every declared claim is backed; any
#        unbacked claim (or a schema/usage error, exit 2) FAILS the gate —
#        a unit may not claim a modality no task trains.
#
#   4. Generated catalog drift — tools/gen_lesson_catalog.py     [required]
#        Regenerates Condisco/DeepLink/LessonCatalog.generated.swift into a
#        temp file and diffs it byte-for-byte against the committed one.
#        Fails the gate on ANY drift (and prints the exact command to
#        regenerate), because the committed catalog must be a faithful
#        snapshot of the five bundled packs for Siri/Shortcuts processes.
#
#   5. Unit tests              — xcodebuild … -only-testing:CondiscoTests
#                                                                [required]
#        Runs CondiscoTests against the Condisco scheme on the iPhone 18 Pro
#        simulator. Fails the gate on any test failure. Uses a fresh derived
#        data path under the system temp dir so the tree is not polluted.
#
#   6. UI smoke                — xcodebuild … -only-testing:CondiscoUITests
#        [optional; only with --with-ui]  Boots/reuses the simulator and
#        runs the CondiscoUITests end-to-end flow. Slower (simulator boot +
#        full UI run), so it is opt-in; if requested and failing, it fails
#        the gate.
#
# Requirements: Xcode with the iOS simulator runtime containing "iPhone 18 Pro"
# (for xcrun / xcodebuild), and python3 (for the catalog generator). The audio
# renderer (tools/render_cafe_audio.py) is intentionally NOT part of this gate.
#
# POSIX-ish bash; resolves the repo root itself, so it can be run from any
# directory.
#
set -uo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

# ---- CLI parsing -----------------------------------------------------------
run_ui=0
for arg in "$@"; do
    case "$arg" in
        --with-ui)
            run_ui=1
            ;;
        --help|-h)
            cat <<'EOF'
usage: bash tools/preflight.sh [--with-ui]

--with-ui   also run the UI smoke (CondiscoUITests); slower, opt-in.
--help      show this help.

Steps (run in order, stops on first required failure):
  1  pack + media integrity        tools/check_packs.sh        (required)
  2  editorial backlog report      tools/audit_editorial.sh    (report only)
  3  modality-claims audit         tools/audit_outcomes.py     (required)
  4  generated catalog drift       tools/gen_lesson_catalog.py (required)
  5  unit tests                    xcodebuild -only-testing:CondiscoTests (required)
  6  UI smoke                      xcodebuild -only-testing:CondiscoUITests (--with-ui)
EOF
            exit 0
            ;;
        *)
            echo "preflight: unknown argument '$arg' (try --help)" >&2
            exit 2
            ;;
    esac
done

# ---- Setup ----------------------------------------------------------------
# One temp root per run holds the audit log, generated catalog, diff, and the
# xcodebuild derived data path; everything is cleaned up on exit (success or
# not) so the tree and the temp dirs stay unpolluted.
preflight_tmp="$(mktemp -d "${TMPDIR:-/tmp}/condisco-preflight.XXXXXX")"
trap 'rm -rf "$preflight_tmp"' EXIT

pass() { printf 'PASS %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; }
skip() { printf 'SKIP %s\n' "$*"; }
say()  { printf '\n== %s ==\n' "$*"; }

# ----------------------------------------------------------------------------
say "Step 1/6  Pack + media integrity  (tools/check_packs.sh)"
if bash "$project_root/tools/check_packs.sh"; then
    pass "pack + media integrity (check_packs.sh)"
else
    fail "pack + media integrity (check_packs.sh) — content is not shippable"
    echo "PREFLIGHT ABORTED after step 1 (stopping on first failure)"
    exit 1
fi

# ----------------------------------------------------------------------------
say "Step 2/6  Editorial backlog report  (tools/audit_editorial.sh — report only, not a gate)"
audit_log="$preflight_tmp/editorial-audit.log"
bash "$project_root/tools/audit_editorial.sh" >"$audit_log" 2>&1
audit_status=$?
# Print the report's SUMMARY lines (one per pack + the final one) and the
# OPEN-ENDED GRADING CHECK section header + EXIT-GATE line for the record.
grep -E '^(SUMMARY|== OPEN-ENDED GRADING CHECK ==|EXIT-GATE)' "$audit_log" || true
if [ "$audit_status" -eq 0 ]; then
    pass "editorial audit ran — backlog counts above are informational, not a gate"
else
    # Packs failed to load *here* after passing step 1; treat as informational
    # per the report-only policy, but surface it loudly.
    printf 'WARN  audit_editorial.sh exited %s (packs failed to load — should have been caught by step 1); continuing\n' "$audit_status"
    pass "editorial audit attempted (non-zero exit treated as informational)"
fi

# ----------------------------------------------------------------------------
say "Step 3/6  Modality-claims audit  (tools/audit_outcomes.py)"
outcomes_log="$preflight_tmp/outcomes-audit.log"
if python3 "$project_root/tools/audit_outcomes.py" >"$outcomes_log" 2>&1; then
    # Compact record for the log: the header, the per-pack table, and the
    # verdict line. Full findings print only when the audit fails.
    grep -E '^(OUTCOMES|Pack|---|fr-foundations|it-foundations|de-foundations|pt-foundations|es-foundations|FINDINGS)' \
        "$outcomes_log" || true
    pass "modality-claims audit (audit_outcomes.py) — every declared claim is backed"
else
    outcomes_status=$?
    fail "modality-claims audit (audit_outcomes.py) — unbacked modality claims (exit $outcomes_status)"
    cat "$outcomes_log" 2>/dev/null || true
    echo "PREFLIGHT ABORTED after step 3 (stopping on first failure)"
    exit 1
fi

# ----------------------------------------------------------------------------
say "Step 4/6  Generated lesson catalog is a faithful snapshot  (tools/gen_lesson_catalog.py)"
catalog_gen="$preflight_tmp/LessonCatalog.generated.swift"
catalog_committed="$project_root/Condisco/DeepLink/LessonCatalog.generated.swift"
catalog_log="$preflight_tmp/gen-catalog.log"
catalog_diff="$preflight_tmp/gen-catalog.diff"

if ! python3 "$project_root/tools/gen_lesson_catalog.py" \
    "$project_root/Condisco/Content/packs" "$catalog_gen" >"$catalog_log" 2>&1; then
    fail "catalog generator failed to run (output below)"
    cat "$catalog_log" 2>/dev/null || true
    echo "PREFLIGHT ABORTED after step 4 (stopping on first failure)"
    exit 1
fi

if diff -u "$catalog_committed" "$catalog_gen" >"$catalog_diff" 2>&1; then
    pass "LessonCatalog.generated.swift regenerates byte-identically from the packs"
else
    fail "LessonCatalog.generated.swift has drifted from the five packs"
    echo "Diff (first 60 lines):"
    sed -n '1,60p' "$catalog_diff"
    echo
    echo "Fix it by regenerating:"
    echo "    python3 tools/gen_lesson_catalog.py Condisco/Content/packs \\"
    echo "        Condisco/DeepLink/LessonCatalog.generated.swift"
    echo "PREFLIGHT ABORTED after step 4 (stopping on first failure)"
    exit 1
fi

# ----------------------------------------------------------------------------
say "Step 5/6  Unit tests  (CondiscoTests)"
if xcodebuild test -project Condisco.xcodeproj -scheme Condisco \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
    -only-testing:CondiscoTests \
    -derivedDataPath "$preflight_tmp/DerivedData" \
    ONLY_ACTIVE_ARCH=YES; then
    pass "unit tests (CondiscoTests)"
else
    fail "unit tests (CondiscoTests) — failing tests block a share"
    echo "PREFLIGHT ABORTED after step 5 (stopping on first failure)"
    exit 1
fi

# ----------------------------------------------------------------------------
if [ "$run_ui" -eq 1 ]; then
    say "Step 6/6  UI smoke  (CondiscoUITests — --with-ui requested)"
    if xcodebuild test -project Condisco.xcodeproj -scheme Condisco \
        -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
        -only-testing:CondiscoUITests \
        -derivedDataPath "$preflight_tmp/DerivedData" \
        ONLY_ACTIVE_ARCH=YES; then
        pass "UI smoke (CondiscoUITests)"
    else
        fail "UI smoke (CondiscoUITests) — failing UI tests block a share"
        echo "PREFLIGHT ABORTED after step 6 (stopping on first failure)"
        exit 1
    fi
else
    say "Step 6/6  UI smoke skipped (pass --with-ui to run it)"
    skip "UI smoke (CondiscoUITests) — optional per gate policy"
fi

# ----------------------------------------------------------------------------
cat <<'EOF'

=======================================================
  PREFLIGHT PASSED — every required step is green.
=======================================================
EOF
exit 0