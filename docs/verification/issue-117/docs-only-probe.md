# Docs-only probe for issue 117

This file exists to be the entire content of a docs-only pull request, so the
**Quality gate** check can be observed reporting a conclusion on one.

Before koniz-dev/flutter-starter#117, `ci.yml` carried
`paths-ignore: ['**/*.md', 'docs/**']`, so a pull request containing only this
file produced no CI run at all and no Quality gate check. Pull request #136
(evidence for issue 65, 19 files, all under `docs/verification/issue-65/`) is
the historical proof: its check list was Issue refs plus the three Strip jobs,
with no Quality gate.

A green Quality gate on this pull request does **not** mean `dart format`,
`flutter analyze` and `flutter test` passed. It means they were not run, because
no changed path can affect them. The job summary for the run states which of the
two happened and lists every changed path.
