# Phase 3 verification — listening coverage without overstating audio

**Date:** 2026-09-26
**Branch:** `main` @ `50a9f7fd43f2442707bd35b5f4deb2054dae5b61` (dirty tree preserved; nothing reset/staged/committed)
**Tree at gate:** 51 files changed, +4805/−1752 (Phase 2 gate: 44 files, +4354/−1738)
**Gate:** `bash tools/preflight.sh --with-ui` → **PREFLIGHT PASSED, EXIT=0**
(13:23:14–13:30:14 -0700; log: `2026-09-26-phase3-preflight-with-ui.log`)

## Gate results (fresh run, this code state)

| Check | Result |
| --- | --- |
| Pack + media (`check_packs.sh`) | PASS — all five packs; media/attribution/listen integrity; 24 declared assets (23 device-speech allowlisted + 1 bundled Italian clip) |
| Editorial `audit_editorial.sh --strict` | PASS, exit 0 — false-free-production **0**; comprehension 102 informational |
| Generated catalog | byte-identical (255 lesson entries; no regeneration needed) |
| Unit tests | **429/429, 0 failures** |
| UI tests | **6/6, 0 failures** |
| `git diff --check` | clean |

## Slices included

### 3.1 Audio inventory + one Spanish listening pilot
- Inventory verified against packs and recorded in `docs/skill-map.md` ("Audio inventory (2026-09-26)"): fr 5 device-speech steps, it 16 device-speech + 1 bundled listen sequence, de/pt/es previously **zero** (skill-map claim confirmed accurate), 5 standalone Listen tracks (ids/durations/files enumerated).
- Pilot: `es-cafe-mission` (Spanish unit 1) gains a 5-step **listen → interpret → respond** sequence — authored 3-line café exchange synthesized on-device (device-speech, offline), visible transcript, gist + 2 key-detail `selection` steps (`skills: ["listening","vocabulary"]`), and a `self-compare` respond step. Step chain 8→10–14→9 keeps the mission terminal (M5 audit green); lesson revision 3→4; step/lesson IDs otherwise untouched; catalog unchanged.
- Provenance: `docs/audio-provenance/spanish-cafe-listen-pilot.json` — synthesized on-device, authored transcript, `reviewPending: true` (naturalness unverified); allowlist `tools/device-speech-media.txt` extended to 23 entries.
- VoiceOver: device-speech "Hear audio/Stop" button carries `.accessibilityHint("Synthesized course voice")`.
- Test: `PackSpanishTests.testCafeListenPilotStepsResolveAndGrade` (step/stimulus resolution + accepted variant + meaning-changing near miss). One compile error in the test (tuple vs String) found and fixed before the gate.
- **No pronunciation grading; no bulk generation** — replication in German/European Portuguese waits for the developer's pilot verdict.

### 3.2 Existing Listen tracks — structural/transcript audit
- All 5 tracks: section timing monotonic and within declared duration (gate-enforced), files present, offline path has zero network calls, background audio + `MPRemoteCommandCenter` + `nowPlayingInfo` wired, position persisted to `listen_state` (5s tick, pause, background, teardown).
- **Reproducible defect fixed:** main Listen player and lock screen lacked the "(synthesized)" provenance label every other voice surface carries → now "Course voice (synthesized)" on both surfaces; pinned by `testListenVoiceDescriptorIsLabeledSynthesized`.
- New **§1b "Listen device checks"** block in `docs/release-checklist.md` (10 manual rows) for the developer's listening pass.
- Accepted/pending (not defects): no live current-section highlight (feature, not wired broken); no audio-interruption observer (device check); Listen tab intro copy wording is a developer decision.

## Developer-owned evidence still open (blocks Phase 4, not this gate)

1. Phase 1.2: export → fresh-simulator restore check.
2. Phase 3.1: pilot listening on iPhone; replication verdict (de/pt) after it works.
3. Phase 3.2 / §1b: by-ear 5-track checklist + lock-screen truncation + interruption behavior + "calm voice" intro copy decision.
4. Phase 4.1/4.2: walkthrough rows + Instruments traces.

## Evidence integrity

- All figures from the 2026-09-26 Phase 3 gate log — no older run reused.
- No device row marked PASS anywhere; native naturalness/prosody and learner outcomes remain **UNVERIFIED**; all five tracks keep `reviewPending: true`.
- This gate proves the code/content state only — Phase 3's "device notes state what was actually heard" remains open until the developer's listening pass.
