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
| `reviewer` | "M. Silva (European Portuguese)" |
| `date` | `2026-10-02` |
| `variant` | `pt-PT` (vs `pt-BR`) |
| `disposition` | `pass` \| `pass-with-notes` \| `needs-work` \| `reject` |
| `notes` | Findings as `lessonId → step/activity id: issue` |

Record granularity below the lesson (step/activity id, e.g. `pt-cafe-mission-act-2`) goes in `notes`; the record itself is per lesson, matching how the pack and the plan treat review ("record … on each reviewed lesson").

## Tracking schema

### CSV column spec

Columns, in order: `date,pack_id,pack_version,unit_id,lesson_id,reviewer,variant,disposition,notes`

Rules: ISO dates (`2026-10-02`); `variant` uses BCP-47 (`pt-PT`, `pt-BR`, `es-ES`, `es-MX`, `fr-FR`, `fr-CA`, `de-DE`, `it-IT`); `disposition` from the enum; `notes` may contain the `\n`-escaped list of findings. One row per lesson review; a re-review is a new row with a new date.

### JSON record (one object per lesson)

```json
{
  "date": "2026-10-02",
  "packId": "pt-foundations",
  "packVersion": "0.7.3",
  "unitId": "pt-unit-1",
  "lessonId": "pt-cafe-mission",
  "reviewer": "M. Silva",
  "variant": "pt-PT",
  "disposition": "needs-work",
  "notes": [
    "pt-cafe-mission-act-3: missing accepted answer 'obrigada' for a female speaker",
    "pt-cafe-mission-act-2: prompt invites open output but activity is text-graded (rubric H1)"
  ]
}
```

Files to keep in `docs/reviews/` once tracking starts (e.g. `docs/reviews/review-log.csv` and `docs/reviews/2026-10-pt-unit-1.json`). No tracker exists in the repo today; this kit is its specification.

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
3. The existing `attribution` strings already say review remains open — they are the floor. When a lesson passes, record it; when it has not been reviewed, the same "review remains open" language applies to it.
4. The product promise "Learn without limits" (`Onboarding/Welcome.swift:71`) is about finding a next step — it must never be read as "full proficiency" (plan, product promise).