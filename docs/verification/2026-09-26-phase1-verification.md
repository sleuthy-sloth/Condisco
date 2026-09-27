# Phase 1 verification — protect progress and recovery

**Date:** 2026-09-26
**Branch:** `main` @ `50a9f7fd43f2442707bd35b5f4deb2054dae5b61` (dirty tree preserved throughout; nothing reset, staged, or committed by the coder)
**Tree at gate:** 36 files changed, +3091/−1638 (Phase 0 baseline 32 files, +1400/−1416, plus Phase 1 slices)
**Gate:** `bash tools/preflight.sh --with-ui` → **PREFLIGHT PASSED, EXIT=0**
(12:01:32–12:09:28 -0700; log: `2026-09-26-phase1-preflight-with-ui.log`)

## Gate results (fresh run, this code state)

| Check | Result |
| --- | --- |
| Pack + media (`check_packs.sh`) | PASS (step green in preflight) |
| Editorial `audit_editorial.sh --strict` | PASS, exit 0 — false-free-production **0** (comprehension 102 informational) |
| Unit tests | **404/404, 0 failures**, iPhone 18 Pro simulator |
| UI tests | **6/6, 0 failures** |
| Catalog drift | PASS |

## Slices included

### 1.1 Export complete and legible
- Export now carries `formatVersion: 1` + `app: "Condisco"` header; includes saved phrases, saved-phrase tombstones, checkpoint tombstones, placement recommendations; excludes device preferences, sync bookkeeping, keychain identity.
- 5 new `DataExportTests` (contents, header, exact round-trip identifiers/timestamps, placement, no-secrets key pinning).
- Export screen copy states contents and exclusions explicitly.

### 1.2 Safe local restore
- New pure `Condisco/Store/ImportValidator.swift` (50 MB cap, app marker, formatVersion 1 + legacy pre-1.1 path, unique event IDs, reference consistency, finite listen positions, no catalog filtering → unbundled historical events retained).
- `LearningStore.applyImport`: one SQLite transaction; conflicting event ID → full rollback (byte-identity asserted); identical repeat import no-op; tombstone-aware merge; placement applied post-commit only.
- `YouView`: `.fileImporter` → preview sheet (counts + date + merge semantics) → explicit confirm. **Developer approved the confirmation copy (2026-09-26).**
- 12 new `ImportRestoreTests`. Two initial fixture failures were diagnosed as tests bypassing the documented caller contract (post-commit placement; full legacy-credit exercise set) — fixtures corrected, production behavior unchanged.
- **Pending developer action (queued with Phase 4):** export from installed app → restore into fresh simulator → confirm lesson progress, saved phrases, Listen position.

### 1.3 Sync promise accurate
- Entitlement reality: `Condisco.entitlements` declares app-groups only; iCloud/CloudKit keys absent (comment: re-add when enrolled).
- You screen / sync paths now state "progress is saved on this device; sync isn't available in this build" when the capability is absent; Sign in with Apple button hidden in this build (returns automatically when entitlements are added).
- README: CloudKit described as optional/absent in this build; **two-device CloudKit sync UNVERIFIED** stated explicitly.
- Release checklist: §7 two-device rows stay BLANK/UNVERIFIED; §8 accepted limitation — whole-row listen-state last-write-wins.
- Simulated two-store merge tests verified present and unweakened: event replay, checkpoint deletion, phrase deletion, listen state, plus offline-first test.
- **Regression found and fixed during Phase 1:** the initial runtime `CKContainer.default()` capability probe SIGTRAP-crashed the app on the You tab (no iCloud entitlement → CloudKit trap; diagnostic `Condisco-2026-09-26-114455.ips`, stack `isCloudKitConfigured.getter → headerSubtitle.getter`). Fixed with a compile-time `CLOUDKIT_ENABLED` gate (off in this build; `#else` paths are local-only truth; no CloudKit symbol reachable without the flag). Both affected UI tests re-ran and passed before this gate.

## Evidence integrity

- All figures above are from the 2026-09-26 Phase 1 gate log, not older runs.
- No device row is marked PASS anywhere; physical-device smoke and two-device CloudKit remain UNVERIFIED.
- Phase 0 baseline remains the reference for the pre-Phase-1 state: `2026-09-26-phase0-baseline.md`.
