# Juicer Task: Add a Common Destructive-Operation Safety Model

## Objective

Create the shared transaction foundation required to make Juicer’s file and system-changing tools previewable, explicit, recoverable, and auditable.

## Important repository note

The previous roadmap file `plan.md` is unexpectedly absent from the workspace. Do not delete or overwrite any planning/documentation file during this task. Record the missing `plan.md` in `report.md`; restoring it is a separate planning-recovery action unless it can be recovered safely from the repository history without changing unrelated work.

## Scope

- Add a focused transaction model under `juicer/sources/models` with lowercase naming.
- Define reusable types for:
  - operation identity and title;
  - read-only preview items and selected targets;
  - estimated impact, including item count and byte count where available;
  - confirmation state;
  - progress/state transitions;
  - success, partial failure, cancellation, and recovery information;
  - an operation manifest suitable for local action history.
- Keep the model independent of SwiftUI and direct filesystem mutation where possible.
- Add path-scope validation that rejects ambiguous or unsafe targets such as the filesystem root, home directory, workspace root, or empty paths unless a narrowly scoped feature explicitly authorizes them.
- Add a reusable preview-to-confirmation flow that feature views can adopt without duplicating safety logic.
- Add deterministic tests for state transitions, target validation, byte/item aggregation, cancellation, partial failure, and manifest serialization.
- Use temporary directories only in tests. Do not delete or mutate real user files.
- Integrate the model into one low-risk existing feature as a preview-only vertical slice, preferably Cache Cleaner or another workflow where the current code already exposes selected cleanup candidates.
- Do not implement broad deletion refactors in this task. The first integration must prove preview and manifest behavior before any real destructive commit path is changed.
- Preserve all unrelated pre-existing working-tree changes.

## Safety requirements

- Preview must identify each target path or a privacy-safe redacted representation before confirmation.
- Confirmation must state what will change and how many items/bytes are affected.
- A failed operation must never be reported as fully successful.
- Cancellation must produce a distinct result and preserve the manifest.
- Logs and manifests must not contain secrets or unnecessary file contents.
- The implementation must not introduce new shell execution or broaden entitlements.

## Verification

- Generate the Xcode project from `project.yml` if XcodeGen is available.
- Run the XCTest suite and confirm the existing 10 tests still pass along with the new tests.
- Run `swiftc -parse` or stronger compile/type validation over application and test sources.
- Exercise path validation and transaction state transitions with temporary-directory tests.
- Inspect the integrated feature to confirm it remains preview-only and cannot delete files through the new code path.
- Run scoped `git diff --check` for changed files.
- Report the missing `plan.md`, all files changed, tests run, and any environment limitation in `report.md`.

## Deliverables

- Shared destructive-operation transaction model and validation logic.
- Focused XCTest coverage.
- One preview-only feature integration.
- Updated generated project metadata only if required by the repository workflow.
- `report.md` with verification results and the `plan.md` recovery note.

After completing the task and writing `report.md`, delete this `task.md` file.
