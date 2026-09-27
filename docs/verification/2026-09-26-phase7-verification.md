# Phase 7 verification — B1-oriented Spanish pilot (7.1)

**Date:** 2026-09-26
**Method:** AI-assisted authoring under `docs/reviews/2026-09-26-b1-pilot-outline.md` (approved); sources per `docs/reviews/2026-09-26-b1-pilot-grammar-sources.md`; per-lesson record in `docs/reviews/2026-09-26-b1-pilot-review-ledger.md`. Developer sign-off empty until the developer reviews; native review `pending` on all 18 rows. The app may call this a **B1-oriented pilot, never "B1 achieved"** — no proficiency/level claim is shipped (strict audit exit-gate PASS 0; copy-ban tests green).

## What shipped

| | Before (0.7.5) | After (0.7.9) |
|---|---|---|
| Units | 17 | **20** (`es-unit-18` Viaje interrumpido, `es-unit-19` El trabajo y los estudios, `es-unit-20` Una decisión social) |
| Lessons | 52 | **70** (18 × `es-b1-*`, 6 per unit) |
| Activities | 435 | **591** |
| Checkpoints | 2 | **3** (+ `es-cp-independent`, `stage: independent`, 3 items: unseen-passage reading auto-graded, ungraded connected writing, record + self-assessed rubric) |
| Hosted dialogues | 2 | **5** (`es-b1-dialogo-vuelo`, `es-b1-dialogo-oferta`, `es-b1-dialogo-fiesta`) |
| Open tasks | 3 | **6** (+ one written OTW per unit — all `selfAssessed`, never graded) |
| Sustained readings | 3 | **6** (pilot 3/3) |
| Sustained listenings | 1 | **4** (pilot 3/3; device speech, es-ES/es-MX alternating, transcript byte-exact) |

Also: 18 per-lesson ledger rows fully filled (accepted-answer review, regional variant es-ES/es-MX, provenance, accessibility, naturalness questions, **two-source grammar columns** — 18 points × 2 verified references, C3's register-ranking gap honestly labeled); 3 new audio-provenance records (`spanish-b1-listen-aeropuerto/-oferta/-fiesta.json`, `reviewPending: true`); one self-compare mission + one final task per unit; retrieval-hook prerequisites + `reviewOf` wiring per lesson; catalog regenerated (273 lesson entries, idempotent).

## Gate evidence (fresh runs per wave)

| Wave | Gates | Result |
|---|---|---|
| Unit 18 | check_packs, strict, outcomes, catalog, diff-check, suite | all exit 0; **519/0** |
| Unit 19 | same | all exit 0; **519/0** |
| Unit 20 | same | all exit 0; **519/0** |
| `es-cp-independent` | same | all exit 0; **519/0** (suite 21:36 -0700) |
| Phase boundary | `bash tools/preflight.sh --with-ui` | **PASSED, exit 0** (2026-09-26 21:49 -0700) |

Strict audit exit-gate each wave: `(open-ended free production falsely auto-graded): PASS (0)`.

## Defects found and fixed during the waves

- **34 invalid `ErrorCategory` raw values** (33 in Unit 18 content, 1 in Unit 20) — decoder hard-fails; all remapped to the 12-value enum with per-site semantic justification; byte-diff confirmed only `category` lines changed.
- **1 copy-ban violation**: dialogue line "¿Es correcto?" → "¿Es así?" (ban list `correct/incorrect/score/graded/cefr/level` is developer-approved discipline — content changed, not the test).
- **Test pin drift** across four waves: ~40 pins updated across `PackSpanishTests.swift`/`StoreTests.swift` (counts, version, strip-surgery sets extended per wave so "pre-feature" simulations stay faithful, `taskCount` kept 0), including two pins the authoring reports initially missed and one wrong pin (open tasks 7 → actual 6) caught at gate time.
- One transient simulator abort (`Invalid device state`) — re-run green; not a product defect.

## Done-when (plan §7.1) status

| Requirement | Status | Evidence |
|---|---|---|
| No dead-end branch | ✅ | dialogue graph rules in check_packs + dialogue path tests (every hosted path ≥3 learner turns, clarification + misunderstanding/recovery, explicit ends) |
| No falsely graded open response | ✅ | `ActivityEvaluation.openTask` always `.selfAssessed`; strict exit-gate 0; open-task copy-ban test green |
| No missing media | ✅ | SL is device speech (no MediaItem) — listen-track checks pass; 3 provenance records with `reviewPending: true` |
| Complete per-lesson review record | ✅ | ledger 18/18 rows, structured + two-source columns; native review `pending` / dev sign-off empty (honest, not missing) |
| Passing pack/unit/UI gates | ✅ | `preflight.sh --with-ui` exit 0, 2026-09-26 21:49 -0700 |
| **Developer walkthrough on the iPhone** | ⛔ **PENDING — developer-owned** | see below |
| "B1-oriented pilot" wording only | ✅ | no "B1 achieved"/CEFR claim anywhere (strict audit + copy-ban tests) |

## Flags F1–F6 dispositions

- **F1 (first `listening` family in es):** satisfied — shipped and gated on the es pack.
- **F2 (audio provenance for the 3 SL pieces):** satisfied — three facts-only records created, `reviewPending: true`; no media entries → no allowlist change.
- **F3 (checkpoint surfacing):** satisfied — one `es-cp-independent` entry (honest shape for "three independent checkpoint tasks"); UI consumes it with no code change.
- **F4 (B2 disposition wording):** **decided 2026-09-26 — "B1 path teaches it first"** (`porque` first at u18L4/L5, shipped); A2 bridge lesson stays backlog. `docs/editorial-rubric.md` §A2→B1 and `docs/reviews/2026-09-26-a1a2-bridge-spanish.md` updated to match.
- **F5 (es-ES + es-MX variant review):** satisfied — all three SL pieces alternate regions; all 18 ledger rows carry regional-variant entries.
- **F6 (new ids → catalog regen):** satisfied — regenerated after every wave; final catalog idempotent (273 entries).

## Decisions recorded

- **6.4 (optional AI feedback experiment) OMITTED** by developer decision — offline self-assessment remains the shipped solution (plan allows either branch of the done-when).
- **F4** disposition revision (above).
- CI workflow stays deleted; local `preflight.sh --with-ui` is the gate.

## Developer-pending (blocks calling 7.1 fully done)

1. **iPhone walkthrough** of the pilot: stage-end Independent checkpoint card surfacing, dialogue branch resume after force quit, sustained reading/listening presentation (transcript reveal, slow replay, two-voice), open-task recording lifecycle, glossary save-to-review. Record results in this note or the phase-7 device appendix; no claims until walked.
2. **Native review** of the 18 ledger rows + wording approval (incl. the listening intro "synthesized" wording call left open from Phase 4).
3. Then **Phase 7.2**: developer self-study evidence loop — defect log scaffold opened at `docs/verification/2026-09-26-phase7-defect-log.md` (dated defect log + retest evidence + replication decision are its done-when).
