# Root inspection of issue #1259

Accepted source: 36babffc54ea6632b4e399fc606f27bb97fc8853.

I inspected the actual repository eviction helper, the interceptor selection guard, the new real-provider test, the independent probe source, and both raw counterfactual outputs. The initial four orphan cases fail because the secure access token survives. The strengthened callback-count test then fails four times with one refresh invocation, exposing the non-null snapshot with a null token. The final audit reports 130 successes and the corrected refresh integration fixture reports three successes.

Eviction starts only after a present access token is paired with a missing/unreadable user. Token-read failures are modelled without blindly removing an unknown/new credential set. Both valid and invalid cached-user reads check the captured generation before returning a user or starting deletion. Teardown registration precedes invalidation, so a newer sign-in waits for local deletion while an older refresh cannot persist its late response. Independent probes execute both stale-read cases and the old-refresh case rather than checking mock call order alone.

Local and HTTP cache cleanup run independently; the first cleanup failure is returned, otherwise the original cache-read failure is preserved. This is local eviction, with no remote logout that could stall startup. The real secure-store test verifies both physical backing-map token removals and a later real Dio request with no bearer. The counting wrapper delegates to the real repository refresher and verifies zero calls, so the demo remote datasource cannot make that assertion vacuous.

The interceptor checks null/empty token after generation/revision certification and before refresh. Its existing finally block drains/rejects pending work and resets the single-flight flag. Nonempty-token refresh/replay controls still execute; the queue error-recovery control establishes a new credentialed session after its first failed refresh removes the old one.

No dependency, platform manifest, environment asset, deploy workflow or real credential changed. Evidence tokens are fixed test strings, and HTTP logger output redacts bearer headers. These host tests establish local session eviction and request behavior; they do not assert Keychain reinstall behavior or server revocation.
