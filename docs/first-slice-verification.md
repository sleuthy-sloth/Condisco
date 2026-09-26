# First-slice verification

How to verify the first implementation slice of the Condisco quality plan
(`docs/roadmaps/2026-09-25-condisco-quality-and-growth.md`). Two parts are automated
and run in seconds; two parts need a real device and real learners. Nothing here
claims proficiency — the goal is that no learner loses work, meets a dead end, or is
promised media the app cannot play.

## What is now automated

```sh
# 1. Pack + media integrity (missing assets, file type, declared sha256)
bash tools/check_packs.sh

# 2. Unit tests
xcodebuild test -project Condisco.xcodeproj -scheme Condisco \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:CondiscoTests ONLY_ACTIVE_ARCH=YES
```

Expected results:

- `check_packs.sh` exits `0` and ends with
  `PASS Content media inventory: every declared asset resolves with matching type/hash, or is allowlisted for device speech`.
  It resolves every pack-declared media URL and every Listen track URL against
  `Condisco/Content` and checks existence, extension-per-kind, and declared SHA-256.
- The one shipped pack audio asset (`it-market-listen-audio`, the Italian market
  Listen track) reports `ok`. The other 21 declared lesson assets have no file and are
  listed as `device-speech (intentional)` — see `tools/device-speech-media.txt`.
  Each missing entry names the referencing lesson and step.
- Unit tests: baseline before the slice was **59 passed, 1 skipped**. The skip was the
  duplicate-event byte-stability defect, now fixed and un-skipped.
- Unit tests: **123 passed, 0 failed, 0 skipped** (2026-09-25, after the Phase 1
  deep-link seam repair; the pre-fix baseline was 120 executed, 1 skipped — see
  `docs/verification/2026-09-25-baseline.md`). The previously skipped
  `NextLessonTests.testContinueDeepLinkResolutionRequiresStoreSeam` is gone: the
  `condisco://continue` seam now routes through a tested pure resolver
  (`continueLessonResolution`), and parsing, partial/full/orphaned resolution,
  and Home/widget/deep-link agreement on the same completed set are all covered.
  `** TEST SUCCEEDED **`.

## Manual: on-device smoke path

Run on a real iPhone. Record pass/fail and the exact observed behavior; do not smooth
over rough edges.

| Step | Expected | Result |
| --- | --- | --- |
| Fresh install, launch | Onboarding appears, no crash | |
| Complete onboarding | Placement runs, lands on Home | |
| First mission | Completes end to end | |
| Wrong text answer | Correction explains the specific error, lesson continues | |
| Wrong accent | Accent correction shown, not a dead end | |
| Assisted continuation | Learner can continue; practice is distinguished from independent recall | |
| Kill app during a lesson, relaunch | Progress preserved, no lost checkpoint | |
| Review session | Due items appear and complete | |
| Listen with screen locked | Audio keeps playing (background playback) | |
| Microphone denied, then allowed | Denied path is clear; allowed path records | |
| Content update with existing checkpoint | Old checkpoint still valid, no reset | |
| French device-speech lesson (e.g. `fr-cafe-order-foundation`) | "Hear audio" works, labeled "Course voice (synthesized)", no dead control | |
| Italian device-speech lesson (e.g. `it-cafe-order-foundation`) | Same as above | |
| Italian market Listen track | Shipped recording plays | |

Shipped-media copy now in place: a step with no recording offers **"Hear audio"** /
**"Stop"** and is captioned **"Course voice (synthesized)"**; with no transcript it reads
**"A recording for this step isn't available yet."**; a playback failure reads
**"Audio could not play on this device. Try again."** (no false "check the download").

## Manual: five usability sessions

Five short moderated sessions on the first mission and one story, with at least one
learner using larger text. Do not coach. For each session capture:

```
Session #___  Learner: ___        Larger text? Y/N
Task stated in their words: ______________________________________
Hesitations (where, what they expected): _________________________
Real-world use explained unaided? Y/N  — quote: __________________
```

Record these measures, not time-in-app or streak length:

- **Task success** — finishes the first mission and can explain its real-world use unaided.
- **Recovery** — after a wrong answer, identifies the correction and continues without leaving the lesson.
- **Clarity** — can name the next useful action from Home within a few seconds.

## Manual: later-phase features (P2–P3)

Added after the first slice. Each row needs a real device or simulator; mark pass/fail and
the exact observed behaviour.

| Area | Check | Result |
| --- | --- | --- |
| Today plan | Home shows ONE primary action; no competing continue/review CTAs | |
| Today plan | No resume + partial pack → next lesson is primary; due>0 still shows a review row | |
| Today plan | Path complete + due>0 → review is primary | |
| Today plan | Review row copy offers a short option ("Start with 5 — a few minutes"); no streak anywhere | |
| Lesson | Primary action is reachable and tappable with the keyboard open | |
| Lesson | After a wrong answer, feedback and the primary action are both on screen on a small iPhone | |
| Lesson | Full passage is not repeated above every question | |
| Recall warm-up | Fresh lesson with due cards from earlier lessons shows ≤2 warm-up cards, oldest first, before the briefing | |
| Recall warm-up | Resuming a mid-lesson checkpoint never shows the warm-up | |
| Recall warm-up | The warm-up never asks the same question the lesson is about to ask | |
| Recap | Shows goal achieved, key phrases framed for outside use, one "Worth remembering" correction, and an independent-vs-with-help split | |
| Mission task | A mission recap shows "TAKE IT OUTSIDE" with the task and a phrase save; "I tried it" persists across app restarts (local only) | |
| Listen | "Slow" replays the current line at 0.75x and clears when the rate is changed | |
| Listen | Transcript is readable/selectable; background playback and lock-screen controls still work | |
| Practice loop | Listen → Practice runs line → reveal → speak → model → next, with no score or accuracy claim | |
| Practice loop | Denying the mic skips the speak step quietly; main player's background playback still works afterwards | |
| Pair card | Conversation recap → pair card flips which role you read first; sharing exports a PNG with course content only | |
| Accessibility | VoiceOver order/labels on Home, lesson, review and courses; verdict buttons announce their meaning | |
| Accessibility | Reduce Motion: flashcard flip and lesson transitions do not animate | |
| Labelling | Any synthesized audio is labelled "(synthesized)"; no control claims a recording it does not have | |

## Blocked on humans

- **On-device audio verification** (one French + one Italian device-speech lesson) needs a real device.
- **The five usability sessions** need real learners.
- **Audio provenance**: `docs/audio-provenance/` does not exist, but the Italian market
  track's `attribution` cites `docs/audio-provenance/italian-market-listen.json`. Supply
  the record or correct the citation.
- **Native-speaker review** remains open per the pack attribution. The 21 device-speech
  steps currently ship synthesized speech, not reviewed recordings.

## Open findings

- The Italian market Listen track's declared SHA-256 was stale (`c0c6bee6…`). The
  shipped file hashes to `4b62a0f69ac5c9becf88ee82553003ed9a45a70f514f11ee5168d9ad84166fe5`.
  The declaration was corrected to match the shipped artifact. Because no reference
  audio exists to regenerate against, the shipped file is treated as the source of
  truth; content review of that audio is still a human task.
- 21 declared lesson audio assets have no file and are intentionally served by device
  speech (allowlisted in `tools/device-speech-media.txt`). Any new missing asset that is
  **not** allowlisted fails `check_packs.sh`.
