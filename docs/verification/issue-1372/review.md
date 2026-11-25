# Independent pre-merge review

Issue: 1372. PR: 1398.
Reviewed base: `8d7c387a4443fd81646479345ba8b6f0e2d4d608`.
Reviewed head: `e3d326baaf98fb9f59d67f23d55595bae4c4f6bb`.

No actionable findings in this change.

Inspected the complete documentation and test diff, the issue acceptance criteria, remaining LoginUseCase references throughout docs, the shipped AuthNotifier.login implementation, router session redirects, and the real graph used by the documentation tests. Login returns Future<void> and publishes AuthState.user/failure; the revised examples retain this contract and leave routing to the session observer. Remaining direct use-case examples are domain, service, declaration or test examples. No runtime authentication/storage/network code changes.

The provider widget is self-contained and analyzed by the existing snippet helper. The helper rewrites the Markdown template package import to the current pubspec package, preserving renamed-adopter behavior. Existing auth-flow tests already depended on the auth docs and auth module; extending that test does not add a new stripped-variant dependency. The Markdown reader test is under test/docs, which DOC_TESTS already includes.

Independently executed the new lexical guard logic against every Markdown file in each Git tree. It reported 9 original violations at the base and zero at the reviewed head. Additional ordinary, quoted, tilde, and nested Dartdoc fence controls all rejected use-case navigation. A string/comment navigation control was accepted. Probe source and exact output are in 1372-independent-guard-probe.dart and 1372-independent-guard-probe.log. Also inspected the original host failure log: provider example stored tokens but remained SessionStatus.signedOut, while the existing integration control passed. This establishes regression discrimination beyond testing only fixed text.

Limits: this is an intentionally vocabulary-based guard, not interprocedural Dart analysis or a general Markdown parser. The graph test executes the selected documented API; it does not tap the Markdown widget callback. The separate snippet analysis checks widget API compatibility. No duplicate full-suite run, device/backend assurance, or screenshot assertion was performed by this reviewer. Source checkout remained unchanged.


# Independent post-merge QA and auth-documentation security review

Issue 1372; PR 1398; merged source `d2f223b6a25429a294ee4476ca0209691bda307a`.
Accepted source `e3d326baaf98fb9f59d67f23d55595bae4c4f6bb`.

No actionable findings. Independently verified both trees equal `73306b8f370074e1086820157b82f7dea7cb6b35`. The checkout was clean at initial inspection. The change is limited to ten Markdown files and two documentation-test files.

QA walked the actual issue acceptance criteria:

1. Inspected the original five reported examples and remaining direct use-case references throughout docs. UI examples use AuthNotifier.login, generic Result examples demonstrate user lookups, and direct login use-case examples are explicitly domain/service/test guidance. AuthNotifier.login is Future<void> and publishes AuthState.user/failure; the router session binding reads the user and redirects. The docs no longer imply a Result return from notifier login or force Home after credential persistence.
2. Re-executed an independent external guard probe against all Markdown at the merged SHA. It returned zero violations and rejected ordinary, quoted, tilde, and nested Dartdoc examples containing direct use-case navigation. Navigation words in strings/comments were accepted. The earlier independent probe found nine violations at the original base; the original host log also records SessionStatus.signedOut for the provider example despite saved tokens. This is regression discrimination, not merely a passing fixed-text assertion.

Inspected issue-1372 evidence format.log (669 files, zero changes, exit 0), analyze.log (no issues, exit 0), tests.log (4812 passed, 14 skipped, exit 0). Inspected final-head CI metadata: seven actual PR checks succeeded, including all five strip variants; the Quality gate log records 4811 tests passed, 16 skipped and 97.17% coverage above 94%. Counts differ between local and CI; neither was represented as the other. The documentation checker reports no broken relative links, constructor/signature mismatch, unresolved symbols, unknown defines or missing test paths.

Auth-documentation security scope: inspected the replacement sign-in guidance against the existing notifier, session-status binding, and router redirect behavior. It routes UI sign-in through the existing session owner, preserves the router destination behavior, and introduces no storage, transport, dependency, credential or runtime auth implementation change. Hardcoded email/password values remain illustrative documentation values. No security defect introduced by this documentation/test diff was identified.

Artifacts: 1372-postmerge-probe.dart and 1372-postmerge-probe.log contain the independent executable probe and exact output. No source or external state was mutated by this reviewer. Root's post-merge audit was running during review; this report does not treat an unfinished audit as a PASS.

Limits: the guard is vocabulary-based, not an interprocedural proof for arbitrary Dart. The graph test exercises the selected documented API, while snippet analysis checks widget compilation. No device, live-backend, native storage, screenshot, or general runtime security assurance is claimed. Final evidence publication and issue closure remain the owning session's responsibility.


Owning-session completion: post-merge audit finished successfully with clean format/analyze and 26 passing tests; post-merge documentation checker passed. Root inspected the final review, probe outputs, logs, parity, refs, deliverable and epic gates before publication.

