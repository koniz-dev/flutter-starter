# Source inspection

Accepted source: e3d326baaf98fb9f59d67f23d55595bae4c4f6bb.

The real AuthNotifier.login returns Future<void>, invokes the domain use case,
and publishes the resulting user/failure through AuthState. The router consumes
sessionStatusProvider, which derives signed-in state from that user.

UI examples in API providers, onboarding, common tasks and API overview now call
the shipped notifier. They await completion and observe auth state; the router
owns redirects. Generic Result/DI examples use user lookup; direct LoginUseCase
examples in the domain reference and architecture migration notes are explicitly
labelled domain/service use and process results without navigating.

The Markdown guard scans tracked Markdown, uses CommonMark fence recognition,
lexes Dart while excluding comments/string literals, and checks nested Dartdoc
fences separately. It catches the documented direct/provider/constructor names
paired with navigation or widget consumers. It is a vocabulary regression guard,
not arbitrary interprocedural analysis. Positive and negative controls exercise
its intended boundary.

Baseline before documentation changes: 7 tests passed and 2 failed, including
real SessionStatus.signedOut after the provider widget's direct-use-case API.
The final suite also compiles the self-contained provider widget against the
current package API and checks real token persistence plus signed-in status.
See baseline.log, guard.log, focused-audit.log and source.patch.

No runtime app changes, screenshot assertions or live backend assurance.
