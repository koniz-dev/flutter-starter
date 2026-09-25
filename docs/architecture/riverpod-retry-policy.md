# Riverpod retry policy

**Riverpod's automatic retry is turned off for the whole app, for the whole
process lifetime.** If you add a provider that can fail and you expect Riverpod
to re-run it for you, it will not. Nothing warns you: the provider simply stays
in its error state.

This page states the policy, where it is set, why it exists, what still retries
without you, and what to do when a provider of yours genuinely needs retry.

---

## Table of Contents

- [The policy in one table](#the-policy-in-one-table)
- [Where it is set](#where-it-is-set)
- [Why auto-retry is off](#why-auto-retry-is-off)
- [Why it could not be limited to startup](#why-it-could-not-be-limited-to-startup)
- [What still retries](#what-still-retries)
- [What to do when a provider needs retry](#what-to-do-when-a-provider-needs-retry)
- [What not to do](#what-not-to-do)
- [Who this affects today](#who-this-affects-today)

---

## The policy in one table

| Layer | Retries? | Scope |
| --- | --- | --- |
| Riverpod provider rebuilds (`Retry` on the container) | **No** | Every provider, every launch, whole process lifetime |
| Riverpod provider rebuilds (`retry:` on one provider) | Yes, if you set it | Only the provider that declares it |
| Dio HTTP requests (`RetryInterceptor`) | Yes, by default | Traffic that goes through `ApiClient` / `DioNetworkClient` only |
| Any other I/O (platform channels, WebSockets, file reads, `dart:io`) | **No** | Nothing retries these for you |

## Where it is set

`lib/main.dart` builds the one container the app runs on:

```dart
Duration? _neverRetry(int retryCount, Object error) => null;

@visibleForTesting
ProviderContainer createAppContainer({
  List<Override> overrides = const <Override>[],
}) {
  return ProviderContainer(retry: _neverRetry, overrides: overrides);
}
```

That same container is handed to `runApp` inside an `UncontrolledProviderScope`
at the end of `main()`. It is not a startup-only container and it is never
swapped out, so `_neverRetry` governs every provider rebuild the app will ever
perform. The `@visibleForTesting` annotation marks the `overrides` seam, not the
function - this is the production factory.

A `Retry` returning `null` means "do not retry"; returning a `Duration` means
"retry after this delay". Riverpod's own
`ProviderContainer.defaultRetry` - the behaviour this template opts out of -
retries up to 10 times with an exponential backoff from 200 ms to 6.4 s, for
every failure that is not an `Error` and not a `ProviderException`.

## Why auto-retry is off

The default retry caused a hard launch failure. `main()` reads its startup
providers with `container.read(p.future)`, which **awaits the future without
listening to the provider**. When `storageInitializationProvider` threw
`MigrationExecutionException` - an `Exception`, so squarely inside what
`defaultRetry` retries - Riverpod scheduled a retry by invalidating a provider
that had no listeners. Nothing rebuilt it. The awaited future never completed:
measured past 120 seconds with the migration body having run exactly once.

The consequence was not a slow launch, it was no launch. `runApp` was never
reached, the `StartupFailureApp` error screen below the guard never fired, and
the user got a black window with no error, no retry button, and no way out. A
visible failure is recoverable; an unbounded hang is not.

Full reasoning, with the measurements: koniz-dev/flutter-starter#101, and the
regression suite in `test/core/startup/startup_reachability_test.dart` (which
drives the real `createAppContainer()`, so a regression in `main.dart`'s
container fails those tests).

## Why it could not be limited to startup

The obvious wish is "retry off for the startup sequence, Riverpod's default
everywhere else". Riverpod 3 cannot express it. A container-level `Retry` is:

```dart
typedef Retry = Duration? Function(int retryCount, Object error);
```

It receives the attempt count and the error. **It is not told which provider
failed**, so a container-level function cannot single out the startup
providers. And because the app has exactly one container - the startup one,
handed straight to `runApp` - a container-level opt-out is necessarily an
app-lifetime opt-out.

The lever that *is* provider-aware is the per-provider `retry:` parameter. See
[What to do when a provider needs retry](#what-to-do-when-a-provider-needs-retry).

## What still retries

`RetryInterceptor` is wired unconditionally into the Dio pipeline in
`ApiClient._createDio`, and it is unaffected by the Riverpod policy - it sits a
layer below, replaying the HTTP request rather than rebuilding a provider. It
retries transient failures (timeouts, connection errors, 5xx) with exponential
backoff and jitter, up to three retries by default, and only for the RFC 9110 safe
methods (`GET`, `HEAD`, `OPTIONS`) unless a request opts in. Details and the
per-request override: [RetryInterceptor](../api/core/network.md#retryinterceptor).

The boundary matters. `RetryInterceptor` covers **Dio traffic only**. A
provider that reads a file, opens a WebSocket, calls a platform channel, or
talks to a vendor SDK with its own HTTP stack gets no retry from either layer.

## What to do when a provider needs retry

Do not change the container. Set `retry:` on the individual provider. Riverpod
resolves the policy per provider as
`origin.retry ?? container.retry ?? ProviderContainer.defaultRetry`
(`riverpod/lib/src/core/element.dart`), so a provider-level value wins over the
container's `_neverRetry` without touching anyone else.

Hand-written provider:

```dart
final remoteConfigProvider = FutureProvider<Config>(
  (ref) => ref.watch(configServiceProvider).fetch(),
  retry: (retryCount, error) =>
      retryCount >= 3 ? null : Duration(milliseconds: 200 * (1 << retryCount)),
);
```

Code-generated provider (`@riverpod`), including an `AsyncNotifier`:

```dart
@Riverpod(retry: _retryConfig)
Future<Config> remoteConfig(Ref ref) =>
    ref.watch(configServiceProvider).fetch();

Duration? _retryConfig(int retryCount, Object error) =>
    retryCount >= 3 ? null : Duration(milliseconds: 200 * (1 << retryCount));
```

Two things to check before you reach for this:

1. **Is the provider watched?** Per-provider retry has the same requirement the
   startup hang exposed. Retry works by invalidating the provider and waiting
   for a rebuild, which only happens if something is listening. A provider read
   with `container.read(p.future)` or `ref.read(p.future)` and merely awaited
   will hang instead of retrying. Retry belongs on providers a widget
   `ref.watch`es.
2. **Is it a UX regression?** A retrying provider stays in
   `AsyncLoading(retrying: true)`, so the `AsyncValue.error` branch in your
   widget does not run until the attempts are exhausted. With the Riverpod
   default that is up to ten invisible attempts before the user sees anything.
   Bound the attempt count, and prefer surfacing the error with an explicit
   "Try again" affordance.

Alternatives that often fit this template better, because they keep the retry
visible and testable:

- Retry inside the repository or data source and return a `Result`, the way the
  rest of the template reports failure. See
  [Error Handling: Result Pattern](design-decisions.md#error-handling-result-pattern).
- For HTTP, opt the request into `RetryInterceptor` rather than retrying a
  provider around it.
- For a user-triggered retry, `ref.invalidate(provider)` behind a button. The
  startup sequence does the coarse version of this: `StartupFailureApp`'s "Try
  again" button re-invokes `main()`.

## What not to do

Do not remove `retry: _neverRetry` from `createAppContainer` to "get the
default back". That is the exact configuration that produced the black-window
hang, and `test/core/startup/startup_reachability_test.dart` will fail if you
do. If you need the Riverpod default broadly, the startup reads in `main()`
have to stop being unlistened `read(p.future)` awaits first.

## Who this affects today

Nothing in `lib/` relies on Riverpod auto-retry, which is why the opt-out was
safe to make:

- The three `FutureProvider`s are `storageInitializationProvider`,
  `sessionRestorationProvider` (both startup-only) and `currentLocaleProvider`
  (whose service catches `Exception` and falls back to the default locale, so
  only an `Error` can escape - and `defaultRetry` never retried `Error`s).
- There is no `AsyncNotifier` in the tree. `AuthNotifier.build()` and
  `TasksNotifier.build()` are synchronous; their I/O runs in methods that assign
  state from a `Result`, which `retry` does not govern.
- The feature-flag providers are the only ones feeding an `AsyncValue` error
  branch in a widget, and their remote data source is
  `NoOpFeatureFlagsRemoteDataSource`.

The first network-backed `FutureProvider` or the first `AsyncNotifier` added to
this template changes that. That contributor inherits this policy without
choosing it, which is the reason this page exists.

---

## Related

- [Design Decisions](design-decisions.md) - why Riverpod, and the Result pattern
- [Network API reference](../api/core/network.md) - `ApiClient` and the interceptor pipeline
- [Common Tasks](../guides/features/common-tasks.md) - adding providers and features
