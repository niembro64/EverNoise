# Sound engine history and rollback

## Original independent layers — build 22

This is the last release before the fundamental power-complementary crossover redesign authorized on November 15, 2026. Its sound was described by the user as smooth and consistent. The preferred balance is the third Low button, third Mid button, and second High button, counting Off as the first: internal levels **2 / 2 / 1**, with gains **−12 / −12 / −18 dB**.

The engine combines independent Brown, Mid, and GrayAir streams. Brown runs at 8 kHz; Mid/High at 48 kHz. Their overlapping spectra are separately shaped and are not a power-complementary filter bank. Stereo uses independently seeded left/right streams. The existing fixed gains and linear filters avoid the old nonlinear distortion problem.

The Git tag **`sound-baseline-build-22`** preserves the complete app, production DSP, tests, listing, and spectrum evidence before changing generation. `Store/build-22-manifest.json` records the exact source and signed package hashes; `Store/BAND_OVERLAP_AUDIT.md` and `Store/band-overlap-v22.json` document the spectrum and preferred balance. Generated binaries and large test artifacts remain local under ignored `build/`.

To inspect or audition this baseline without overwriting current work:

```sh
git worktree add --detach ../evernoise-sound-baseline sound-baseline-build-22
```

Open that checkout's Xcode project and run it locally. An App Store/TestFlight rollback must use a **new, higher build number**; do not reuse build 22. Record any return to the baseline as a new commit rather than rewriting Git history.

## Next generation: power-complementary bands

The user explicitly approved a fundamental change to sound generation and does not require the new generator to reproduce the old favorite exactly. Treat any changed timbre as an intentional sound-design change, document the target spectrum and crossover math, and retain the baseline tag. Measure complementary power after actual conversion, clipping/headroom, smooth level changes, stereo behavior, and long-duration state continuity before release.
