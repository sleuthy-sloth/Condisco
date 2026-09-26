# Condisco final gate report — 2026-09-26

Closing deliverable of `docs/roadmaps/2026-09-25-condisco-next-worker-closure-plan.md`
("Final release decision"). Every row states the exact command + result, or is
explicitly **BLANK** where no evidence exists. Nothing blank was converted to a
pass by assumption.

**Build under test:** Condisco 1.0 (build 1), Debug-iphonesimulator, commit
`bca8ad6`. **Simulator:** iPhone 18 Pro, iOS 27.0 simulator runtime.

## 1. Automated gates (all commands re-run for this report)

| Gate | Command | Result | Evidence |
|---|---|---|---|
| Pack + media integrity | `bash tools/check_packs.sh` | **PASS** (5/5 languages, media type/hash, listen durations/sections, attribution citations resolve) | `docs/verification/2026-09-26-phase4-5-final-preflight-with-ui.log` |
| Editorial audit (strict) | `bash tools/audit_editorial.sh --strict` | **PASS, exit 0** — open-ended false-auto-grade count **0** | same log (step 2) + waveF log |
| Generated catalog drift | `python3 tools/gen_lesson_catalog.py` + diff | **PASS** — byte-identical | same log (step 3) |
| Unit tests | `xcodebuild test -only-testing:CondiscoTests` | **PASS — 385/385, 0 failures** | same log (step 4) |
| UI smoke | `xcodebuild test -only-testing:CondiscoUITests` | **PASS — 6/6, 0 failures** (FirstRun + 5 accessibility-sweep tests) | same log (step 5) |
| Full pre-share gate | `bash tools/preflight.sh --with-ui` | **EXIT=0** | `2026-09-26-phase4-5-final-preflight-with-ui.log` |
| CI (no secrets) | `.github/workflows/ci.yml` | defined: pack/media, catalog consistency, unit tests | repo |

Infra notes recorded honestly in the logs: two simulator `testmanagerd`
socket flakes (recovered by shutting down wedged simulators) and one SIGTERM
kill of a run mid-build — none were test failures, none were counted as passes.
The one **real** failure found by the gate (`testLargestDynamicTypeKeepsActionsReachable`)
was fixed in `593c766` with a stronger assertion, not a weakened one.

## 2. Editorial status

| Metric | Count |
|---|---|
| Total lessons with review-log disposition | **255 / 255** |
| `pass` | **183** |
| `pass-with-notes` (native-confirmation items open in `unresolvedQuestions`) | **72** |
| `unreviewed` / `needs-work` | **0** |
| Review method | **AI-assisted solo protocol — never native review** |
| Usability / learner sessions held | **0** |

Source: `docs/reviews/review-log.jsonl` (+ per-pack files under
`docs/reviews/review-log/`). Regenerate master via `python3 tools/gen_review_log.py`.

## 3. Device / capability gates — ALL BLANK

No physical iPhone or iPad, no paid-capability CloudKit two-device setup, and
no outside testers were available to this worker. These require the developer:

| Gate | Status |
|---|---|
| On-device audio (record/compare, Listen playback, lock screen, background) | **BLANK — physical device required** |
| On-device accessibility (VoiceOver, Reduce Motion, largest Dynamic Type on hardware) | **BLANK — physical device required** |
| Upgrade drills on hardware (previous-build DB + checkpoint, force-quit/resume, airplane mode) | **BLANK — physical device required** (simulator-only upgrade tests exist in StoreTests) |
| CloudKit two-device real merge | **BLANK — paid capability + second device; local progress is the release guarantee otherwise** |
| Performance / battery (cold launch, pack load, memory, Listen battery on oldest supported device) | **BLANK — device measurement required**; simulator-only probes recorded in `docs/performance-budget.md` §7, device table §3 rows all TODO |
| Version bump + archive + clean/update install + checklist sign-off | **BLANK — release action for the developer** (`docs/release-checklist.md` rows stay PASS/BLANK, never assumed) |

## 4. Outcome measures — ALL UNVERIFIED

The three plan measures are **unverified — no learner sessions held**:

1. Five adult beginners complete a first mission without coaching, identify a
   correction, name the next Home action — **unverified**.
2. One-week delayed recall/production of an earlier phrase — **unverified**.
3. Clarity / task-success acceptance — **unverified**.

What exists instead: a **solo, simulator-only** walkthrough and accessibility
audit (`docs/usability/2026-09-26-solo-walkthrough-and-outcome-status.md`).
Per plan, AI simulation finds possible UI problems; it is not evidence that
learners succeeded. No streak or time-in-app metric substitutes for these.

## 5. Remaining limitations (complete list)

- **Native review pending** on all 255 lessons; 72 `pass-with-notes` rows carry
  open native-confirmation items. No content is native-reviewed, certified, or
  claim-complete for any CEFR level.
- All section-3 device/CloudKit/performance gates blank; all section-4 outcome
  measures unverified. **The original quality plan must not be called
  "complete" while these are blank.**
- Known backlog (documented, non-blocking): `CoursesView` "Up next" badge
  uses `finishedLessons` vs `participationCompleted` (decision open); Italian
  `units[]` ordering quirk (it-unit-9 last); editorial hint/feedback backlog
  counts remain report-only in `audit_editorial` (authored step-specific where
  dispositioned; never bulk-generic).
- Audio-start latency: hook points documented in `docs/performance-budget.md`
  §2.5/§5, **not measured** (view-side signpost not yet wired; device-only).

## 6. Share decision

Automated gates are green (`preflight --with-ui` EXIT=0 at `bca8ad6`).
**A candidate may be shared with external testers only after** the developer
runs the section-3 physical-device progress/media checks and signs off
`docs/release-checklist.md`. Learner-facing claims must state outcome measures
are unverified and native review is pending.
