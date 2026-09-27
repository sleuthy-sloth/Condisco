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

| Date | Log | Result |
| --- | --- | --- |
| Baseline (pre-fix, 2026-09-25) | `2026-09-25-baseline-preflight-with-ui.log` (+ `2026-09-25-baseline.md`) | Steps 1–4 green; **UI smoke FAIL**; preflight exit 1 |
| Phase 1 (post-fix, 2026-09-25) | `2026-09-25-phase1-preflight-with-ui.log` | All 5 steps PASS; unit suite 123 tests / 0 failures; UI 1/1; `PREFLIGHT PASSED`, exit 0 |
| Phase 2 (rerun, 2026-09-25) | `2026-09-25-phase2-preflight-with-ui.log` | All 5 steps PASS; unit suite 127 tests / 0 failures; UI 1/1; `PREFLIGHT PASSED`, exit 0 |
| Phase 0 baseline (2026-09-26) | `2026-09-26-phase0-baseline-gates.log` (+ [`2026-09-26-phase0-baseline.md`](verification/2026-09-26-phase0-baseline.md)) | All 5 steps PASS; unit 387/387, 0 failures; UI 6/6, 0 failures; `PREFLIGHT PASSED`, exit 0 — gates green on the dirty working tree at `50a9f7f` |

The strict editorial gate is green on the same date: `tools/audit_editorial.sh
--strict` exits 0 with `EXIT-GATE … PASS (0)` recorded in both phase logs.
This iOS project uses `bash tools/preflight.sh --with-ui` as its local build gate.
The 2026-09-26 local install follow-up records a later preflight (386 unit /
6 UI), a final-code 387-test rerun, and an iPhone target build:
[`docs/verification/2026-09-26-local-install-followup.md`](verification/2026-09-26-local-install-followup.md).
The Phase 0 baseline sheet
([`docs/verification/2026-09-26-phase0-baseline.md`](verification/2026-09-26-phase0-baseline.md))
records the same gate set green on the dirty working tree at `50a9f7f` on
2026-09-26 (log `2026-09-26-phase0-baseline-gates.log`) — a tree-state
baseline, not a per-commit pass claim.

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

## 1b. Listen device checks

Reproducible manual checks for the Listen feature that the unit suite cannot
exercise (audio playback, background session, lock-screen controls need a real
device with the app installed). Run each row on a physical iPhone and record
pass/fail + observed behavior; do not mark a row PASS without that evidence.
Automated coverage that exists: position/listened persistence in the
`listen_state` table and sync merge are pinned by `CondiscoTests`
(`StoreTests`, `EngineTests`); section timing is enforced by
`tools/check_packs.sh` (strictly increasing `startS`, `>= 0`, `<= durationS`,
declared duration within 1 s of the real audio).

- [ ] **Speed applies to the current audio** — Play a track, tap the rate
  button until it reads `0.75×`: audio audibly slows mid-track. Tap through to
  `1.5×`: it audibly speeds up. Changing speed never stops or restarts the
  audio, and the lock screen shows the same rate.
- [ ] **Slow replay** — Play, tap **Slow**: playback jumps to the current
  section's start and continues at a gentle pace (0.75×). Tap **Slow** again:
  speed returns to normal in place.
- [ ] **Resume survives leave/return** — Play past 5 seconds, leave the track,
  reopen it: playback resumes where you stopped (within ~5 s).
- [ ] **Resume survives force quit** — Play past 5 seconds, background the app
  (home button), kill it from the app switcher, relaunch, reopen the track:
  position resumes where you stopped. (The player also persists every 5 s
  while playing and on entering the background.)
- [ ] **Resume card offers both paths** — With a saved position the player
  shows "You stopped at …" with Resume and Start over; Start over discards the
  position and plays from the beginning.
- [ ] **Background playback + lock-screen controls** — Start a track, lock the
  screen: audio keeps playing. On the lock screen / Control Center,
  play/pause, ±15 s skip, and the scrubber all work; finishing the track
  updates the now-playing screen (rate 0, no false "playing").
- [ ] **Provenance label** — The player card shows **"Course voice
  (synthesized)"** under the track title, and the lock screen title includes
  it. No Listen control claims a human recording. (Code region labeled on
  2026-09-26; verify the wording on device.)
- [ ] **Offline** — With Airplane mode on, the Listen tab lists all 5 tracks,
  audio plays, positions save and restore, and no network error surfaces
  anywhere in the path.
- [ ] **Practice loop** — Listen → Practice walks line → reveal → respond →
  compare → next section; the compare replay plays at the slow pace; closing
  the sheet returns to the main player with its paused state and resume point
  intact.
- [ ] **Sleep timer** — Set the 5-minute sleep timer, lock the screen:
  playback pauses at the deadline and the player shows the paused state when
  reopened.

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

## 3b. Phase 4.1 walkthrough (dated)

Repeatable on-device walkthrough for plan Phase 4.1. **Date the run** (record it
here when executed) and note the **candidate build identity from the 4.3 gate**
(commit/diff) before starting — that identity goes in the "Build (commit/diff
identity)" column of every row. Rows 1–5 run on the **owned iPhone**; row 6's
extra sizes (small iPhone, landscape, iPad) are **simulator** rows and every
simulator result must be labeled `simulator` in the "Device + iOS" column (row
7's restore is a fresh-simulator run: label it `simulator` too). Record one
short observation per row and mark Result **PASS / FAIL / UNVERIFIED**. These
are human device results — never fill a Result cell from an automated or AI
run, and never guess (convention in §6). Rows that also exist in §1 / §1b / §2
keep their place here with the reference appended; run them once and record the
evidence below.

| Row | Result (PASS/FAIL/UNVERIFIED) | Device + iOS | Build (commit/diff identity) | Observation |
| --- | --- | --- | --- | --- |
| 1 · Clean install → onboarding → placement → first mission → wrong-answer correction → assisted continuation → recap → next lesson. | | | | |
| 2 · Force quit mid-lesson → relaunch → exact checkpoint, no duplicate credit (see §1, §3). | | | | |
| 3 · Update install over a build with progress → same events, known marks, phrasebook, listen position (see §1, §3). | | | | |
| 4 · Airplane mode → lesson, five-card review, Listen, synthesized course voice, data export (see §1b, §3). | | | | |
| 5 · Microphone denied then allowed; recording cleanup and audio-session recovery (see §1). | | | | |
| 6 · VoiceOver, largest Dynamic Type, Reduce Motion, keyboard-open actions, reachable review buttons (note: small-iPhone / landscape / iPad layouts are **simulator** rows, labeled as such; see §2). | | | | |
| 7 · Export → fresh-simulator restore: progress, saved phrases, Listen position (Phase 1.2 developer check, currently only in verification notes). | | | | |

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
| Engineering | `preflight.sh` green (unit tests + pack/media + catalog) | **PASS (2026-09-25)** — `docs/verification/2026-09-25-phase1-preflight-with-ui.log` and `…-phase2-…log`: all required steps PASS, `PREFLIGHT PASSED`, exit 0. **PASS (2026-09-26)** — `docs/verification/2026-09-26-phase0-baseline-gates.log`: `preflight.sh --with-ui` EXIT=0, unit 387/387, UI 6/6 on iPhone 18 Pro (see `docs/verification/2026-09-26-phase0-baseline.md`) | |
| Engineering | UI smoke (`--with-ui`) run once per release | **PASS (2026-09-25)** — step 5 PASS in both phase logs (UI 1/1, twice); the baseline log records the pre-fix FAIL for honesty. **PASS (2026-09-26)** — step 5 PASS in `docs/verification/2026-09-26-phase0-baseline-gates.log` (UI 6/6, 0 failures, iPhone 18 Pro simulator) | |
| Media | Zero unresolved non-allowlisted assets; allowlist unchanged or justified | **PASS (2026-09-25)** — "Content media inventory: every declared asset resolves…" in both phase logs; 21 device-speech assets allowlisted in `tools/device-speech-media.txt`; attribution citations + listen-duration/section checks PASS (phase 2 log) | |
| Editorial | Gate: `tools/audit_editorial.sh --strict` green | **PASS (2026-09-25)** — `EXIT-GATE … PASS (0)` in both phase logs (strict gate exits 0) | |
| Editorial | Review dispositions logged and reviewed | **PASS for AI-assisted editorial disposition only (2026-09-26).** `docs/reviews/review-log.jsonl` has 255 rows: 183 `pass`, 72 `pass-with-notes`, 0 `unreviewed`. Native-speaker review remains pending for all; 72 notes require native confirmation | |
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
  (`docs/reviews/review-log.jsonl`) records 183 `pass` and 72
  `pass-with-notes` AI-assisted dispositions. None counts as native review.
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
  semantics in unit tests cover it. Two-device CloudKit verification stays
  **UNVERIFIED/BLANK** — a device or two-device row must not be marked PASS.

## 8. Accepted limitations

Recorded when a behavior is known but accepted by design — stated honestly,
never hidden from the learner, and never upgraded to a PASS without evidence.

- **Listen-state sync is whole-row last-write-wins.** One row per track (resume
  position + listened mark) merges by `updated_at_ms`, so a listened mark
  written on one device can overwrite a newer resume position written on the
  other when both edit the same track before the next sync. No reproducible
  user-visible failure exists to report — CloudKit is disabled in this build —
  so this is recorded as an **accepted design limitation**, not a
  verified-fixed bug. Revisit before enabling two-device sync.
