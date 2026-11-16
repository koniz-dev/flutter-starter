# Root inspection

The app observes locale events only while MyApp is mounted and removes its observer on disposal. A deferred initial refresh catches a device fallback read before mounting; the callback checks mounted before using ref and runs outside widget creation. Both normal and stripped bootstrap use restoreLocale, which does not mark a device fallback as a user choice. LocaleNotifier records explicit selection before notification and ignores late restore/provider results after that selection. Stored choices still resolve through LocalizationService.

Opened independent report and raw results: eight head runtime cases pass; exact archived base gives six regression failures and two passing controls. Two independent probes cover observer unmount/remount and invalidated futures/manual precedence; 26 main/picker tests pass. Probe harness metadata/eager-read corrections are documented as harness issues rather than app defects. The initial six-case root baseline gave four failures/two controls; the additional deterministic captured-fallback test exposed and fixed the missing initial refresh.

Broad audit passes223 tests, clean format/analyzer. One obsolete constructor test asserted ConsumerWidget inheritance; actual MyApp configuration, idle-frame, scope override and rendering tests remain. The source golden main counterpart was synchronized and independently compared byte-for-byte. No generator annotations changed, so codegen is skipped. Framework locale events/text/directionality are host proof; no physical settings UI, backend, screenshot or font-layout assurance is claimed.

Full host/CI, source parity and postmerge checks remain to be appended before publication.

Final host at88fadddd80da674c77d6f2df3e633a13d7f62ec8 completed:4569 tests passed,14 skipped, exit0; format638 unchanged and analyzer clean. Five final-head Strip checks SUCCESS. M/E fetched with0/0 divergence. Quality pending; no merge before its raw results/coverage/tracked guard are inspected.

All six final-head CI checks SUCCESS. Quality tail inspected:4568 passed/16 skipped, coverage96.71%, tracked-file guard clean. Ready for guarded squash merge of accepted88fadddd80da674c77d6f2df3e633a13d7f62ec8.

Merged d1b5830f4b73ac8abe118b6eba5c25c1d826d5f4 has accepted tree7bc0560fa9e6d684093c5f936e69019b61a4d0d9. Postmerge G2 audit52 passed and independent QA10 passed. Opened QA report/raw, refs, deliverable, epic coverage and parity outputs. The first postmerge QA selector selected zero tests; corrected regex invocation executed all ten, transparently preserved in raw output. No criterion rests on that empty invocation, a screenshot or a physical device claim. Ownership/status current and no remaining finding.
