## Summary

Describe the focused change and why it is needed.

- Related issue: Fixes #
- User-visible behavior changed: Yes / No

## Definition of done

- [ ] The implementation is focused, with no unrelated formatting or refactoring.
- [ ] Pure logic and deterministic command/file behavior have unit tests where applicable.
- [ ] A user-visible workflow has integration, UI, or documented manual validation where practical.
- [ ] Success, loading, empty, permission-denied, unsupported, and failure states are handled where applicable.
- [ ] Accessibility labels, keyboard paths, and reduced-motion-safe interactions are covered where applicable.
- [ ] Destructive actions include a preview, explicit confirmation, and recovery information.
- [ ] Privacy was reviewed; secrets, tokens, personal paths, and command output are not unnecessarily persisted or logged.
- [ ] Documentation and release notes are updated for user-visible behavior changes.
- [ ] `xcodegen generate` succeeds.
- [ ] Swift parsing/compilation succeeds.
- [ ] Relevant tests pass.
- [ ] YAML and `git diff --check` quality checks pass.
- [ ] Any environment limitation or intentionally non-applicable item is explained below.

## Verification

List the commands and manual checks run, with their results.

## Limitations and risk

Explain unchecked items, environment limitations, migration concerns, and rollback or recovery behavior.

## UI evidence

For UI changes, include screenshots or a short recording. Write `Not applicable` otherwise.
