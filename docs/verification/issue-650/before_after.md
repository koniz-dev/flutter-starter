# Contrast of the demo card's fill button

Before (main at b03ffbc): `demo_sign_in_card_contrast_test.dart` run against
the unfixed card failed in both themes:

    light: Expected >= 4.5, Actual 1.1132849011364936  (label #0069D9 on card)
    dark:  Expected >= 4.5, Actual 1.7860508226524883  (label #4DA3FF on card)

`before_web_build_real_fonts.png` is the walkthrough screenshot that found
it: a debug web build in Chrome with real fonts; measured from its pixels the
label is 1.13:1 against the card.

After (this change): label and outline use `onSecondaryContainer`; both
themes pass (`contrast_tests.log`), and `login_demo_light.png` /
`login_demo_dark.png` are the new acceptance goldens of the login screen with
the card.
