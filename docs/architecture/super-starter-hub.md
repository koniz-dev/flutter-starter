# Super starter hub

One entry page for **what exists**, **what is optional**, and **where it is documented**. Deep content stays in linked guides; this file only maps capabilities.

## Capability matrix

| Area | In repo by default | Enable / replace when needed | Primary doc |
| --- | --- | --- | --- |
| Clean Architecture (layers) | Yes | N/A (keep boundaries) | [Architecture README](README.md), [overview](overview.md) |
| Boundaries (contracts + adapters) | Yes | Swap adapters + DI | [contracts-map.md](contracts-map.md), ADRs in [adr/](adr/) |
| State + DI (Riverpod) | Yes | Path B: rebind presentation to your stack; keep domain | [choose-your-stack.md](choose-your-stack.md) |
| Routing (GoRouter) | Yes | Replace `AppNavigator` adapter + router module | [adr/0003-navigation-boundary.md](adr/0003-navigation-boundary.md), [Routing guide](../guides/features/routing-guide.md) |
| HTTP (Dio + `INetworkClient`) | Yes | Replace `ApiClient` / feature datasources | [adr/0001-network-boundary.md](adr/0001-network-boundary.md), [Network API](../api/core/network.md) |
| Key-value + tokens | Yes | Custom `IKeyValueStore` / `ITokenStore` | [adr/0002-storage-boundary.md](adr/0002-storage-boundary.md), [Storage API](../api/core/storage.md) |
| Theme / design tokens | Yes | New `AppDesignTokens` + `AppTheme` | [adr/0004-theme-token-boundary.md](adr/0004-theme-token-boundary.md) |
| Auth / tasks / flags samples | Yes | Strip via Mason or `tool/strip_sample_features.dart` | [Fork and customize](../guides/onboarding/fork-and-customize.md) |
| Testing (unit / widget) | Yes | Add suites per feature | [Testing guide](../guides/testing/guide.md), [summary](../guides/testing/testing-summary.md) |
| E2E (Patrol) | Dev dependency | Configure devices + write flows | [Testing guide](../guides/testing/guide.md) |
| Security hardening | Guides + optional RASP | FreeRASP override, checklist | [Security README](../guides/security/README.md) |
| i18n | Yes | Add locales + ARB | [Internationalization](../guides/features/internationalization-guide.md) |
| Performance | Guides | Apply as needed | [Performance README](../guides/performance/README.md) |
| Accessibility | Guides | Apply as needed | [Accessibility README](../guides/accessibility/README.md) |
| Store deploy (Fastlane + Actions) | Templates (often manual) | Secrets, signing, enable triggers | [Deployment hub](../deployment/README.md), [fastlane README](../../fastlane/README.md) |
| Local analyze / test | Yes | Tune workflows / branch protection | [Testing summary](../guides/testing/testing-summary.md), [Quality gates](migrations/quality-gates-and-risks.md), [`ci.yml`](../../.github/workflows/ci.yml) |

## Optional integration modules

See **Optional modules** in [contracts-map.md](contracts-map.md) for provider overrides and default (no-op) behavior.

## Quick links

- [Choose your stack](choose-your-stack.md)
- [Contracts and adapter map](contracts-map.md)
- [Fork and customize](../guides/onboarding/fork-and-customize.md)
- [Documentation home](../README.md)
