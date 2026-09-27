# B1-oriented pilot — per-lesson review ledger (Spanish) — 2026-09-26

Companion to `docs/reviews/2026-09-26-b1-pilot-outline.md`. One pre-created
row-block per **proposed** pilot lesson (18 total, none shipped). Every source
field below starts **empty/`pending`** — sources are filled by the later
research lane, never in this prep slice.

## Rules of this ledger

1. **Two INDEPENDENT authoritative references for disputed linguistic
   claims.** The class of acceptable source: RAE/ASALE `NGLE` (Nueva gramática)
   and `DPD` (Diccionario panhispánico de dudas), Fundéu, and comparable
   published reference grammars / usage dictionaries. **No citation may be
   fabricated** — a row stays `pending` until the research lane names two real,
   independently authored references and records both (reference 1, reference
   2) plus a disposition.
2. **AI agreement alone is not evidence.** Two or more AI models agreeing on a
   disputed point does not clear a grammar/usage check; only the
   reference-backed disposition clears it. `reviewMethod: "AI-assisted"`
   reviews are editorial evidence only and **never** clear native review
   (convention: `docs/native-review-kit.md`).
3. **Method honesty.** Every block starts with `reviewMethod: AI-assisted`
   (the existing honest-method convention; see "Convention source" below).
   `developer` sign-off column stays **empty** until the developer reviews;
   the pack `attribution` "native-speaker editorial review remains open"
   language applies to every pilot lesson (`native review: pending`) until an
   `external-human` record with a named reviewer and recorded variant exists.
4. **Wording.** These are **B1-oriented pilot** lessons — content-alignment
   labels only (rubric R6). No record here, and no product copy, may claim
   "B1 achieved".

## Convention source (quoted, not reinvented)

From `docs/reviews/review-log.jsonl` (first record, 2026-09-25) — the pattern
this ledger mirrors:

> "AI-assisted solo editorial review only; native-speaker review remains
> pending."

From `docs/native-review-kit.md` (review methods table):

> `AI-assisted` — An AI model reviewed a lesson (full or in part), possibly
> reviewed by the developer afterwards. … "No — never. AI-assisted review is
> *not* native review and must never be recorded as such."

From the same kit (per-lesson record): `unreviewed` is the initial state of
every seeded record; `modelOrTool` required for `AI-assisted`; `variant`
BCP-47 (`es-ES`, `es-MX`, …); a re-review is a new row with a new date.

**Common seed values** (overridable per lesson): `packId: es-foundations`,
`packVersion: 0.7.5`, `reviewMethod: AI-assisted`, `reviewer: solo maintainer`
(a later human lane), `modelOrTool: pending` (record the model version when
the review runs), `date: pending`, `disposition: unreviewed`,
`variant: pending` (proposed default es-ES for Castilian content; sustained
listenings span es-ES + es-MX device voices per the shipped 6.1 pattern —
record the reviewed variant(s)), `native review: pending` (every lesson),
`developer sign-off: ` (empty until the developer walkthrough, outline §8 item
5 records it).

*Audio provenance link pattern:* `docs/audio-provenance/<id>.json` — the file
is created by the authoring lane per rubric R3; until then the cell says
`pending — docs/audio-provenance/…` (facts-only record, never fabricated;
pattern: `docs/audio-provenance/spanish-cafe-listen-pilot.json`).

---

## Unit A — `es-unit-18` "Viaje interrumpido" (travel disruption)

### 1. `es-b1-retraso-narracion` (story)
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | A1: RAE/ASALE, NGLE §23.12–23.13 (opposition canté/cantaba) — https://www.rae.es/gramática/sintaxis/el-pretérito-imperfecto-cantaba-iii-relevancia-del-modo-de-acción-la-oposición-canté--cantaba · RAE, "Español al día" («Había muchas personas», «ha habido quejas», «hubo problemas») — https://www.rae.es/espanol-al-dia/habia-muchas-personas-ha-habido-quejas-hubo-problemas · disposition: both accept the foreground/background split; había (state) vs hubo (event) confirmed — note: different works, same institution (RAE/ASALE), undisputed. A2: RAE/ASALE, NGB §16.3 "Los conectores discursivos" — https://www.rae.es/gramática-básica/la-preposición-la-conjunción-la-interjección/los-conectores-discursivos · RAE/ASALE, NGLE §30.13a (group 10 "De ordenación") + §30.13s — https://www.rae.es/gramática/sintaxis/conectores-discursivos-adverbiales-ii-clases-semánticas · disposition: both list luego/después/al final/entonces in the ordering group; register nuance not disputed — note: different works, same institution, undisputed — points A1 (pretérito/imperfecto narration), A2 (sequence markers). The authored content teaches the A1/A2 points named here: story passage contrasts hubo (event) vs había (scene) and eran/hacía; activity errors teach the switch; primero/luego/después/al final appear in the passage, examples stimulus and three activities |
| Accepted-answer review | AI-assisted 2026-09-26 — every `text`/`cloze` `answers[]` compared against the dictated story phrase per the comprehension worklist. Variants included: `Hubo un problema en las vías.` + singular `Hubo un problema en la vía.` (both natural); read step accepts ES full phrase, bare noun phrase and English gloss; recall accepts `a casa de nuestros tíos` and `a la casa de nuestros tíos` (both natural); EN + ES forms on the (Reading) step. Accents preserved where distinguishing (salió, había, llegamos); `allowTypo: true` set on every answer; errors[] does not collide with any accepted form (R2 checked in-lane) |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned |
| Accessibility pass | pass (structural) — story is a `text` stimulus with `translation`; every prompt/hint/feedback is plain readable text; no ungraded/self-assessed step in this lesson (H2 n/a) |
| Unresolved naturalness questions | Story idiom worth a native check: «mi hermana perdió la paciencia» and «la cena estaba fría» as a closing beat; whether «llegamos a casa de nuestros tíos» reads as naturally as «a la casa de…» at B1 |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 2. `es-b1-aviso-lectura` (discovery) — sustained reading `es-b1-text-vuelo-cancelado`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | A3: J. B. Butt & C. Benjamin, A New Reference Grammar of Modern Spanish, 6th ed., Routledge (2018), §21.3.3 area (conditional/politeness treatment) · Lawless Spanish Grammar, "Polite requests: querría, quería and quisiera" — https://progress.lawlessspanish.com/revision/grammar/querria-queria-and-quisiera-as-forms-of-courtesy · disposition: register gradation confirmed; quería accepted as colloquial politeness — note: independent pair (different authors, institutions, publishers). A5: RAE, DLE s.v. por (cause, route, means senses) — https://dle.rae.es/por · RAE/ASALE, DPD s.v. porque §1a–b (causal porque = por + cause; final = para + purpose) — https://www.rae.es/dpd/porque · disposition: cause vs purpose distinction supported; travel context is a direct application — note: different works, same institution, undisputed — points A3 (conditional of hypothesis in news register), A5 (por/para travel contexts). Authored content teaches A3 (reprogramaría/sería/había que in reported news register; activity errors contrast conditional vs future vs pretérito). A5 shows in content lightly («por el mal tiempo» cause, «para facturar» purpose) but is not the lesson's graded target — kept as exposure wording only |
| Accepted-answer review | AI-assisted 2026-09-26 — gist + 2-detail recognition over the article. Variants included: read step accepts full phrase, bare «Aceptar la nueva reserva.» and English gloss; recall accepts the full offer sentence and the bare conditional clause. Every sustained question accepts exactly one option (deterministic set-equality grading, no open auto-grading); distractor options are factually distinct from the article. `allowTypo: true` on all answers; R2 (no accepted/error collision) checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned (sustained reading only) |
| Accessibility pass | pass (structural) — the article ships 4 sections, each with a per-section `accessibilityLabel`, plus a section-list `accessibleSummary`; article body is plain readable text with `provenance`; no ungraded step beside the sustained launch (labeled "Read the short article…", H2-safe) |
| Unresolved naturalness questions | News-register naturalness for B1 worth a native check: «Según el comunicado oficial», «una portavoz», and the quoted conditional «Sería posible salir el domingo» — plausibility of the invented airline «Aerolínea Costa» and flight id CO-417 |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 3. `es-b1-aeropuerto-listen` (listening) — sustained listening `es-b1-listen-aeropuerto`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | A4: RAE/ASALE, NGB §25.5 "Discurso directo y discurso indirecto" — https://www.rae.es/gramática-básica/oraciones-subordinadas-sustantivas/discurso-directo-y-discurso-indirecto · RAE/ASALE, Glosario de términos gramaticales, s.v. "discurso indirecto" (refs. NGLE §43.9–43.10) — https://www.rae.es/gtg/discurso-indirecto · disposition: tense adaptation described, not mandated; non-backshifted sequences accepted — note: different works, same institution, undisputed — spoken numbers/time forms; A4 (reported speech in the exchange). Authored content: the exchange carries the spoken forms (falta una hora, el embarque es a las siete y cuarto, la puerta número doce, perdón/perdone as polite interruption). A4 is exposed lightly («he oído un aviso») but not graded |
| Accepted-answer review | AI-assisted 2026-09-26 — gist + 2-detail recognition over the audio. Variants included on the read step: full gate phrase, bare «La número doce.» and English gloss; recall accepts the full polite request plus natural short forms with/without the opener («Perdone, ¿puede repetir, por favor?» / «¿Puede repetir el aviso, por favor?»), and errors teach the tú/usted register mismatch rather than rejecting a form. Time answers use words (las siete y cuarto) — digits deliberately not accepted on the write step since the dictated form is the word form. `allowTypo: true`; R2 checked in-lane |
| Regional variant | spans es-ES + es-MX device voices (6.1 pattern): sections 1/3 es-ES (com.apple.voice.compact.es-ES.Monica), sections 2/4 es-MX (com.apple.voice.compact.es-MX.Paulina); content itself is neutral-standard Spanish suitable for both regions. Recorded for review: both variants |
| Audio provenance | `docs/audio-provenance/spanish-b1-listen-aeropuerto.json` (created 2026-09-26) — device speech via per-section `voiceId`, no media entry, `reviewPending: true`; no allowlist entry needed (no MediaItem asset) |
| Accessibility pass | pass (structural) — per-section `accessibilityLabel` with the synthesised-voice disclosure on all 4 sections, plus `accessibleSummary`; transcript-reveal behavior follows the `es-sustained-listen-llamada` pattern |
| Unresolved naturalness questions | Device-voice naturalness of the es-ES/es-MX pair for announcements pending a human listen; whether «¿Ha pasado algo con el vuelo?» reads as natural passenger speech at B1; «oigo mal cuando anuncian por megafonía» idiom worth a native check |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 4. `es-b1-reprogramar-dialogo` (conversation) — dialogue `es-b1-dialogo-vuelo`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | A3: J. B. Butt & C. Benjamin, A New Reference Grammar of Modern Spanish, 6th ed., Routledge (2018), §21.3.3 area (conditional/politeness treatment) · Lawless Spanish Grammar, "Polite requests: querría, quería and quisiera" — https://progress.lawlessspanish.com/revision/grammar/querria-queria-and-quisiera-as-forms-of-courtesy · disposition: register gradation confirmed; quería accepted as colloquial politeness — note: independent pair (different authors, institutions, publishers) — A3 (conditional politeness set incl. imperfect `quería` register). Authored content teaches the set me gustaría / podría / quisiera / quería throughout the lesson activities and the hosted exchange, with porque + sentence as the reason frame (outline L4 row; overlaps bridge flag F4 — see report) |
| Accepted-answer review | AI-assisted 2026-09-26 — dialogue-choice option feedback reviewed for never contradicting accepted forms; in-lane graph check confirms no dead-end branch: every path reaches an explicit end state with ≥3 learner turns; the hosted exchange (es-b1-dialogo-vuelo) carries a clarification node, a misunderstanding node with an authored recovery route, and a recovery node that routes back on with choices. Lesson text answers accept natural variants (e.g. «¿Podría darme otra fecha?» / «¿Me podría dar otra fecha?») and errors teach register rather than rejecting valid forms; `allowTypo: true`; R2 checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned (exchange is read, not voiced) |
| Accessibility pass | pass (structural) — dialogue nodes carry the shipped line + `meaning` gloss pair, every hosted choice has a stable id, and the open turn labels itself self-assessed (rubric tick, never auto-graded) |
| Unresolved naturalness questions | Agent register (formal but not stiff) worth a native check: «¿Podría contarme el motivo exacto para anotarlo?» and «Que tenga buen viaje» as the closer; whether the misunderstanding premise (agent hears martes for lunes) is plausible over the phone/counter |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 5. `es-b1-viaje-escrito` (recall) — open task written
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | A1: RAE/ASALE, NGLE §23.12–23.13 (opposition canté/cantaba) — https://www.rae.es/gramática/sintaxis/el-pretérito-imperfecto-cantaba-iii-relevancia-del-modo-de-acción-la-oposición-canté--cantaba · RAE, "Español al día" («Había muchas personas», «ha habido quejas», «hubo problemas») — https://www.rae.es/espanol-al-dia/habia-muchas-personas-ha-habido-quejas-hubo-problemas · disposition: both accept the foreground/background split; había (state) vs hubo (event) confirmed — note: different works, same institution, undisputed. A2: RAE/ASALE, NGB §16.3 "Los conectores discursivos" — https://www.rae.es/gramática-básica/la-preposición-la-conjunción-la-interjección/los-conectores-discursivos · RAE/ASALE, NGLE §30.13a (group 10 "De ordenación") + §30.13s — https://www.rae.es/gramática/sintaxis/conectores-discursivos-adverbiales-ii-clases-semánticas · disposition: both list luego/después/al final/entonces in the ordering group; register nuance not disputed — note: different works, same institution, undisputed. A5: RAE, DLE s.v. por (cause, route, means senses) — https://dle.rae.es/por · RAE/ASALE, DPD s.v. porque §1a–b (causal porque = por + cause; final = para + purpose) — https://www.rae.es/dpd/porque · disposition: cause vs purpose distinction supported; the DPD porque entry likewise backs the causal porque required in written output — note: different works, same institution, undisputed — A1/A2 in written output; A5 porque first written use in this unit. Authored content: the open task's `requiredPoints` and `modelResponse` model primero/luego/después/al final + porque + a reason (outline L5 row; porque surfaces here as the written output requirement — same bridge flag F4 overlap as L4, see report) |
| Accepted-answer review | n/a (open-task is self-assessed, never fixed-list graded — H1). Reviewed the `rubric` criteria (meaning/organization/useful-language/repair) and the `modelResponse` naturalness instead: the model tells an original four-beat trip with a porque reason and no learner-level claim; rubric copies carry no graded language (H2 — the step labels itself for self-assessment) |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a |
| Accessibility pass | pass (structural) — rubric criteria and the on-demand model reveal are plain readable text, screen-reader traversable; required-points list and length guidance are prose; no graded-language copy around the ungraded step |
| Unresolved naturalness questions | Whether the model response's register («Primero salimos de casa muy contentos…») is B1-sized; «porque el tren de la tarde también llegó tarde» as a closing reason reads playful — worth a native check for naturalness vs contrivance |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 6. `es-b1-reclamacion-mission` (mission) — final task (claims desk) + self-compare `es-b1-reclamacion-say`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | A4: RAE/ASALE, NGB §25.5 "Discurso directo y discurso indirecto" — https://www.rae.es/gramática-básica/oraciones-subordinadas-sustantivas/discurso-directo-y-discurso-indirecto · RAE/ASALE, Glosario de términos gramaticales, s.v. "discurso indirecto" (refs. NGLE §43.9–43.10) — https://www.rae.es/gtg/discurso-indirecto · disposition: tense adaptation described, not mandated; non-backshifted sequences accepted — note: different works, same institution, undisputed. A6: Lawless Spanish Grammar, "Polite requests" + "Indirect Speech" — https://lawlessspanish.com/grammar/indirect-speech · RAE/ASALE, Glosario de términos gramaticales, s.v. "discurso indirecto" (complaint relay = reported speech + polite request) — https://www.rae.es/gtg/discurso-indirecto · disposition: register spectrum confirmed; no dispute in the literature — note: independent cross-institution pair — A4 (reported speech: me dijeron que), A6 (polite complaint frames). Authored content: mission brief and activities teach me dijeron que + non-backshifted tense (both «salía» and «salió» accepted — A4-natural sequences), quisiera reclamar / quería frames, and the register contrast quiero vs quisiera (A6) |
| Accepted-answer review | AI-assisted 2026-09-26 — mission final-response fixed answers (M5) carry fair variants: «Buenos días. Quisiera reclamar una indemnización.» with comma and «, por favor.» forms; errors teach register (quiero) and missing article (una) without contradicting accepted forms. act-3 (reported speech) accepts both «salía» and «salió» per A4. Self-compare `modelText` reviewed for naturalness; the step is labeled ungraded (H2). `allowTypo: true`; R2 checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a + disclosure — no `modelAudioId` binds on `es-b1-reclamacion-say` (the model is shown as text), so the café-pilot provenance pattern does not apply; if a future lane voices the model line, it must add a provenance record then |
| Accessibility pass | pass (structural) — self-compare copy labels the step ungraded on screen (H2); mission brief is a `text` stimulus with `translation`; all graded prompts/hints/feedback are plain readable text |
| Unresolved naturalness questions | Whether «Quisiera reclamar una indemnización por el retraso» (mission brief phrase) vs the final-response without «por el retraso» is the right level of specificity at the desk; «Me dijeron que el vuelo salía a las nueve, pero salió a la una» — naturalness of the tense switch in the report worth a native check; device-voice naturalness n/a (no audio bound) |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

---

## Unit B — `es-unit-19` "El trabajo y los estudios" (work and study plans)

### 7. `es-b1-trabajo-futuro` (discovery)
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | B1: RAE/ASALE, NGLE §23.14r (futuro) + §28.8c–e (el verbo ir, prospective value) — https://www.rae.es/gramática/sintaxis/ · F. Matte Bon, "Maneras de hablar del futuro en español…", RedEle 6 (2006), Ministerio de Educación — https://www.educacionfpydeportes.gob.es/dam/jcr:32d4e732-fdfe-4d29-96ae-c113c693bcfe/2006-redele-6-09mattebon-pdf.pdf · disposition: teach the tricolon with ir a preferred for plans in speech; register distinction noted — note: independent pair (academy grammar + journal article). B2: RAE/ASALE, DPD s.v. "porque" §1–§4 — https://www.rae.es/dpd/porque · RAE, "Español al día" — porque / por qué / por que — https://rae.es/espanol-al-dia/porque-porque-por-que-por-que-0 · corroborated by FundéuRAE, "porqué, porque, por que y por qué" — https://www.fundeu.es/recomendacion/porque-porque-por-que-y-por-que-935/ · disposition: teach the orthography rule alongside the causal use; canonical connector — points B1 (futuro vs ir a vs present), B2 (porque in plan reasons; the pack's first porque use is u18L4/L5, corrected 2026-09-26 — this lesson practises it in plan reasons). Authored content teaches the split: the notice and write steps drill ir a for decided plans, the fill step the present for a fixed date, and the recall step the future; the write/read steps carry porque + reason sentences (Voy a solicitar el puesto porque necesito más experiencia) |
| Accepted-answer review | AI-assisted 2026-09-26 — every `text`/`cloze` `answers[]` compared against the dictated plan sentences per the comprehension worklist. Variants included: ES full phrase only (natural); read step accepts the full porque reason and the bare reason clause «Porque quiere trabajar en un hospital.»; recall accepts the full dictated plan sentence. «El año que viene» kept as the only natural next-year phrase at B1 (not «el próximo año» as a dictated alternative). Accents preserved where distinguishing (año, más, después); `allowTypo: true` set on every answer; errors[] does not collide (exact-match) with any accepted form (R2 checked in-lane) |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned |
| Accessibility pass | pass (structural) — intro is an `examples` stimulus with glossed pairs; every prompt/hint/feedback is plain readable text; no ungraded/self-assessed step in this lesson (H2 n/a) |
| Unresolved naturalness questions | «El año que viene» as the sole dictated next-year phrase worth a native check (colloquial «el año que viene» vs textbook «el próximo año»); whether «Voy a solicitar el puesto porque necesito más experiencia» reads naturally at B1 in writing |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 8. `es-b1-trabajo-listen` (listening) — sustained listening `es-b1-listen-oferta`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | B1: RAE/ASALE, NGLE §23.14r (futuro) + §28.8c–e (el verbo ir, prospective value) — https://www.rae.es/gramática/sintaxis/ · F. Matte Bon, "Maneras de hablar del futuro en español…", RedEle 6 (2006), Ministerio de Educación — https://www.educacionfpydeportes.gob.es/dam/jcr:32d4e732-fdfe-4d29-96ae-c113c693bcfe/2006-redele-6-09mattebon-pdf.pdf · disposition: teach the tricolon with ir a preferred for plans in speech; register distinction noted — note: independent pair (academy grammar + journal article). B6: RAE/ASALE, DPD s.v. "estar" §3 («Estuvo de director en el instituto») y s.v. "ser" §2.1 («Su padre es médico») — counted as ONE reference (same work) · J. B. Butt & C. Benjamin, A New Reference Grammar of Modern Spanish, 6th ed., Routledge (2018), §29.2.1 (ser: equational identity, «Es médico») + §29.3.2 (estar de: «temporary employment or situation», «Está de camarero en Inglaterra») — verified live against full text · disposition: cross-institution pair (RAE/ASALE vs King's College London/Routledge); identity vs temporary occupancy confirmed by both — points B1 in speech, B6 (estar de + activity). Authored content: spoken numbers (mil ochocientos) and the conditional offer (podría empezar el lunes) carry the graded drills; turn-taking (a ver, ¿me oyes?) and B6 (estoy de becaria) appear in the notice activity, the listening passage and the glossary — B6 exposure-tagged, not the lesson's main graded target |
| Accepted-answer review | AI-assisted 2026-09-26 — gist + 2-detail recognition over the audio. Variants included on the read step: full conditional offer phrase («Podría empezar el lunes.») only; the cloze accepts the spoken number word «mil» (digits deliberately not accepted — the dictated form is the word form); write step accepts the full salary line with «de» required. `allowTypo: true`; R2 (exact-match accepted/error non-collision) checked in-lane |
| Regional variant | spans es-ES + es-MX device voices (6.1 pattern): sections 1/3 es-ES (com.apple.voice.compact.es-ES.Monica), sections 2/4 es-MX (com.apple.voice.compact.es-MX.Paulina); content is neutral-standard Spanish suitable for both regions. Recorded for review: both variants |
| Audio provenance | `docs/audio-provenance/spanish-b1-listen-oferta.json` (created 2026-09-26) — device speech via per-section `voiceId`, no media entry, `reviewPending: true`; no allowlist entry needed (no MediaItem asset) |
| Accessibility pass | pass (structural) — per-section `accessibilityLabel` with the synthesised-voice disclosure on all 4 sections, plus `accessibleSummary`; transcript-reveal behavior follows the `es-sustained-listen-llamada` pattern |
| Unresolved naturalness questions | Device-voice naturalness of the es-ES/es-MX pair for a two-party call pending a human listen; whether the turn-taking opener «A ver, ¿me oyes bien?» reads as natural phone Spanish at B1; «dos pagas extra» and «un documento de identidad» register worth a native check |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 9. `es-b1-entrevista-lectura` (discovery) — sustained reading `es-b1-text-entrevista`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | B4: RAE/ASALE, NGLE §45.1a–g "Características generales de las construcciones comparativas" — https://www.rae.es/gramática/sintaxis/características-generales-de-las-construcciones-comparativas · RAE/ASALE, NGB §13.2.1.1–3 "Los relativos que, quien, cual y cuyo" — https://www.rae.es/gramática-básica/relativos-interrogativos-y-exclamativos/descripción-de-los-relativos/los-relativos-que-quien-cual-y-cuyo · disposition: confirm the u16 pattern; que covers most relative needs in work talk — note: different works, same institution; undisputed (the two sources cover the two halves of the claim: comparatives, relatives). B2: RAE/ASALE, DPD s.v. "porque" §1–§4 — https://www.rae.es/dpd/porque · RAE, "Español al día" — porque / por qué / por que — https://rae.es/espanol-al-dia/porque-porque-por-que-por-que-0 · corroborated by FundéuRAE — https://www.fundeu.es/recomendacion/porque-porque-por-que-y-por-que-935/ · disposition: teach the orthography rule alongside the causal use; canonical connector — points B4 (comparatives/relatives in work talk), B2 (porque justification). Authored content: the notice/write/recall drills carry más… que, el más + de and the que/quien for-persons rule; the read step and the article (es-b1-text-entrevista) carry porque justifications (Prefiere la agencia porque el equipo es pequeño) |
| Accepted-answer review | AI-assisted 2026-09-26 — gist + 2-detail recognition over the article. Variants included: read step accepts the full porque reason and the bare clause («porque el equipo es pequeño y el jefe cercano»); recall accepts the full company-relative sentence and the bare relative clause. Every sustained question accepts exactly one option (deterministic set-equality grading); distractor options are factually distinct from the article. `allowTypo: true` on all answers; R2 (exact-match) checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned (sustained reading only) |
| Accessibility pass | pass (structural) — the article ships 4 sections, each with a per-section `accessibilityLabel`, plus a section-list `accessibleSummary`; article body is plain readable text with `provenance`; no ungraded step beside the sustained launch (labeled "Read the interview article below…", H2-safe) |
| Unresolved naturalness questions | Interview-article genre naturalness for B1 worth a native check: «lleva seis meses de becaria», the quoted «Para mí, lo importante es aprender», and the invented magazine/agency framing; whether «dejará la puerta abierta» reads as natural at B1 |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 10. `es-b1-decision-dialogo` (conversation) — dialogue `es-b1-dialogo-oferta`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | B3: RAE/ASALE, DPD s.v. "deber" §2a–b — https://www.rae.es/dpd/deber · FundéuRAE, "deber + infinitivo y deber de + infinitivo, diferencia" (2025-09-19) — https://www.fundeu.es/recomendacion/deber-de-infinitivo-obligacion-suposicion/ · disposition: deberías = default advice form; debes = firmer obligation — note: different works; FundéuRAE is RAE-affiliated but a separate body with its own editorial recommendations — point B3 (deberías vs debes register). Authored content: the meet/think/fill/recall drills carry deberías as soft advice and debes as the firmer error; the hosted exchange (es-b1-dialogo-oferta) reuses debería in the open turn's model (Debería pedir el plan de formación por escrito); comparatives (más… que) and porque reasons appear in the exchange and the read passage as exposure, not this lesson's graded target (B4 is graded in L3) |
| Accepted-answer review | AI-assisted 2026-09-26 — dialogue-choice option feedback reviewed for never contradicting accepted forms; in-lane graph check confirms no dead-end branch: every path reaches an explicit end state with ≥3 learner turns; the hosted exchange (es-b1-dialogo-oferta) carries a clarification node, a misunderstanding node (salary figure) with an authored recovery route, and a recovery node that routes back on with choices. Lesson text answers accept natural variants (e.g. «Este puesto paga más que el otro.») and errors teach register (debes), the accent (mas vs más) and number agreement; `allowTypo: true`; R2 (exact-match) checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned (exchange is read, not voiced) |
| Accessibility pass | pass (structural) — dialogue nodes carry the shipped line + `meaning` gloss pair, every hosted choice has a stable id, and the open turn labels itself self-assessed (rubric tick, never auto-graded) |
| Unresolved naturalness questions | Advice register (deberías softness) worth a native check: «Deberías preguntar por la formación» vs the exchange's «elige la agencia y pide el plan de formación por escrito»; whether the misunderstanding premise (friend hears mil ochocientos for paga más) is plausible in a friendly chat about two offers |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 11. `es-b1-plan-escrito` (recall) — open task written
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | B1: RAE/ASALE, NGLE §23.14r (futuro) + §28.8c–e (el verbo ir, prospective value) — https://www.rae.es/gramática/sintaxis/ · F. Matte Bon, "Maneras de hablar del futuro en español…", RedEle 6 (2006), Ministerio de Educación — https://www.educacionfpydeportes.gob.es/dam/jcr:32d4e732-fdfe-4d29-96ae-c113c693bcfe/2006-redele-6-09mattebon-pdf.pdf · disposition: teach the tricolon with ir a preferred for plans in speech; register distinction noted — note: independent pair (academy grammar + journal article). B2: RAE/ASALE, DPD s.v. "porque" §1–§4 — https://www.rae.es/dpd/porque · RAE, "Español al día" — porque / por qué / por que — https://rae.es/espanol-al-dia/porque-porque-por-que-por-que-0 · corroborated by FundéuRAE — https://www.fundeu.es/recomendacion/porque-porque-por-que-y-por-que-935/ · disposition: teach the orthography rule alongside the causal use; canonical connector — B1/B2 in connected writing. Authored content: the open task's `requiredPoints` and `modelResponse` model primero/luego/al final + ir a + the future simple + porque + a reason (el curso de fotografía / solicitaré prácticas / porque me encanta hacer retratos); the lesson drills dictate the same frames (outline L5 row; porque surfaces as the written-output requirement — same bridge flag F4 overlap as u18L5, see report) |
| Accepted-answer review | n/a (open-task is self-assessed, never fixed-list graded — H1). Reviewed the `rubric` criteria (meaning/organization/useful-language/repair), the `goal`, and the `modelResponse` naturalness instead: the model tells an original three-step plan with a porque reason and no learner-level claim; rubric copies carry no graded language (H2 — the step labels itself for self-assessment); copy-ban scan (correct/incorrect/score/graded/cefr/level) clean in all open-task fields |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a |
| Accessibility pass | pass (structural) — rubric criteria and the on-demand model reveal are plain readable text, screen-reader traversable; required-points list and length guidance are prose; no graded-language copy around the ungraded step |
| Unresolved naturalness questions | Whether the model response's register («Luego solicitaré prácticas en un estudio pequeño») is B1-sized; «porque me encanta hacer retratos» as a closing reason reads natural but is worth a native check alongside the dictated «me encanta el diseño publicitario» in the read passage (deliberately distinct strings for unseen-wording) |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 12. `es-b1-entrevista-mission` (mission) — final task (job interview) + self-compare `es-b1-entrevista-say`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | B5: RAE/ASALE, NGLE §25.5g (alternation contexts in substantive clauses) — https://www.rae.es/gramática/sintaxis/el-modo-en-las-subordinadas-sustantivas-iii-otros-contextos-de-alternancia · RAE, Libro de estilo de la lengua española, "El modo: ¿indicativo o subjuntivo?" §5.1 — https://www.rae.es/libro-estilo-lengua-española/el-modo-indicativo-o-subjuntivo · disposition: light revisit defensible; espero que is the minimal productive trigger for B1 — note: different works, same institution; undisputed. B6: RAE/ASALE, DPD s.v. "estar" §3 + s.v. "ser" §2.1 — counted as ONE reference (same work) · J. B. Butt & C. Benjamin, A New Reference Grammar of Modern Spanish, 6th ed., Routledge (2018), §29.2.1 + §29.3.2 — verified live against full text · disposition: cross-institution pair (RAE/ASALE vs King's College London/Routledge); identity vs temporary occupancy confirmed by both — points B5 (subjunctive light revisit — recognition + one dictated production: espero que el equipo sea acogedor), B6 (llevo dos años de becaria — estar de/llevar + de role). Authored content: the mission brief and act-8 dictate the subjunctive hope; act-3 drills llevar + time + de + role (B6 as temporary-role framing) |
| Accepted-answer review | AI-assisted 2026-09-26 — mission final-response fixed answers (M5) carry fair variants: «Buenos días, me llamo Lucía y soy de Zaragoza.» with comma and full-stop forms; errors teach the mood (es vs sea), the role gender (becario vs becaria), origin ser (estoy de vs soy de) and the missing reflexive (me llamo) without contradicting accepted forms. act-8 accepts the full hope sentence; the subjunctive is a dictated production target (B5 recognition + production scope decision: production limited to the dictated mission line). Self-compare `modelText` reviewed for naturalness; the step is labeled ungraded (H2). `allowTypo: true`; R2 (exact-match) checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a + disclosure — no `modelAudioId` binds on `es-b1-entrevista-say` (the model is shown as text), so the café-pilot provenance pattern does not apply; if a future lane voices the model line, it must add a provenance record then |
| Accessibility pass | pass (structural) — self-compare copy labels the step ungraded on screen (H2); mission brief is a `text` stimulus with `translation`; all graded prompts/hints/feedback are plain readable text |
| Unresolved naturalness questions | Whether «Llevo dos años de becaria en una revista» is the natural interview phrasing of the experience (vs «he trabajado dos años como becaria») worth a native check; whether `espero que el equipo sea acogedor` reads as an idiomatic B1 hope in an interview; «acogedor» register (warmly-welcoming) in a job context worth a native check |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

---

## Unit C — `es-unit-20` "Una decisión social" (a social decision)

### 13. `es-b1-preferencia-razones` (discovery)
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | C1: RAE/ASALE, DPD s.v. "gustar" (intransitive; experiencer as indirect object) — https://www.rae.es/dpd/gustar · RAE/ASALE, NGLE §35.8v (alternance, argumental indirect object vs subject) — https://www.rae.es/gramática/sintaxis/alternancias-del-complemento-indirecto-con-el-sujeto-y-el-complemento-directo · disposition: mandatory dative + agreement confirmed — note: different works, same institution, undisputed. C2: RAE/ASALE, DPD s.v. "porque" §1, §2, §4 — https://www.rae.es/dpd/porque · FundéuRAE, "«porqué», «porque», «por que» y «por qué»" — https://www.fundeu.es/recomendacion/porque-porque-por-que-y-por-que-935/ — verified live 2026-09-26 (HTTP 200) · disposition: DPD definitive; Fundéu recommendation independently corroborates each spelling case — note: C2's source 2 corrected 2026-09-26 (replaces the mis-cited NGB §10.4.2); different works; FundéuRAE is RAE-affiliated but a separate body; undisputed — points C1 (gustar-type + porque; agreement me gusta/me gustan, mandatory dative), C2 (porque/por qué/por que orthography — the pack's first porque was u18L4/L5, corrected 2026-09-26; this lesson teaches the spelling distinction). Authored content teaches both: the intro pairs and drills carry the agreement contrast (me gusta el cine / me gustan las películas, a Laura le gustan), porque + full sentence as the reason frame, and the ¿por qué? vs porque spelling distinction in the notice and write steps |
| Accepted-answer review | AI-assisted 2026-09-26 — every `text`/`cloze` `answers[]` compared against the dictated taste sentences per the comprehension worklist. Variants included: ES full phrase only (natural); read step accepts the full porque reason («Porque es lo único que aceptan los dos.») with distractor reasons teaching the fact-difference rather than rejecting a form; recall accepts the full dictated taste sentence. Accents preserved where distinguishing (más, está, exposición, ¿por qué?); the think error «por qué» (spaced, accented) teaches the C2 orthography and follows the pack's accent-distinguishing error pattern (cf. te/té errors in earlier units); `allowTypo: true` on every answer; errors[] does not collide with any accepted form (R2 checked in-lane, accent- and spacing-sensitive) |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned |
| Accessibility pass | pass (structural) — intro is an `examples` stimulus with glossed pairs; every prompt/hint/feedback is plain readable text; no ungraded/self-assessed step in this lesson (H2 n/a) |
| Unresolved naturalness questions | porque-clause position (after the preference clause vs sentence-final) and the naturalness of «las historias me emocionan» as a B1 taste reason worth a native check; «no se ponen de acuerdo» idiom in the read stimulus |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 14. `es-b1-fiesta-listen` (listening) — sustained listening `es-b1-listen-fiesta`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | C3: RAE/ASALE, DPD s.v. "gustar" (polite/transitive use, indirect-object experiencer) — https://www.rae.es/dpd/gustar · RAE/ASALE, NGLE §35.8v (gustar alternance; conditional derivable from the pattern) — https://www.rae.es/gramática/sintaxis/alternancias-del-complemento-indirecto-con-el-sujeto-y-el-complemento-directo · disposition: the invitation forms themselves are standard — **honest gap carried from the C3 source note**: no standalone DPD usage entry exists for *apetecer*, and the register/frequency ordering of the accept/decline set (¿te gustaría…? / ¿te apetece…? / claro que sí / lo siento, no puedo) is pedagogical-textbook convention, not a disputed linguistic claim — the note is carried, not papered over — flag: straightforward (forms); register ranking = pedagogical convention, recorded as such — note: different works, same institution. C5: RAE/ASALE, NGLE §28.8 «El verbo ir» (ir a prospective value for plans) — https://www.rae.es/gramática/sintaxis/ · RAE/ASALE, DPD s.v. "quedar" §1c («Cuando significa 'acordar'… con un complemento encabezado por *en*: *Quedamos en que…*») — https://www.rae.es/dpd/quedar · RAE/ASALE, DPD s.v. "parecer" §2 (with indirect object, parecer denotes opinion) — https://www.rae.es/dpd/parecer · disposition: one source per frame; two distinct works (NGLE grammar + DPD usage dictionary); the earlier "DPD + DPD" same-work note is resolved by the NGLE source covering frame 1 — note: C5 restructured 2026-09-26; same institution, different works; undisputed — points C3 (invitation frames in speech), C5 (planning frames). Authored content: the call and drills carry ¿te apetece…?, claro que sí, lo siento/no puedo exposure, vamos a celebrarlo, quedamos en + place and porque reasons; the graded drills target the fiesta frames (accept frame, quedamos en, celebramos, the porque reason in the pizzeria sentence) |
| Accepted-answer review | AI-assisted 2026-09-26 — gist + 2-detail recognition over the audio. Variants included on the read step: full meeting phrase («Quedan a las ocho en la plaza.») only; the cloze accepts the dictated spoken form celebramos (nosotros); write step accepts the full decided-plan sentence with its porque reason; recall accepts the full meeting frame. Digits deliberately not accepted where the dictated form is the word form (diez euros). `allowTypo: true`; R2 (accent- and spacing-sensitive exact-match) checked in-lane |
| Regional variant | spans es-ES + es-MX device voices (6.1 pattern): sections 1/3 es-ES (com.apple.voice.compact.es-ES.Monica), sections 2/4 es-MX (com.apple.voice.compact.es-MX.Paulina); content is neutral-standard Spanish suitable for both regions. Recorded for review: both variants |
| Audio provenance | `docs/audio-provenance/spanish-b1-listen-fiesta.json` (created 2026-09-26) — device speech via per-section `voiceId`, no media entry, `reviewPending: true`; no allowlist entry needed (no MediaItem asset) |
| Accessibility pass | pass (structural) — per-section `accessibilityLabel` with the synthesised-voice disclosure on all 4 sections, plus `accessibleSummary`; transcript-reveal behavior follows the `es-sustained-listen-llamada` pattern |
| Unresolved naturalness questions | Device-voice naturalness of the es-ES/es-MX pair for a two-party planning call pending a human listen; whether «¿Ponemos algo para el regalo?» reads as natural phone Spanish at B1; «Diez euros está bien» register worth a native check |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 15. `es-b1-celebracion-lectura` (discovery) — sustained reading `es-b1-text-aniversario`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | C4: RAE/ASALE, NGLE §46.1d/h (*por* denotes cause; *para* introduces beneficiary/finality) + §46.10n–ñ (causal vs final locutions) — https://www.rae.es/gramática/sintaxis/introducci%C3%B3n-caracter%C3%ADsticas-generales-de-estas-construcciones · RAE, DLE s.v. *para* §1 — «Denota el fin o término a que se encamina una acción» — https://dle.rae.es/para — **verified live 2026-09-26 (HTTP 200)** · disposition: purpose (DLE sense 1) vs cause (NGLE §46.1d) supported by a dictionary entry and a grammar treatise — note: C4's source 2 completed 2026-09-26 (the earlier NOT FOUND for DPD *para* stands: the DPD has no stable standalone entry for the preposition); same institution, different works; undisputed. C3: RAE/ASALE, DPD s.v. "gustar" — https://www.rae.es/dpd/gustar · RAE/ASALE, NGLE §35.8v — https://www.rae.es/gramática/sintaxis/alternancias-del-complemento-indirecto-con-el-sujeto-y-el-complemento-directo · disposition: the conditional invitation ¿te gustaría…? is a standard dative-invitation form (register ranking per the C3 caveat — pedagogical convention, see row 14 note) — note: different works, same institution; straightforward (forms) — points C4 (para + inf purpose vs por + cause in organizing), C3 (conditional invitation). Authored content: the thread and drills carry ¿te gustaría organizar una cena?, para regalar / para celebrar (purpose), por su aniversario (occasion) and porque reasons; the read step teaches the group's porque reason for the home dinner |
| Accepted-answer review | AI-assisted 2026-09-26 — gist + 2-detail recognition over the thread. Variants included: read step accepts the full porque reason («Porque la pareja prefiere la tranquilidad de casa.») and the bare reason clause; recall accepts the bare purpose phrase («Flores para regalar.»). Every sustained question accepts exactly one option (deterministic set-equality grading); distractor options are factually distinct from the thread. `allowTypo: true` on all answers; R2 (exact-match) checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned (sustained reading only) |
| Accessibility pass | pass (structural) — the thread ships 4 sections, each with a per-section `accessibilityLabel`, plus a section-list `accessibleSummary`; thread body is plain readable text with `provenance`; no ungraded step beside the sustained launch (labeled "Read the message thread below…", H2-safe) |
| Unresolved naturalness questions | Message-thread genre naturalness for B1 worth a native check: «¡Buenas noticias! Mis padres cumplen 25 años de boda», «¿qué os parece un libro de fotografías?», and whether the invented family details (paella, postre) read naturally; chat-register vs written-register balance |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 16. `es-b1-plan-dialogo` (conversation) — dialogue `es-b1-dialogo-fiesta`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | C5: RAE/ASALE, NGLE §28.8 «El verbo ir» (ir a prospective value) — https://www.rae.es/gramática/sintaxis/ · RAE/ASALE, DPD s.v. "quedar" §1c — https://www.rae.es/dpd/quedar · RAE/ASALE, DPD s.v. "parecer" §2 — https://www.rae.es/dpd/parecer · disposition: one source per frame; NGLE + DPD as two distinct works (C5 restructured 2026-09-26 — see row 14 note) — note: same institution, different works; undisputed. C3: RAE/ASALE, DPD s.v. "gustar" — https://www.rae.es/dpd/gustar · RAE/ASALE, NGLE §35.8v — https://www.rae.es/gramática/sintaxis/alternancias-del-complemento-indirecto-con-el-sujeto-y-el-complemento-directo · disposition: the accept/decline forms (claro que sí, lo siento, no puedo) are standard; register ordering per the C3 honest-gap caveat (pedagogical convention, see row 14 note) — flag: straightforward (forms) — points C5 (vamos a / quedamos en / ¿qué te parece?), C3 (accept/decline formulas). Authored content: the drills carry the three frames (¿qué te parece si…?, quedamos en la plaza a las ocho, lo siento no puedo venir el sábado, voy a proponer); the hosted exchange (es-b1-dialogo-fiesta) reuses the frames in repair — a clarification node (clarify-day), a misunderstanding node (day heard wrong) with an authored recovery route (recover-day), a recovery node that routes back on with choices, and an open turn using quedamos en / vamos a |
| Accepted-answer review | AI-assisted 2026-09-26 — dialogue-choice option feedback reviewed for never contradicting accepted forms; in-lane graph check confirms no dead-end branch: every path reaches an explicit end state with ≥3 learner turns; the hosted exchange (es-b1-dialogo-fiesta) carries a clarification node, a misunderstanding node with an authored recovery route, and a recovery node that routes back on with choices (pattern of `es-b1-dialogo-oferta`). Lesson text answers accept natural variants (e.g. «Quedamos en tu casa a las nueve.») and errors teach the missing en and the hour article (a las nueve); `allowTypo: true`; R2 (exact-match) checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a — no audio planned (exchange is read, not voiced) |
| Accessibility pass | pass (structural) — dialogue nodes carry the shipped line + `meaning` gloss pair, every hosted choice has a stable id, and the open turn labels itself self-assessed (rubric tick, never auto-graded) |
| Unresolved naturalness questions | Repair-turn phrasing worth a native check: «¡Anda, yo pensaba que era el domingo!» and «Te lo aclaro»; whether the misunderstanding premise (friend hears domingo for sábado) is plausible in a friendly plan |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 17. `es-b1-decision-escrito` (recall) — open task written
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | C1: RAE/ASALE, DPD s.v. "gustar" — https://www.rae.es/dpd/gustar · RAE/ASALE, NGLE §35.8v — https://www.rae.es/gramática/sintaxis/alternancias-del-complemento-indirecto-con-el-sujeto-y-el-complemento-directo · disposition: mandatory dative + agreement confirmed — note: different works, same institution, undisputed. C2: RAE/ASALE, DPD s.v. "porque" §1, §2, §4 — https://www.rae.es/dpd/porque · FundéuRAE, "porqué, porque, por que y por qué" — https://www.fundeu.es/recomendacion/porque-porque-por-que-y-por-que-935/ · disposition: orthography rule canonical (C2's source 2 corrected 2026-09-26 — see row 13 note) — points C1/C2 in written output, C3 revisit (accept/decline in writing; register ranking per the C3 caveat — pedagogical convention, row 14 note). Authored content: the open task's `requiredPoints` and `modelResponse` model prefiero + porque + quedamos en over a park celebration; the drills dictate the orthography (porque one word no accent; por qué the question) and the dative agreement (me gustaría). porque surfaces as the written-output requirement — same bridge flag F4 overlap as u18L5/u19L5, see report |
| Accepted-answer review | n/a (open-task is self-assessed, never fixed-list graded — H1). Reviewed the `rubric` criteria (meaning/organization/useful-language/repair), the `goal`, and the `modelResponse` naturalness instead: the model justifies a social choice with a porque reason and no learner-level claim; rubric copies carry no graded language (H2 — the step labels itself for self-assessment); copy-ban scan (correct/incorrect/score/graded/cefr/level) clean in all open-task fields |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a |
| Accessibility pass | pass (structural) — rubric criteria and the on-demand model reveal are plain readable text, screen-reader traversable; required-points list and length guidance are prose; no graded-language copy around the ungraded step |
| Unresolved naturalness questions | Whether the model response's register («Prefiero el parque porque es tranquilo y cabemos todos») is B1-sized; «Quedamos en la fuente a las seis» as a written meeting frame worth a native check; the model's porque clause is deliberately distinct from the read passage's (unseen-wording) |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

### 18. `es-b1-regalo-mission` (mission) — final task (group gift) + self-compare `es-b1-regalo-say`
| Field | Value |
|---|---|
| Grammar/usage checks (ref 1 · ref 2 · disposition) | C4: RAE/ASALE, NGLE §46.1d/h + §46.10n–ñ — https://www.rae.es/gramática/sintaxis/introducci%C3%B3n-caracter%C3%ADsticas-generales-de-estas-construcciones · RAE, DLE s.v. *para* §1 — https://dle.rae.es/para — verified live 2026-09-26 (C4's source 2 completed; see row 15 note) · disposition: purpose (DLE) vs cause (NGLE) supported. C6: RAE/ASALE, NGLE §16.11 "Secuencias de pronombres átonos" (conditions A–E) — https://www.rae.es/gramática/sintaxis/secuencias-de-pronombres-átonos · RAE/ASALE, NGB §10.4.2 "Grupos de pronombres átonos" — https://www.rae.es/gramática-básica/el-pronombre-personal/colocación-de-los-pronombres-átonos/grupos-de-pronombres-átonos · corroboration (third): RAE/ASALE, DPD s.v. "Pronombres personales átonos" §4 (order table; rejects *me se) — https://www.rae.es/dpd/pronombres%20personales%20átonos · disposition: three distinct works confirm the identical rule; no dispute in the literature — note: same institution, three works; undisputed — points C4 (por/para in purpose/cause), C6 (clitic combo scope: production limited to the dictated mission line `Se lo compro esta tarde.`; te lo appears in the self-compare model as exposure only — outline C6 production-scope decision recorded). Authored content: the mission brief and act-3/-8 dictate the se lo production (le lo → se lo error), act-4 drills the occasion por, act-6 the aim para, act-5 the per-person price (diez euros — u10 market numbers revisited) |
| Accepted-answer review | AI-assisted 2026-09-26 — mission final-response fixed answers (M5) carry fair variants: «Se lo compro esta tarde.» with errors teaching le lo → se lo (incorrect answer), te lo (wrong dative), and esta tarde (wrong gender); act-8 accepts the same dictated errand line with the se-rule errors. Self-compare `modelText` reviewed for naturalness; the step is labeled ungraded (H2). `allowTypo: true`; R2 (accent- and spacing-sensitive exact-match) checked in-lane |
| Regional variant | es-ES (content Castilian-aligned; no voiced material) |
| Audio provenance | n/a + disclosure — no `modelAudioId` binds on `es-b1-regalo-say` (the model is shown as text), so the café-pilot provenance pattern does not apply; if a future lane voices the model line, it must add a provenance record then |
| Accessibility pass | pass (structural) — self-compare copy labels the step ungraded on screen (H2); mission brief is a `text` stimulus with `translation`; all graded prompts/hints/feedback are plain readable text |
| Unresolved naturalness questions | Whether «Se lo compro esta tarde en la tienda» is the natural B1 errand line (vs «lo compro en la tienda»); «Ponemos diez euros cada uno» as group-chat register worth a native check; whether se lo production at B1 is the right light-touch scope (outline C6 production-scope decision) |
| reviewMethod / modelOrTool / date / disposition | AI-assisted / deepseek-v4-flash (authoring lane, 2026-09-26) / 2026-09-26 / unreviewed |
| Native review | pending |
| Developer sign-off | (empty) |

---

## Follow-up lanes (what fills this ledger)

- **Research lane** → grammar/usage reference 1 + reference 2 + disposition for
  the 17 grammar points of the outline §6 (NGLE/DPD/Fundéu class; two
  independent authored references; AI agreement never counts).
- **Authoring lane** → audio provenance records for the 3 SL pieces (+ any
  bound model audio), per `spanish-cafe-listen-pilot.json` pattern.
- **Review/editorial lane** → accepted-answer review (R1/H1 discipline),
  accessibility pass, unresolved naturalness questions, variant recording
  (es-ES; es-MX where SL voices span).
- **Human lanes** → `external-human` native review (clears `native review:
  pending`) and the developer sign-off (iPhone walkthrough, outline §8 item 5)
  with date + initials. Rows stay `disposition: unreviewed` until then —
  unreviewed is the initial state of every seeded record (native-review-kit).