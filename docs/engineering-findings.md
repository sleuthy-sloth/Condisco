# Engineering findings log (historical)

This log records findings from the initial quality pass. For current gate
results and remaining device work, use
`docs/verification/2026-09-26-final-gate-report.md`. Later work has closed
several items below, so the original severity and audit counts are historical.

Findings discovered while working the quality/growth plan. Keep this list short and
checkable; every entry names a reproducer and a status. Content backlogs live in
`docs/skill-map.md` (curriculum) and `tools/audit_editorial.sh` (feedback/hints).

## Reproducers

```sh
bash tools/check_packs.sh        # pack + media integrity gate
bash tools/audit_editorial.sh    # editorial backlog report (not a gate)
xcodebuild test -project Condisco.xcodeproj -scheme Condisco \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:CondiscoTests ONLY_ACTIVE_ARCH=YES
```

## Fixed and verified (P0 slice)

- Duplicate-event conflict from key-order-sensitive JSON comparison — fixed by
  canonical (`.sortedKeys`) comparison on both sides; independently reviewed.
- Stale declared SHA-256 on the Italian market Listen track — corrected to the shipped
  file's hash; `check_packs.sh` now verifies it.
- Dead-end audio steps — `Stimulus.audio` with no shipped recording now offers a labeled
  on-device synthesized voice instead of an unavailable-audio message.
- Widget next-lesson logic deduplicated onto `CoursePack.firstUncompletedLesson`; Home and
  widget proven to agree; deep-link completion set verified identical by inspection.

## Open findings

| # | Finding | Severity | Status |
| - | - | - | - |
| 1 | **Corrupt local event rows are skipped + observable, never repaired.** The read path is now tolerant: `project(pack:)` / `unsyncedEvents()` / `learningEventsWithQuarantine(packId:)` / `allEventsWithQuarantine()` skip undecodable rows and surface their ids via `PackProgress.quarantined` / `corruptEventIds()` (logged at store open and at sync). The raw-log reads (`learningEvents(packId:)`, `allEvents()`) deliberately remain fail-loud with a typed `StoreError.corruptPayload` naming the first bad id, because data export must not silently drop history. Genuinely open: no self-healing — a corrupt row is never replaced from the server copy (deliberately left as follow-up until a repair can prove which copy is authoritative). | Minor (needs actual corruption; tolerated + observable) | Open — repair pass only; exclusion of corrupt rows from upload means they never reach the server. |
| 2 | **Listen-state merge is whole-row last-write-wins.** `LearningStore.mergeListenState` replaces position and listened mark together, so two devices editing different fields of one track near-simultaneously can clobber one field. | Minor | Accepted as documented design; latent UX risk. |
| 3 | **No runtime recovery for a malformed pack.** Decoding failure is a typed error (tested, no crash), but there is no path that skips one bad pack and keeps the others usable. | Moderate | Partially addressed (safe failure tested); full recovery open. |
| 4 | **Accessibility gaps.** Missing accessibility traits/values on many interactive elements, no contrast-ratio tracking, no touch-target enforcement, individual animations not reduced-motion guarded on some screens, no orientation declaration. | Moderate | Partially addressed — lesson-screen lane in flight. |
| 5 | **No release/perf confidence.** No CI config, no documented release checklist, no launch/perf measurement, no second-device or offline-first drill before this phase. | Moderate | Drills now added; checklist + perf budget + CI still open. |
| 6 | **Audio provenance record missing.** Italian market track cites `docs/audio-provenance/italian-market-listen.json`, which does not exist. | Minor | Open — media owner must supply the record or correct the citation. |
| 7 | **Generic "Hear it" TTS buttons carry no synthesized indication.** `ShadowMode.swift` (~127), `HandsFreeReview.swift` (~42), and `LessonMoments.swift` (~612) play TTS with no caption or hint. Unlike the surfaces already fixed, these make no provenance claim ("native", "pronunciation", "hear them all"), so this is a consistency question, not a false promise. | Minor | Open — decide one consistent screen-level caveat; avoid per-button noise. |
| 8 | **Review summary controls may be under 44pt.** `ReviewView.swift` ~385-447 ("Done"/"Undo", quiz "Reveal answer") were flagged as likely ~20pt hit areas; the a11y pass fixed the equivalents in `FlashcardsView.swift`/`HandsFreeReview.swift` but not this file. | Minor | Open — same mechanical fix. |
| 9 | **Recap-saved phrases don't deep-link.** Phrases saved from the "TAKE IT OUTSIDE" mission card leave `sourcePackId`/`sourceLessonId` unfilled, so the phrasebook's id fallback resolves them gracefully but without a lesson link. | Minor | Open — fill source ids at the save call site. |
| 10 | **Widget snapshot not refreshed from the recall warm-up.** The Review tab refreshes the widget on verdict; the lesson warm-up does not (it only refreshes reminders), so the widget's due count lags until its next cycle. | Minor | Open — call the writer in the warm-up handler if parity is wanted. |
| 11 | **P1.1 content authoring is not done.** The rubric and a report-only audit exist, but no hints or error-specific feedback were authored: the audit counts ~1,743 graded steps with no hint and hundreds of activities whose wrong answers all fall back to one generic string (Spanish alone: 355/355 graded steps hint-gap, 183 feedback-gap surfaces). This needs editorial judgement plus native review, so it remains a content backlog rather than an agent mass-edit. | Major (product quality) | Open — author per unit, starting with the first two units. The other P1.1 rule ("no open-ended prompt falsely auto-graded") **now PASSES (0)**: the audit measures it, `preflight.sh` surfaces it, and the two genuine violations were reworded to dictate their target. |
| 12 | **Corrupt-row observability decodes the whole log.** `corruptEventIds()` runs at store open and on every sync, decoding all rows O(n); unmeasured on a long log. | Minor | Open — measure under P4.3 before logs grow. |

## Fixed after the P0 slice

- Corrupt local event rows no longer block projection, lesson boot, review, or
  sync: the read path skips undecodable rows and reports their ids
  (`PackProgress.quarantined` / `corruptEventIds()`, logged at store open and on
  every sync) instead of throwing; raw-log export (`learningEvents(packId:)`,
  `allEvents()`) stays fail-loud by design. Covered by
  `testCorruptStoredEventPayloadStillProjectsAndSyncs`,
  `testPackScopedTolerantReadReturnsGoodEventsAndReportsSkipped`, and
  `testCorruptStoredEventPayloadRawLogsThrowTypedErrorNotCrash` in
  `Condisco/Tests/StoreTests.swift`.
- Synthesized playback was labeled "Native voice" in `VoiceRecorder.swift`; relabeled to
  "Course voice (synthesized)" to match the existing convention. The pair-practice TTS
  fallback in `StimulusViews.swift` was also captioned (previously announced as
  "pronunciation" with no synthesized caveat).

## Content backlog (quantified by `tools/audit_editorial.sh`)

Highest-leverage authoring work, in order: cloze error-specific feedback (262/262 blanks
fall back to the generic string), then per-pack text error feedback (de 125/125, pt
131/131, es 129/129, it 128/152, fr 105/126), then authored hints (1,743 graded steps have
none). Mission/story final-response gaps: pt-station-mission, pt-hotel-mission,
fr-city-mission, fr-pharmacy-mission, it-market-run-mission, it-restaurant-mission,
it-directions-mission. Protect what works: zero lessons missing an objective.
