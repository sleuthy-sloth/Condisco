# Phase 0 baseline — 2026-09-26 (Condisco)

Dated baseline record for Phase 0.1 of the improvement plan ("a dated baseline
matches the tree"). This note pins the **working-tree state** the gates were run
against on 2026-09-26 and what passed on that tree. It is a **dirty-tree
baseline, not a pass claim for future commits** — nothing was staged, reset, or
committed to produce it.

## 1. Checkout identity

- Branch `main`, **HEAD `50a9f7fd43f2442707bd35b5f4deb2054dae5b61`** —
  "Reconcile roadmap checkboxes against evidence: 17 ticked, 12 left open with
  BLANK notes" (2026-09-26 08:59:53 -0700).
- Working tree **dirty at baseline**: 34 status entries, 32 files changed,
  **+1400 / −1416**, nothing staged (`git diff --cached` empty).
- Because the tree carries substantial uncommitted product work, every result
  in this note applies to this exact tree and today's run — a commit that
  precedes or follows it must be re-gated, not presumed green.

## 2. Dirty-file inventory (matches `git status --short`)

All preserved intact; Phase 0.1 discarded none of it.

- **Ongoing product work, cluster 1 — Italian pack content update:**
  `Condisco/Content/packs/italian.json` (v1.5.6),
  `Condisco/DeepLink/LessonCatalog.generated.swift` (regenerated),
  `Condisco/DeepLink/DeepLink.swift`.
- **Ongoing product work, cluster 2 — "I know this" navigation fix:**
  `Condisco/Store/LearningStore.swift`, `Condisco/Store/WidgetSnapshotWriter.swift`,
  `Condisco/Home/HomeView.swift`, `Condisco/Lesson/CoursesView.swift`,
  `Condisco/Lesson/LessonPlayerView.swift`, plus tests
  `Condisco/Tests/EngineTests.swift`, `Condisco/Tests/StoreTests.swift`.
- **Generated/icon output:** `Condisco/ArtworkStage/*` (deleted bee icon
  source, new `Icon-1024.png`, updated `decode-artwork.sh`), all 11
  `Condisco/Assets.xcassets/AppIcon.appiconset/Icon-*.png`.
- **Xcode personal UI state:** `Condisco.xcodeproj/…/UserInterfaceState.xcuserstate`.
- **`.gitignore` modification.**
- **Docs in progress:** `README.md`, `docs/engineering-findings.md`,
  `docs/native-review-kit.md`, `docs/release-checklist.md`, `docs/skill-map.md`,
  and untracked `docs/verification/2026-09-26-local-install-followup.md`.
- **CI workflow:** `.github/workflows/ci.yml` deleted (unstaged). **Decision
  (2026-09-26, developer): keep it deleted — intentional.** Local
  `bash tools/preflight.sh --with-ui` is the required gate; documented in README.

## 3. Gate results — run 2026-09-26

| Gate | Command | Exit | Result |
| --- | --- | --- | --- |
| Pack + media integrity | `bash tools/check_packs.sh` | 0 | PASS (run 10:45–10:57 -0700) |
| Editorial audit (strict) | `bash tools/audit_editorial.sh --strict` | 0 | PASS — false-free-production gate: free-phrase 0, interrogative 0; informational: comprehension prompts 102 |
| Diff hygiene | `git diff --check` | 0 | PASS |
| Full pre-share gate | `bash tools/preflight.sh --with-ui` | 0 | PASS — `PREFLIGHT PASSED`; unit 387/387, 0 failures; UI 6/6, 0 failures; iPhone 18 Pro (iOS 27 runtime), Debug-iphonesimulator |

Full log: `docs/verification/2026-09-26-phase0-baseline-gates.log`.

## 4. Prior-evidence cross-check

- `2026-09-26-final-gate-report.md` (at commit `bca8ad6`): 385 unit / 6 UI,
  preflight exit 0. Consistent with today's fresh run (387 unit — the +2 come
  from the "I know this" recap-path assertions added since; see the local
  install follow-up).
- `2026-09-26-local-install-followup.md`: 386→387 unit rerun on final code,
  6 UI, unsigned iPhone-target build PASS, editorial strict PASS. Consistent.
- **Physical-device smoke remains UNVERIFIED/BLANK everywhere** — no device
  result is recorded here, and none was marked PASS.

## 5. Doc staleness fixed in this slice

- README: Phase 1 / Phase 2 verification rows annotated as historical /
  superseded with the current baseline (387 unit, 6 UI, 2026-09-26); CI
  workflow removal stated explicitly (local preflight is the gate).
- `docs/release-checklist.md`: 2026-09-26 evidence added to the Engineering
  preflight and UI smoke PASS rows (dates kept attached per claim); Phase 0
  baseline row added; CI-workflow wording replaced with the local-gate
  statement. All BLANK/UNVERIFIED rows left blank.