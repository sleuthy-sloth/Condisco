# Condisco completion plan for the next AI worker

> **For the next AI worker:** Execute this plan in order in the existing checkout. Preserve the current uncommitted work. Do not mark a phase complete because its code exists; run its gate and record the result. Use small, reviewable commits after each green task. Do not create a native-speaker review claim or a proficiency claim.

**Goal:** Close the gaps in the [quality and growth plan](2026-09-25-condisco-quality-and-growth.md) so Condisco is reliable, honest about course quality, usable offline, and ready for a solo developer to share with testers.

**Starting state (2026-09-25):** The pack/media check and unit suite pass. The first-run UI test fails after Home changed from “Continue learning” to “Today” (`Condisco/UITests/FirstRunUITests.swift:25`). The editorial audit reports 1,743 graded steps without authored hints and 880 feedback gaps; its open-ended grading check passes. Twenty-one declared lesson recordings are absent and explicitly served by device speech. Five standalone Listen tracks have files. Native review, physical-device checks, usability sessions, performance measurements, and release sign-offs have no completed records. The working tree has many uncommitted changes, including the previous AI worker's implementation and the three fixes from the latest review.

**Architecture:** Keep the existing local SQLite event log and FSRS projection as the source of truth. Improve content, UI, playback, and release checks around that core. Use AI-assisted editorial review with traceable evidence and conservative product copy; it cannot substitute for native-speaker validation.

**Tech stack:** SwiftUI and AVFoundation, iOS 17+, SQLite, CloudKit, Xcode XCTest/XCUITest, bundled JSON packs, Swift/Python shell tools. Do not add third-party runtime dependencies or a backend.

## Global constraints

- The developer is solo and has no native speakers available. Remove native-speaker review as a *required completion dependency* for this release; replace it with the AI-assisted protocol below and disclose its limits. Never record an AI worker as a native reviewer.
- Preserve `verbalibera.sqlite`, the keychain service, existing event IDs, pack/lesson/step IDs, and legacy UserDefaults keys. Any migration requires an explicit upgrade test.
- Keep lessons and Listen usable offline. CloudKit is optional and must not block local progress.
- Recordings made in the app stay disposable and local. Do not add pronunciation scores, a community service, analytics, or remote AI calls to the learner flow.
- Do not bulk-fill hints or feedback with generic templates to make the audit green. Each authored line must match its actual prompt, answer, and likely mistake.
- Do not call a pack “native reviewed,” “certified,” “complete A1/A2,” or “full proficiency” unless independent evidence exists. CEFR topic mapping may be described as coverage, with gaps disclosed.
- A passing automated test is not evidence of real-device audio, battery behavior, language naturalness, or learner comprehension.

**What the worker can finish alone:** code, tests, simulator checks, media inventory, documented AI-assisted editorial passes, and conservative copy. **What still requires outside observation:** physical-iPhone behavior and real learner outcomes. Without native speakers, the release can be honestly described as AI-assisted and developer-reviewed; it cannot be described as native-reviewed. These limits remain open in the final gate report rather than being converted into fictional sign-offs.

## Solo-developer editorial policy

1. Use `docs/editorial-rubric.md` and `docs/skill-map.md` as the checklist, but change the review record schema from an implied native sign-off to an explicit `reviewMethod` (`AI-assisted`, `developer`, or `external-human`), model/tool version where applicable, date, sources checked, disposition, and unresolved questions. Keep the existing attribution's “native-speaker review pending” where true.
2. For each lesson, review the source JSON and its actual runtime path. Check grammar, register, regional variant, plausible situation, prompt/accepted-answer alignment, hints, wrong-answer feedback, and story/mission outcome. Use at least two independent checks for a disputed linguistic claim (for example, authoritative dictionary/grammar references plus a separate AI critique). Record exact source links and step IDs. Do not let two models agreeing count as proof of naturalness.
3. Resolve a high-confidence error in the pack with a focused test. If the evidence is mixed, narrow the accepted claim or remove the risky line. Mark unresolved naturalness/pronunciation issues as `needs external review`; do not silently pass them.
4. Review in this order: first two units of all five packs, all 40 missions, all 36 stories, then remaining lessons. Track every one of the 255 lessons in a machine-readable review log. A lesson is `pass` only if its rubric checks are complete; `needs-work` keeps its pack out of the release-quality claim.
5. Native speech is unavailable for 21 lesson assets. Keep their clearly labeled device-speech alternative and test it on device. Do not synthesize an MP3 and present it as a reviewed human recording. Check the five bundled Listen tracks against transcripts and attribution separately.

## Execution order and gates

### 0. Stabilize the inherited worktree

**Files:** `Condisco/`, `Condisco/Tests/`, `Condisco/UITests/`, `docs/`, `tools/`, `Condisco.xcodeproj/`.

- [ ] Capture `git status --short`, branch, and `git diff --stat`. Identify which changes are product work, generated output, and personal Xcode UI state. Preserve all user work; stage only intended files in later commits.
- [ ] Run `bash tools/check_packs.sh`, `bash tools/audit_editorial.sh`, the unit suite, and the UI suite. Save dated command, exit code, and failures in `docs/verification/`; create the directory. Compare documentation claims with these fresh results.
- [ ] Correct stale status notes, especially `docs/engineering-findings.md` where corrupt-row reads are still described as fatal despite the new tolerant paths. Keep any genuinely open corrupt-row, sync, or performance risk in the log.

**Gate:** A reproducible baseline exists. No prior uncommitted product change is discarded, and no failing test is described as passing.

### 1. Restore the automated trust gate (P0)

**Files:** `Condisco/UITests/FirstRunUITests.swift`, `Condisco/Home/HomeView.swift`, `Condisco/ContentView.swift`, `Condisco/DeepLink/DeepLink.swift`, `Condisco/Tests/EngineTests.swift`, `Condisco/Tests/StoreTests.swift`, `tools/preflight.sh`.

- [ ] Repair the first-run UI test against the current “Today” layout. Keep its meaningful journey assertions: onboarding, opening the first mission, wrong answer and accent correction, assisted continuation, kill/relaunch resume, and Review navigation. Fix app defects revealed by the test; do not simply delete failing assertions. Run `-only-testing:CondiscoUITests -parallel-testing-enabled NO` until green.
- [ ] Make `condisco://continue` lesson selection testable through a pure resolver or injected store seam. Replace `NextLessonTests.testContinueDeepLinkResolutionRequiresStoreSeam`'s unconditional skip with tests for partial, complete, and orphaned packs; confirm Home, widget, and deep link use the same completed set.
- [ ] Re-run local duplicate inserts, reordered JSON, replay, conflict, and two-temp-database merge tests. Add or retain a test that a corrupt local event does not stop projection or sync while its ID remains observable. Do not change event identity or storage paths.
- [ ] Run `bash tools/preflight.sh --with-ui` after the above; fix any catalog drift, pack failure, compile issue, or UI regression. Make the UI check required for any candidate build shared externally, even if the developer keeps it optional during daily edits.

**Gate:** `check_packs.sh`, unit tests, catalog regeneration, and the first-run UI smoke all pass in one preflight run; the deep-link skip is gone.

### 2. Finish media integrity and audio truthfulness (P0, P3)

**Files:** `Condisco/Content/packs/*.json`, `Condisco/Content/listen-tracks/*.json`, `Condisco/Content/audio/`, `Condisco/Lesson/StimulusViews.swift`, `Condisco/Listen/ShadowMode.swift`, `Condisco/Lesson/LessonMoments.swift`, `Condisco/Listen/ListenModels.swift`, `Condisco/Listen/ListenView.swift`, `tools/check_packs.swift`, `tools/device-speech-media.txt`, `docs/audio-provenance/`.

- [ ] Keep the exact 21-entry fallback allowlist auditable. For each entry, verify the referenced step has a nonempty transcript, audible device speech, a visible/VoiceOver synthesized label, a working Stop control, and no broken recording control. Any new missing media must fail validation unless explicitly authored as a speech fallback.
- [ ] Check all five Listen files: existence, file type, hash, true duration, transcript section boundaries, silence/clipping, offline playback, normal/slow replay, lock-screen controls, and background continuation. Preserve the recent `defaultRate` and section-boundary fixes with a regression test using final and untargeted sections.
- [ ] Resolve the missing Italian market provenance reference: supply the actual provenance record only if evidence is available; otherwise remove or correct the citation and state what is known. Never invent a speaker or recording source.
- [ ] Ensure every TTS surface has accurate screen-level or control-level provenance. Remove “native voice” wording where playback is synthesized. Test mic denied/allowed, disposal of temporary recordings, and audio-session recovery after record/compare.

**Gate:** Zero unresolved non-allowlisted asset references; five Listen tracks validate; French and Italian device-speech lessons and one Listen track work on a real iPhone. If no iPhone is available to the AI worker, record simulator results and leave this gate explicitly open for the developer.

### 3. Repair and review course content (P1)

**Files:** `Condisco/Content/packs/*.json`, `docs/editorial-rubric.md`, `docs/native-review-kit.md`, `docs/skill-map.md`, new `docs/reviews/review-log.csv` or JSONL, `tools/audit_editorial.swift`, `tools/audit_editorial.sh`, `Condisco/Tests/`.

- [ ] Build a stable, machine-readable per-lesson audit from the existing report: pack/unit/lesson/step/activity IDs, missing hint, generic feedback, missing final response, ungraded type, and open-ended grading flags. Keep the current report readable; add a strict mode only for checks the worker can genuinely enforce.
- [ ] Apply the solo-developer editorial policy above in batches. First correct the first two units per language; then missions and stories; then every remaining lesson. Each batch gets a review-log disposition, pack JSON changes, targeted answer/evaluation tests, `check_packs.sh`, and the editorial audit. Do not leave an entire lesson passed when one of its steps is unresolved.
- [ ] Author helpful, specific hints for the 1,743 currently gap-marked graded steps and error-specific feedback for the 880 currently flagged surfaces. Prefer a shorter, narrower prompt or a typed choice over pretending arbitrary free production can be checked by a fixed string list. Keep the open-ended false-auto-grade count at zero.
- [ ] Complete the skill map for every unit, including real-world act, evidence for each of reading/listening/speaking/writing, prerequisite, and revisit point. Mark missing skills honestly. Reconcile pack descriptions and browser copy with mapped coverage; remove unverified certification or full-syllabus wording.
- [ ] Revise the original quality plan's P1 exit gate, `docs/native-review-kit.md`, and the release checklist to name the achievable solo editorial gate precisely. Preserve “native review pending” as a limitation, and ensure no document describes AI review as native review.
- [ ] Review and correct the five standalone Listen transcripts and high-value mission phrases using the same review log. Record uncertain pronunciation and register separately from grammatical correctness.

**Gate:** Every lesson has a review-log disposition; first two units and all missions/stories pass the solo editorial rubric. Full P1 completion requires all 255 shipped lessons to pass it. A `needs-work` lesson keeps P1 open; a beta build must identify that limitation and avoid a quality or level claim for it. The audit has zero false-auto-graded open prompts and zero unaddressed hint/feedback gaps in lessons marked pass. No native-review claim is added.

### 4. Verify the daily path and accessibility (P2, P4)

**Files:** `Condisco/Home/HomeView.swift`, `Condisco/Lesson/LessonPlayerView.swift`, `Condisco/Lesson/LessonMoments.swift`, `Condisco/Review/ReviewModels.swift`, `Condisco/Review/ReviewView.swift`, `Condisco/Lesson/CoursesView.swift`, `Condisco/Store/WidgetSnapshotWriter.swift`, `Condisco/UITests/`.

- [ ] Exercise Today selection for fresh, resumed, due-review, path-complete, and no-content states. Confirm Home's five-card invitation actually preselects five; direct Review entry retains its chosen/default size. Review data must derive from the existing projection, with no competing persisted counter.
- [ ] Exercise warm-up selection and verdict recording: at most two overdue earlier ideas, no duplicate evidence key, no immediate same-question repeat, no interruption of a resumed lesson. Refresh the widget due count after a warm-up verdict as the Review tab already does.
- [ ] Check the recap against real attempts: goal, outside phrase, useful correction, independent/practiced distinction, next step. Save source pack/lesson IDs on mission recap phrases so phrasebook navigation works.
- [ ] On small iPhone, landscape iPhone, iPad, largest Dynamic Type, VoiceOver, and Reduce Motion, verify answer/feedback visibility, reachable keyboard-open action, context disclosure, touch targets, labels/order, and no clipped controls. Fix failures in the owning screen and add focused UI tests for repeatable cases.

**Gate:** The first mission and a five-card review session complete one-handed on a small iPhone; no required feedback or action is hidden. Accessibility results are recorded by device/settings. Simulator evidence is labeled simulator-only.

### 5. Harden storage, offline use, and releases (P4)

**Files:** `Condisco/Store/LearningStore.swift`, `Condisco/Store/PackLoader.swift`, `Condisco/Sync/CloudKitSync.swift`, `Condisco/Tests/StoreTests.swift`, `Condisco/CondiscoApp.swift`, `docs/performance-budget.md`, `docs/release-checklist.md`, `README.md`, `tools/preflight.sh`, optional `.github/workflows/`.

- [ ] Run upgrade drills with a database and checkpoint made by the previous build, force-quit/resume, airplane-mode lesson/review/Listen, offline-to-online replay, and a two-store simulated merge. On a second signed-in device, run a real CloudKit merge if the developer has the paid capabilities; otherwise document that the CloudKit device gate is unavailable and keep local progress as the release guarantee.
- [ ] Recover from one malformed bundled pack without hiding the other four. Return a visible, nonfatal content error for that course, keep local progress untouched, and add a malformed-pack test. Keep raw-log export fail-loud on corrupt stored rows; tolerant UI/sync reads must surface skipped IDs.
- [ ] Add measurement points for Home/Review projection, widget refresh, and repeated lesson navigation. Measure cold launch, pack load, memory, navigation, and Listen battery on the oldest accessible supported iPhone. Put actual device/build/median values in `docs/performance-budget.md` before setting budgets; simulator timings may guide debugging but are not battery evidence.
- [ ] Keep `README.md` and `docs/release-checklist.md` aligned with reality. Add a no-secret CI workflow for pack/media validation, generated catalog consistency, and unit tests if a macOS runner is available; document a local preflight command regardless. Run UI smoke before sharing any candidate build.
- [ ] Bump app and widget version/build together, archive the candidate, run a clean install and update install, and complete every release-checklist sign-off with actual results. Do not convert a blank row into a pass by assumption.

**Gate:** No lost progress in the tested upgrade/offline/replay paths; malformed content cannot disable every course; a dated performance table and release checklist exist. Physical-device and CloudKit results are labeled with the actual device/capability used.

### 6. Validate learning outcomes without native-speaker access

**Files:** `docs/first-slice-verification.md`, `docs/learning-feedback-plan.md`, new dated session notes under `docs/usability/` with participants anonymized.

- [ ] Recruit five adult beginners for short first-mission/story sessions; they need not speak the target language natively. Ask them to complete tasks without coaching, identify a correction after a wrong answer, and name the next Home action. Include one large-text user if available. Obtain consent and record only observations and quotes; no learner recordings or raw answers.
- [ ] Invite the same learners one week later to produce or recognize one earlier phrase before seeing the model. Record successes, misses, and confusing prompts. Treat this as formative evidence, not proof of proficiency.
- [ ] If no outside testers are available, perform the documented solo device walkthrough and accessibility audit, but leave task-success, clarity, and delayed-recall acceptance measures **unverified**. An AI simulation is useful for finding possible UI problems, not evidence that learners succeeded.

**Gate:** The plan's outcome measures have dated observations, or the release note explicitly lists them as unverified. No streak/time-in-app metric substitutes for them.

## Final release decision

The next worker must end with a concise gate report: command and result for pack/media validation, editorial audit, catalog check, unit tests, UI smoke; exact device/build and result for audio, accessibility, upgrade/offline, and performance; count of editorial `pass`/`needs-work`/unreviewed lessons; number of usability sessions; and every remaining limitation. A candidate may be shared with external testers only when automated gates and real-device progress/media checks pass. If learner sessions remain unavailable, label outcome measures unverified. Do not call the original quality plan “complete” while any exit gate is blank.

## Paste into the next AI worker's task

> Work in `/Users/spkoehl/Projects/VerbaLibera`. Read `docs/roadmaps/2026-09-25-condisco-next-worker-closure-plan.md` and the linked quality plan. Preserve the current uncommitted changes. Execute tasks in order, recording evidence after each gate. Start by fixing the failing first-run UI test and running preflight with UI. I am a solo developer without native speakers: use the plan's AI-assisted editorial protocol, keep language claims conservative, and never mark content native-reviewed. Continue through the AI-completable tasks; clearly list physical-device, CloudKit, or learner-session gates I must perform. Do not claim completion from code or documentation alone.
