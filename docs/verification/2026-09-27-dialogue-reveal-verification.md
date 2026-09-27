# Dialogue model-reveal state verification

**Date:** 2026-09-27
**Scope:** Open turns in hosted conversations. The learner's explicit model reveal must remain marked after draft edits and checkpoint resume, then clear when the turn advances.
**Full gate:** `bash tools/preflight.sh --with-ui` → exit 0. Raw output: `docs/verification/2026-09-27-dialogue-reveal-preflight-with-ui.log`.

## Cause and correction

The dialogue view observed the entire value-typed `DialogueSession`. Every draft edit changed `session.openDraft`, so its session-change handler reset the draft form, rubric choices, optional rating, and in-memory model-reveal flag. The flag was absent from `DialogueCheckpointState`, so resuming the same open turn could also lose the reveal evidence.

The form now resets only when the presented dialogue turn changes. `openModelRevealed` belongs to the session and its additive checkpoint state; the reveal action updates that state, the submitted turn records it, and the next turn clears it. Older checkpoints without the new key decode with `false`.

## Evidence

| Check | Result |
| --- | --- |
| Test-first focused run | Failed at compile because the form and checkpoint marker did not exist |
| Focused dialogue suite after fix | 10 tests passed, 0 failures |
| Pack, media, editorial, outcome, and generated-catalog checks | Passed in full preflight |
| Full unit suite | 565 tests passed, 0 failures |
| Simulator UI suite | 6 tests passed, 0 failures |
| Full preflight | `PREFLIGHT PASSED`, exit 0 |

The two new tests cover draft-edit form retention, turn-change reset, marker propagation to a submitted turn, checkpoint encode/decode and resume, and old-checkpoint compatibility. The simulator UI smoke covers the general first-run and accessibility journeys; it does not directly navigate a dialogue reveal. A physical-iPhone walkthrough of the Spanish dialogues remains open.
