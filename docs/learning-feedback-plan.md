# Private learning feedback (P4.5)

How we learn from learners without surveilling them. Per the plan: **start with voluntary
interviews and a small tester journal. If diagnostics are ever added, collect only the
minimum needed to answer a specific product question, with clear consent and no raw
recordings or free-text answers sent off-device by default.** **Human-blocked**: needs
volunteer testers; Stage 2 constrains diagnostics if ever proposed.

## Status 2026-09-26 (Phase 6 — dated note)

- **No sessions held.** No learners recruited, no consent conversations, no
  journals. Every measure in this plan — task success, recovery, clarity,
  delayed recall, media reliability, progress safety — is
  **unverified — no learner sessions held** and must not be reported as
  measured.
- **Automated gates and editorial ledger** are tracked in
  `docs/first-slice-verification.md` ("Status 2026-09-26"): waveF preflight
  green (372/372 unit, 1/1 first-run UI), editorial ledger 255/255
  dispositioned (183 pass / 72 pass-with-notes / 0 unreviewed); a later
  accessibility-sweep run has one open failure (largest Dynamic Type).
- **Solo fallback**: `docs/usability/2026-09-26-solo-walkthrough-and-outcome-status.md`
  records the simulator-only walkthrough the roadmap defines when no outside
  testers are available. An AI simulation is not evidence that learners
  succeeded.
- The recruiting/consent rules and the "Do not do" list below are unchanged
  and apply verbatim to the first real session.

## Stage 1 — voluntary interviews + tester journal

### Recruiting and consent basics

| Item | Rule |
| --- | --- |
| Recruiting | Existing learners who opt in; no pressure framing, no streak/bonus incentives |
| Consent | Read the consent script (below) before the session; record verbal agreement; stop/withdraw anytime |
| Cadence | ~15–20 min sessions, weekly at most, ≈5 concurrent testers |
| Coaching | **None** — observe, ask capture questions, never hint/correct/carry through steps |

### Capture template

Use the capture template/procedure in `docs/first-slice-verification.md` ("Manual: five
usability sessions"): session #, learner, task in their words, hesitations, real-world use
unaided; record **measures, not time-in-app or streak length**.

### Findings → acceptance measures

| Measure | What to capture | Cross-check |
| --- | --- | --- |
| Task success | Finished first mission + explained real-world use unaided | Session/journal quote |
| Recovery | Wrong answer → identifies correction, continues in-lesson | Session note |
| Delayed recall | One week later produces/recognizes a phrase | Week-1 follow-up, same tester |
| Media reliability | Playback failures, dead audio, device-speech flakiness | `bash tools/check_packs.sh` |
| Progress safety | Lost checkpoint / reworked items after kill-and-relaunch | `docs/engineering-findings.md` #1/#2 |
| Clarity | Names next action from Home within seconds | Journal note |

Route: editorial (`tools/audit_editorial.sh`) · review (`docs/native-review-kit.md`) · engineering (`docs/engineering-findings.md`, with reproducer).

## Stage 2 — if diagnostics are ever added

1. **Nothing is built now.** Minimum-collection — only what answers a specific product question.
2. **The gate** — each data point must name the question + the decision it changes;
   no decision → rejected (e.g. a *recovery* question, not *"what do users type?"*).
3. **Explicit opt-in consent**, renewed per question, separate from onboarding.
4. **Never collected by default:** raw audio recordings, free-text learner answers,
   precise location, contacts. (Off unless a question requires them *and* consent.)
5. **On-device-first processing** — aggregate/count locally from the existing SQLite
   event log; upload aggregates, never the raw event stream.
6. **Retention & deletion** — period stated in consent; withdrawal/end date deletes the data.
7. **Withdrawal** — visible, simple path; withdrawal *deletes* collected data, not just stops it.

## Privacy rules (all stages)

- Data stays **on-device** unless a specific, consented question requires otherwise: the local
  SQLite event log and disposable `VoiceRecorder` files already stay on-device.
- **No third-party analytics SDK by default.** No Crashlytics/analytics pods.
- **CloudKit is optional and off when signed out** — progress syncs only when signed in + enabled.

## Consent script (say this to a tester)

> "This is a beta test of the learning app. I may watch you use it and take notes, but I won't
> record your voice or read your typed answers off this device. Nothing leaves the device unless
> you agree to a specific question first, and you can stop or take back your answers at any time.
> You're here to help us find out whether the first mission works — no right answers about you."

## Journal template (one entry per session)

```
Date: ________  Session #: ___  Learner: ___  Larger text? Y/N
Stage 1 task (mission/story): ______________
Task success (finished + explained real-world use unaided): Y/N — quote: ____
Recovery (wrong answer → identified correction, continued in-lesson): Y/N — note: ____
Clarity (named next action from Home in seconds): ____ s / couldn't
Media (listened/played/Hear-audio happened, failures): ____
Progress (kill-and-relaunch kept the checkpoint): Y/N
Delayed recall (week-1: phrase produced/recognized): ____
Hesitation points: ____
Follow-ups: ____ (editorial backlog / native-review kit / engineering findings)
```

## Do not do

- Do not record audio or capture typed answers in Stage 1 sessions — notes only.
- Do not coach, hint, or rescue a stuck tester.
- Do not use time-in-app or streak length as success measures.
- Do not ship analytics SDKs or always-on telemetry.
- Do not read free-text learner answers off-device even after consent, unless the specific
  question and consent cover exactly that.
- Do not add a diagnostic without naming the product question it answers.