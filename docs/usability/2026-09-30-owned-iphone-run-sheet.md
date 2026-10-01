# Owned-iPhone verification run sheet

Prepared 2026-09-30. Status: not run on hardware. One iPhone is sufficient.
Record phone model, iOS version, build commit, date, and result for each row.
Keep simulator results in a separate record. Never erase real progress before a verified backup exists.

| Check | Concrete procedure | Expected result | Observed result |
|---|---|---|---|
| Preserve progress | Export learning data; keep a copy outside the app. First restore it into a clean simulator. Compare events, checkpoints, phrases and library documents. | Restore succeeds and identifiers/counts agree. | Not run on device |
| Upgrade | Install the candidate over the current build; open a completed lesson, due review and saved phrase. | Existing history remains accessible; revised lessons may request fresh practice. | Not run |
| Force quit | Start a lesson, type a draft, reveal a model, leave mid-step, force quit and reopen. | Same checkpoint restores; revealed work stays assisted. | Not run |
| Fully offline | Enable airplane mode; open Home, a lesson, Review and Listen. | All core flows work without an account or network. | Not run |
| Library-only due | Import short text, save a phrase with its meaning, return Home and open Review. | Due totals agree and the phrase appears once. | Not run |
| Library cancellation | Select an oversized or unavailable text file; cancel while loading. | UI stays responsive; no draft or document is saved after cancellation. | Not run |
| Unicode text | Import accented text with tabs/newlines and an optional UTF-8 BOM. | Readable text is preserved; no visible BOM. | Not run |
| Delete document | Delete an imported document with linked phrases. | Document disappears; phrases survive, but its orphaned library review cards are no longer scheduled. | Not run |
| Mixed languages | Create reviews in two languages, change focus and inspect the daily reminder. | Reminder does not attribute all due cards to the focus language. | Not run |
| Synthesized lesson audio | Play each new German/Portuguese exchange, replay, show transcript, submit the decision. | Correct language voice; intelligible playback; transcript assistance remains recorded. | Not run |
| Microphone denied | Deny recording permission on a spoken task; continue using available self-check controls. | No dead end or claim that a recording was assessed. | Not run |
| Microphone restored | Enable permission in Settings and record/replay again. | Recording recovers and temporary audio is disposable. | Not run |
| Interrupt audio | Start Listen, lock phone, change output route, interrupt with another audio app, return. | Playback state/position recover predictably. | Not run |
| VoiceOver | Navigate onboarding, wrong-answer feedback, Review reveal/verdict, library selection and next-practice action. | Labels make sense; required controls are reachable and actionable. | Not run |
| Largest text | Use the largest accessibility text size; finish one lesson and a five-card review. | Feedback and primary actions remain reachable without clipping. | Not run |
| Reduced motion | Enable Reduce Motion; advance lesson steps and recap. | Required navigation works without unnecessary animated movement. | Not run |
| Spanish independent path | Complete one B1 dialogue and one B2 open task, with and without a revealed model. | Open work stays self-assessed; assisted history is distinguishable. | Not run |
| Recommendation | Open You, tap next practice; change focus and repeat. | Action opens the named lesson or course review for the current language. | Not run |

## Performance observations

Use the same candidate build and phone. Record five cold launches to usable content and the median; note review loading with a seeded long history, slowest visible lesson navigation and time from play tap to audible output. Record memory with Instruments when available. For Listen battery, record start/end charge after 15 minutes with fixed screen/output settings. Do not infer battery or audible latency from simulator timings or an audio API return time. Set budgets after observations exist.

## Defect record

For each failure record the row, exact actions, expected/actual behavior, build, and whether it repeats. The coder can then add an automated regression and fix it. Rows remain open until actually exercised.
