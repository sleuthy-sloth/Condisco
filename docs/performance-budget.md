# Performance budget

Measurement procedure and budget record for launch, pack load, and interaction
latency (P4.3). Companion to the quality and growth roadmap
(`docs/roadmaps/2026-09-25-condisco-quality-and-growth.md`).

> **Status: no measurements exist yet.** This document defines *what* to measure,
> *how* to measure it, and the budget bookkeeping. Every value in the table below
> is `TODO`. Taking the measurements requires a human with a device; it is
> intentionally **device- and human-blocked** — nothing here was measured, and no
> budget number has been set from data.

## 1. What to measure

| # | Metric | Where it happens | Instrumented today? |
|---|--------|------------------|---------------------|
| 1 | Cold launch → first content | `CondiscoApp.init()` → root `ContentView` first `onAppear` | ✅ `LaunchToFirstContent` signpost |
| 2 | First pack load (I/O + JSON decode + validation, five packs, ~4 MB) | `PackLoader.loadPacksUncached()` — runs once per process under the lazy `cached` static | ✅ `PackLoad` signpost |
| 3 | Home projection | `LearningStore.project(pack:)` | ❌ deferred (Store lane) |
| 4 | Review projection | `ReviewCatalog.loadDue` | ❌ deferred (Review/Store lane) |
| 5 | Listen background playback, battery | `ListenView` tab load + background audio while screen is off | ❌ deferred (Listen lane) |
| 6 | Widget refresh | `WidgetSnapshotWriter.refresh` | ❌ deferred (Store lane) |
| 7 | Repeated lesson navigation (back/forth between lessons) | `LessonPlayerView` / `LessonMoments` | ❌ deferred (Lesson lane) |

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

## 3. Budget record

Columns: **metric · device · build · value · budget · status.**

| Metric | Device | Build | Value | Budget | Status |
|--------|--------|-------|-------|--------|--------|
| Cold launch → first content (`LaunchToFirstContent`) | TODO | TODO | TODO | set from measurement | not measured — needs device |
| First pack load (`PackLoad`) | TODO | TODO | TODO | set from measurement | not measured — needs device |
| Home projection (`LearningStore.project`) | TODO | TODO | TODO | set from measurement | not measured — needs device + signpost |
| Review projection (`ReviewCatalog.loadDue`) | TODO | TODO | TODO | set from measurement | not measured — needs device + signpost |
| Listen background playback (battery, 15 min) | TODO | TODO | TODO | set from measurement | not measured — needs device |
| Widget refresh (`WidgetSnapshotWriter.refresh`) | TODO | TODO | TODO | set from measurement | not measured — needs device + signpost |
| Repeated lesson navigation (p50 per transition) | TODO | TODO | TODO | set from measurement | not measured — needs device + signpost |

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