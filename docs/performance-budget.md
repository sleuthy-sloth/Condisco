# Performance budget

Measurement procedure and budget record for launch, pack load, and interaction
latency (P4.3). Companion to the quality and growth roadmap
(`docs/roadmaps/2026-09-25-condisco-quality-and-growth.md`).

> **Status: no device measurements exist yet.** This document defines *what* to
> measure, *how* to measure it, and the budget bookkeeping. Every value in the
> budget table (§3) is `TODO`. Taking those measurements requires a human with a
> device; the table is intentionally **device- and human-blocked**. Simulator
> wall-clock probes for lesson step transition and review card flip were added
> in Phase 5 and are recorded in §7, explicitly labeled **simulator-only** — they
> are troubleshooting aids, not budgets.

## 1. What to measure

| # | Metric | Where it happens | Instrumented today? |
|---|--------|------------------|---------------------|
| 1 | Cold launch → first content | `CondiscoApp.init()` → root `ContentView` first `onAppear` | ✅ `LaunchToFirstContent` signpost |
| 2 | First pack load (I/O + JSON decode + validation, five packs, ~4 MB) | `PackLoader.loadPacksUncached()` — runs once per process under the lazy `cached` static | ✅ `PackLoad` signpost |
| 3 | Home projection | `LearningStore.project(pack:)` | ⚠️ simulator probe only (`SimulatorPerformanceProbeTests` measures a seeded project through the review probe) |
| 4 | Review projection / one card flip | `ReviewCatalog.loadDue` + verdict record + re-project | ⚠️ simulator probe only (`testProbeReviewCardFlipWallClock`) |
| 5 | Listen background playback, battery | `ListenView` tab load + background audio while screen is off | ❌ deferred (Listen lane) |
| 6 | Widget refresh | `WidgetSnapshotWriter.refresh` | ❌ deferred (Store lane) |
| 7 | Lesson step transition | submit → evaluate → advance in `LessonSession` | ⚠️ simulator probe only (`testProbeLessonStepTransitionWallClock`) |
| 8 | Audio start latency (play tapped → audible) | Listen player / lesson TTS start | ❌ hook proposed in §5 (`AudioStart`); needs Listen/lesson lanes |

## 2. How to measure

**Device.** Use an *older supported* iPhone — the floor of the supported range
(iOS 17): iPhone XS / XR / 11 / SE (2nd gen) class. A current-gen dev device
masks budget violations. Disable auto-brightness, Bluetooth, and background app
refresh for the session; reboot the phone before the first run.

**Session setup.** In Xcode: Product → Scheme → Edit Scheme → Run → Profile,
ensure the **Release** configuration is *not* used blindly — the signposts are
DEBUG-only, so profile a **Debug** build when measuring signposts. (Release
builds contain no instrumentation by design; see §4.)

Open Instruments (Xcode → Open Developer Tool → Instruments) and use the
**os_signpost (Points of Interest)** template — it surfaces the
`LaunchToFirstContent` and `PackLoad` signposts directly. Add **Time Profiler**
for stack-level attribution. Use **Energy Log** for battery work.

**Cold launch, specifically:**

1. Uninstall the app from the device, then install the Debug build (ensures a
   truly cold first run and no cached snapshots).
2. In the app switcher, swipe the app fully away — cold means *no process alive*.
3. In Instruments, start the os_signpost recording, then launch the app from the
   home screen (or use the Profile action, which launches it for you).
4. On first content appearing, stop recording; read the `LaunchToFirstContent`
   interval in Points of Interest.
5. Repeat 5 times; log the median. Discard a run where the device was under
   thermal throttling or still installing.

**First pack load.** Launch fresh (per above) — the `PackLoad` signpost fires
once per process (lazy cache under `swift_once`) and captures I/O + decode +
validation of all five packs. Read it in Points of Interest, or grep the DEBUG
console for `PackLoad finished in X ms`.

**Home / Review projections (once signposts are added, §5).** Instruments Time
Profiler while switching to the Home tab and the Review tab; or the signed
interval in Points of Interest. Without signposts (today), take the Time
Profiler width of `LearningStore.project(pack:)` / `ReviewCatalog.loadDue` on the
call tree.

**Listen battery.** Energy Log template: open the Listen tab, start a track, turn
the screen off, leave playback running for 15 minutes. Record energy impact
(background energy used / `mAh`) and whether the app appears under *Significant
energy use*. Compare against a same-duration baseline with the screen off and no
audio.

**Widget refresh.** WidgetKit refreshes are scheduled by the system and not
reliably triggerable from Instruments; measure the *cost* of a refresh by
triggering `WidgetSnapshotWriter.refresh` from app code with a DEBUG-only
signpost once the Store lane adds it (§5). Until then, record only qualitative
notes (widget seems stale / updates promptly).

**Repeated lesson navigation.** Time Profiler on: open lesson A → exit → open
lesson B → exit, repeated 5×. Watch for growing retained memory (Allocations)
and frame drops. A signpost per lesson-open is proposed in §5.

## 2.5 Simulator-only measurement checklist (Phase 5)

Simulator numbers are **never budgets and never battery evidence** — they only
guide debugging (§7 records them separately). Every number below must be
labeled `simulator-only` when it lands in any report. Checklist for the four
Phase-5 measurement points:

1. **App launch (cold).** Already instrumented: the `LaunchToFirstContent`
   signpost (§1 row 1) and its DEBUG console line
   (`LaunchToFirstContent finished in N ms`). On a simulator: quit the app,
   `xcrun simctl launch booted <bundle-id>`, read the console line in Xcode
   (Debug build). Repeat 5×, record the median in §7 as simulator-only. Do
   NOT read device/battery meaning into it.
2. **Lesson step transition.** Pinned by the XCTest probe
   `SimulatorPerformanceProbeTests.testProbeLessonStepTransitionWallClock`
   (submit + evaluate + advance across the whole linear fr-home-foundation
   lesson; divide by step count for one transition). Run it with
   `-only-testing:CondiscoTests/SimulatorPerformanceProbeTests` and copy the
   `measured [Time, seconds] average:` line into §7. The probe covers the pure
   engine only — view layout, audio, and animations are not included.
3. **Audio start latency (play tapped → audible).** No pure-core probe exists
   (AVPlayer + UI live in the Listen/lesson lanes). Concrete hook, ready to
   drop into those lanes when they open: wrap the playback start call in
   `ListenPlayerModel` (`play()` / where `AVAudioPlayer.play()` is invoked)
   and the lesson TTS kickoff (`ShadowSpeaker` speak path) with
   `PerfSignpost` — `AudioStart` begin when the tap handler runs, end where
   `play()` returns after `prepareToPlay`. Simulator manual step meanwhile:
   tap play, time to first audible sample (or the console `AudioStart …`
   line once the hook lands), label simulator-only. **Not measured yet** (§7).
4. **Review card flip.** Pinned by
   `SimulatorPerformanceProbeTests.testProbeReviewCardFlipWallClock`
   (resolve due set + persist one verdict + re-project — audio and card
   animation excluded). Record the `measured` line in §7.

See §7 for the Phase 5 process used on 2026-09-26 and its recorded values.

## 3. Budget record

Columns: **metric · device · build · value · budget · status.**

| Metric | Device | Build | Value | Budget | Status |
|--------|--------|-------|-------|--------|--------|
| Cold launch → first content (`LaunchToFirstContent`) | TODO | TODO | TODO | set from measurement | not measured — needs device (simulator-only in §7) |
| First pack load (`PackLoad`) | TODO | TODO | TODO | set from measurement | not measured — needs device (simulator-only in §7) |
| Home projection (`LearningStore.project`) | TODO | TODO | TODO | set from measurement | not measured — needs device + signpost (simulator probe in §7) |
| Review projection / one card flip (`ReviewCatalog.loadDue` + verdict) | TODO | TODO | TODO | set from measurement | not measured — needs device (simulator probe in §7) |
| Lesson step transition (p50) | TODO | TODO | TODO | set from measurement | not measured — needs device (simulator probe in §7) |
| Audio start latency (play tapped → audible) | TODO | TODO | TODO | set from measurement | not measured — needs device + `AudioStart` hook (§5) |
| Listen background playback (battery, 15 min) | TODO | TODO | TODO | set from measurement | not measured — needs device |
| Widget refresh (`WidgetSnapshotWriter.refresh`) | TODO | TODO | TODO | set from measurement | not measured — needs device + signpost |

**Budget policy.** No budget number is written until the corresponding
measurement exists. Once a value is on the table, a budget is set at a round
multiple of the measured cold-start median (e.g. p50 value × 1.25), then
enforced in review. Do not backfill this table from estimates.

## 4. Instrumentation shipped in this phase

DEBUG-only, no Release impact. See `Condisco/CondiscoApp.swift` →
`PerfSignpost`.

| Signpost name | Begin | End |
|---------------|-------|-----|
| `LaunchToFirstContent` | `CondiscoApp.init()` | root `ContentView`'s first `onAppear` (attached in `CondiscoApp.body`; guarded to close only the first interval) |
| `PackLoad` | top of `PackLoader.loadPacksUncached()` | `defer` at the end of the same function (covers the full decode+validate loop) |

Properties:

- Every real call is `#if DEBUG`-guarded inside `PerfSignpost`; Release compiles
  the enum to `@inline(__always)` no-ops with a zero-size `Token`. No log, no
  signpost, no allocation, no syscall in Release — verified by inspection of the
  `#else` branch. One-line DEBUG console log per completed measurement
  (`LaunchToFirstContent: begin`, `… finished in N ms`).
- Subsystem: `com.sleuthysloth.condisco`, category `Performance` → read them in
  Instruments' Points of Interest (os_signpost) template.

## 5. Remaining signposts (blocked by lane ownership)

The files below belong to other lanes right now; add these when those lanes are
free, using the same `PerfSignpost` helper (all are in the main target, so the
helper is directly available):

| Proposed signpost | File · function | Blocked by |
|-------------------|-----------------|-----------|
| `HomeProjection` | `Condisco/Store/LearningStore.swift` · `project(pack:)` (wrap body) | Store lane |
| `ReviewLoadDue` | `Condisco/Review/ReviewModels.swift` · `ReviewCatalog.loadDue` (wrap body) | Store lane |
| `ListenTrackLoad` | `Condisco/Listen/ListenView.swift` · `refresh()` (wrap body) | Listen lane |
| `WidgetSnapshot` | `Condisco/Store/WidgetSnapshotWriter.swift` · `refresh(packs:focusSlug:)` (wrap body) | Store lane |
| `LessonOpen` | `Condisco/Lesson/LessonPlayerView.swift` (wrap view load / transition) | Lesson lane |
| `LessonStepTransition` | `Condisco/Engine/LessonSession.swift` · wrap `submitResponse` + `advanceLesson` callers in `LessonPlayerView` (submit → next step shown). Until that lane opens, the XCTest probe `SimulatorPerformanceProbeTests.testProbeLessonStepTransitionWallClock` covers the same work (§2.5, §7) | Lesson lane |
| `AudioStart` | begin on the play tap in `Condisco/Listen/ListenPlayerModel.swift` (and the lesson TTS kickoff in `ShadowSpeaker`); end where `AVAudioPlayer.play()` returns after `prepareToPlay` — covers "tapped → audible" | Listen/lesson lanes |
| `ReviewCardFlip` | `Condisco/Review/ReviewView.swift` · wrap card advance (verdict chosen → next card shown); the pure-core equivalent is probed by `SimulatorPerformanceProbeTests.testProbeReviewCardFlipWallClock` (§2.5, §7) | Review lane |

Pattern for each (identical to the pack-load one):

```swift
let measurement = PerfSignpost.begin("HomeProjection")
defer { PerfSignpost.end("HomeProjection", measurement) }
```

The widget extension target (`CondiscoWidget/`) is a separate process and cannot
use the main target's helper — if a signpost is ever wanted *inside* the widget,
add a small DEBUG-only `PerfSignpost` twin in that target; measurement of widget
*refresh cost* is covered by the main-target signpost above.

## 6. Reading the results

- **Launch:** the `LaunchToFirstContent` interval includes
  `CondiscoApp.init()` (DEBUG UI-test reset, if any), scene body evaluation, and
  the first appearance of the root `ContentView`. It does *not* include
  `ContentView`'s `.task` (Spotlight indexing) — a tighter end-point in
  `ContentView` is a follow-up once that lane is free.
- **Pack load:** one interval per process. If it appears twice, `swift_once`
  caching is broken — investigate.
- All numbers go in §3 with device + build recorded, or they don't count.

## 7. Simulator-only probe record (not budgets)

Simulator measurements guide debugging only. Per the §3 budget policy, **no
budget is set from these numbers**, they never stand in for device results,
and they are not battery evidence. Everything below is labeled simulator-only.

Process used (2026-09-26, Phase 5 verification-code lane):

- Probes: `Condisco/Tests/StoreTests.swift` → `SimulatorPerformanceProbeTests`,
  `XCTClockMetric` with no baseline (never fails a run). Run under the unit
  suite on the iOS Simulator (`xcodebuild test -only-testing:CondiscoTests`,
  destination `iPhone 18 Pro`, latest OS, Debug build).
- App launch and pack load: signpost-based (`LaunchToFirstContent`, `PackLoad`);
  simulator console values are only meaningful relatively, so they are
  reported as recorded but flagged not-measured-for-device below.

| Date (2026-09-26) | Metric | Simulator value | Meaning |
|---|---|---|---|
| simulator-only | Lesson step transition (pure engine: submit + evaluate + advance), whole 9-step fr-home-foundation walk | p50 ≈ 3 ms per lesson walk, ≈ 0.3 ms per step (`measured … average: 0.003 s`) | Pure engine only — no views, audio, or animations. Debug build, warmed caches. |
| simulator-only | Review card flip (pure core: `loadDue` + persist one `.exact` verdict + re-project, 2 seeded due keys) | p50 ≈ 2 ms per card (`measured … average: 0.002 s`) | Excludes card animation, audio, view layout. Debug build. |
| simulator-only | Cold launch → first content (`LaunchToFirstContent`) | not recorded (needs an app run in the simulator; follow §2.5 step 1 and add the value here) | Signpost exists; simulator launch timing is host-dependent and not budget evidence. |
| simulator-only | First pack load (`PackLoad`, five packs ≈ 4 MB) | not recorded here (see §2.5 / §2 procedure, Instruments Points of Interest) | One interval per process; debug-build console shows `PackLoad finished in N ms`. |
| simulator-only | Audio start latency | **not measured** — hook `AudioStart` proposed in §5; no pure-core probe exists (AVPlayer/UI live in Listen/lesson lanes) | Mark unmeasured rather than inventing a number. |

Boundary: these numbers compare *within this machine's simulator* over time;
they say nothing about an older iPhone, real audio, or battery. Any future
edits to this section must keep the simulator-only label and the dated table
format; never merge these rows into §3.