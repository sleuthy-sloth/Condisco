# Phase 5 verification — A1/A2→B1 map, skill evidence, checkpoints, authoring gate

**Date:** 2026-09-26
**Gate run:** `bash tools/preflight.sh --with-ui` → **exit 0**, 16:58–17:03 -0700
**Log:** `docs/verification/2026-09-26-phase5-preflight-with-ui.log`
**Tree:** branch `main` @ `50a9f7fd43f2442707bd35b5f4deb2054dae5b61` + uncommitted Phase 1–5 working tree (preserved untouched; nothing staged).

## Gate evidence (fresh run)

| Gate | Result |
| --- | --- |
| `tools/check_packs.sh` | exit 0 — 5 packs/255 lessons; structural-integrity section (reference integrity 566 reviewOf refs, reachability 255/255, unknown-kind probes, checkpoint unseen-wording) all PASS |
| `tools/audit_editorial.sh --strict` | exit 0 — false free-production grading: 0 |
| `python3 tools/audit_outcomes.py` | exit 0 — every declared modality claim backed (now required as preflight Step 3) |
| Catalog drift (`gen_lesson_catalog.py`) | identical (255 lessons) |
| Unit tests (`CondiscoTests`) | **459/459**, 0 failures |
| UI smoke (`CondiscoUITests --with-ui`) | **6/6**, 0 failures |
| `git diff --check` | exit 0 |

Test-count timeline for this phase: 434 → 439 (5.2B rotation) → 449 (5.3A checkpoints) → 457 (5.3B flow) → **459** (5.4 update-safety pins).

## Slices landed (5.1–5.4)

**5.1 A1/A2→B1 map (Spanish pilot, dev-confirmed):**
- `docs/skill-map.md` — per-unit evidence matrix (77 units; reading/listening/production/interaction marked, absence explicit); audio inventory (de/pt/es = 0 media).
- `docs/editorial-rubric.md` — "A2→B1 bridge (Spanish, 2026-09-26)": B2 (`porque`) flagged needs-bridging; rest dispositioned "B1 path teaches it first". Bridge review: `docs/reviews/2026-09-26-a1a2-bridge-spanish.md`.
- `tools/audit_outcomes.py` — structural audit (declared modality vs actual activity); **16 unbacked `speaking` claims repaired** (fr 2, it 1, de 10, pt 3 — tags removed/retargeted on selection/dialogue/text activities; census 52→16, matching genuine self-compare lessons). No prompts/answers/IDs/revisions touched.
- Courses browser (`CoursesView.swift`) — "Course levels" section: Foundation → Developing → Independent cards (169/86/0 lessons), outcomes from authored unit objectives, prerequisite lines, "Content structure, not a test result." sub-label. **Copy approved by developer.** Browsing/progress/deep-links untouched; informational cards only.

**5.2 Practice by skill:**
- `EvidenceCategory` projection (seen / recognized / produced-with-help / produced-independently / recalled-later) — zero payload/schema changes; "Practice by skill" You section (no combined score).
- `ReviewCueRotation` — cue rotation derived from `reps` over authored `[prompt, hints…]`; FSRS scheduling untouched (interval fuzz behavior confirmed; tests assert fuzz-invariant facts).

**5.3 Checkpoint task bank (Spanish, optional):**
- Schema: pack-level `checkpoints` (additive, `decodeIfPresent ?? []` — old pack JSON decodes unchanged); `es-cp-foundation`, `es-cp-developing` (unseen reading passage + 2 questions, connected written response, spoken response + 4-criterion rubric). Listening omitted — no unseen Spanish checkpoint audio exists (documented).
- Store: `checkpoint-attempt` event (eventVersion 2); one transaction; retake appends without duplicating completion or erasing earlier attempts; `independent = itemsRevealed && assistance.isEmpty`; export/import round-trip preserved; no locks/streaks/penalties.
- Flow (`CheckpointFlow.swift`): Courses-screen stage-boundary card → intro → items (translation assistance recorded) → self-assessment rubric → results with **source-of-result phrases** ("Identified from the passage…", "Practised in writing…", "You compared your spoken response…") → targeted revisit suggestions (real lesson ids, honest-empty when thin) → attempt history. **All copy approved by developer**; forbidden-claim test pins (no "B1 achieved"/CEFR/"you are") green.
- Validators: leak check (no lesson step references a checkpoint item), unseen-wording check, unique ids, modality-declaration coverage.

**5.4 Authoring/update safety:**
- Unit authoring template in `docs/editorial-rubric.md` (10-field table grounded in real key paths, invariant rules, 14-item checklist, stable-ID/revision contract).
- `check_packs` structural pass (missing links, unreachable branches/ cycles, unknown kinds rejected by decode, repeated checkpoint cues); **C2 debt cleared** — 36 dangling `reviewOf` refs removed (de/pt/es).
- `audit_outcomes` wired as required preflight Step 3 → **one-command validation**.
- Update-safety pins (`PackUpdateTests`): update over existing progress preserves completion/legacy credit/known marks/checkpoint attempts/review history (fuzz-invariant FSRS fields); grown checkpoint bank installs over existing progress without reset.
- Bundle baseline: `docs/verification/2026-09-26-bundle-baseline.md` (36.4 MB content; 28.8 MB = 5 Listen tracks).

## Done-when check (§5.1–5.4)

- ✅ One focus language (Spanish) has an honest A1/A2→B1 map; every displayed skill claim has an activity behind it (audit exit 0).
- ✅ Existing progress resolves to the same lessons (no state migrations; update-safety pins green).
- ✅ Practice tracked by skill and evidence category, no combined score, no proficiency claims.
- ✅ Progression includes transfer checks (unseen checkpoints) reporting evidence by modality, not lesson counts as proficiency.
- ✅ New unit authorable from template, validated in one command, installed over progress without data loss.

## Remaining / queued

- **Phase 4 (developer-owned):** §3b walkthrough table (7 rows BLANK), §1/§1b Listen checks, Spanish pilot verdict, Instruments traces, 4.3 foundation gate on the walked state. Wording calls queued: Listen intro "a calm voice…by ear" vs "synthesized".
- De/pt checkpoint replication waits on the Spanish pilot verdict; no bulk content generation.
- Phases 6–9 next per plan order.
