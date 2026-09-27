# B1-oriented pilot — authoring outline (Spanish) — 2026-09-26

Phase 7.1 prep: the authoring plan for a **B1-oriented pilot** — three connected
units of six lessons each in Spanish. This document is a **plan, not shipped
content**: every lesson id below is **proposed** (`none shipped`). No file under
`Condisco/` was touched; this slice only wrote this outline and its companion
per-lesson review ledger (`docs/reviews/2026-09-26-b1-pilot-review-ledger.md`).

The app may call this a **B1-oriented pilot**, never "B1 achieved" — labels
here are content-alignment claims per `docs/editorial-rubric.md` (Content
alignment labeling rule, R6), never a learner-level claim.

Everything below is grounded in the real pack (`Condisco/Content/packs/
spanish.json`, `es-foundations`, version 0.7.5, 52 lessons / 17 units):
every retrieval hook names an existing lesson id from that file, and every
content-type marker maps to a mechanism that exists in the pack today
(verified 2026-09-26 — see the mechanism checklist in §5).

---

## 1. Why these three themes (kept, with justification)

The plan suggests travel disruption, work/study plans, and a social decision.
**Kept as proposed** — they are the themes with the widest, most natural
retrieval surface in the existing Spanish pack:

| Theme | Existing content it retrieves / builds on |
|---|---|
| **Travel disruption** | `es-transport-foundation` (unit 9, getting around), `es-directions-mission` (unit 6, station/museum navigation), `es-a2-hotel-mission` (unit 17, reporting a problem politely), `es-a2-preterito-imperfecto` (unit 13, tense choice). The 6.1 sustained-listening precedent (`es-sustained-listen-llamada`) is itself a phone call about a disrupted first day — the pattern generalises to an airport/station call. |
| **Work / study plans** | `es-a2-futuro-formacion` / `es-a2-futuro-usos` / `es-a2-planes-intenciones` (unit 14, future + plans), `es-a2-superlativos` (unit 17, work talk), `es-a2-tecnologia` (unit 17), `es-a2-comparativos` (unit 16, choosing between options). |
| **A social decision** | `es-free-time-foundation` (unit 11, gustar/encantar), `es-invitations-foundation` (unit 12, invite/accept/decline), `es-a2-me-gustaria` (unit 15, polite wishes), the existing branch dialogue `es-a2-planes-sabado` (dialogues bank, plans for Saturday). This unit reinforces the bridge gap **B2 (`porque` + sentence over a preference)** — the pack's first use is earlier, at u18L4/L5 (corrected 2026-09-26) — see §4. |

Themes map to existing units 1, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17 —
eleven of the seventeen units feed the pilot. Alternative themes (e.g. moving
house, health scares) retrieve a smaller set and overlap unit 12/7 content
already covered; keeping the suggested themes maximizes the pilot's
"retrieval from an earlier unit" requirement with real, existing lessons.

---

## 2. Unit × lesson table (18 proposed lessons)

Conventions followed from the pack:

- **Lesson ids** mirror the A2 block pattern (`es-a2-<theme>` →
  `es-b1-<theme>`), with the family-flavored suffixes the pack already mixes
  (`-narracion` like `es-a2-imperfecto`, `-mission` like `es-a2-hotel-mission`,
  `-lectura`/`-listen` new but consistent with `es-sustained-*` naming).
  New ids → the orchestrator regenerates the lesson catalog
  (`tools/gen_lesson_catalog.py`) after authoring.
- **Unit ids** continue the existing numeric convention:
  `es-unit-18` / `es-unit-19` / `es-unit-20` (new `units[]` entries).
- **Families** are from the existing enum (`discovery, story, conversation,
  listening, construction, scene, mission, recall`; `CoursePack.swift:111-114`).
  `listening` is used here for the first time in the Spanish pack — it is a
  legal family, flagged in §5.
- **Content-type markers** (all exist in the pack today, §5): SR =
  sustained-reading (`sustainedTexts[]` + step `sustainedTextId`); SL =
  sustained-listening (`sustainedListenings[]` + step `sustainedListeningId`,
  multi-section, 6.1 pattern of `es-sustained-listen-llamada`); **OTW** =
  open-task written / **OTS** = open-task spoken (`open-task` kind, modes
  written|spoken, self-assessed, 6.2); **SC** = self-compare (`self-compare`
  kind, spoken self-assessment); **DB** = dialogue-branch (`dialogues[]` bank +
  `dialogue-choice` steps, 6.3); **FT** = final task in a new setting
  (mission/transfer terminal step — a new setting is an authoring choice on
  existing step kinds, not a new mechanism).

Retrieval hook = an **existing** earlier-unit lesson whose content the lesson
re-pulls (via `legacyExercises[].reviewOf[]` spaced recall, a recall-family
step, and/or in-lesson reuse of its phrases — mechanisms verified in §5).
Prerequisites (declared `prerequisites[].lessonId`) will chain within each
pilot unit and open from the unit-17 tail (`es-a2-tecnologia` completes
`es-unit-17`, so pilot entry lessons declare it as their prerequisite where
ordering matters — final chain fixed at authoring time; catalog regen covers
it).

### Unit A — `es-unit-18` "Viaje interrumpido" (Travel disruption)
**Communicative outcome:** handle a disrupted trip — retell what happened,
understand a station/airport announcement, rebook with someone, and follow up
in writing.

| Proposed id | Family | Title | Communicative outcome | Grammar/vocab in context | Retrieval hook (from) | Content markers |
|---|---|---|---|---|---|---|
| `es-b1-retraso-narracion` | story | El tren de las siete | Tell a connected 3+ sentence narration of a delayed journey with time/order markers | Pretérito vs imperfecto in narration; primero/luego/después/al final; travel verbs (perder, retrasarse, facturar) | `es-a2-preterito-imperfecto` (u13 tense choice) | — (supported practice: selection/cloze/text on the story stimulus) |
| `es-b1-aviso-lectura` | discovery | El vuelo cancelado | Read a report + notice about a cancelled flight and extract the main point plus two supporting details | Conditional of hypothesis (sería, habría) in news register; rebooking vocab (retraso, cancelación, reprogramar) | `es-transport-foundation` (u9 getting around) | **SR** (new `es-b1-text-vuelo-cancelado`, short-article) |
| `es-b1-aeropuerto-listen` | listening | En el aeropuerto | Follow a multi-section airport/station exchange: gist plus two details | Spoken numbers/time (falta una hora, el tren de las siete); polite interruption (perdone) | `es-directions-mission` (u6 station/ticket context) | **SL** (new `es-b1-listen-aeropuerto`, 4 sections, alternating voices) |
| `es-b1-reprogramar-dialogo` | conversation | Reprogramar el viaje | Hold a 3+ turn branched exchange with an agent to rebook and confirm | Conditional politeness (me gustaría, podría, ¿le importaría?); porque for reasons | `es-a2-me-gustaria` (u15 polite wishes) | **DB** (new `es-b1-dialogo-vuelo` in the dialogues bank; host lesson) |
| `es-b1-viaje-escrito` | recall | Cuenta tu viaje | Write 2–4 connected sentences about a disrupted trip of your own | Connected past narration in writing; order markers; porque (first use in written output) | `es-a2-fin-de-semana` (u13 weekend narrative + written open-task precedent) | **OTW** (self-assessed; rubric ticks, model revealed on demand) |
| `es-b1-reclamacion-mission` | mission | La reclamación | Compose/relay a compensation claim at a service desk — a **new setting** vs all shipped venues | Reported speech (dijo que + tense); polite complaint frames (quisiera reclamar, me dijeron que) | `es-a2-hotel-mission` (u17 problem reporting) | **FT** (new setting: claims desk / phone line) + **SC** (embedded `es-b1-reclamacion-say`, precedent `es-cafe-listen-say`) |

### Unit B — `es-unit-19` "El trabajo y los estudios" (Work and study plans)
**Communicative outcome:** talk about work/study plans and intentions, follow
a job/study-related conversation, and justify decisions with reasons.

| Proposed id | Family | Title | Communicative outcome | Grammar/vocab in context | Retrieval hook (from) | Content markers |
|---|---|---|---|---|---|---|
| `es-b1-trabajo-futuro` | discovery | El año que viene | State work/study plans distinguishing decided (ir a), scheduled (present) and predicted (future simple) plans | Futuro simple vs ir a + inf. vs present; porque in plan reasons (B2 gap — pack's first use is u18L4/L5, corrected 2026-09-26); study/work vocab | `es-a2-planes-intenciones` (u14) | — |
| `es-b1-trabajo-listen` | listening | La llamada de la oferta | Follow a 3+ minute multi-section call about a job offer and extract main point + two details | Numbers/salaries; conditional in offers (podría empezar…); turn-taking in calls (a ver, ¿me oyes?) | `es-a2-tecnologia` (u17 work/tech vocab) | **SL** (new `es-b1-listen-oferta`, multi-section, alternating voices) |
| `es-b1-entrevista-lectura` | discovery | Una entrevista | Read a candidate's account / interview article and extract main point + two supporting details | Superlatives/work talk in context; porque in justification; relative links (que, quien) | `es-a2-superlativos` (u17 work talk) | **SR** (new `es-b1-text-entrevista`, interview article) |
| `es-b1-decision-dialogo` | conversation | ¿Cuál elijo? | Negotiate a choice between two offers in a 3+ turn branched dialogue | Comparatives in context; deberías (soft advice); porque + reasons | `es-a2-comparativos` (u16) | **DB** (new `es-b1-dialogo-oferta` in the dialogues bank; host lesson) |
| `es-b1-plan-escrito` | recall | Tu plan de estudios | Write 2–4 connected sentences about a study/work plan with at least one porque reason | Future/ir a in connected writing; porque; sequence markers | `es-a2-futuro-usos` (u14 future uses) | **OTW** (self-assessed) |
| `es-b1-entrevista-mission` | mission | La entrevista | Perform a mock job interview — a **new setting** vs all shipped venues | Self-presentation (me llamo, llevo…, soy de…); polite requests; work vocab; subjunctive trigger (espero que) light revisit | `es-introductions-foundation` (u1 introducing yourself) | **FT** (new setting: interview) + **SC** (embedded `es-b1-entrevista-say`) |

### Unit C — `es-unit-20` "Una decisión social" (A social decision)
**Communicative outcome:** negotiate a social decision (a celebration/plan) —
explain a preference with a reason, accept/decline gracefully, agree on a plan.

| Proposed id | Family | Title | Communicative outcome | Grammar/vocab in context | Retrieval hook (from) | Content markers |
|---|---|---|---|---|---|---|
| `es-b1-preferencia-razones` | discovery | Me gusta porque… | Explain a preference with gustar/encantar/querer plus a porque + sentence reason | Gustar-type verbs; **porque + sentence (bridge gap B2 — pack's first use is u18L4/L5, reinforced here; corrected 2026-09-26)** vs por + noun; porque/por qué/por que orthography | `es-free-time-foundation` (u11 likes) | — |
| `es-b1-fiesta-listen` | listening | La llamada del cumpleaños | Follow a multi-section planning call and extract the agreed plan plus two details | Invitation frames in speech (¿te apetece…?); future/ir a in plans; porque | `es-invitations-foundation` (u12 invitations) | **SL** (new `es-b1-listen-fiesta`, multi-section, alternating voices) |
| `es-b1-celebracion-lectura` | discovery | El aniversario | Read a message-thread deliberation and extract main point + two supporting details | Conditional invitation (te gustaría…); para + purpose; porque reasons | `es-a2-condicional` (u15) | **SR** (new `es-b1-text-aniversario`, message-thread) |
| `es-b1-plan-dialogo` | conversation | ¿Quedamos? | Repair a misunderstanding and agree on a plan in a 3+ turn branched dialogue | Vamos a / quedamos en / ¿qué te parece?; accept/decline formulas | `es-a2-planes-intenciones` (u14; branch precedent `es-a2-planes-sabado`) | **DB** (new `es-b1-dialogo-fiesta` in the dialogues bank; host lesson) |
| `es-b1-decision-escrito` | recall | Tu decisión | Write 2–4 connected sentences justifying a social choice with reasons | Preference + porque; accept/decline revisited in writing | `es-a2-me-gustaria` (u15 polite preference frame) | **OTW** (self-assessed) |
| `es-b1-regalo-mission` | mission | El regalo del grupo | Organise a group gift in a group-chat + shop run — a **new setting** vs all shipped venues | por/para in purpose/cause; prices/quantities revisited; te lo/te la clitic combo (light) | `es-market-foundation` (u10 prices/buying) | **FT** (new setting: group decision) + **SC** (embedded `es-b1-regalo-say`) |

**Per-unit requirement coverage (from plan §7.1):**

| Requirement (per unit) | Unit A | Unit B | Unit C |
|---|---|---|---|
| Sustained input (≥1) | SR + SL | SL + SR | SL + SR |
| Vocabulary/grammar in context | ✓ every lesson | ✓ every lesson | ✓ every lesson |
| Retrieval from an earlier unit | ✓ all 6 lessons, named hooks (§2) | ✓ all 6 lessons | ✓ all 6 lessons |
| Connected writing | OTW `es-b1-viaje-escrito` | OTW `es-b1-plan-escrito` | OTW `es-b1-decision-escrito` |
| Spoken self-comparison | SC in `es-b1-reclamacion-mission` | SC in `es-b1-entrevista-mission` | SC in `es-b1-regalo-mission` |
| Multi-turn interaction | DB `es-b1-reprogramar-dialogo` | DB `es-b1-decision-dialogo` | DB `es-b1-plan-dialogo` |
| Final task in a new setting | claims desk | job interview | group gift decision |

Embedding the unit's self-compare **inside its closing mission** mirrors the
shipped precedent (`es-cafe-listen-say` inside `es-cafe-mission`, steps
10–14) and keeps the unit at six lessons. If authoring prefers a dedicated
self-compare lesson per unit, the unit grows to seven lessons — the plan says
"roughly six", so six is the default, not a constraint.

---

## 3. Pilot-wide coverage matrix vs plan minimums

| Plan minimum target | Named items | Met? |
|---|---|---|
| ≥1 sustained input per unit | A: SR+SL · B: SL+SR · C: SL+SR | ✓ (2 per unit) |
| 3 original extended readings | `es-b1-aviso-lectura` (u18L2), `es-b1-entrevista-lectura` (u19L3), `es-b1-celebracion-lectura` (u20L3) | ✓ |
| 3 multi-minute listening pieces | `es-b1-aeropuerto-listen` (u18L3), `es-b1-trabajo-listen` (u19L2), `es-b1-fiesta-listen` (u20L2) — each the multi-section synthesized pattern of 6.1 `es-sustained-listen-llamada` (per-section heading + text + `voiceId`/`languageCode` + `accessibilityLabel`, alternating es-ES/es-MX voices) | ✓ |
| 3 independent checkpoint tasks | New `es-cp-independent` (`stage: independent`) entry in the `checkpoints` bank with **3 items**: reading (unseen passage, auto-graded recognition — main point + 2 details), writing (connected response), speaking (record + self-assessed rubric) | ✓ with one surfacing note (§4/§5) |
| Connected writing per unit | 3 × OTW (u18L5, u19L5, u20L5) | ✓ |
| Spoken self-compare per unit | 3 × SC embedded in the missions | ✓ |
| Multi-turn dialogue per unit | 3 × DB (u18L4, u19L4, u20L4) | ✓ |
| Final task in a new setting per unit | 3 × FT (u18L6, u19L6, u20L6) | ✓ |

**No gaps against the plan minimums.** The only interpretive flag: the
checkpoint target reads "three independent checkpoint tasks"; the bank and UI
consume **one entry per stage** (`pack.checkpoints.first { $0.stage == … }`,
`CoursesView.swift:405`), so the honest shape is one `es-cp-independent` entry
whose three items are the three tasks. If the intent was three separate stage-
independent entries, the UI would surface only the first — a mechanism note,
not a blocker (§5, flag F3).

### cefr-tagging approach for the pilot (content alignment only)

Every proposed pilot lesson carries `cefr: "B1"` as an **alignment tag** — it
describes what the content aligns with (CEFR B1 task descriptors), never what
the learner has achieved (rubric R6; content-alignment labeling rule). The
consequences, both existing mechanisms:

- `CoursesView.swift:294-299` derives the course path from `lesson.cefr`:
  `"A2"` → Developing, `"A1"`/nil → Foundation, **anything else →
  Independent**. `"B1"` tags therefore populate the currently-empty
  **Independent** path card automatically — no UI change.
- `CheckpointFlow.swift:36-42` (`checkpointStage(of:)`) maps `"B1"` → `.independent`,
  and the stage-end checkpoint card appears after the last pilot unit only
  when `pack.checkpoints` ships a `.independent` entry — which is exactly the
  `es-cp-independent` bank item above.
- The Independent path's prerequisite line already says "Would follow
  Developing." — accurate for the pilot (entry prerequisites on the first
  pilot lessons reference unit-17 tail lessons).

Labels stay content alignment: pack `description`, unit objectives and lesson
copy may describe the pilot as **B1-oriented**, never "B1 achieved" (bridge
doc §2; `docs/editorial-rubric.md` content-alignment rule; `native-review-kit.md` §Certification policy).

---

## 4. Bridge-gap alignment (rubric §"A2→B1 bridge (Spanish)" + `docs/reviews/2026-09-26-a1a2-bridge-spanish.md` §2)

The five bridge capabilities are what the B1 path teaches first (rubric
dispositions). Coverage map:

| # | Capability | Covered by | Status |
|---|---|---|---|
| B1 | Connected narration (3+ sentences, time/order markers) | `es-b1-retraso-narracion` (u18L1) — the pack's first 3+ sentence connected narration with primero/luego/después/al final (closing the `es-a2-fin-de-semana` sequence-word drift — the drift itself stays a deferred pack-copy fix); reinforced by every OTW lesson | ✓ covered |
| B2 | Explanation of a preference with reasons (`porque` absent pack-wide) | **porque + sentence is first taught at u18L4 (`es-b1-reprogramar-dialogo`, reason frame) and u18L5 (`es-b1-viaje-escrito`, first in written output)** — corrected 2026-09-26; `es-b1-preferencia-razones` (u20L1) then reinforces it over the u11 gustar/encantar repertoire (no longer the pack's first use); further reinforced u20L4 dialogue, u20L5 OTW, checkpoint writing item, u19 OTWs | ✓ covered — **flag F4**: rubric/bridge disposition said "needs a **bridging lesson in A2**"; the pilot teaches it at B1 instead — first at u18L4/L5 (corrected 2026-09-26). Either the disposition is revised to "B1 path teaches it first" for the pilot (and the A2 bridge lesson stays backlog), or an A2 bridge lesson is authored separately first. Decision needed from the orchestrator — not a structural blocker. |
| B3 | Following multi-turn exchanges | 3 × DB lessons on `dialogues[]` (u18L4, u19L4, u20L4): 3+ turn branched graphs with repair/clear nodes (pattern of shipped `es-a2-planes-sabado`); the 3 SL calls are multi-turn spoken exchanges | ✓ covered |
| B4 | Extracting main point + supporting detail | All 6 SR/SL lessons include a gist step + ≥2 detail checks (precedent `es-cafe-listen-gist/-drink/-here`); checkpoint reading item; FT reading surfaces in missions | ✓ covered |
| B5 | Short connected written response (2–4 sentences) | 3 × OTW written; checkpoint writing item. **The B5 product dependency is already resolved**: the bridge review pins this on a new ungraded/self-assessed written step type, and `open-task` (mode written) shipped with 5.3/6.2 (`es-a2-fin-de-semana-open-task`) — H1-compliant (self-assessed, never fixed-list graded) | ✓ covered, dependency met |

**Missed by the three units:** no bridge capability B1–B5 is left uncovered.
Two non-blocking leftovers, flagged for the record: (a) the B2 disposition
wording (F4 above); (b) `es-a2-fin-de-semana`'s objective-drift pack-copy fix
and the `porque`-in-A2 bridge lesson are outside pilot scope and remain
backlog. Nothing in the pilot's non-covered surface: no lesson in the three
units teaches formal written register (a complaint *letter* as opposed to the
claims-desk spoken/written claim) — that is a future backlog item, not a
bridge capability.

---

## 5. Mechanism checklist — every marker maps to something that exists

All verified against `es-foundations` v0.7.5 + `Condisco/Models/CoursePack.swift` + `Condisco/Lesson/CoursesView.swift` + `Condisco/Lesson/CheckpointFlow.swift` on 2026-09-26:

| Mechanism | Exists today (evidence) | Pilot use |
|---|---|---|
| Sustained reading | `sustainedTexts[]` bank (3 shipped: `es-sustained-text-mensajes/-articulo/-narracion`); a lesson step binds via **`sustainedTextId`** on an `information` launch step (`es-plans-foundation-step-sustained`) | 3 new entries: `es-b1-text-vuelo-cancelado`, `es-b1-text-entrevista`, `es-b1-text-aniversario` |
| Sustained listening | `sustainedListenings[]` bank (1 shipped: `es-sustained-listen-llamada` — sections with heading/text/`voiceId`/`languageCode`/`accessibilityLabel`, device speech); step binds via **`sustainedListeningId`** (`es-a2-imperfecto-step-listen`) | 3 new entries per the llamada pattern: `es-b1-listen-aeropuerto`, `es-b1-listen-oferta`, `es-b1-listen-fiesta` |
| Open task (written / spoken) | `open-task` kind with `mode: written\|spoken`, self-assessed rubric ticks, `modelResponse` reveal (3 shipped: `es-a2-fin-de-semana-open-task` written; `es-cafe-requests-foundation-open-task` and `es-a2-planes-intenciones-open-task` spoken) | 3 OTW: `es-b1-viaje-escrito-open-task`, `es-b1-plan-escrito-open-task`, `es-b1-decision-escrito-open-task` |
| Self-compare | `self-compare` kind, `modelText` + optional `modelAudioId`, outcome `.selfAssessed` (1 shipped: `es-cafe-listen-say`) | 3 embedded: `es-b1-reclamacion-say`, `es-b1-entrevista-say`, `es-b1-regalo-say` |
| Dialogue branch | `dialogues[]` bank (2 shipped: `es-cafe-turno`, `es-a2-planes-sabado` — `hostLessonId`, `prerequisite`, `start`, `nodes[]` with `choices→next`, `kind` clarification/misunderstanding markers) + in-lesson `dialogue-choice` kind (12 shipped) | 3 new bank entries: `es-b1-dialogo-vuelo`, `es-b1-dialogo-oferta`, `es-b1-dialogo-fiesta`, each hosted by its DB lesson |
| Checkpoint bank | `checkpoints[]` with `stage: foundation\|developing` (2 shipped: `es-cp-foundation`, `es-cp-developing`); `.independent` stage declared in `CheckpointStage` (no shipped tasks); items reading (auto-graded recognition, unseen passage) / writing (ungraded) / speaking (rubric) | New `es-cp-independent` entry, 3 items |
| Retrieval from an earlier unit | `legacyExercises[].reviewOf[]` spaced recall (mechanism per rubric T10/R4), `recall`-family lessons, and in-lesson reuse of earlier phrases | Named per lesson in §2; most lessons carry a `reviewOf` legacy exercise pointing at their hook lesson |
| Final task in a new setting | Mission terminal steps (distinct pre-planned final response, rubric M5) and transfer-purpose open tasks (`es-a2-fin-de-semana-step-open-task`, purpose `transfer`) — "new setting" is authoring choice on existing step kinds | FT lessons above |
| cefr → Independent path | `CoursesView.coursePath(of:)` default branch + `checkpointStage(of:)` default branch | `cefr: "B1"` tags on all 18 pilot lessons |
| Audio provenance | `docs/audio-provenance/*.json` facts-only records + `tools/device-speech-media.txt` allowlist + `checkAttributionCitations` (rubric R3/T9); café pilot pattern (`spanish-cafe-listen-pilot.json`) | Per-voice provenance records for the 3 SL pieces (see ledger) — **pending**, written when audio is authored |

**New assets the pilot authoring will add (all additive schema shapes, nothing
structural):** 3 `sustainedTexts[]` entries, 3 `sustainedListenings[]` entries,
3 `dialogues[]` entries, 1 `checkpoints[]` entry, 18 lessons / 20 activity
groups under 3 new units, concepts/vocabulary for the new grammar/vocab, and
provenance records. The pack is already additive-shape safe
(`PackUpdateTests` pins that a grown checkpoint bank projects unchanged).

---

## 6. Grammar-point list per unit (for later two-source checking)

The source policy: every disputed/known-tricky grammar or usage point gets
**two independent authoritative references** (the class of source: RAE/ASALE
`NGLE`/`DPD`, Fundéu, etc. — citations are filled by the research lane, never
fabricated here). Each point below is one the unit's lessons actually teach,
with the aspect worth two-source verification.

### Unit A — Viaje interrumpido
| # | Point | Tricky aspect worth two-source verification |
|---|---|---|
| A1 | Pretérito vs imperfecto in narration | Foreground events vs background/description/habit; the same verb switches tenses across the same story (NGLE §23.2–23.9 vs §24 treatment); `hubo un retraso` (event) vs `había mucha gente` (state) |
| A2 | Sequence markers: primero, luego, después, al final, entonces, de repente | luego vs después overlap and register; whether de repente counts as a sequencer |
| A3 | Conditional politeness: me gustaría, podría, quisiera, quería | Register ordering of the politeness set; colloquial imperfect `quería un café` as polite — vs the A2-taught quisiera (u15) |
| A4 | Reported speech intro: dijo que + tense | Spanish allows non-backshifted tenses in reports (dijo que el tren sale/llegaba/llegará); which sequence is natural for B1 |
| A5 | por/para in travel contexts | por las obras (cause/route) vs para las siete (deadline) — revisiting u16 in new context |
| A6 | Requests/register at a claims desk | Direct vs softened complaint variants (quisiera reclamar vs quiero reclamar); politeness vs firmness in service encounters |

### Unit B — El trabajo y los estudios
| # | Point | Tricky aspect worth two-source verification |
|---|---|---|
| B1 | Futuro simple vs ir a + inf. vs present for plans | Decided/scheduled/predicted split; futuro of probability is out of pilot scope (u14 taught it; decide if the pilot reintroduces) |
| B2 | porque + sentence for reasons (first use pack-wide — taught from u18L4/L5, corrected 2026-09-26) | First occurrence pack-wide (now u18L4/L5) — orthography porque/por qué/por que (DPD entry), position of the causal clause; B2 stays Unit 19's two-source point for the orthography/causal rule |
| B3 | deberías vs debes for advice | Register: conditional softens; debes = stronger obligation (u15 taught -ías advice in es-a2-condicional) |
| B4 | Comparatives/relatives in work talk | más/menos… que vs tan… como revisits u16; que vs quien for persons |
| B5 | Present subjunctive light revisit (espero que + subj) | quiero/espero que triggers taught in u15 (es-a2-subjuntivo-intro); B1-pilot scope decision: recognition-only or production |
| B6 | estar de + activity / ser + role | estar de prácticas vs es el director — ser/estar with work nouns |

### Unit C — Una decisión social
| # | Point | Tricky aspect worth two-source verification |
|---|---|---|
| C1 | Gustar-type verbs + porque | Verb agreement with postposed subject (me gustan los museos); dative/clitic forms (te gustaría, les encanta); porque over the u11 preference repertoire (the pack's first porque use is u18L4/L5 — corrected 2026-09-26) |
| C2 | porque vs por qué vs por que (writing) | Orthographic distinction (DPD porque entry); porque already surfaced in written output at u18L5 — C2 teaches the orthography distinction itself (corrected 2026-09-26) |
| C3 | Invitation formulas: ¿te gustaría…?, ¿te apetece…?, claro que sí, lo siento, no puedo | Register/frequency of the accept/decline set (u12 invitations revisited at B1 length) |
| C4 | para + infinitive vs por + cause in organizing | para regalar (purpose) vs por su cumpleaños (cause/occasion) — u16 por/para revisited |
| C5 | Planning frames: vamos a + inf., quedamos en + place, ¿qué te parece? | Sentence-level proposal frames and their reply patterns |
| C6 | Clitic combo light revisit: te lo/te la (le lo → se lo) | Combination order and se-rule (u16 es-a2-pronombres-od-oi revisited; production scope decision) |

---

## 7. Blockers / flags found (none structural)

- **F1 — first `listening` family in es.** The family exists in the enum
  (`CoursePack.swift:111-114`) but no Spanish lesson uses it today. Legal;
  flagged so the authoring lane knows the family layout is unproven in es.
- **F2 — audio provenance for the 3 SL pieces.** The shipped llamada pattern
  is device speech via per-section `voiceId` (no `media[]` entry today), but
  rubric R3's provenance requirement still applies: facts-only records under
  `docs/audio-provenance/spanish-b1-*.json` + `reviewPending: true` disclosure
  + allowlist entries where a bound stimulus/media is added. Mechanism exists;
  authoring obligation, not a blocker.
- **F3 — checkpoint surfacing.** CoursesView/CheckpointFlow show the stage-end
  card only for the *first* checkpoint of a stage — one `es-cp-independent`
  entry with 3 items is the honest shape for "three independent checkpoint
  tasks" (see §3).
- **F4 — B2 disposition wording** (rubric says A2 bridge lesson; pilot teaches
  porque at B1 — first at u18L4/L5, corrected 2026-09-26). Needs an orchestrator
  decision, not a mechanism.
- **F5 — variant review spans es-ES + es-MX.** The shipped SL pattern
  alternates es-ES/es-MX device voices; pilot SL pieces will too, so the
  regional-variant review in the ledger must cover both. Not a blocker.
- **F6 — new ids → catalog regen.** 18 lesson ids + 3 unit ids are new;
  `tools/gen_lesson_catalog.py` must run after authoring (preflight step 3).
  The orchestrator owns this.

**No missing mechanism blocks any plan requirement.** Every marker in §2 maps
to a verified existing mechanism; nothing was invented.

---

## 8. Authoring-time gate chain (done-when, mapped to existing tooling)

The plan's done-when, mapped to what exists today (all future authoring-lane
work, listed so the outline is complete):

1. **No dead-end branch** — `dialogues[]` graphs validated (reachability of
   `choices→next`, terminal nodes) by `tools/check_packs.sh` + step-graph
   closure C4.
2. **No falsely graded open response** — every OTW/SC step is `selfAssessed`
   (outcome check, `ActivityEvaluation.swift`), never fixed-list graded (H1);
   strict audit (`audit_editorial.sh --strict`) reports none.
3. **No missing media** — new audio assets declared + allowlisted +
   provenance-cited (R3); `check_packs.sh` media/allowlist check green.
4. **Complete per-lesson review record** — the companion ledger
   (`2026-09-26-b1-pilot-review-ledger.md`) filled per lesson with
   source-backed grammar checks, accepted-answer review, variant, audio
   provenance, accessibility pass, unresolved naturalness questions.
5. **Passing pack/unit/UI gates** — `bash tools/preflight.sh` exits 0;
   `python3 tools/audit_outcomes.py` exits 0; unit suite green (StoreTests
   PackUpdateTests shape); catalog regenerated; iPhone walkthrough by the
   developer (checklist item, recorded in the ledger's developer sign-off
   column).
6. **Wording gate** — product surfaces say **B1-oriented pilot**, never
   "B1 achieved" (R6; §3 cefr note).

---

## 9. Companion documents

- Per-lesson review ledger: `docs/reviews/2026-09-26-b1-pilot-review-ledger.md`
  (one pre-created row-block per proposed lesson; all sources `pending`).
- Bridge definitions: `docs/editorial-rubric.md` ("A2→B1 bridge (Spanish,
  2026-09-26)") and `docs/reviews/2026-09-26-a1a2-bridge-spanish.md`.
- Review conventions: `docs/native-review-kit.md`, `docs/reviews/review-log.jsonl`.
- Audio provenance pattern: `docs/audio-provenance/spanish-cafe-listen-pilot.json`.
- No pointer added to `docs/skill-map.md`: it has no natural index/navigation
  section for review documents (it is a per-language evidence map with a
  backlog and a "Keeping this map honest" closer); a pointer line would not
  fit an existing structure, so it was skipped by design.