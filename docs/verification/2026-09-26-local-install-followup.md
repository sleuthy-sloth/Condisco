# Condisco local iPhone install follow-up — 2026-09-26

This follow-up fixes the two path issues recorded in the earlier final gate
report: Italian Unit 9 now precedes Unit 10 in both authored unit and lesson
order, and an “I know this” mark now advances Home, Courses, the widget,
`condisco://continue`, and the lesson recap consistently. The Italian pack is
v1.5.6; its reviewed lesson content is unchanged. The app icon is now the
open-book/conversation mark in `Condisco/ArtworkStage/Icon-1024.png`.

| Check | Result |
| --- | --- |
| `bash tools/preflight.sh --with-ui` | PASS: five content/catalog gates; 386 unit tests and 6 UI tests. This run preceded the final recap helper and progress notification edits. |
| `xcodebuild test -project Condisco.xcodeproj -scheme Condisco -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CondiscoTests -derivedDataPath /tmp/condisco-unit-final ONLY_ACTIVE_ARCH=YES` | PASS on final code: 387 tests, 0 failures. Includes known-mark skip/restore, Italian order, and recap path assertions. |
| `xcodebuild build -project Condisco.xcodeproj -scheme Condisco -destination 'generic/platform=iOS' -derivedDataPath /tmp/condisco-device-build-final CODE_SIGNING_ALLOWED=NO` | PASS on final code: app and widget compile for iPhone. Signing on the connected phone remains an Xcode action. |
| `bash tools/audit_editorial.sh --strict` | PASS: 0 falsely auto-graded free-production/interrogative prompts; report-only editorial backlog remains. |
| App icon assets | All 11 PNGs present at declared dimensions; RGB, opaque. |

This establishes readiness to install over the existing personal-team app
through Xcode. A physical-device smoke test, including audio and progress
preservation after install, remains for the owner to run. No native-speaker
review or learner-outcome claim is made here.
