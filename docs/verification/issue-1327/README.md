# Issue 1327 - the auth forms ignore the keyboard, autofill and password visibility

Merged: PR 1331, squash `c71ff8a8194` (fix, with the pre-merge review's two findings fixed on the branch); PR 1338, squash `26d0598059e` (tests for focus movement and Done in flight). Gates on `main` at `8b9b4a2c test(auth): the demo card fits 360dp at 2x text in every locale (#1339)`.

| Criterion | Artifact | Result |
|---|---|---|
| Next moves from email (and name) to the next field on both screens | `auth_form_keyboard_test.log`: "keyboard flow login: Next on the email moves to the password", "keyboard flow register: Next goes name, email, password" (they assert the focused field's text after each Next) | pass |
| Done on the last field submits as the button does | same log: "login Done on the password field signs in", "register Done on the password field registers" (the use case is called once with the typed values) | pass |
| ... and not while a request is in flight | same log: "keyboard flow login: Done while signing in does not send again", "... register: Done while registering does not send again" (Done twice on a pending request, one call). Removing the `isLoading` guard from both screens makes both fail (PR 1338 body) | pass |
| `AutofillHints.email`, `password` / `newPassword`, `name` inside an `AutofillGroup` | same log: "login/register fields carry keyboard actions and autofill hints" | pass |
| A successful sign-in finishes the autofill context | same log: "autofill context and unmounting a successful sign-in commits the credentials" (`TextInput.finishAutofillContext(true)`); "a rejected sign-in, then leaving, saves nothing" and "leaving while the sign-in runs does not throw" cover the review's findings | pass |
| A localized show/hide toggle on the password fields | same log: "login the password can be shown and hidden again" (`find.byTooltip(l10n.showPassword)`, then `hidePassword`); keys in en, vi, es, ar. `login_demo_light.png` / `login_demo_dark.png`, opened: a suffix icon box at the right end of the password field, in both themes. Ahem draws every glyph as a block, so the images show only that an icon is there; which icon it is and its tooltip text come from the test | pass |
| Widget tests cover all three | `auth_form_keyboard_test.log`: 17 tests, all pass | pass |
| Acceptance goldens | `acceptance_goldens.log` (13 pass at `26d0598`); `goldens-checksums.txt`: the two cited PNGs equal the repository's goldens | unchanged since PR 1331 updated them |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

The other standing goldens are not cited.
