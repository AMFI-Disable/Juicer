# Task #5 Report: Destructive-Operation Safety Foundation

## Outcome

Implemented a reusable, Foundation-only safety transaction model and integrated it into Cache Cleaner as a preview-only vertical slice. The new path validates and freezes selected targets into a serializable manifest, shows exact paths and aggregate impact, and intentionally exposes no mutation action.

The existing Cache Cleaner trash methods were not refactored or invoked by the new preview path. No real user files were deleted, moved, or modified during implementation or verification.

## Shared safety model

Added `juicer/sources/models/destructiveoperation.swift` with reusable types for:

- stable operation identity and human-readable title;
- read-only preview items, selected target IDs, target categories, and exact paths;
- aggregate item count, known byte count, and unknown-size tracking;
- explicit confirmation state and an impact-specific confirmation phrase;
- preview, confirmation, ready, running, success, partial-failure, failure, and cancellation states;
- monotonic item progress;
- target-specific failure details and recovery information;
- a Codable operation manifest suitable for local action history;
- guarded state transitions that prevent incomplete work from being reported as successful;
- path validation for empty, relative, filesystem-root, home-root, workspace-root, and out-of-scope targets, with narrow explicit authorization support.

The model does not import SwiftUI, execute shell commands, or perform filesystem mutation.

## Cache Cleaner preview integration

Updated `CacheCleanerManager` to build a safety manifest from the currently selected, existing cache insights. Path validation occurs before the manifest is published, and selected target IDs and impact are captured together so the preview remains a stable snapshot.

Updated `cachecleanerview` with a **Safety Preview** action and read-only sheet that displays:

- exact selected item count;
- known byte impact and unknown-size count;
- cache/log classification;
- every captured target name and path;
- an explicit statement that the sheet cannot change files;
- guidance that rescans or selection changes require a new preview.

The sheet has only a **Done** action. It has no callback to `trashSelected`, `trashProjectDeps`, `removeItem`, `trashItem`, or command execution.

## Regression coverage

Added `juicer/tests/destructiveoperationtests.swift` with 10 deterministic tests covering:

- selected item/byte aggregation and unknown sizes;
- rejection of an empty selection;
- explicit confirmation and successful state transitions;
- rejection of an incorrect confirmation phrase;
- partial failure classification;
- distinct cancellation with preserved manifest and recovery data;
- manifest JSON serialization round-trip;
- empty, relative, root, home, and workspace target rejection;
- allowed-scope enforcement using temporary directories;
- monotonic progress enforcement.

Tests use only UUID-named directories under `FileManager.default.temporaryDirectory`; teardown removes only the exact directory created by each test.

## Verification

- `swiftc -parse` over all application and test Swift sources: passed.
- Scoped `git diff --check` for Task #5 files: passed. Git emitted a benign fsmonitor IPC warning already present in this workspace.
- `xcodegen generate`: passed with XcodeGen at `/opt/homebrew/bin/xcodegen`.
- Generated project metadata: no tracked diff was required; source folder discovery included both new files.
- Full macOS XCTest run with signing disabled and DerivedData at `/private/tmp/JuicerTask5DerivedData`: passed.
- Test result: **20 tests executed, 0 failures** (the existing 10 tests plus 10 new tests).
- Xcode result bundle: `/private/tmp/JuicerTask5DerivedData/Logs/Test/Test-juicer-2026.08.02_09-34-17-+0800.xcresult`.
- Source audit confirmed the new model contains no command execution or production mutation call, and the preview sheet contains no destructive action.

The build continues to emit pre-existing warnings, including Swift 6 concurrency diagnostics, deprecated macOS APIs, unassigned app-icon children, and a build-script dependency-analysis warning. XCTest also logs an expected notification-authorization failure in the test host. None caused a test failure, and they were outside this focused task.

## Files changed

- `juicer/sources/models/destructiveoperation.swift` — new shared safety transaction, manifest, impact, and path-validation model.
- `juicer/tests/destructiveoperationtests.swift` — new deterministic regression coverage.
- `juicer/sources/models/cachecleanermodel.swift` — preview-manifest builder for selected cache insights.
- `juicer/sources/views/cachecleanerview.swift` — read-only safety preview UI and validation error presentation.
- `report.md` — this completion report.
- `task.md` — removed after completion as requested.

## Planning recovery note

`plan.md` was absent before Task #5 began and remains absent. Repository history contains earlier versions of `plan.md`, so recovery appears possible, but no version was restored because selecting the correct historical roadmap is a separate planning decision and this task explicitly prohibited changing planning/documentation files. No planning file was deleted or overwritten during Task #5.

## Recommended next adoption step

Before changing any production deletion path, make the existing Cache Cleaner confirmation consume the frozen manifest and revalidate it immediately before commit. Persist the terminal manifest atomically to a local history store, then migrate one recoverable mutation path with per-target results and partial-failure reporting. The current task deliberately stops before that boundary.
