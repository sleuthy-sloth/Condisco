# Solo walkthrough and outcome status — 2026-09-26 (Condisco)

Phase 6 lane of `docs/roadmaps/2026-09-25-condisco-next-worker-closure-plan.md`
("Validate learning outcomes without native-speaker access"). This file records
what a **solo developer** can verify alone (simulator-only), which acceptance
rows are still **BLANK**, and what would make the outcome measures verifiable.
It makes no native-review, learner-success, device, or completed-outcome
claims.

**Honesty frame:** the automated evidence cited here is simulator/automation
evidence only. A passing UI test is not device, audio, battery, or
accessibility evidence, and an AI simulation is not evidence that learners
succeeded.

---

## 1. What a solo developer can verify without outside testers

The roadmap's own fallback (section "6. Validate learning outcomes without
native-speaker access", third bullet) is:

> "If no outside testers are available, perform the documented solo device
> walkthrough and accessibility audit, but leave task-success, clarity, and
> delayed-recall acceptance measures **unverified**. An AI simulation is useful
> for finding possible UI problems, not evidence that learners succeeded."

That is exactly what this file documents: the walkthrough and audit were
performed on the **iOS Simulator**, and the acceptance measures below remain
**BLANK**.

---

## 2. Solo walkthrough — exercised on the iOS Simulator (SIMULATOR-ONLY)

Exercised date/configuration: 2026-09-25 → 2026-09-26, on the **iOS Simulator,
iPhone 18 Pro** (the preflight destination). All results in this section are
**SIMULATOR-ONLY**; no physical iPhone has been used.

### 2.1 First-mission journey — `Condisco/UITests/FirstRunUITests.swift`

`testFreshFrenchLearnerCanFinishFirstMissionAfterAccentAndWrongAnswer` drives
the documented first-mission journey end to end against a fresh app state
(`--condisco-ui-test-reset`):

1. Onboarding — "Choose a language" → course selection ("French foundations") →
   "I'm starting fresh".
2. Placement lands on the first lesson briefing; exits via "Back to lessons".
3. Home "Today" — `home.today.header` present, no stale learner name, the
   primary row `home.today.primary` headlines the first mission
   ("Mission : un café à Paris").
4. First mission: briefing → first graded question
   ("The server looks up from the counter. How do you greet them?").
5. **Wrong answer** (Merci.) → correction + "Continue with model answer"
   surfaces; lesson continues in place.
6. **Accent correction** — typed "Un cafe, s'il vous plaît." yields the "Add
   the accent" correction with "Model answer: Un café"; not a dead end.
7. **Assisted continuation** — free-production step answered "No idea yet"
   falls back to "Continue with model answer".
8. **Kill/relaunch resume** — leaving mid-lesson and relaunching re-opens the
   same checkpoint via `home.today.primary`.
9. Order-build, matching, and final ordering activities, then "Back to
   lessons" and **Review navigation** (Review tab reachable; not exercised as a
   completed session here — see §2.2).

Automated evidence (each run is one UI test):

| Run (log file) | Result |
| --- | --- |
| `docs/verification/2026-09-25-baseline-preflight-with-ui.log` | FAILED (pre-fix; "Continue learning" copy gone, assertions at FirstRunUITests line 25 etc.) |
| `docs/verification/2026-09-25-phase1-preflight-with-ui.log` | passed (148.6 s) after the Today-layout repair |
| `docs/verification/2026-09-25-phase2-preflight-with-ui.log` | passed (94.6 s) |
| `docs/verification/2026-09-25-waveA/…-waveC` preflight logs | passed (253.7 / 88.0 / 84.0 s) |
| `docs/verification/2026-09-26-waveD/…-waveF` preflight logs | passed (109.3 / 111.1 / 103.2 s) |

The last completed preflight, `docs/verification/2026-09-26-waveF-preflight-with-ui.log`,
ends with `PREFLIGHT PASSED — every required step is green.` (unit 372/372,
UI smoke 1/1).

### 2.2 Five-card review journey — `Condisco/UITests/AccessibilitySweepUITests.swift`

`testFiveCardReviewSessionCompletesAfterHomeInvitation` drives the Home
invitation → five-card session with a seeded due set
(`--condisco-ui-test-seed-review`):

1. Onboarding → Home; the Today review row (`home.today.review`) shows
   "7 reviews due".
2. Tapping it opens Review showing **"5 of 7 to review"** — the Home
   invitation actually preselects five.
3. Five cards, each: "Reveal answer" → one of the four honest verdicts
   (I knew it / Almost / Not yet / Easy) → next card.
4. "Session complete" → Done → back to Review.

Execution status: **passed** once (102.7 s, 2026-09-26 07:32 run, iPhone 18 Pro
simulator). Simulator-only.

### 2.3 VoiceOver / label sweep — same test file

`testVoiceOverLabelsOnKeyControls` asserts the five tabs, "Focus language",
the Today header/primary labels, the mission name on the primary row, and the
Preferences "Reduce motion" / "Larger text" toggles. **Passed** (21.7 s,
simulator-only). These are label-existence checks via XCTest, which is proxy
evidence for VoiceOver labels — not a real VoiceOver rotor session and not a
device accessibility result.

---

## 3. Accessibility sweep — scope and current execution state (SIMULATOR-ONLY)

Scope defined at the top of `AccessibilitySweepUITests.swift` (its own words):

> "smallest iPhone (iPhone SE 3rd generation), portrait — the roadmap's
> 'one-handed' gate: the pinned primary action must stay hittable in the thumb
> zone, and required feedback/actions must never be hidden; landscape
> orientation — the same controls must stay reachable; largest Dynamic Type
> (`simctl ui … content-size accessibility-extra-extra-extra-large`) — no
> clipped, unreachable actions; iPad — the same flows complete on a tablet."

The file also notes that `simctl ui … content-size` is unusable on this Xcode
build, so the largest-type test pins the category through the
`-UIPreferredContentSizeCategoryName` launch-argument hook
(`UICTContentSizeCategoryAccessibilityXXXL`). The five test methods cover:
small-phone wrong-answer feedback, landscape reachability, largest Dynamic
Type, five-card review completion (§2.2), and VoiceOver labels (§2.3).

**Honest execution record (none of this is passed-by-assumption):**

| Fact | What the log shows |
| --- | --- |
| First (and so far only) execution | 2026-09-26 ~07:32, inside `docs/verification/2026-09-26-phase4slice2-phase5-preflight-with-ui.log` (third preflight invocation of that file) |
| Result | 5 executed, **1 failure** — `testLargestDynamicTypeKeepsActionsReachable` FAILED at `AccessibilitySweepUITests.swift:217` ("Model answer" feedback not found within 15 s after a wrong answer + Check at accessibility-XXXL). Other four tests passed. |
| Run on | iPhone 18 Pro simulator only (the preflight destination). The smallest-iPhone (SE) and iPad configurations named in the file's scope have **not** been run — no sweep script drives them yet, and the small-phone test ran on the larger iPhone 18 Pro. |
| Containing preflight | That log is truncated before a final preflight verdict for the third run; runs 1–2 of the same log aborted at step 4 on a simulator/test-runner communication error ("Failed to establish communication with the test runner"). The latest *completed* green preflight remains waveF (§2.1). |
| Status | **Not green.** Largest-Dynamic-Type failure is OPEN and must be diagnosed (and the sweep re-run, incl. on small iPhone/iPad and on device) before the accessibility gate can be claimed. |

Every result in this section is **SIMULATOR-ONLY**; no physical-device
accessibility testing has happened.

---

## 4. Plan outcome measures — BLANK / unverified

The three acceptance measures from the roadmap's Phase 6 (and
`docs/first-slice-verification.md`, "Manual: five usability sessions") have no
dated observations. No learner sessions have been held.

| Measure | Required observation | Status | What would fill it |
| --- | --- | --- | --- |
| (a) Task success | Five adult beginners complete the first mission without coaching, identify a correction after a wrong answer, and name the next Home action | **unverified — no learner sessions held** | Recruit five adult beginners (need not speak the target language natively), one large-text user if available; moderated first-mission/story sessions with observation-only notes and quotes |
| (b) Delayed recall | One week later, the same learners produce or recognize one earlier phrase before seeing the model | **unverified — no learner sessions held** | Week-1 follow-up with the same five testers; record successes, misses, confusing prompts; formative evidence only, not proof of proficiency |
| (c) Clarity / task-success acceptance | Learner can name the next useful action from Home within a few seconds | **unverified — no learner sessions held** | Capture the "names next action" step in the same session notes (journal template in `docs/learning-feedback-plan.md`) |

Roadmap cross-reference: the gate reads — "The plan's outcome measures have
dated observations, or the release note explicitly lists them as unverified.
No streak/time-in-app metric substitutes for them." This file is the
"explicitly listed as unverified" record. No time-in-app or streak metric is
offered as a substitute anywhere in this repo.

---

## 5. Physical-device gates — BLANK

These require the developer's physical devices (and, for one gate, paid
Apple developer CloudKit capability). No device has been used; every row is
BLANK, not passed.

| Gate | Status | What fills it |
| --- | --- | --- |
| On-device audio — French + Italian device-speech lessons ("Hear audio", Stop, synthesized label, mic denied/allowed, audio-session recovery) | **BLANK — requires developer's physical devices** | Run the manual smoke rows on a real iPhone and record pass/fail + observed behavior |
| On-device accessibility (VoiceOver rotor, Reduce Motion, real Dynamic Type/settings) | **BLANK — requires developer's physical devices** | Screenshot + notes per device/settings; results must be labeled by device |
| Upgrade/offline drills on hardware (database+checkpoint from previous build, force-quit/resume, airplane-mode lesson/review/Listen, offline→online replay) | **BLANK — requires developer's physical devices** | Run the drills on an iPhone with the previous build's data |
| CloudKit two-device merge | **BLANK — requires developer's physical devices / paid CloudKit capability** | Second signed-in device with paid capability; roadmap: "otherwise document that the CloudKit device gate is unavailable and keep local progress as the release guarantee" (two-store simulated merge runs in unit tests) |
| Device performance / battery | **BLANK — requires developer's physical devices** | Actual device/build/median values in `docs/performance-budget.md`; simulator timings are not battery evidence |

---

## 6. What would make these verifiable — roadmap quotes

From `docs/roadmaps/2026-09-25-condisco-next-worker-closure-plan.md`, Phase 6,
verbatim (no paraphrase):

> "Recruit five adult beginners for short first-mission/story sessions; they
> need not speak the target language natively. Ask them to complete tasks
> without coaching, identify a correction after a wrong answer, and name the
> next Home action. Include one large-text user if available. Obtain consent
> and record only observations and quotes; no learner recordings or raw
> answers."

> "Invite the same learners one week later to produce or recognize one earlier
> phrase before seeing the model. Record successes, misses, and confusing
> prompts. Treat this as formative evidence, not proof of proficiency."

> "If no outside testers are available, perform the documented solo device
> walkthrough and accessibility audit, but leave task-success, clarity, and
> delayed-recall acceptance measures **unverified**. An AI simulation is useful
> for finding possible UI problems, not evidence that learners succeeded."

---

## 7. When sessions do happen

Run them under `docs/learning-feedback-plan.md` exactly as written: the
consent script, journal template, capture rules, and "Do not do" list
(observation-only; no learner audio or raw typed answers; no coaching; no
time-in-app or streak measures). Session notes go in this directory
(`docs/usability/`) as dated entries with participants anonymized.