### Fixed

- [Correct rename/configuration guidance](https://github.com/koniz-dev/flutter-starter/issues/1348): remove the stale count of imports needing sorting after rename and the misleading suggestion to add the existing EnvConfig.load call when configuration is supplied through build defines.

- [Finish release and hook audit findings](https://github.com/koniz-dev/flutter-starter/issues/1347): release formatting fails before tests or mutations, changelog headings strip version comments, tag/deletion-only pushes skip tests while branch pushes test the working tree, and docs state PowerShell7+ plus whole-repository pre-commit export costs. Part of the [November audit checklist](https://github.com/koniz-dev/flutter-starter/issues/1343).

- [Prevent editing a pending task snapshot](https://github.com/koniz-dev/flutter-starter/issues/1346): disable the Edit menu item while that task is being mutated, so a title edit opened after a pending toggle completes keeps the updated completion state.

- [Prove auth screen disposal and identify autofill usernames](https://github.com/koniz-dev/flutter-starter/issues/1345): login/register email fields advertise username before email for credential pairing. Pending-submit navigation tests verify the old screen is disposed before completing the request, and detect removal of either mounted guard.

- [Remove Mason through the strip tool](https://github.com/koniz-dev/flutter-starter/issues/1342): onboarding instructions name --remove-bricks and explain that deleting bricks/mason.yaml by hand leaves broken test imports as well as documentation links; regression guards keep this warning in place.

- [Clarify release TLS configuration](https://github.com/koniz-dev/flutter-starter/issues/1341): document that direct API and realtime TLS handshakes in staging/production release use the default or pinned context, and explain where to load private CAs and client certificates instead of relying on HttpOverrides.
