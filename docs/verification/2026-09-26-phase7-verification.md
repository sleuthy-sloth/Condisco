# Phase 7 verification — Spanish B1 pilot snapshot

**Date:** 2026-09-26
**Gate:** `bash tools/preflight.sh --with-ui` → exit 0
**Log:** `docs/verification/2026-09-26-phase7-preflight-with-ui.log`
**Tree:** Local `main` at `50a9f7fd43f2442707bd35b5f4deb2054dae5b61` plus the uncommitted Condisco iOS work, including the 18-lesson Spanish B1 pilot. The subsequent documentation-only README and this note were not present during the run.

| Check | Result |
| --- | --- |
| Pack structure, references, reachability, and media | Pass — 273 lessons across five packs; zero unreachable lessons or prerequisite cycles |
| Strict editorial audit | Pass — zero falsely auto-graded open responses |
| Outcome audit | Pass |
| Generated lesson catalog | Pass — no drift |
| Unit tests | 519 passed, 0 failures |
| Simulator UI tests | 6 passed, 0 failures |
| Preflight result | `PREFLIGHT PASSED`, exit 0 |

This is automated and simulator evidence for the current pilot tree. Per-lesson editorial signoff, native-speaker review, learner outcomes, and the owned-iPhone walkthrough remain open. The gate does not establish CEFR proficiency or device performance.
