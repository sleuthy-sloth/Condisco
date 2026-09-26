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
- Listen-track audio ships as real recordings: the Italian market track's
  declared SHA-256 must match the shipped file.

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

| Area | Check | Signed (name / date) |
| --- | --- | --- |
| Engineering | `preflight.sh` green (unit tests + pack/media + catalog) | |
| Engineering | UI smoke (`--with-ui`) run once per release | |
| Media | Zero unresolved non-allowlisted assets; allowlist unchanged or justified | |
| Editorial | Audit backlog reviewed; every new gap tracked as an issue, none silently shipped as "done" | |
| UX | Accessibility pass (Dynamic Type, VoiceOver, reduce motion, contrast/touch) | |
| UX | Progress-preservation checks (force quit, update, offline, sync replay) | |
| Product | Real-device smoke table completed on a physical iPhone | |
| Product | Version/build bumped; release notes name carried-over risks (below) | |

## 7. Human-blocked items — carried-over risk, stated honestly

These are known-open items. Do **not** mark them green; record them as
carried-over risk in the release notes:

- **Native-speaker review is open** per pack attribution (see
  [`docs/native-review-kit.md`](native-review-kit.md)): 21 device-speech steps
  ship synthesized speech, and the A2 lessons across packs are machine-authored
  and pending native-speaker review. Releasing does not claim otherwise.
- **On-device audio verification** of the French + Italian device-speech
  lessons needs a real device — it is part of §1, not of `preflight.sh`.
- **Five usability sessions** (§ "Manual: five usability sessions" in the
  verification doc) need real learners; they stay a separate, scheduled
  activity.
- **Audio provenance**: `docs/audio-provenance/` does not exist, but the
  Italian market Listen track's `attribution` cites
  `docs/audio-provenance/italian-market-listen.json`. Either supply the record
  or correct the citation before claiming provenance.