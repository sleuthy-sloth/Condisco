# Condisco

Condisco is a native iOS language-learning app: SwiftUI, iOS 17+, zero third-party
dependencies. All five course packs (French, Italian, German, Portuguese, Spanish)
ship bundled in the app; there is no server. The app keeps learner progress in a
local SQLite store and mirrors it to CloudKit as a background copy when the learner
signs in with Apple. Everything else — placement, spaced repetition, review,
flashcards, a Home widget — is derived from that local store.

This is a **port of a sibling web app that is not in this repository.** The Engine
files say so themselves: `LessonSession.swift` is a "faithful port of the web app's
`lesson-session.ts`", `AnswerEngine.swift` of `answer.ts`, and
`ActivityEvaluation.swift` of `activity-evaluation.ts`. `Models/CoursePack.swift`
mirrors `schema-v2.ts`, and `LearningStore`'s projection "mirrors
`projectLessonEvidence`". If you change behavior here, the web repo likely needs the
same change mirrored.

## The naming trap

The directory is `VerbaLibera`, but the product is **Condisco**:

- Xcode project and product: `Condisco` (`Condisco.xcodeproj`, app bundle id
  `com.sleuthysloth.condisco`).
- Widget extension bundle id: `com.sleuthysloth.condisco.CondiscoWidget`; shared
  App Group `group.com.sleuthysloth.condisco`.
- **Legacy `verbalibera` identifiers survive in runtime data.** The SQLite database
  is `verbalibera.sqlite` (Documents dir), the keychain service is
  `com.sleuthysloth.verbalibera`, and several UserDefaults keys are
  `verbalibera.*` (`verbalibera.a11y.largeText`, `verbalibera.sync.lastSyncedAt`,
  `verbalibera.appleDisplayName`, `verbalibera_listen_position:`, …).

Do not "clean up" the legacy identifiers: renaming the database file or keychain
service would silently strand every existing learner's progress. There is no data
migration for them — they are deltas of a name, not a bug.

## Building & running

Open `Condisco.xcodeproj` in Xcode, select the shared **`Condisco`** scheme, and run
on a simulator or device with automatic signing. Minimum deployment target is
iOS 17.0. The project has four targets:

1. **Condisco** — the app.
2. **CondiscoWidget** — the Home screen widget extension.
3. **CondiscoTests** — unit tests, sources in `Condisco/Tests/`.
4. **CondiscoUITests** — UI tests, sources in `Condisco/UITests/`.

CloudKit and Sign in with Apple are wired in code but their entitlements are
**commented out** in `Condisco/Condisco.entitlements` (the file only declares the
App Group). The comment there explains why: a personal-team build cannot use the
iCloud/apple-signin capabilities; re-add them once the project is enrolled in the
paid Apple Developer Program. Until then sync and sign-in degrade gracefully.

## Repository layout

Everything lives under `Condisco/`, organized by feature:

- **`Models/`** — `CoursePack.swift`, the decode-only v2 pack models (see
  "Working on content"). Never encoded on device.
- **`Engine/`** — the pure evaluation core: `LessonSession` (session reducers),
  `AnswerEngine` (text matching), `ActivityEvaluation` (per-activity grading).
  No storage, clocks, or randomness; fully deterministic.
- **`Store/`** — persistence: `Database` (a minimal raw-SQLite3 wrapper),
  `LearningStore` (the event log, projection, checkpoints, phrasebook, key/value),
  `Fsrs` (FSRS v6 spaced repetition), `PackLoader` (bundled packs), and
  `WidgetSnapshotWriter`.
- **`Lesson/`** — the lesson player UI (`LessonPlayerView` plus activity views,
  glossary, vocabulary browser, phrasebook) and the Courses list.
- **`Home/`, `Listen/`, `Review/`, `You/`** — the other tabs, plus `Theme/`
  (`DesignTokens` — a warm "studio" palette — and `A11ySettings` accessibility
  toggles) and `Onboarding/` (welcome flow + placement test).
- **`Sync/`** — `CloudKitSync`, a background mirror of the local store.
- **`Auth/`** — `AppleSignIn`, keychain-backed.
- **`DeepLink/`** — the URL router (`DeepLink.swift`), Spotlight indexing
  (`SpotlightIndex.swift`), Siri Shortcuts intents (`CondiscoIntents.swift`), and
  `LessonCatalog.generated.swift` (see below).
- **`Content/`** — bundled packs, audio, images, and listen tracks. Declared as an
  Xcode **folder reference**, so its layout is copied verbatim into the bundle,
  mirroring the web repo's `public/`.
- **`CondiscoWidget/`** — the widget extension target.
- **`tools/`** — pack validation and generation scripts (see below).
- Supporting files: `CondiscoApp.swift` (entry point), `ContentView.swift` (tabs +
  navigation), `Condisco.entitlements`, `Condisco.storekit`, `Previews/` (App Store
  preview images), `Condisco/ArtworkStage/` (app-icon source artwork).

## Architecture

Condisco's centerpiece is an **append-only event log as the single source of
truth**:

```
LessonPlayerView ──► Engine (pure evaluation) ──► LearningStore.record() ──► SQLite `events`
                                                          │
                                                          ▼
                                      project(pack:) replays events ──► PackProgress
                                                          │
                              (FSRS state, completions, skill counts, …)
                                                          ▼
                                    Home · Review · Widget · CloudKit
```

The player never persists derived state. A lesson submission flows through the
pure engines and into `LearningStore.record(_:)`, which appends one row to the
SQLite `events` table. `project(pack:)` then replays those rows into a
`PackProgress` — FSRS state per evidence key, completed lessons, skill counts —
and every UI surface (Home, Review, the widget, even CloudKit's copy) is a
consumer of that projection. Events are idempotent on insert: a duplicate id with
identical payload is a no-op, a conflicting one throws. This is also what makes
cross-device sync safe — the log merges, and projections are recomputed locally.

Every entry point lands in the same player. Deep links (`condisco://continue`,
`condisco://lesson/<packId>/<lessonId>`, `condisco://review`,
`condisco://phrasebook`), Spotlight results, and Siri Shortcuts all funnel through
`DeepLinkRouter` in `ContentView`, which presents the same `LessonPlayerView` as
any in-app lesson.

One file to be careful with: **`Store/WidgetSnapshot.swift` is compiled into both
the app target and the widget extension**, and must stay Foundation-only — no
SwiftUI, no WidgetKit, no app modules. The app writes the snapshot to the shared
App Group and the widget reads it.

## Working on content

Course content is JSON, authored in the web repo's format:

1. Edit the packs in `Condisco/Content/packs/*.json` (one per language).
2. Validate offline with `./tools/check_packs.sh` — it compiles the *real* model
   and store code with `xcrun swiftc` and decodes every pack, so a pack cannot
   drift from the Swift types.
3. Audio comes from `tools/render_cafe_audio.py` (the café-scenario clips the
   packs reference); images live under `Content/images/`.
4. Regenerate the Siri/Shortcuts lesson picker catalog when lessons change:

   ```
   python3 tools/gen_lesson_catalog.py Condisco/Content/packs \
       Condisco/DeepLink/LessonCatalog.generated.swift
   ```

   `LessonCatalog.generated.swift` is a **generated file — never hand-edit it**.
   The script reproduces the committed file byte-identically.

Packs use `schemaVersion` 2, enforced in the `CoursePack` decoder (it throws on
anything else). Five packs: `french`, `italian`, `german`, `portuguese`, `spanish`.

## Conventions

- **File-header comments are the spec.** They carry invariants the code relies on —
  "the caller persists events between `submitResponse` and `advanceLesson`;
  advancing never writes", "engine evaluates before recording", "WidgetSnapshot
  must stay extension-safe". Read them before editing a file.
- **Best-effort, silent failures.** Spotlight indexing, deep links, and widget
  refresh never surface errors to the learner — a missed refresh just leaves the
  last good state in place until the next change. Match that when touching those
  paths.
- **UI tests opt in to a blank slate.** `FirstRunUITests` launches with
  `--condisco-ui-test-reset`, which wipes UserDefaults and deletes
  `verbalibera.sqlite*`. It is `#if DEBUG`-only and never part of a normal launch.
- **The app is fully free.** StoreKit purchases are a tip jar — `Condisco.storekit`
  defines three non-consumable "support" products (Espresso, Cappuccino, Feast)
  whose descriptions literally say they unlock nothing. All features are available
  without any purchase.
- **Packs load once per process.** `PackLoader.loadPacks()` caches its result
  (success *or* failure) in a lazy static — the five packs are ~4 MB of JSON and
  are immutable at runtime, so the cache is safe and thread-safe under
  `swift_once`.

## Testing

Unit tests live in `Condisco/Tests/` (target `CondiscoTests`); the UI
end-to-end flow lives in `Condisco/UITests/` (target `CondiscoUITests`):

- **`PlacementTests.swift`** — placement math (weighted scoring, victory-lap
  clamping) and accent-tolerance cases for `AnswerEngine`, plus two
  `LessonContextTests` that load the real French pack through `PackLoader` and
  check story-stimulus selection.
- **`EngineTests.swift`** — deterministic grading decisions (`AnswerEngine`:
  exact match, tolerance, alternatives, authored errors, typo forgiveness).
- **`StoreTests.swift`** — `LearningStore` event-log persistence against a
  throwaway SQLite file per test.
- **`Pack{French,Italian,German,Portuguese,Spanish}Tests.swift`** — per-pack
  editorial regression tests, one file per bundled language.
- **`Condisco/UITests/FirstRunUITests.swift`** — one end-to-end flow: fresh
  install, onboarding, placement, first lesson (including an accent-missing
  answer), leaving and resuming mid-lesson.

Run the unit tests on the simulator (scheme `Condisco`, test target
`CondiscoTests`; UI tests live in target `CondiscoUITests`):

```
xcodebuild test -project Condisco.xcodeproj -scheme Condisco \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:CondiscoTests \
  ONLY_ACTIVE_ARCH=YES
```

### Automated gates and reports

- `bash tools/check_packs.sh` — pack + media integrity gate: compiles the real
  production model with `xcrun swiftc`, decodes all five packs, and verifies
  every declared media asset (existence, type, SHA-256); the 21 intentional
  device-speech assets are allowlisted in `tools/device-speech-media.txt`. Exits
  non-zero on any problem.
- `bash tools/audit_editorial.sh` — editorial backlog report (missing authored
  error feedback, generic-only hints, ungraded activities, mission/story
  final-response gaps). Report-only: exits 0 whenever the packs load; the counts
  are a backlog, not a gate. `--strict` additionally exits 1 on
  objectively-enforceable violations (open-ended prompts falsely auto-graded) —
  that is what the CI workflow runs.
- `bash tools/preflight.sh` — the **pre-share gate**: runs `check_packs.sh`,
  the editorial audit, a byte-identical regeneration check of
  `LessonCatalog.generated.swift`, and the unit tests above (plus the UI smoke
  with `--with-ui`). Stops on the first failure and exits non-zero on any
  required failure. Run it before sharing a build — see
  `docs/release-checklist.md` for the full manual checklist:

  ```sh
  bash tools/preflight.sh            # required steps
  bash tools/preflight.sh --with-ui  # + UI smoke — REQUIRED before any external share
  ```

  The UI smoke is what the 2026-09-25 baseline caught failing (a stale Home
  string broke `FirstRunUITests`); the Phase 1 and Phase 2 runs after the fix
  both end in `PREFLIGHT PASSED` (logs below).

The check-packs tool is the real content safety net; the unit tests cover the pure
scoring/engine math that needs no fixtures. `preflight.sh` is the single entry
point before any share.

### Verification evidence

All gate runs are logged under `docs/verification/`, named by date and phase, so
a claim like "preflight green" is traceable to a recorded exit code:

- `2026-09-25-baseline.md` (+ `2026-09-25-baseline-preflight-with-ui.log`) —
  pre-fix state: steps 1–4 green, UI smoke FAIL, preflight exit 1.
- `2026-09-25-phase1-preflight-with-ui.log` — post-fix: all five steps PASS
  (unit suite 123 tests / 0 failures; UI 1/1), `PREFLIGHT PASSED`, exit 0.
- `2026-09-25-phase2-preflight-with-ui.log` — rerun: all five steps PASS
  (unit suite 127 tests / 0 failures; UI 1/1), `PREFLIGHT PASSED`, exit 0.

The **editorial review log** lives at `docs/reviews/review-log.jsonl` — one
disposition row per lesson (255 rows; all currently `unreviewed`, with the
in-progress batch-1 dispositions in per-pack files under
`docs/reviews/review-log/`). Review to date is AI-assisted/developer-led only.

**Continuous integration:** `.github/workflows/ci.yml` runs the same four checks
— pack/media integrity, the editorial audit with `--strict`, the generated
catalog drift check, and the `CondiscoTests` unit tests — on every push and pull
request. It uses no secrets and does not run the UI tests (simulator flakiness;
local `preflight.sh --with-ui` covers them).

### Honest limitations

What has **not** been verified yet — do not claim otherwise in releases,
screenshots, or store copy:

- **Native-speaker review is pending.** All content edits so far are
  AI-assisted/developer-reviewed only; nothing has been certified by a native
  speaker, and no pack claims complete A1/A2 coverage or full proficiency.
- **Listening audio is synthesized course voice.** The 21 device-speech
  fallback steps ship without bundled audio (allowlisted in
  `tools/device-speech-media.txt`) and all 5 bundled Listen tracks are TTS with
  `reviewPending`; human listening review remains open
  (see `docs/audio-provenance/`).
- **No physical-device, performance, or battery evidence is recorded yet.** The
  gates above are simulator/automation evidence only; on-device audio,
  battery, and performance are unmeasured (see `docs/performance-budget.md`).
- **Learner-outcome measures are unverified.** No usability sessions or
  outcome study has been run.

## Where to start

- `Condisco/ContentView.swift` — the tab scaffold and the single routing point for
  deep links, Spotlight, and the onboarding-triggered lesson.
- `Condisco/Store/LearningStore.swift` — the event log, `record(_:)`, and
  `project(pack:)`; the heart of the architecture.
- `Condisco/Lesson/LessonPlayerView.swift` — the player; start at `boot()` (session
  resume/checkpoint logic) and `handleSubmit` (the evaluate-then-record path).
- `Condisco/Engine/LessonSession.swift` — the pure session reducer that everything
  above drives.

Then run `./tools/check_packs.sh` after any pack edit, and keep the web repo's
engine sources in view when changing behavior here.