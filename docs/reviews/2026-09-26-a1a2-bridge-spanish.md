# A1/A2 map + A2→B1 bridge (Spanish) — 2026-09-26

Phase 5.1 groundwork: skill-map reconciliation, the Spanish A2→B1 bridge
definition, and the structural outcomes-audit tool. Focus language: **Spanish**
(developer decision, 2026-09-26). **No file under `Condisco/` was touched** —
the walkthrough candidate stays frozen; this slice only wrote
`docs/skill-map.md`, `docs/editorial-rubric.md`, `tools/audit_outcomes.py`,
and this report. Suite still 429/429 green (no app code changed).

Sources read directly: `Condisco/Content/packs/{french,italian,german,
portuguese,spanish}.json`, `Condisco/Content/listen-tracks/*.json`,
`tools/device-speech-media.txt`, `Condisco/Models/CoursePack.swift`
(skill enum at lines 99–100, activity kinds at 578, `GradedBase.skills` at 327),
`docs/reviews/review-log.jsonl`.

---

## 1. Skill map — evidence matrix (2026-09-26)

A dated per-unit evidence matrix (one table per language, unit rows) was added
to `docs/skill-map.md` under "Per-unit evidence matrix (2026-09-26)": 77 unit
rows covering all 255 lessons, marks machine-derived from the pack JSONs.
Legend: R = reading (text-bearing step), L = listening (audio-backed step —
`mediaId` stimulus or `modelAudioId` reference; device-speech counts, it plays
at lesson time), SP = spoken production (`self-compare` only; a skill tag on a
choice step is NOT speaking evidence), WP = written production
(text/cloze/ordering, constrained), I = interaction (`dialogue-choice` only).
`—` = not trained in any lesson of the unit. Standalone Listen tracks are
listed per language as Ⓛ and are **not** unit L evidence.

**Unit-level counts per language (marks ✓):**

| Pack | Units | Lessons | R | L | SP | WP | I |
|------|------:|--------:|--:|--:|---:|---:|--:|
| French    | 13 | 50 | 13 | 2  | 0 | 13 | 3 |
| Italian   | 13 | 49 | 13 | 6  | 6 | 13 | 3 |
| German    | 17 | 52 | 17 | 0  | 0 | 17 | 5 |
| Portuguese| 17 | 52 | 17 | 0  | 0 | 17 | 5 |
| Spanish   | 17 | 52 | 17 | 1  | 1 | 17 | 6 |
| **Total** | **77** | **255** | **77** | **9** | **7** | **77** | **22** |

**Notable absences (the scarce columns, stated honestly in the map):**

- **Spoken production exists only in Italian units 1–6 (12 `self-compare`
  activities) and the Spanish pilot's `es-cafe-listen-say`.** French, German
  and Portuguese have zero self-compare anywhere; their `speaking` skill tags
  sit on selection/text/dialogue-choice steps (see §3 findings).
- **In-lesson listening exists only in French units 1/6 (5 device-speech model
  steps), Italian units 1–6 (16 model steps + the market Listen lesson steps),
  and Spanish unit 1 (the 2026-09-26 café listen pilot).** German and
  Portuguese declare no media at all; the five standalone Listen tracks are
  separate content, not lesson evidence.
- **Interaction is exercised only in units that contain dialogue-choice**
  (fr 4/5/6, it 4/6/11, de 3/4/9/12/15, pt 3/4/9/12/15, es 3/4/8/9/12/15).
  Every other unit — including all missions without a dialogue-choice step —
  rehearses the learner's side of the exchange only.

**Stale claims corrected (same edit):**

1. `french.json` is **v1.5.8** (the map said v1.5.7 in the section heading and
   in the French level claim; the review log already records 1.5.8). Fixed in
   both places.
2. The map claimed the review log recorded "all 255 lessons as unreviewed".
   The log actually holds **255 dispositions dated 2026-09-25/26 — 183 `pass`,
   72 `pass-with-notes`**, all AI-assisted, **zero `reviewMethod:
   "external-human"`**. Corrected in the "Description claims vs mapped
   coverage" German row and in backlog #7's evidence: the German copy's
   native-review claim stays **unverified** (the review kit requires
   `external-human`), but the "all unreviewed" wording was stale.
3. Everything else reconciled: per-unit evidence prose matches the matrix on
   every unit (spot-checked all 77 rows); the matrix's stricter interaction
   column adds information without contradicting the prose.

---

## 2. A2→B1 bridge (Spanish) — dispositions

Added to `docs/editorial-rubric.md` ("A2→B1 bridge (Spanish, 2026-09-26)"),
including the **content-alignment labeling rule**: pathway labels describe the
content's CEFR alignment, never a learner-level claim.

| # | Capability | Gap found (2026-09-26) | Disposition |
|---|-----------|------------------------|-------------|
| B1 | Connected narration | No lesson strings 3+ sentences; `es-a2-fin-de-semana` objective names "sequence words" but steps retrieve only ayer/anoche; `luego` appears only in directions | **B1 path teaches it first** (+ pack-copy fix for the objective drift, deferred) |
| B2 | Explanation of a preference (with reasons) | `porque` absent from the whole pack (0 occurrences across activities/stimuli/concepts/vocabulary — grepped, pre-pilot) | **Disposition revised 2026-09-26 (F4): "B1 path teaches it first"** — `porque` now first at u18L4/L5 in the B1 pilot (shipped, gated); the A2 bridging lesson (near es-unit-11/-15) stays backlog |
| B3 | Following multi-turn exchanges | Nothing longer than ~3 turns; only the pilot is audio; pilot `reviewPending: true` | **B1 path teaches it first** |
| B4 | Extracting main point + supporting detail | Reading checks are single-detail selection; audio main-point+detail exists only in the pilot (`es-cafe-listen-gist/-drink/-here`) | **B1 path teaches it first** |
| B5 | Short connected written response | No free written production exists anywhere (engine auto-grades fixed lists only; rubric H1) — requires a new ungraded/self-assessed written step type | **B1 path teaches it first**, with an explicit **product dependency** (H1-compliant affordance) |

Four of five default to "B1 path teaches it first"; exactly one (B2) is
flagged for a bridging lesson. The es-unit-11 lesson (`es-free-time-foundation`)
supplies the preference half; the asterisked assumption "the missing piece is
A2-sized" is the flag's justification. The B5 disposition also pins a product
gap that no pack edit can fix.

---

## 3. Structural audit tool — `tools/audit_outcomes.py`

Standalone stdlib-python validator (new file; deliberately **not** wired into
`tools/preflight.sh`/`check_packs.sh` — that is Phase 5.4; the orchestrator
runs it manually). Editorial quality is out of scope (that's
`audit_editorial.swift`); this tool answers: *is every declared modality claim
backed by an activity type that actually exercises it?*

**Skill tokens, derived empirically from the packs** (every token on every
activity of all five packs, cross-checked against the Swift `Skill` enum at
`CoursePack.swift:99-100`):

```
reading, listening, writing, speaking, grammar, vocabulary
```

The four modality skills are checked; `grammar`/`vocabulary` are content tags
(census only). **Any other token is a WARNING, never a failure.**

**Rule set (per lesson declaring a modality skill; skills live on activities
only — verified: zero lessons/steps/stimuli carry `skills`):**

| Declared claim | Backed when the lesson contains… |
|---|---|
| `listening` | an audio-backed step: stimulus with `mediaId`, or an activity with `modelAudioId`; the media id must be declared in the pack's `media` array or allowlisted in `tools/device-speech-media.txt` (device speech still plays at lesson time) |
| `speaking` | ≥ 1 `self-compare` activity (self-assessed production). Skill tags on selection/text/dialogue-choice steps are NOT evidence |
| `writing` | ≥ 1 `text` or `cloze` activity (constrained production) |
| `reading` | ≥ 1 text-bearing step (activity `prompt`/`body`, or stimulus `body`/`pairs`/`translation`) |

Output: deterministic per-pack summary (lessons, declaring lessons,
audio-backed lessons, self-compare activities, text/cloze activities, unbacked
claims), the findings list (lesson, unit, family, skill, declaring activity
ids + kinds, missing evidence), warnings (unknown tokens / dangling refs /
malformed `skills`), and a skill-token census. Exit codes: **0** all claims
backed · **1** unbacked claims listed · **2** usage/schema error
(unreadable/malformed pack, missing top-level keys, bad CLI). `--help`
documents it; `--root`/`--packs`/`--allowlist` overrides are accepted, with
repo-relative defaults.

**How to run:**

```
python3 tools/audit_outcomes.py            # from the repo root
python3 tools/audit_outcomes.py --help
```

**Current state (baseline run 2026-09-26): exit 1 — 16 lessons with unbacked
`speaking` claims** (every other modal claim in all five packs is backed):

- French (2): `fr-cafe-mission`, `fr-a2-hotel-mission` — `speaking` tags on
  selection/text steps; no self-compare (the hotel mission's case was already
  flagged in the map's fr-unit-13 evidence line).
- Italian (1): `it-cafe-mission` — same pattern.
- German (10): `de-cafe-mission`, `de-train-mission`, `de-family-visit-mission`,
  `de-a2-bewerbungsgespraech-mission` (seven selection/text-tagged missions)
  and `de-shopping-foundation`, `de-questions-foundation`,
  `de-family-people-foundation`, `de-health-foundation`,
  `de-invitations-foundation`, `de-a2-hoefliche-bitten` (six conversations
  whose `speaking` tags sit on dialogue-choice steps).
- Portuguese (3): `pt-cafe-mission`, `pt-station-mission`, `pt-hotel-mission`.
- Spanish (0): the pilot's self-compare backs the unit; welcome contrast.

Census (baseline): reading 723 · listening 29 · writing 978 · speaking 52 ·
grammar 888 · vocabulary 817 tagged activities; 0 unknown tokens; 0 warnings.

---

## 4. Deferred items — pack/CoursesView changes later

Explicit list of what this slice deliberately did **not** change (all live
under `Condisco/`, frozen for the walkthrough; route to later slices):

1. **16 lessons carry an unbacked `speaking` skill tag** (§3 findings). Fix is
   pack data: either add a real `self-compare` step per lesson (italian
   pattern) or retag the recognition activities (drop/rename `speaking`) —
   Phase 5.4+ decision.
2. **`es-a2-fin-de-semana` objective drift**: objective promises "sequence
   words"; authored steps retrieve time adverbs (ayer/anoche) only. Pack-copy
   fix (narrow the objective) — no lesson authoring.
3. **B2 bridging lesson (`porque` + sentence over gustar/encantar/querer)** —
   flagged in the rubric (§2); author as a new A2 lesson near es-unit-11/-15.
   *(Disposition revised 2026-09-26 (F4): the B1 path now teaches `porque`
   first — u18L4/L5 — so this is a non-blocking backlog enrichment, not a
   prerequisite.)*
4. **B5 product dependency**: short connected written response needs a new
   ungraded/self-assessed written-production step type (H1/H2-compliant) —
   `Condisco/Models/CoursePack.swift` + `Condisco/Engine`/UI, then B1 lessons.
5. **De/pt in-lesson listening** (none today): audio steps would need pack
   media + allowlist entries (backlog #1 family; the Spanish pilot is the
   template).
6. **CoursesView**: renders `pack.description` verbatim
   (`CoursesView.swift:151`) and adds no level claims — correct as-is. When a
   B1 pathway *label* ever ships, the labeling rule (content alignment, never a
   learner claim; §2) must be enforced in whatever surface renders it; no
   CoursesView change is needed today.
7. **French v1.5.8** is already in the pack JSON and review log; map corrected;
   no app change required.