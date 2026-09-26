# Condisco quality and growth plan

**Purpose:** Make Condisco a trustworthy, enjoyable iPhone language course that helps an adult beginner use what they learn in real situations. The app should feel calm and personal, work offline, and make progress visible without punishing missed days.

**Product promise:** “Learn without limits” should mean a learner can always find a useful next step, recover from an error, revisit weak material, and keep progressing. It should not imply that the current five packs already cover full proficiency. Course descriptions must state their actual scope.

**Planning assumption:** Prioritize practical beginner conversation and comprehension before broad course expansion. Preserve the existing local-first design, free access, optional sync, and the bee as a friendly learning companion. Validate that emphasis with a few real learners before investing in advanced features.

## What exists today

- Native SwiftUI app with onboarding, placement, five bundled course packs, lessons, stories, missions, review scheduling, flashcards, listening, recording and comparison, a widget, and optional CloudKit sync.
- 255 lessons across French, Italian, German, Portuguese, and Spanish. The packs include 40 missions and 36 stories. This is substantial breadth, but coverage and editorial quality vary by language.
- The recent player changes put feedback near the answer, explain common spelling slips, and allow assisted continuation. These fixes need validation throughout the complete course, on a real device.
- The packs declare 22 lesson audio assets. Only one of those 22 referenced files is present under `Condisco/Content` (the Italian market lesson recording); the other 21 are declared but missing and **allowlisted as intentional device speech** (`tools/device-speech-media.txt`), so audio steps play a labeled on-device synthesized voice — the earlier unavailable-audio dead end is fixed (verified 2026-09-25: `check_packs.sh` passes on that basis). The five standalone Listen tracks have files and pass type/hash checks. Recorded native audio for the 21 device-speech steps remains absent, and native review of them is still pending.
- Mimo's local refactor improved pack loading and Home/deep-link agreement. The widget now uses the same shared `CoursePack.firstUncompletedLesson` helper, and Home/widget/deep-link agreement on the same completed set plus the new engine/store tests are all integrated and passing in the local working tree (verified 2026-09-25).

## Lessons from other apps and research

| Source | What works | Condisco adaptation |
| --- | --- | --- |
| [Duolingo's spaced review](https://blog.duolingo.com/spaced-repetition-for-learning/) and [Babbel Review](https://support.babbel.com/hc/en-us/articles/360037496932-Memorizing-vocabulary) | Bring material back after a delay and ask for recall. | Use Condisco's existing FSRS queue inside a short daily plan and occasionally in later lessons; do not create a second scheduler. |
| [Duolingo Stories](https://blog.duolingo.com/duolingo-advanced-stories/) | Small narratives have a communication goal, characters, and varied real-world text forms. | Give each story a reason to read, a change between beats, and one comprehension outcome. Use messages, signs, menus, and dialogue where they serve the skill. |
| [Memrise's local-speaker clips](https://www.memrise.com/app) and [Pimsleur's speaking focus](https://www.pimsleur.com/pimsleur-app/) | Learners hear and produce language used by people. | Repair bundled audio first, then offer short listen–repeat–compare practice with clear limits on what the app can assess. |
| [Busuu's community corrections](https://help.busuu.com/hc/en-us/articles/15936615354641-What-is-Busuu) | Human feedback helps with open expression. | Start with optional shareable pair practice. A full community requires moderation, privacy controls, and a backend, so it is a later product decision. |
| [Spacing and retrieval research](https://www.nature.com/articles/s44159-022-00089-1) | Durable learning benefits from spaced attempts to retrieve an answer. | Measure delayed recall and useful production, not just lesson completion or time in app. |

These are inspirations, not feature checklists. Condisco's differentiator should be **a small daily act of communication**: see or hear a situation, respond, understand a correction, and revisit it later. The bee can cue that sequence without becoming a second layer of decoration.

## Priority order

### P0 — Trust and correctness gate

**Outcome:** No learner loses work, meets a dead end, or is promised media the app cannot play.

1. **Audit and repair bundled media.** Add a validator that resolves every pack media URL and Listen track URL against the app bundle, checks file type and declared hash, and reports missing assets by pack, lesson, and step. Supply reviewed recordings for all 22 declared lesson assets or change the authored step to an explicit, tested device-speech alternative. Never display a broken play control or a “check the download” message for media that was supposed to ship with the app. Focus files: `Content/packs/*.json`, `Content/audio/`, `Store/PackLoader.swift`, `Lesson/StimulusViews.swift`, `tools/check_packs.*`.
2. **Finish and verify event idempotency.** Mimo's new store tests describe a possible duplicate-event conflict caused by comparing JSON strings whose key order can vary. Confirm the failure, use canonical encoding or decoded semantic comparison, and test local duplicate writes plus CloudKit replay. Preserve existing event IDs, database path, and legacy storage keys. Focus files: `Store/LearningStore.swift`, `Store/LearningEvents.swift`, `Tests/StoreTests.swift`.
3. **Verify the next-lesson result everywhere.** Mimo is updating the widget to use the shared `CoursePack` helper already used by Home and deep links. Confirm the change with a partially completed pack, a fully completed pack, and an orphaned lesson; then integrate it. Focus files: `Home/HomeView.swift`, `DeepLink/DeepLink.swift`, `Store/WidgetSnapshotWriter.swift`.
4. **Run a real-device smoke path.** Fresh install, onboarding, first mission, incorrect text and accent, assisted continuation, app kill/resume, review, Listen with screen locked, microphone denied/allowed, and a content update with an existing checkpoint. Record failures and fix blockers before widening scope.

**Exit gate:** All declared media resolve; packs validate; unit and first-run UI tests pass; the real-device path has no dead end or lost progress.

### P1 — Course quality and honest progression

**Outcome:** Lessons feel authored for a learner, and the app can support its level claims.

1. **Create one editorial rubric for all five languages.** Each mission needs a plausible situation, a concrete goal, progressive steps, useful phrases, and a distinct final response. Each story needs a character motive, an event or turn, a payoff, and questions answered by the passage. Remove “write anything” language where grading accepts only a fixed list. Check that hints and feedback identify the learner's specific error. Work in the prescribed review order: the first two units of all five packs, then the 40 missions, then the 36 stories, then the remaining lessons.
2. **Run the AI-assisted editorial review.** Review each lesson against the rubric in `docs/editorial-rubric.md` for what a solo developer with AI assistance can reliably judge: grammar mechanics, alignment between prompt and accepted answers, hint usefulness, error-specific feedback, and grading honesty (H1–H4). Work in the prescribed order: the first two units of all five packs, then the 40 missions, then the 36 stories, then the remaining lessons. Record one entry per lesson in `docs/reviews/review-log.jsonl` with `reviewMethod` (`AI-assisted` or `developer`), `modelOrTool` (required for `AI-assisted`), `date`, `sourcesChecked`, `disposition`, and `unresolvedQuestions`. A lesson is `pass` only when its applicable rubric checks are complete; a `needs-work` lesson keeps its pack out of release-quality claims. **Native-speaker review is no longer a required completion dependency for this release.** An AI-assisted or developer review is editorial evidence only: it never clears the “native-speaker review pending” language in pack `attribution`, is never described as native review, and does not make the course certified. Register, regional usage, cultural plausibility, and pronunciation naturalness still require a native speaker (recorded as `reviewMethod: external-human` with a named reviewer and variant, per `docs/native-review-kit.md`); that remains an advertised limitation until it happens.
3. **Define a skill map.** For each unit, name the real-world act the learner should manage and the evidence for reading, listening, speaking, and writing. Mark prerequisites and revisit points. A1/A2 labels should describe actual coverage; gaps become a prioritized content backlog rather than hidden promises.
4. **Improve the course browser.** Show “what you will be able to do,” approximate time, practiced skills, and the next recommended activity. Keep the full catalog browseable; allow a learner to change language or revisit any lesson without resetting progress.

**Exit gate (solo-achievable):** Every one of the 255 lessons (fr 50, it 49, de 52, pt 52, es 52) has a review-log disposition in `docs/reviews/review-log.jsonl`; the prescribed review order is executed (first two units of all five packs → all 40 missions → all 36 stories → remaining lessons); zero open-ended prompts are falsely auto-graded (count is 0 today and must stay 0); zero unaddressed hint/feedback gaps remain in any lesson marked `pass` (the current audit backlog — 1,743 graded steps with generic/empty hints and 880 error-feedback gaps — is worked down, never silently ignored); resolved high-confidence errors have targeted evaluation tests; and pack/media validation plus the editorial audit run green (`tools/check_packs.sh` passes on the device-speech allowlist basis, `tools/audit_editorial.sh --jsonl <path>` reports, `--strict` gates only objectively enforceable checks).

**What this gate does and does not claim.** This is the achievable solo-editorial gate: an AI worker plus the solo developer can complete it on their own, because it covers rubric checks that an automated/editorial pass can judge (prompt↔answer alignment, hints, feedback, grading honesty) and their tracking in the review log, plus the objectively enforceable audit checks. It does **not** clear native-speaker review: `native review pending` remains a stated limitation, no document may describe AI-assisted or developer review as native review, and no “certified”, “complete A1/A2”, or “full proficiency” claim may be made — CEFR topic mapping in the skill map expresses coverage with gaps disclosed. It also does not cover what still requires outside observation: physical-device validation (P0 real-device smoke path), native-speaker naturalness (register, regional usage, cultural plausibility, pronunciation — P1.2), and real learner outcomes (acceptance measures below). A lesson is `pass` only when its rubric checks are complete; any `needs-work` lesson keeps its pack out of release-quality claims.

### P2 — Make the daily loop coherent

**Outcome:** One obvious next action, with a satisfying path from lesson to review to real use.

1. **Replace competing Home calls to action with a small “Today” plan.** Present one recommended new lesson, due review count, and an optional listen/speak activity. Respect a learner who has only three minutes; do not require a streak. Use the existing projection and FSRS data rather than new persisted counters.
2. **Bring delayed recall into the path.** After a lesson, queue one or two earlier ideas for later retrieval. At the next visit, ask before showing the model. The Review tab remains the full queue; the path gives it a natural entry point. Avoid repeating the exact same question within one mission unless it is a deliberate, changed-context recall.
3. **Polish the lesson interaction on small and large screens.** Keep the answer and response feedback visible together; keep the primary action reachable when the keyboard is open; preserve context without repeating a whole passage above every question. Test portrait/landscape, iPad, Dynamic Type, VoiceOver, and reduced motion. Use the bee for one helpful cue such as “hear it again” or “try a shorter answer,” not constant praise.
4. **Give the learner an honest recap.** Show the goal achieved, a phrase they can use outside the app, one correction worth remembering, and a next step. If they used the model, distinguish practice completed from independent recall without shame.

**Exit gate:** In moderated tests, a new learner can state the current task and find the next action without guidance; the first mission and review session can be completed one-handed on a small iPhone; no relevant feedback appears off-screen.

### P3 — Listening, speaking, and real-world transfer

**Outcome:** Learners practice understanding and saying useful language, not only tapping and typing.

1. **Build from repaired audio.** Add reviewed recordings to high-value mission exchanges first. Give normal/slow replay and readable transcripts. Maintain an offline device-speech fallback for examples, clearly labeled when it is synthesized. Expand Listen beyond one track per language only after the initial tracks pass listening and transcript QA.
2. **Use a short listen–respond–compare loop.** A scenario plays a line, the learner chooses or speaks a reply, then hears a model. Recording stays local and disposable. The app must not claim pronunciation accuracy from a simple playback comparison; any future speech scoring needs separate validation by language and accent.
3. **Add an “outside the app” action.** End selected missions with a low-pressure task such as ordering, asking a direction, or composing a short message. Let the learner save the phrase and optionally mark that they tried it. Treat this as reflection, not proficiency evidence.
4. **Prototype learning together without a network service.** Let two people share a short role-play card and take turns locally or by share sheet. Evaluate demand and privacy needs before building accounts, a public community, or AI conversation.

**Exit gate:** Every featured scenario has usable reviewed audio or an explicit speech alternative; transcript and playback work offline; speaking practice states what it can and cannot evaluate.

### P4 — Platform polish and release confidence

**Outcome:** An app someone can keep using for months and update without fear.

1. **Accessibility audit:** VoiceOver order and labels, large text clipping, contrast, touch targets, keyboard focus, captions/transcripts, reduced motion, and screen orientation. Fix findings in the same milestone as the screen being changed.
2. **Storage and sync drills:** upgrade with old checkpoints, duplicate events, offline-to-online transition, second-device merge, sign-in unavailable on a personal team, and recovery from a malformed pack. Keep local progress usable when CloudKit is unavailable.
3. **Performance and battery budget:** measure cold launch, first pack load, Home/Review projection, Listen background playback, widget refresh, and repeated lesson navigation on an older supported iPhone. Set limits from measurements, not guesses.
4. **Documentation and release process:** update the README for the native iPhone app and current test suite. Make pack validation, media integrity, generator consistency, unit tests, and a compact UI smoke test run before each build shared with testers.
5. **Private learning feedback:** start with voluntary interviews and a small tester journal. If diagnostics are later added, collect only the minimum needed to answer a specific product question, with clear consent and no raw recordings or free-text answers sent off-device by default.

**Exit gate:** A documented release checklist passes on an iPhone and iPad; a version update preserves progress; the app remains useful with airplane mode on.

## First implementation slice

Keep the first slice narrow enough to finish and test independently:

1. Add media-path and hash validation to `tools/check_packs.sh` and make the missing-asset list explicit.
2. Repair the missing lesson audio or author a deliberate fallback for each affected step; verify one French and one Italian audio lesson on device.
3. Stabilize duplicate-event handling and finish Mimo's store tests; run a local/sync replay regression.
4. Verify Mimo's widget change and test the shared next-lesson choice across all three surfaces.
5. Run five short usability sessions on the first mission and a story (at least one learner using larger text); capture what they did, where they hesitated, and what answer they expected.

Only then start the larger editorial and daily-loop work. This slice directly addresses broken promises and gives a reliable baseline for judging later improvements.

## How to tell whether this is working

Use these as **acceptance measures**, not vanity goals:

- **Task success:** testers finish the first mission and can explain its real-world use without assistance.
- **Recovery:** after a wrong answer, testers can identify the correction and continue without leaving the lesson.
- **Delayed recall:** one week later, testers can produce or recognize a phrase from an earlier lesson without first seeing the answer.
- **Media reliability:** zero unresolved references in bundled packs; no silent audio failures in device smoke tests.
- **Progress safety:** no lost events or checkpoints across force quit, update, offline use, and sync replay.
- **Clarity:** the learner can name the next useful action from Home in a few seconds.

Revisit the order after the first implementation slice and usability sessions. Add features only when they improve one of these outcomes.
