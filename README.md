# Condisco

Condisco is a free, offline-first iPhone app for practising useful language in context. It combines short lessons, stories, real-world missions, spaced review, listening, and self-assessed speaking and writing. The app uses SwiftUI, targets iOS 17+, and has no third-party runtime dependencies or required account.

This repository is the **native iOS app**. The earlier VerbaLibera web app is preserved in the web-legacy branch. The iOS app is the active product; some web-era storage identifiers remain to preserve learner progress.

## Current scope

Five bundled course packs contain **309 lessons**:

| Course | Lessons | Current scope |
| --- | ---: | --- |
| French | 50 | Beginner and developing practice |
| Italian | 49 | Beginner and developing practice |
| German | 52 | Beginner and developing practice |
| Portuguese | 52 | Beginner and developing practice |
| Spanish | 106 | Beginner and developing practice, a 48-lesson B1-oriented path across eight units, plus a 6-lesson B2-oriented pilot unit |

The Spanish B1-oriented path (units 18–25) uses connected readings, multi-section synthesized listening, open writing and speaking tasks, and branching conversations. **B1-oriented describes curriculum design, not measured learner proficiency.** The path is still being verified; its lesson review ledger and iPhone walkthroughs are not signed off. Unit 26 is a six-lesson **B2-oriented pilot** on the same rule: B2 is a design reference for task complexity, not a claim the app certifies any level, and the developer's usefulness verdict on the pilot is still open. None of the five courses is native-speaker reviewed, certified, or a complete CEFR-level syllabus.

The Courses tab offers **Foundation, Developing, and Independent** as browsable content paths. Selecting a path shows only courses with lessons there, then opens a lesson list and search scoped to that path; the ordinary course card still shows its full course and vocabulary. These names organize lesson content, not learner ability. The first café mission in each course has 12 steps. The French, German, Italian, and Portuguese missions now each add a distinct listening decision and a self-assessed spoken reply, alongside the Spanish mission's listening sequence.

The app also includes placement suggestions, a Today path, a course browser, a phrasebook, an FSRS-based Review queue, five standalone Listen tracks, a private practice library, a Home Screen widget, deep links, Spotlight entries, Siri Shortcuts, accessibility settings, and a voluntary tip jar. Brief word-ordering and lesson-recap motion respects Reduce Motion. Purchases unlock no lessons or features.

## Data, offline use, and sync

Lessons, review, and the five packs are bundled and work without a network connection. Learner progress lives in a local SQLite event log. The app derives lesson completion, review schedules, and skill-practice summaries from that log. Re-inserting an event ID with identical content is harmless; conflicting content is rejected.

The You tab can export learning data and restore a validated export after showing a preview. The current export format is version 2. Exports include events, checkpoints, saved phrases and their deletion markers, Listen position, placement recommendations, and imported library documents with their phrase links. They exclude temporary recordings, device preferences, sign-in identity, and secrets. Restore merges into the local store in one SQLite transaction; it does not replace the database. Older exports remain readable.

The practice library accepts pasted or imported plain text, capped at 1 MB. Learners can select a passage, save a phrase, and review it through the existing FSRS queue. Documents stay in the local store and are included in a user-initiated export; they do not enter CloudKit, the widget, or Spotlight. Deleting a document removes its local text and links without erasing saved phrases or unrelated learning events. The library has no audio-file import yet.

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

Condisco/Engine contains the deterministic lesson and answer evaluators. Condisco/Store owns SQLite, event replay, FSRS scheduling, checkpoints, import validation, library documents, and pack loading. Condisco/Lesson, Home, Review, Listen, Onboarding, and You contain learner flows. Condisco/Models/CoursePack.swift holds the five-course metadata registry used by loading, voice selection, and display helpers. Condisco/Sync contains the optional CloudKit mirror. CondiscoWidget is the extension; Condisco/Store/WidgetSnapshot.swift is shared between the app and extension and must remain Foundation-only.

Open writing and speaking tasks use a model response and a learner-facing self-check rubric. They are **not automatically marked correct or incorrect** by the fixed-answer engine. Recordings are temporary and disposable. Checkpoint and conversation events record practice evidence without turning lesson completion into a proficiency claim. A revealed model in a conversation stays marked through draft edits and checkpoint resume, so that turn cannot later be treated as independent practice.

## Course content and audio

Each pack is a JSON file in Condisco/Content/packs. The schema decoder rejects unsupported kinds. When lesson metadata changes, regenerate Condisco/DeepLink/LessonCatalog.generated.swift:

~~~sh
python3 tools/gen_lesson_catalog.py Condisco/Content/packs \
  Condisco/DeepLink/LessonCatalog.generated.swift
~~~

The generated catalog must match the packs byte-for-byte. Lesson and activity IDs stay stable across updates; changed content gets a new revision so old attempts are not treated as evidence for the new version. An updated mission may therefore ask a returning learner to complete it again. docs/editorial-rubric.md has the authoring template and review rules; docs/skill-map.md maps all current units and records coverage gaps. The Spanish B1 path and B2 pilot have outlines, source notes, and a review ledger under docs/reviews.

Audio provenance matters: **31 declared lesson assets intentionally use labeled on-device synthesized speech** (French 7, Italian 18, German 2, Portuguese 2, Spanish 2), listed in tools/device-speech-media.txt. The four new café exchanges and their response models are among them; their provenance records live under docs/audio-provenance, and naturalness review is pending. One Italian lesson clip and five standalone synthesized Listen tracks are bundled. Spanish sustained passages use per-section on-device speech. Missing media outside the explicit fallback list fails validation. The five Listen tracks have file, hash, duration, and section checks; naturalness, device playback, lock-screen behavior, and recording recovery still need human iPhone checks. Do not describe synthesized audio as native recorded speech.

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

The latest local full preflight for the 309-lesson tree passed on 2026-09-27: **576 unit tests and 8 simulator UI tests**, with zero failures. One UI case skips its search-field interaction when the simulator does not expose the inline search drawer to automation; the scoped-search rule also has a unit test. This is automated and simulator evidence, not a physical-device, native-speaker, or learner-outcome review. docs/release-checklist.md lists remaining manual checks and docs/performance-budget.md separates simulator probes from unmeasured device performance.

## Known limits and next work

- Review the Spanish B1 path and B2 pilot on an iPhone before describing either as verified. Their AI-assisted lesson ledger has rows 1–54; native review and developer sign-off remain pending. The other four courses do not have B1 paths.
- Run the owned-iPhone walkthrough: fresh and update installs, force-quit resume, offline use, audio and microphone behavior, VoiceOver, large text, and export to fresh-install restore. Physical-device results are still unverified.
- Walk the practice library from import through phrase review, document deletion, and fresh-install restore on an iPhone. The developer's usefulness verdict for the B2 pilot is also open.
- Measure launch, navigation, memory, audio start, and Listen battery on an iPhone before setting performance budgets. No learner outcome study or native-speaker review has been completed.
- Complete the dated Phase 7.2 self-study and delayed retest before deciding which lesson patterns to replicate. The B1-oriented path and B2-oriented pilot are curriculum slices, not full-level coverage. A sixth language remains a developer decision; none is bundled.

The app stays usable without these future steps. Release claims should distinguish automated checks, simulator checks, physical-device checks, AI-assisted editorial review, and observations from actual learners.
