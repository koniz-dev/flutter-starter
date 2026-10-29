# Deep audit 2026-10-29 - reproduction tests

Failing tests written during the audit of `main` 2974085f8fe. Each one fails
at that commit. To run one, copy it into a clone of `main` at the same path,
then run `flutter test <path>`.

| Test | Issue |
|---|---|
| `test/core/network/audit/stale_401_api_client_test.dart`, `stale_401_test.dart` | koniz-dev/flutter-starter#793 |
| `test/features/auth/audit/refresh_unreadable_test.dart` | koniz-dev/flutter-starter#800 |
| `request_body_replay_code_assertion.diff` (applied to `test/core/network/request_body_replay_test.dart`) | koniz-dev/flutter-starter#801 |
| `test/core/utils/audit/pagination_reset_race_test.dart` | koniz-dev/flutter-starter#802 |
| `test/features/feature_flags/audit/override_index_race_test.dart` | koniz-dev/flutter-starter#803 |
