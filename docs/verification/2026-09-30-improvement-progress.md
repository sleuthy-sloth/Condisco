# Improvement execution ledger — 2026-09-30

Base: d63923f. User authorized all work not requiring human review. The user subsequently authorized committing and pushing the improvements with an updated README to GitHub. No app build or release publication is implied.

## Completed implementation

- One combined course/library due queue for Home, widget, reminders and all-course Review; focus-specific warm-ups remain course-only. Neutral reminder wording; library save/delete refresh invitations.
- Off-main-actor, cancellable file reading capped at 1 MB plus one sentinel byte. Reject binary/control text, accept UTF-8 BOM, retain Unicode.
- Actionable practice recommendations with concrete reachable lessons or all-course Review. Self-assessed spoken responses contribute practice recency without claiming assessed ability or creating recall cards. Completed-lesson practice starts a fresh session and preserves evidence; unfinished recommendations resume their saved checkpoint and draft.
- Four small listening/decision/spoken-response slices in the first two German and Portuguese units. Device speech is explicit in provenance. Existing lesson revisions retained to preserve unchanged recall evidence; revisions increased only for changed answer activities.
- Corrected narrow German recall prompts and Portuguese reply wording.
- Prepared an owned-iPhone run sheet, Spanish seven-day self-study kit, and six-task samples per language. No observed results invented.

## Verification

- Clean baseline: 576 unit tests passed.
- Regression red run: 7 tests, 6 expected failures for combined review totals, binary input and BOM behavior.
- First focused green: 22 tests passed (review scope/library and text validation).
- Bounded reader green: 7 import tests passed; new curriculum reachability test initially failed before content was added.
- Pack/media validation and outcomes audit passed after content changes.
- Independent code review identified loss of unchanged FSRS history from lesson revision bumps and completed practice opening recap. Both corrected locally.
- Final tree build-for-testing: passed for the app and all unit/UI test sources.
- Final unit suite: **588 tests passed, zero failures**. Includes review invitations, readable/bounded imports, early lesson reachability, practice recency, preserved historical evidence and completed-only fresh replay.
- Final UI smoke suite: **blocked by host simulator/test-runner stalls**. Simulator restart recovered unit execution, but the UI runner remained at “Running tests…” without reporting a test case. The stalled invocation was stopped; no UI pass is claimed. Simulator.app is absent from this host's Xcode bundle; that observation alone does not establish the cause. All UI sources compiled successfully.
- Strict editorial audit: no hint gaps or authored error-feedback gaps; no falsely auto-graded open-ended production. Outcomes audit, pack/media integrity, generated catalog drift and git diff whitespace checks passed.
- Final independent follow-up review: no remaining Important issues found. The review was read-only and did not substitute for simulator or human checks.

Core preflight checks were run individually. The full preflight including UI is not certified because UI execution remains blocked. Final logs: /private/tmp/condisco-final-verified-tests.log, condisco-final-build.log, condisco-final-pack-check.log, condisco-final-editorial.log and condisco-final-outcomes.log.

## Human observations still required

Owned-phone usability, VoiceOver and Dynamic Type, audio naturalness and audibility, measured battery/performance, physical-device backup/restore, and the seven-day learning observations. Authored language tasks still need naturalness/usefulness review. See the dated run sheets under docs/usability and docs/reviews.


To retry UI on a healthy Xcode host:

```sh
xcodebuild test -project Condisco.xcodeproj -scheme Condisco \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:CondiscoUITests -parallel-testing-enabled NO
```

The implementation and README are prepared for the authorized GitHub source update. No app build or release has been published. No further human approval is needed to rerun automated UI checks when the host is healthy. Human observation is needed only for the listed phone, language-quality and learning checks.
