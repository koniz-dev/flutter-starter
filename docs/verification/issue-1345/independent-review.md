# Independent adversarial review: issue1345 / PR1351

Reviewed accepted `98a16be36b5db4768aed4f8b225652bca3ab4318` against actual base `797573efca9fdb8cc1788bee66ff6f5566ad0ff5`, live acceptance criteria, all three changed files, both submit handlers, AuthNotifier result handling, PasswordFormField and the SDK autofill contract.

**Outcome: no actionable defect identified.** The runtime diff only changes the email fields' ordered hints to `[username, email]`. Email keyboard type/validation, login password and registration newPassword hints, AutofillGroup cancellation, success-only credential commit, request de-duplication and mounted guards are unchanged. The tests explicitly start and advance the transition, then assert both captured State.mounted=false and absence of an offstage old screen before completing the held result. This reaches the previously missed continuation safely and symmetrically for both screens.

## Actual independent checks

Raw output: `1345-independent-tests.log`. Temporary-copy reproducer: `1345-independent-check.py`. All commands used the isolated Flutter3.50/Dart3.14 SDK; root source was never mutated and no full suite was duplicated.

- Accepted-tree focused suite: six neighboring auth test files, **42 tests passed**, exit0. Includes keyboard actions/duplicate-submit controls, both lifecycle tests, normal login/register, failed submit navigation and whitespace email behavior.
- Temporary clone checked out at the actual base, with the unchanged final test file copied in: selecting both hint cases produces **exactly two assertion failures**, expecting `[username,email]` but seeing `[email]`. These are valid discrimination failures, not compilation or harness failures.
- Temporary clone reset to accepted source; remove only login's existing mounted guard: its specific pending-navigation test fails with **Using ref when a widget is about to or has been unmounted is unsafe**. Restore the source, remove only registration's guard: its corresponding test fails with the same error. Both mutations were confined to the temporary clone and restored there before the next check.
- Additional independent adjacent controls in the temporary copy: **2 passed** when each disposed screen receives a late failed request instead of success; both assert disposal before reply and no exception afterward.
- Additional independent registration autofill controls: **2 passed**. Success invokes a credential-saving finish context; rejection followed by leaving commits no credentials and the register screen is absent.

The temporary clone was removed after testing. Tracked root tree is clean and HEAD remains the accepted commit.

## Platform and security scope

The checked-in SDK documents that iOS and web account for only the first hint, while Android translates all hints; username-first is consequently material rather than a list-order-only test change. The email input is an account identifier, while the password field retains its distinct login/new-password purpose. No new credential persistence, logging, transport, session teardown or validation policy is introduced.

Widget tests prove hint configuration and TextInput context calls, not that every native password manager offers or saves credentials on a real device. No native/store/backend assurance is claimed. No generated annotation or strip golden counterpart changed. No external mutations or messages were performed by this reviewer.
