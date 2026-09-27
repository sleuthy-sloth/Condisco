# B1-oriented pilot — extension batch 1 (units 21–23) — authoring outline (Spanish) — 2026-09-26

Phase 8.1 prep: the authoring plan for **batch 1 of the B1-oriented extension** —
three connected units of six lessons each in Spanish, extending the shipped
pilot (`es-unit-18/19/20`, 18 lessons) toward the plan's "six to eight thematic
B1-oriented units" for the pilot language. This document is a **plan, not
shipped content**: every lesson id below is **proposed** (`none shipped`). It is
the content spec the subsequent source-research and one-unit-at-a-time
authoring slices execute. No file under `Condisco/` was touched by this slice.

Companion spec kept deliberate: this outline mirrors the 7.1 outline
(`docs/reviews/2026-09-26-b1-pilot-outline.md`) — same structural template
(unit × lesson tables, coverage matrix, bridge map, mechanism checklist,
grammar-point tables, flags). It adds the 8.1-specific checkpoint investigation
(§7), which the pilot outline left as a mechanism note (F3).

Wording discipline is inherited unchanged: content-alignment labels only —
the app and these docs call the extension **B1-oriented**, never "B1
achieved" (`docs/editorial-rubric.md`, content-alignment labeling rule R6).
Native naturalness and learner outcomes remain **unverified** for every content
claim in this outline, exactly as for the pilot.

Everything below is grounded in the real pack (`Condisco/Content/packs/
spanish.json`, `es-foundations`, version 0.7.9, 70 lessons / 20 units / 591
activities): every retrieval hook names an existing shipped lesson id (all 18
pilot lessons plus the A2 tail, verified 2026-09-26 via the pack's `lessons[]`),
and every content-type marker maps to a mechanism that exists in the pack today
(§5 mechanism checklist, verified against the same files the 7.1 outline cited).

---

## 1. Why these three themes (kept, with justification)

The orchestrator's batch-1 trio is **personal accounts · plans and
consequences · opinions with reasons**, a narrative → causal → argumentative
progression that also feeds the later B2-oriented pilot's argumentative
strand. **Kept as proposed.** It is three of the plan's five suggested themes;
the remaining two are handled explicitly (§3, flag F17).

| Theme | What it extends / retrieves in the shipped pack |
|---|---|
| **Personal accounts** (narrative) | Deepens the pilot's connected-narration strand: `es-b1-retraso-narracion` (u18, connected past narration), `es-b1-viaje-escrito` (u18, written account), `es-b1-aeropuerto-listen` (u18, spoken exchange); A2 base `es-a2-preterito-imperfecto` / `es-a2-fin-de-semana` (u13), `es-a2-imperfecto` (u13). |
| **Plans and consequences** (causal) | Extends the pilot's plan/reason strand from `porque` (cause) to consequence frames (`por eso`, `así que`, `entonces`, `si… + consequence`): `es-b1-trabajo-futuro` / `es-b1-plan-escrito` (u19), `es-b1-fiesta-listen` / `es-b1-plan-dialogo` / `es-b1-regalo-mission` (u20); A2 base `es-a2-planes-intenciones` / `es-a2-futuro-usos` (u14). |
| **Opinions with reasons** (argumentative) | Seed of the B2 argumentative strand: `es-b1-preferencia-razones` (u20, preference + porque), `es-b1-celebracion-lectura` (u20, thread deliberation), `es-b1-decision-dialogo` (u19, comparing options); A2 base `es-free-time-foundation` (u11), `es-a2-comparativos` (u16), `es-a2-subjuntivo-intro` (u15). |

Why kept rather than swapped:

1. **The ramp is scope-natural.** Connected narration (u21) → causal
   consequence (u22) → opinion with reasons (u23) is a single rising
   complexity curve against a fixed repertoire; each unit layers one new
   sentence-level frame family onto the previous one (time/order → cause →
   consequence → opinion introducers plus trigger recognition). The pilot's
   `porque`-first decision (F4) pays off continuously: u21 consolidates it,
   u22 extends cause to consequence, u23 uses it as the reason backbone of
   opinions.
2. **The retrieval surface is exactly the shipped pilot.** All 18 new lessons
   hook their delayed review into shipped units 18–20 (1:1, every shipped
   pilot lesson re-pulled exactly once — §2). Alternative trios from the plan
   (e.g. leading with practical problems) would either re-tread the u17-u18
   problem-reporting surface (`es-a2-hotel-mission`, `es-b1-reclamacion-mission`)
   or hook a thinner set of shipped lessons.
3. **"Understanding longer speech/text" is folded in, not lost.** The plan's
   comprehension theme is the sustained-input motif of all three units: 1 new
   sustained reading + 2 new sustained listenings (§2). "Practical problems"
   is deliberately deferred to batch 2 and **labeled as not covered** rather
   than silently absorbed (§3, F17).

This is a justification, not a silent deviation: the trio stands exactly as the
orchestrator proposed it.

---

## 2. Unit × lesson table (18 proposed lessons)

Conventions followed from the pack and the 7.1 outline (unchanged):

- **Lesson ids** continue the `es-b1-<theme>-<suffix>` family-flavored pattern
  (`-listen` listening, `-lectura` sustained reading, `-dialogo` conversation,
  `-escrito` recall/open-task, `-mission` mission, `-conectar`/`-frames`
  discovery, `-construccion` construction, `-historia` story). New ids → the
  orchestrator regenerates the lesson catalog (`tools/gen_lesson_catalog.py`)
  after authoring.
- **Unit ids** continue the numeric convention: `es-unit-21` / `es-unit-22` /
  `es-unit-23` (new `units[]` entries, appended after `es-unit-20`, and the
  units' lessons appended after the unit-20 lessons in `lessons[]` — that
  append order is what the course browser's `unitsInOrder` derives from).
- **Families** are from the existing enum (`discovery, story, conversation,
  listening, construction, scene, mission, recall`; `CoursePack.swift:111-114`).
  Batch 1 uses discovery, listening, story, construction, conversation, recall,
  mission — seven families; `scene` stays unused pack-wide (noted, not a
  blocker).
- **Content-type markers** (all exist in the pack, §5): SR = sustained-reading
  (`sustainedTexts[]` + step `sustainedTextId`); SL = sustained-listening
  (`sustainedListenings[]` + step `sustainedListeningId`, multi-section,
  alternating es-ES/es-MX device voices — the 6.1 `es-sustained-listen-llamada`
  pattern); **OTW** = open-task written (self-assessed, never auto-graded);
  **SC** = self-compare (`es-b1-*-say`, embedded in the closing mission);
  **DB** = dialogue-branch (`dialogues[]` bank + host lesson); **FT** = final
  task in a new setting (mission terminal step, M5).

**Delayed review (the extension's core requirement):** every new lesson declares
exactly **one** `legacy-success` prerequisite pointing at a **shipped pilot
lesson (units 18–20)** — the established pilot pattern, which the pack carries
on all 18 pilot lessons (verified: 18/18 declare a single `legacy-success`
prereq; non-mission lessons' `legacyExercises[].reviewOf[]` re-pull the same
hook per activity). The hook map below is **1:1** — each of the 18 shipped
pilot lessons is re-pulled by exactly one batch-1 lesson. All hook ids exist in
the pack (verified against `lessons[]`, 2026-09-26).

### Unit 21 — `es-unit-21` "Historias que cuento" (personal accounts)
**Communicative outcome:** recount a personal story in connected sentences, say
what people told you, react to someone else's account, and retell it to a new
listener.

| Proposed id | Family | Title | Communicative outcome | Grammar/vocab in context | Retrieval hook (from shipped pilot) | Content markers |
|---|---|---|---|---|---|---|
| `es-b1-historia-conectar` | discovery | Contar una historia | Connect 3+ narration sentences with time/order **and** contrast markers (mientras, cuando, pero, aunque) | Mientras + imperfecto (background) vs cuando + pretérito (event); pero/aunque in narration; sequence markers revisit | `es-b1-retraso-narracion` (u18L1 connected narration) | — (supported practice: selection/cloze/text on story stimuli) |
| `es-b1-anecdota-listen` | listening | Una anécdota del sábado | Follow a 4-section spoken personal account: gist plus two details | Spoken narration markers (pues, entonces, al final resultó que); spoken tense switching | `es-b1-aeropuerto-listen` (u18L3 SL pattern) | **SL** (new `es-b1-listen-anecdota`, 4 sections, alternating voices) |
| `es-b1-equivoco-historia` | story | El mensaje equivocado | Follow and retell a story where a message goes wrong: main point plus two details | Reported frames (me dijo que, le dije que) in a story; mientras background; porque reason | `es-b1-viaje-escrito` (u18L5 written account frames) | — (story stimulus + comprehension + retell steps) |
| `es-b1-reaccion-dialogo` | conversation | ¿Y qué pasó? | Hold a 3+ turn branched exchange reacting to a friend's story: ask for detail, share a reaction, offer a parallel anecdote | Reaction/follow-up frames (¿en serio?, ¡qué fuerte!, ¿y luego?, ¿y qué hiciste?); porque/aunque in replies | `es-b1-reprogramar-dialogo` (u18L4 hosted dialogue) | **DB** (new `es-b1-dialogo-historia` in the dialogues bank; host lesson) |
| `es-b1-historia-escrito` | recall | Cuéntame algo que te pasó | Write 2–4 connected sentences about something that happened to you, with time/order markers and one porque or pero clause | Connected past narration in writing; porque first reappears in written output post-pilot; sequence markers | `es-b1-preferencia-razones` (u20L1 porque reason frames) | **OTW** (self-assessed; rubric ticks, model revealed on demand) |
| `es-b1-relato-mission` | mission | El relato | Retell the practiced anecdote to a **new listener in a new setting** (a personal voice note to a friend) with a closing reaction | Retell frames (pues/entonces/al final); reported speech light; reaction closer | `es-b1-reclamacion-mission` (u18L6 mission pattern, reported frames) | **FT** (new setting: personal voice-note message) + **SC** (embedded `es-b1-relato-say`) |

### Unit 22 — `es-unit-22` "Planes y consecuencias" (plans and consequences)
**Communicative outcome:** state a plan, say what it depends on, and explain
consequences — anticipated and actual — with causal and consequence frames.

| Proposed id | Family | Title | Communicative outcome | Grammar/vocab in context | Retrieval hook (from shipped pilot) | Content markers |
|---|---|---|---|---|---|---|
| `es-b1-consecuencia-conectar` | discovery | Por eso, así que | Link a plan/event to its consequence with por eso, así que, entonces; distinguish from porque (cause) | Consequence connectors vs porque; sentence position; plan vocab revisit | `es-b1-trabajo-futuro` (u19L1 plans/future) | — |
| `es-b1-cambio-planes-lectura` | discovery | El cambio de planes | Read a before/after account of changed plans: main point plus two supporting details | Plans + outcome frames (pensaba que…, al final…, salió bien/mal); porque + por eso in one text | `es-b1-entrevista-lectura` (u19L3 SR pattern) | **SR** (new `es-b1-text-cambio-planes`, 4 sections) |
| `es-b1-si-entonces` | construction | Si pasa esto… | Build and complete open-conditional sentences: si + present → consequence (future/ir a) | Si + presente → futuro/ir a; real-conditional scope (si tuviera out of pilot scope) | `es-b1-plan-escrito` (u19L5 plan frames) | — (construction: ordering/cloze/text on dictated si-sentences) |
| `es-b1-cambio-dialogo` | conversation | ¿Y si cambiamos? | Negotiate a change of plans in a 3+ turn branched exchange, stating causes and consequences | Change-of-plan frames (¿qué tal si…?, mejor…, nos quedamos en…, lo dejamos para otro día); por eso/así que | `es-b1-fiesta-listen` (u20L2 planning-call content) | **DB** (new `es-b1-dialogo-consecuencia` in the dialogues bank; host lesson) |
| `es-b1-consecuencia-escrito` | recall | Tu plan y su consecuencia | Write 2–4 connected sentences: a plan, its likely consequence, and one because/so link | ir a/futuro + porque/por eso in connected writing; sequence markers | `es-b1-decision-escrito` (u20L5 written decision frames) | **OTW** (self-assessed) |
| `es-b1-plan-mission` | mission | El plan al aire libre | Organise an outdoor plan with a rain backup and tell the group the decision + consequence — a **new setting** vs all shipped venues | Si + present consequences in use; por eso/así que; weather if-clauses light | `es-b1-regalo-mission` (u20L6 group-decision mission) | **FT** (new setting: outdoor event planning) + **SC** (embedded `es-b1-consecuencia-say`) |

### Unit 23 — `es-unit-23` "Opiniones con razones" (opinions with reasons)
**Communicative outcome:** give an opinion with a reason and a supporting
detail, agree/disagree politely, and follow a longer spoken discussion of
opinions.

| Proposed id | Family | Title | Communicative outcome | Grammar/vocab in context | Retrieval hook (from shipped pilot) | Content markers |
|---|---|---|---|---|---|---|
| `es-b1-opinion-frames` | discovery | Dar una opinión | State an opinion with creo que/pienso que/me parece que + porque; recognise disagreeing triggers | Opinion introducers + indicativo; porque reason; no creo que + subjuntivo (recognition only) | `es-b1-celebracion-lectura` (u20L3 thread deliberation) | — |
| `es-b1-opinion-listen` | listening | ¿Qué opináis? | Follow a multi-section discussion with agreement/disagreement: gist plus two details | Spoken opinion frames; disagreed turns (bueno, sí, pero…; a ver; ¿tú qué crees?); porque reasons | `es-b1-trabajo-listen` (u19L2 SL pattern) | **SL** (new `es-b1-listen-discusion`, 4 sections, alternating voices) |
| `es-b1-opinion-construccion` | construction | Estoy de acuerdo | Build opinion sentences: agree (tienes razón, de acuerdo), disagree politely (no estoy seguro/a), each with a reason | Agreement/disagreement frames; de acuerdo vs estoy de acuerdo; creo que + porque dictated sentences | `es-b1-decision-dialogo` (u19L4 comparing options) | — (construction: ordering/cloze/text) |
| `es-b1-opinion-dialogo` | conversation | ¿Tú qué opinas? | Discuss a choice in a 3+ turn branched exchange, agreeing/disagreeing politely with reasons | Opinion frames + porque; softening (no estoy seguro); repair on disagreement | `es-b1-plan-dialogo` (u20L4 hosted dialogue + repair) | **DB** (new `es-b1-dialogo-opinion` in the dialogues bank; host lesson) |
| `es-b1-opinion-escrito` | recall | Tu opinión | Write 2–4 connected sentences: an opinion, one porque reason, and a supporting detail (además/por ejemplo) | Opinion + reason + detail in connected writing; register (written > chat) | `es-b1-aviso-lectura` (u18L2 reading-comprehension skill) | **OTW** (self-assessed) |
| `es-b1-recomendacion-mission` | mission | Recomiéndalo | Recommend something to someone new (a place/film/plan) in a **new setting** (a review / recommendation to a newcomer) | Opinion + reason + detail register; polite recommendation frames; para + purpose | `es-b1-entrevista-mission` (u19L6 self-presentation mission) | **FT** (new setting: review/recommendation) + **SC** (embedded `es-b1-recomendacion-say`) |

**Per-unit requirement coverage (from plan 8.1):**

| Requirement (per unit) | Unit 21 | Unit 22 | Unit 23 |
|---|---|---|---|
| Sustained input (≥1) | SL | SR | SL |
| Vocabulary/grammar in context | ✓ every lesson | ✓ every lesson | ✓ every lesson |
| Delayed review into shipped units 18–20 (exactly one `legacy-success` prereq per lesson) | ✓ 6 hooks (u18 ×5, u20 ×1) | ✓ 6 hooks (u19 ×3, u20 ×3) | ✓ 6 hooks (u18 ×1, u19 ×3, u20 ×2) |
| Connected writing | OTW `es-b1-historia-escrito` | OTW `es-b1-consecuencia-escrito` | OTW `es-b1-opinion-escrito` |
| Spoken self-comparison | SC in `es-b1-relato-mission` | SC in `es-b1-plan-mission` | SC in `es-b1-recomendacion-mission` |
| Multi-turn interaction | DB `es-b1-reaccion-dialogo` | DB `es-b1-cambio-dialogo` | DB `es-b1-opinion-dialogo` |
| Final task in a new setting | voice-note retell | outdoor plan with backup | review/recommendation |
| Input-to-output arc (no grammar-only unit) | notice frames → hear a story → read a story → react in dialogue → write your account → retell to a new listener | frames → read changed plans → build si-sentences → negotiate a change → write plan+consequence → decide the outdoor plan | frames → hear a discussion → build opinions → discuss → write your opinion → recommend |

Sustained-input balance across the batch: **+1 SR and +2 SL** (pack banks go
6→7 sustained texts, 4→6 sustained listenings). The extra SL is deliberate:
the `listening` family is the pack's rarest (3 lessons) and was flagged
unproven in es at 7.1 (F1); hardening it is the principled choice, and the
narrative and opinion themes map naturally onto spoken sustained input while
plans/consequences maps onto a written before/after account.

Embedding each unit's self-compare **inside its closing mission** mirrors the
shipped precedent (`es-cafe-listen-say`, and the pilot's three embedded `say`
activities) and keeps every unit at six lessons.

---

## 3. Coverage matrix vs the 8.1 done-when

The 8.1 done-when is expressed per **path**, not per unit: *each shipped
B1-oriented path has mapped tasks, sustained input, connected output,
interaction, delayed review, and checkpoint evidence; any language still
lacking those is labeled accurately.* Parity across future languages is tracked
by communicative function × modality, never lesson counts.

| 8.1 done-when item | Unit 21 | Unit 22 | Unit 23 | Shipped evidence the pilot already covers |
|---|---|---|---|---|
| **Mapped tasks** — every lesson's task map resolves to an existing mechanism | 6/6 lessons map to shipped step/activity kinds (selection, text, cloze, ordering, dialogue-choice, open-task, self-compare, mission terminal) | 6/6 same kinds | 6/6 same kinds | 7.1 §5 mechanism checklist; pilot lessons 18–20 authored on exactly these kinds. Batch 1 invents nothing (§5 re-verifies every marker) |
| **Sustained input** (≥1 per unit) | SL `es-b1-listen-anecdota` (4 sections, es-ES/es-MX voices) | SR `es-b1-text-cambio-planes` (4 sections) | SL `es-b1-listen-discusion` (4 sections, es-ES/es-MX voices) | Pilot ships 6 SR / 4 SL bank entries (3+3, 1+3); batch adds +1 SR / +2 SL → 7 SR / 6 SL. Path total per unit stays ≥1 (pilot units had 2 each) |
| **Connected output** | OTW `es-b1-historia-escrito` + SC `es-b1-relato-say` | OTW `es-b1-consecuencia-escrito` + SC `es-b1-consecuencia-say` | OTW `es-b1-opinion-escrito` + SC `es-b1-recomendacion-say` | OTW kind self-assessed (H1/H2, never auto-graded); SC outcome `.selfAssessed` — precedent `es-b1-viaje-escrito`, `es-cafe-listen-say` |
| **Interaction** | DB `es-b1-dialogo-historia` (≥3 learner turns, clarification/misunderstanding/recovery nodes) | DB `es-b1-dialogo-consecuencia` | DB `es-b1-dialogo-opinion` | `dialogues[]` bank pattern of `es-b1-dialogo-vuelo/-oferta/-fiesta` (hostLessonId, prereq, start, nodes with choices→next) |
| **Delayed review** | 6 `legacy-success` prereqs into shipped pilot (u18 ×5, u20 ×1) + per-activity `reviewOf[]` | 6 prereqs (u19 ×3, u20 ×3) | 6 prereqs (u18 ×1, u19 ×3, u20 ×2) | The pilot itself established the pattern (18/18 lessons carry a single legacy-success prereq; non-missions re-pull the hook per activity). Batch 1 is 1:1 — all 18 shipped pilot lessons re-pulled exactly once (§2) |
| **Checkpoint evidence (unseen)** | Path-level: the Independent path's single unseen checkpoint (`es-cp-independent`, 3 items) surfaces after the **last** Independent unit — unit 23 after the extension ships (Option A, §7). Its unseen passage and prompts exercise plans, `porque` reasons and a choice with a reason — the batch's causal/opinion themes | same | same | Pilot F3: one entry per stage is the honest shape (`CoursesView.swift:405`, `first { $0.stage == stage }`); the card auto-relocates because `checkpointAfterLastUnitOfStage` computes "last unit of stage" from lesson order. **No per-unit checkpoint card is claimed** — that reading needs an app change (§7, flag F-option C) |

**Status: all six done-when rows met at the path level** (mapped tasks,
sustained input, connected output, interaction, delayed review, checkpoint
evidence), with two labeled qualifications:

1. **Checkpoint evidence is path-level, not per-unit.** The batch adds **no**
   checkpoint bank entries; the one Independent checkpoint moves to the
   extended path's end (recommended Option A, §7). Verified Surfacing math in
   §7. This is the same reading the pilot used (7.1 F3); a strict per-unit
   "each unit ends with its own unseen checkpoint" reading is out of reach
   without an app change — flagged for the orchestrator/developer, not
   implemented here.
2. **"Practical problems" is not in batch 1.** Labeled accurately: it is a
   batch-2 unit theme. Nearest shipped partial evidence — `es-a2-hotel-mission`
   (u17) and `es-b1-reclamacion-mission` (u18) exercise polite problem-reporting
   at A2-/B1-adjacent level — is cited here so the gap is a named gap, not a
   silent one (F17). "Understanding longer speech/text" **is** exercised as the
   motif of all three sustained inputs (plus the pilot's six): the plan's five
   theme list is 4/5 covered across the extended path, the fifth labeled open.

**Language/parity discipline:** Spanish batch 1 covers the communicative
functions *personal accounts, plans and consequences, opinions with reasons*
across the modalities reading/writing/speaking/listening (the parity unit for
future languages is function × modality, and batch 1 defines that grid via the
markers above — it is transferable to fr/it/de/pt). **No coverage row is ever
labeled "B1"** — the wording throughout stays **"B1-oriented"**; native
naturalness and learner outcomes remain **unverified** for all batch-1 content.

---

## 4. Bridge-gap alignment (rubric §"A2→B1 bridge (Spanish)")

The five bridge capabilities were first taught by the pilot; batch 1 extends
them, never re-invents:

| # | Capability | Pilot (shipped) | Batch 1 extension | Status |
|---|---|---|---|---|
| B1 | Connected narration (3+ sentences, time/order markers) | `es-b1-retraso-narracion`, `es-b1-viaje-escrito` | u21 L1 (contrast + sequence), L3 story, L5 OTW, L6 retell — narration now includes porque *and* pero/aunque | extended, covered |
| B2 | Explanation of a preference/reason (`porque` + sentence) | first taught u18L4/L5 (F4, decided 2026-09-26) | u21 L5 (porque reappears in written output), u22 (causal → consequence: por eso, así que, entonces), u23 (opinion + porque backbone) | extended, covered |
| B3 | Following multi-turn exchanges | 3 × DB + 3 × SL calls (u18–u20) | 3 new hosted DB (u21L4, u22L4, u23L4) + 2 new SL discussions (u21L2, u23L2) | extended, covered |
| B4 | Extracting main point + supporting detail | all 6 SR/SL pilot lessons (gist + ≥2 details) | 3 new sustained inputs, each gist step + ≥2 detail checks | extended, covered |
| B5 | Short connected written response (2–4 sentences) | 3 × OTW (u18L5, u19L5, u20L5) | 3 new OTW (u21L5, u22L5, u23L5); product dependency already resolved (open-task self-assessed) | extended, covered |

**Beyond the bridge:** batch 1 adds the causal step the bridge does not name —
consequence frames beyond `porque` (u22) — and the argumentative seed (u23)
that the later B2-oriented pilot's argumentative strand will build on. Both are
content-alignment claims only; no learner-level claim anywhere.

---

## 5. Mechanism checklist — every marker maps to something that exists today

All verified against `es-foundations` v0.7.9 + `Condisco/Models/CoursePack.swift`
+ `Condisco/Lesson/CoursesView.swift` + `Condisco/Lesson/CheckpointFlow.swift` +
`Condisco/Store/LearningStore.swift` on 2026-09-26 (this slice):

| Mechanism | Exists today (evidence) | Batch 1 use |
|---|---|---|
| Sustained reading | `sustainedTexts[]` bank (6 entries: 3 shipped + 3 pilot); step binds via `sustainedTextId` | 1 new: `es-b1-text-cambio-planes` (u22L2) |
| Sustained listening | `sustainedListenings[]` bank (4 entries: 1 shipped + 3 pilot, per-section headings/text/`voiceId`/`languageCode`/`accessibilityLabel`); step binds via `sustainedListeningId` | 2 new: `es-b1-listen-anecdota` (u21L2), `es-b1-listen-discusion` (u23L2) |
| Open task (written) | `open-task` kind, `mode: written`, self-assessed rubric, `modelResponse` reveal (3 pilot OTW shipped) | 3 new: `es-b1-historia-escrito-open-task`, `es-b1-consecuencia-escrito-open-task`, `es-b1-opinion-escrito-open-task` |
| Self-compare | `self-compare` kind, `modelText` + optional `modelAudioId`, outcome `.selfAssessed` (pilot pattern `es-b1-*-say`) | 3 embedded: `es-b1-relato-say`, `es-b1-consecuencia-say`, `es-b1-recomendacion-say` |
| Dialogue branch | `dialogues[]` bank (5 entries incl. 3 pilot: `hostLessonId`, `prerequisite`, `start`, `nodes[]` with `choices→next`, clarification/misunderstanding/recovery kinds) + in-lesson `dialogue-choice` | 3 new bank entries: `es-b1-dialogo-historia` (host u21L4), `es-b1-dialogo-consecuencia` (host u22L4), `es-b1-dialogo-opinion` (host u23L4) |
| Checkpoint bank | `checkpoints[]` with `stage: foundation\|developing\|independent` (3 entries); **the UI consumes exactly one per stage** — `pack.checkpoints.first { $0.stage == stage }` (`CoursesView.swift:405`) surfacing only after the last unit of the stage (`CoursesView.swift:400-406`); `LearningStore.recordCheckpointAttempt` resolves by id (`LearningStore.swift:1913`) | **none new — Option A (position shift, §7)** |
| Delayed review | `legacyExercises[].reviewOf[]` per activity + `prerequisites[]` `legacy-success` (18/18 pilot lessons carry the pattern, verified) | 18 hooks, 1:1 into shipped units 18–20 (§2) |
| Final task in a new setting | Mission terminal steps (distinct pre-planned final response, M5); "new setting" is an authoring choice on existing step kinds | 3 FT missions (voice-note retell / outdoor plan / recommendation) |
| cefr → Independent path | `CoursesView.coursePath(of:)` default branch + `CheckpointFlow.checkpointStage(of:)` default branch | `cefr: "B1"` alignment tags on all 18 new lessons |

**New assets batch 1 will add (all additive schema shapes, nothing structural):**
1 `sustainedTexts[]` entry, 2 `sustainedListenings[]` entries, 3 `dialogues[]`
entries, **0 checkpoint entries**, 18 lessons / ~20 activity groups under 3 new
units, concepts/vocabulary for the new grammar/vocab, and 2 audio-provenance
records. The pack is additive-shape safe (`PackUpdateTests` pins that a grown
checkpoint bank and added assets project unchanged; the count/version pins
in `PackSpanishTests` are deliberate update points — F10).

---

## 6. Grammar-point list per unit — every point **source-pending**

Source policy unchanged from the pilot: every disputed/known-tricky grammar or
usage point needs **two independent authoritative references** (class of source:
RAE/ASALE `NGLE`/`DPD`, Fundéu, etc.). **No citation is fabricated here** — every
row below is explicitly **source-pending**; the research lane fills reference 1
+ reference 2 + disposition before authoring teaches the point. (The 6.1 class
of note is preserved: two AI models agreeing never clears a point — only
reference-backed disposition does.)

### Unit 21 — Historias que cuento (lesson → point mapping: L1→21.1, L2→21.2, L3→21.3, L4→21.4, L5→21.5, L6→21.6)
| # | Point | Tricky aspect worth two-source verification | Source status |
|---|---|---|---|
| 21.1 | Narration connectors vs contrast: mientras/cuando/más tarde + pero/aunque | mientras + imperfecto (background) vs cuando + pretérito (punctual); aunque + indicativo vs subjuntivo (conceded vs hypothetical) scope decision | **source-pending** |
| 21.2 | Spoken narration markers: pues, entonces, al final resultó que | Register/frequency in informal spoken retelling; whether resultó que is idiomatic at B1; recognition vs production scope | **source-pending** |
| 21.3 | Reported frames in a story: me dijo que / le dije que + tense | Tense sequence in reports of completed vs pending events (dijo que llegaba/llegaría/llega — which read natural at B1); non-backshifted sequences accepted per the u18 A4 findings — re-verify for story register | **source-pending** |
| 21.4 | Reaction/follow-up frames: ¿en serio?, ¡qué fuerte!, ¿y luego?, ¿y qué hiciste? | Idiomaticity and register of reaction particles; pedagogical-convention ordering — flag if no authoritative usage source exists | **source-pending** |
| 21.5 | Written account structure: primero/luego/al final + one porque or pero clause | Paragraph-level ordering conventions vs spoken narration; distribution of porque vs pero in a short text | **source-pending** |
| 21.6 | Retell framing: tuve que / decidí / al final resultó que + closer | Register of impersonal resultó que; tuve que (event/obligation) vs tenía que (background) in retelling | **source-pending** |

### Unit 22 — Planes y consecuencias (L1→22.1, L2→22.2, L3→22.3, L4→22.4, L5→22.5, L6→22.6)
| # | Point | Tricky aspect worth two-source verification | Source status |
|---|---|---|---|
| 22.1 | Consequence connectors: por eso, así que, entonces, de manera que | Semantic/register overlap and sentence position; which are B1-natural in speech vs writing | **source-pending** |
| 22.2 | por eso (consequence) vs porque (cause) in one text | Clause function and position distinction; both connect to the B2 bridge decision (porque first at u18L4/L5) | **source-pending** |
| 22.3 | Open conditional: si + presente → futuro/ir a consequence | Real vs unreal conditionals at B1 (si tuviera out of pilot scope — decide and record); ¿y si…? + indicative vs subjunctive in questions | **source-pending** |
| 22.4 | Plan/outcome frames: pensaba que…, al final…, salió bien/mal, cambiamos de plan | Aspect in outcome reporting (pensaba que + past); register of cambio de planes / cambiamos de plan | **source-pending** |
| 22.5 | Change-of-plan conversation frames: ¿qué tal si…?, mejor…, nos quedamos en…, lo dejamos para otro día | Register/frequency in informal negotiation; pedagogical-convention flag if no authoritative usage source | **source-pending** |
| 22.6 | Polite re-planning: podríamos, se podría, ¿te importaría si…? | Register ordering of the politeness set (parallel to the u18 A3 pair); ¿te importaría si + subjunctive trigger | **source-pending** |

### Unit 23 — Opiniones con razones (L1→23.1, L2→23.2, L3→23.3, L4→23.4, L5→23.5, L6→23.6)
| # | Point | Tricky aspect worth two-source verification | Source status |
|---|---|---|---|
| 23.1 | Opinion introducers: creo que, pienso que, me parece que + indicativo (+ me parece + adj + que + subjuntivo recognition) | Trigger split (indicative vs subjunctive after the same verb family); negation triggers (no creo que + subjuntivo); recognition-only scope vs one dictated production | **source-pending** |
| 23.2 | Agreeing/disagreeing politely: tienes razón, de acuerdo, claro, no estoy seguro/a, no pienso igual | Register/frequency; de acuerdo vs estoy de acuerdo; softening frames; pedagogical-convention flag where no authoritative source | **source-pending** |
| 23.3 | Opinion + reason + supporting detail: porque + además / por ejemplo | Connector register in opinion texts; porque clause position relative to the opinion | **source-pending** |
| 23.4 | No creo que / no me parece que + subjuntivo (light) | Negation-triggered subjunctive at B1; production scope decision (parallel to the pilot's B5 scope at `es-b1-entrevista-mission`) | **source-pending** |
| 23.5 | Spoken disagreement strategies: bueno, sí, pero…; a ver; ¿tú qué crees? | Turn-taking particles and overlap in discussion; register; pedagogical-convention flag | **source-pending** |
| 23.6 | Written opinion register: en mi opinión / para mí + reason; preference + opinion combined | Written vs chat register; para mí vs en mi opinión frequency; combination with prefiero + porque | **source-pending** |

---

## 7. Checkpoint — the "unseen checkpoint" question, investigated honestly

**What the code actually does (read, not assumed, 2026-09-26):**

- `CoursesView.swift:400-406` (`checkpointAfterLastUnitOfStage`) renders the
  stage-end card **only after the last unit of a stage**: `stageOf(unit)` is the
  unit's first lesson's cefr-derived stage (392–395), `laterSameStage` scans
  `unitsInOrder` (which derives from `pack.lessons` order, 378–383), and the
  returned task is `pack.checkpoints.first { $0.stage == stage }` — **one entry
  per stage, first in bank order** (405).
- `CheckpointFlow.swift:36-42` maps `"B1"` → `.independent`, matching the path
  cards' `coursePath(of:)` default branch (`CoursesView.swift:294-299`).
- Attempts filter by `checkpointId` (`CoursesView.swift:444-446`); the store
  resolves a record by id (`LearningStore.swift:1913`) and keys the bank by id
  (`LearningStore.swift:1676`) — **attempts survive any relocation of the card**.
- The bank is additive-safe (`PackUpdateTests` pins a grown checkpoint bank
  projecting unchanged), **but** `PackSpanishTests.swift:142-161` pins the exact
  id list `["es-cp-foundation", "es-cp-developing", "es-cp-independent"]` and
  states *"one checkpoint task ships per stage"* — any extra `.independent`
  entry breaks that test. `YouView` also counts checkpoints in its preview
  string (YouView.swift:817).

**Consequence for batch 1:** appending units 21–23 (all `cefr: "B1"` →
`.independent`) moves the surfacing automatically: the card disappears from
after unit 20 and appears after unit 23 — because "last unit of stage" is
computed from lesson order, not hard-coded.

**Options considered:**

- **Option A — stage-end card position shift (recommended).** No content, no
  code, no test change. The existing `es-cp-independent` card surfaces after the
  extended path's last unit (unit 23). It claims: the Independent path (units
  18–23) has exactly one unseen checkpoint at its true end; the existing unseen
  passage and prompts already exercise the batch's themes (plans with `porque`;
  a choice with a reason); reading remains auto-graded recognition, writing and
  speaking stay self-assessed. It does **not** claim: a per-unit checkpoint
  card, or per-unit unseen passages — the batch's units 21/22 individually end
  with their mission, not with a checkpoint card.
- **Option B — additional `.independent` bank entries.** Store-safe and
  additive-valid, but (a) `CoursesView` consumes the first entry per stage, so
  extra entries **never render** (dead content), (b) the checkpoint pin test
  breaks, (c) the YouView count changes. Only meaningful combined with Option C.
- **Option C — app change** (flag F-option C; **not implemented in this slice —
  a developer/orchestrator decision**). e.g. `checkpointAfterLastUnitOfStage`
  selects per-batch or per-unit entries, or surfaces the per-stage list. Would
  deliver true per-unit unseen checkpoints; requires bank entries, the pin-test
  update, and a UX decision on where the card sits mid-list and how attempts
  aggregate. Cost/benefit is a product call; the plan's path-level reading
  (pilot F3 already records it) does not require it.

**Recommendation: Option A.** The batch provides its unseen-checkpoint evidence
at the **path level** — one unseen checkpoint at the extended Independent
path's end — which is exactly what the shipped pilot provided and what the
8.1 done-when ("each shipped B1-oriented path has … checkpoint evidence")
asks for. If the orchestrator wants a strict per-unit checkpoint card later,
that is the Objective-flagged app change (Option C), not this slice.

---

## 8. Flags / blockers (F7+, continuing the 7.1 numbering F1–F6)

None of these blocks outline acceptance; they are honest pre-authoring notes.

- **F7 — first beyond-pilot extension of a shipped path.** Units 21–23 extend
  the Independent path past the 7.1 pilot. Every mechanism batch 1 uses
  re-verified in §5, but the path's new tail (learners reaching unit 23) is
  newly exercised content with no prior walkthrough; the developer iPhone
  walkthrough gate (outline §9, gate 5) extends to the new units.
- **F8 — checkpoint card relocation (Option A behavior).** After authoring, the
  Independent checkpoint card surfaces after unit 23, not after unit 20.
  Attempts persist (keyed by checkpoint id). A learner finishing unit 20 sees
  the card only at the extended path's end. Expected behavior — recorded so
  nobody "fixes" it into a regression. **Corollary (Option C, not implemented
  in this slice):** if the orchestrator/developer later wants per-unit unseen
  checkpoint cards, that is an app change in
  `checkpointAfterLastUnitOfStage` (`CoursesView.swift:400-406`) plus new
  bank entries plus the checkpoint id-list pin update (`PackSpanishTests`,
  F10) — a product decision, out of this slice's scope.
- **F9 — Independent path card outcome line caps at 3 objectives.**
  `CoursesView.pathOutcomeLine` (314-327) samples the first three distinct unit
  objectives in pack order; with six Independent units it keeps showing units
  18–20 objectives. Stale-but-honest; units 21–23 objectives appear on their
  unit headers. No change proposed.
- **F10 — count/version pins (developer lane at authoring time).**
  `PackSpanishTests` decode-compatibility tests pin `pack.lessons.count == 70`,
  `pack.units.count == 20`, `pack.activities.count == 591`, and version strings
  `"0.7.9"` at four sites (lines 249–251, 1904–1906, 2856–2860, 3189–3191).
  The version bump 0.7.9→0.7.10 plus +18 lessons / +3 units breaks them; they
  are deliberate update points, updated when the batch lands. The checkpoint
  id-list pin (142–161) survives under Option A.
- **F11 — catalog regen.** `tools/gen_lesson_catalog.py` must run after
  authoring (3 unit ids, 18 lesson ids, new bank entries) — orchestrator-owned,
  unchanged from pilot F6.
- **F12 — audio provenance for the 2 new SL pieces.** Facts-only records
  `docs/audio-provenance/spanish-b1-listen-anecdota.json` and
  `...-discusion.json` (pattern: `spanish-cafe-listen-pilot.json`), device
  speech via per-section `voiceId` (es-ES/es-MX alternation), `reviewPending:
  true`, no allowlist entry needed (no MediaItem assets). Authoring obligation,
  not a blocker.
- **F13 — pack metadata copy.** `description` ("Seventy Spanish lessons in
  twenty units", units list) and `attribution` gain the units 21–23 sentence
  and a batch-1 attribution line; wording stays **B1-oriented** (R6); British
  English learner-facing strings; strict accents; copy-ban scan
  (`correct/incorrect/score/graded/cefr/level`) on all dialogue and open-task
  copy fields.
- **F14 — ledger/skill-map follow-ups.** Ledger rows 19–36 are pre-created here
  (companion ledger §Extension batch 1); `docs/skill-map.md` rows for units
  21–23 land with authoring; `docs/reviews/review-log.jsonl` dispositions flow
  from the review lane.
- **F15 — listening-family hardening.** Batch 1 adds 2 more SL lessons (bank
  4→6, lessons 3→5). The 7.1 F1 note ("listening family unproven in es") now
  stands on more shipped evidence; the family remains the enum-legal pattern it
  always was.
- **F16 — SL authoring obligations (mirror pilot F2/F5).** Each new SL piece is
  multi-section with per-section `accessibilityLabel` + synthesised-voice
  disclosure + `accessibleSummary`, transcript-reveal after the
  `es-sustained-listen-llamada` pattern, es-ES/es-MX voices → the variant
  recorded in review is both regions.
- **F17 — "practical problems" absent from batch 1, labeled accurately.** It is
  a batch-2 unit theme; nearest shipped partial evidence (`es-a2-hotel-mission`,
  `es-b1-reclamacion-mission`) is cited in §3 so the gap is named, never
  papered over. "Understanding longer speech/text" is covered as the motif of
  the 3 new sustained inputs (plus the pilot's 6).
- **F18 — standing discipline re-stated for the extension:** 100% original
  content (no lifted or repurposed third-party text); open production is always
  self-assessed (H1/H2) — never auto-graded; no CEFR/level/proficiency claim in
  any objective, `culturalNote`, concept explanation, or pack/unit copy; per
  unit at least one input-to-output arc (a unit of grammar drills alone is
  rejected); catalogue iD, revision, and completion-policy discipline per the
  rubric checklist C1/C3.

---

## 9. Authoring-time gate chain (done-when, per unit — never bulk)

The plan's authoring proceeds **one unit at a time with full gates per unit**
(repeated 21 → 22 → 23), mapped to existing tooling:

1. **No dead-end branch** — the 3 new `dialogues[]` graphs validated
   (reachability of `choices→next`, terminal nodes) by `tools/check_packs.sh` +
   step-graph closure C4.
2. **No falsely graded open response** — every OTW/SC step is `selfAssessed`
   (`ActivityEvaluation.swift`), never fixed-list graded (H1); strict audit
   (`audit_editorial.sh --strict`) reports none.
3. **No missing media** — new audio declared, allowlisted where bound,
   provenance-cited (R3, F12); `check_packs.sh` green.
4. **Complete per-lesson review record** — the 8.1 ledger section's rows
   (companion ledger) move from `pending` to filled as each unit authors:
   source-backed grammar checks (outline §6 points), accepted-answer review,
   variant, audio provenance, accessibility pass, unresolved naturalness
   questions.
5. **Passing pack/unit/UI gates** — `bash tools/preflight.sh` exits 0;
   `python3 tools/audit_outcomes.py` exits 0; unit suite green (incl. the F10
   count/version pin updates the developer applies); catalog regenerated (F11);
   iPhone walkthrough by the developer recorded in the ledger's sign-off
   column.
6. **Wording gate** — product surfaces say **B1-oriented**, never "B1
   achieved" (R6); copy-bans enforced (F18). Pack version bumps 0.7.9 → 0.7.10
   at the batch level; `description`/`attribution` updated (F13).

---

## 10. Companion documents and open questions

Companions: per-lesson review ledger (`docs/reviews/2026-09-26-b1-pilot-review-ledger.md`,
§"Extension batch 1 (units 21–23)", rows 19–36, all `pending`); bridge
definitions (`docs/editorial-rubric.md` "A2→B1 bridge (Spanish, 2026-09-26)");
review conventions (`docs/native-review-kit.md`, `docs/reviews/review-log.jsonl`);
audio provenance pattern (`docs/audio-provenance/spanish-cafe-listen-pilot.json`).

**Open questions for the developer or orchestrator before content authoring:**

1. **Confirm Option A** (no new checkpoint bank entries, no Swift change; the
   single Independent checkpoint relocates to after unit 23) — or authorize the
   Option C app change for per-unit checkpoint cards.
2. **Confirm the 1:1 delayed-review hook map** (each new lesson prereqs exactly
   one shipped pilot lesson; all 18 shipped lessons used once, §2) — or prefer
   some entry lessons to hook A2 content instead.
3. **Confirm unit titles/themes** (Historias que cuento / Planes y
   consecuencias / Opiniones con razones) and the **SL, SR, SL**
   sustained-input arrangement (+1 SR, +2 SL → bank 7 SR / 6 SL).
4. **Confirm authoring order and release packaging**: units authored 21 → 22 →
   23 with full gates each; version bump 0.7.9 → 0.7.10 at the batch level (or
   per-unit release decision).
5. **Confirm the F10 count/version pin updates** are the developer lane's job
   at authoring time (they are deliberate update points).
6. **Review-lane scope for the extension rows**: rows 19–36 are `pending` until
   each unit authors; confirm the same two-source, AI-assisted-only-evidence
   conventions as rows 1–18.

### Orchestrator decisions (2026-09-26)

All six questions above are **decided**; they are resolved state for authoring
lanes, not open items:

1. **Option A confirmed.** No new checkpoint bank entries, no Swift change.
   `es-cp-independent` relocates to after unit 23 via the existing
   `checkpointAfterLastUnitOfStage` math. The literal "every unit needs an
   unseen checkpoint" reading is recorded as a **flagged deviation** (F8),
   consistent with the approved 5.3 one-entry-per-stage design; Option C
   (per-unit cards, fresh items, app change) remains a developer-authorized
   future slice only — nobody may implement it unasked.
2. **1:1 delayed-review hook map approved as designed** (each new lesson
   prereqs exactly one shipped pilot lesson; all 18 shipped lessons used once;
   hook ids verified to exist at outline time).
3. **Titles/themes and the SL, SR, SL sustained-input arrangement approved as
   written** (bank lands at 7 SR / 6 SL across the batch; per-unit: U21 SL,
   U22 SR, U23 SL).
4. **Authoring order 21 → 22 → 23 with full gates each; version bump is
   per-unit, not batch-level: 0.7.10 (u21) → 0.7.11 (u22) → 0.7.12 (u23)**,
   matching the 7.1 wave convention where every gated wave bumped. This
   supersedes the batch-level suggestion above.
5. **F10 pin/count/version updates are the AI coder lanes' job at authoring
   time.** The developer does device checks, walkthroughs, and wording
   decisions only — never test pins.
6. **Rows 19–36 use exactly the rows 1–18 conventions** (two independent
   sources per disputed point, honest gaps per C3/C5, `AI-assisted` review
   method, native review `pending`, developer sign-off empty). Source columns
   are filled from the consolidated blocks in
   `docs/reviews/2026-09-26-b1-pilot-grammar-sources.md` (Extension batch 1
   section) by a dedicated fill lane; authoring lanes do not edit the ledger
   source columns themselves.

---

# Batch 2 — units 24–25 (practical problems · understanding longer speech/text) — authoring design (2026-09-27)

Phase 8.1 continuation: the design for **batch 2 of the B1-oriented extension**
— two connected units of six lessons each in Spanish, completing the extended
path at **units 18–25 (8 B1-oriented units, 48 lessons)**. This is a **design,
not shipped content**: every lesson id below is **proposed** (`none shipped`).
It extends the batch-1 outline above (§1–§10, unchanged and decided) rather
than re-specifying its conventions — identical wording discipline (B1-oriented,
never "B1 achieved", rubric R6), identical family enum, identical content-type
markers, identical one-hook-per-lesson delayed-review convention, and the
same per-path (never per-unit) checkpoint reading (§3, F8). No file under
`Condisco/` was touched by this slice.

Grounded in the real pack as it stands after batch 1 (`Condisco/Content/packs/
spanish.json`, `es-foundations`, version **0.7.12**, 88 lessons / 23 units /
744 activities, verified 2026-09-27): every proposed lesson id is
collision-free against the pack's current id set (verified), and every
retrieval-hook candidate names a shipped lesson (units 18–23 — see B2-6).

Batch-1's two flagged theme gaps close here, explicitly and by design:
**"practical problems"** becomes unit 24 (it was labeled *not covered* in §3,
F17), and **"understanding longer speech/text"** — previously only the motif
of batch-1's sustained inputs — becomes unit 25's *raison d'être*, carrying
**both** a new sustained listening and a new sustained reading in one unit
(the plan's five themes are then 5/5 across the extended path, §B2-3).

---

## B2-1. Theme rationale and retrieval surface

Batch 1's three units built narrative → causal → argumentative; batch 2's two
units are the plan's two remaining themes, transactional + comprehension:

| Theme | What it extends / retrieves in the shipped pack |
|---|---|
| **Practical problems** (transactional) | Extends the pilot's polite problem-reporting surface (`es-b1-reclamacion-mission` u18L6, `es-a2-hotel-mission` u17) from report-only to **describe → ask → negotiate → resolve**: `es-b1-problema-frames` (u24L1, problem frames), `es-b1-problema-listen` (u24L2, SL service call), `es-b1-problema-construccion` (u24L3, request/offer building), `es-b1-problema-dialogo` (u24L4, negotiation DB), `es-b1-problema-escrito` (u24L5, written report), `es-b1-arreglo-mission` (u24L6, resolve in a new setting). A2 base: `es-a2-por-para` (u16), `es-a2-me-gustaria` (u15). |
| **Understanding longer speech/text** (comprehension) | Deepens the batch-1 sustained-input motif into its own unit with **both** modalities: `es-b1-hilo-frames` (u25L1, discourse-signpost tracking frames), `es-b1-hilo-listen` (u25L2, SL talk — the pack's longest spoken piece), `es-b1-cronica-lectura` (u25L3, SR chronicle), `es-b1-aclarar-dialogo` (u25L4, clarify/repair DB), `es-b1-resumen-escrito` (u25L5, written summary), `es-b1-transmitir-mission` (u25L6, relay the gist to a new listener). Pilot base: `es-b1-aeropuerto-listen` / `es-b1-viaje-escrito` tracking skills. |

Why kept exactly as the plan proposes: the two themes are the plan's remaining
list; practical problems reuses the pack's strongest problem-reporting chain
(F17 cites it), and the comprehension theme is the only theme that *requires*
both an SL and an SR to be honest to its name — unit 25 ships both (§B2-3),
the first unit in the pack to do so (F26).

---

## B2-2. Unit × lesson tables (12 proposed lessons)

Conventions inherited unchanged from §2: lesson ids continue the
`es-b1-<theme>-<suffix>` family-flavored pattern; unit ids continue
`es-unit-24` / `es-unit-25` (new `units[]` entries appended after
`es-unit-23`, lessons appended after the unit-23 lessons in `lessons[]` —
that append order is what `unitsInOrder` and the checkpoint math derive
from, §7 / B2-7); families from the existing enum; markers SL/SR/OTW/SC/DB/FT
exactly as defined in §2. New ids → catalog regeneration after authoring
(§B2-9, F22).

### Unit 24 — `es-unit-24` "Problemas cotidianos" (practical problems)
**Communicative outcome:** describe a practical everyday problem clearly, ask
for a solution politely, negotiate a fix in a branched exchange, and leave a
clear message that resolves the problem with a new listener.

| Proposed id | Family | Title | Communicative outcome | Grammar/vocab in context | Retrieval hook (final per decision 1 — options in B2-6) | Content markers |
|---|---|---|---|---|---|---|
| `es-b1-problema-frames` | discovery | Describir un problema | Name a practical problem precisely (what, where, since when) with a polite ask | Problem frames: se ha estropeado, no funciona, hay un problema con, funciona mal; + polite request opener | `es-b1-consecuencia-conectar` (u22L1, cause→consequence frames that problems trigger) | — (supported practice: selection/cloze/text on problem stimuli) |
| `es-b1-problema-listen` | listening | La llamada al servicio técnico | Follow a 4-section service-call conversation: the problem, the diagnosis, the options, the agreement | Spoken problem-reporting register (llamo porque…, ¿me podría…?, ya le digo); tense past/present switching | `es-b1-opinion-listen` (u23L2, multi-section SL pattern) | **SL** (new `es-b1-listen-reparacion`, 4 sections, alternating es-ES/es-MX voices) |
| `es-b1-problema-construccion` | construction | Pedir una solución | Build request/offer sentences: polite ask, stated constraint, acceptable alternative | Polite request/offer frames (¿me podría…?, hay que…, me vale si…); porque reason in requests | `es-b1-opinion-construccion` (u23L3, sentence-building on frames) | — (construction: ordering/cloze/text on dictated requests) |
| `es-b1-problema-dialogo` | conversation | Resolverlo juntos | Negotiate a fix/appointment in a 3+ turn branched exchange with clarification and recovery | Negotiation frames (¿qué tal si…?, mejor…, nos quedamos en…); agreement + porque; repair | `es-b1-cambio-dialogo` (u22L4, change-of-plan negotiation) | **DB** (new `es-b1-dialogo-problema` in the dialogues bank; host lesson) |
| `es-b1-problema-escrito` | recall | Cuéntalo por escrito | Write 2–4 connected sentences: the problem, why it matters, the fix you ask for | Problem + porque + consequence in connected writing; sequence markers; polite written register | `es-b1-consecuencia-escrito` (u22L5, written plan+consequence frames) | **OTW** (self-assessed; rubric ticks, model revealed on demand) |
| `es-b1-arreglo-mission` | mission | El arreglo | Leave a clear voice-note message to a service/landlord describing the problem and the agreed fix — a **new setting** vs all shipped venues | Report frames (llamo porque…, al final…); polite ask; para + purpose close | `es-b1-reclamacion-mission` (u18L6, problem-reporting mission — pilot re-pull, final per decision 1) | **FT** (new setting: message to a service) + **SC** (embedded `es-b1-arreglo-say`) |

### Unit 25 — `es-unit-25` "Seguir el hilo" (understanding longer speech/text)
**Communicative outcome:** follow a longer spoken piece and a longer written
text, keep track of the thread across sections, clarify when you lose it, and
summarise/relay the gist to someone new.

| Proposed id | Family | Title | Communicative outcome | Grammar/vocab in context | Retrieval hook (final per decision 1 — options in B2-6) | Content markers |
|---|---|---|---|---|---|---|
| `es-b1-hilo-frames` | discovery | Seguir el hilo | Recognise and use discourse signposts that track a longer message across sections | Tracking signposts: en primer lugar, por un lado… por otro lado, luego, al final, es decir, o sea | `es-b1-cambio-planes-lectura` (u22L2, before/after tracking SR) | — |
| `es-b1-hilo-listen` | listening | Una charla más larga | Follow a 4-section longer talk: the claim, the example, the aside, the wrap-up — gist plus two details | Spoken signposts (bueno, en fin, como decía…); digression-and-recovery markers; spoken register | `es-b1-anecdota-listen` (u21L2, multi-section SL account — strict-1:1 swap, final per decision 1) | **SL** (new `es-b1-listen-charla`, 4 sections, alternating voices) |
| `es-b1-cronica-lectura` | discovery | Una crónica | Read a 4-section longer text (a chronicle/report): main idea plus two supporting details across sections | Text-organisation markers (según el autor, la idea principal es…); anaphoric reference light; porque support | `es-b1-celebracion-lectura` (u20L3, thread-tracking SR — pilot re-pull, final per decision 1) | **SR** (new `es-b1-text-cronica`, 4 sections) |
| `es-b1-aclarar-dialogo` | conversation | ¿Me explico? | Hold a 3+ turn branched exchange clarifying a longer explanation: check, re-explain, confirm | Clarification/repair frames (no te sigo, ¿qué quieres decir?, es decir que…, perdona, ¿puedes repetir?) | `es-b1-plan-dialogo` (u20L4, repair-node-rich dialogue) | **DB** (new `es-b1-dialogo-aclaracion`; host lesson) |
| `es-b1-resumen-escrito` | recall | El resumen | Write 2–4 connected sentences summarising a longer input: main point, two details, one porque | Summary frames (la idea principal es…, además…, por ejemplo…); según + source; reported frames light | `es-b1-opinion-escrito` (u23L5, opinion+details written structure) | **OTW** (self-assessed) |
| `es-b1-transmitir-mission` | mission | Pásalo | Relay the gist of a longer piece you heard/read to a **new listener in a new setting** (a voice note to a friend who missed it) | Retell + relay frames; signposts; reported speech light; reaction closer | `es-b1-relato-mission` (u21L6, retell-to-new-listener mission) | **FT** (new setting: passing on a longer piece) + **SC** (embedded `es-b1-transmitir-say`) |

**Per-unit requirement coverage (from plan 8.1):**

| Requirement (per unit) | Unit 24 | Unit 25 |
|---|---|---|
| Sustained input (≥1) | SL `es-b1-listen-reparacion` | SL `es-b1-listen-charla` **and** SR `es-b1-text-cronica` (first dual-input unit in the pack — F26) |
| Vocabulary/grammar in context | ✓ every lesson | ✓ every lesson |
| Delayed review into shipped B1 lessons (exactly one `legacy-success` prereq per lesson) | ✓ 6 hooks (decision-1 map: u18 ×1, u22 ×3, u23 ×2) | ✓ 6 hooks (decision-1 map: u20 ×2, u21 ×2, u22 ×1, u23 ×1) |
| Connected writing | OTW `es-b1-problema-escrito` | OTW `es-b1-resumen-escrito` |
| Spoken self-comparison | SC in `es-b1-arreglo-mission` | SC in `es-b1-transmitir-mission` |
| Multi-turn interaction | DB `es-b1-problema-dialogo` | DB `es-b1-aclarar-dialogo` |
| Final task in a new setting | voice-note message to a service | voice-note relay of a longer piece |
| Input-to-output arc (no grammar-only unit) | frames → hear the service call → build request sentences → negotiate the fix → write the report → leave the resolving message | signposts → hear a longer talk → read a longer chronicle → clarify in dialogue → write the summary → relay the gist |

Sustained-input balance across the batch: **+1 SR and +2 SL** (pack banks go
7→8 sustained texts, 6→8 sustained listenings). The design decision per the
theme: unit 25 carries **both** modalities because "understanding longer
speech/text" names both — it is the pack's first unit to do so (F26); unit
24 carries SL because practical problems are primarily spoken/transactional.
The `listening` family (pack's rarest, F1/F15) gains two more lessons; SL
lessons are multi-section with per-section `voiceId` es-ES/es-MX alternation
(F24). Embedding each unit's self-compare inside its closing mission mirrors
the batch-1 and shipped precedent and keeps every unit at six lessons.

---

## B2-3. Coverage matrix vs the 8.1 done-when

Done-when remains **per path, not per unit** (§3): units 24–25 extend the
Independent path (with batch 1) to units 18–25; the matrix below mirrors §3
for the two new units. Parity for future languages stays function × modality.

| 8.1 done-when item | Unit 24 | Unit 25 | Shipped evidence the extended path now covers |
|---|---|---|---|
| **Mapped tasks** — every lesson's task map resolves to an existing mechanism | 6/6 lessons map to shipped step/activity kinds (selection, text, cloze, ordering, dialogue-choice, open-task, self-compare, mission terminal) | 6/6 same kinds | 7.1 §5 mechanism checklist + batch-1 §5 re-verification; batch 2 invents nothing; §B2-5 re-checks every marker |
| **Sustained input** (≥1 per unit) | SL `es-b1-listen-reparacion` (4 sections, es-ES/es-MX voices) | SL `es-b1-listen-charla` + SR `es-b1-text-cronica` (both 4 sections) | Banks: 7→8 SR / 6→8 SL across batch 2; path total 8 SR / 8 SL; exceeding ≥1 by design in u25 (F26) |
| **Connected output** | OTW `es-b1-problema-escrito` + SC `es-b1-arreglo-say` | OTW `es-b1-resumen-escrito` + SC `es-b1-transmitir-say` | OTW kind self-assessed (H1/H2); SC `.selfAssessed` — precedent batch-1 trio |
| **Interaction** | DB `es-b1-dialogo-problema` (≥3 learner turns, clarification/misunderstanding/recovery nodes) | DB `es-b1-dialogo-aclaracion` (≥3 learner turns; repair is the point of the exchange) | `dialogues[]` bank pattern of `es-b1-dialogo-problema/-aclaracion` (hostLessonId, prereq, start, nodes with choices→next) |
| **Delayed review** | 6 `legacy-success` prereqs + per-activity `reviewOf[]` (recommended: u22 ×4, u23 ×2) | 6 prereqs (recommended: u20 ×1, u21 ×2, u22 ×2, u23 ×1) | Batch 1 established 1:1 over all 18 pilot lessons; batch 2's map is a **proposed** extension over units 21–23 (+ one pilot re-pull at u25L4) — orchestrator decision, B2-6 (F19) |
| **Checkpoint evidence (unseen)** | Path-level: the Independent path's single unseen checkpoint (`es-cp-independent`, 3 items) surfaces after the **last** Independent unit — **unit 25** after batch 2 ships (Option A, §B2-7). Its unseen passage and prompts remain valid across the longer path; no per-unit checkpoint card is claimed (F21) | same | Pilot F3 + batch-1 F8: one entry per stage; the card auto-relocates because `checkpointAfterLastUnitOfStage` computes "last unit of stage" from lesson order (§B2-7 verifies the code again for the new tail) |

**Status: all six done-when rows met at the path level**, with the same two
labeled qualifications as §3, now resolved where batch 1 flagged them:

1. **Checkpoint evidence is path-level, not per-unit.** Same reading as batch
   1 (Option A, §7). The card moves again — after unit 25 — with no app
   change (§B2-7). Per-unit unseen cards remain an app-change product
   decision (Option C), unchanged and not implemented.
2. **"Practical problems" is now covered** (this batch) — §3's F17-labeled
   gap closes with unit 24; "understanding longer speech/text" is now a
   dedicated unit (25) with both an SL and an SR, not merely a motif.
   The plan's five theme list is now **5/5 covered** across units 18–25.

**Language/parity discipline:** identical to §3 — Spanish extends the four
communicative functions *problem-solving* and *comprehension-of-longer-input*
across all four modalities; the function × modality grid remains the
transferable parity unit for fr/it/de/pt. **No coverage row is ever labeled
"B1"** — wording stays **"B1-oriented"** throughout; native naturalness and
learner outcomes remain **unverified** for all batch-2 content.

---

## B2-4. Mechanism checklist — batch-2 markers (all additive shapes)

Verified against `es-foundations` v0.7.12 + `Condisco/Models/CoursePack.swift`
+ `Condisco/Lesson/CoursesView.swift` + `Condisco/Lesson/CheckpointFlow.swift`
+ `Condisco/Store/LearningStore.swift` on 2026-09-27 (this slice) — every
mechanism batch 2 uses exists today; nothing structural is added:

| Mechanism | Exists today (evidence, condensed from §5) | Batch 2 use |
|---|---|---|
| Sustained reading | `sustainedTexts[]` bank (7 entries); step binds via `sustainedTextId` | 1 new: `es-b1-text-cronica` (u25L3) |
| Sustained listening | `sustainedListenings[]` bank (6 entries); step binds via `sustainedListeningId` | 2 new: `es-b1-listen-reparacion` (u24L2), `es-b1-listen-charla` (u25L2) |
| Open task (written) | `open-task` kind, `mode: written`, self-assessed rubric, `modelResponse` reveal | 2 new: `es-b1-problema-escrito-open-task`, `es-b1-resumen-escrito-open-task` |
| Self-compare | `self-compare` kind, `modelText` + optional `modelAudioId`, outcome `.selfAssessed` | 2 embedded: `es-b1-arreglo-say`, `es-b1-transmitir-say` |
| Dialogue branch | `dialogues[]` bank (8 entries incl. 6 shipped/batch-1); `hostLessonId`, `prerequisite`, `start`, `nodes[]` with `choices→next`, clarification/misunderstanding/recovery kinds | 2 new bank entries: `es-b1-dialogo-problema` (host u24L4), `es-b1-dialogo-aclaracion` (host u25L4) |
| Checkpoint bank | `checkpoints[]` 3 entries, one per stage; UI consumes **one per stage** — `pack.checkpoints.first { $0.stage == stage }` (`CoursesView.swift:405`) after the last unit of the stage (:400-406); `LearningStore.recordCheckpointAttempt` resolves by id (:1913) | **none new — Option A (position shift only, §B2-7)** |
| Delayed review | `legacyExercises[].reviewOf[]` + `prerequisites[]` `legacy-success` (all 88 current lessons carry the single-prereq pattern, verified) | 12 hooks into shipped B1 lessons — proposed map in B2-6 (F19) |
| Final task in a new setting | Mission terminal steps; "new setting" is an authoring choice | 2 FT missions (service message / relay of a longer piece — both new settings vs batch-1's voice-note retell) |
| cefr → Independent path | `CoursesView.coursePath(of:)` default branch + `CheckpointFlow.checkpointStage(of:)` default branch | `cefr: "B1"` alignment tags on all 12 new lessons |

**New assets batch 2 will add (all additive schema shapes):** 1
`sustainedTexts[]` entry, 2 `sustainedListenings[]` entries, 2 `dialogues[]`
entries, **0 checkpoint entries**, 12 lessons under 2 new units,
concepts/vocabulary for the new grammar/vocab, and 2 audio-provenance records
(F23). `PackUpdateTests` additive-shape guarantees apply as for batch 1; the
count/version pins in `PackSpanishTests` are the deliberate update points
(F21).

---

## B2-5. Grammar/content points per unit — every point **source-pending**

Source policy unchanged (§6): every disputed/known-tricky point needs **two
independent authoritative references** (RAE/ASALE `NGLE`/`DPD`, Fundéu,
Butt & Benjamin, peer-reviewed or established-editorial class). **No citation
is fabricated here** — every row is **source-pending**; the research lane
fills reference 1 + reference 2 + disposition before authoring. Grammar-source
independence = **different works** (never NGLE+NGLE sections of one work; the
batch-1 method-audit rule); cross-institution pairs only for disputed claims;
same-work pairs rejected; two AI models agreeing never clears a point. Points
are planned with the *pair strategy* stated per row (classes of source
intended, honest one-source gap expectations per C3/C5 — a gap is labeled,
never padded; reuse of an already-verified batch-1/pilot pair is disclosed and
preferable to padding where the phenomenon is identical).

### Unit 24 — Problemas cotidianos (L1→24.1, L2→24.2, L3→24.3, L4→24.4, L5→24.5, L6→24.6)
| # | Point | Planned pair strategy (classes only — source-pending) | Source status |
|---|---|---|---|
| 24.1 | Problem frames: se ha estropeado / no funciona / hay un problema con; mark of recent result | Resultative se/estar + participle (NGLE §41 area) vs buttressed result state (Butt & Benjamin ser/estar area) — plan a **cross-institution pair** (RAE-family + Routledge) for the stative/passive reading | **source-pending** |
| 24.2 | Spoken service-call register: llamo porque…, ¿me podría…?, ya le digo | Reuse the verified A3 politeness pair (Butt & Benjamin §21.3.3 + Lawless polite-requests) — same phenomenon, disclosed reuse; no new pair needed unless the phone-formula sub-claim splits | **source-pending** |
| 24.3 | Polite request/offer building: ¿me podría…?, hay que + inf, me vale si… | Impersonal obligation hay que (NGLE) + register ordering of the request set (pedagogical-convention flag per 22.5 precedent) — plan RAE-family grammar + a second independent work for hay que; ordering = labeled convention, never padded | **source-pending** |
| 24.4 | Negotiation frames in a problem context: ¿qué tal si…?, mejor…, nos quedamos en… | Same frame family as 22.5/23.2 — reuse those verified pairs (NGLE §30.13v + DPD quedar / Fundéu de acuerdo) with disclosed reuse; the *problem-context* application is not a new linguistic claim | **source-pending** |
| 24.5 | Written problem report: problem + porque + consequence; polite written register | Reuse 21.5 ordering pair (NGB §16.3) + 22.2 porque/por eso pair (DPD porque + NGLE §30.13ñ) — both verified; written-vs-spoken register note may carry the C3-style convention flag if no second source | **source-pending** |
| 24.6 | Relay of the fix: llamo porque…, al final…, para + purpose closer | Purpose para (reuse C4 pair: NGLE §46.1d/h + DLE para) + retell framing (reuse 21.6 pair: NGLE §23.12–23.13 + Español al día) — disclosed reuse; no new disputed claim expected | **source-pending** |

### Unit 25 — Seguir el hilo (L1→25.1, L2→25.2, L3→25.3, L4→25.4, L5→25.5, L6→25.6)
| # | Point | Planned pair strategy (classes only — source-pending) | Source status |
|---|---|---|---|
| 25.1 | Tracking signposts: en primer lugar, por un lado/por otro lado, luego, al final, es decir, o sea | Ordering + reformulative connector groups — reuse A2/21.5 pair (NGB §16.3 + NGLE §30.13a/s); o sea register/frequency likely needs the cross-institution academic source (Val.Es.Co DPDE, precedent 23.5) or a labeled gap | **source-pending** |
| 25.2 | Spoken signposts and digression-recovery: bueno, en fin, como decía… | bueno among affirmation markers (NGLE §30.13v, reuse 23.5 pair) + Val.Es.Co DPDE for spoken-particle frequency (precedent 23.5) — cross-institution; digression-recovery set = pedagogical convention flag if no authoritative codification | **source-pending** |
| 25.3 | Longer-text organisation: según el autor, la idea principal es…, anaphoric reference light | Anaphora/reference (NGLE §16 area) + a second independent work (Butt & Benjamin reference chapter) — cross-institution; text-organisation marker set may carry a C3 convention flag | **source-pending** |
| 25.4 | Clarification/repair in dialogue: no te sigo, ¿qué quieres decir?, es decir que…, perdona, ¿puedes repetir? | Reformulative es decir/o sea (NGLE §30.13, reuse strategy of 25.1) + Val.Es.Co DPDE (o sea, es decir entries — cross-institution, precedent 23.5); repair formulas are standard — straightforward forms flag like 23.2 | **source-pending** |
| 25.5 | Written summary: la idea principal es…, además…, por ejemplo…, según + source | Reuse 23.3 additive/exemplificative pair (NGLE §30.13c/q + NGB §16.3) + reported-light frames (reuse 21.3 pair: NGB §25.5 + GTG) — disclosed reuse; summary-frame bundle = pedagogical convention note (C3) if needed | **source-pending** |
| 25.6 | Relay of the gist: retell frames + signposts + reaction closer | Reuse 21.6 retell pair (NGLE §23.12–23.13 + Español al día) + 25.1 signpost sources — disclosed reuse; relay-register ranking = labeled convention (C5 precedent) | **source-pending** |

---

## B2-6. Prerequisite (delayed-review hook) design — 12 lessons, options each, **flag for orchestrator — do not decide**

Batch-1 convention: one `legacy-success` prereq per lesson; 18 hooks mapped
1:1 onto the 18 pilot lessons (units 18–20), each re-pulled exactly once.
Batch 2's 12 lessons must hook **earlier B1 lessons** — the pool is the
shipped B1-oriented surface, units **18–23 (36 lessons: 18 pilot + 18
batch-1; the brief's "24 lessons" is read as an approximate count — the
verified pool is 36, F20)**. Because batch 1 already pulled every pilot
lesson once, a batch-2 map has three honest shapes; the orchestrator decides
(F19). Per-lesson options below list the strongest candidates; each is
verified to exist in the pack. Recommended maps are marked **▶ rec** — the
recommendation is a design preference, not a decision.

**Option A — "batch-1 lessons first, 1:1-spirit" (recommended).** All 12
hooks land on **batch-1 lessons (units 21–23)**, each batch-1 lesson used at
most once *(12 of 18; pilots stay singly-pulled, preserving the cleanest
reading of the 1:1 convention)*. Where a pilot lesson is the only strong
match, the alternative below names it as Option B.

**Option B — "thematic-pilot re-pull".** Same as A, except the strongest
thematic matches that sit in the pilot are allowed **one re-pull each**
(e.g. `es-b1-aclarar-dialogo` → `es-b1-plan-dialogo` u20L4, `es-b1-
cronica-lectura` → `es-b1-celebracion-lectura` u20L3). Rationale: delayed
review values the re-encounter over uniqueness; F8's "attempts keyed by
lesson id" makes re-pulls store-safe.

**Option C — "newest-first LIFO".** The 12 hooks target the 12 most recently
shipped B1 lessons regardless of family/theme (u23 lessons first, then u22,
then u21). Simplest to author, weakest retrieval affinity; included for
completeness, not recommended.

| New lesson | Option A candidates (1:1-spirit, units 21–23) | Option B re-pull candidate(s) (pilot) | ▶ rec |
|---|---|---|---|
| `es-b1-problema-frames` (u24L1) | `es-b1-consecuencia-conectar` (u22L1, cause→consequence frames) · `es-b1-historia-conectar` (u21L1) · `es-b1-opinion-frames` (u23L1) | — | A: `es-b1-consecuencia-conectar` |
| `es-b1-problema-listen` (u24L2) | `es-b1-opinion-listen` (u23L2, SL discussion) · `es-b1-anecdota-listen` (u21L2, SL account) · `es-b1-consecuencia-conectar` (u22L1) | `es-b1-aeropuerto-listen` (u18L3, SL + polite request) | A: `es-b1-opinion-listen` |
| `es-b1-problema-construccion` (u24L3) | `es-b1-opinion-construccion` (u23L3, sentence-building) · `es-b1-si-entonces` (u22L3, conditions) · `es-b1-cambio-planes-lectura` (u22L2, SR) | — | A: `es-b1-opinion-construccion` |
| `es-b1-problema-dialogo` (u24L4) | `es-b1-cambio-dialogo` (u22L4, negotiation) · `es-b1-opinion-dialogo` (u23L4) · `es-b1-reaccion-dialogo` (u21L4) | — | A: `es-b1-cambio-dialogo` |
| `es-b1-problema-escrito` (u24L5) | `es-b1-consecuencia-escrito` (u22L5) · `es-b1-historia-escrito` (u21L5) · `es-b1-opinion-escrito` (u23L5) | — | A: `es-b1-consecuencia-escrito` |
| `es-b1-arreglo-mission` (u24L6) | `es-b1-plan-mission` (u22L6, mission + SC) · `es-b1-relato-mission` (u21L6) · `es-b1-recomendacion-mission` (u23L6) | `es-b1-reclamacion-mission` (u18L6, problem-reporting mission — thematically ideal) | B: `es-b1-reclamacion-mission` *(the one place a pilot re-pull earns its keep: mission→mission problem surface)* |
| `es-b1-hilo-frames` (u25L1) | `es-b1-cambio-planes-lectura` (u22L2, tracking SR) · `es-b1-historia-conectar` (u21L1) · `es-b1-opinion-frames` (u23L1) | — | A: `es-b1-cambio-planes-lectura` |
| `es-b1-hilo-listen` (u25L2) | `es-b1-opinion-listen` (u23L2, SL) · `es-b1-anecdota-listen` (u21L2, SL) · `es-b1-trabajo-listen` (u19L2 — pilot, Option B only) | `es-b1-trabajo-listen` (u19L2, multi-section SL) | A: `es-b1-opinion-listen` |
| `es-b1-cronica-lectura` (u25L3) | `es-b1-cambio-planes-lectura` (u22L2, SR) · `es-b1-celebracion-lectura` (u20L3 — pilot, Option B only) · `es-b1-entrevista-lectura` (u19L3 — pilot) | `es-b1-celebracion-lectura` (u20L3, thread deliberation) | B: `es-b1-celebracion-lectura` *(SR→SR; the pack's only other thread-tracking SR)* |
| `es-b1-aclarar-dialogo` (u25L4) | `es-b1-reaccion-dialogo` (u21L4) · `es-b1-cambio-dialogo` (u22L4) · `es-b1-opinion-dialogo` (u23L4) | `es-b1-plan-dialogo` (u20L4, repair-node-rich) | B: `es-b1-plan-dialogo` *(repair is the lesson's engine — the pilot dialogue with clarification/misunderstanding/recovery nodes is the strongest match)* |
| `es-b1-resumen-escrito` (u25L5) | `es-b1-opinion-escrito` (u23L5) · `es-b1-historia-escrito` (u21L5) · `es-b1-consecuencia-escrito` (u22L5) | — | A: `es-b1-opinion-escrito` |
| `es-b1-transmitir-mission` (u25L6) | `es-b1-relato-mission` (u21L6, retell mission) · `es-b1-plan-mission` (u22L6) · `es-b1-recomendacion-mission` (u23L6) | `es-b1-entrevista-mission` (u19L6, self-presentation) | A: `es-b1-relato-mission` |

**Recommended map (hybrid of A + the three flagged B re-pulls):** u24 →
`consecuencia-conectar`, `opinion-listen`, `opinion-construccion`,
`cambio-dialogo`, `consecuencia-escrito`, `reclamacion-mission` (B); u25 →
`cambio-planes-lectura`, `opinion-listen` *(u25L2 — note: shares with u24L2
under the recommended map; if the orchestrator wants strict 1:1, swap u25L2
to `es-b1-anecdota-listen` u21L2)*, `celebracion-lectura` (B),
`plan-dialogo` (B), `opinion-escrito`, `relato-mission`. **Flagged F19 for
the orchestrator; not decided here.** Note u25L2 duplicates u24L2's hook in
the recommended shape — the two SL lessons are the pack's comprehension
anchors; a duplicate hook is store-safe (re-pull) but the orchestrator may
prefer the strict-1:1 swap above.

---

## B2-7. Checkpoint — surfacing on the extended path, investigated again

The batch-1 investigation (§7) is re-read on the current code (verified
2026-09-27, same files and line anchors):

- `CoursesView.swift:400-406` (`checkpointAfterLastUnitOfStage`) renders the
  stage-end card **only after the last unit of a stage**: `stageOf(unit)` is
  the unit's first lesson's cefr-derived stage (:392-395), `laterSameStage`
  scans `unitsInOrder` (which derives from `pack.lessons` order, :378-383),
  and the returned task is `pack.checkpoints.first { $0.stage == stage }` —
  one entry per stage, first in bank order (:405).
- `CheckpointFlow.swift:36-42` maps `"B1"` → `.independent` (default branch),
  matching the path cards' `coursePath(of:)` default branch
  (`CoursesView.swift:294-299`).
- Attempts filter by `checkpointId` (`CoursesView.swift:444-446`); the store
  resolves by id (`LearningStore.swift:1913`) and keys the bank by id
  (:1676) — **attempts survive any relocation of the card**.
- `PackSpanishTests.swift:142-161` still pins the exact id list
  `["es-cp-foundation", "es-cp-developing", "es-cp-independent"]`
  ("one checkpoint task ships per stage") — batch 2 adds no bank entries, so
  **this pin survives untouched**. `YouView` preview count unchanged (3).

**Consequence for batch 2:** appending units 24–25 (all `cefr: "B1"` →
`.independent`) after unit 23 moves the surfacing automatically **a second
time**: the card disappears from after unit 23 and appears after unit 25 —
"last unit of stage" is computed from lesson order, not hard-coded.

**What batch 2 needs for surfacing: no app-code change.** This slice's
investigation found nothing code-side that must move. The only
surfacing-adjacent item is **pack metadata copy**: the pack `description`
("…the pack's independent checkpoint, which surfaces at the end of this
extended path") and the units-21–23 sentence must be extended to units 24–25
at the 0.7.14 bump (F25) — that is an authoring-lane pack-JSON edit, not a
Swift change. If the orchestrator ever wants per-unit unseen checkpoint
cards, that remains the Option C app change (§7) — out of scope, not
assumed.

---

## B2-8. Pack version bumps

Batch-1 pattern decided per-unit (0.7.10 → 0.7.11 → 0.7.12); batch 2
continues it per-unit, one unit at a time with full gates (never bulk):

| Wave | Unit | Version | Lessons | Units | Activities (approx, pins update at authoring — F21) |
|---|---|---|---|---|---|
| Batch 2 wave 1 | 24 | **0.7.13** | 88 → 94 | 23 → 24 | 744 → ~760 |
| Batch 2 wave 2 | 25 | **0.7.14** | 94 → 100 | 24 → 25 | ~760 → ~778 |

The `PackSpanishTests` count/version pins (lessons.count == 88 at 4 sites,
activities count, version strings "0.7.12") are the deliberate update points;
the F10/F21 note stands: pins are the authoring lane's job, never the
developer's. The orchestrated completion note and pack `attribution`
"native-speaker editorial review remains open" wording carry forward.

---

## B2-9. Flags / blockers (F19+, continuing the F1–F18 numbering)

None of these blocks design acceptance; they are honest pre-authoring notes.
Batch-1 flags F7–F18 carry forward where applicable (catalog regen, SL
obligations, copy-bans, ledger follow-ups) and are restated only where batch
2 changes them.

- **F19 — delayed-review hook map for units 24–25 (orchestrator decision).**
  §B2-6 offers Options A/B/C and a recommended hybrid map; **this slice does
  not decide**. The chosen map fixes 12 `legacy-success` prereqs + per-activity
  `reviewOf[]`. All candidate ids verified to exist in the pack (2026-09-27).
- **F20 — hook-pool count.** The brief counts "24 lessons" in units 18–23;
  the verified pool is **36** (18 pilot + 18 batch-1). Options are defined
  over the verified pool; the orchestrator's number is read as approximate.
- **F21 — version/count pins at authoring.** `PackSpanishTests` pins
  lessons.count == 88 (4 sites), version "0.7.12", activities count — updated
  by the authoring lane to 94/100, "0.7.13"/"0.7.14" when each wave lands;
  the checkpoint id-list pin (:142-161) survives unchanged under Option A.
- **F22 — catalog regen.** `tools/gen_lesson_catalog.py` runs after each
  wave (u24, then u25): 2 unit ids, 12 lesson ids, new bank entries (2 SL +
  1 SR + 2 DB) — orchestrator-owned, unchanged from batch-1 F11.
- **F23 — audio provenance for the 2 new SL pieces.** Facts-only records
  `docs/audio-provenance/spanish-b1-listen-reparacion.json` and
  `...-charla.json` (pattern: `spanish-cafe-listen-pilot.json`), device
  speech via per-section `voiceId` (es-ES/es-MX alternation),
  `reviewPending: true`, no allowlist entry needed. Authoring obligation.
- **F24 — SL authoring obligations (mirror batch-1 F16).** Each new SL piece
  is multi-section with per-section `accessibilityLabel` + synthesised-voice
  disclosure + `accessibleSummary`, transcript-reveal per the
  `es-sustained-listen-llamada` pattern, es-ES/es-MX voices → variant
  recorded as both regions.
- **F25 — pack metadata copy at 0.7.14.** `description` ("…100 Spanish
  lessons in twenty-five units", units-24–25 sentence, checkpoint wording
  "surfaces at the end of this extended path" now = after unit 25) and
  `attribution` gain batch-2 lines; wording stays **B1-oriented** (R6);
  copy-ban scan on all new dialogue/open-task fields.
- **F26 — unit 25 is the pack's first dual-sustained-input unit (SL + SR).**
  Banks land 8 SR / 8 SL; per-unit requirement "≥1 sustained input" is
  exceeded by design for the comprehension theme. No mechanism change —
  both step kinds exist — but the shape is a first; check_packs and unit
  pins accommodate it.
- **F27 — u25 "longer speech" content choice.** The SL talk must be an
  original fictional talk (a community/city talk, invented speaker, no
  third-party material) — originality gate per F18; the "longer text"
  chronicle likewise invented (an invented local chronicle/report, no real
  events or sources).
- **F28 — conservative-content choice for u24.** Problem scenarios stay
  **everyday and low-stakes** (appliance fault, delivery issue, appointment
  mix-up) — away from the A2 emergency surface (`es-emergency-foundation`),
  no medical/legal/billing escalation; flagged for the review lane's
  naturalness pass, not assumed.
- **F29 — ledger rows 37–48 pre-created** (companion ledger §Extension batch
  2): all `pending`, mirroring rows 19–36 exactly; grammar cells filled by
  the research lane from consolidated blocks in
  `docs/reviews/2026-09-26-b1-pilot-grammar-sources.md` (a new Extension
  batch 2 section) before authoring.
- **F30 — standing discipline re-stated for batch 2 (mirror F18):** 100%
  original content; open production always self-assessed (H1/H2), never
  auto-graded; no CEFR/level/proficiency claim in any objective,
  `culturalNote`, concept explanation, or pack/unit copy; per unit at least
  one input-to-output arc (no grammar-only unit — §B2-2 rows show 6/6 arcs);
  catalogue id/revision/completion-policy discipline per rubric C1/C3.

---

## B2-10. Batch-2 open questions — **proposed, awaiting orchestrator decision**

In the §10 spirit, the decisions batch 1 received are **not** re-opened
(Option A checkpoint reading, SL/SR/SL arrangement of batch 1, 1:1 hook map
of batch 1, per-unit version bumps, pin ownership, ledger conventions). The
following batch-2 items are recorded as **proposed** and await the
orchestrator:

1. **Hook map** — confirm §B2-6's recommended hybrid map (Option A +
   the three B re-pulls: u24L6→`es-b1-reclamacion-mission` (u18L6),
   u25L3→`es-b1-celebracion-lectura` (u20L3), u25L4→`es-b1-plan-dialogo`
   (u20L4)) and the u25L2 strict-1:1 swap (`es-b1-anecdota-listen`), or pick
   Option A/B/C wholesale (F19, F20).
2. **Unit titles/themes and sustained-input arrangement** — confirm
   "Problemas cotidianos" (u24, SL) and "Seguir el hilo" (u25, **SL + SR**,
   first dual-input unit, F26), banks landing 8 SR / 8 SL.
3. **Option A re-confirmed for the new tail** — `es-cp-independent` relocates
   to after unit 25 with no app change (B2-7); description copy updated at
   0.7.14 (F25); Option C remains unimplemented.
4. **Authoring order and releases**: units 24 → 25, one unit at a time with
   full gates each; version bumps per-unit **0.7.13 (u24) → 0.7.14 (u25)**.
5. **F21 pin/count/version updates** are the authoring lanes' job at each
   wave (developer does device checks/walkthroughs only).
6. **Rows 37–48 use exactly the rows 19–36 conventions** (two independent
   sources per disputed point, honest gaps per C3/C5, `AI-assisted` review
   method, native review `pending`, developer sign-off empty; source columns
   filled from the grammar-sources file's Extension batch 2 section by the
   dedicated fill lane, never by authoring lanes).

### Orchestrator decisions (2026-09-27)

Recorded in the §10 spirit; these close the six open questions above.

1. **Hook map — APPROVED as the recommended hybrid with the strict-1:1
   swap.** Final map (12 `legacy-success` prereqs, every target distinct):
   u24L1→`es-b1-consecuencia-conectar` · u24L2→`es-b1-opinion-listen` ·
   u24L3→`es-b1-opinion-construccion` · u24L4→`es-b1-cambio-dialogo` ·
   u24L5→`es-b1-consecuencia-escrito` ·
   u24L6→`es-b1-reclamacion-mission` (pilot re-pull) ·
   u25L1→`es-b1-cambio-planes-lectura` · u25L2→`es-b1-anecdota-listen`
   (the strict-1:1 swap — no duplicate hook) ·
   u25L3→`es-b1-celebracion-lectura` (pilot re-pull) ·
   u25L4→`es-b1-plan-dialogo` (pilot re-pull) ·
   u25L5→`es-b1-opinion-escrito` · u25L6→`es-b1-relato-mission`.
   Rationale: the three pilot re-pulls earn their place on thematic affinity
   (mission→mission problem surface, SR→SR thread tracking, repair-dialogue
   engine) and are store-safe under F8; the swap preserves the verifiable
   batch-1-style property that all 12 hook targets are unique. F20: the
   "24 lessons" pool figure was approximate — the verified 36-lesson pool
   (units 18–23) is authoritative.
2. **Titles and inputs — CONFIRMED:** `es-unit-24` "Problemas cotidianos"
   (SL) and `es-unit-25` "Seguir el hilo" (SL + SR — the pack's first
   dual-input unit, F26); sustained banks land 8 SR / 8 SL.
3. **Option A — RE-CONFIRMED for the new tail:** `es-cp-independent`
   relocates to after unit 25 automatically (B2-7: last-unit-of-stage is
   computed from lesson order, not hard-coded) with **no app-code change**;
   pack `description`/`attribution` copy updates are orchestrator-owned at
   the 0.7.14 batch-end (F25, mirroring F13). Option C (per-unit checkpoint
   cards) remains a developer-authorized future slice only.
4. **Authoring order — DECIDED:** unit 24 first (**0.7.13**), then unit 25
   (**0.7.14**), one unit per slice with the full fresh gate battery each,
   never bulk. F21 pin/count/version updates are the authoring lanes' job
   (the F10 decision carries).
5. **Research-before-authoring — MANDATORY (F29):** points 24.1–25.6 receive
   two-source verification (or honest C3/C5 gap labels) with a consolidated
   Extension batch 2 section in the grammar-sources file **before any pack
   authoring starts**; ledger rows 37–48 grammar cells are filled by the
   dedicated fill lane only.
6. **Standing discipline (F23/F24/F27/F28/F30) — ACCEPTED as written:**
   100% original content; low-stakes everyday problem scenarios (F28);
   SL provenance records + accessibility obligations at authoring (F23/F24);
   self-assessed open production, never auto-graded; no CEFR/level/
   proficiency claim anywhere in content or copy.
7. **Unit-25 research outcome — ACCEPTED with the 25.1 reframe (lib-12,
   2026-09-27):** all six points 25.1–25.6 are source-backed (two-source or
   disclosed reuse) with honest labels. **Reframe approved for 25.1:** teach
   `o sea` as *a reformulative connector documented in spoken register*
   (NGLE §30.13p + §30.13a group 5) and **omit the comparative register
   claim** («o sea more colloquial than es decir») — no extractable
   authoritative source; recorded as a C5-style labeled gap, never padded
   (the U23 `¿te importaría si…?` precedent). The Val.Es.Co DPDE citations
   (25.1/25.2/25.4) stand per the 23.5 precedent — site live, entry content
   JS-rendered/not fetched, disclosed exactly as 23.5's block does. Labeled
   conventions stand: digression-recovery bundle (25.2), text-organisation
   marker bundle (25.3, C3), summary-frame bundle (25.5, C3), relay-register
   ranking (25.6, C5).
8. **Unit-24 research outcome — ACCEPTED (lib-13, 2026-09-27), with the
   tier question resolved:** 24.1 and 24.3 are two-source verified using
   **Settemilalingue as the established-editorial second source — ACCEPTED**
   (tier precedent: Lawless Spanish already sits in the pilot's A3 pair as
   the second source beside Butt & Benjamin; both phenomena are undisputed
   descriptive grammar with NGLE as canonical first source; the site is a
   structured Spanish-FL grammar reference, above the blog/tweet sub-tier).
   The block text must record the tier honestly ("established editorial,
   Spanish-FL grammar site"). **24.2:** the «ya le digo» sub-claim is an
   **honest C5-style labeled gap** (no dedicated codification; 21.4
   precedent) — carried into the ledger, never padded; the A3 reuse covers
   ¿me podría…? only. **24.4** inherits 22.5's recorded frame-family gap;
   **24.5** written-vs-spoken register note stays a C3 convention flag;
   **24.6** clean reuse. No §B2-5 strategy changes recommended by research
   beyond lib-12's approved 25.1 reframe (decision 7).