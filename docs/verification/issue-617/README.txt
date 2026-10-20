file_seeds_before_main.txt: optimized_image_test.dart as on main (4485f06),
  under the CI seed and three others. On main the failure is not fully
  seed-determined: seed 42 failed in the first local run and passed in this
  one, because whether precacheImage's timer is still pending also depends
  on image-pipeline timing. The fix removes the timer from the file entirely.
file_seeds_after.txt: the fixed file, 12 seeds including all four above.
full_suite_seeds.txt: the whole suite under 1104818320 (CI's) and two fresh
  random seeds; per-seed logs alongside.
