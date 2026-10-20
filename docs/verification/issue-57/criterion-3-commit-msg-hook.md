=== .githooks/commit-msg accept/reject table ===

| Subject | Expected | Actual | |
|---|---|---|---|
| **the five inputs named in issue #57** | | | |
| `feat(auth)!: x` | ACCEPT | ACCEPT | ok |
| `feat!: x` | ACCEPT | ACCEPT | ok |
| `Revert "feat: x"` | ACCEPT | ACCEPT | ok |
| `fixup! feat: x` | ACCEPT | ACCEPT | ok |
| `feat(auth): x` | ACCEPT | ACCEPT | ok |
| **other forms that must still be accepted** | | | |
| `Revert "feat(auth): x"` | ACCEPT | ACCEPT | ok |
| `squash! feat: x` | ACCEPT | ACCEPT | ok |
| `amend! feat: x` | ACCEPT | ACCEPT | ok |
| `Merge branch 'main' into fix/x` | ACCEPT | ACCEPT | ok |
| `fix(tooling): build_all.sh drops --flavor` | ACCEPT | ACCEPT | ok |
| `chore(deps)!: require Dart 3.9` | ACCEPT | ACCEPT | ok |
| **malformed subjects that must still be rejected** | | | |
| `updated some stuff` | REJECT | REJECT | ok |
| `feat` | REJECT | REJECT | ok |
| `feat:` | REJECT | REJECT | ok |
| `feat: ` | REJECT | REJECT | ok |
| `feat(auth)!x` | REJECT | REJECT | ok |
| `Feat(auth): x` | REJECT | REJECT | ok |
| `wip! feat: x` | REJECT | REJECT | ok |
| `reverted the thing` | REJECT | REJECT | ok |

=== full multi-line message with the Refs trailer (the form this repo uses) ===
ACCEPT
    fix(tooling)!: make the commit-msg hook accept breaking changes and reverts
    
    Refs koniz-dev/flutter-starter#57

=== rejection output shown to the author ===
    ❌ Commit message does not follow Conventional Commits.
    
       Format: <type>(<optional-scope>)<optional-!>: <subject>
    
       Types: feat fix docs style refactor test chore perf ci build revert
    
       Examples:
         feat(auth): add biometric login
         fix: handle null user after logout
         feat(api)!: drop the v1 endpoints (breaking)
         docs(readme): update install steps
    
       Also accepted: Merge..., Revert "...", fixup!/squash!/amend! ...
    
       Bypass (rare): git commit --no-verify


=== BEFORE: the same table against the pre-fix hook (a688cbd) ===
=== .githooks/commit-msg accept/reject table ===

| Subject | Expected | Actual | |
|---|---|---|---|
| **the five inputs named in issue #57** | | | |
| `feat(auth)!: x` | ACCEPT | REJECT | MISMATCH |
| `feat!: x` | ACCEPT | REJECT | MISMATCH |
| `Revert "feat: x"` | ACCEPT | REJECT | MISMATCH |
| `fixup! feat: x` | ACCEPT | REJECT | MISMATCH |
| `feat(auth): x` | ACCEPT | ACCEPT | ok |
| **other forms that must still be accepted** | | | |
| `Revert "feat(auth): x"` | ACCEPT | REJECT | MISMATCH |
| `squash! feat: x` | ACCEPT | REJECT | MISMATCH |
| `amend! feat: x` | ACCEPT | REJECT | MISMATCH |
| `Merge branch 'main' into fix/x` | ACCEPT | ACCEPT | ok |
| `fix(tooling): build_all.sh drops --flavor` | ACCEPT | ACCEPT | ok |
| `chore(deps)!: require Dart 3.9` | ACCEPT | REJECT | MISMATCH |
| **malformed subjects that must still be rejected** | | | |
| `updated some stuff` | REJECT | REJECT | ok |
| `feat` | REJECT | REJECT | ok |
| `feat:` | REJECT | REJECT | ok |
| `feat: ` | REJECT | REJECT | ok |
| `feat(auth)!x` | REJECT | REJECT | ok |
| `Feat(auth): x` | REJECT | REJECT | ok |
| `wip! feat: x` | REJECT | REJECT | ok |
| `reverted the thing` | REJECT | REJECT | ok |

=== full multi-line message with the Refs trailer (the form this repo uses) ===
REJECT
    fix(tooling)!: make the commit-msg hook accept breaking changes and reverts
    
    Refs koniz-dev/flutter-starter#57

=== rejection output shown to the author ===
    ❌ Commit message does not follow Conventional Commits.
    
       Format: <type>(<optional-scope>): <subject>
    
       Types: feat fix docs style refactor test chore perf ci build revert
    
       Examples:
         feat(auth): add biometric login
         fix: handle null user after logout
         docs(readme): update install steps
    
       Bypass (rare): git commit --no-verify


=== real "git commit" through the installed hook ===

-- 1. Conventional Commit with the repo's Refs trailer --
   exit=0 subject=feat(auth): add biometric login
-- 2. breaking change with a scope (used to need --no-verify) --
   exit=0 subject=feat(api)!: drop the v1 endpoints
-- 3. breaking change without a scope --
   exit=0 subject=feat!: require Dart 3.9
-- 4. git revert of commit 3 (hook sees the generated subject) --
   exit=0 subject=Revert "feat!: require Dart 3.9"
-- 5. git commit --fixup of commit 1 --
   exit=0 subject=fixup! feat(auth): add biometric login
-- 6. malformed subject is still refused --
   exit=1 rejected, HEAD still: fixup! feat(auth): add biometric login

=== resulting history ===
  fixup! feat(auth): add biometric login
  Revert "feat!: require Dart 3.9"
  feat!: require Dart 3.9
  feat(api)!: drop the v1 endpoints
  feat(auth): add biometric login
