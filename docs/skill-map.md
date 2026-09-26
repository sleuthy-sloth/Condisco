# Skill map (P1.3)

Scope of this document: the **first two units of each of the five languages** — the plan's starting scope (`docs/roadmaps/2026-09-25-condisco-quality-and-growth.md`, P1.1/P1.3). A fill-in template for the remaining units is at the end. Nothing here claims coverage it does not map: level labels describe what the mapped lessons actually do, and gaps are backlog, not promises.

## Legend

- **Real-world act** — what the learner should be able to manage after the unit.
- **Evidence** — where the ability is demonstrated: reading = text/dialogue stimuli; listening = audio stimuli (`media`-backed steps); speaking = `self-compare` (self-assessed production); writing = typed answers (`text`, `cloze`, `ordering`). A missing skill is shown as **none**.
- **Prerequisites** — declared `lesson.prerequisites` or, for entry units, the runtime "Suggested start" tag (`PlacementStore.recommendedLessonId` in the lesson browser, `Condisco/Lesson/CoursesView.swift`).
- **Revisit points** — the FSRS review queue: every graded activity writes a per-`evidenceKey` FSRS state (`Condisco/Store/Fsrs.swift`, FSRS v6, desired retention 0.9); due items (`dueAt <= now`, `LearningStore.swift:1397`) surface in the Review tab as a `ReviewItem` that recalls the original prompt and accepted answer (`Condisco/Review/ReviewModels.swift`). Revisit = that queue, otherwise the phrases decay.

---

## French (`fr`, pack `fr-foundations`, v1.5.7)

### fr-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `fr-cafe-mission` | "Mission : un café à Paris" (mission) | Order a coffee in a café; first real exchange |
| `fr-identity-foundation` | "Names and introductions" (discovery) | I-am forms, masculine/feminine, introducing |
| `fr-people-foundation` | "People and être" (discovery) | People vocabulary + être in an exchange |
| `fr-family-foundation` | "Family and avoir" (discovery) | Family vocabulary + avoir in an exchange |
| `fr-numbers-foundation` | "Numbers and age" (discovery) | Numbers, stating age |

- Real-world act: walk into a café and order; introduce yourself, your name, your age, and your family.
- Evidence: **reading** – mission/story transcripts and example pairs; **listening** – French lesson audio runs on labeled device speech (synthesized; 5 assets allowlisted, see backlog #1); the only recorded French audio is the standalone Listen track — recorded lesson audio remains unavailable; **speaking** – none (no `self-compare` in French); **writing** – typed answers in identity/people/family/numbers lessons.
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
- Evidence: **reading** – two stories with comprehension; **listening** – same media caveat; **speaking** – none; **writing** – construction (ordering) and cloze answers.
- Prerequisites: fr-unit-1 lessons.
- Revisit: agreement/plural evidence keys are high-value Review-queue items for spelling-level recall (accent/diacritic-sensitive).

**Level claim:** A1 foundation (introductions, home, routine). Honest caveat: French lessons carry **no** structured `cefr` field in the pack (verified: zero `"cefr"` keys in `french.json`), so A1/A2 labels rest on prose only.

---

## Italian (`it`, pack `it-foundations`, v1.5.5)

### it-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-cafe-mission` | "Missione: un caffè al bar" (mission) | Order a caffè in a Roman bar |
| `it-identity-foundation` | "Names and introductions" (discovery) | Names and introductions |
| `it-people-foundation` | "People and essere" (discovery) | People vocabulary + essere |
| `it-family-foundation` | "Family and avere" (discovery) | Family vocabulary + avere |
| `it-numbers-foundation` | "Numbers and age" (discovery) | Numbers, age |

- Real-world act: order a coffee; introduce yourself, your family, your age.
- Evidence: **reading** – mission/story text; **listening** – media caveat as French; **speaking** – Italian is the only pack with `self-compare` activities (12 in `italian.json`; self-assessed production, `outcome: .selfAssessed`); **writing** – typed answers.
- Prerequisites: entry unit; mission is "Suggested start".
- Revisit: caffè ordering and avere/essere evidence keys via the Review queue.

### it-unit-2 · "Home and daily life" · objective: "Describe your surroundings and routine."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `it-home-foundation` | "Home and definite articles" (story) | Home vocabulary + definite articles in a story |
| `it-descriptions-foundation` | "Colors and agreement" (discovery) | Describing with agreed adjectives |
| `it-plural-foundation` | "More than one" (discovery) | Plurals |
| `it-routine-foundation` | "Study and work" (story) | Routine vocabulary in a story |

- Real-world act: describe your home and day; handle articles, colors, plurals.
- Evidence: **reading** – two stories; **listening** – media caveat; **speaking** – `self-compare` steps may appear in unit-2 lessons (12 exist pack-wide); **writing** – typed answers.
- Prerequisites: it-unit-1 lessons.
- Revisit: article/plural choice points (wrong-article category) via Review queue.

**Level claim:** A1 foundation. Italian is the only pack with structured `cefr` tags, and they exist **only on A2 lessons** (17 tags, all `"A2"`, units 9–13); unit-1–2 lessons are untagged → the A1 claim is content-based, consistent with CEFR A1 descriptors for introductions.

---

## German (`de`, pack `de-foundations`, v0.7.4)

### de-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-cafe-mission` | "Mission: ein Kaffee in Berlin" (mission) | Order a coffee in a Berlin café |
| `de-introductions-foundation` | "Introducing yourself" (discovery) | heißen; verb-fronted questions |
| `de-cafe-requests-foundation` | "At the café" (conversation) | Ordering a drink; accusative `einen` |

- Real-world act: introduce yourself by name and order a drink politely.
- Evidence: **reading** – mission/conversation text; **listening** – media caveat; **speaking** – none; **writing** – typed answers.
- Prerequisites: entry unit; mission is "Suggested start".
- Revisit: heißen forms and accusative article shifts via Review queue (wrong-article category).

### de-unit-2 · "Getting around" · objective: "Understand prices and quantities in everyday errands."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `de-numbers-quantities-foundation` | "Numbers and quantities" (discovery) | 1–10; reversed number words (einundzwanzig) |

- Real-world act: **partial** — count 1–10 and read reversed number words. Prices and quantities in real errands are **not yet practiced** (1 lesson only).
- Evidence: **reading** – examples; **listening** – none; **speaking** – none; **writing** – typed answers.
- Prerequisites: de-unit-1.
- Revisit: number-word evidence keys via Review queue.

**Level claim:** A1. German carries structured `cefr` tags on part of the pack: many A1 lessons (units 1–12) are tagged `"A1"` and all 17 A2 lessons (units 13–17) `"A2"`, but tagging is inconsistent — the opening mission and "Introducing yourself" in unit 1 are untagged while "At the café" carries `"A1"`.

---

## Portuguese (`pt`, pack `pt-foundations`, v0.7.3, **European Portuguese throughout**)

### pt-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-cafe-mission` | "Missão: um café em Lisboa" (mission) | Order a coffee at a Lisbon pastelaria |
| `pt-introductions-foundation` | "Introducing yourself" (discovery) | Introducing as Ana; é vs e accents |
| `pt-cafe-requests-foundation` | "At the café" (conversation) | Ordering with `gostaria de`; gendered thanks |

- Real-world act: order a coffee and introduce yourself in European Portuguese.
- Evidence: **reading** – mission/conversation text; **listening** – media caveat; **speaking** – none; **writing** – typed answers (accent-sensitive: é/e, gostaria).
- Prerequisites: entry unit; mission is "Suggested start".
- Revisit: accent-bearing evidence keys (`é` vs `e`) via Review queue — accents matter in `AnswerSpec.answers` matching.

### pt-unit-2 · "Getting around" · objective: "Understand prices and quantities in everyday errands."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `pt-numbers-quantities-foundation` | "Numbers and quantities" (discovery) | 1–10; dois/duas gender agreement |

- Real-world act: **partial** — count 1–10 with correct dois/duas agreement. Prices/errands not yet practiced (1 lesson only).
- Evidence: **reading** – examples; **listening** – none; **speaking** – none; **writing** – typed answers.
- Prerequisites: pt-unit-1.
- Revisit: number-gender evidence keys via Review queue.

**Level claim:** A1. Portuguese lessons carry **no** structured `cefr` field (verified: zero `"cefr"` keys in `portuguese.json`). The "A1–A2" label in the description is prose-level; per-lesson levels are unverifiable by machine today. Variant is uniformly European Portuguese (stated in the description; record per-lesson in review, see `docs/native-review-kit.md`).

---

## Spanish (`es`, pack `es-foundations`, v0.7.2)

### es-unit-1 · "Meeting people" · objective: "Introduce yourself and your family."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-cafe-mission` | "Misión: un café en Madrid" (mission) | Order a coffee in a Madrid café |
| `es-introductions-foundation` | "Introducing yourself" (discovery) | llamarse + reflexive pronouns |
| `es-cafe-requests-foundation` | "At the café" (conversation) | Ordering with `quisiera`; accents on café/té |

- Real-world act: introduce yourself and order a drink politely.
- Evidence: **reading** – mission/conversation text; **listening** – media caveat; **speaking** – none; **writing** – typed answers (accent-sensitive).
- Prerequisites: entry unit; mission is "Suggested start".
- Revisit: reflexives and accented order words via Review queue.

### es-unit-2 · "Getting around" · objective: "Understand prices and quantities in everyday errands."

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| `es-numbers-quantities-foundation` | "Numbers and quantities" (discovery) | 1–10; welded number words (veintiuno) |

- Real-world act: **partial** — count 1–10 and recognize welded number words. Prices/errands not yet practiced (1 lesson only).
- Evidence: **reading** – examples; **listening** – none; **speaking** – none; **writing** – typed answers.
- Prerequisites: es-unit-1.
- Revisit: number-word evidence keys via Review queue.

**Level claim:** A1. Spanish tags most lessons with structured `cefr` fields (`"A1"` across units 1–12, `"A2"` across units 13–17) but inconsistently — the opening café mission in unit 1 is untagged while other unit-1 lessons carry `"A1"`.

---

## Description claims vs mapped coverage

Where the pack description says more than units 1–2 (or the whole pack) can support, the gap is backlog below — not a promise.

| Pack | Description claim (verbatim) | Mapped reality | Verdict |
|------|------------------------------|----------------|---------|
| French | "Twenty-four original A1 foundation lessons. A growing course, not a complete A1 certification syllabus." | A1 units (1–8) now hold **32** lessons; units 1–2 map introductions & home. | **Understates A1 count** (24 vs 32). The "not a complete A1 certification syllabus" disclaimer is accurate — keep it. |
| French | "Now expanded with 18 CEFR A2 lessons in 5 new units" | Units 9–13 hold **18** lessons ✓ count matches; **no structured `cefr` tags exist** in the pack, so A2 is prose-only | Count OK; level claim unverifiable by machine. |
| Italian | "Twenty-four original A1 foundation lessons" | A1 units (1–8) hold **33** lessons | **Understates A1 count** (24 vs 33). |
| Italian | "Adds 17 new CEFR A2 lessons (units 9–13)" | **17** lessons carrying `cefr: "A2"` ✓ | Consistent with structured data — the one fully machine-checkable level claim. |
| German | "35 A1 German lessons… 17 new A2 discovery/mission lessons" | Units 1–12 = **35**; units 13–17 = **17** ✓ | Most internally consistent claims; per-lesson tags partial (see above). |
| Portuguese | "52 A1–A2 lessons; European Portuguese throughout. Native-speaker review pending." | 52 lessons (35 units 1–12 + 17 units 13–17) ✓; **no structured `cefr` tags**; variant recorded only in prose | Count OK; "A1–A2" is a lumped label; per-lesson levels unverifiable. |
| Spanish | "the full A1 arc … plus seventeen new CEFR A2 lessons" | A1 = 35 lessons, A2 = 17 ✓ counts; units 1–2 cover only introductions/café/numbers — the arc (directions, shopping, weather, health…) lives in units 3+ | Pack-level claim **broader than this map's scope**; arc needs mapping/verification before it can be claimed as complete. |

## Prioritized content backlog (gaps, in priority order)

| # | Gap | Evidence | Fix / decision |
|---|-----|----------|----------------|
| 1 | **Listening evidence is synthesized, not recorded.** 22 lesson audio assets are declared across packs: 1 shipped recording (Italian market track); the other 21 are allowlisted as **intentional device speech** (`tools/device-speech-media.txt`) — labeled synthesized course voice, not recorded native audio — and `check_packs.sh` passes on that basis (2026-09-25 baseline). Recorded listening evidence exists only where a track ships: the Italian market lesson recording and the 5 standalone Listen tracks. | Media declarations + allowlist; `tools/check_packs.sh` | P0.1's repair took the device-speech alternative (allowlisted, labeled); mark listening evidence as synthesized (not recorded) in the map; on-device audio verification and native review of the 21 synthesized steps remain pending |
| 2 | **de/pt/es unit 2 "Getting around" = 1 lesson** — prices and quantities in errands are promised in the unit objective but not practiced | `de-numbers-quantities-foundation`, `pt-numbers-quantities-foundation`, `es-numbers-quantities-foundation` | Author 1–2 lessons, or narrow the unit objective |
| 3 | **Speaking evidence missing in 4 of 5 languages** — only Italian has `self-compare` (12 activities, all in `italian.json`); fr/de/pt/es units 1–2 have no speaking step | grep `"kind": "self-compare"` → italian.json only | Add self-compare steps for high-value phrases (rubric H1/H2) |
| 4 | **Open-ended prompts auto-graded against fixed lists** produce silent generic-fallback feedback ("That is not the form we are looking for…", `AnswerEngine.swift:210-212`) wherever `errors: []` | `"errors": []` is the decode default (`CoursePack.swift:316`); search each pack | Apply rubric H1/H3 per lesson: narrow prompts or author error entries |
| 5 | **French/Portuguese have no structured CEFR tags** — level labels are prose-only | zero `"cefr"` keys in `french.json`, `portuguese.json` | Add `cefr` to lessons when levels are re-verified (German/Spanish tagging is also partial) |
| 6 | **Totals reconciliation** — **resolved, not a discrepancy.** Verified by counting `lessons[]` per pack: fr 50, it 49, de 52, pt 52, es 52 = **255**. Per-unit sums match exactly; no orphan `unitId`s and no duplicate lesson ids. Matches the plan inventory (255). | `lessons[]` per pack | Closed |
| 7 | Remaining units (3+) per language are unmapped | — | Extend this map with the template below |

## Template for remaining units

Copy per unit, one subsection per unit in `docs/skill-map.md`:

```markdown
### <pack>-unit-<n> · "<unit title>" · objective: "<unit.objective>"

| Lesson id | Title (family) | What it trains |
|-----------|----------------|----------------|
| <lesson id> | <title> (<family>) | <one line> |

- Real-world act: <what the learner manages after this unit; "partial — <missing part>" if the lessons don't reach the unit objective>
- Evidence: **reading** – …; **listening** – …; **speaking** – …; **writing** – …
- Prerequisites: <lesson ids or "entry unit; mission is Suggested start">
- Revisit: <which evidence keys should return via the FSRS Review queue>

**Level claim:** <A1/A2 statement with the structured-tag caveat for this pack>
```

Rule when extending: if any evidence column is **none**, say so. If the unit does not reach its own `objective`, mark "partial" and add a backlog row — never restate the objective as achieved coverage.