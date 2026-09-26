# Editorial rubric (P1.1)

One rubric for all five packs (French, Italian, German, Portuguese, Spanish). Every check below is grounded in the shipped data model, so a reviewer can point at the JSON or Swift behavior that a finding refers to.

## How to use

1. Review one lesson at a time, against the scorecard at the end.
2. Work in the plan's order: **the first two units of each language, then the 40 missions**, then the remaining stories and lessons. (Plan: `docs/roadmaps/2026-09-25-condisco-quality-and-growth.md`, P1.1.)
3. Mark one disposition per lesson: `unreviewed` (initial state), `pass`, `pass-with-notes`, `needs-work`, `reject`. Record `reviewMethod` (`AI-assisted`, `developer`, or `external-human`), `modelOrTool` where applicable, `sourcesChecked`, and unresolved questions alongside it. Feed the result into the review tracker `docs/reviews/review-log.jsonl` (schema in `docs/native-review-kit.md`).
4. Cite the failing element by `lesson id` → step/activity id. A finding without an identifier is not actionable.

Families in the schema (`Condisco/Models/CoursePack.swift:111-114`): `discovery, story, conversation, listening, construction, scene, mission, recall`. Missions are `family == "mission"`, stories `family == "story"`.

## Mission criteria

A mission is a single real-world outcome with a situation, a goal, steps, usable phrases, and a closing response.

| # | Criterion | Pass | Needs work |
|---|-----------|------|------------|
| M1 | Plausible situation | The scene is a setting the learner could actually be in (café, station, shop, street) and the wrong setting is not used as decoration | Setting is generic, impossible, or only cosmetic |
| M2 | Concrete learner goal | One sentence states what the learner achieves by the end ("order and pay for a coffee") and the lesson closes that loop | Goal is vague ("talk in German") or differs from what the final step tests |
| M3 | Progressive steps | Steps build from noticing → producing → using, and later steps reuse earlier phrases | Steps jump levels, or a step depends on material never presented |
| M4 | Useful phrases | The phrases practiced are ones a native speaker would actually use in the situation; translations are attached | Practice targets textbook-only or unnatural phrasing |
| M5 | Distinct final response | The last exchange is a specific, pre-planned response (paying, thanking, confirming) — not "anything you like" | Final step is open-ended but is still auto-graded (see H1) |

## Story criteria

| # | Criterion | Pass | Needs work |
|---|-----------|------|------------|
| S1 | Character motive | The character wants or needs something the passage makes clear | Characters act randomly; no stated need |
| S2 | An event or turn | Something changes between beats (a discovery, a mistake, a decision) | The passage is a flat sequence of facts |
| S3 | A payoff | The turn resolves; the reader gets closure tied to the motive | The passage ends without consequence |
| S4 | Comprehension answerable from the passage | Every comprehension question is answerable only from the passage text, meaning/translation included | Questions require knowledge the passage never gives, or are answerable from the question wording alone |

## Grading-honesty rules

These rules exist because of how the engine actually grades. In `Condisco/Engine/AnswerEngine.swift`, a text answer is matched against `AnswerSpec.answers[]` and, on a wrong answer, against authored `AnswerSpec.errors[]` (`AnswerEngine.swift:102-103`). When nothing matches, the single generic fallback fires (`AnswerEngine.swift:210-212`): *"That is not the form we are looking for. Study the explanation, then try again."* Many activities are authored with `errors: []` (the decode default, `CoursePack.swift:316`), so every wrong answer gets that generic string. Hints come from `GradedBase.hints`; the runtime fallback hint is the first letter of the first accepted cloze answer, otherwise literally `"Try it"` (`Condisco/Engine/ActivityEvaluation.swift:204-211`). `GradedBase.feedback` is one string per activity, not per error.

| # | Rule | How to check |
|---|------|--------------|
| H1 | **No fixed-list auto-grading of open prompts.** A prompt that invites an open answer ("write anything", "describe freely") must not be a `text`/`cloze`/`selection` graded activity against a fixed list — every unmatched answer silently gets the generic fallback. | Read each `text` activity prompt and each cloze blank. If the prompt invites open output, either narrow the prompt to the exact form tested, or convert the step to `self-compare` / `information` (H2). |
| H2 | **Ungraded/self-assessed steps must be labeled as such.** `self-compare` produces outcome `.selfAssessed`; `information` produces `.ungraded` (`ActivityEvaluation.swift:46,52`). The on-screen copy must say the step is not graded ("compare yourself", "reading time"), and no graded language ("correct", "score") may appear around it. | For every `self-compare` and `information` activity, check the surrounding copy in the step context. |
| H3 | **Error-specific feedback where authored errors exist.** If `errors[]` is non-empty, the wrong-answer path must surface the specific category + explanation (e.g. `"wrong conjugation"`) for each likely wrong answer. Where `errors: []`, at minimum the top 2–3 likely wrong answers of each `text`/`cloze` activity should get authored error entries — otherwise the generic fallback is all the learner ever sees. | Grep the pack: `"errors": []` on graded activities is a finding. For activities with authored errors, confirm each covers a real likely mistake and the explanation teaches the fix. |
| H4 | **Hints must be useful.** Every graded activity needs a real authored hint in `base.hints`. A step whose only hint is the runtime `"Try it"` fallback (everything except cloze) fails this check. | For each graded activity with `hints: []` or hint `"Try it"`, flag it. Cloze steps may rely on the first-letter hint. |

## Scorecard

Fill one row per lesson in the review tracker `docs/reviews/review-log.jsonl`. `Pass`/`Needs work` are the verdicts from the tables above. `pass` requires every applicable rubric check to be complete; `needs-work` keeps the pack out of release-quality claims. Record the `reviewMethod` (and `modelOrTool` for `AI-assisted`) on the same record — an AI-assisted or developer review is editorial evidence only, never native review.

| Criterion | Pass | Needs work | Notes (lesson id → element) |
|-----------|------|------------|------------------------------|
| M1 Plausible situation | ☐ | ☐ | |
| M2 Concrete learner goal | ☐ | ☐ | |
| M3 Progressive steps | ☐ | ☐ | |
| M4 Useful phrases | ☐ | ☐ | |
| M5 Distinct final response | ☐ | ☐ | |
| S1 Character motive | ☐ | ☐ | |
| S2 Event or turn | ☐ | ☐ | |
| S3 Payoff | ☐ | ☐ | |
| S4 Comprehension answerable | ☐ | ☐ | |
| H1 No fixed-list grading of open prompts | ☐ | ☐ | |
| H2 Ungraded steps labeled | ☐ | ☐ | |
| H3 Error-specific feedback | ☐ | ☐ | |
| H4 Useful hints | ☐ | ☐ | |
| **Review method** | `external-human` (native review) | `AI-assisted` / `developer` (evidence only — native review stays open) | `reviewMethod` + `modelOrTool` on the ledger record |
| **Disposition** | | | `unreviewed` / `pass` / `pass-with-notes` / `needs-work` / `reject` |

## Scope note

The rubric applies identically to all five languages. Counts to plan against (verified by unit counts in the packs): 40 missions and 36 stories; per the plan inventory, 255 lessons across the five packs. If a unit-1–2 lesson does not satisfy one of M1–M5, S1–S4, H1–H4, the lesson is `needs-work` — the P1 exit gate requires the first two units of each language to pass editorial and native review.