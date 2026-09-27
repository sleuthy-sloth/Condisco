# Phase 6 verification — intermediate practice modes

**Date:** 2026-09-26
**Gate run:** `bash tools/preflight.sh --with-ui` → **exit 0**, 19:14–19:19 -0700
**Log:** `docs/verification/2026-09-26-phase6-preflight-with-ui.log`
**Tree:** branch `main` @ `50a9f7fd43f2442707bd35b5f4deb2054dae5b61` + uncommitted Phase 1–6 working tree (preserved untouched; nothing staged).

## Gate evidence (fresh run)

| Gate | Result |
| --- | --- |
| `tools/check_packs.sh` | exit 0 — incl. sustained/open-task/dialogue unseen-wording passes, structural integrity (references, reachability, unknown-kind probes) |
| `tools/audit_editorial.sh --strict` | exit 0 — false free-production grading: 0 |
| `python3 tools/audit_outcomes.py` | exit 0 — every declared modality claim backed (spoken/written open-tasks count as production evidence) |
| Catalog drift | byte-identical (255 lessons) |
| Unit tests | **519/519**, 0 failures |
| UI smoke | 6/6, 0 failures |
| `git diff --check` | exit 0 |

Test-count timeline for this phase: 459 → 466 (6.1-A) → 479 (6.1-B) → 497 (6.2) → **519** (6.3).

## Slices landed (6.1–6.3)

**6.1 Sustained reading & listening:**
- Schema: top-level `sustainedTexts[]` / `sustainedListenings[]` (additive; old packs decode unchanged), `LessonStep` bindings; sections carry per-section TTS text, voice id (offline fallback rule: missing voice never fatal), transcript, glossary, provenance, a11y labels.
- Content (original, Spanish): three genres — message thread "Planes para el sábado", short article "El mercado de la plaza", personal narrative "Mi primer día en Sevilla" — + 5-section multi-voice synthesized listening passage "La llamada del sábado" (~2–2.5 min, es-ES/es-MX voices, provenance record `docs/audio-provenance/spanish-sustained-listen-pilot.json`, reviewPending). Each: 3 questions (main idea / key detail / speaker intent), deterministic grading, reveal-after-answer.
- Experience: full-passage reading view (Dynamic Type, VO document order, section headers), glossary tap → popover with save-to-review through the real phrasebook API (non-interrupting), listening with transcript hidden on first pass, per-section replay at normal/slow speed, synthesized labeling (visible + VoiceOver), declared-voice-missing surfaced in-memory.
- Validators: shape/binding/orphan/transcript/voice/gene checks + unseen-wording; 7 negative fixtures; old-pack fallback test.

**6.2 Connected writing & spoken production:**
- New `open-task` activity kind (written/spoken): goal, required points, model response, 4-dimension self-check rubric (meaning/organization/useful language/repair), soft length guidance (targets, not thresholds).
- 3 Spanish tasks — fin-de-semana (written), café order (spoken), weekend plans (spoken) — **rubric + task copy approved by developer 2026-09-26**.
- Flow: private draft / disposable local recording (deletable), optional hints (assistance), explicit model reveal (voids independence), rubric self-assessment, submit records completion + assistance + self-rating only — response text/audio never enters the learning log.
- **Production invariant fixed during slice:** `ActivityEvaluation.openTask` now always returns `.selfAssessed` — no path can grade an open response correct/incorrect (plan §6.2 item 3).
- Audit rule extended: spoken open-task backs `speaking`, written open-task backs `writing`; selection/dialogue/text repair rules from 5.1.4 unchanged.
- Structure pins: M5 batch-4 invariant (discovery lessons end with text final-response) preserved by inserting open-task steps mid-chain.

**6.3 Multi-turn interaction & repair:**
- Extended existing `dialogues` shape (no new Activity case): additive `partner`/`hostLessonId`, node `kind` (clarification|misunderstanding|recovery), open turns with 6.2-style rubric, choice ids; old fr/it dialogues decode unchanged.
- Two Spanish exchanges: `es-cafe-turno` (9 nodes, 12 paths, includes misheard-order recovery) and `es-a2-planes-sabado` (7 nodes, 4 paths, day-misunderstanding recovery); each has clarification + misunderstanding + authored recovery route, explicit end states, ≥3 learner turns on every path.
- Session engine: branch position checkpointed (`LessonCheckpoint.dialogue`), per-turn `dialogue-turn` event (idempotent, authored-order `turnIndex`, drafts never stored), force-quit resume replays the turn thread along real edges, recap shows only learner-supplied responses.
- Validators: reachability, no dead ends, no cycles, turn-depth, clarification/recovery presence, one dialogue per host lesson, cross-content unseen-wording.

**6.4 (conditional, plan):** not started — decision on whether to prepare the optional AI-feedback experiment is the developer's (offline self-assessment flow is the shipped default).

## Done-when check (§6)

- ✅ Learner can follow connected text and audio segments, recover from a missed detail, answer beyond a memorized phrase (6.1).
- ✅ Intermediate learners compose and speak connected responses without false correct/incorrect from a short-answer engine (6.2 — invariant pinned by test).
- ✅ Practice requires following a changing partner response with clarification and repair, not isolated translations (6.3).

## Remaining / queued

- **Developer device review of Phase 6 experience on iPhone** (plan owner note): sustained reading/large-text/VO order, transcript reveal + slow speed, two-voice availability, open-task recording lifecycle, dialogue branch resume after force quit.
- **Phase 4 (developer-owned):** §3b walkthrough (7 rows BLANK), §1/§1b Listen checks, Spanish pilot verdict, Instruments traces, 4.3 gate; wording call on Listen intro ("a calm voice…by ear").
- 6.4 enable/omit decision (developer).
- Phases 7–9 next per plan order.
