# Phase 2 verification — precise learning claims and review behavior

**Date:** 2026-09-26
**Branch:** `main` @ `50a9f7fd43f2442707bd35b5f4deb2054dae5b61` (dirty tree preserved; nothing reset/staged/committed)
**Tree at gate:** 44 files changed, +4354/−1738 (Phase 1 gate: 36 files, +3091/−1638)
**Gate:** `bash tools/preflight.sh --with-ui` → **PREFLIGHT PASSED, EXIT=0**
(13:02:08–13:10:06 -0700; log: `2026-09-26-phase2-preflight-with-ui.log`)

## Gate results (fresh run, this code state)

| Check | Result |
| --- | --- |
| Pack + media (`check_packs.sh`) | PASS — all five packs, media/attribution/listen-track integrity |
| Editorial `audit_editorial.sh --strict` | PASS, exit 0 — false-free-production **0**; comprehension 102 informational |
| Unit tests | **427/427, 0 failures** |
| UI tests | **6/6, 0 failures** |
| `git diff --check` | clean |

## Slices included

### 2.1 "What you can say" → evidence-specific labels
- `sayablePhrases` replaced by `YouModel.evidenceGroups`: selection/matching wins no longer count as production; grouping validated exactly like `LearningStore.project` (profile can never disagree with SRS).
- Groups + labels (**developer-approved 2026-09-26**): "Phrases you practised" (section), "Phrases you built or typed" (independent text/cloze), "Phrases you practised (with hints)" (assisted-only), "Phrases you recognised" (selection-type), "Speaking practice (self-assessed)" (self-compare; model sentence quoted — no audio evidence exists). No "can say" copy remains; a test pins the label strings.
- 8 new `YouPhraseEvidenceTests`: recognition never enters production, assisted identified, manual "I know this" implies no mastery, self-compare lands only in speaking practice.
- No event schema changes.

### 2.2 The 102 fixed-answer comprehension prompts
- Worklist with per-prompt dispositions: `docs/reviews/2026-09-26-comprehension-worklist.md` — **102 rows reconciled with the audit count** (fr 13, it 18, de 21, pt 29, es 21): **81 clear · 17 narrow wording · 4 add variants · 0 convert**.
- All 21 non-clear prompts fixed by widening accepted lists only (no question wording changed): FR 3, IT 7, PT 11. Examples: `il mio libro`, `No, she doesn't.`, `em frente`, digit dates (`le 3 mai`/`il 3 maggio`), full-sentence name answers, `Perché è migliore per il mio lavoro.`
- 2 stale authored-error entries removed where they contradicted newly accepted variants (`Dix heures`, `Two.`).
- Every changed prompt has a targeted test (accepted variant + meaning-changing near miss): 421→421 gate-era counts confirmed green; no fuzzy acceptance, no online grader, accents preserved where distinguishing, lesson metadata untouched (no catalog regeneration needed).

### 2.3 Focus course / All courses review scope
- `ReviewScope` enum on `ReviewModel`, session state, default **All courses** (Home count/invitation keep agreeing with the queue); segmented picker under the section picker; scope-aware counts and empty states; focus resolves from existing `condisco.focusLanguage` (no second focus concept).
- FSRS scheduling and event recording untouched; verdict in one scope never removes another language's due cards (asserted).
- Home invitation entry resets narrowed scope to All via `.condiscoReviewHomeEntry` notification (pattern-matches `.condiscoProgressChanged`), so Home's displayed count always matches the queue it opens.
- 6 new `ReviewScopeTests` (mixed queue, honest empty state, mid-visit switching both directions, verdict isolation across packs, event-log + FSRS assertions, invitation reset).

## Evidence integrity

- All figures from the 2026-09-26 Phase 2 gate log — no older run reused.
- Developer-approved wording: 2.1 evidence labels (2026-09-26); restore copy approved in Phase 1.
- No device row marked PASS; physical-device smoke and two-device CloudKit remain UNVERIFIED.
- Manual developer checks still queued: 1.2 export→fresh-simulator restore; Phase 3 listening on iPhone.
