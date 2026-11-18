# Postmerge independent QA/security: issue1345 / PR1351

Reviewed merged main `e85e16314c8e01a7e43a66965c4462ea888e8fa6`. Independently verified its complete tree matches accepted `98a16be36b5db4768aed4f8b225652bca3ab4318`: both tree IDs are `6a22382e302225cf3ec6ab9fbf81ff4e7fb5e1b7`, and the whole-tree diff is empty. Tracked checkout is clean.

**Outcome: no actionable defect identified.** Reinspected both auth submit handlers: mounted guards precede post-await ref access; success-only `finishAutofillContext` and cancel-on-dispose groups remain intact. Both email fields lead with username and retain email, while login password and registration newPassword hints retain their distinct purposes. No credential storage/logging, session lifecycle or transport policy changed. Premerge original-source discrimination, guard-removal failures and additional late-failure/registration-context controls remain applicable by exact tree parity.

Fresh merged-tree command, isolated Flutter3.50/Dart3.14:

`flutter test test/features/auth/presentation/screens/auth_form_keyboard_test.dart test/features/auth/presentation/screens/auth_forms_keyboard_test.dart --reporter expanded`

**18 tests passed**, exit0. Actual output is preserved in `1345-postmerge-independent-tests.log`. This covers both disposal-before-completion tests, hint ordering, keyboard submit/focus/duplicate-request controls, credential context success/cancel behavior and keyboard-constrained auth form layout.

No duplicate full suite, source mutation or external write was performed. No real-device password-manager, store-signing or live-backend guarantee is claimed.
