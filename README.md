# Condisco

Condisco is a free, offline-first iPhone app for practising useful language in context. It combines short lessons, stories, real-world missions, spaced review, listening, and self-assessed speaking and writing. The app uses SwiftUI, targets iOS 17+, and has no third-party runtime dependencies or required account.

This repository is the **native iOS app**. The earlier VerbaLibera web app is preserved in the web-legacy branch. The iOS app is the active product; some web-era storage identifiers remain to preserve learner progress.

## Current scope

Five bundled course packs contain **273 lessons**:

| Course | Lessons | Current scope |
| --- | ---: | --- |
| French | 50 | Beginner and developing practice |
| Italian | 49 | Beginner and developing practice |
| German | 52 | Beginner and developing practice |
| Portuguese | 52 | Beginner and developing practice |
| Spanish | 70 | Beginner and developing practice, plus an 18-lesson B1-oriented pilot in three units |

The Spanish pilot uses connected readings, multi-section synthesized listening, open writing and speaking tasks, and branching conversations. **B1-oriented describes curriculum design, not measured learner proficiency.** The pilot is still being verified; its lesson review ledger and iPhone walkthrough are not signed off. None of the five courses is native-speaker reviewed, certified, or a complete CEFR-level syllabus.

The app also includes placement suggestions, a Today path, a course browser, a phrasebook, an FSRS-based Review queue, five standalone Listen tracks, a Home Screen widget, deep links, Spotlight entries, Siri Shortcuts, accessibility settings, and a voluntary tip jar. Purchases unlock no lessons or features.

## Data, offline use, and sync

Lessons, review, and the five packs are bundled and work without a network connection. Learner progress lives in a local SQLite event log. The app derives lesson completion, review schedules, and skill-practice summaries from that log. Re-inserting an event ID with identical content is harmless; conflicting content is rejected.

The You tab can export learning data and restore a validated export after showing a preview. Exports include events, checkpoints, saved phrases and their deletion markers, Listen position, and placement recommendations. They exclude temporary recordings, device preferences, sign-in identity, and secrets. Restore merges into the local store in one SQLite transaction; it does not replace the database.

CloudKit mirror code exists, but **iCloud and Sign in with Apple capabilities are disabled in this build**. The app tells learners that progress is saved on this device and sync is unavailable. Simulated two-store merge tests exist; real two-device CloudKit sync has not been verified. Local use never depends on CloudKit.

Some persisted identifiers still use verbalibera: the verbalibera.sqlite database, keychain service com.sleuthysloth.verbalibera, and several UserDefaults keys. **Do not rename these without an explicit migration and upgrade test** or existing progress may become inaccessible. The app bundle ID remains com.sleuthysloth.condisco; the widget bundle ID is com.sleuthysloth.condisco.CondiscoWidget.

## Build and run

1. Open Condisco.xcodeproj in Xcode.
2. Select the shared Condisco scheme and an iOS 17+ simulator or iPhone.
3. Configure automatic signing for your Apple team if installing on a device, then build and run.

The project contains the app, CondiscoWidget, CondiscoTests, and CondiscoUITests targets. Its bundled Condisco/Content directory is an Xcode folder reference; keep the pack, media, and Listen-track paths intact. Personal-team builds do not include CloudKit entitlements.

## How it works

~~~text
Bundled pack → Lesson session → Evaluation → SQLite learning event
                                                ↓
                                    PackProgress projection
                                                ↓
                              Today · Review · Courses · Widget
~~~

Condisco/Engine contains the deterministic lesson and answer evaluators. Condisco/Store owns SQLite, event replay, FSRS scheduling, checkpoints, import validation, and pack loading. Condisco/Lesson, Home, Review, Listen, Onboarding, and You contain learner flows. Condisco/Sync contains the optional CloudKit mirror. CondiscoWidget is the extension; Condisco/Store/WidgetSnapshot.swift is shared between the app and extension and must remain Foundation-only.

Open writing and speaking tasks use a model response and a learner-facing self-check rubric. They are **not automatically marked correct or incorrect** by the fixed-answer engine. Recordings are temporary and disposable. Checkpoint and conversation events record practice evidence without turning lesson completion into a proficiency claim.

## Course content and audio

Each pack is a JSON file in Condisco/Content/packs. The schema decoder rejects unsupported kinds. When lesson metadata changes, regenerate Condisco/DeepLink/LessonCatalog.generated.swift:

~~~sh
python3 tools/gen_lesson_catalog.py Condisco/Content/packs \
  Condisco/DeepLink/LessonCatalog.generated.swift
~~~

The generated catalog must match the packs byte-for-byte. New lessons need stable IDs and a deliberate revision policy so an update does not discard old progress. docs/editorial-rubric.md has the authoring template and review rules; docs/skill-map.md maps the original A1/A2 units and records coverage gaps. The Spanish B1 pilot has a separate outline and review ledger under docs/reviews.

Audio provenance matters: **23 declared lesson assets intentionally use labeled on-device synthesized speech** (French 5, Italian 16, Spanish 2), listed in tools/device-speech-media.txt. One Italian lesson clip and five standalone synthesized Listen tracks are bundled. Spanish sustained passages use per-section on-device speech. Missing media outside the explicit fallback list fails validation. The five Listen tracks have file, hash, duration, and section checks; naturalness, device playback, lock-screen behavior, and recording recovery still need human iPhone checks. Do not describe synthesized audio as native recorded speech.

## Verification

Run the local gates from the repository root:

~~~sh
bash tools/check_packs.sh
bash tools/audit_editorial.sh --strict
python3 tools/audit_outcomes.py
bash tools/preflight.sh --with-ui
git diff --check
~~~

check_packs.sh validates pack structure, references, lesson reachability, media, provenance links, and authored task shapes. The strict editorial audit rejects falsely auto-graded open responses; its other counts are an editorial report. audit_outcomes.py checks that declared reading, listening, speaking, and writing claims have matching activities. preflight.sh also checks generated catalog drift and runs unit tests; --with-ui adds the simulator UI smoke. Run the full preflight on the **exact candidate tree** before sharing a build. GitHub Actions was removed by developer decision, so local preflight is the automated gate.

The current 273-lesson tree passed the full gate on 2026-09-26: **519 unit tests and 6 simulator UI tests**, with no failures. See docs/verification/2026-09-26-phase7-verification.md and its raw log. The gate covers code and content, while the final README and verification note were added afterward. docs/release-checklist.md lists remaining manual checks and docs/performance-budget.md separates simulator probes from unmeasured device performance.

## Known limits and next work

- Complete the Spanish pilot's per-lesson review records and walk it on an iPhone before describing it as a verified pilot. The other four courses do not have B1 paths.
- Run the owned-iPhone walkthrough: fresh and update installs, force-quit resume, offline use, audio and microphone behavior, VoiceOver, large text, and export to fresh-install restore. Physical-device results are still unverified.
- Measure launch, navigation, memory, audio start, and Listen battery on an iPhone before setting performance budgets. No learner outcome study or native-speaker review has been completed.
- Resolve the conversation open-turn reveal-state issue before relying on its independent-practice label: editing a draft can reset the in-memory model-reveal marker.
- Continue the solo improvement plan one reviewed unit at a time. The B1-oriented pilot is a first slice, not full B1 coverage; a B2 pilot and additional languages are future decisions.

The app stays usable without these future steps. Release claims should distinguish automated checks, simulator checks, physical-device checks, AI-assisted editorial review, and observations from actual learners.
