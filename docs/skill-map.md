# Skill map (P1.3)

Scope of this document: **every unit of all five packs** (`Condisco/Content/packs/*.json`, as of 2026-09-26 working tree): French 13 units / 50 lessons, Italian 13 units / 49 lessons, German 17 units / 52 lessons, Portuguese 17 units / 52 lessons, Spanish 17 units / 52 lessons — **77 units, 255 lessons** (40 missions, 36 stories, verified by counting `lessons[]` per pack and per unit). P1.1/P1.3 context: `docs/roadmaps/2026-09-25-condisco-quality-and-growth.md`. Nothing here claims coverage it does not map: level labels describe what the mapped lessons actually do, and gaps are backlog, not promises.

## Legend

- **Real-world act** — what the learner should be able to manage after the unit. Where the unit's lessons do not reach the unit `objective`, the act is marked **partial** and the missing part is named.
- **Evidence** — where the ability is demonstrated: reading = text/dialogue stimuli (stories, mission transcripts, example pairs, prompt text); listening = audio stimuli (`media`-backed steps); speaking = `self-compare` (self-assessed production, `outcome: .selfAssessed`); writing = typed answers (`text`, `cloze`, `ordering`). A skill that is not trained in a unit is stated as **not trained here** — nothing is invented.
- **Listening caveat (pack-wide, see backlog #1):** every audio step today plays synthesized audio — either the on-device course voice for the 23 allowlisted asset ids (`tools/device-speech-media.txt`, French 5 + Italian 16 + Spanish 2 from the 2026-09-26 café listen pilot), or the bundled Listen tracks (5 files, still synthesized at author time, `reviewPending: true`, see `docs/audio-provenance/index.md`). There is **no native recording** in any pack yet; `check_packs.sh` passes on the allowlist basis (2026-09-25 baseline, extended 2026-09-26). `de` and `pt` declare **no media at all**, so listening is *not trained here* in those packs; `es` declared no media until 2026-09-26, when the café listen pilot added two device-speech assets (listening now trained only in es-unit-1).
- **Prerequisites** — declared `lesson.prerequisites` (chains are `legacy-success` on the preceding lesson) or, for entry units, the runtime "Suggested start" tag (`PlacementStore.recommendedLessonId` in the lesson browser, `Condisco/Lesson/CoursesView.swift`). Units whose lessons declare `prerequisites: []` are open-access consolidation units (the placement recommendation may point there, but nothing gates).
- **Revisit points** — the FSRS review queue: every graded activity writes a per-`evidenceKey` FSRS state (`Condisco/Store/Fsrs.swift`, FSRS v6, desired retention 0.9); due items (`dueAt <= now`, `LearningStore.swift:1397`) surface in the Review tab as a `ReviewItem` that recalls the original prompt and accepted answer (`Condisco/Review/ReviewModels.swift`). Revisit = that queue, otherwise the phrases decay. Each unit below names the evidence keys that should return.

---

## Audio inventory (2026-09-26)

Media-backed lesson steps per language, verified against `Condisco/Content/packs/*.json` and `tools/device-speech-media.txt` on 2026-09-26. "Device-speech" = an allowlisted asset id with **no file on disk**: at lesson time the on-device synthesized course voice reads the declared transcript (see `docs/audio-provenance/index.md` and `docs/audio-provenance/spanish-cafe-listen-pilot.json`).

| Pack | Device-speech assets (allowlisted) | Bundled listen clip (file on disk) | Media-backed lesson steps |
|------|-------------------------------------|-------------------------------------|---------------------------|
| French (`fr`) | 5 — `fr-identity-foundation-model`, `fr-people-foundation-model`, `fr-family-foundation-model`, `fr-numbers-foundation-model`, `fr-polite-coffee-audio` | none | 5 (model-audio steps in the four unit-1 discovery lessons; `fr-polite-coffee-audio` self-compare step in `fr-cafe-order-foundation`) |
| Italian (`it`) | 16 — `it-polite-coffee-audio` + 15 `*-foundation-model` clips | 1 — `it-market-listen-audio` (`/audio/italian-foundations/it-market-foundation-listen.mp3`, sha256 `4b62a0f6…`) | 16 model-audio steps + the 5-step listen sequence in `it-market-foundation` (gist / prosciutto / pesche / ordine / grazie, all bound to `it-market-listen-stim`) |
| German (`de`) | 0 | none | none — de declares no media at all; listening is not trained here |
| Portuguese (`pt`) | 0 | none | none — pt declares no media at all; listening is not trained here |
| Spanish (`es`) | **2 (new, 2026-09-26)** — `es-cafe-listen-audio`, `es-cafe-listen-model` | none | **1 pilot sequence (5 steps)** in `es-cafe-mission`: listen (step-10) → interpret (steps 11–13, gist + two key details) → respond (step-14 self-compare). Previously es declared **no media at all** |

Statement of record: before 2026-09-26, `de`, `pt` and `es` had **no media-backed step anywhere** — listening was *not trained here* in those packs. The Spanish café listen pilot is the first listening evidence in the Spanish pack; de and pt remain media-free. The Spanish pilot assets are not reviewed recordings: they are authored transcripts synthesized on-device (`reviewPending: true`, naturalness unverified — see `docs/audio-provenance/spanish-cafe-listen-pilot.json`).

The five standalone Listen tracks (bundled files, still synthesized at author time; `reviewPending: true` in every transcript):

| Track (lessonId) | Duration | File |
|------------------|----------|------|
| `it-market-foundation` | 663.92 s | `/audio/italian-foundations/it-market-foundation-listen.mp3` |
| `fr-identity-foundation` | 755.58 s | `/audio/french-foundations/fr-identity-listen.mp3` |
| `de-introductions-foundation` | 772.92 s | `/audio/german-foundations/de-introductions-foundation-listen.mp3` |
| `pt-introductions-foundation` | 785.17 s | `/audio/portuguese-foundations/pt-introductions-foundation-listen.mp3` |
| `es-introductions-foundation` | 795.60 s | `/audio/spanish-foundations/es-introductions-foundation-listen.mp3` |

Durations are the declared `durationS` values in `Condisco/Content/listen-tracks/*.json` (verified by `tools/check_packs.sh` against the real files). These five tracks are standalone Listen-list content, not lesson steps; the Spanish track is **not** wired into any lesson (the 2026-09-26 pilot deliberately does not reuse it).

---

## Per-unit evidence matrix (2026-09-26)

Dated machine-derived evidence matrix for every unit of all five packs, extracted from the actual pack JSONs (`Condisco/Content/packs/*.json`) on 2026-09-26. One table per language, unit rows. Every mark is a **claim about what an activity actually does**, not what it is tagged with. The per-unit prose sections below remain the canonical walkthrough; this matrix is the scannable evidence layer and takes precedence where the prose disagrees (two stale lines were corrected on this date — the French pack version and the review-log claim in "Description claims vs mapped coverage").

**Legend (modality → activity evidence that actually exercises it)**

- **R = reading** — at least one text-bearing step in the unit: story/mission transcript, example pairs, an `information` read body, or prompt text.
- **L = listening** — at least one audio-backed step: a stimulus with `mediaId` (kind `audio`), or a `modelAudioId` reference. Device-speech steps count here — the allowlisted on-device course voice reads the transcript at lesson time (see Audio inventory 2026-09-26 and backlog #1). German/Portuguese/Spanish lessons have **no in-lesson listening**; that is a real `—`.
- **SP = spoken production** — at least one `self-compare` activity (`outcome: .selfAssessed`). A `speaking` *skill tag* on a choice/text/dialogue-choice step is **not** speaking evidence (plan rule, 2026-09-26); the Spanish pilot's `es-cafe-listen-say` is the only production step outside Italian.
- **WP = written production** — at least one `text`/`cloze`/`ordering` activity (constrained production; dictated answers only — see rubric H1).
- **I = interaction** — at least one `dialogue-choice` activity (multi-turn exchange, receptive choice). Missions that lack a dialogue-choice step show `—`: their steps rehearse your side of the exchange, not the exchange itself.
- ✓ = the unit contains an exercising activity type; **—** = not trained in any lesson of the unit.
- **Ⓛ = standalone Listen track** (`Condisco/Content/listen-tracks/*.json`): separate bundled-audio content, **not** lesson steps, and **not** unit L evidence. Listed once per language below its table for completeness.

**Footnotes:** ‡1 the unit objective names "descriptions", but that content lives in the preceding home/descriptions unit — not this one. ‡2 "Getting around" unit has **1 lesson**: prices and quantities in errands are promised in the objective but not practiced. ‡3 "follow **spoken** directions" requires listening; the unit only traces directions on paper/text. ‡4 "where you live" is not trained here (it arrives in a later unit). † Italian unit array order: `it-unit-9` renders last in the browser (see its section note).

### French

| Unit | Lessons | Target task (`unit.objective`, trimmed) | Prereq chain | Vocab/grammar focus | R | L | SP | WP | I |
|------|--------:|------------------------------------------|--------------|----------------------|---|---|---|---|---|
| fr-unit-1 | 5 | Order a coffee; introduce yourself and your family | Entry — mission is Suggested start | Greetings, être/avoir, numbers, café order | ✓ | ✓ | — | ✓ | — |
| fr-unit-2 | 4 | Describe your home and daily routine | u1 chain (fr-home ← fr-numbers-foundation) | House vocab, adjectives, plurals, routine | ✓ | — | — | ✓ | — |
| fr-unit-3 | 4 | Questions, descriptions and requests ‡1 | u2 chain | Negation, question words, market, possessives | ✓ | — | — | ✓ | — |
| fr-unit-4 | 4 | Destinations, past actions, plans | u3 chain | Transport, pouvoir, passé composé, futur proche | ✓ | — | — | ✓ | ✓ |
| fr-unit-5 | 4 | Days, time, weather, market prices | fr-days → u1 numbers, then chain | Days, time, weather, prices | ✓ | — | — | ✓ | ✓ |
| fr-unit-6 | 5 | Aches, pharmacy, emergencies, invitations | u5 chain | Health, pharmacy, emergency, invitations, café order | ✓ | ✓ | — | ✓ | ✓ |
| fr-unit-7 | 3 | Consolidation — build, decide, remember | Open-access (none declared) | Café build, picnic mission, first-steps recall | ✓ | — | — | ✓ | — |
| fr-unit-8 | 3 | Missions — navigate Paris, pharmacy, home build | Open-access (none declared) | Paris mission, pharmacy mission, agreement | ✓ | — | — | ✓ | — |
| fr-unit-9 | 4 | Passé composé and imparfait, chosen and told | u8 chain | Passé composé, imparfait, tense choice, day narrative | ✓ | — | — | ✓ | — |
| fr-unit-10 | 3 | Futur simple: promises, predictions, projects | u9 chain | Futur simple endings, aller + infinitif | ✓ | — | — | ✓ | — |
| fr-unit-11 | 3 | Conditional politeness, wishes, si + imparfait | u10 chain | Conditionnel, souhaits, si-clauses | ✓ | — | — | ✓ | — |
| fr-unit-12 | 4 | y/en, relatives, comparatives, superlatives | u11 chain | y/en, qui/que/où, plus/moins, superlatifs | ✓ | — | — | ✓ | — |
| fr-unit-13 | 4 | Subjunctive intro, work vocab, hotel, A1 review | u12 chain | Subjonctif (il faut que), travail, hôtel, rappel A1 | ✓ | — | — | ✓ | — |

Counts (13 units, 50 lessons): **R 13 · L 2 · SP 0 · WP 13 · I 3**. Notable absences: **no spoken production anywhere in French** (no `self-compare` anywhere in the pack; the recognition-only `speaking` tags on fr-cafe-mission/fr-a2-hotel-mission steps were removed in the 2026-09-26 outcomes repair — `audit_outcomes.py` now exits 0); listening only in unit 1 (four model audio steps) and unit 6 (one café-order model audio step). Standalone Ⓛ `fr-identity-foundation`.

### Italian

| Unit | Lessons | Target task (`unit.objective`, trimmed) | Prereq chain | Vocab/grammar focus | R | L | SP | WP | I |
|------|--------:|------------------------------------------|--------------|----------------------|---|---|---|---|---|
| it-unit-1 | 5 | Order a caffè; introduce yourself and your family | Entry — mission is Suggested start | Names, essere, avere, numbers | ✓ | ✓ | ✓ | ✓ | — |
| it-unit-2 | 4 | Describe your home and daily routine | u1 chain (it-home ← it-numbers-foundation) | Home, articles, colors, plurals | ✓ | ✓ | ✓ | ✓ | — |
| it-unit-3 | 4 | Questions, descriptions and requests ‡1 | u2 chain | Negation, prendere, possessives, transport | ✓ | ✓ | ✓ | ✓ | — |
| it-unit-4 | 4 | Destinations, past actions, plans | u3 chain | Modals, polite requests, past, future plans | ✓ | ✓ | ✓ | ✓ | ✓ |
| it-unit-5 | 4 | Days, time, weather, market prices | it-days → u1 numbers, then chain | Days, time, weather, market (incl. price-list listen) | ✓ | ✓ | ✓ | ✓ | — |
| it-unit-6 | 5 | Aches, pharmacy, emergencies, invitations | u5 chain | Health, pharmacy, emergency, invitations, café order | ✓ | ✓ | ✓ | ✓ | ✓ |
| it-unit-7 | 3 | Consolidation — build, decide, remember | Open-access (none declared) | Café build, market run, early-words recall | ✓ | — | — | ✓ | — |
| it-unit-8 | 3 | Missions — dinner, directions, bar build | Open-access (none declared) | Pizzeria dinner, directions, bar orders | ✓ | — | — | ✓ | — |
| it-unit-10 | 3 | Futuro semplice: promises, predictions, plans | u9 chain (← it-a2-passato-imperfetto) | Futuro endings, promesse, progetti | ✓ | — | — | ✓ | — |
| it-unit-11 | 3 | Conditional wishes and polite requests | u10 chain | Condizionale, vorrei/potrebbe | ✓ | — | — | ✓ | ✓ |
| it-unit-12 | 4 | Link ideas: congiuntivo, ne/ci, relatives, gerundio | u11 chain | Congiuntivo, ne/ci, che/cui, stare+gerundio | ✓ | — | — | ✓ | — |
| it-unit-13 | 3 | Comparatives, work, hotel stay | u12 chain | Comparativi, lavoro, albergo | ✓ | — | — | ✓ | — |
| it-unit-9 † | 4 | Il passato: passato prossimo, imperfetto, choice | From u8 (← it-food-construction; array-last) | Passato prossimo (avere/essere), imperfetto, choice | ✓ | — | — | ✓ | — |

Counts (13 units, 49 lessons, array order 1–8, 10–13, 9): **R 13 · L 6 · SP 6 · WP 13 · I 3**. Notable absences: the whole A2 block (units 9–13) has no listening and no self-compare — the pack's listening and spoken production live entirely in units 1–6. Standalone Ⓛ `it-market-foundation` (the only shipped audio file, still `reviewPending: true`).

### German

| Unit | Lessons | Target task (`unit.objective`, trimmed) | Prereq chain | Vocab/grammar focus | R | L | SP | WP | I |
|------|--------:|------------------------------------------|--------------|----------------------|---|---|---|---|---|
| de-unit-1 | 3 | Introduce yourself; order a drink politely | Entry — mission is Suggested start | heißen, verb-fronted questions, accusative einen | ✓ | — | — | ✓ | — |
| de-unit-2 | 1 | Prices and quantities in errands ‡2 | u1 | Numbers 1–10, reversed number words | ✓ | — | — | ✓ | — |
| de-unit-3 | 2 | Ask where things are; follow directions ‡3 | u2 | Directions story, haggling at the flea market | ✓ | — | — | ✓ | ✓ |
| de-unit-4 | 2 | Days, times, the people around you | u3 | Weekdays, time, family introductions | ✓ | — | — | ✓ | ✓ |
| de-unit-5 | 2 | Weather and free time ‡4 | u4 | Weather, free-time talk | ✓ | — | — | ✓ | — |
| de-unit-6 | 3 | Consolidation — build, decide, remember | Open-access (none declared) | Café requests build, market run, recall | ✓ | — | — | ✓ | — |
| de-unit-7 | 3 | Missions — train, family dinner, week build | Open-access (none declared) | Ticket/platform, dinner small talk, weekly routine | ✓ | — | — | ✓ | — |
| de-unit-8 | 4 | Home and your day | u5 | der/die/das, invariable adjectives, plurals, routine | ✓ | — | — | ✓ | — |
| de-unit-9 | 4 | Everyday exchanges: no, questions, food, mine/yours | u8 | kein/nicht, question words, food, possessives | ✓ | — | — | ✓ | ✓ |
| de-unit-10 | 4 | Move around, ask politely, past and plans | u9 | Night-train story, Perfekt, plans | ✓ | — | — | ✓ | — |
| de-unit-11 | 3 | Time words and the market | u10 | Months/dates, time-telling, market mission | ✓ | — | — | ✓ | — |
| de-unit-12 | 4 | Health and social life | u11 | Doctor, pharmacy, emergency, invitations | ✓ | — | — | ✓ | ✓ |
| de-unit-13 | 4 | Perfekt and the storyteller's Präteritum | u12 | haben/sein, irregular participles, modals, weekend | ✓ | — | — | ✓ | — |
| de-unit-14 | 3 | Futur I: plans and guesses | u13 | werden + infinitive, wird wohl, resolutions | ✓ | — | — | ✓ | — |
| de-unit-15 | 3 | würde, polite requests, unreal wishes | u14 | Konjunktiv II, hotel front desk, wäre/hätte | ✓ | — | — | ✓ | ✓ |
| de-unit-16 | 4 | Connect ideas: relatives, comparisons, wo/wohin | u15 | Relativsätze, -er/als, am besten, case choice | ✓ | — | — | ✓ | — |
| de-unit-17 | 3 | Work talk: passive, job vocab, interview | u16 | Passiv mit werden, Beruf/Bewerbung | ✓ | — | — | ✓ | — |

Counts (17 units, 52 lessons): **R 17 · L 0 · SP 0 · WP 17 · I 5**. Notable absences: **no in-lesson listening at all** (de declares no media) and **no spoken production** (no `self-compare` anywhere; the recognition-only `speaking` tags on the choice/text/dialogue-choice steps of ten lessons — mission and `conversation` family, the pack with the most unbacked speaking claims — were removed in the 2026-09-26 outcomes repair; `audit_outcomes.py` now exits 0). Standalone Ⓛ `de-introductions-foundation`.

### Portuguese

| Unit | Lessons | Target task (`unit.objective`, trimmed) | Prereq chain | Vocab/grammar focus | R | L | SP | WP | I |
|------|--------:|------------------------------------------|--------------|----------------------|---|---|---|---|---|
| pt-unit-1 | 3 | Order a coffee; introduce yourself (European PT) | Entry — mission is Suggested start | gostaria de, é vs e accents, introductions | ✓ | — | — | ✓ | — |
| pt-unit-2 | 1 | Prices and quantities in errands ‡2 | u1 | Numbers 1–10, dois/duas agreement | ✓ | — | — | ✓ | — |
| pt-unit-3 | 2 | Ask where things are; follow directions ‡3 | u2 | ficar for location, price frame | ✓ | — | — | ✓ | ✓ |
| pt-unit-4 | 2 | Days, times, the people around you | u3 | Week from domingo, hyphenated days, relatives | ✓ | — | — | ✓ | ✓ |
| pt-unit-5 | 3 | Consolidation — build, decide, remember | Open-access (none declared) | Café order build, market mission, look-back | ✓ | — | — | ✓ | — |
| pt-unit-6 | 3 | Missions — station, hotel, family build | Open-access (none declared) | Directions, check-in, family sentences | ✓ | — | — | ✓ | — |
| pt-unit-7 | 4 | Home and your day | u4 | em+article fusions, agreement, plurals, routine | ✓ | — | — | ✓ | — |
| pt-unit-8 | 4 | Everyday exchanges: no, questions, food, mine/yours | u7 | não, question words, food, possessives | ✓ | — | — | ✓ | — |
| pt-unit-9 | 4 | Move around, ask politely, past and plans | u8 | ir, Pode…/Gostaria de…, pretérito, plans | ✓ | — | — | ✓ | ✓ |
| pt-unit-10 | 4 | Time words, weather, the market | u9 | Weather frames, time, months/dates, quantities | ✓ | — | — | ✓ | — |
| pt-unit-11 | 1 | Free time and hobbies (thinnest unit) | u10 | Gosto de…, hobbies | ✓ | — | — | ✓ | — |
| pt-unit-12 | 4 | Health and social life | u11 | Dói-me, pharmacy, emergencies, invitations | ✓ | — | — | ✓ | ✓ |
| pt-unit-13 | 4 | Pretérito perfeito and imperfeito | u12 | Perfeito, imperfeito, choice, weekend narrative | ✓ | — | — | ✓ | — |
| pt-unit-14 | 3 | Future: ir + infinitivo, futuro simples | u13 | vou fazer, falarei, intentions | ✓ | — | — | ✓ | — |
| pt-unit-15 | 3 | Desejos: condicional, gostaria/queria, conjuntivo | u14 | Condicional, queria um café, quero que… | ✓ | — | — | ✓ | ✓ |
| pt-unit-16 | 4 | Link ideas: relatives, comparisons, pronoun forms | u15 | que/quem/onde, mais/menos, lhe/lhes, comigo | ✓ | — | — | ✓ | — |
| pt-unit-17 | 3 | Superlatives, hotel check-in, A1 review | u16 | -íssimo, check-in mission, revisão A1 | ✓ | — | — | ✓ | — |

Counts (17 units, 52 lessons): **R 17 · L 0 · SP 0 · WP 17 · I 5**. Notable absences: **no in-lesson listening** (pt declares no media) and **no spoken production** (no `self-compare` anywhere; the recognition-only `speaking` tags on pt-cafe-mission/pt-station-mission/pt-hotel-mission steps were removed in the 2026-09-26 outcomes repair — `audit_outcomes.py` now exits 0). Standalone Ⓛ `pt-introductions-foundation`.

### Spanish

| Unit | Lessons | Target task (`unit.objective`, trimmed) | Prereq chain | Vocab/grammar focus | R | L | SP | WP | I |
|------|--------:|------------------------------------------|--------------|----------------------|---|---|---|---|---|
| es-unit-1 | 3 | Introduce yourself; order a drink; first café listen | Entry — mission is Suggested start | llamarse, quisiera, accents (café/té) | ✓ | ✓ | ✓ | ✓ | — |
| es-unit-2 | 1 | Prices and quantities in errands ‡2 | u1 | Numbers 1–10, welded number words (veintiuno) | ✓ | — | — | ✓ | — |
| es-unit-3 | 2 | Ask where things are; follow directions ‡3 | u2 | dónde/donde accent, costar agreement | ✓ | — | — | ✓ | ✓ |
| es-unit-4 | 2 | Days, times, the people around you | u3 | Weekdays, mi/mis, siblings | ✓ | — | — | ✓ | ✓ |
| es-unit-5 | 3 | Consolidation — build, decide, remember | Open-access (none declared) | Polite-request build, find-café mission, recall | ✓ | — | — | ✓ | — |
| es-unit-6 | 3 | Missions — museum, party, family build | Open-access (none declared) | Directions/ticket, birthday party, family sentences | ✓ | — | — | ✓ | — |
| es-unit-7 | 4 | Home and your day | u4 | el/la/los/las, ser + adjective, plurals, routine | ✓ | — | — | ✓ | — |
| es-unit-8 | 4 | Everyday exchanges: no, questions, food, mine/yours | u7 | no/nunca/nada, question accents, food, mi/tu/su | ✓ | — | — | ✓ | ✓ |
| es-unit-9 | 4 | Move around, ask politely, past and plans | u8 | ir, poder/querría, pretérito first look, ir a | ✓ | — | — | ✓ | ✓ |
| es-unit-10 | 4 | Time words, weather, the market | u9 | hace sol/frío, time (es/son), dates, quantities | ✓ | — | — | ✓ | — |
| es-unit-11 | 1 | Free time and hobbies (thinnest unit) | u10 | me gusta/me encanta + infinitive | ✓ | — | — | ✓ | — |
| es-unit-12 | 4 | Health and social life | u11 | Body parts, Me duele, pharmacy, emergencias, invitations | ✓ | — | — | ✓ | ✓ |
| es-unit-13 | 4 | Pretérito e imperfecto, chosen and told | u12 | Pretérito endings/irregulars, imperfecto, choice, fin de semana | ✓ | — | — | ✓ | — |
| es-unit-14 | 3 | Future: formation, uses, plans | u13 | Future endings (rebel stems), promises, ir a | ✓ | — | — | ✓ | — |
| es-unit-15 | 3 | Deseos y cortesía, subjunctive trigger | u14 | Condicional, me gustaría/quisiera, quiero que… | ✓ | — | — | ✓ | ✓ |
| es-unit-16 | 4 | Link ideas: relatives, comparisons, pronouns, por/para | u15 | que/quien/donde, más/menos, lo/la/le, por vs para | ✓ | — | — | ✓ | — |
| es-unit-17 | 3 | Work, superlatives, hotel mission, tech talk | u16 | -ísimo/el más, check-in mission, tecnología | ✓ | — | — | ✓ | — |

Counts (17 units, 52 lessons): **R 17 · L 1 · SP 1 · WP 17 · I 6**. Notable absences: in-lesson listening exists **only** in unit 1 (the 2026-09-26 café listen pilot: 5 steps in `es-cafe-mission`, `reviewPending: true`); every other unit has no listening and no spoken production. Interaction is the most exercised modality after reading/writing (6 units) via the `conversation`-family dialogue-choice lessons. Standalone Ⓛ `es-introductions-foundation` (not wired into any lesson).

### Cross-language totals (2026-09-26)

77 units, 255 lessons: **R 77 · L 9 · SP 7 · WP 77 · I 22** (unit-level marks). Reading and constrained written production are exercised in every unit of every pack; listening, spoken production and interaction are the scarce columns. Speaking evidence (self-compare) exists only in Italian units 1–6 and the Spanish pilot unit 1; in-lesson listening only in French units 1/6, Italian units 1–6, and the Spanish pilot unit 1; interaction only in the dialogue-choice-bearing conversation/mission units listed above. These are the numbers the 2026-09-26 audit report builds on (`docs/reviews/2026-09-26-a1a2-bridge-spanish.md`).

---

## French (`fr`, pack `fr-foundations`, v1.5.8)

### fr-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-cafe-mission` | "Mission : un café à Paris" (mission) | Order a coffee in a café; first real exchange |
| `fr-identity-foundation` | "Names and introductions" (discovery) | I-am forms, masculine/feminine, introducing |
| `fr-people-foundation` | "People and être" (discovery) | People vocabulary + être in an exchange |
| `fr-family-foundation` | "Family and avoir" (discovery) | Family vocabulary + avoir in an exchange |
| `fr-numbers-foundation` | "Numbers and age" (discovery) | Numbers, stating age |

- Real-world act: walk into a café and order; introduce yourself, your name, your age, and your family.
- Evidence: **reading** – mission transcript and example pairs; **listening** – model-audio steps in the four discovery lessons play the allowlisted device speech (synthesized course voice; 4 of the 5 French allowlisted assets are here, see backlog #1); the mission has no audio step; **speaking** – not trained here (no `self-compare` in French); **writing** – typed answers in identity/people/family/numbers lessons.
- Prerequisites: entry unit; the mission is the "Suggested start".
- Revisit: café phrases and name/age replies (evidence keys from the mission and numbers lessons) return via the Review queue.

### fr-unit-2 · "Home and daily life" · objective: "Describe your surroundings and routine."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-home-foundation` | "Histoire : le chat et le livre" (story) | Read-a-story: house vocabulary, finding the cat |
| `fr-descriptions-foundation` | "Build it : décrire" (construction) | Assemble sentences; adjective agreement |
| `fr-plural-foundation` | "Build it : le pluriel" (construction) | Plural sentences with agreement |
| `fr-routine-foundation` | "Histoire : une journée d'étudiante" (story) | Follow a day, describe tomorrow's study |

- Real-world act: describe your home and daily routine; make adjectives and plurals agree.
- Evidence: **reading** – two stories with comprehension; **listening** – not trained here (no media-backed step in this unit); **speaking** – not trained here; **writing** – construction (ordering) and cloze answers.
- Prerequisites: fr-unit-1 lessons (`fr-home-foundation` requires `fr-numbers-foundation`, then each lesson requires the previous).
- Revisit: agreement/plural evidence keys are high-value Review-queue items for spelling-level recall (accent/diacritic-sensitive).

### fr-unit-3 · "Everyday communication" · objective: "Use questions, descriptions and requests."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-negation-foundation` | "Build it : la négation" (construction) | ne…pas in exactly the right slots |
| `fr-questions-foundation` | "Build it : les questions" (construction) | est-ce que, qui, où in the right slots |
| `fr-food-foundation` | "Mission : au marché" (mission) | Buy coffee and tea at the market: greet, prendre, pay |
| `fr-possession-foundation` | "Build it : mon, ma, mes" (construction) | The right possessive for the right noun |

- Real-world act: **partial** — ask questions, say no cleanly, buy drinks at the market, and claim things; the "descriptions" named in the objective are not trained in this unit (they live in unit 2).
- Evidence: **reading** – example pairs, tiles and the market mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers (negation slot choice, question word order).
- Prerequisites: fr-unit-2 chain (`fr-negation-foundation` requires `fr-routine-foundation`, then each lesson requires the previous).
- Revisit: ne…pas placement, est-ce que/qui/où order, and mon/ma/mes agreement keys via the Review queue.

### fr-unit-4 · "Going further" · objective: "Discuss destinations, past actions and plans."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-transport-foundation` | "Mission : à la gare" (mission) | Buy a ticket, find the way, board at Gare de Lyon |
| `fr-requests-foundation` | "Au comptoir : demander poliment" (conversation) | Polite counter talk with pouvoir; dialogue choices |
| `fr-past-foundation` | "Histoire : hier" (story) | Reconstruct a day using the past tense |
| `fr-plans-foundation` | "Histoire : demain" (story) | Say what each person will do tomorrow |

- Real-world act: cross town to the station and buy a ticket, hold a polite counter exchange, tell what happened yesterday and what is planned for tomorrow.
- Evidence: **reading** – mission, dialogue and story text with comprehension checks; **listening** – not trained here; **speaking** – not trained here; **writing** – typed, cloze and choice answers (pouvoir request line; past/plan forms).
- Prerequisites: fr-unit-3 chain (`fr-transport-foundation` requires `fr-possession-foundation`).
- Revisit: passé composé vs futur proche evidence keys in the two stories, plus the pouvoir request line.

### fr-unit-5 · "Time and the world around you" · objective: "Handle days, time, weather and market prices."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-days-foundation` | "Remember : numbers and days" (recall) | Count through the French week (retrieves unit 1) |
| `fr-time-foundation` | "Remember : days and time" (recall) | The week behind every hour (retrieval) |
| `fr-weather-foundation` | "Petite conversation : le temps" (conversation) | Weather small talk: agree, observe, keep the chat alive |
| `fr-market-foundation` | "Au marché : les prix" (conversation) | Ask prices, react to the total, pay like a regular |

- Real-world act: handle a week's small talk — say what day and time it is, chat about the weather, and ask market prices.
- Evidence: **reading** – dialogue choices and example pairs; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze and typed answers.
- Prerequisites: declared chain via `fr-days-foundation`, which reaches back to `fr-numbers-foundation` (unit 1) — then days → time → weather → market.
- Revisit: number and day evidence keys (cross-unit back-reference to unit 1), weather and price replies.

### fr-unit-6 · "Santé et vie sociale" · objective: "Handle aches, the pharmacy, emergencies and invitations."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-health-foundation` | "Chez le médecin" (conversation) | Say where it hurts, answer questions, take advice |
| `fr-pharmacy-foundation` | "À la pharmacie" (conversation) | Ask politely with je voudrais, choose, pay |
| `fr-emergency-foundation` | "Mission : urgence" (mission) | Call for help, request an ambulance, give details |
| `fr-invitations-foundation` | "Inviter : samedi soir" (conversation) | Invite, handle a yes, handle a no, close warmly |
| `fr-cafe-order-foundation` | "Au café : commander et payer" (conversation) | Order, ask the price, pay politely |

- Real-world act: get through a doctor visit, a pharmacy run, a late-night emergency, an invitation — and a full café order.
- Evidence: **reading** – dialogue and mission text; **listening** – only the closing café-order lesson carries a model-audio step (allowlisted device speech, synthesized; `fr-polite-coffee-audio`); **speaking** – not trained here; **writing** – typed and dialogue-choice answers.
- Prerequisites: fr-unit-5 chain (`fr-health-foundation` requires `fr-market-foundation`).
- Revisit: emergency call phrases and the café order line (`fr-cafe-order-foundation-*` evidence keys) via the Review queue.

### fr-unit-7 · "En action" · objective: "Use your French in new ways: build, decide, remember."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-cafe-build-construction` | "Build it: au café" (construction) | Assemble café sentences: order, price, pay |
| `fr-picnic-plan-mission` | "Mission: un pique-nique" (mission) | Buy picnic food, invite a friend, announce the plan |
| `fr-first-steps-recall` | "Remember: your first steps" (recall) | Retrieval: greetings, introductions, age, negatives, questions |

- Real-world act: consolidation — build café sentences, run a picnic mission, and refresh the earliest phrases.
- Evidence: **reading** – blocks and mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers.
- Prerequisites: none declared — open-access consolidation unit (placement may recommend here; nothing gates entry).
- Revisit: deliberate cross-course retrieval — café, picnic-plan and first-steps evidence keys all return.

### fr-unit-8 · "En mission" · objective: "Use your French in the wild: navigate Paris, survive a headache, and build perfectly agreeing sentences."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-city-mission` | "Mission : un jour à Paris" (mission) | Navigate Paris: station, market, clock, home by midday |
| `fr-pharmacy-mission` | "Mission : à la pharmacie" (mission) | Name the pain, get medicine, set the dose |
| `fr-home-build-construction` | "Build it : ma maison" (construction) | Agreeing sentences about your home |

- Real-world act: integration missions — a day navigating Paris, a pharmacy run, and home descriptions with full adjective agreement.
- Evidence: **reading** – mission transcripts; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers.
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: agreement keys from the home build, and the mission phrase keys.

### fr-unit-9 · "Le passé raconté" · objective: "Tell what happened: build the passé composé and the imparfait, choose between them, and tell your day in order."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-a2-passe-compose-formation` | "Yesterday, in two beats" (discovery) | passé composé with avoir: helper + past participle |
| `fr-a2-imparfait-formation` | "The tense of “used to”" (discovery) | imparfait: nous-stem + -ais/-ait/-ions… |
| `fr-a2-passe-imparfait-choix` | "Photograph or painting ?" (discovery) | Choose finished event vs background/habit |
| `fr-a2-journee-recit` | "Raconte : ta journée" (story) | Retell a day in order with time words |

- Real-world act: narrate what happened — single events vs habits/background — and retell a full day in sequence.
- Evidence: **reading** – example pairs and the story; **listening** – not trained here; **speaking** – not trained here; **writing** – typed, cloze and matching answers (tense forms and choice).
- Prerequisites: fr-unit-8 chain (`fr-a2-passe-compose-formation` requires `fr-home-build-construction`).
- Revisit: passé composé and imparfait formation keys plus the choix decision keys — high-value written recall.

### fr-unit-10 · "L'avenir et les projets" · objective: "Talk about what's coming: form the futur simple, use it for promises and predictions, and name your projects and resolutions."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-a2-futur-formation` | "The future in one word" (discovery) | futur simple: infinitive + -ai/-as/-a/-ons/-ez/-ont |
| `fr-a2-futur-emplois` | "Remember : the future in one word" (recall) | Retrieval: one ending, every verb |
| `fr-a2-projets-resolutions` | "Remember : near-future plans" (recall) | Retrieval: aller + infinitif for plans |

- Real-world act: make promises and predictions in the futur simple, and state projects/resolutions with aller + infinitif.
- Evidence: **reading** – example pairs; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze and typed answers.
- Prerequisites: fr-unit-9 chain (`fr-a2-futur-formation` requires `fr-a2-journee-recit`).
- Revisit: futur endings and aller + infinitif evidence keys via the Review queue.

### fr-unit-11 · "Politesse et hypothèses" · objective: "Soften requests and open imaginary worlds: the conditional for politeness and wishes, plus si + imparfait."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-a2-conditionnel-politesse` | "The grammar of politeness" (discovery) | Conditional: future stem + imparfait endings; je voudrais / pourriez-vous |
| `fr-a2-conditionnel-souhait` | "Histoire : le rêve" (story) | Dream-trip narrative; express a wish |
| `fr-a2-si-imparfait-intro` | "Histoire : si seulement…" (story) | si + imparfait: two imaginary plans |

- Real-world act: soften requests with the conditional and open hypotheticals with si + imparfait.
- Evidence: **reading** – example pairs and two stories; **listening** – not trained here; **speaking** – not trained here; **writing** – typed, cloze and ordering answers.
- Prerequisites: fr-unit-10 chain (`fr-a2-conditionnel-politesse` requires `fr-a2-projets-resolutions`).
- Revisit: conditional endings and si-clause keys (wish sentences) — the politeness forms are the ones learners will need aloud first.

### fr-unit-12 · "Précision et liens" · objective: "Speak with precision: the pronouns y and en, the relatives qui/que/où, comparatives and superlatives."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-a2-pronoms-y-en` | "The tiny words y and en" (discovery) | Replace à + place/thing (y) and de + thing/quantity (en), before the verb |
| `fr-a2-relatifs-qui-que-ou` | "Linking ideas: qui, que, où" (discovery) | Link clauses: qui (subject), que (object), où (place/time) |
| `fr-a2-comparatifs` | "More, less, as" (discovery) | plus/moins/aussi + adjectif + que; bon → meilleur |
| `fr-a2-superlatifs` | "The most, the least, the best" (discovery) | le/la/les + plus/moins + adjectif (+ de); le meilleur / le pire |

- Real-world act: speak with precision — replace nouns with y/en, join clauses with relatives, and compare/superlative.
- Evidence: **reading** – example pairs and matching; **listening** – not trained here; **speaking** – not trained here; **writing** – typed, cloze, ordering and matching answers.
- Prerequisites: fr-unit-11 chain (`fr-a2-pronoms-y-en` requires `fr-a2-si-imparfait-intro`).
- Revisit: y/en placement, relative choice (qui vs que) and irregular comparative keys.

### fr-unit-13 · "Il faut que…" · objective: "Say what must be done: first steps into the subjunctive, the vocabulary of work, a hotel mission, and a review of A1."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-a2-subjonctif-intro` | "Il faut que… (first subjunctive)" (discovery) | ils-stem + -e/-es/-e/-ions… for obligation |
| `fr-a2-travail-vocab` | "Remember : study and work" (recall) | Retrieval: the verbs behind every workday |
| `fr-a2-hotel-mission` | "À l'hôtel : check-in" (mission) | Greet, state the booking, key + breakfast, quiet room |
| `fr-a2-rappel-a1` | "Retour sur le niveau A1" (recall) | Retrieval: introductions, negation, questions, numbers, requests… |

- Real-world act: say what must be done (il faut que + subjunctive), check into a hotel, and hold onto the A1 foundations.
- Evidence: **reading** – example pairs and the hotel mission transcript; **listening** – not trained here; **speaking** – not trained here (the hotel mission's recognition-only "speaking" skill tags were removed in the 2026-09-26 outcomes repair; there is no `self-compare` production step); **writing** – typed, cloze, ordering and matching answers.
- Prerequisites: fr-unit-12 chain (`fr-a2-subjonctif-intro` requires `fr-a2-superlatifs`).
- Revisit: subjunctive stem keys, hotel check-in phrases, and the A1 retrieval items (rappel).

**Level claim:** A1 foundation (units 1–8: introductions, home, routine, everyday exchanges, time/weather/market, health/social, consolidation) and an 18-lesson A2 block (units 9–13). Structured `cefr` tags exist **only on the A2 lessons** (18 × `"A2"`, units 9–13 — machine-checkable); the 32 A1 lessons are untagged, so the A1 label rests on content alignment with CEFR A1 descriptors. Note: an earlier version of this map stated "zero `"cefr"` keys in `french.json`" — stale against the current v1.5.8 working tree, which carries the 18 A2 tags.

---

## Italian (`it`, pack `it-foundations`, v1.5.6)

Note on unit order: this pack's `units` array places **it-unit-9 last** (order 1–8, 10, 11, 12, 13, 9) — the lesson browser shows that array order, so "Il passato" appears after the A2 work units. Unit ids are unaffected; the map below follows the pack's array order and flags the placement.

### it-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-cafe-mission` | "Missione: un caffè al bar" (mission) | Order a caffè in a Roman bar |
| `it-identity-foundation` | "Names and introductions" (discovery) | Names and introductions |
| `it-people-foundation` | "People and essere" (discovery) | People vocabulary + essere |
| `it-family-foundation` | "Family and avere" (discovery) | Family vocabulary + avere |
| `it-numbers-foundation` | "Numbers and age" (discovery) | Numbers, age |

- Real-world act: order a coffee; introduce yourself, your family, your age.
- Evidence: **reading** – mission text and example pairs; **listening** – model-audio steps in the four discovery lessons (allowlisted device speech, synthesized; 4 of the 16 Italian allowlisted assets); **speaking** – `self-compare` in people, family and numbers (self-assessed production); **writing** – typed, cloze and ordering answers.
- Prerequisites: entry unit; mission is "Suggested start".
- Revisit: caffè ordering and avere/essere evidence keys via the Review queue; self-compare items return as review prompts too.

### it-unit-2 · "Home and daily life" · objective: "Describe your surroundings and routine."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-home-foundation` | "Home and definite articles" (story) | Home vocabulary + definite articles in a story |
| `it-descriptions-foundation` | "Colors and agreement" (discovery) | Describing with agreed adjectives |
| `it-plural-foundation` | "More than one" (discovery) | Plurals |
| `it-routine-foundation` | "Study and work" (story) | Routine vocabulary in a story |

- Real-world act: describe your home and day; handle articles, colors, plurals.
- Evidence: **reading** – two stories plus example pairs; **listening** – model audio in descriptions and plural (allowlisted device speech, synthesized); the two story lessons have no audio step; **speaking** – `self-compare` in descriptions and plural; **writing** – typed, cloze and ordering answers.
- Prerequisites: it-unit-1 lessons (`it-home-foundation` declares `it-numbers-foundation`).
- Revisit: article/plural choice points (wrong-article category) via Review queue.

### it-unit-3 · "Everyday communication" · objective: "Use questions, descriptions and requests."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-negation-foundation` | "Saying no and asking" (discovery) | Negation and question forms |
| `it-food-foundation` | "Food and -ere verbs" (discovery) | prendere to order drinks; a short café exchange |
| `it-possession-foundation` | "What belongs to whom" (discovery) | Possessives |
| `it-transport-foundation` | "Going places" (story) | Moving around in a story |

- Real-world act: **partial** — say no, ask, order with prendere and claim things; the "descriptions" named in the objective are not trained in this unit (they live in unit 2).
- Evidence: **reading** – example pairs and the story; **listening** – model audio in food and possession (allowlisted device speech, synthesized); **speaking** – `self-compare` in negation, food and possession; **writing** – typed, matching, cloze and ordering answers.
- Prerequisites: it-unit-2 chain (`it-negation-foundation` requires `it-routine-foundation`).
- Revisit: non/negation slots, prendere order lines and possessive agreement keys.

### it-unit-4 · "Going further" · objective: "Discuss destinations, past actions and plans."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-requests-foundation` | "Modal verbs and requests" (conversation) | Modal verbs; polite requests |
| `it-reflexive-foundation` | "Morning routines" (recall) | Reflexive morning-routine retrieval |
| `it-past-foundation` | "A first look at the past" (discovery) | First past-tense forms |
| `it-plans-foundation` | "Tomorrow and future plans" (discovery) | Future plans (andare a, present) |

- Real-world act: ask politely with modal verbs, describe a morning routine, tell what happened yesterday and what you plan to do. (Destinations/transport were already practiced in unit 3's story; this unit delivers the past/plans/requests half of the objective.)
- Evidence: **reading** – dialogue choices, example pairs and recall prompts; **listening** – model audio in requests, past and plans (allowlisted device speech, synthesized; the requests lesson also plays `it-polite-coffee-audio`); **speaking** – `self-compare` in requests; **writing** – typed, cloze, ordering and dialogue-choice answers.
- Prerequisites: it-unit-3 chain (`it-requests-foundation` requires `it-transport-foundation`).
- Revisit: modal request keys, pas/past and plan formation keys via the Review queue.

### it-unit-5 · "Time and the world around you" · objective: "Handle days, time, weather and market prices."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-days-foundation` | "Days, months and dates" (discovery) | Weekday and date in an exchange |
| `it-time-foundation` | "Telling the time" (mission) | Ask/say the time: half hours and quarters |
| `it-weather-foundation` | "Weather and seasons" (story) | Today's weather; two seasons |
| `it-market-foundation` | "At the market: prices" (listening) | Ask prices; understand a price list (20 min) |

- Real-world act: handle days/dates, time-telling, weather chat, and market prices — including listening to a price list.
- Evidence: **reading** – example pairs and the story; **listening** – this unit carries the pack's only shipped audio file: `it-market-foundation` has five Listen steps on `it-market-listen-audio` (bundled but still synthesized at author time, `reviewPending: true`, see `docs/audio-provenance/index.md`) plus a model step; the days lesson also has model audio (device speech); **speaking** – `self-compare` in days and market; **writing** – typed, cloze and ordering answers.
- Prerequisites: declared chain via `it-days-foundation`, which reaches back to `it-numbers-foundation` (unit 1) — then days → time → weather → market.
- Revisit: market price-list comprehension keys (the Listen lesson) and time/date evidence keys.

### it-unit-6 · "Health and social life" · objective: "Handle aches, the pharmacy, emergencies and invitations."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-health-foundation` | "Aches and the doctor" (conversation) | Say where it hurts; answer the doctor |
| `it-pharmacy-foundation` | "At the pharmacy" (conversation) | Ask for medicine; understand the price |
| `it-emergency-foundation` | "Emergencies" (discovery) | Call for help; ask for an ambulance |
| `it-invitations-foundation` | "Invitations" (conversation) | Invite; accept or decline politely |
| `it-cafe-order-foundation` | "At the café: order and pay" (conversation) | Order, ask the price, pay politely |

- Real-world act: get through a doctor visit, a pharmacy run, an emergency call, an invitation — and a full café order.
- Evidence: **reading** – dialogue and example text; **listening** – model audio in emergency and café-order (allowlisted device speech, synthesized; the café-order lesson plays `it-polite-coffee-audio`); **speaking** – `self-compare` in café-order; **writing** – typed, dialogue-choice, matching and cloze answers.
- Prerequisites: it-unit-5 chain (`it-health-foundation` requires `it-market-foundation`).
- Revisit: emergency phrases, invitation accept/decline and the café order line.

### it-unit-7 · "In azione" · objective: "Use your Italian in new ways: build sentences, complete a mission, remember what you learned."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-cafe-build-construction` | "Build your order" (construction) | Café orders from word tiles |
| `it-market-run-mission` | "Market mission" (mission) | Ask the price of three items; confirm payment |
| `it-early-words-recall` | "Remember the beginning" (recall) | Retrieval: first words and sentences |

- Real-world act: consolidation — build café orders, run a market errand, and pull the earliest phrases back from memory.
- Evidence: **reading** – tiles and mission transcript; **listening** – not trained here; **speaking** – not trained here (no `self-compare` in these lessons); **writing** – ordering, cloze and typed answers.
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: café-order build keys, market price keys and early-word retrieval items.

### it-unit-8 · "Alla prova" · objective: "Put your Italian to the test: order dinner, find the piazza, build sentences at the bar."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-restaurant-mission` | "Missione: cena in pizzeria" (mission) | Order dinner for two; ask for the bill |
| `it-directions-mission` | "Missione: trova la piazza" (mission) | Ask for directions; find the piazza |
| `it-food-construction` | "Costruisci: al bar" (construction) | Build bar sentences: what you and a friend will have |

- Real-world act: integration missions — a full pizzeria dinner, a directions quest, and bar orders built from tiles.
- Evidence: **reading** – mission transcripts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: restaurant order, directions, and bar-build evidence keys.

### it-unit-10 · "Il futuro" · objective: "Talk about the future: forming the futuro semplice, promises and predictions, plans and intentions."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-a2-futuro-semplice` | "Il futuro semplice" (construction) | Form the futuro semplice; talk about tomorrow |
| `it-a2-futuro-usi` | "Il futuro: promesse e previsioni" (recall) | Future for promises, predictions, present suppositions |
| `it-a2-progetti-futuri` | "Progetti e intenzioni" (mission) | Plans with andare a, pensare di, avere intenzione di |

- Real-world act: make promises and predictions, and state plans and intentions in the future.
- Evidence: **reading** – example pairs and the mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: declared chain via `it-a2-futuro-semplice`, which requires `it-a2-passato-imperfetto` (it-unit-9).
- Revisit: futuro endings, andare a / pensare di / avere intenzione di keys via the Review queue.

### it-unit-11 · "Desideri e cortesia" · objective: "Express wishes and make polite requests with the conditional."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-a2-condizionale` | "Il condizionale presente" (construction) | Form the conditional; wishes and hypotheticals |
| `it-a2-condizionale-cortesia` | "La cortesia: vorrei e potrebbe" (conversation) | Polite requests: vorrei, potrebbe, sarebbe possibile |
| `it-a2-vorrei` | "In negozio: vorrei provare" (conversation) | Try on clothes; ask politely in a shop |

- Real-world act: express wishes and make polite requests — including a clothes-shop exchange.
- Evidence: **reading** – example pairs and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – typed, dialogue-choice, ordering and cloze answers.
- Prerequisites: it-unit-10 chain (`it-a2-condizionale` requires `it-a2-progetti-futuri`).
- Revisit: conditional endings and vorrei/potrebbe request keys — priority spoken-form recall.

### it-unit-12 · "Collegare le frasi" · objective: "Link ideas: the subjunctive after penso che, ne and ci, relative pronouns, and stare + gerundio."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-a2-congiuntivo` | "Il congiuntivo: penso che…" (discovery) | Present subjunctive after penso/credo/spero che |
| `it-a2-ne-ci` | "Ne e ci: due piccole parole" (construction) | ne (of it/them), ci (there / about it) |
| `it-a2-relativi-che-cui` | "Che e cui: collegare le frasi" (construction) | Relative che and cui |
| `it-a2-stare-gerundio` | "Stare + gerundio: azioni in corso" (story) | Actions in progress: stare + gerundio |

- Real-world act: link and soften ideas — subjunctive triggers, ne/ci, relatives and ongoing actions.
- Evidence: **reading** – example pairs and the story; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: it-unit-11 chain (`it-a2-congiuntivo` requires `it-a2-vorrei`).
- Revisit: subjunctive trigger keys, ne/ci placement and che vs cui choice keys.

### it-unit-13 · "Lavoro e tecnologia" · objective: "Compare things, talk about work, and survive a hotel stay — in Italian."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-a2-comparativi` | "I comparativi" (discovery) | più/meno… di/che and irregular comparatives |
| `it-a2-lavoro` | "Il mondo del lavoro" (mission) | Work talk: si impersonale + job vocabulary |
| `it-a2-albergo-mission` | "Missione: una notte in albergo" (mission) | Check in, ask for needs, solve a problem |

- Real-world act: compare things, talk about work, and survive a hotel stay.
- Evidence: **reading** – example pairs and two mission transcripts; **listening** – not trained here; **speaking** – not trained here; **writing** – typed, matching, cloze and ordering answers.
- Prerequisites: it-unit-12 chain (`it-a2-comparativi` requires `it-a2-stare-gerundio`).
- Revisit: comparative forms and hotel check-in phrase keys.

### it-unit-9 · "Il passato" · objective: "Talk about the past: passato prossimo with avere and essere, the imperfetto, and choosing between them."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-a2-passato-prossimo` | "Il passato prossimo con avere" (construction) | Yesterday with passato prossimo + avere |
| `it-a2-essere-participi` | "Il passato prossimo con essere" (recall) | essere as helper; agreeing participle |
| `it-a2-imperfetto` | "L'imperfetto" (recall) | Habits and scenes: imperfetto |
| `it-a2-passato-imperfetto` | "Passato prossimo o imperfetto?" (recall) | Choose single events vs background/habits; tell a day |

- Real-world act: narrate the past — events with passato prossimo, habits/background with imperfetto, and the choice between them.
- Evidence: **reading** – example pairs and recall prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: declared chain from it-unit-8 (`it-a2-passato-prossimo` requires `it-food-construction`). Note the placement: although unit id 9, this unit is **last in the pack's array** — the browser runs units 1–8 → 10–13 → 9.
- Revisit: participle agreement (essere) and tense-choice keys — the imperfetto/passato-prossimo decision is the unit's core review value.

**Level claim:** A1 foundation (units 1–8) and an 17-lesson A2 block (units 9–13 by id; unit 9 sits last in the array). Italian is the only pack with structured `cefr` tags **only on A2 lessons** (17 × `"A2"` — machine-checkable); the 32 A1 lessons are untagged → the A1 claim is content-based, consistent with CEFR A1 descriptors for introductions.

---

## German (`de`, pack `de-foundations`, v0.7.4)

### de-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-cafe-mission` | "Mission: ein Kaffee in Berlin" (mission) | Order a coffee in a Berlin café |
| `de-introductions-foundation` | "Introducing yourself" (discovery) | heißen; verb-fronted questions |
| `de-cafe-requests-foundation` | "At the café" (conversation) | Ordering a drink; accusative `einen` |

- Real-world act: introduce yourself by name and order a drink politely.
- Evidence: **reading** – mission/conversation text; **listening** – not trained here (no audio declared in this pack); **speaking** – not trained here; **writing** – typed answers.
- Prerequisites: entry unit; mission is "Suggested start".
- Revisit: heißen forms and accusative article shifts via Review queue (wrong-article category).

### de-unit-2 · "Getting around" · objective: "Understand prices and quantities in everyday errands."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-numbers-quantities-foundation` | "Numbers and quantities" (discovery) | 1–10; reversed number words (einundzwanzig) |

- Real-world act: **partial** — count 1–10 and read reversed number words. Prices and quantities in real errands are **not yet practiced** (1 lesson only).
- Evidence: **reading** – examples; **listening** – not trained here; **speaking** – not trained here; **writing** – typed answers.
- Prerequisites: de-unit-1.
- Revisit: number-word evidence keys via Review queue.

### de-unit-3 · "Finding your way" · objective: "Ask where things are and follow spoken directions."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-directions-foundation` | "Story: lost in the old town" (story) | Follow a lost tourist; find the way |
| `de-shopping-foundation` | "Conversation: haggling at the flea market" (conversation) | Ask prices, react, close the deal |

- Real-world act: **partial** — ask where things are and trace directions on paper/text; "follow **spoken** directions" requires listening, which is not trained here.
- Evidence: **reading** – story and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze and typed answers.
- Prerequisites: de-unit-2 chain (`de-directions-foundation` requires `de-numbers-quantities-foundation`).
- Revisit: direction phrases and price/quantity keys via the Review queue.

### de-unit-4 · "Everyday life" · objective: "Talk about days, times, and the people around you."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-time-days-foundation` | "Days and times" (discovery) | The week's gods and the one weekday that names nobody |
| `de-family-people-foundation` | "Conversation: meeting the parents" (conversation) | Introduce your family; survive the questions |

- Real-world act: talk about days and times and introduce the people around you.
- Evidence: **reading** – example pairs and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-3 chain (`de-time-days-foundation` requires `de-shopping-foundation`).
- Revisit: weekday/time evidence keys and the family-introduction line.

### de-unit-5 · "Weather and free time" · objective: "Say what the weather is doing, and talk about your free time and where you live."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-weather-foundation` | "Story: the Hamburg weekend" (story) | Weather language through a fickle weekend |
| `de-free-time-foundation` | "Story: the tennis bet" (story) | Free-time talk through a bet |

- Real-world act: **partial** — weather and free time are practiced; "where you live" is not trained in this unit (it arrives in unit 8 "Zuhause und Alltag").
- Evidence: **reading** – two stories with comprehension; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze and typed answers.
- Prerequisites: de-unit-4 chain (`de-weather-foundation` requires `de-family-people-foundation`).
- Revisit: weather and free-time evidence keys from both stories.

### de-unit-6 · "In Aktion" · objective: "Use your German in new ways: build, decide, remember."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-requests-build-construction` | "Build it: café requests" (construction) | Assemble requests/introductions; verb in second position |
| `de-market-run-mission` | "Mission: market run" (mission) | Buy two apples and a coffee; pay the bill |
| `de-remember-recall` | "Remember: everything so far" (recall) | Retrieval, lesson by lesson |

- Real-world act: consolidation — build café requests, run a market errand, and refresh everything so far.
- Evidence: **reading** – tiles and mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers.
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: second-position verb keys and market-run phrase keys via the Review queue.

### de-unit-7 · "Out and about" · objective: "Catch a train, meet a family, and build sentences about your week."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-train-mission` | "Mission: the Hamburg train" (mission) | Buy a ticket, find the platform, catch the train |
| `de-family-visit-mission` | "Mission: dinner with Lena's family" (mission) | Introduce yourself; charm through dinner |
| `de-routine-construction` | "Build it: my week" (construction) | Real sentences about your days; word order |

- Real-world act: integration missions — the Hamburg train, a family dinner, and week sentences built from tiles.
- Evidence: **reading** – mission transcripts; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers.
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: ticket/platform phrases and weekly-routine word-order keys.

### de-unit-8 · "Zuhause und Alltag" · objective: "Talk about your home and your day in German."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-home-foundation` | "Home and articles" (discovery) | der/die/das for rooms and furniture |
| `de-descriptions-foundation` | "Describing things" (discovery) | Adjectives that never change |
| `de-plural-foundation` | "Build it: plurals" (construction) | die for every plural; verb agrees |
| `de-routine-foundation` | "Work and daily routine" (discovery) | What you do and when; time word after the verb |

- Real-world act: describe your home and your day, with articles, plurals and word order under control.
- Evidence: **reading** – example pairs and tiles; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-5 chain (`de-home-foundation` requires `de-free-time-foundation`).
- Revisit: article choice and plural keys (wrong-article category) — high-value spelling-level recall.

### de-unit-9 · "Alltagskommunikation" · objective: "Handle everyday exchanges: no, questions, food, mine and yours."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-negation-foundation` | "Build it: saying no" (construction) | kein for nouns; nicht for the rest |
| `de-questions-foundation` | "Conversation: small talk at the party" (conversation) | Ask the right questions; keep the chat going |
| `de-food-foundation` | "Food and drink" (discovery) | What you eat, drink and like |
| `de-possession-foundation` | "Mine and yours" (discovery) | mein, dein, sein, ihr |

- Real-world act: handle everyday exchanges — say no, ask, talk food, and claim things.
- Evidence: **reading** – example pairs and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-8 chain (`de-negation-foundation` requires `de-routine-foundation`).
- Revisit: kein-vs-nicht and possessive agreement keys via the Review queue.

### de-unit-10 · "Weiter geht's" · objective: "Go further: move around, ask politely, talk about yesterday and tomorrow."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-transport-foundation` | "Story: the night train" (story) | Catch the night train to Berlin — almost |
| `de-requests-foundation` | "Remember: polite requests" (recall) | Retrieval: können, möchten, verb-last rule |
| `de-past-foundation` | "Story: yesterday, honestly" (story) | Perfekt narrative |
| `de-plans-foundation` | "Making plans" (discovery) | Plan tomorrow and next week in the present |

- Real-world act: move around, ask politely, tell what happened (Perfekt) and what is planned.
- Evidence: **reading** – stories, example pairs and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-9 chain (`de-transport-foundation` requires `de-possession-foundation`).
- Revisit: Perfekt participle keys, polite-request keys and plan phrases.

### de-unit-11 · "Zeit und Welt" · objective: "Master time words and handle the market."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-months-foundation` | "Months, seasons and dates" (discovery) | Months; a German date |
| `de-time-telling-foundation` | "Remember: telling the time" (recall) | Retrieval: halb, viertel, Wie spät ist es? |
| `de-market-foundation` | "Mission: dinner from the market" (mission) | Buy everything for tonight's dinner |

- Real-world act: name months and dates, tell the time, and complete a market mission.
- Evidence: **reading** – example pairs and the mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-10 chain (`de-months-foundation` requires `de-plans-foundation`).
- Revisit: date/time word keys and market mission phrases.

### de-unit-12 · "Gesundheit und Sozialleben" · objective: "Take care of yourself and your social life in German."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-health-foundation` | "Conversation: at the doctor's" (conversation) | What's wrong; answer the doctor; understand advice |
| `de-pharmacy-foundation` | "Mission: the pharmacy errand" (mission) | Get something for the headache at the Apotheke |
| `de-emergency-foundation` | "Mission: get help fast" (mission) | Call for help; direct it |
| `de-invitations-foundation` | "Conversation: the birthday invitation" (conversation) | Invite, handle hesitation, pin the day |

- Real-world act: manage a doctor visit, pharmacy errand, emergency call and a birthday invitation.
- Evidence: **reading** – dialogue and mission text; **listening** – not trained here; **speaking** – not trained here; **writing** – typed, cloze, dialogue-choice and ordering answers.
- Prerequisites: de-unit-11 chain (`de-health-foundation` requires `de-market-foundation`).
- Revisit: health/emergency phrase keys and invitation accept/decline keys.

### de-unit-13 · "Vergangenheit erzählt" · objective: "Talk about the past: Perfekt with haben and sein, and the storyteller's Präteritum."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-a2-perfekt-bildung` | "Build it: Perfekt" (construction) | haben second, participle last |
| `de-a2-perfekt-sein-irregular` | "Remember: Perfekt with sein" (recall) | Movement takes sein; irregular participles |
| `de-a2-praeteritum-modal` | "Remember: the story past" (recall) | war, hatte, konnte — the storyteller's past |
| `de-a2-wochenende-erzaehlen` | "Story: the perfect Saturday" (story) | Tell a Saturday with zuerst, dann, danach, am Ende |

- Real-world act: narrate the past — Perfekt with haben/sein and the modal Präteritum — and tell a weekend in order.
- Evidence: **reading** – example pairs, story and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-12 chain (`de-a2-perfekt-bildung` requires `de-invitations-foundation`).
- Revisit: haben-vs-sein helper choice and participle-final word-order keys.

### de-unit-14 · "Zukunft und Pläne" · objective: "Talk about the future: Futur I for plans and guesses, plus resolutions."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-a2-futur-bildung` | "Build it: Futur" (construction) | werden second, infinitive last |
| `de-a2-futur-vermutung` | "Story: the mysterious neighbor" (story) | Guess with wird wohl… |
| `de-a2-plaene-vorsaetze` | "Story: resolutions, kept and broken" (story) | Three resolutions through January |

- Real-world act: make plans and guesses with Futur I, and talk about resolutions.
- Evidence: **reading** – example pairs and two stories; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-13 chain (`de-a2-futur-bildung` requires `de-a2-wochenende-erzaehlen`).
- Revisit: werden + infinitive frame keys and wird-wohl guess patterns.

### de-unit-15 · "Wünsche und Höflichkeit" · objective: "Soften your German: würde, polite requests, and unreal wishes."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-a2-konjunktiv-wuerde` | "Würde: wishes and polite would" (discovery) | würde + infinitive: Ich würde gern helfen |
| `de-a2-hoefliche-bitten` | "Conversation: the hotel front desk" (conversation) | Check in politely; handle small problems |
| `de-a2-irreale-wuensche` | "Remember: impossible wishes" (recall) | wäre, hätte, könnte — the grammar of daydreams |

- Real-world act: soften requests with würde, run a polite hotel exchange, and express unreal wishes.
- Evidence: **reading** – example pairs, dialogue text and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering, typed and dialogue-choice answers.
- Prerequisites: de-unit-14 chain (`de-a2-konjunktiv-wuerde` requires `de-a2-plaene-vorsaetze`).
- Revisit: würde-frame keys and wäre/hätte/könnte forms — priority spoken-form recall.

### de-unit-16 · "Sätze verbinden" · objective: "Connect ideas: relative clauses, comparatives, superlatives, and wo vs wohin."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-a2-relativsaetze` | "Build it: relative clauses" (construction) | Pronoun copies gender; verb goes last |
| `de-a2-komparativ` | "Komparativ: bigger, better" (discovery) | -er and als: größer als, besser als |
| `de-a2-superlativ` | "Remember: the superlative" (recall) | am besten, der schnellste |
| `de-a2-wechselpraepositionen` | "Wechselpräpositionen: wo vs wohin" (discovery) | Dativ for wo; Akkusativ for wohin |

- Real-world act: connect ideas with relatives, compare and superlative, and choose Dativ/Akkusativ by wo vs wohin.
- Evidence: **reading** – example pairs and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-15 chain (`de-a2-relativsaetze` requires `de-a2-irreale-wuensche`).
- Revisit: relative-gender and case-choice keys (wo/wohin) — wrong-case category.

### de-unit-17 · "Arbeit und Medien" · objective: "Talk about work: the passive, job vocabulary, and a full job interview."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-a2-passiv-intro` | "Passiv mit werden" (discovery) | Das Auto wird repariert |
| `de-a2-berufsvokabular` | "Berufe und Bewerbung" (discovery) | der Beruf, die Stelle, das Vorstellungsgespräch |
| `de-a2-bewerbungsgespraech-mission` | "Mission: Das Bewerbungsgespräch" (mission) | Introduce yourself, describe experience, stay polite |

- Real-world act: describe processes passively, talk about jobs and applications, and survive a job interview.
- Evidence: **reading** – example pairs and the interview mission transcript; **listening** – not trained here; **speaking** – not trained here (the mission's recognition-only "speaking" skill tags were removed in the 2026-09-26 outcomes repair; no `self-compare` production step); **writing** – cloze, ordering and typed answers.
- Prerequisites: de-unit-16 chain (`de-a2-passiv-intro` requires `de-a2-wechselpraepositionen`).
- Revisit: werden-passive frame keys and interview phrase keys.

**Level claim:** A1 (units 1–12) plus a 17-lesson A2 block (units 13–17). Structured `cefr` tags cover 45 of 52 lessons (28 × `"A1"` across units 1–12, 17 × `"A2"` in units 13–17) but tagging is partial: the opening mission in unit 1 plus the three lessons of the unit-6 consolidation unit and the three of unit 7 are untagged (7 untagged total). Tagging is also inconsistent with the description's arithmetic and review claims — see "Description claims vs mapped coverage" and backlog #7.

---

## Portuguese (`pt`, pack `pt-foundations`, v0.7.3, **European Portuguese throughout**)

### pt-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-cafe-mission` | "Missão: um café em Lisboa" (mission) | Order a coffee at a Lisbon pastelaria |
| `pt-introductions-foundation` | "Introducing yourself" (discovery) | Introducing as Ana; é vs e accents |
| `pt-cafe-requests-foundation` | "At the café" (conversation) | Ordering with `gostaria de`; gendered thanks |

- Real-world act: order a coffee and introduce yourself in European Portuguese.
- Evidence: **reading** – mission/conversation text; **listening** – not trained here (no audio declared in this pack); **speaking** – not trained here; **writing** – typed answers (accent-sensitive: é/e, gostaria).
- Prerequisites: entry unit; mission is "Suggested start".
- Revisit: accent-bearing evidence keys (`é` vs `e`) via Review queue — accents matter in `AnswerSpec.answers` matching.

### pt-unit-2 · "Getting around" · objective: "Understand prices and quantities in everyday errands."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-numbers-quantities-foundation` | "Numbers and quantities" (discovery) | 1–10; dois/duas gender agreement |

- Real-world act: **partial** — count 1–10 with correct dois/duas agreement. Prices/errands not yet practiced (1 lesson only).
- Evidence: **reading** – examples; **listening** – not trained here; **speaking** – not trained here; **writing** – typed answers.
- Prerequisites: pt-unit-1.
- Revisit: number-gender evidence keys via Review queue.

### pt-unit-3 · "Finding your way" · objective: "Ask where things are and follow spoken directions."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-directions-foundation` | "Asking the way" (story) | ficar for location; the grave-accent step |
| `pt-shopping-foundation` | "Prices and paying" (conversation) | What it costs; the singular price frame |

- Real-world act: **partial** — ask where things are and trace directions on text; "follow **spoken** directions" requires listening, which is not trained here.
- Evidence: **reading** – story and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze and typed answers (accent-sensitive: onde/onde?).
- Prerequisites: pt-unit-2 chain (`pt-directions-foundation` requires `pt-numbers-quantities-foundation`).
- Revisit: direction phrases and price-frame evidence keys.

### pt-unit-4 · "Everyday life" · objective: "Talk about days, times, and the people around you."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-time-days-foundation` | "Days and times" (discovery) | The week from domingo; segunda-feira hyphens |
| `pt-family-people-foundation` | "Family and people" (conversation) | Relatives; the article before possessives |

- Real-world act: talk about days and times and introduce the people around you.
- Evidence: **reading** – example pairs and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers (hyphenated day names).
- Prerequisites: pt-unit-3 chain (`pt-time-days-foundation` requires `pt-shopping-foundation`).
- Revisit: weekday spelling keys (segunda-feira) and family-introduction lines.

### pt-unit-5 · "Em ação" · objective: "Use your Portuguese in new ways: build, decide, remember."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-cafe-order-construction` | "Build it: at the café" (construction) | Café orders from blocks; gostaria de; matching thanks |
| `pt-market-trip-mission` | "Your mission: market day" (mission) | Complete the market list: prices, choose, pay |
| `pt-look-back-recall` | "Look back: what you know" (recall) | Retrieval of the first eight lessons |

- Real-world act: consolidation — build café orders, run the market mission, and pull back what you know.
- Evidence: **reading** – tiles and mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers (accent-sensitive).
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: gostaria de frame keys and market-list phrase keys.

### pt-unit-6 · "Na cidade e em casa" · objective: "Check in, find your way, and talk about your family — all with words you already know."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-station-mission` | "Your mission: find the station" (mission) | Ask the way; follow directions to the station |
| `pt-hotel-mission` | "Your mission: check in" (mission) | Greet, introduce yourself, ask the price, pay |
| `pt-family-construction` | "Build it: my family" (construction) | Family sentences: owners, agreements |

- Real-world act: integration missions — find the station, check in to a hotel, and describe your family.
- Evidence: **reading** – mission transcripts; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers.
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: direction and check-in phrase keys; family agreement keys.

### pt-unit-7 · "Em casa e no dia a dia" · objective: "Talk about your home and your day in Portuguese."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-home-foundation` | "Home and articles" (discovery) | Rooms; em fused with articles (na cozinha, no quarto) |
| `pt-descriptions-foundation` | "Describing things" (discovery) | Adjectives that agree: alto/alta, novo/nova |
| `pt-plural-foundation` | "More than one" (discovery) | -s, -es and the -ão rebels (pães) |
| `pt-routine-foundation` | "Work and daily routine" (construction) | -ar verbs and time-of-day phrases |

- Real-world act: describe your home and your day, with fused prepositions, agreement and plurals.
- Evidence: **reading** – example pairs and tiles; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers (accent-sensitive).
- Prerequisites: pt-unit-4 chain (`pt-home-foundation` requires `pt-family-people-foundation`).
- Revisit: em+article fusions and -ão plural keys — wrong-form category.

### pt-unit-8 · "Comunicação do dia a dia" · objective: "Handle everyday exchanges: no, questions, food, mine and yours."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-negation-foundation` | "Saying no" (discovery) | não before the verb; emphatic double negatives |
| `pt-questions-foundation` | "Asking questions" (construction) | What/who/where/when/how; softened with é que |
| `pt-food-foundation` | "Food and drink" (story) | comer, beber, gostar de |
| `pt-possession-foundation` | "Mine and yours" (discovery) | Possessives agreeing with the thing owned |

- Real-world act: handle everyday exchanges — say no, ask, talk food, and claim things.
- Evidence: **reading** – example pairs and the story; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: pt-unit-7 chain (`pt-negation-foundation` requires `pt-routine-foundation`).
- Revisit: double-negative and question-word accent keys; possessive agreement keys.

### pt-unit-9 · "Mais longe" · objective: "Go further: move around, ask politely, talk about yesterday and tomorrow."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-transport-foundation` | "Getting around" (mission) | ir; de carro, de metro, a pé |
| `pt-requests-foundation` | "Polite requests" (conversation) | Pode…?, Gostaria de…, por favor |
| `pt-past-foundation` | "Yesterday: a first look at the past" (recall) | falei, comi, foi, fiz |
| `pt-plans-foundation` | "Making plans" (construction) | vou, vamos, ir + infinitive |

- Real-world act: move around the city, ask politely, and tell what happened and what you plan.
- Evidence: **reading** – mission transcript, example pairs, dialogue and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: pt-unit-8 chain (`pt-transport-foundation` requires `pt-possession-foundation`).
- Revisit: transport prepositions (de/a), polite-request frames and past keys.

### pt-unit-10 · "O tempo e o mundo" · objective: "Master time words, the weather, and the market."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-weather-foundation` | "Weather and seasons" (discovery) | Está sol, Faz calor, o verão |
| `pt-time-telling-foundation` | "Telling the time" (discovery) | Que horas são? São três e meia |
| `pt-months-foundation` | "Months and dates" (discovery) | em junho; em 3 de maio |
| `pt-market-foundation` | "At the market" (mission) | Buy by quantity: um quilo de, uma garrafa de, uma dúzia de |

- Real-world act: master time words, weather talk, dates and market quantities.
- Evidence: **reading** – example pairs and the mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: pt-unit-9 chain (`pt-weather-foundation` requires `pt-plans-foundation`).
- Revisit: weather frames, time answers and quantity phrase keys.

### pt-unit-11 · "Tempo livre" · objective: "Talk about what you love doing."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-free-time-foundation` | "Free time and hobbies" (story) | Gosto de…, jogar, ouvir música |

- Real-world act: talk about hobbies and what you love doing. Reached, but note this is the pack's thinnest unit — one lesson with no practice variety (see backlog #9).
- Evidence: **reading** – story text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze and typed answers.
- Prerequisites: pt-unit-10 chain (`pt-free-time-foundation` requires `pt-market-foundation`).
- Revisit: gostar de + infinitive evidence keys via the Review queue.

### pt-unit-12 · "Saúde e vida social" · objective: "Take care of yourself and your social life in Portuguese."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-health-foundation` | "Health and the body" (story) | Dói-me…, Estou doente, Tenho febre |
| `pt-pharmacy-foundation` | "At the pharmacy" (conversation) | Preciso de…, para a dor de cabeça |
| `pt-emergency-foundation` | "Emergencies" (mission) | Socorro!, Chame…!, É urgente! |
| `pt-invitations-foundation` | "Invitations" (conversation) | Queres vir…?, com prazer, desta vez não |

- Real-world act: manage aches, a pharmacy run, an emergency and an invitation.
- Evidence: **reading** – story, dialogue and mission text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering, typed and dialogue-choice answers.
- Prerequisites: pt-unit-11 chain (`pt-health-foundation` requires `pt-free-time-foundation`).
- Revisit: health/emergency phrases and invitation accept/decline keys.

### pt-unit-13 · "O passado" · objective: "Talk about the past: the pretérito perfeito, the imperfeito, and how they work together."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-a2-preterito-perfeito` | "O pretérito perfeito" (story) | falei, comeste, partiu, falámos |
| `pt-a2-imperfeito` | "O imperfeito" (discovery) | falava, comia, era, costumava |
| `pt-a2-perfeito-vs-imperfeito` | "Perfeito ou imperfeito?" (recall) | Completed events vs background/habits |
| `pt-a2-contar-fim-de-semana` | "Contar o fim de semana" (recall) | Narrate the weekend: no sábado, depois, então, à noite |

- Real-world act: narrate the past — perfeito for events, imperfeito for background — and tell a weekend in order.
- Evidence: **reading** – story, example pairs and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers (falámos accent).
- Prerequisites: pt-unit-12 chain (`pt-a2-preterito-perfeito` requires `pt-invitations-foundation`).
- Revisit: tense-choice keys (perfeito vs imperfeito) and the falámos spelling.

### pt-unit-14 · "O futuro" · objective: "Talk about the future: ir + infinitivo, the futuro simples, and expressing plans."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-a2-ir-futuro` | "Ir + infinitivo" (construction) | vou fazer, vais sair, vamos viajar |
| `pt-a2-futuro-simples` | "O futuro simples" (story) | falarei, choverá, serei — promises and predictions |
| `pt-a2-planos-intencoes` | "Planos e intenções" (recall) | tencionar, pensar em, decidir + infinitivo |

- Real-world act: express the near future with ir + infinitivo, the futuro simples, and intentions.
- Evidence: **reading** – example pairs, story and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: pt-unit-13 chain (`pt-a2-ir-futuro` requires `pt-a2-contar-fim-de-semana`).
- Revisit: ir-future frames and futuro simples endings via the Review queue.

### pt-unit-15 · "Desejos e hipóteses" · objective: "Soften requests and wishes: the condicional, gostaria/queria, and a first taste of the conjuntivo."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-a2-condicional` | "O condicional" (conversation) | falaria, poderia, seria — polite requests, hypotheticals |
| `pt-a2-gostaria-queria` | "Gostaria e queria" (story) | Queria um café, por favor |
| `pt-a2-conjuntivo-intro` | "O conjuntivo: quero que…" (discovery) | que fales, que venhas after quero/é preciso/espero que |

- Real-world act: soften wants with the condicional and take a first step into the conjuntivo.
- Evidence: **reading** – dialogue, story and example pairs; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: pt-unit-14 chain (`pt-a2-condicional` requires `pt-a2-planos-intencoes`).
- Revisit: conditional endings and conjuntivo trigger keys — priority spoken-form recall.

### pt-unit-16 · "Ligar frases" · objective: "Connect your sentences: relative pronouns, comparatives, and pronouns with prepositions."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-a2-relativos` | "Que, quem, onde" (construction) | o livro que comprei, com quem falei, onde nasci |
| `pt-a2-comparativos` | "Comparativos" (discovery) | mais/menos… do que, tão… como, melhor/pior |
| `pt-a2-lhe-lhes` | "Lhe e lhes" (recall) | dei-lhe, disse-lhes, não lhe disse nada |
| `pt-a2-pronomes-preposicoes` | "Comigo, contigo, para mim" (story) | para mim/ti, comigo, contigo, consigo |

- Real-world act: connect sentences with relatives, compare, and handle pronoun + preposition forms.
- Evidence: **reading** – example pairs, story and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering, typing and matching answers.
- Prerequisites: pt-unit-15 chain (`pt-a2-relativos` requires `pt-a2-conjuntivo-intro`).
- Revisit: relative choice keys and the lhe/lhes and preposition-pronoun forms.

### pt-unit-17 · "Trabalho e tecnologia" · objective: "Superlatives and work vocabulary, a hotel check-in mission, and a full A1 review."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-a2-superlativos-trabalho` | "Superlativos no trabalho" (discovery) | o mais… de, -íssimo + work/tech vocabulary |
| `pt-a2-no-hotel` | "Missão: no hotel" (mission) | Check in in Porto: reservation, key, breakfast time |
| `pt-a2-revisao-a1` | "Revisão: o essencial do A1" (recall) | Greet, order, chat about yesterday/tomorrow, leave warmly |

- Real-world act: superlatives in a work context, a hotel check-in, and a full A1 review.
- Evidence: **reading** – example pairs, mission transcript and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering, typing and matching answers.
- Prerequisites: pt-unit-16 chain (`pt-a2-superlativos-trabalho` requires `pt-a2-pronomes-preposicoes`).
- Revisit: -íssimo and o mais… de keys; hotel check-in phrases; A1 review items.

**Level claim:** A1 (units 1–12) plus a 17-lesson A2 block (units 13–17), European Portuguese throughout (variants stated in the pack description and the review kit's `variant` field; record per-lesson in review, see `docs/native-review-kit.md`). Structured `cefr` tags cover 45 of 52 lessons (28 × `"A1"`, 17 × `"A2"`); 7 lessons are untagged — the unit-1 café mission and the six lessons of the unit-5 and unit-6 consolidation units. The description's "A1–A2" is a lumped label for the whole pack; per-lesson levels are now mostly machine-checkable, with the 7 untagged lessons the exception.

---

## Spanish (`es`, pack `es-foundations`, v0.7.2)

### es-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-cafe-mission` | "Misión: un café en Madrid" (mission) | Order a coffee in a Madrid café |
| `es-introductions-foundation` | "Introducing yourself" (discovery) | llamarse + reflexive pronouns |
| `es-cafe-requests-foundation` | "At the café" (conversation) | Ordering with `quisiera`; accents on café/té |

- Real-world act: introduce yourself and order a drink politely.
- Evidence: **reading** – mission/conversation text; **listening** – started 2026-09-26 with the café listen pilot in `es-cafe-mission` (5 steps: listen → interpret → respond) on two allowlisted device-speech assets (`es-cafe-listen-audio`, `es-cafe-listen-model`; synthesized on-device course voice, `reviewPending: true` — see Audio inventory 2026-09-26 and `docs/audio-provenance/spanish-cafe-listen-pilot.json`); **speaking** – first `self-compare` in the same pilot (`es-cafe-listen-say`, self-assessed production); **writing** – typed answers (accent-sensitive).
- Prerequisites: entry unit; mission is "Suggested start".
- Revisit: reflexives and accented order words via Review queue; the three listen comprehension evidence keys (`es-cafe-listen-gist` / `-drink` / `-here`) return as listening review items.

### es-unit-2 · "Getting around" · objective: "Understand prices and quantities in everyday errands."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-numbers-quantities-foundation` | "Numbers and quantities" (discovery) | 1–10; welded number words (veintiuno) |

- Real-world act: **partial** — count 1–10 and recognize welded number words. Prices/errands not yet practiced (1 lesson only).
- Evidence: **reading** – examples; **listening** – not trained here; **speaking** – not trained here; **writing** – typed answers.
- Prerequisites: es-unit-1.
- Revisit: number-word evidence keys via Review queue.

### es-unit-3 · "Finding your way" · objective: "Ask where things are and follow spoken directions."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-directions-foundation` | "Asking the way" (mission) | The accent that turns donde into a question; trace directions |
| `es-shopping-foundation` | "Prices and paying" (conversation) | ¿…? price questions; costar agreement (uno/varios) |

- Real-world act: **partial** — ask where things are and trace directions on text; "follow **spoken** directions" requires listening, which is not trained here.
- Evidence: **reading** – mission transcript and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze and typed answers (accent-sensitive: dónde, ¿…?).
- Prerequisites: es-unit-2 chain (`es-directions-foundation` requires `es-numbers-quantities-foundation`).
- Revisit: question-accent keys (dónde/donde) and costar-agreement keys.

### es-unit-4 · "Everyday life" · objective: "Talk about days, times, and the people around you."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-time-days-foundation` | "Days and times" (discovery) | Weekdays: the planets and the two that break the pattern |
| `es-family-people-foundation` | "Family and people" (conversation) | How many siblings; mi/mis with the number |

- Real-world act: talk about days and times and introduce the people around you.
- Evidence: **reading** – example pairs and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: es-unit-3 chain (`es-time-days-foundation` requires `es-shopping-foundation`).
- Revisit: weekday names and mi/mis number-agreement keys.

### es-unit-5 · "En acción" · objective: "Use your Spanish in new ways: build, decide, remember."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-cafe-order-construction` | "Build it: polite requests" (construction) | Polite café requests from parts, without the frame |
| `es-find-cafe-mission` | "Mission: find the café" (mission) | Ask the way, follow directions, order politely |
| `es-basics-recall` | "Remember the basics" (recall) | Retrieval of the first four lessons |

- Real-world act: consolidation — build polite requests, find the café, and pull the basics back from memory.
- Evidence: **reading** – tiles and mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers.
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: polite-request frame keys and first-lesson retrieval items.

### es-unit-6 · "De nuevo" · objective: "Use your Spanish in new ways: complete missions and build sentences."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-directions-mission` | "Mission: find the museum" (mission) | Ask the way to the museum; buy a ticket; say thanks |
| `es-party-mission` | "Mission: the birthday party" (mission) | Greet, introduce yourself, introduce siblings |
| `es-family-construction` | "Build it: my family" (construction) | Family sentences from tiles |

- Real-world act: integration missions — the museum, a birthday party, and family sentences built from tiles.
- Evidence: **reading** – mission transcripts; **listening** – not trained here; **speaking** – not trained here; **writing** – ordering, cloze and typed answers.
- Prerequisites: none declared — open-access consolidation unit.
- Revisit: direction/ticket phrases and family-construction agreement keys.

### es-unit-7 · "En casa y a diario" · objective: "Talk about your home and your day in Spanish."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-home-foundation` | "Home and articles" (story) | Rooms; el/la/los/las before every noun |
| `es-descriptions-foundation` | "Describing things" (discovery) | ser + adjective that matches (alto/alta) |
| `es-plural-foundation` | "More than one" (construction) | -s after a vowel, -es after a consonant |
| `es-routine-foundation` | "Work and daily routine" (story) | trabajar/estudiar; por la mañana/tarde/noche |

- Real-world act: describe your home and your day, with articles, agreement and plurals.
- Evidence: **reading** – two stories plus example pairs and tiles; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: es-unit-4 chain (`es-home-foundation` requires `es-family-people-foundation`).
- Revisit: article and plural keys (wrong-article category) — high-value spelling-level recall.

### es-unit-8 · "Comunicación diaria" · objective: "Handle everyday exchanges: no, questions, food, mine and yours."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-negation-foundation` | "Saying no" (construction) | no before the verb; nunca, nada, nadie |
| `es-questions-foundation` | "Asking questions" (conversation) | qué, quién, dónde, cuándo, cómo — with accents |
| `es-food-foundation` | "Food and drink" (story) | comer/beber; me gusta |
| `es-possession-foundation` | "Mine and yours" (construction) | mi/tu/su and mis/tus/sus |

- Real-world act: handle everyday exchanges — say no, ask, talk food, and claim things.
- Evidence: **reading** – example pairs, dialogue and the story; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers (question-word accents).
- Prerequisites: es-unit-7 chain (`es-negation-foundation` requires `es-routine-foundation`).
- Revisit: negation + indefinite keys and question-accent keys.

### es-unit-9 · "Más lejos" · objective: "Go further: move around, ask politely, talk about yesterday and tomorrow."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-transport-foundation` | "Getting around" (story) | ir: voy, vas, va; en coche, en metro, a pie |
| `es-requests-foundation` | "Polite requests" (conversation) | poder/querer; soften with querría |
| `es-past-foundation` | "Yesterday: a first look at the past" (discovery) | hablé, comí — and the mighty fue |
| `es-plans-foundation` | "Making plans" (recall) | ir a + infinitive for the near future |

- Real-world act: move around, ask politely, and tell what happened and what you plan.
- Evidence: **reading** – story, example pairs, dialogue and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: es-unit-8 chain (`es-transport-foundation` requires `es-possession-foundation`).
- Revisit: transport prepositions, querría frames and ir-a plan keys.

### es-unit-10 · "El tiempo y el mundo" · objective: "Master time words, the weather, and the market."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-weather-foundation` | "Weather and seasons" (story) | hace sol, hace frío; the four seasons |
| `es-time-telling-foundation` | "Telling the time" (recall) | Es la una, Son las tres y media; ¿Qué hora es? |
| `es-months-foundation` | "Months and dates" (discovery) | Months; dates the Spanish way (el 3 de mayo) |
| `es-market-foundation` | "At the market" (mission) | Buy by quantity; point with este/esta |

- Real-world act: master time words, weather talk, dates and market quantities.
- Evidence: **reading** – story, example pairs, retrieval prompts and the mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: es-unit-9 chain (`es-weather-foundation` requires `es-plans-foundation`).
- Revisit: time answers (es/son), weather frames and quantity phrase keys.

### es-unit-11 · "Tiempo libre" · objective: "Talk about what you love doing."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-free-time-foundation` | "Free time and hobbies" (recall) | Me gusta leer, Me encanta nadar |

- Real-world act: talk about hobbies and what you love doing. Reached, but note this is the pack's thinnest unit — one lesson with no practice variety (see backlog #9).
- Evidence: **reading** – retrieval prompts and example pairs; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze and typed answers.
- Prerequisites: es-unit-10 chain (`es-free-time-foundation` requires `es-market-foundation`).
- Revisit: me gusta/me encanta + infinitive keys via the Review queue.

### es-unit-12 · "Salud y vida social" · objective: "Take care of yourself and your social life in Spanish."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-health-foundation` | "Health and the body" (story) | Body parts; Me duele la cabeza |
| `es-pharmacy-foundation` | "At the pharmacy" (mission) | Necesito algo para el dolor |
| `es-emergency-foundation` | "Emergencies" (discovery) | ¡Socorro!, Llame a una ambulancia, ¿Dónde está el hospital? |
| `es-invitations-foundation` | "Invitations" (conversation) | Te invito a cenar, ¡Claro que sí!, Lo siento, no puedo |

- Real-world act: manage aches, a pharmacy run, an emergency and an invitation.
- Evidence: **reading** – story, mission transcript, example pairs and dialogue text; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering, typed and dialogue-choice answers.
- Prerequisites: es-unit-11 chain (`es-health-foundation` requires `es-free-time-foundation`).
- Revisit: health/emergency phrase keys and invitation accept/decline keys.

### es-unit-13 · "El pasado" · objective: "Talk about what happened: the preterite and the imperfect."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-a2-preterito-formacion` | "Formar el pretérito" (discovery) | Full -ar/-er/-ir endings; the big irregulars |
| `es-a2-imperfecto` | "El imperfecto" (story) | Habits, settings, background scenes |
| `es-a2-preterito-imperfecto` | "Pretérito o imperfecto" (recall) | Events vs background choice |
| `es-a2-fin-de-semana` | "Contar el fin de semana" (recall) | Weekend narrative: sequence words and past verbs |

- Real-world act: narrate what happened — preterite events vs imperfect background — and tell a weekend.
- Evidence: **reading** – example pairs, story and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers (irregular past forms).
- Prerequisites: es-unit-12 chain (`es-a2-preterito-formacion` requires `es-invitations-foundation`).
- Revisit: irregular preterite keys and pretérito-vs-imperfecto decision keys.

### es-unit-14 · "El futuro" · objective: "Talk about tomorrow: the simple future and your plans."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-a2-futuro-formacion` | "Formar el futuro" (discovery) | Infinitive + endings; the rebel stems |
| `es-a2-futuro-usos` | "Usos del futuro" (story) | Promises, predictions, present guesses |
| `es-a2-planes-intenciones` | "Planes e intenciones" (discovery) | ir a + infinitive; wishes with querer |

- Real-world act: talk about tomorrow — simple future, promises/predictions and plans.
- Evidence: **reading** – example pairs and the story; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: es-unit-13 chain (`es-a2-futuro-formacion` requires `es-a2-fin-de-semana`).
- Revisit: future endings (incl. irregular stems) and ir-a plan keys.

### es-unit-15 · "Deseos y cortesía" · objective: "Wish, ask politely, and trigger the subjunctive."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-a2-condicional` | "El condicional" (conversation) | Wishes, advice, polite requests |
| `es-a2-me-gustaria` | "Cortesía: me gustaría, quisiera" (recall) | The manners that open doors |
| `es-a2-subjuntivo-intro` | "Quiero que…: el subjuntivo" (discovery) | quiero/necesito/es importante que + subjunctive |

- Real-world act: wish, ask politely with the conditional, and trigger the subjunctive.
- Evidence: **reading** – dialogue, example pairs and retrieval prompts; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering, typed and dialogue-choice answers.
- Prerequisites: es-unit-14 chain (`es-a2-condicional` requires `es-a2-planes-intenciones`).
- Revisit: conditional endings and subjunctive trigger keys — priority spoken-form recall.

### es-unit-16 · "Conectar frases" · objective: "Link ideas: relative clauses, comparisons, pronouns, por and para."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-a2-relativos` | "Que, quien, donde" (construction) | que, quien/quienes, donde, el que, lo que |
| `es-a2-comparativos` | "Comparativos" (discovery) | más/menos… que, tan… como, mejor/peor |
| `es-a2-pronombres-od-oi` | "Pronombres: lo, la, le" (construction) | lo/la/le/les; combining into se lo |
| `es-a2-por-para` | "Por y para" (discovery) | por (cause, through) vs para (purpose, deadline) |

- Real-world act: link ideas with relatives, compare, swap nouns for pronouns, and split por/para.
- Evidence: **reading** – example pairs and tiles; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: es-unit-15 chain (`es-a2-relativos` requires `es-a2-subjuntivo-intro`).
- Revisit: relative-que vs quien, se-lo combinations and por/para choice keys.

### es-unit-17 · "Trabajo y tecnología" · objective: "Work, superlatives, the hotel mission, and tech talk."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-a2-superlativos` | "Superlativos y el trabajo" (discovery) | el más… and -ísimo; work talk |
| `es-a2-hotel-mission` | "Misión: en el hotel" (mission) | Check in: booking, breakfast, report a problem |
| `es-a2-tecnologia` | "Tecnología" (discovery) | Passwords, screens, sending, downloading |

- Real-world act: polish with superlatives, check into a hotel, and handle tech talk.
- Evidence: **reading** – example pairs and the mission transcript; **listening** – not trained here; **speaking** – not trained here; **writing** – cloze, ordering and typed answers.
- Prerequisites: es-unit-16 chain (`es-a2-superlativos` requires `es-a2-por-para`).
- Revisit: -ísimo / el más… keys and hotel check-in phrases.

**Level claim:** A1 (units 1–12) plus a 17-lesson A2 block (units 13–17). Structured `cefr` tags cover 45 of 52 lessons (28 × `"A1"` across units 1–12, 17 × `"A2"` in units 13–17) but tagging is partial: 7 lessons are untagged — the unit-1 café mission and the six lessons of the unit-5 and unit-6 consolidation units. The map now covers the whole arc the description calls "full A1"; "full" is a coverage claim, not a verification claim — native review remains open (see "Description claims vs mapped coverage" and backlog #8).

---

## Description claims vs mapped coverage

Where a pack description says more than the mapped lessons can support, the gap is backlog below — not a promise. Counts verified 2026-09-25 against the packs as they stand: fr 50, it 49, de 52, pt 52, es 52 (255 total); 40 missions, 36 stories.

| Pack | Description claim (verbatim) | Mapped reality | Verdict |
|------|------------------------------|----------------|---------|
| French | "Twenty-four original A1 foundation lessons. A growing course, not a complete A1 certification syllabus." | A1 units (1–8) hold **32** lessons. | **Understates A1 count** (24 vs 32). The "not a complete A1 certification syllabus" disclaimer is accurate — keep it. |
| French | "Now expanded with 18 CEFR A2 lessons in 5 new units" | Units 9–13 hold **18** lessons and all 18 carry `cefr: "A2"` — machine-checkable now. | Count and level tag consistent. (Earlier versions of this map recorded "no structured tags in french.json"; stale — reconciled.) |
| Italian | "Twenty-four original A1 foundation lessons" | A1 units (1–8) hold **32** lessons. | **Understates A1 count** (24 vs 32). |
| Italian | "Adds 17 new CEFR A2 lessons (units 9–13)" | **17** lessons carrying `cefr: "A2"` ✓; unit ids 9–13 are correct, but **it-unit-9 sits last in the pack's `units` array** (order 1–8, 10–13, 9) — the browser lists it after unit 13. | Count/level claim machine-checkable; display order quirk worth fixing (see backlog #10). |
| German | "35 A1 German lessons … **plus 19 new discovery lessons** … 17 new A2" | Pack has **52** lessons total (35 A1 + 17 A2), not 35+19+17=71. The 19 listed topics are the units 8–12 lessons already inside the 35; several of those lessons are not `discovery` family (missions, stories, conversations, recall). | **Double count + family mislabel** in pack copy. Needs copy fix (backlog #7). |
| German | "Lessons 1-8 have been through native-speaker review." | `docs/reviews/review-log.jsonl` records all 255 lessons with an AI-assisted disposition (183 `pass`, 72 `pass-with-notes`, dated 2026-09-25/26 — the earlier "all 255 unreviewed" record is stale, corrected 2026-09-26), but **none** with `reviewMethod: "external-human"`. `docs/native-review-kit.md` requires `reviewMethod: "external-human"` + named reviewer + recorded variant to clear "pending". | **Unverified claim of native review.** Also present in pack `attribution` ("lessons 1-8 reviewed 2026-09-11"). Needs routing (backlog #7). |
| Portuguese | "European Portuguese throughout. 52 A1–A2 lessons; native-speaker review pending." | 52 lessons ✓; 45 of 52 carry `cefr` tags (28 A1, 17 A2), 7 untagged (unit-1 mission, units 5–6); review-pending language is honest and verified against the review log. | Count OK; "A1–A2" is a lumped label over mixed tagging; variant is uniformly European Portuguese. Keep. |
| Spanish | "Fifty-two Spanish lessons: the full A1 arc … plus seventeen new CEFR A2 lessons in five units" | 52 lessons ✓; A1 = 35, A2 = 17; tagging partial (7 untagged). The arc is now fully mapped here, but "full A1 arc" reads as a completion claim, and native review is open (the description itself says "Native-speaker editorial review remains open"). | Counts match; "full A1 arc" phrasing implies completion — soften or keep only as coverage disclosure (backlog #8). |

## Prioritized content backlog (gaps, in priority order)

| # | Gap | Evidence | Fix / decision |
|---|-----|----------|----------------|
| 1 | **Listening evidence is synthesized, not recorded.** 24 lesson audio assets are declared across packs: 1 shipped recording (Italian market Listen track file); the other 23 are allowlisted as **intentional device speech** (`tools/device-speech-media.txt`) — French 5 + Italian 16 + Spanish 2 (the 2026-09-26 café listen pilot in `es-cafe-mission`) — labeled synthesized course voice, not recorded native audio, and `check_packs.sh` passes on that basis (2026-09-25 baseline, extended 2026-09-26). The 5 standalone Listen tracks have files but are themselves synthesized at author time with `reviewPending: true` (`docs/audio-provenance/index.md`). So: no native listening evidence anywhere yet. | Media declarations + allowlist; `tools/check_packs.sh`; `docs/audio-provenance/index.md` + `docs/audio-provenance/spanish-cafe-listen-pilot.json` | P0.1's repair took the device-speech alternative (allowlisted, labeled); marked as synthesized in the map. On-device audio verification and native review of the 23 synthesized steps remain pending |
| 2 | **de/pt/es unit 2 "Getting around" = 1 lesson** — prices and quantities in errands are promised in the unit objective but not practiced | `de-numbers-quantities-foundation`, `pt-numbers-quantities-foundation`, `es-numbers-quantities-foundation` | Author 1–2 lessons, or narrow the unit objective |
| 3 | **Speaking evidence missing in 4 of 5 languages** — only Italian has `self-compare` (12 activities, verified per lesson: people/family/numbers, descriptions/plural, negation/food/possession, requests, days/market, café-order); fr/de/pt/es have none | grep `"kind": "self-compare"` → italian.json only | Add self-compare steps for high-value phrases (rubric H1/H2) |
| 4 | **Open-ended prompts auto-graded against fixed lists** produce silent generic-fallback feedback ("That is not the form we are looking for…", `AnswerEngine.swift:210-212`) wherever `errors: []` | `"errors": []` is the decode default (`CoursePack.swift:316`); search each pack | Apply rubric H1/H3 per lesson: narrow prompts or author error entries |
| 5 | **Partial structured CEFR tagging.** French A1 (32 lessons) and Italian A1 (32) carry no tags — only their A2 blocks are tagged (18 and 17 × "A2"). German/Portuguese/Spanish tag 45 of 52 each; the untagged 7 per pack are the unit-1 café mission and the two consolidation units (de units 6–7; pt/es units 5–6). | counts of `"cefr"` per pack (2026-09-25) | Add `cefr` to the untagged lessons when levels are re-verified; earlier "fr/pt have zero cefr keys" record is stale and closed |
| 6 | **Totals reconciliation** — **resolved, not a discrepancy.** Verified by counting `lessons[]` per pack: fr 50, it 49, de 52, pt 52, es 52 = **255** (77 units, 40 missions, 36 stories). No orphan `unitId`s, no duplicate lesson ids. | `lessons[]` per pack | Closed |
| 7 | **German pack copy (description + attribution) is inaccurate and over-claims review.** Description arithmetic double counts (35 + 19 + 17 ≠ 52), calls missions/stories/conversations/recall lessons "19 new discovery lessons", and claims "Lessons 1-8 have been through native-speaker review" while the review log's 255 AI-assisted dispositions (183 pass / 72 pass-with-notes as of 2026-09-26) contain no `reviewMethod: "external-human"` entry — the native-review claim stays unverified for every lesson. | `german.json` `description` (line 9) and `attribution` (line 10); `docs/reviews/review-log.jsonl` | Route to pack-copy lane: correct the count and family labels; align the review claim with the log or record the missing native review records first |
| 8 | **Spanish description "the full A1 arc" reads as completion.** Mapping now covers every lesson, but "full" implies verified completeness while native review is open and per-lesson tags are partial (7 untagged). | `spanish.json` `description` (line 9) | Route to pack-copy lane: rephrase as coverage ("covers the A1 arc") or add the review-open disclosure to the phrase itself |
| 9 | **pt/es unit 11 "Tempo livre"/"Tiempo libre" = 1 lesson** — the objective is reached but with no practice variety; thin units decay faster | `pt-free-time-foundation`, `es-free-time-foundation` | Author 1–2 supporting lessons (e.g. a hobbies conversation), or accept and note the thin review surface |
| 10 | **Italian unit array order: it-unit-9 is last** (1–8, 10–13, 9). Unit ids are fine; the browser and this map follow the array, so the A2 "Il passato" unit appears after the units that presuppose it. | `italian.json` `units[]` order | Reorder the `units` array (id 9 before 10) — low risk, or accept as authoring order |
| 11 | **Description level labels that were machine-unverifiable are now mostly checkable, but A1 labels on untagged lessons remain prose** (fr/pt A1, it A1, de/es/pt consolidation units) | see backlog #5 | Re-verify levels lesson-by-lesson (review kit); only then add tags or let the prose claims stand as disclosed |

## Keeping this map honest

- **Every lesson appears exactly once** across the five sections above (count check method: sum of per-unit rows per pack = pack `lessons[]` count; see per-pack tallies in the report accompanying this file).
- **Unit ids in the headings match pack `units[].id` verbatim** (spot-checked across all 77 units; Italian headings follow the pack's array order, flagged where that differs from numeric order).
- **Evidence is derived from the packs, not from intent**: reading = text/dialogue stimuli present in each lesson's activities; listening = only where a `mediaId`-backed step exists (fr/it, plus the es café listen pilot as of 2026-09-26; all synthesized); speaking = only `self-compare` activities (it, plus the es pilot as of 2026-09-26); writing = `text`/`cloze`/`ordering` activities (present in every lesson). A skill with no such activity in a unit is written as **not trained here**.
- **Pack `description` / `attribution` copy is owned by other lanes**: this document records discrepancies (table above) but does not edit pack JSON. Routed items: German `description` line 9 + `attribution` line 10; Spanish `description` line 9. No other in-app copy repeats these claims — `Condisco/Lesson/CoursesView.swift` renders `pack.description` verbatim (line 151) and adds no level claims of its own.

## Template for future packs/units

Copy per unit, one subsection per unit in this document:

```markdown
### <pack>-unit-<n> · "<unit title>" · objective: "<unit.objective>"

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| <lesson id> | <title> (<family>) | <one line> |

- Real-world act: <what the learner manages after this unit; "partial — <missing part>" if the lessons don't reach the unit objective>
- Evidence: **reading** – …; **listening** – …; **speaking** – …; **writing** – …
- Prerequisites: <lesson ids or "entry unit; mission is Suggested start">
- Revisit: <which evidence keys should return via the FSRS Review queue>
```

Rule when extending: if any evidence column is **not trained here**, say so. If the unit does not reach its own `objective`, mark "partial" and add a backlog row — never restate the objective as achieved coverage. Keep level claims to the pack-level paragraph and reconcile them against the pack's actual `cefr` tags before editing.
