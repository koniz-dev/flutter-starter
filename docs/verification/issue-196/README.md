# Acceptance evidence - issue #196

`refactor(auth): drop the legacy secureStorageService fallback from
AuthLocalDataSourceImpl`

Verified against `main` after PR #244 merged (`44efa6828cb`).

## Criterion map

| # | Criterion | Artifact |
|---|---|---|
| 1 | parameter and `ArgumentError` branch gone; `tokenStore` required | `criterion-1-constructor.log` |
| 2 | no `secure_storage_service.dart` / `secure_token_store.dart` import | `criterion-2-imports.log` |
| 3 | `grep -rn "StorageService" lib/features` clean | `criterion-3-grep.log` |
| 4 | three call sites wrap the service; assertions unchanged; no test deleted | `criterion-4-call-sites.log` |
| 5 | `./scripts/dev/audit_template.sh` exits 0 | `criterion-5-audit_template.log` |
| 6 | breaking change recorded | `criterion-6-changelog.log` |

`analyze.log`, `format.log` and `tests.log` are the standard
`scripts/test/run_acceptance.sh 196 --no-goldens` output. No goldens ran and the
directory holds no `.png`.

## Breaking change - what an adopter must change

Only code that constructed the data source with the secure-storage form:

```dart
// was
AuthLocalDataSourceImpl(
  storageService: storageService,
  secureStorageService: secureStorageService,
);

// now
AuthLocalDataSourceImpl(
  storageService: storageService,
  tokenStore: SecureTokenStore(secureStorageService),
);
```

`SecureTokenStore` (`lib/core/storage/adapters/secure_token_store.dart`) is
unchanged and is exactly the object the old constructor built, so behaviour is
identical. Any other `ITokenStore` works too.

Nothing in this repository's `lib/` needed the change:
`lib/features/auth/di/auth_providers.dart` has always passed `tokenStore:`.
Three test call sites did, at lines 228, 502 and 619 of
`auth_local_datasource_test.dart`.

## Judgement call: a grep dictated one sentence of prose

Criterion 3 is `grep -rn "StorageService" lib/features` returning no hit in any
`*_local_datasource.dart` - #179's criterion 1 written literally. The dartdoc
explaining the removal originally named `SecureStorageService` and so kept the
grep matching. It now reads "a nullable secure-storage escape hatch" and points
at the CHANGELOG entry, which carries the migration snippet in full. The class
name is still discoverable; it just is not in the file the grep polices.

## No test was deleted

Criterion 4 asks which test asserting the `ArgumentError` was removed. None was:
`grep -rn "ArgumentError" test/features/auth/` matched nothing before or after,
so the branch was unreachable from the suite and removing it cost no coverage.
The whole test diff is four lines: three arguments and one import.
