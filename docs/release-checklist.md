# Release checklist — Condisco

Practical pre-release checklist for sharing a Condisco build (TestFlight, review
builds, external testers, screenshots). The automated gate is
`tools/preflight.sh`; everything else below is manual and needs a human with a
real device. Save this checklist with the build/version noted, and record every
manual result (pass/fail + observed behavior) — do not smooth over rough edges.

Pointer for the detailed steps this checklist summarizes:
[`docs/first-slice-verification.md`](first-slice-verification.md).

---

## 0. Automated gate — must be green

Run from the repo root (the script self-locates):

```sh
bash tools/preflight.sh               # required steps
bash tools/preflight.sh --with-ui     # + UI smoke; do this at least once per
                                      # release before any external share
```

| Step | What it blocks on | Required? |
| --- | --- | --- |
| 1. Pack + media integrity (`tools/check_packs.sh`) | Any declared asset missing, wrong type, or SHA-256 mismatch (beyond the allowlist) | Yes |
| 2. Editorial backlog (`tools/audit_editorial.sh`) | Nothing — report only; counts are a backlog, not a gate | No |
| 3. Generated catalog drift (`tools/gen_lesson_catalog.py` diff) | `LessonCatalog.generated.swift` not byte-identical to a fresh regeneration | Yes |
| 4. Unit tests (`xcodebuild … -only-testing:CondiscoTests`) | Any unit test failure | Yes |
| 5. UI smoke (`xcodebuild … -only-testing:CondiscoUITests`, only with `--with-ui`) | Any UI test failure | Only if invoked |

`preflight.sh` stops at the first required failure and exits non-zero. A green
run ends with `PREFLIGHT PASSED`.

Every claim below that is backed by a recorded result points at a dated log in
[`docs/verification/`](verification/):

| Date (2026-09-25) | Log | Result |
| --- | --- | --- |
| Baseline (pre-fix) | `2026-09-25-baseline-preflight-with-ui.log` (+ `2026-09-25-baseline.md`) | Steps 1–4 green; **UI smoke FAIL**; preflight exit 1 |
| Phase 1 (post-fix) | `2026-09-25-phase1-preflight-with-ui.log` | All 5 steps PASS; unit suite 123 tests / 0 failures; UI 1/1; `PREFLIGHT PASSED`, exit 0 |
| Phase 2 (rerun) | `2026-09-25-phase2-preflight-with-ui.log` | All 5 steps PASS; unit suite 127 tests / 0 failures; UI 1/1; `PREFLIGHT PASSED`, exit 0 |

The strict editorial gate is green on the same date: `tools/audit_editorial.sh
--strict` exits 0 with `EXIT-GATE … PASS (0)` recorded in both phase logs. The
repo's CI (`.github/workflows/ci.yml`) runs check_packs, the editorial audit
with `--strict`, the catalog drift check, and the unit tests on every push/pull
request — no UI tests in CI, no secrets.

---

## 1. Real-device smoke

`preflight.sh` runs on a simulator; a release must also be exercised on a real
iPhone. Use the manual smoke table in
[`docs/first-slice-verification.md`](first-slice-verification.md)
(§ "Manual: on-device smoke path") and record each row: fresh install +
onboarding, first mission end-to-end, wrong-answer and wrong-accent recovery,
assisted continuation, kill-and-relaunch mid-lesson, review session, Listen with
screen locked (background audio), microphone denied → allowed, content update
with an existing checkpoint, and the French + Italian device-speech "Hear audio"
steps plus the shipped Italian market Listen track.

Key expectation to verify specifically: a step with no recording offers
**"Hear audio" / "Stop"** captioned **"Course voice (synthesized)"**; no step
may show a dead control or "check the download".

## 2. Accessibility checks

Test with the OS-level settings, on device, in addition to the app's own
`A11ySettings` toggles (`verbalibera.a11y.*` keys):

- **Dynamic Type** — largest text size end-to-end (onboarding → first lesson →
  Home); no truncation that hides content, no layout breakage.
- **VoiceOver** — navigate Home and a full lesson; every interactive element is
  labeled; wrong-answer corrections are announced.
- **Reduce motion** — flows complete without animation dead-ends.
- **Contrast / touch targets** — interactive elements meet the ~44 pt minimum
  target and the text/background contrast holds in the "studio" palette.

## 3. Progress-preservation checks

The progress guarantees are the app's core promise — verify each on device:

- **Force quit mid-lesson, relaunch** — checkpoint resumes exactly where the
  learner left; nothing lost.
- **Content update with an existing checkpoint** — install the new build over
  one with progress; the old checkpoint is still valid, no reset.
- **Airplane mode / offline** — the app is fully local: lessons, Listen, and
  review keep working; sync degrades gracefully with no error surfaced to the
  learner.
- **Second-device / sync replay** — two devices on the same Apple ID; complete a
  lesson on one, verify the projection replays on the other (the event log
  merges, projections recompute locally).

## 4. Media integrity

`tools/check_packs.sh` must be green with **zero unresolved non-allowlisted
assets**:

- Exactly the **21 device-speech assets** listed in `tools/device-speech-media.txt`
  may be missing — they are intentional (synthesized course voice).
- Any other missing, mistyped, or hash-mismatched asset fails the gate. If a
  step is *intentionally* switched to device speech, add it to the allowlist
  with a comment naming the lesson/step and the reason — never as a silent
  bypass.
- Listen-track audio ships in the bundle: each track's declared SHA-256 must
  match the shipped file. The tracks are synthesized course voice (TTS,
  `reviewPending`) — see the audio-provenance item in §7; do not describe them
  as human recordings.

## 5. Version / build bump

- Bump **Version** (marketing version; current content is v0.7.0-era — next
  release e.g. 0.8.0) and **Build** in the Xcode target **Condisco** → General.
- Keep the **CondiscoWidget** extension's build number in sync (same release).
- After upload, confirm the version/build shown in TestFlight/Organizer matches
  what the checklist is filed against.
- Note: the project currently sets no explicit `MARKETING_VERSION` /
  `CURRENT_PROJECT_VERSION` in the pbxproj, so the very first explicit bump
  will add those build settings — verify both app and widget afterwards.

## 6. Sign-off

Status convention: **PASS** means a recorded result exists (log path given);
**BLANK** means explicitly unverified — never convert a blank into a pass
without the evidence. Record name/date in the last column when you sign.

| Area | Check | Status / evidence | Signed (name / date) |
| --- | --- | --- | --- |
| Engineering | `preflight.sh` green (unit tests + pack/media + catalog) | **PASS (2026-09-25)** — `docs/verification/2026-09-25-phase1-preflight-with-ui.log` and `…-phase2-…log`: all required steps PASS, `PREFLIGHT PASSED`, exit 0 | |
| Engineering | UI smoke (`--with-ui`) run once per release | **PASS (2026-09-25)** — step 5 PASS in both phase logs (UI 1/1, twice); the baseline log records the pre-fix FAIL for honesty | |
| Media | Zero unresolved non-allowlisted assets; allowlist unchanged or justified | **PASS (2026-09-25)** — "Content media inventory: every declared asset resolves…" in both phase logs; 21 device-speech assets allowlisted in `tools/device-speech-media.txt`; attribution citations + listen-duration/section checks PASS (phase 2 log) | |
| Editorial | Gate: `tools/audit_editorial.sh --strict` green | **PASS (2026-09-25)** — `EXIT-GATE … PASS (0)` in both phase logs (strict gate exits 0) | |
| Editorial | Review dispositions logged and reviewed | **BLANK — in progress.** `docs/reviews/review-log.jsonl` has 255 rows, all `unreviewed`; batch-1 dispositions (AI-assisted/developer review) are in `docs/reviews/review-log/<pack>.jsonl`. Native-speaker review is pending for all — do not claim otherwise | |
| UX | Accessibility pass (Dynamic Type, VoiceOver, reduce motion, contrast/touch) | **BLANK — unverified.** No device accessibility run recorded; must be done on a physical device | |
| UX | Progress-preservation checks (force quit, update, offline, sync replay) | **BLANK — partially covered.** Force-quit/offline flows are exercised only by the simulator UI smoke; on-device app-over-app update and two-device CloudKit merge are unverified (entitlements commented out; needs two devices on one Apple ID) | |
| Product | Real-device smoke table completed on a physical iPhone | **BLANK — unverified.** No physical-device evidence recorded yet (includes on-device audio, battery, performance) | |
| Product | Version/build bumped; release notes name carried-over risks (below) | **BLANK — not done.** No release filed yet; the pbxproj sets no explicit marketing/current project version until the first bump | |

## 7. Human-blocked items — carried-over risk, stated honestly

These are known-open items. Do **not** mark them green; record them as
carried-over risk in the release notes:

- **Native-speaker review is open** per pack attribution (see
  [`docs/native-review-kit.md`](native-review-kit.md)): 21 device-speech steps
  ship synthesized speech, and the A2 lessons across packs are machine-authored
  and pending native-speaker review. The disposition log
  (`docs/reviews/review-log.jsonl`) confirms all 255 lessons are still
  `unreviewed` (batch-1 AI-assisted/developer dispositions are in
  `docs/reviews/review-log/`). Releasing does not claim otherwise.
- **On-device audio verification** of the French + Italian device-speech
  lessons needs a real device — it is part of §1, not of `preflight.sh`.
- **Five usability sessions** (§ "Manual: five usability sessions" in the
  verification doc) need real learners; they stay a separate, scheduled
  activity.
- **Audio provenance records now exist** (`docs/audio-provenance/`, one
  record per Listen track + `index.md`), and the pack attribution citations
  resolve — "PASS attribution citations" in
  `docs/verification/2026-09-25-phase2-preflight-with-ui.log`. What stays open
  is **human listening review**: the Italian market Listen track's
  `attribution` itself notes "Native-speaker prosody review remains open", and
  all 5 bundled Listen tracks are TTS with `reviewPending`. Do not claim the
  audio is human-recorded or prosody-reviewed.
- **Performance/battery evidence is unmeasured** — no physical-device profiling
  or battery runs have been recorded (see `docs/performance-budget.md`).
- **CloudKit two-device merge is unexercised** — sync entitlements are
  commented out (personal-team build cannot use them), so a real two-device
  replay on one Apple ID has never been run; only the event-log merge
  semantics in unit tests cover it.