# Native-speaker review kit (P1.2)

Execution of this phase is **human-blocked**: it requires native speakers. This kit defines what they review, what must be recorded per lesson, and how results are tracked. Everything here matches the fields that actually exist in the packs and the review status already declared in each pack's `attribution`.

## Status

Every pack ships with review-open language in `attribution` (pack JSON top level):

- French: "…native-speaker editorial review remains open. The 18 new A2 lessons (version 0.7.0) are machine-authored and pending native-speaker review."
- Italian: "…native-speaker editorial review remains open. The A2 lessons (units 9–13) are machine-authored and pending native-speaker review."
- German: "…Native-speaker editorial review: lessons 1-8 reviewed 2026-09-11; lessons 9-10 pending; 19 discovery lessons added 2026-09-23 are machine-authored and pending native-speaker review. The 17 new A2 lessons added in v0.7.0 are machine-authored and pending native-speaker review."
- Portuguese: "…native-speaker editorial review remains open. The 21 foundation lessons in units 7–12 are machine-authored in European Portuguese and pending native-speaker review. Units 13–17 (CEFR A2) are likewise machine-authored and pending native-speaker review."
- Spanish: "…native-speaker editorial review remains open for the whole pack. The 17 A2 lessons in units 13–17 were machine-authored in September 2026 and are pending native-speaker review."

So: German has partial review (lessons 1–8, dated 2026-09-11); the other four packs have none recorded. Review order matches the rubric: **first two units of each language, then the 40 missions, then the remaining stories and lessons** (plan P1.1/P1.2).

## Review methods

Every review record must say **how** it was produced (`reviewMethod`). A review method is an evidence label, not a quality claim:

| `reviewMethod` | What it means | `modelOrTool` | Clears "native-speaker review pending"? |
|----------------|---------------|---------------|------------------------------------------|
| `external-human` | A person outside the project (for native review: a native speaker) reviewed the lesson. | Tool used to view the lesson (e.g. `condisco-ios 1.5.x`) — optional. | Yes, if the reviewer is a native speaker of the pack's variant and `variant` is recorded. |
| `developer` | The maintainer's own review against the rubric. | Optional (e.g. `audit_editorial --jsonl`). | **No.** |
| `AI-assisted` | An AI model reviewed a lesson (full or in part), possibly reviewed by the developer afterwards. | Required, with version where applicable (e.g. `claude-sonnet-4-5`, `gpt-4o`, `deepseek-v4-flash`). | **No — never.** AI-assisted review is *not* native review and must never be recorded as such. |

**Native-speaker review requires `reviewMethod: "external-human"` with a named human reviewer and a recorded `variant`.** Records with `reviewMethod` `AI-assisted` or `developer` keep the pack's "native-speaker review pending" language in `attribution` untouched — they do not clear it.

## Review dimensions

| Dimension | What the reviewer checks | Typical finding to record |
|-----------|--------------------------|---------------------------|
| Grammar | Every learner-facing sentence is grammatical; explanations of forms are correct | Wrong gender/article, wrong tense choice in explanation text |
| Register | Language fits the situation and the learner level (no slang in a textbook step, no stiff bookish talk in a café mission) | "Too formal for spoken café order" |
| Regional usage | Usage is natural in the recorded variant (see below) — not a mix of dialects | Brazilian-only word in European Portuguese pack |
| Cultural plausibility | The situation could actually happen in the target culture (café norms, payment, greetings); `culturalNote` facts are right | "Paying at the counter before seating is the norm" |
| Pronunciation | Transcription `media[].transcript` and any audio match real pronunciation; where only device speech exists, note it | "Device speech mispronounces this word" |
| Prompt ↔ accepted answers | For each graded activity: every `AnswerSpec.answers[]` entry is a correct, natural answer; plausible alternatives are missing; authored `errors[]` match the stated `ErrorCategory` and the explanation teaches | "Missing accepted answer '…'"; "error category says 'wrong preposition', actually 'wrong article'" |

The last dimension is the one most tied to the engine: answers are matched as strings (`AnswerEngine.swift`), so the reviewer decides whether the fixed list is fair for the prompt — cross-reference rubric rule H1 (`docs/editorial-rubric.md`).

## Language variants to record

| Pack | Variant to name (examples) |
|------|----------------------------|
| Portuguese | European (pack standard) vs Brazilian |
| Spanish | European (Castilian) vs Latin American (country-level if needed) |
| French | European vs Canadian (vs African variants if reviewed) |
| German | Standard (Hochdeutsch); note Austria/Switzerland where relevant |
| Italian | Standard (Regional Italian if a note is needed) |

Portuguese is explicitly **European Portuguese throughout** (pack description); any Brazilian form found is a `needs-work` register/regional finding.

## Per-lesson record

One record per reviewed lesson, at minimum:

| Field | Example |
|-------|---------|
| `packId` | `pt-foundations` |
| `packVersion` | `0.7.3` |
| `unitId` | `pt-unit-1` |
| `lessonId` | `pt-cafe-mission` |
| `reviewMethod` | `AI-assisted` \| `developer` \| `external-human` (null → `unreviewed`) |
| `modelOrTool` | `claude-sonnet-4-5` (required for `AI-assisted`; version where applicable) |
| `reviewer` | "M. Silva (European Portuguese)" |
| `date` | `2026-10-02` |
| `variant` | `pt-PT` (vs `pt-BR`) |
| `sourcesChecked` | `["pt-foundations v0.7.3 pack JSON", "editorial-rubric H1–H4"]` |
| `disposition` | `unreviewed` \| `pass` \| `pass-with-notes` \| `needs-work` \| `reject` |
| `unresolvedQuestions` | `["pt-cafe-mission-act-4: is 'obrigado' accepted for the female speaker?"]` |
| `notes` | Findings as `lessonId → step/activity id: issue` |

Record granularity below the lesson (step/activity id, e.g. `pt-cafe-mission-act-2`) goes in `notes`; the record itself is per lesson, matching how the pack and the plan treat review ("record … on each reviewed lesson").

`pass` means every applicable rubric check (M1–M5, S1–S4, H1–H4) is complete for the lesson. Anything short is `needs-work` (or `reject`), and `needs-work` keeps the pack out of release-quality claims. `unreviewed` is the initial state of every seeded record — a lesson is never `pass` before it has been reviewed.

## Tracking schema

### CSV column spec

Columns, in order:
`date,pack_id,pack_version,unit_id,lesson_id,review_method,model_or_tool,reviewer,variant,disposition,sources_checked,unresolved_questions,notes`

Rules: ISO dates (`2026-10-02`); `review_method` from the enum (`AI-assisted`, `developer`, `external-human`; empty for `unreviewed`); `model_or_tool` required when `review_method` is `AI-assisted`; `variant` uses BCP-47 (`pt-PT`, `pt-BR`, `es-ES`, `es-MX`, `fr-FR`, `fr-CA`, `de-DE`, `it-IT`); `sources_checked`/`unresolved_questions` are `;`-joined lists; `disposition` from the enum; `notes` may contain the `\n`-escaped list of findings. One row per lesson review; a re-review is a new row with a new date.

### JSON record (one object per lesson)

```json
{
  "date": "2026-10-02",
  "packId": "pt-foundations",
  "packVersion": "0.7.3",
  "unitId": "pt-unit-1",
  "lessonId": "pt-cafe-mission",
  "reviewMethod": "external-human",
  "modelOrTool": null,
  "reviewer": "M. Silva",
  "variant": "pt-PT",
  "disposition": "needs-work",
  "sourcesChecked": [
    "pt-foundations v0.7.3 pack JSON",
    "editorial-rubric H1"
  ],
  "unresolvedQuestions": [],
  "notes": [
    "pt-cafe-mission-act-3: missing accepted answer 'obrigada' for a female speaker",
    "pt-cafe-mission-act-2: prompt invites open output but activity is text-graded (rubric H1)"
  ]
}
```

An `AI-assisted` record differs only in the method fields — note the required `modelOrTool` and that it does **not** clear native review:

```json
{
  "date": "2026-09-25",
  "packId": "pt-foundations",
  "packVersion": "0.7.3",
  "unitId": "pt-unit-1",
  "lessonId": "pt-cafe-mission",
  "reviewMethod": "AI-assisted",
  "modelOrTool": "claude-sonnet-4-5",
  "reviewer": "solo maintainer",
  "variant": null,
  "disposition": "needs-work",
  "sourcesChecked": ["pt-foundations v0.7.3 pack JSON", "editorial-rubric M1–M5"],
  "unresolvedQuestions": ["confirm 'obrigado' vs 'obrigada' with a native speaker"],
  "notes": []
}
```

### Tracker: `docs/reviews/review-log.jsonl`

The repo tracker is `docs/reviews/review-log.jsonl` — one JSON object per lesson (255 today), seeded by `tools/gen_review_log.py` with `disposition: "unreviewed"`, `reviewMethod: null`, empty `sourcesChecked`/`unresolvedQuestions`/`notes`. Rows are keyed by `lessonId`; updating a lesson means editing its line in place (reviews are recorded, never deleted). The generator is re-runnable: it re-derives the seed from the packs and preserves any row whose `disposition` is no longer `unreviewed` verbatim, so re-running never overwrites review work. Per-date JSON snapshots (`docs/reviews/2026-10-pt-unit-1.json`) remain optional for sharing a batch.

## Per-lesson checklist

Reviewer walks the lesson's steps in order (`Lesson.steps`, entry step → `nextStepId`/branches) and ticks:

- [ ] Unit objective is reached by the lesson's final step (else "partial" note).
- [ ] Every `stimulus.text`/`dialogue` turn is grammatical and natural in the variant.
- [ ] `culturalNote` (if present) is factual for the target culture.
- [ ] Every `self-compare`/`information` step is visibly labeled as ungraded/self-assessed (rubric H2).
- [ ] Every `text`/`cloze` `AnswerSpec.answers[]` entry is correct; plausible alternatives are accepted; `allowTypo` behavior is sane for spelling-sensitive steps.
- [ ] Every authored `errors[]` entry's category matches the mistake and its `explanation` teaches (rubric H3).
- [ ] Every graded activity has a useful authored hint (`GradedBase.hints`), not only the runtime `"Try it"` fallback (rubric H4).
- [ ] Pronunciation: transcripts/audio match; device-speech fallback is labeled as such.
- [ ] **Disposition recorded** with reviewer, date, variant.

## Certification policy

**While any review for a pack is open, the course must not be presented as certified proficiency.** Plain statements:

1. UI copy and pack descriptions may say what the pack covers, not that the learner is certified or CEFR-certified at any level. The browser (`Condisco/Lesson/CoursesView.swift`) today shows pack description text verbatim — edit pack copy, not the browser, if a claim is too strong.
2. The P1 exit gate ("first two units of each language pass editorial and native review", plan P1) is the earliest point at which level claims for those units can be made.
3. The existing `attribution` strings already say review remains open — they are the floor. When a lesson passes native review, record it (`reviewMethod: external-human`); when it has not been reviewed, the same "review remains open" language applies to it. Records with `reviewMethod` `AI-assisted` or `developer` are evidence toward editorial review only and must never be presented as, or recorded as, native review.
4. The product promise "Learn without limits" (`Onboarding/Welcome.swift:71`) is about finding a next step — it must never be read as "full proficiency" (plan, product promise).