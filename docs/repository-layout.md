# Repository Layout

Juicer keeps the public root small, groups implementation by role, and keeps
machine-specific work under an ignored `.local/` directory.

## Public And Tracked

```text
sources/
  models/
  services/
  views/
  resources/
tests/
project.yml
readme.md
license
security.md
contributing.md
code_of_conduct.md
changelog.md
appcast.xml
docs/
  releases/
  capability-matrix.md
  feature-opportunities.md
  open-source-feature-audit.md
  release-checklist.md
  ui-improvements.md
web/
```

The public surface contains source code, reproducible project generation,
product documentation, release notes, legal policy, security guidance, and
the download website.

## Local-Only

```text
.local/
  assets/galleries/
  artifacts/
  build/
  metadata/
  reports/
  tools/my_clean_crew/
```

`.local/` is ignored by `.gitignore` and is the home for generated builds,
archives, internal reports, screenshots that are not part of the public
website, and the auxiliary local agent project. The generated
`juicer.xcodeproj/` remains at the root for Xcode convenience but is also
ignored and must always be regenerated from `project.yml`.

Root-level agent settings and deployment metadata remain in their conventional
locations when tools require those paths; `.gitignore` keeps them out of the
public repository.

## Organization Rules

- Keep Swift implementation under `sources/models`, `sources/services`, and
  `sources/views`; keep app resources under `sources/resources`.
- Keep XCTest files under `tests/`.
- Keep roadmap, audits, release notes, and UI planning under `docs/`.
- Keep release notes under `docs/releases/`; keep `changelog.md` at the root
  for repository hosting conventions.
- Keep generated projects and build products local and ignored.
- Make changes to project structure in `project.yml`, then run `xcodegen
  generate`.
- Use lowercase names for every new file and folder.

`.gitignore` controls future visibility of untracked files. It cannot remove a
file that has already been committed from repository history; that would
require a separate, explicitly authorized Git operation.
