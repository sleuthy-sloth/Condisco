# 8.3 outline — B2-oriented practice pilot (Spanish)

**Date:** 2026-09-27
**Plan:** 8.3 "Pilot B2-oriented practice in the focus language" — AI coder
drafts; **the developer decides whether the material is useful enough to
continue.** A full B2 curriculum across five languages is explicitly out of
scope (later content program, not a consequence of this pilot).
**Done when (plan):** "the platform can host a coherent B2-style unit
without new shortcuts in grading, playback, or storage."
**Recon sources:** exp-5 (authoring pipeline, gates, pins), lib-15 (CEFR B2
reference + Spanish grammar authorities), `spanish.json` unit-25 exemplar
reads (lesson skeleton, family/genre enums, provenance pattern).

## 1. Honest-labeling rules (binding on every copy string)

1. **"B2-oriented", never "B2" as an outcome.** Mirror the existing
   pack-description construction verbatim in pattern: "B1-oriented practice,
   not a claim that completing it confers B1" → for this unit's copy:
   B2-oriented, not a claim of B2 certification. No screen may show a level
   as an achieved result.
2. **CEFR descriptors stay OUT of the app.** The Council of Europe B2 global
   scale and Companion Volume mediation descriptors (quoted in §3 below) are
   *design references for complexity and independence only* — they inform
   task design in this document and must never be reproduced as learner-facing
   copy, progress labels, or completion text. Quoting them in-app would also
   carry CoE CC BY 4.0 attribution obligations we do not need.
3. **The lesson `cefr` field is the existing content-alignment pattern.**
   It is `String?` in `CoursePack.swift:991` (no enum, decodes any value);
   unit-25 lessons already carry `"cefr": "B1"` (spanish.json:62818 area).
   New lessons carry `"cefr": "B2"` as a **content-alignment tag** — same
   status as the existing B1 tags: an authored source-level marker, never a
   proficiency claim. Display copy around it (if any) follows rule 1.
4. **No new claims anywhere:** no native-naturalness, no learner-outcome, no
   grading shortcuts. Self-assessment stays honest (existing SC/OTW rubric
   patterns: rubric-scored by the learner, never auto-graded against a
   proficiency scale).
5. **Synthesized speech is labeled as such** — the SL lesson ships via
   on-device TTS exactly like `es-b1-listen-charla` (device-speech, no audio
   file), provenance record marks `generator.class = on-device speech
   synthesis` and `reviewPending: true` for naturalness.

## 2. Design references (internal only — not app copy)

- **CEFR B2 global scale** (Council of Europe, *Table 1 (CEFR 3.3)*,
  https://www.coe.int/en/web/common-European-framework-reference-languages/table-1-cefr-3.3-common-reference-levels-global-scale,
  CC BY 4.0, credit: Council of Europe): the B2 row's descriptors on
  understanding complex concrete/abstract texts, interacting with fluency and
  spontaneity, and producing clear detailed texts that **explain a viewpoint
  on a topical issue giving advantages and disadvantages of various
  options** — the direct design target for the written-argument lesson.
- **Companion Volume (2020) mediation descriptors at B2** (CoE, CC BY 4.0):
  relaying specific information and arguments reliably; summarising a
  complex text's main points and relevant details; *"Can outline the main
  points in a disagreement with reasonable precision and explain the
  positions of the parties involved"*; *"Can summarise the statements made
  by the two sides, highlighting areas of agreement and obstacles to
  agreement"* — the design target for the mediation dialogue (§5 lesson 4).
- These shape the outline only. Attribution line retained here for the
  record; nothing above may leak into learner-facing text.

## 3. Requirement mapping (plan 8.3 → existing engines)

| Plan requirement | Hosted by | Engine | New machinery? |
|---|---|---|---|
| (a) longer connected input | SR lesson (multi-section article) **and** SL lesson (four-section, two-voice) | `SustainedText` / `SustainedListening` + `<bank-id>-launch` step binding | none |
| (b) contrasting viewpoints | **single SR short-article with alternating position sections** + comparison questions (decision D2, §4) | existing `SustainedText.sections` + fixed-answer question logic | none |
| (c) written argument with reasons/counterpoint | OTW lesson, `mode: written`, `requiredPoints` incl. counterpoint, `rubric` 2–4 criteria | `OpenTaskActivity` (self-assessed, never auto-graded) | none |
| (d) multi-turn discussion / mediation | DB dialogue: learner mediates a disagreement between two parties | `DialogueChoiceActivity` (`choice` + `open` nodes, ≥3 turns/path, clarification + recovery, host-lesson binding) | none |
| (support) connectives/stance notice→practice | frames lesson | existing legacy-exercise (`frames`) pipeline | none |
| (support) mission wrap: argued take + self-check | mission lesson FT + SC | existing free-talk + self-compare | none |

**Gap found by exp-5:** no activity schema presents two opposing texts as a
paired construct. See decision D2 — resolved inside existing schemas.

## 4. Orchestrator decisions

- **D1 — unit id/title.** `es-unit-26`, draft title **"Ponerse en el otro
  lado"** (working title; developer may rename at review). Objective covers:
  follow a longer text and a longer discussion that present two positions,
  track the signposts of an argument, concede and counter with contrastive
  connectives, mediate a disagreement, and write an argued position with a
  counterpoint. Version bump: pack `0.7.14` → **`0.7.15`**.
- **D2 — contrasting viewpoints without a new activity type.** Host the
  contrast in ONE `SustainedText` (`genre: short-article`) whose sections
  alternate positions (intro → position A with reasons → position B with
  counter-reasons → synthesis), with the question set including
  compare/evaluate items across sections. Rationale: the done-when forbids
  new shortcuts in grading/playback/storage; a paired-texts schema would be
  new grading machinery and scope beyond "small advanced slice". The SL
  discussion (lesson 2) provides a second contrasting input in the other
  modality. Flagged to the developer as the pilot's one design compromise.
- **D3 — `cefr: "B2"` tags** on the six new lessons per rule 3 (content-
  alignment marker, decodes as plain `String?`).
- **D4 — no CEFR descriptors in app copy** (rule 2).
- **D5 — checkpoints unchanged.** Option A stays: exactly 3
  (`es-cp-foundation`, `es-cp-developing`, `es-cp-independent`);
  `PackSpanishTests.swift:145-147` pins must NOT move. No B2 checkpoint.
- **D6 — original content only.** All texts authored fresh for this unit
  (no external recordings, no copied articles); provenance records per the
  `docs/audio-provenance/spanish-b1-listen-charla.json` pattern for the SL
  (device-speech, `sha256: ""`, `reviewPending: true`), and pack
  `provenance` fields on SR/SL banks following unit-25 wording.
- **D7 — prerequisites.** Linear chain across the six lessons; first lesson
  prerequisites the final unit-25 lesson (`es-b1-transmitir-mission`) with
  the same `requirement` kind unit-25 uses (authoring lane clones the exact
  structure).
- **D8 — research-before-authoring** (batch-2 decision 5 pattern carries
  over): §6's source-verification section must be completed and written to a
  research file BEFORE any `spanish.json` edit. One unit = one authoring
  slice = one fresh gate.

## 5. Unit sketch — `es-unit-26` (six lessons, clone unit-25 skeleton)

Skeleton fields cloned from `es-b1-hilo-frames` (spanish.json:62696+):
`unitId`, `title`, `objective`, `family`, `revision: 1`, `estimatedMinutes`,
`entryStepId`, `steps[]` (`id`/`purpose`/`activityId`/`required`/
`nextStepId`), `completionPolicy`, `prerequisites[]`, `concepts[]`,
`vocabulary[]`, `cefr`, `culturalNote`, `legacyExercises[]` where applicable.
Family values: clone the unit-25 counterpart lesson for each type
(frames→`discovery` confirmed at 62699; listen/lectura/escrito/dialogo/
mission: authoring lane reads the exact values — do not guess).

1. **`es-b2-postura-frames`** (frames, family `discovery`) — hook: **the
   signposts of conceding and countering**. Notice→practice cycle over
   concessive/contrastive connectives (`aunque` + indicative/subjunctive
   contrast, `sin embargo`, `no obstante`, `en cambio`, `pero` vs adverbial
   connectors) and stance/hedging markers (`creo que`, `en mi opinión`,
   `parece que`). Skills: grammar + vocabulary. `cefr: "B2"`.
2. **`es-b2-listen-debate`** (SL, family `listening`) — bank
   `es-b2-listen-debate`, launch `es-b2-listen-debate-launch` (decision D1's
   `<bank-id>-launch` convention). Four sections, **two voices** (es-ES +
   es-MX pair like `es-b1-listen-charla`), a structured disagreement where
   each side states a position, gives a reason, and responds. Questions:
   main idea / key detail / speaker intent (6.1 fixed-answer pattern).
   Provenance JSON record per `spanish-b1-listen-charla.json`. No audio
   file ships — device TTS. Hook: tracking who concedes what.
3. **`es-b2-text-postura`** (SR, family: clone `es-b1-cronica-lectura`) —
   bank `es-b2-text-postura`, launch `es-b2-text-postura-launch`, genre
   `short-article`, four alternating-position sections per D2. Question set
   includes cross-section comparison items. Glossary 4–8 entries; the
   discussion relies on contrastive connectives already drilled in lesson 1.
4. **`es-b2-dialogo-mediar`** (DB, family `conversation`) — dialogue
   `es-b2-dialogo-mediar`, host-bound to this lesson. Multi-turn mediation:
   learner is the third party relaying positions, finding common ground,
   proposing a way forward; `choice` + `open` nodes, ≥3 turns every path,
   clarification + miscommunication recovery, explicit end states, self-
   assessed `open` nodes rubric-scored (never auto-graded). Hook: summarising
   both sides before proposing. (Maps to the CoE mediation descriptors in §2
   — as design reference only.)
5. **`es-b2-argumento-escrito`** (OTW, family: clone unit-25's escrito
   lesson; `mode: written`) — activity `es-b2-argumento-open-task`. Goal:
   state a position on a topical issue, give reasons, acknowledge and answer
   the strongest counterpoint. `requiredPoints[]`: position stated; ≥2
   reasons; explicit counterpoint acknowledged; response to counterpoint.
   `rubric` 2–4 criteria (position clarity / reason support / counterpoint
   handling), `modelResponse`, `lengthGuidance` — the self-assessed written
   engine, no auto-grading.
6. **`es-b2-postura-mission`** (mission, family `mission`, FT + SC like
   `es-b1-arreglo-mission`) — free-talk: deliver a short argued take
   aloud; self-compare against the model. `cefr: "B2"`.

Hook distinctness: six distinct targets (connective noticing, concession
tracking, cross-section evaluation, two-sides summarising, counterpoint
writing, spoken argued take) — no two lessons reuse a hook, per the
batch-2 12-hook-map discipline.

## 6. Research-before-authoring ✅ COMPLETE (2026-09-27)

**Done:** `docs/reviews/2026-09-27-b2-pilot-grammar-sources.md` — verification
pass (lib-16) with no-fabrication discipline. **That file is the
authoritative citation record**; the table below is its transfer summary.
Statuses: R3 CONFIRMED · R1/R2/R4 SINGLE-SOURCE · Fundéu register entry GAP ·
Butt & Benjamin UNVERIFIABLE-ONLINE throughout (no B&B section numbers may
be cited).

| # | Point | Verified authority | Wording limit |
|---|---|---|---|
| R1 | `aunque` + indicative vs subjunctive in concessives | **NGLE §47.13** (rae.es) — hypothetical → subjunctive; factual → both modes | no B&B §16.12.8 citation; single-source only |
| R2 | Contrastive adverbial connectors (`sin embargo`, `no obstante`, `en cambio`) | **NGLE §30.13** (+ gramática básica grouping) | no Fundéu register-difference claim (GAP); don't overstate register |
| R3 | `pero` (conjunction, not postposable) vs adverbial connectors | **NGLE §31.10 + §31.10j** — "redundante, pero enfática" combinations | quote §31.10j exactly if quoted |
| R4 | Stance/hedging markers (`creo que`, `en mi opinión`, `parece que`) | **Yao (2025) *Ibérica* abstract** — hedging as a documented category | never claim the abstract validates this specific marker list |

Also required of authoring: strict accents on every Spanish string; no
C1-tier constructions slipped into "B2-oriented" copy; every dialogue/OTW/SR
learner-facing string obeys the strict editorial rules (the `--strict` gate
checks free-production / auto-grade violations anyway, but content must not
invite them). Developer owns final naturalness wording — flag all model
responses and the marker-teaching copy for native review.

## 7. Pins and gates (from exp-5; authoring lane updates, orchestrator gates)

- `PackSpanishTests.swift`: `pack.version` `0.7.14`→`0.7.15` (:248);
  `units.count` 25→26 (:251); `lessons.count` 100→106 (:249, :2884, :3221);
  `activities.count` 847→(847+N, N counted at authoring) (:250, :3220).
  Do NOT touch: checkpoint pins (:145-147, decision D5), historical-version
  fixture pins (:1919-1921 `0.7.2` shape, :2882 pre-6.2 fallback — verify
  each pin's semantics before editing).
- Activity/SL/DB/OTW/SC tallies if asserted elsewhere (SL 8, SR 8, dialogues
  10, open tasks 11, self-compares 9 per batch-2 note — recount at authoring).
- `python3 tools/gen_lesson_catalog.py …` ×2 + shasum: catalog **303 → 309**.
- Standard fresh battery per slice: `check_packs` (incl. unseen-wording,
  reachability, media-integrity, attribution-citation), `audit_editorial
  --strict`, `audit_outcomes`, catalog idempotency, `git diff --check`,
  combined suite (expected **555 + N** unit / 6 UI), then phase-boundary
  `preflight.sh --with-ui` at the 8.3 close.
- Check_packs constraints that shape authoring: unknown activity kinds
  rejected; checkpoint/sustained/open-task/dialogue unseen-wording rules
  (no string reuse across banks); every `reviewOf`/`conceptId`/`vocabulary`/
  media reference resolves; entry-lesson reachability + acyclic
  prerequisites; `ErrorCategory` values limited to the 12-case enum
  (`CoursePack.swift:291-304`).

## 8. Batch-end (orchestrator-owned, after the slice gates)

README counts, skill-map recount (85→86 units / 303→309 lessons / 48→48
missions / 38→38 stories — recount, don't assume), F13 pack
description/attribution (decide whether the pack description gains a
"B2-oriented" sentence mirroring the B1 non-claim construction — flag to
developer), defect-log currency, verification note, ledger rows for any new
grammar cells (native review + sign-off cells remain developer-owned).

## 9. Open developer decisions (non-blocking until review)

1. Working title / theme of `es-unit-26` (D1).
2. Acceptance of D2 as the pilot's contrast mechanism (single article with
   alternating sections, not a paired-texts schema).
3. Usefulness verdict after on-device walkthrough — gates continuation of
   the B2 line (plan text; replication to other languages stays gated on
   7.2 regardless).
4. Wording approval: pack-description sentence (batch-end), OTW
   `modelResponse` + rubric wording, all SR/SL/DB learner-facing copy
   (developer owns wording).
5. Naturalness review of the two-voice SL (provenance `reviewPending: true`
   until a human listens on-device — same status as batch-2 SLs).
